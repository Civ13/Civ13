"""Separate native preflight: one compile, two children, no performance verdict.

Default prints a source plan. Execution needs an independently reviewed image,
larger-envelope controls, hard host filesystems and an exact one-use admission.
This module never acquires an image, installs dependencies or dispatches a job.
"""
import argparse
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import uuid

MEMORY = 1536 * 1024**2
SCRATCH = 128 * 1024**2
BUILD = 1024**3
RECEIPT = 8 * 1024**2
OUTPUT = 16 * 1024**2
SCOPE = 'civ13-reserved-native-preflight'
LOG = {'Type': 'local', 'Config': {'max-size': '1m', 'max-file': '1', 'compress': 'false'}}
COUNTERS = {'memory.max': str(MEMORY), 'memory.swap.max': '0', 'pids.max': '32', 'cpu.max': '100000 100000'}
MISSING_FILE = re.compile(r'cannot (?:open|find)|unable to (?:open|find)|file[^\r\n]*(?:not found|does not exist)|missing file', re.I)


def require(value, message):
    if not value:
        raise ValueError(message)


def sha(path):
    value = hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda: source.read(1024**2), b''):
            value.update(block)
    return value.hexdigest()


def load(path):
    require(path.is_file() and not path.is_symlink() and path.stat().st_size <= RECEIPT, 'Bounded regular JSON required')
    return json.loads(path.read_text(encoding='utf-8'))


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


def plan():
    return {'scope': SCOPE, 'default': 'OFF', 'compile_count': 1, 'smoke_modes': ['baseline', 'candidate'],
            'batch_processes': 0, 'performance_verdict': False, 'image_acquisition': False,
            'memory': MEMORY, 'memory_plus_swap': MEMORY, 'pids': 32, 'cpu': 1,
            'compile_scratch': BUILD, 'aggregate_host_and_smoke_scratch': SCRATCH, 'receipt_bytes': RECEIPT,
            'compile_wall': 180, 'compile_cpu': 60, 'smoke_wall_each': 30, 'smoke_cpu_each': 10,
            'outer_wall': 600, 'cleanup_reserve_each': 15,
            'status': 'SOURCE ONLY: no accepted toolchain/image or larger-envelope controls are supplied'}


def toolchain(value):
    require(value.get('status') == 'INDEPENDENTLY_REVIEWED' and value.get('version') == '516.1681'
            and value.get('platform') == 'linux/amd64', 'Unresolved toolchain')
    require(re.fullmatch('[0-9a-f]{64}', value.get('archive_sha256') or '')
            and re.fullmatch(r'[^\s]+@sha256:[0-9a-f]{64}', value.get('image') or '')
            and re.fullmatch('sha256:[0-9a-f]{64}', value.get('image_id') or ''), 'Missing archive/image identity')
    for key, expected in [('compiler', 'byond/bin/DreamMaker'), ('daemon', 'byond/bin/DreamDaemon'),
                          ('python', '/usr/local/bin/python3.12')]:
        require(value[key]['path'] == expected and re.fullmatch('[0-9a-f]{64}', value[key]['sha256'] or ''), 'Binary identity')
    require(value.get('rootfs_provenance') and value.get('independent_review') and value.get('rootfs_files'),
            'Missing dependency/rootfs provenance')
    for path, digest in value['rootfs_files'].items():
        require(not path.startswith('/') and all(x not in ('', '.', '..') for x in path.split('/'))
                and '\\' not in path and ':' not in path and re.fullmatch('[0-9a-f]{64}', digest or ''), 'Rootfs inventory')
    require(value['rootfs_files'].get('opt/byond/bin/DreamMaker') == value['compiler']['sha256']
            and value['rootfs_files'].get('opt/byond/bin/DreamDaemon') == value['daemon']['sha256'], 'Rootfs binary binding')


