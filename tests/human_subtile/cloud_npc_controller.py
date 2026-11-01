"""One exact public GitHub-hosted wildlife smoke container; no image pull/build.

Source for review only. Explicit --execute is required. This controller does not
configure host networking, host security, package repositories or Docker daemon.
The pinned 386 image and complete ABI must be independently reviewed first.
"""
import argparse
import base64
import hashlib
import importlib.util
import io
import json
import lzma
import os
from pathlib import Path, PurePosixPath
import re
import selectors
import signal
import subprocess
import sys
import tarfile
import time
import uuid

IMAGE = 'docker.io/library/python@sha256:e859437f5f6d28ecc8452905c49f0729533f72e680feec294186e1ab3799a445'
SCOPE = 'civ13-wildlife-cloud-smoke'
MAX_SECONDS = 600
WORK_SECONDS = 490  # reserve 110 seconds for evidence and owned teardown
MAX_CLI = 2 * 1024**2
MAX_PACKAGE = 16 * 1024**2
MAX_LOG_PACKAGE = 320 * 1024
SHA = re.compile(r'^[0-9a-f]{40}$')
CID = re.compile(r'^[0-9a-f]{64}$')
OWNER = re.compile(r'^[0-9a-f]{32}$')


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


def hosted(env, head):
    require(sys.platform == 'linux' and SHA.fullmatch(head or ''), 'Linux exact commit required')
    required = {'GITHUB_ACTIONS':'true', 'RUNNER_ENVIRONMENT':'github-hosted', 'RUNNER_OS':'Linux',
                'RUNNER_ARCH':'X64', 'GITHUB_REPOSITORY':'Civ13/Civ13',
                'GITHUB_REPOSITORY_ID':'141349998', 'GITHUB_EVENT_NAME':'workflow_dispatch',
                'CIV13_REPOSITORY_VISIBILITY':'public', 'GITHUB_SHA':head}
    require(all(env.get(k) == v for k, v in required.items()), 'Wrong hosted/manual/public exact-head context')


def inspect_owned(info, cid, name, owner, head):
    require(CID.fullmatch(cid or '') and info.get('Id') == cid and info.get('Name') == '/' + name,
            'Container ID/name mismatch')
    labels = info['Config'].get('Labels') or {}
    require(all(labels.get(k) == v for k, v in {'scope':SCOPE, 'owner':owner, 'head':head}.items()),
            'Container labels mismatch')


def inspect_settings(info, image_id, mounts, uidgid, head, suite='smoke', work_deadline=None):
    host, config = info['HostConfig'], info['Config']
    require(info['Image'] == image_id and config['Image'] == IMAGE, 'Container image drift')
    require(host['Memory'] == 3*1024**3 and host['MemorySwap'] == 3*1024**3 and
            host['PidsLimit'] == 64 and host['NanoCpus'] == 2000000000, 'Resource setting mismatch')
    require(host['NetworkMode'] == 'none' and host['ReadonlyRootfs'] is True and host['Privileged'] is False and
            host['CgroupnsMode'] == 'private' and host['IpcMode'] == 'private' and host['PidMode'] == '',
            'Namespace/root mismatch')
    require(host.get('CapDrop') == ['ALL'] and 'no-new-privileges' in (host.get('SecurityOpt') or []) and
            not host.get('PortBindings') and not host.get('Devices') and not host.get('Binds'), 'Extra authority')
    require(host.get('Tmpfs') == {'/work':'rw,noexec,nosuid,nodev,size=1073741824,mode=1777'} and
            host.get('ShmSize') == 1048576, 'Scratch mismatch')
    require(host.get('LogConfig') == {'Type':'local','Config':{'max-size':'1m','max-file':'1','compress':'false'}},
            'Docker log configuration mismatch')
    actual = {(m['Source'],m['Destination'],m['RW'],m['Type']) for m in info['Mounts']}
    require(actual == {(str(src), dst, False, 'bind') for src,dst in mounts}, 'Extra or writable mount')
    require(config.get('User') == uidgid and config.get('Entrypoint') == ['/usr/local/bin/python3.12'],
            'Worker entrypoint/user mismatch')
    expected_cmd=['-I','-B','/source/tests/human_subtile/cloud_npc_smoke.py','--head',head,
                  '--byond-bin','/opt/byond/bin','--byond-archive','/inputs/byond.zip',
                  '--scratch-root','/work','--reviewed-cloud-envelope']
    if suite != 'smoke': expected_cmd += ['--suite',suite]
    if suite in ('random05','random10','cardinal05','cardinal10'):
        require(isinstance(work_deadline,float) and work_deadline>0, 'Missing random work deadline')
        expected_cmd += ['--work-deadline',str(work_deadline)]
    require(config.get('Cmd') == expected_cmd, 'Worker command mismatch')
    env_names = [(item.split('=',1)[0]).upper() for item in (config.get('Env') or [])]
    require(not any(re.search(r'(GITHUB|GH_TOKEN|SECRET|CREDENTIAL|PASSWORD|API_KEY)', key) for key in env_names),
            'Unexpected credential-like worker environment')


class Docker:
    def __init__(self, config, end):
        self.config, self.end = config, end

    def call(self, args, timeout=10, maximum=MAX_CLI, optional=False):
        budget = min(timeout, self.end-time.monotonic())
        require(budget > 0, 'Controller deadline')
        command = ['docker','--host','unix:///var/run/docker.sock','--config',str(self.config),*args]
        env = {'PATH':'/usr/bin:/bin','HOME':str(self.config),'LANG':'C.UTF-8'}
        child = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                 stderr=subprocess.PIPE, env=env, start_new_session=True)
        sel = selectors.DefaultSelector()
        streams = {child.stdout:bytearray(), child.stderr:bytearray()}
        for stream in streams:
            sel.register(stream, selectors.EVENT_READ)
        end = time.monotonic()+budget
        try:
            while sel.get_map():
                require(time.monotonic() < end, 'Docker CLI timeout')
                for key,_ in sel.select(min(.1, max(0,end-time.monotonic()))):
                    data = os.read(key.fd, 65536)
                    if data:
                        streams[key.fileobj].extend(data)
                        require(sum(map(len,streams.values())) <= maximum, 'Docker CLI output limit')
                    else:
                        sel.unregister(key.fileobj)
            remaining = max(0, end-time.monotonic())
            child.wait(timeout=remaining)
        finally:
            sel.close()
            if child.poll() is None:
                try: os.killpg(child.pid, signal.SIGKILL)
                except ProcessLookupError: pass
                child.wait(timeout=3)
            child.stdout.close(); child.stderr.close()
        out,err = bytes(streams[child.stdout]),bytes(streams[child.stderr])
        require(optional or child.returncode == 0, 'Docker command failed: ' + args[0] + ' rc=' + str(child.returncode))
        return child.returncode,out,err


