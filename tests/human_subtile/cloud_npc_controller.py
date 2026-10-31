"""One exact public GitHub-hosted wildlife smoke container; no image pull/build.

Source for review only. Explicit --execute is required. This controller does not
configure host networking, host security, package repositories or Docker daemon.
The pinned 386 image and complete ABI must be independently reviewed first.
"""
import argparse
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
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


def inspect_settings(info, image_id, mounts, uidgid, head):
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


def unpack_copy(raw, expected):
    require(len(raw) <= MAX_PACKAGE+1024*1024, 'Docker copy exceeds bound')
    with tarfile.open(fileobj=io.BytesIO(raw), mode='r:') as outer:
        rows=outer.getmembers()
        require(len(rows)==1 and rows[0].isfile() and rows[0].name.lstrip('./') == 'harness-evidence.tar' and
                rows[0].size <= MAX_PACKAGE, 'Unexpected Docker copy payload')
        data=outer.extractfile(rows[0]).read(MAX_PACKAGE+1)
    require(len(data) == expected['bytes'] <= MAX_PACKAGE and hashlib.sha256(data).hexdigest() == expected['sha256'],
            'Evidence package identity mismatch')
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:') as inner:
        entries=inner.getmembers()
        allowed={'harness-status.json', 'smoke-summary.json', 'npc-smoke/cloud-manifest.json',
                 'npc-smoke/npc-manifest.json', 'npc-smoke/stage/compile-stdout.log',
                 'npc-smoke/stage/compile-stderr.log'}
        allowed.update(f'npc-smoke/{suite}/{name}' for suite in ('runtime','runtime-wildlife')
                       for name in ('receipt.json','result.txt','port-closed.txt','runtime.log',
                                    'daemon-stdout.log','daemon-stderr.log','npc-receipt.json'))
        allowed.update(f'abi/abi-{index}-{part}.log' for index in range(6) for part in ('stdout','stderr'))
        require(len(entries) <= 32 and all(x.isfile() and not x.name.startswith('/') and
                '..' not in Path(x.name).parts and x.name in allowed and x.size <= 4*1024**2 for x in entries)
                and sum(x.size for x in entries) <= MAX_PACKAGE, 'Unsafe evidence archive')
        names=[x.name for x in entries]
        require(len(set(names))==len(names) and 'harness-status.json' in names, 'Missing/duplicate evidence')
    return data


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


def save(path, report):
    data=(json.dumps(report,indent=2,sort_keys=True)+'\n').encode()
    require(len(data) <= 65536, 'Controller receipt bound')
    tmp=path.with_suffix('.tmp'); tmp.write_bytes(data); os.replace(tmp,path)


def save_container_logs(docker, cid, path, timeout=3):
    _,stdout,stderr=docker.call(['logs','--tail','100',cid],timeout=timeout)
    data=stdout+b'\n'+stderr
    path.write_bytes(data[-1024**2:])
    return {'bytes':min(len(data),1024**2),'truncated':len(data)>1024**2}


def create_args(name,owner,head,source,binary,archive,uidgid):
    return ['create','--name',name,'--platform','linux/386','--pull','never',
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
    report={'head':head,'owner':owner,'name':name,'complete':False,'scope':SCOPE,'fixture_dme_only':True}
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
            '--output',str(out),'--name',name,'--owner',owner,'--deadline',str(deadline)],
            env=env,stdin=subprocess.DEVNULL,start_new_session=True)
        try:
            create_uncertain=True
            value=docker.call(create_args(name,owner,head,source,binary,archive,uidgid),timeout=15)[1].decode().strip()
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
        inspect_settings(info,image['Id'],mounts,uidgid,head)
        docker.call(['start',cid],timeout=10)
        marker=None
        while time.monotonic() < deadline-(MAX_SECONDS-WORK_SECONDS):
            info=inspect(docker,cid); inspect_owned(info,cid,name,owner,head)
            _,outlog,errlog=docker.call(['logs','--tail','100',cid],timeout=5)
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
            raw=docker.call(['cp',cid+':/work/harness-evidence.tar','-'],timeout=10,maximum=MAX_PACKAGE+1024*1024)[1]
            evidence=unpack_copy(raw,package)
            (out/'harness-evidence.tar').write_bytes(evidence)
            report['evidence']={'bytes':len(evidence),'sha256':hashlib.sha256(evidence).hexdigest()}
            report['outcome']=marker.get('outcome')
            if report['outcome'] == 'passed':
                validate_pass_evidence(evidence,head)
                report['host_receipts_validated']=True
            lease=marker.get('lease_seconds')
            require(isinstance(lease,(int,float)) and 0 <= lease <= 15, 'Invalid evidence lease')
            wait_end=min(deadline-20,time.monotonic()+lease+2)
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