def admission(packet, grant, now):
    require(set(packet) == {'head', 'packet_sha256', 'executor', 'toolchain', 'controls_receipt_sha256', 'source_manifest_sha256'}
            and re.fullmatch('[0-9a-f]{64}', packet['source_manifest_sha256'] or ''), 'Packet inventory')
    require(re.fullmatch('[0-9a-f]{40}', packet.get('head') or ''), 'Exact head')
    require(grant.get('scope') == SCOPE and grant.get('head') == packet['head'] and grant.get('packet_sha256') == packet['packet_sha256']
            and grant.get('executor') == packet['executor'] and grant.get('granted') is True, 'Wrong admission')
    require(type(grant.get('starts')) in (int, float) and type(grant.get('ends')) in (int, float)
            and math.isfinite(grant['starts']) and math.isfinite(grant['ends'])
            and grant['starts'] <= now < grant['ends'] and grant['ends'] - now >= 15, 'Expired/insufficient cleanup lease')
    require(grant.get('compile_count') == 1 and grant.get('smoke_modes') == ['baseline', 'candidate']
            and grant.get('larger_controls_accepted') is True and grant.get('engine_contract_accepted') is True
            and grant.get('zero_cost_handoff_accepted') is True and grant.get('controls_receipt_sha256') == packet.get('controls_receipt_sha256')
            and re.fullmatch('[0-9a-f]{64}', packet.get('controls_receipt_sha256') or ''), 'Missing bounded platform/engine/handoff acceptance')
    toolchain(packet['toolchain'])


def contained(path, root):
    require(path.is_absolute() and path.is_relative_to(root) and not path.is_symlink()
            and path.resolve().is_relative_to(root.resolve()), 'Output path escape')
    cursor = path
    while cursor != root:
        require(not cursor.is_symlink(), 'Linked output ancestor')
        cursor = cursor.parent
    return path


def quota(root, cap, statvfs=os.statvfs if hasattr(os, 'statvfs') else None, ismount=os.path.ismount):
    require(root.is_absolute() and not root.is_symlink() and ismount(root), 'Dedicated hard filesystem mount required')
    require(statvfs is not None, 'Linux filesystem counters required')
    data = statvfs(root)
    require(data.f_frsize * data.f_blocks == cap and 0 < data.f_bavail <= data.f_blocks, 'Hard capacity mismatch')
    return {'capacity': cap, 'available': data.f_frsize * data.f_bavail, 'device': root.stat().st_dev}


def capacity_control(root, cap):
    """Causal ENOSPC of the aggregate host filesystem, before any native start.

    Only the exclusively-created probe is removed. No directory cleanup/retry.
    Literal Linux errno 28 also makes offline receipt readers portable.
    """
    before = quota(root, cap)
    probe = root / ('capacity-' + uuid.uuid4().hex)
    written = 0
    error = None
    try:
        with probe.open('xb', buffering=0) as output:
            block = b'\0' * (1024**2)
            while written <= cap:
                try:
                    count = output.write(block)
                    written += count
                except OSError as failure:
                    error = failure.errno
                    break
        require(error == 28 and 0 < written <= cap, 'Missing filesystem ENOSPC control')
    finally:
        probe.unlink(missing_ok=True)
    after = quota(root, cap)
    require(after['device'] == before['device'], 'Filesystem changed during control')
    return {'errno': error, 'written': written, 'before': before, 'after': after}