def inspect(docker, target, optional=False):
    rc,out,err = docker.call(['inspect',target],timeout=2,optional=optional)
    return None if rc else json.loads(out)[0]


def absent(docker, cid):
    rc,out,_ = docker.call(['container','ls','-a','--filter','id='+cid,'--format','{{.ID}}'],timeout=2)
    require(rc == 0 and not out.strip(), 'Container still present or absence uncertain')


def retire(docker,cid,name,owner,head,log_path=None):
    info = inspect(docker,cid,optional=True)
    if info is None:
        absent(docker,cid)
        return {'absent':True,'already_absent':True}
    inspect_owned(info,cid,name,owner,head)
    before = {k:info['State'].get(k) for k in ('Status','Running','Pid','ExitCode','OOMKilled','Error')}
    if info['State']['Running']:
        docker.call(['kill',cid],timeout=5)
        docker.call(['wait',cid],timeout=5)
    stopped = inspect(docker,cid)
    inspect_owned(stopped,cid,name,owner,head)
    require(not stopped['State']['Running'] and stopped['State']['Pid'] == 0, 'Owned container still running')
    after = {k:stopped['State'].get(k) for k in ('Status','ExitCode','OOMKilled','Error')}
    logs = None
    # Diagnostics are optional and only after containment. Preserve time for
    # rm and absence verification even if the daemon is slow.
    if log_path and docker.end-time.monotonic() > 12:
        try: logs=save_container_logs(docker,cid,log_path,timeout=3)
        except BaseException as exc: logs={'error':type(exc).__name__}
    docker.call(['rm',cid],timeout=5)
    absent(docker,cid)
    return {'absent':True,'before':before,'after':after,'logs':logs}


def validate_package(data, expected, suite='smoke'):
    require(len(data) == expected['bytes'] <= MAX_PACKAGE and hashlib.sha256(data).hexdigest() == expected['sha256'],
            'Evidence package identity mismatch')
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:') as inner:
        entries=inner.getmembers()
        allowed={'harness-status.json', 'smoke-summary.json', 'npc-smoke/cloud-manifest.json',
                 'npc-smoke/npc-manifest.json', 'npc-smoke/stage/compile-stdout.log',
                 'npc-smoke/stage/compile-stderr.log',
                 'npc-smoke/geometry-stage/manifest.json', 'npc-smoke/geometry-stage/compile-stdout.log',
                 'npc-smoke/geometry-stage/compile-stderr.log', 'production/source-compact.json',
                 'production/stage/compile-stdout.log', 'production/stage/compile-stderr.log'}
        allowed.update(f'npc-smoke/{suite}/{name}' for suite in ('runtime','runtime-wildlife')
                       for name in ('receipt.json','result.txt','port-closed.txt','runtime.log',
                                    'daemon-stdout.log','daemon-stderr.log','npc-receipt.json'))
        allowed.update(f'abi/abi-{index}-{part}.log' for index in range(6) for part in ('stdout','stderr'))
        allowed.update('npc-smoke/geometry/'+name for name in ('receipt.json','result.txt','port-closed.txt',
            'runtime.log','daemon-stdout.log','daemon-stderr.log'))
        limit = 32
        if suite in ('random05', 'random10'):
            # These are the only files the three-mode random worker can emit:
            # one candidate runtime and two separate parent runtimes.
            allowed = {'harness-status.json', 'smoke-summary.json'}
            allowed.update(f'{prefix}/{name}' for prefix in ('npc-smoke', 'npc-parent')
                           for name in ('cloud-manifest.json', 'stage/compile-stdout.log', 'stage/compile-stderr.log'))
            allowed.update(f'{prefix}/{runtime}/{name}'
                           for prefix, runtime in (('npc-smoke', 'runtime'), ('npc-parent', 'runtime'),
                                                   ('npc-parent', 'runtime-wildlife'))
                           for name in ('receipt.json', 'result.txt', 'port-closed.txt', 'runtime.log',
                                        'daemon-stdout.log', 'daemon-stderr.log'))
            allowed.update(f'abi/abi-{index}-{part}.log' for index in range(6) for part in ('stdout', 'stderr'))
            limit = len(allowed)  # 38; fixed names, with no additional evidence classes.
        elif suite in ('cardinal05', 'cardinal10'):
            allowed = {'harness-status.json', 'smoke-summary.json', 'npc-smoke/cloud-manifest.json',
                       'npc-smoke/stage/compile-stdout.log', 'npc-smoke/stage/compile-stderr.log'}
            allowed.update(f'npc-smoke/{runtime}/{name}' for runtime in ('runtime', 'runtime-wildlife')
                           for name in ('receipt.json','result.txt','port-closed.txt','runtime.log',
                                        'daemon-stdout.log','daemon-stderr.log'))
            allowed.update(f'abi/abi-{index}-{part}.log' for index in range(6) for part in ('stdout','stderr'))
            limit = len(allowed)  # Exact 29-file maximum; failed phases may omit files.
        require(len(entries) <= limit and all(x.isfile() and not x.name.startswith('/') and
                '..' not in Path(x.name).parts and x.name in allowed and x.size <= 4*1024**2 for x in entries)
                and sum(x.size for x in entries) <= MAX_PACKAGE, 'Unsafe evidence archive')
        names=[x.name for x in entries]
        require(len(set(names))==len(names) and 'harness-status.json' in names, 'Missing/duplicate evidence')
    return data


def package_from_logs(log, marker, suite='smoke'):
    """Reject partial, reordered, duplicated or oversized log-carried evidence."""
    package = marker.get('package') or {}
    count = package.get('parts')
    require(type(count) is int and 0 < count <= 54 and type(package.get('compressed_bytes')) is int and
            0 < package['compressed_bytes'] <= MAX_LOG_PACKAGE and type(package.get('complete')) is bool and
            package.get('compression') == 'xz',
            'Invalid log package metadata')
    chunks = []
    for line in log.splitlines():
        if line.startswith(b'HARNESS_EVIDENCE_PART '):
            match = re.fullmatch(rb'HARNESS_EVIDENCE_PART ([0-9]+)/([0-9]+) ([A-Za-z0-9+/=]+)', line)
            require(match is not None and int(match.group(1)) == len(chunks)+1 and
                    int(match.group(2)) == count and len(match.group(3)) <= 8192, 'Invalid evidence part')
            chunks.append(match.group(3))
    require(len(chunks) == count, 'Missing evidence parts')
    compressed = base64.b64decode(b''.join(chunks), validate=True)
    require(len(compressed) == package['compressed_bytes'], 'Compressed evidence size mismatch')
    decoder = lzma.LZMADecompressor(format=lzma.FORMAT_XZ, memlimit=64*1024**2)
    data = decoder.decompress(compressed, max_length=MAX_PACKAGE+1)
    require(decoder.eof and not decoder.unused_data and len(data) <= MAX_PACKAGE,
            'Incomplete, oversized or trailing compressed evidence')
    return validate_package(data, package, suite)