def settings(info, packet, source, build, output, compile_phase):
    host = info['HostConfig']
    require(info['Image'] == packet['toolchain']['image_id'] and info['Config']['Image'] == packet['toolchain']['image'], 'Image drift')
    require(host['Memory'] == MEMORY and host['MemorySwap'] == MEMORY and host['PidsLimit'] == 32
            and host['NanoCpus'] == 1000000000 and host['LogConfig'] == LOG, 'Resource/log configuration drift')
    require(host['NetworkMode'] == 'none' and host['ReadonlyRootfs'] is True and host['Privileged'] is False
            and host['CgroupnsMode'] == 'private' and host['IpcMode'] == 'private' and host['PidMode'] == ''
            and host['CapDrop'] == ['ALL'] and 'no-new-privileges' in host['SecurityOpt']
            and not host.get('PortBindings') and not host.get('Devices') and not host.get('Binds')
            and not host.get('Tmpfs') and host['ShmSize'] == 1048576, 'Isolation drift')
    actual = {(row['Source'], row['Destination'], row['RW'], row['Type']) for row in info['Mounts']}
    expected = {(str(source), '/source', False, 'bind'), (str(build), '/build', compile_phase, 'bind'),
                (str(output), '/work', True, 'bind')}
    require(actual == expected and len(info['Mounts']) == 3, 'Mount configuration drift')
    require(info['Config']['User'] == '65534:65534' and info['Config']['Entrypoint'] == ['/usr/local/bin/python3.12']
            and info['Config']['WorkingDir'] == '/work', 'User/entrypoint drift')


def arguments(name, owner, packet, source, build, output, phase):
    require(phase in ('compile', 'baseline', 'candidate'), 'Process budget/phase')
    return ['create', '--name', name, '--platform', 'linux/amd64', '--pull', 'never',
            '--label', 'scope=' + SCOPE, '--label', 'owner=' + owner, '--label', 'head=' + packet['head'],
            '--network', 'none', '--read-only', '--cap-drop', 'ALL', '--security-opt', 'no-new-privileges',
            '--user', '65534:65534', '--pids-limit', '32', '--memory', str(MEMORY), '--memory-swap', str(MEMORY),
            '--cpus', '1', '--cgroupns', 'private', '--ipc', 'private', '--shm-size', '1048576',
            '--mount', 'type=bind,src=' + str(source) + ',dst=/source,readonly',
            '--mount', 'type=bind,src=' + str(build) + ',dst=/build' + ('' if phase == 'compile' else ',readonly'),
            '--mount', 'type=bind,src=' + str(output) + ',dst=/work', '--workdir', '/work',
            '--env', 'PYTHONDONTWRITEBYTECODE=1', '--env', 'PYTHONUNBUFFERED=1', '--restart', 'no', '--stop-timeout', '1', '--no-healthcheck',
            '--log-driver', 'local', '--log-opt', 'max-size=1m', '--log-opt', 'max-file=1', '--log-opt', 'compress=false',
            '--entrypoint', '/usr/local/bin/python3.12', packet['toolchain']['image'], '-B',
            '/source/tests/reserved_lighting/native_preflight/run.py', '--inside', phase]


def owned_phase(pilot, docker, packet, source, build, output, phase, lease):
    """Reuse accepted ownership/retirement primitives; never pull or retry.

    The caller gives the separately loaded helper module this distinct scope;
    its owned()/retire() functions then require the native-preflight label.
    """
    name = 'civ13-native-' + uuid.uuid4().hex
    owner = uuid.uuid4().hex
    row = {'phase': phase, 'name': name, 'owner': owner, 'complete': False}
    cid = None
    try:
        lease(reserve=195 if phase == 'compile' else 45)
        try:
            cid_text = docker.call(arguments(name, owner, packet, source, build, output, phase))[1].strip()
            require(re.fullmatch('[0-9a-f]{64}', cid_text), 'Created CID missing')
            candidate = pilot.inspect(docker, cid_text)
            pilot.owned(candidate, cid_text, name, owner, packet['head'])
            cid = cid_text
        except BaseException as failure:
            row['create_error'] = str(failure)
            try:
                rc, text, err = docker.call(['inspect', name], optional=True, cleanup=True)
                row['reconciliation'] = {'returncode': rc, 'stderr': err[-512:]}
                if rc == 0:
                    info = json.loads(text)[0]
                    require(re.fullmatch('[0-9a-f]{64}', info['Id']), 'Uncertain CID')
                    pilot.owned(info, info['Id'], name, owner, packet['head'])
                    cid = info['Id']
            except BaseException as reconcile:
                row['reconciliation_error'] = str(reconcile)
            raise
        settings(candidate, packet, source, build, output, phase == 'compile')
        lease(reserve=195 if phase == 'compile' else 45)  # after create/inspection, before start
        row['settings_verified'] = True
        docker.call(['start', cid])
        row['exit_code'] = int(docker.call(['wait', cid], timeout=180 if phase == 'compile' else 30)[1].strip())
        terminal = pilot.inspect(docker, cid)
        pilot.owned(terminal, cid, name, owner, packet['head'])
        require(row['exit_code'] == 0 and terminal['State']['OOMKilled'] is False, 'Native phase failed/OOM')
        lease()
    except BaseException as failure:
        row['error'] = str(failure)
    finally:
        if cid is None:
            row['cleanup'] = {'all_exited': False, 'error': 'No owned CID; no signals, no retry'}
        else:
            try:
                # Larger-envelope descendant control is an external prerequisite.
                # This stopped native phase claims owned container removal only.
                row['cleanup'] = pilot.retire(docker, cid, name, owner, packet['head'], {})
            except BaseException as failure:
                row['cleanup'] = {'all_exited': False, 'error': str(failure)}
    row['complete'] = not row.get('error') and row['cleanup']['all_exited']
    return row


def sequence(phase, verify, persist):
    """Exactly three phase calls; stop on first unexpected result, no retry."""
    receipt = {'scope': SCOPE, 'complete': False, 'runs': [], 'performance_verdict': False}
    try:
        for name in ('compile', 'baseline', 'candidate'):
            verify()
            row = phase(name)
            receipt['runs'].append(row); persist(receipt)
            require(row['complete'] is True, 'Incomplete ' + name)
            verify()
        receipt['parity'] = verify(final=True)
        verify()  # final lease/input hash check after parity/hashing
        receipt['complete'] = True
    except BaseException as failure:
        receipt['error'] = str(failure)
    finally:
        persist(receipt)
    return receipt


def save(path, value):
    data = (json.dumps(value, indent=2) + '\n').encode()
    require(len(data) <= RECEIPT, 'Receipt sublimit')
    path.write_bytes(data)


def compiler_result(code, log, diagnostic):
    require(code == 0 and 'DM compiler version 516.1681' in log
            and re.search(r'^probe.dmb - 0 errors, 0 warnings \(.+\)$', log, re.M)
            and not diagnostic.search(log) and not MISSING_FILE.search(log),
            'Compiler failed/diagnostic (real exit status required)')


def compiler_limits():
    import resource
    resource.setrlimit(resource.RLIMIT_CPU, (60, 60))
    # This limit applies to ALL created files. Resource artifacts must fit the
    # separate 1 GiB build filesystem, not the 16 MiB log polling threshold.
    resource.setrlimit(resource.RLIMIT_FSIZE, (BUILD, BUILD))


def compile_once(fixture, paths, popen=subprocess.Popen, clock=time.monotonic, pause=time.sleep):
    with paths[0].open('xb') as out, paths[1].open('xb') as err:
        child = popen(['/opt/byond/bin/DreamMaker', '-max_errors', '0', 'probe.dme'], cwd=fixture,
                      stdout=out, stderr=err, start_new_session=True, preexec_fn=compiler_limits)
        try:
            deadline = clock() + 180
            while child.poll() is None:
                require(clock() < deadline, 'Compiler wall deadline')
                require(sum(path.stat().st_size for path in paths) <= OUTPUT, 'Compiler log output bound (polling)')
                pause(.05)
            require(sum(path.stat().st_size for path in paths) <= OUTPUT, 'Compiler log output bound (polling)')
            return child.returncode
        finally:
            if child.poll() is None:
                child.kill(); child.wait(timeout=3)