def validate_resource_states(summary, status, labels=('vendor','wildlife')):
    artifacts = summary.get('artifacts') or {}
    initial = artifacts.get('human_subtile.rsc') or {}
    states = summary.get('resource_states')
    require(isinstance(states, dict) and set(states) == set(labels) and
            status.get('resource_copies_independent') is True and status.get('runtime_resources') == states,
            'Missing or mismatched resource receipts')
    def valid(observation):
        return (isinstance(observation, dict) and type(observation.get('bytes')) is int and
                0 < observation['bytes'] <= 1024**3 and
                re.fullmatch('[0-9a-f]{64}', observation.get('sha256') or '') and
                type(observation.get('mode')) is int and observation['mode'] == 0o600)
    require(valid(initial), 'Invalid initial resource identity')
    for label in labels:
        state = states[label]
        require(isinstance(state, dict) and valid(state.get('before')) and valid(state.get('after')) and
                state['before'] == initial and type(state.get('changed')) is bool and
                state['changed'] == (state['before'] != state['after']) and
                state.get('integrity_verified') is True and 'daemon_error' not in state and
                'integrity_error' not in state, 'Invalid runtime resource receipt: ' + label)


def validate_pass_evidence(data, head):
    """Revalidate successful receipts on the host; never infer pass from a marker."""
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:') as archive:
        def read(name):
            row=archive.getmember(name)
            require(row.isfile() and row.size <= 4*1024**2, 'Invalid receipt member')
            return archive.extractfile(row).read()
        status=json.loads(read('harness-status.json'))
        summary=json.loads(read('smoke-summary.json'))
        require(status.get('head') == head and status.get('outcome') == 'passed' and
                status.get('phase') == 'complete' and status.get('fixture_dme_only') is True,
                'Harness status does not establish fixture pass')
        require(summary.get('head') == head and summary.get('accepted') is True,
                'Summary does not match exact head')
        validate_resource_states(summary, status)
        for suite in ('runtime','runtime-wildlife'):
            require(read('npc-smoke/'+suite+'/result.txt') == b'PASS\n' and
                    read('npc-smoke/'+suite+'/port-closed.txt') == b'closed\n', 'Bad suite markers')
        vendor=json.loads(read('npc-smoke/runtime/receipt.json'))
        wildlife=json.loads(read('npc-smoke/runtime-wildlife/receipt.json'))
        spec=importlib.util.spec_from_file_location('reviewed_cloud_npc_oracle', Path(__file__).with_name('run-npc.py'))
        npc=importlib.util.module_from_spec(spec); spec.loader.exec_module(npc)
        npc.validate_npc_receipt(vendor,head)
        require(vendor.get('cloud_wildlife_checks') == 0 and vendor.get('scope') ==
                'vendor AI pulses and owned-offset codec; no wildlife acceptance', 'Vendor scope mismatch')
        require(wildlife.get('head') == head and wildlife.get('error') is None and wildlife.get('port') == 0 and
                (wildlife.get('byond_version'),wildlife.get('byond_build')) == (516,1688) and
                wildlife.get('cloud_wildlife_checks') == 9 and wildlife.get('npc_checks') == 0 and
                wildlife.get('scope') == 'wildlife owner/contact helper only; no Life/bite acceptance',
                'Wildlife receipt mismatch')
        log=(read('npc-smoke/stage/compile-stdout.log') + read('npc-smoke/stage/compile-stderr.log')).decode(errors='replace')
        npc.current.legacy.validate_compile(log, 'human_subtile.dmb')


def validate_extended_evidence(data, head):
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:') as archive:
        def read(name):
            item=archive.getmember(name)
            require(item.isfile() and item.size <= 4*1024**2, 'Invalid extended evidence member')
            return archive.extractfile(item).read()
        status=json.loads(read('harness-status.json')); summary=json.loads(read('smoke-summary.json'))
        require(status.get('head') == head and status.get('outcome') == 'passed' and status.get('phase') == 'complete' and
                status.get('fixture_dme_only') is True and status.get('suite') == 'extended' and
                status.get('resource_copies_independent') is True and summary.get('head') == head and
                summary.get('accepted') is True and summary.get('suite') == 'extended' and
                summary.get('fixture_dme_only') is True, 'Invalid extended status')
        states=summary.get('resource_states')
        require(isinstance(states,dict) and set(states)=={'extended'} and status.get('runtime_resources')==states,
                'Missing extended resource state')
        state=states['extended']; initial=summary.get('artifacts',{}).get('human_subtile.rsc',{})
        before=state.get('before',{});after=state.get('after',{})
        require(before==initial and state.get('integrity_verified') is True and 'daemon_error' not in state and
                'integrity_error' not in state and type(state.get('changed')) is bool and state['changed']==(before!=after),
                'Invalid extended resource integrity')
        for item in (before,after):
            require(type(item.get('bytes')) is int and 0 < item['bytes'] <= 1024**3 and item.get('mode') == 0o600 and
                    re.fullmatch('[0-9a-f]{64}',item.get('sha256') or ''), 'Invalid extended resource identity')
        spec=importlib.util.spec_from_file_location('extended_receipts',Path(__file__).with_name('cloud_wildlife_extended.py'))
        ext=importlib.util.module_from_spec(spec);spec.loader.exec_module(ext)
        spec2=importlib.util.spec_from_file_location('extended_npc',Path(__file__).with_name('run-npc.py'))
        npc=importlib.util.module_from_spec(spec2);spec2.loader.exec_module(npc)
        for label,folder,validator in (('extended','runtime',ext.validate_extended),('geometry','geometry',ext.validate_geometry)):
            prefix='npc-smoke/'+folder+'/'
            require(read(prefix+'result.txt') == b'PASS\n' and read(prefix+'port-closed.txt') == b'closed\n', 'Invalid extended result')
            raw=read(prefix+'receipt.json');validator(json.loads(raw),head)
            require(summary.get('results',{}).get(label,{}).get('receipt_sha256') == hashlib.sha256(raw).hexdigest(),
                    'Extended receipt hash mismatch')
        for folder,artifact in (('stage','human_subtile.dmb'),('geometry-stage','large_geometry.dmb')):
            prefix='npc-smoke/'+folder+'/compile-'
            npc.current.legacy.validate_compile((read(prefix+'stdout.log')+read(prefix+'stderr.log')).decode(errors='replace'),artifact)
        for name in ('npc-smoke/cloud-manifest.json','npc-smoke/geometry-stage/manifest.json'):
            require(json.loads(read(name)).get('head') == head, 'Extended manifest head mismatch')