def adapter_evidence(samples, identity, validate):
    previous = None
    require(samples, 'Missing adapter counters')
    for sample in samples:
        validate(sample, identity, previous, {'wall': 30, 'cpu': 10, 'private': MEMORY})
        previous = sample
    require(samples[-1]['exited'] is True and samples[-1]['exit_code'] == 0 and samples[-1]['cpu'] > 0,
            'Missing wait4 CPU/exit evidence')
    require(any(value['private_sampled'] and value['private'] > 0 for value in samples), 'No positive smaps sample')


def build_inventory(build, head, compiler, relative):
    compiled = load(build / 'build.json')
    require(compiled['head'] == head and compiled['compiler'] == compiler and compiled['exit_code'] == 0, 'Build provenance')
    for rel, value in compiled['files'].items():
        require(sha(build / relative(rel)) == value, 'Compiled artifact changed')
    # Exactly the five resource-directory symlinks made by common fixture setup.
    links = {'fixture/' + part for part in ('icons', 'sound', 'UI', 'interface', 'code/js')}
    actual = set()
    found_links = set()
    for path in build.rglob('*'):
        rel = path.relative_to(build).as_posix()
        if path.is_symlink():
            require(rel in links and path.resolve() == Path('/source') / rel[len('fixture/'):], 'Unexpected compiled link')
            found_links.add(rel)
        elif path.is_file():
            actual.add(rel)
    require(actual == set(compiled['files']) | {'build.json'} and found_links == links, 'Changed build inventory')
    return compiled