def validate_bridge_evidence(data, head):
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:') as archive:
        def read(name):
            item=archive.getmember(name)
            require(item.isfile() and item.size <= 4*1024**2, 'Invalid bridge evidence member')
            return archive.extractfile(item).read()
        status=json.loads(read('harness-status.json')); summary=json.loads(read('smoke-summary.json'))
        require(status.get('head') == head and status.get('outcome') == 'passed' and status.get('phase') == 'complete' and
                status.get('fixture_dme_only') is True and status.get('suite') == 'bridge' and
                status.get('resource_copies_independent') is True and summary.get('head') == head and
                summary.get('accepted') is True and summary.get('suite') == 'bridge' and
                summary.get('fixture_dme_only') is True, 'Invalid bridge status')
        states=summary.get('resource_states')
        require(isinstance(states,dict) and set(states)=={'bridge'} and status.get('runtime_resources')==states,
                'Missing bridge resource state')
        state=states['bridge']; initial=summary.get('artifacts',{}).get('human_subtile.rsc',{})
        before=state.get('before',{}); after=state.get('after',{})
        require(before==initial and state.get('integrity_verified') is True and 'daemon_error' not in state and
                'integrity_error' not in state and type(state.get('changed')) is bool and state['changed']==(before!=after),
                'Invalid bridge resource integrity')
        for item in (before,after):
            require(type(item.get('bytes')) is int and 0 < item['bytes'] <= 1024**3 and item.get('mode') == 0o600 and
                    re.fullmatch('[0-9a-f]{64}',item.get('sha256') or ''), 'Invalid bridge resource identity')
        spec=importlib.util.spec_from_file_location('bridge_receipts',Path(__file__).with_name('cloud_wildlife_bridge.py'))
        bridge=importlib.util.module_from_spec(spec);spec.loader.exec_module(bridge)
        spec2=importlib.util.spec_from_file_location('bridge_npc',Path(__file__).with_name('run-npc.py'))
        npc=importlib.util.module_from_spec(spec2);spec2.loader.exec_module(npc)
        prefix='npc-smoke/runtime/'
        require(read(prefix+'result.txt') == b'PASS\n' and read(prefix+'port-closed.txt') == b'closed\n', 'Invalid bridge result')
        raw=read(prefix+'receipt.json'); bridge.validate_bridge(json.loads(raw),head)
        require(summary.get('results',{}).get('bridge',{}).get('receipt_sha256') == hashlib.sha256(raw).hexdigest(),
                'Bridge receipt hash mismatch')
        compile_prefix='npc-smoke/stage/compile-'
        npc.current.legacy.validate_compile((read(compile_prefix+'stdout.log')+read(compile_prefix+'stderr.log')).decode(errors='replace'),'human_subtile.dmb')
        require(json.loads(read('npc-smoke/cloud-manifest.json')).get('head') == head, 'Bridge manifest head mismatch')


def validate_scheduler_evidence(data,head):
    """Independently compare both retained insect receipts on the host."""
    with tarfile.open(fileobj=io.BytesIO(data),mode='r:') as archive:
        def read(name):
            item=archive.getmember(name)
            require(item.isfile() and item.size<=4*1024**2,'Invalid scheduler evidence member')
            return archive.extractfile(item).read()
        status=json.loads(read('harness-status.json'));summary=json.loads(read('smoke-summary.json'))
        require(status.get('head')==head and status.get('outcome')=='passed' and status.get('phase')=='complete' and
                status.get('fixture_dme_only') is True and status.get('suite')=='scheduler' and
                summary.get('head')==head and summary.get('accepted') is True and summary.get('suite')=='scheduler' and
                summary.get('fixture_dme_only') is True,'Invalid scheduler status')
        validate_resource_states(summary,status,('legacy','smooth'))
        spec=importlib.util.spec_from_file_location('scheduler_receipts',Path(__file__).with_name('cloud_wildlife_scheduler_draft.py'))
        scheduler=importlib.util.module_from_spec(spec);spec.loader.exec_module(scheduler)
        spec2=importlib.util.spec_from_file_location('scheduler_npc',Path(__file__).with_name('run-npc.py'))
        npc=importlib.util.module_from_spec(spec2);spec2.loader.exec_module(npc)
        receipts={}
        for label,folder in (('legacy','runtime'),('smooth','runtime-wildlife')):
            prefix='npc-smoke/'+folder+'/'
            phase=summary.get('results',{}).get(label,{}).get('daemon',{})
            require(phase.get('returncode')==0 and phase.get('timed_out') is False and
                    phase.get('oversized_log') is False and phase.get('deadline')==90,
                    'Scheduler daemon phase is not bounded and successful: '+label)
            require(read(prefix+'result.txt')==b'PASS\n' and read(prefix+'port-closed.txt')==b'closed\n',
                    'Scheduler daemon did not complete: '+label)
            raw=read(prefix+'receipt.json');receipts[label]=json.loads(raw)
            require(summary.get('results',{}).get(label,{}).get('receipt_sha256')==hashlib.sha256(raw).hexdigest(),
                    'Scheduler receipt hash mismatch: '+label)
        require(summary.get('scope')==scheduler.SCOPE and
                scheduler.compare_pair(receipts['legacy'],receipts['smooth'],head)==summary.get('comparison'),
                'Scheduler pair comparison mismatch')
        compile_prefix='npc-smoke/stage/compile-'
        phase=summary.get('compile',{})
        require(phase.get('returncode')==0 and phase.get('timed_out') is False and
                phase.get('oversized_log') is False and phase.get('deadline')==120,
                'Scheduler compiler phase is not bounded and successful')
        npc.current.legacy.validate_compile((read(compile_prefix+'stdout.log')+read(compile_prefix+'stderr.log')).decode(errors='replace'),'human_subtile.dmb')
        manifest=json.loads(read('npc-smoke/cloud-manifest.json'))
        require(manifest.get('head')==head and manifest.get('scheduler_scope')==scheduler.SCOPE,'Scheduler manifest mismatch')


def validate_random_evidence(data,head,suite,git,git_env):
    """Independently recheck all three raw receipts; never assert parity."""
    spec=importlib.util.spec_from_file_location('random_receipts',Path(__file__).with_name('random_cadence_contract.py'))
    contract=importlib.util.module_from_spec(spec);spec.loader.exec_module(contract)
    tick=contract.selection(suite)
    require(subprocess.check_output(git+['rev-parse',contract.HANDOFF_BASE+'^{tree}'],env=git_env,timeout=10).decode().strip()
            ==contract.HANDOFF_BASE_TREE,'Handoff baseline tree mismatch')
    require(subprocess.run(git+['merge-base','--is-ancestor',contract.HANDOFF_BASE,head],env=git_env,
                           capture_output=True,timeout=10).returncode==0,'Handoff baseline is not an ancestor')
    changed=set(subprocess.check_output(git+['diff','--name-only',contract.HANDOFF_BASE,head],
                                        env=git_env,timeout=30).decode().splitlines())
    require(changed==contract.HANDOFF_FILES,
            'Unexpected reviewed comparison source diff')
    for revision,items in ((contract.HANDOFF_BASE,{**contract.CANDIDATE_BLOBS,contract.MOVEMENT:contract.PARENT_MOVEMENT_BLOB}),
                           (head,{**contract.CANDIDATE_BLOBS,contract.CANDIDATE_TEST:contract.CANDIDATE_TEST_BLOB,
                                  contract.MOVEMENT:contract.CANDIDATE_MOVEMENT_BLOB,
                                  contract.PARENT_FIXTURE:contract.PARENT_MOVEMENT_BLOB})):
        for path,blob in items.items():
            require(subprocess.check_output(git+['rev-parse',revision+':'+path],env=git_env,timeout=10).decode().strip()==blob,
                    'Variant blob mismatch: '+path)
    with tarfile.open(fileobj=io.BytesIO(data),mode='r:') as archive:
        members=archive.getmembers();names=[item.name for item in members]
        require(len(names)==len(set(names)) and sum(item.size for item in members)<=16*1024**2 and
                all(item.isfile() and not PurePosixPath(item.name).is_absolute() and
                    '..' not in PurePosixPath(item.name).parts for item in members),'Unsafe random evidence archive')
        def read(name):
            item=archive.getmember(name)
            require(item.isfile() and item.size<=4*1024**2,'Invalid random evidence member')
            return archive.extractfile(item).read()
        status=json.loads(read('harness-status.json'));summary=json.loads(read('smoke-summary.json'))
        require(status.get('head')==head and status.get('suite')==suite and status.get('outcome')=='passed' and
                status.get('phase')=='complete' and status.get('fixture_dme_only') is True and
                summary.get('head')==head and summary.get('suite')==suite and summary.get('tick')==tick and
                summary.get('fixture_dme_only') is True and summary.get('observation_complete') is True and
                summary.get('parity_established') is False and summary.get('scope')==contract.SCOPE and
                summary.get('budget')==contract.budget(),
                'Invalid random observation status')
        states=summary.get('resource_states');artifacts=summary.get('artifacts')
        require(isinstance(states,dict) and set(states)==set(contract.MODES) and status.get('runtime_resources')==states and
                isinstance(artifacts,dict) and set(artifacts)=={'parent','candidate'},'Missing random resource states')
        for mode in contract.MODES:
            source='candidate' if mode=='candidate' else 'parent';state=states[mode]
            initial=artifacts[source].get('human_subtile.rsc',{})
            before=state.get('before',{});after=state.get('after',{})
            require(before==initial and state.get('integrity_verified') is True and 'daemon_error' not in state and
                    'integrity_error' not in state and type(state.get('changed')) is bool and state['changed']==(before!=after),
                    'Random resource state mismatch: '+mode)
            for item in (before,after):
                require(type(item.get('bytes')) is int and 0<item['bytes']<=1024**3 and item.get('mode')==0o600 and
                        re.fullmatch('[0-9a-f]{64}',item.get('sha256') or ''),'Invalid random resource identity')
        spec2=importlib.util.spec_from_file_location('random_npc',Path(__file__).with_name('run-npc.py'))
        npc=importlib.util.module_from_spec(spec2);spec2.loader.exec_module(npc)
        manifests={};source_blobs={}
        for label,folder in (('parent','npc-parent'),('candidate','npc-smoke')):
            m=json.loads(read(folder+'/cloud-manifest.json'));manifests[label]=m
            require(m.get('head')==head and m.get('random_source_variant')==label and m.get('random_scope')==contract.SCOPE and
                    m.get('parent_commit')==contract.HANDOFF_BASE and
                    m.get('candidate_local_commit')==contract.LOCAL_CANDIDATE and
                    m.get('candidate_blobs')==contract.CANDIDATE_BLOBS and
                    m.get('movement_blobs')=={'parent':contract.PARENT_MOVEMENT_BLOB,'candidate':contract.CANDIDATE_MOVEMENT_BLOB},
                    'Random source manifest')
            revision=contract.HANDOFF_BASE if label=='parent' else head
            source_blobs[label]={p:subprocess.check_output(git+['show',revision+':'+p],env=git_env,timeout=10)
                                 for p in (*contract.SPECIES,contract.MOVEMENT)}
            expected={p:hashlib.sha256(raw).hexdigest() for p,raw in source_blobs[label].items()}
            require(m.get('paired_preimages')==expected,'Source preimages do not match Git objects')
            for path,raw in source_blobs[label].items():
                adapted=(contract.movement_fixture_bytes(raw,label) if path==contract.MOVEMENT
                         else contract.species_fixture_bytes(path,raw))
                require(m.get('stage_files',{}).get(path)=={'bytes':len(adapted),'sha256':hashlib.sha256(adapted).hexdigest()},
                        'Adapted species differs from verified Git source')
            phase=summary.get('compiles',{}).get(label,{})
            require(phase.get('returncode')==0 and phase.get('timed_out') is False and
                    phase.get('oversized_log') is False and phase.get('deadline')==contract.COMPILE_SECONDS,
                    'Unbounded or failed random compile')
            log=(read(folder+'/stage/compile-stdout.log')+read(folder+'/stage/compile-stderr.log')).decode(errors='replace')
            npc.current.legacy.validate_compile(log,'human_subtile.dmb')
        a=manifests['parent']['stage_files'];b=manifests['candidate']['stage_files']
        require(set(a)==set(b) and {k for k in a if a[k]!=b[k]}=={contract.MOVEMENT},
                'Paired adapted sources differ outside reviewed movement handoff')
        require(all(source_blobs['candidate'][p]==source_blobs['parent'][p] and
                    source_blobs['candidate'][p].count(contract.RANDOM_OVERRIDE)==1 for p in contract.SPECIES),
                'Species period policy differs between variants')
        receipts={}
        for mode,prefix in (('legacy','npc-parent/runtime/'),('parent','npc-parent/runtime-wildlife/'),
                            ('candidate','npc-smoke/runtime/')):
            phase=summary.get('results',{}).get(mode,{}).get('daemon',{})
            require(phase.get('returncode')==0 and phase.get('timed_out') is False and
                    phase.get('oversized_log') is False and phase.get('deadline')==contract.DAEMON_SECONDS,
                    'Unbounded or failed random daemon: '+mode)
            require(read(prefix+'result.txt')==b'PASS\n' and read(prefix+'port-closed.txt')==b'closed\n',
                    'Random daemon result/port failure')
            raw=read(prefix+'receipt.json');receipts[mode]=json.loads(raw)
            require(summary['results'][mode].get('receipt_sha256')==hashlib.sha256(raw).hexdigest(),
                    'Random receipt hash mismatch')
        phase_seconds=[summary['compiles'][name].get('seconds') for name in ('parent','candidate')]
        phase_seconds += [summary['results'][name]['daemon'].get('seconds') for name in contract.MODES]
        require(all(contract.finite(s) and 0<=s<=limit for s,limit in zip(phase_seconds,
                (contract.COMPILE_SECONDS,contract.COMPILE_SECONDS,contract.DAEMON_SECONDS,
                 contract.DAEMON_SECONDS,contract.DAEMON_SECONDS))) and
                contract.finite(summary.get('child_elapsed')) and
                abs(sum(phase_seconds)-summary['child_elapsed']) < 0.000001 and
                contract.setup_used(summary.get('comparison_elapsed'),summary['child_elapsed'])==summary.get('setup_seconds'),
                'Invalid random elapsed budget')
        require(contract.compare(receipts,head,tick)==summary.get('comparison'), 'Random comparison mismatch')