def execute(packet_path, grant_path, source, build, output, env=os.environ):
    require(sys.platform == 'linux', 'Linux-only execution')
    require(sys.dont_write_bytecode, 'Use Python -B; no unbounded bytecode writers')
    packet = load(packet_path)
    packet['packet_sha256'] = sha(packet_path)
    grant = load(grant_path)
    expected = {'GITHUB_ACTIONS': 'true', 'RUNNER_ENVIRONMENT': 'github-hosted', 'RUNNER_OS': 'Linux',
                'RUNNER_ARCH': 'X64', 'GITHUB_REPOSITORY': 'Civ13/Civ13', 'GITHUB_REPOSITORY_ID': '141349998',
                'GITHUB_EVENT_NAME': 'workflow_dispatch', 'CIV13_REPOSITORY_VISIBILITY': 'public',
                'CIV13_NATIVE_PREFLIGHT_CONFIRMED': 'true', 'GITHUB_SHA': packet['head']}
    require(all(env.get(k) == v for k, v in expected.items()), 'Exact public free-hosted manual job required')
    start = time.monotonic()
    def lease():
        require(time.monotonic() - start < 585, 'Outer deadline/cleanup reserve')
        require(sha(packet_path) == packet['packet_sha256'] and load(grant_path) == grant, 'Admission inputs changed')
        admission(packet, grant, time.time())
    lease()
    require(source.resolve() == source and build.resolve() == build and output.resolve() == output
            and not any(left.is_relative_to(right) for left, right in ((source, output), (output, source),
                        (source, build), (build, source), (build, output), (output, build))),
            'Disjoint canonical input/output mounts required')
    quota(build, BUILD); quota(output, SCRATCH)
    require(build.stat().st_dev != output.stat().st_dev, 'Separate compile/aggregate filesystem required')
    require(not list(build.iterdir()) and not list(output.iterdir()), 'Fresh empty bounded mounts required')
    # The source preparation module is local reviewed code, not discovered code.
    prep = module('native_staging', Path(__file__).with_name('prepare.py'))
    manifest = load(source / 'source.json')
    require(manifest['head'] == packet['head'] and sha(source / 'source.json') == packet['source_manifest_sha256'], 'Source packet mismatch')
    prep.validate(source, manifest); lease()
    require(sha(source / 'tests/reserved_lighting/native_preflight/run.py') == sha(Path(__file__))
            and sha(source / 'tests/reserved_lighting/native_preflight/prepare.py') == sha(Path(__file__).with_name('prepare.py')),
            'Controller differs from immutable source')
    capacity = {'scratch': capacity_control(output, SCRATCH), 'compile': capacity_control(build, BUILD)}
    # O_EXCL claim is an actual one-use guard on this run's aggregate filesystem.
    # The external sole dispatcher must also prevent a new filesystem replay.
    with (output / 'USED').open('xb') as used:
        used.write(packet['packet_sha256'].encode())
    save(output / 'request.json', packet)
    save(output / 'capacity.json', capacity)
    pilot = module('accepted_pilot', source / 'tests/reserved_lighting/containment_pilot.py')
    pilot.SCOPE = SCOPE  # local module instance only; never edit the accepted source
    def verify(final=False, reserve=15):
        lease(); prep.validate(source, manifest)
        quota(build, BUILD); quota(output, SCRATCH)
        if (build / 'build.json').exists():
            build_inventory(build, packet['head'], packet['toolchain']['compiler'], prep.relative)
        for phase in ('baseline', 'candidate'):
            if (output / phase).exists():
                expected_names = prep.name_paths((source / 'code/names.dm').read_bytes())
                actual_names = {path.relative_to(output / phase).as_posix() for path in (output / phase / 'config').rglob('*') if path.is_file()}
                require(actual_names == expected_names, 'Final smoke runtime inventory')
                for rel in expected_names:
                    path = contained(output / phase / rel, output)
                    require(sha(path) == manifest['files'][rel]['sha256'], 'Final runtime input drift')
                require(load(output / phase / 'adapter.json')['complete'] is True, 'Incomplete adapter receipt')
        if final:
            sys.path.insert(0, str(source / 'tests/reserved_lighting'))
            from compare import compare
            value = compare(output / 'baseline/states.jsonl', output / 'candidate/states.jsonl')
            require(value == {'snapshots': 6, 'rows': 1350, 'equal': True}, 'Wrong smoke comparison')
            return value
        lease()  # hashing and filesystem observations consume lease time too
        require(grant['ends'] - time.time() >= reserve, 'Insufficient phase+cleanup lease after hashing')
    def phase(name):
        cli = output / ('controller-' + name); cli.mkdir()
        docker = pilot.Docker(cli)  # every CLI/log/config writer shares the aggregate hard mount
        return owned_phase(pilot, docker, packet, source, build, output, name, verify)
    result = sequence(phase, verify, lambda value: save(output / 'preflight.json', value))
    require(result['complete'], result.get('error', 'Incomplete preflight'))
    return result