def validate_production_evidence(data,head,expected_tree,expected_inventory):
    with tarfile.open(fileobj=io.BytesIO(data),mode='r:') as archive:
        def read(name):
            item=archive.getmember(name)
            require(item.isfile() and item.size <= 4*1024**2, 'Invalid production evidence member')
            return archive.extractfile(item).read()
        status=json.loads(read('harness-status.json'));summary=json.loads(read('smoke-summary.json'))
        compact=json.loads(read('production/source-compact.json'))
        spec=importlib.util.spec_from_file_location('production_stage',Path(__file__).with_name('cloud_production_compile.py'))
        production=importlib.util.module_from_spec(spec);spec.loader.exec_module(production)
        manifest=production.restore_manifest(compact,expected_inventory,head,expected_tree)
        manifest_raw=(json.dumps(manifest,indent=2)+'\n').encode()
        require(status.get('head')==head and status.get('outcome')=='passed' and status.get('phase')=='complete' and
                status.get('suite')=='production_compile' and status.get('fixture_dme_only') is False and
                summary.get('head')==head and summary.get('accepted') is True and summary.get('suite')=='production_compile' and
                summary.get('fixture_dme_only') is False and summary.get('scope') ==
                'unmodified full tracked production DME compile only; no daemon or game acceptance', 'Invalid production compile status')
        files=manifest.get('files')
        require(manifest.get('head')==head and manifest.get('source_unmodified') is True and manifest.get('dme')=='civ13.dme' and
                isinstance(files,dict) and 0 < len(files) <= 8000 and 'civ13.dme' in files and
                summary.get('tree') == manifest.get('tree') == expected_tree and re.fullmatch('[0-9a-f]{40}',manifest.get('tree') or '') and
                summary.get('source_file_count')==len(files) and summary.get('source_bytes')==manifest.get('bytes') and
                summary.get('source_manifest_sha256')==hashlib.sha256(manifest_raw).hexdigest(), 'Invalid production source manifest')
        total=0
        for name,item in files.items():
            require(isinstance(name,str) and name and not name.startswith('/') and '..' not in Path(name).parts and
                    isinstance(item,dict) and type(item.get('bytes')) is int and 0 <= item['bytes'] <= 256*1024**2 and
                    re.fullmatch('[0-9a-f]{64}',item.get('sha256') or '') and re.fullmatch('[0-9a-f]{40}',item.get('git_blob') or ''),
                    'Invalid production source identity')
            total+=item['bytes']
        require(total==manifest['bytes'] and total<=1024**3,'Invalid production source total')
        phase=summary.get('compile',{})
        require(phase.get('returncode') == 0 and phase.get('timed_out') is False and
                phase.get('oversized_log') is False and phase.get('deadline') == 120,
                'Invalid production compiler phase')
        for name in ('civ13.dmb','civ13.rsc'):
            item=summary.get('artifacts',{}).get(name,{})
            require(type(item.get('bytes')) is int and 0 < item['bytes'] <= 1024**3 and
                    re.fullmatch('[0-9a-f]{64}',item.get('sha256') or ''),'Missing production compile artifact identity')
        spec=importlib.util.spec_from_file_location('production_npc',Path(__file__).with_name('run-npc.py'))
        npc=importlib.util.module_from_spec(spec);spec.loader.exec_module(npc)
        npc.current.legacy.validate_compile((read('production/stage/compile-stdout.log')+
                                             read('production/stage/compile-stderr.log')).decode(errors='replace'),'civ13.dmb')


def save(path, report):
    data=(json.dumps(report,indent=2,sort_keys=True)+'\n').encode()
    require(len(data) <= 65536, 'Controller receipt bound')
    tmp=path.with_suffix('.tmp'); tmp.write_bytes(data); os.replace(tmp,path)


def save_container_logs(docker, cid, path, timeout=3):
    _,stdout,stderr=docker.call(['logs',cid],timeout=timeout)
    data=stdout+b'\n'+stderr
    path.write_bytes(data[-1024**2:])
    return {'bytes':min(len(data),1024**2),'truncated':len(data)>1024**2}


def create_args(name,owner,head,source,binary,archive,uidgid,suite='smoke',work_deadline=None):
    args = ['create','--name',name,'--platform','linux/386','--pull','never',
        '--label','scope='+SCOPE,'--label','owner='+owner,'--label','head='+head,
        '--network','none','--read-only','--user',uidgid,'--cap-drop','ALL',
        '--security-opt','no-new-privileges','--pids-limit','64','--memory','3g',
        '--memory-swap','3g','--cpus','2','--cgroupns','private','--ipc','private',
        '--shm-size','1048576','--tmpfs','/work:rw,noexec,nosuid,nodev,size=1073741824,mode=1777',
        '--mount',f'type=bind,src={source},dst=/source,readonly',
        '--mount',f'type=bind,src={binary},dst=/opt/byond/bin,readonly',
        '--mount',f'type=bind,src={archive},dst=/inputs/byond.zip,readonly',
        '--workdir','/source','--restart','no','--stop-timeout','1','--no-healthcheck',
        '--log-driver','local','--log-opt','max-size=1m','--log-opt','max-file=1','--log-opt','compress=false',
        '--entrypoint','/usr/local/bin/python3.12',IMAGE,'-I','-B','/source/tests/human_subtile/cloud_npc_smoke.py',
        '--head',head,'--byond-bin','/opt/byond/bin','--byond-archive','/inputs/byond.zip',
        '--scratch-root','/work','--reviewed-cloud-envelope']
    if suite != 'smoke': args += ['--suite',suite]
    if suite in ('random05','random10','cardinal05','cardinal10'):
        require(isinstance(work_deadline,float) and work_deadline>0, 'Missing random work deadline')
        args += ['--work-deadline',str(work_deadline)]
    return args


def absent_name(docker, name):
    _,out,_=docker.call(['container','ls','-a','--filter','name='+name,'--format','{{.Names}}'],timeout=2)
    require(name not in out.decode(errors='replace').splitlines(), 'Owned container name still present')