def inside(phase):
    """Runs only inside separately admitted larger containment; no host fallback."""
    source, build, output = Path('/source'), Path('/build'), Path('/work')
    request = load(output / 'request.json')
    toolchain(request['toolchain'])
    for rel, value in request['toolchain']['rootfs_files'].items():
        require(sha(Path('/') / rel) == value, 'Runtime rootfs drift')
    require(sha(Path(sys.executable)) == request['toolchain']['python']['sha256'], 'Python identity drift')
    counters = {key: (Path('/sys/fs/cgroup') / key).read_text().strip() for key in COUNTERS}
    require(counters == COUNTERS, 'Actual enforced cgroup counters missing/drifted')
    tools = source / 'tests/reserved_lighting'
    sys.path.insert(0, str(tools))
    import measurement as measure
    if phase == 'compile':
        fixture = build / 'fixture'
        prepare = module('fixture_preparation', tools / 'prepare.py')
        prepare.prepare(source, fixture, provenance={'head': request['head'], 'dirty_diff_sha256': hashlib.sha256(b'').hexdigest()})
        for rel in ('icons', 'sound', 'UI', 'interface', 'code/js'):
            target = fixture / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            target.symlink_to(source / rel, target_is_directory=True)
        paths = [output / ('compile-' + part + '.log') for part in ('stdout', 'stderr')]
        code = compile_once(fixture, paths)
        log = ''.join(path.read_text(errors='replace') for path in paths)
        compiler_result(code, log, measure.DIAGNOSTIC)
        products = {path.relative_to(build).as_posix(): sha(path) for path in fixture.rglob('*') if path.is_file() and not path.is_symlink()}
        require(all('fixture/' + name in products for name in ('probe.dme', 'probe.dmb', 'probe.rsc', 'manifest.json')), 'Missing compiled artifact')
        save(build / 'build.json', {'head': request['head'], 'compiler': request['toolchain']['compiler'], 'exit_code': code,
                                   'files': products, 'counters': counters})
        return
    require(phase in ('baseline', 'candidate'), 'Unbudgeted smoke')
    prep = module('inside_native_staging', Path(__file__).with_name('prepare.py'))
    build_inventory(build, request['head'], request['toolchain']['compiler'], prep.relative)
    work = output / phase; work.mkdir()
    source_manifest = load(source / 'source.json')
    paths = measure.runtime_paths()
    runtime = {'head': request['head'], 'source': 'code/names.dm', 'source_sha256': measure.sha(measure.NAMES_SOURCE),
               'source_git_blob': measure.git_blob(measure.NAMES_SOURCE.read_bytes()),
               'files': {name: source_manifest['files'][name] for name in paths}}
    measure.stage_runtime({'head': request['head'], 'runtime': runtime}, source, work)
    adapter = measure.LinuxAdapter()
    child = None
    row = {'phase': phase, 'complete': False, 'samples': [], 'counters': counters}
    limits = {'wall': 30, 'cpu': 10, 'private': MEMORY}
    try:
        child = adapter.launch({'daemon': '/opt/byond/bin/DreamDaemon', 'dmb': 'fixture/probe.dmb',
                                'limits': {'output': OUTPUT}, 'command_tail': ['-close', '-trusted', '-log', 'runtime.log', '-params']}, build, work, phase)
        previous = None
        while True:
            sample = adapter.sample(child)
            row['samples'].append(sample); save(work / 'adapter.json', row)
            measure.validate_sample(sample, child.identity, previous, limits)
            measure.output_bound(work, OUTPUT)
            if sample['exited']:
                require(sample['exit_code'] == 0 and sample['cpu'] > 0, 'Missing wait4 CPU/exit evidence')
                break
            previous = sample
            time.sleep(.02)
        adapter_evidence(row['samples'], child.identity, measure.validate_sample)
        measure.outcome(work, OUTPUT)
        for log in ('stdout.log', 'stderr.log', 'runtime.log'):
            require(not MISSING_FILE.search((work / log).read_text(errors='replace')), 'Missing-file diagnostic')
        measure.validate_runtime_files(runtime, work, exact=True)
    except BaseException as failure:
        row['error'] = str(failure)
        raise
    finally:
        try:
            row['cleanup'] = adapter.cleanup(child)
        except BaseException as failure:
            row['cleanup'] = {'all_exited': False, 'empty': False, 'error': str(failure)}
        save(work / 'adapter.json', row)
    require(row['cleanup']['all_exited'] and row['cleanup']['empty'], 'Child/group cleanup incomplete')
    row['complete'] = True; save(work / 'adapter.json', row)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--inside', choices=('compile', 'baseline', 'candidate'))
    parser.add_argument('--execute', action='store_true')
    for name in ('packet', 'grant', 'source', 'build', 'output'):
        parser.add_argument('--' + name, type=Path)
    args = parser.parse_args()
    if args.inside:
        require(not args.execute, 'Choose one entry')
        inside(args.inside)
    elif args.execute:
        require(all(getattr(args, name) for name in ('packet', 'grant', 'source', 'build', 'output')), 'Missing execution inputs')
        print(json.dumps(execute(args.packet, args.grant, args.source, args.build, args.output), indent=2))
    else:
        print(json.dumps(plan(), indent=2))