def watchdog(docker,cid,name,owner,head,deadline,receipt):
    delay=max(0,deadline-time.monotonic()-60)
    time.sleep(delay)
    report={'watchdog':True,'head':head,'cid':cid,'timeout':True}
    try:
        if not cid:
            info=inspect(docker,name,optional=True)
            if info is not None:
                cid=info.get('Id'); inspect_owned(info,cid,name,owner,head)
                report['cid']=cid
        if cid:
            report['cleanup']=retire(docker,cid,name,owner,head,log_path=receipt.with_name('watchdog-tail.log'))
        else:
            absent_name(docker,name)
            report['cleanup']={'absent':True,'never_created':True}
    except BaseException as exc:
        report['cleanup_error']=type(exc).__name__ + ': ' + str(exc)[:512]
    save(receipt,report)
    print('WATCHDOG_RECEIPT '+json.dumps(report,sort_keys=True),flush=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute',action='store_true')
    parser.add_argument('--head',required=True)
    parser.add_argument('--source',required=True,type=Path)
    parser.add_argument('--byond-bin',required=True,type=Path)
    parser.add_argument('--byond-archive',required=True,type=Path)
    parser.add_argument('--output',required=True,type=Path)
    parser.add_argument('--watchdog',action='store_true',help=argparse.SUPPRESS)
    parser.add_argument('--cid',help=argparse.SUPPRESS)
    parser.add_argument('--name',help=argparse.SUPPRESS)
    parser.add_argument('--owner',help=argparse.SUPPRESS)
    parser.add_argument('--deadline',type=float,help=argparse.SUPPRESS)
    parser.add_argument('--suite',choices=('random05','random10','cardinal05','cardinal10'),required=True)
    args=parser.parse_args()
    started=time.monotonic()
    require(args.execute, 'Execution requires explicit --execute')
    hosted(os.environ,args.head)
    source,binary,archive,out=(args.source.resolve(),args.byond_bin.resolve(),args.byond_archive.resolve(),args.output.resolve())
    require(out.parent == Path(os.environ['RUNNER_TEMP']).resolve(), 'Output must be direct child of runner temp')
    if args.watchdog:
        require((not args.cid or CID.fullmatch(args.cid)) and OWNER.fullmatch(args.owner or '') and
                args.name == 'civ13-wildlife-'+args.owner and args.deadline is not None,
                'Invalid retained watchdog identity')
        require(out.is_dir(), 'Missing owned output')
        docker=Docker(out/'docker-config',args.deadline)
        watchdog(docker,args.cid,args.name,args.owner,args.head,args.deadline,out/'watchdog.json')
        return
    require(not out.exists() and source.is_dir() and binary.is_dir() and archive.is_file(), 'Invalid source/output')
    git_env={'PATH':'/usr/bin:/bin','LANG':'C.UTF-8','HOME':'/nonexistent',
             'GIT_CONFIG_NOSYSTEM':'1','GIT_CONFIG_GLOBAL':'/dev/null',
             'GIT_TERMINAL_PROMPT':'0','GIT_OPTIONAL_LOCKS':'0'}
    git=['git','-c','core.fsmonitor=false','-c','core.hooksPath=/dev/null','-C',str(source)]
    head=subprocess.check_output(git+['rev-parse','HEAD'],timeout=10,env=git_env).decode().strip()
    require(head == args.head and not subprocess.check_output(git+['status','--porcelain=v1','--untracked-files=all'],timeout=30,env=git_env), 'Source differs from exact clean head')
    exact_tree=subprocess.check_output(git+['rev-parse',head+'^{tree}'],timeout=10,env=git_env).decode().strip()
    require(SHA.fullmatch(exact_tree),'Invalid exact Git tree')
    config_check=subprocess.run(git+['config','--local','--name-only','--get-regexp',r'(http\..*\.extraheader|credential\.)'],capture_output=True,timeout=10,env=git_env)
    require(config_check.returncode == 1 and not config_check.stdout, 'Credential config in checkout')
    require(archive.stat().st_size == 4887281 and hashlib.sha256(archive.read_bytes()).hexdigest() == '16278f318cdeb4b77c57868dd7135032fde717ea6226269d22b2a1a50968e7f9', 'Archive pin mismatch')
    owner=uuid.uuid4().hex; name='civ13-wildlife-'+owner
    owner_info=source.stat(); require(owner_info.st_uid != 0, 'Checkout owner must be unprivileged')
    uidgid=f'{owner_info.st_uid}:{owner_info.st_gid}'
    out.mkdir(); (out/'docker-config').mkdir()
    if args.deadline is not None:
        require(started < args.deadline <= started+MAX_SECONDS, 'Invalid shared outer deadline')
    deadline=min(started+MAX_SECONDS,args.deadline) if args.deadline is not None else started+MAX_SECONDS
    docker=Docker(out/'docker-config',deadline)
    report={'head':head,'owner':owner,'name':name,'complete':False,'scope':SCOPE,
            'fixture_dme_only':args.suite != 'production_compile','suite':args.suite}
    save(out/'controller.json',report)
    cid=None; watch=None; create_uncertain=False
    try:
        image=json.loads(docker.call(['image','inspect',IMAGE])[1])[0]
        digests=image.get('RepoDigests',[])
        accepted={'python@'+IMAGE.split('@',1)[1], 'library/python@'+IMAGE.split('@',1)[1], IMAGE}
        require(image['Os']=='linux' and image['Architecture']=='386' and
                any(d in accepted for d in digests) and re.fullmatch(r'sha256:[0-9a-f]{64}',image['Id']),
                'Pinned 386 image missing or identity mismatch')
        report['image_id']=image['Id']; save(out/'controller.json',report)
        # Start the identity-checking watchdog before create, so even an uncertain
        # create can be reconciled by its exact fresh name after controller death.
        env={k:v for k,v in os.environ.items() if k in ('GITHUB_ACTIONS','RUNNER_ENVIRONMENT','RUNNER_OS','RUNNER_ARCH',
            'GITHUB_REPOSITORY','GITHUB_REPOSITORY_ID','GITHUB_EVENT_NAME','CIV13_REPOSITORY_VISIBILITY','GITHUB_SHA','RUNNER_TEMP')}
        env.update(PATH='/usr/bin:/bin',LANG='C.UTF-8')
        watch=subprocess.Popen([sys.executable,'-I','-B',str(Path(__file__).resolve()),'--execute','--watchdog',
            '--head',head,'--source',str(source),'--byond-bin',str(binary),'--byond-archive',str(archive),
            '--output',str(out),'--name',name,'--owner',owner,'--deadline',str(deadline),'--suite',args.suite],
            env=env,stdin=subprocess.DEVNULL,start_new_session=True)
        try:
            create_uncertain=True
            config_args=(create_args(name,owner,head,source,binary,archive,uidgid,args.suite,
                         deadline-(MAX_SECONDS-WORK_SECONDS)) if args.suite in ('random05','random10','cardinal05','cardinal10') else
                         create_args(name,owner,head,source,binary,archive,uidgid,args.suite))
            value=docker.call(config_args,timeout=15)[1].decode().strip()
            require(CID.fullmatch(value), 'Bad created container ID'); cid=value; create_uncertain=False
        except BaseException:
            # Reconcile a possible completed create by this fresh name and labels.
            possible=inspect(docker,name,optional=True)
            if possible is not None:
                candidate=possible.get('Id'); inspect_owned(possible,candidate,name,owner,head); cid=candidate; create_uncertain=False
            raise
        report['cid']=cid; save(out/'controller.json',report)
        info=inspect(docker,cid); inspect_owned(info,cid,name,owner,head)
        mounts=((source,'/source'),(binary,'/opt/byond/bin'),(archive,'/inputs/byond.zip'))
        if args.suite in ('random05','random10','cardinal05','cardinal10'):
            inspect_settings(info,image['Id'],mounts,uidgid,head,args.suite,deadline-(MAX_SECONDS-WORK_SECONDS))
        else:
            inspect_settings(info,image['Id'],mounts,uidgid,head,args.suite)
        docker.call(['start',cid],timeout=10)
        marker=None
        while time.monotonic() < deadline-(MAX_SECONDS-WORK_SECONDS):
            info=inspect(docker,cid); inspect_owned(info,cid,name,owner,head)
            _,outlog,errlog=docker.call(['logs',cid],timeout=5)
            rows=[line for line in (outlog+b'\n'+errlog).decode(errors='replace').splitlines() if line.startswith('HARNESS_EVIDENCE_READY ')]
            require(len(rows)<=1, 'Duplicate evidence markers')
            if rows:
                marker=json.loads(rows[0].split(' ',1)[1]); break
            if not info['State']['Running']: break
            time.sleep(1)
        report['logs']=save_container_logs(docker,cid,out/'container-tail.log')
        if marker:
            package=marker.get('package') or {}
            require(type(package.get('bytes')) is int and re.fullmatch('[0-9a-f]{64}', package.get('sha256') or ''), 'Bad evidence marker')
            scratch=marker.get('scratch') or {}
            require(type(scratch.get('sampled_peak_bytes')) is int and 0 <= scratch['sampled_peak_bytes'] <= 1024**3 and
                    type(scratch.get('samples')) is int and scratch['samples'] > 0, 'Missing bounded scratch observation')
            report['scratch_observation']=scratch
            # Capture complete logs after the marker, including if PID 1 already exited.
            _,outlog,errlog=docker.call(['logs',cid],timeout=5)
            evidence=package_from_logs(outlog+b'\n'+errlog,marker,args.suite)
            (out/'harness-evidence.tar').write_bytes(evidence)
            report['evidence']={'bytes':len(evidence),'sha256':hashlib.sha256(evidence).hexdigest()}
            report['outcome']=marker.get('outcome')
            report['evidence_complete']=package['complete']
            if report['outcome'] == 'passed' and package['complete']:
                if args.suite == 'extended': validate_extended_evidence(evidence,head)
                elif args.suite == 'bridge': validate_bridge_evidence(evidence,head)
                elif args.suite == 'scheduler': validate_scheduler_evidence(evidence,head)
                elif args.suite in ('random05','random10'): validate_random_evidence(evidence,head,args.suite,git,git_env)
                elif args.suite in ('cardinal05','cardinal10'):
                    spec=importlib.util.spec_from_file_location('cardinal_evidence',Path(__file__).with_name('cardinal_evidence.py'))
                    cardinal=importlib.util.module_from_spec(spec);spec.loader.exec_module(cardinal)
                    cardinal.validate(evidence,head,args.suite,git,git_env)
                elif args.suite == 'production_compile':
                    spec=importlib.util.spec_from_file_location('production_stage',Path(__file__).with_name('cloud_production_compile.py'))
                    production=importlib.util.module_from_spec(spec);spec.loader.exec_module(production)
                    inventory,_=production.tree_inventory(subprocess.check_output(git+['ls-tree','-r','-l','-z',head],timeout=30,env=git_env))
                    validate_production_evidence(evidence,head,exact_tree,inventory)
                else: validate_pass_evidence(evidence,head)
                report['host_receipts_validated']=True
            wait_end=min(deadline-20,time.monotonic()+5)
            while time.monotonic() < wait_end:
                info=inspect(docker,cid); inspect_owned(info,cid,name,owner,head)
                if not info['State']['Running']: break
                time.sleep(.5)
            if info['State']['Running']:
                report['outcome']='incomplete-supervisor-did-not-exit'
        else:
            report['outcome']='incomplete-no-evidence-marker'
        report['terminal_state']={k:info['State'].get(k) for k in ('Status','Running','Pid','ExitCode','OOMKilled','Error')}
        if not marker and info['State']['Running']:
            report['timeout']=True
        save(out/'controller.json',report)
    except BaseException as exc:
        report['error']=type(exc).__name__ + ': ' + str(exc)[:512]
        if cid and deadline-time.monotonic() > 30:
            try: report['logs']=save_container_logs(docker,cid,out/'container-tail.log')
            except BaseException as log_error: report['logs_error']=type(log_error).__name__
        save(out/'controller.json',report)
    finally:
        try:
            if not cid:
                possible=inspect(docker,name,optional=True)
                if possible is not None:
                    candidate=possible.get('Id'); inspect_owned(possible,candidate,name,owner,head); cid=candidate
            if cid:
                report['cleanup']=retire(docker,cid,name,owner,head)
            elif create_uncertain:
                # A timed-out create may still be completing in the daemon.
                # Keep the independent watchdog alive; an instant absence is
                # not evidence that creation cannot complete later.
                report['cleanup']={'absent':False,'create_outcome':'uncertain'}
            else:
                absent_name(docker,name)
                report['cleanup']={'absent':True,'never_created':True}
        except BaseException as exc:
            report['cleanup_error']=type(exc).__name__ + ': ' + str(exc)[:512]
        # Stop only the exact watchdog child after confirmed container absence.
        if watch and report.get('cleanup',{}).get('absent'):
            if watch.poll() is None: watch.terminate()
            watch.wait(timeout=5)
        elif watch:
            try:
                watch.wait(timeout=max(1,deadline-time.monotonic()))
                report['watchdog_finished']=True
            except subprocess.TimeoutExpired:
                report['watchdog_finished']=False
        terminal=report.get('terminal_state') or {}
        report['complete']=report.get('outcome')=='passed' and report.get('host_receipts_validated') is True and bool(report.get('evidence')) and terminal.get('Running') is False and terminal.get('ExitCode') == 0 and terminal.get('OOMKilled') is False and report.get('cleanup',{}).get('absent') is True and 'error' not in report
        save(out/'controller.json',report)
    require(report['complete'], 'Smoke incomplete or failed; see controller receipt')


if __name__=='__main__':
    try:
        main()
    except BaseException as exc:
        print('CONTROLLER_FAILURE ' + json.dumps({'type':type(exc).__name__, 'message':str(exc)[:512]}), file=sys.stderr, flush=True)
        raise
