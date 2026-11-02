"""Reviewed-source proposal: bounded Linux vendor/codec smoke, never wildlife acceptance.

This program does not configure a container, network, cgroup, mount or host security.
Provision and independently review the closed cloud envelope described in
WILDLIFE-NATIVE-PLAN.md before use. The operator must explicitly acknowledge that
review; automated checks are additional fail-closed checks, not its substitute.
"""
import argparse
import base64
import hashlib
import importlib.util
import io
import json
import lzma
import os
from pathlib import Path
import re
import signal
import shutil
import stat
import struct
import subprocess
import sys
import tarfile
import threading
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
MAX_MEMORY = 3 * 1024**3
MAX_DISK = 1024**3
MAX_PIDS = 64
MAX_SECONDS = 600
EXPECTED_ARCHIVE = '16278f318cdeb4b77c57868dd7135032fde717ea6226269d22b2a1a50968e7f9'
RUN_STATE = {'phase': 'entry', 'outcome': 'incomplete', 'history': []}
RUN_ROOT = None
RUN_STARTED = None
SCRATCH_METER = None
EVIDENCE_PATHS = (
    'harness-status.json', 'smoke-summary.json', 'npc-smoke/cloud-manifest.json',
    'npc-smoke/npc-manifest.json', 'npc-smoke/stage/compile-stdout.log',
    'npc-smoke/stage/compile-stderr.log',
    'npc-smoke/geometry-stage/manifest.json',
    'npc-smoke/geometry-stage/compile-stdout.log', 'npc-smoke/geometry-stage/compile-stderr.log',
    'npc-parent/cloud-manifest.json', 'npc-parent/stage/compile-stdout.log', 'npc-parent/stage/compile-stderr.log',
    *(f'npc-parent/{suite}/{name}' for suite in ('runtime', 'runtime-wildlife')
      for name in ('receipt.json', 'result.txt', 'port-closed.txt', 'runtime.log', 'daemon-stdout.log', 'daemon-stderr.log')),
    'production/source-compact.json', 'production/stage/compile-stdout.log', 'production/stage/compile-stderr.log',
    *(f'npc-smoke/geometry/{name}' for name in ('receipt.json','result.txt','port-closed.txt','runtime.log',
                                                'daemon-stdout.log','daemon-stderr.log')),
    *(f'npc-smoke/{suite}/{name}' for suite in ('runtime', 'runtime-wildlife')
      for name in ('receipt.json', 'result.txt', 'port-closed.txt', 'runtime.log',
                   'daemon-stdout.log', 'daemon-stderr.log', 'npc-receipt.json')),
    *(f'abi/abi-{index}-{part}.log' for index in range(6) for part in ('stdout','stderr')),
)
EVIDENCE_LIMIT = 16 * 1024**2
LOG_EVIDENCE_LIMIT = 320 * 1024


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


def checkpoint(phase, **fields):
    RUN_STATE.update(fields)
    RUN_STATE['phase'] = phase
    if len(RUN_STATE['history']) < 24:
        RUN_STATE['history'].append(phase)
    encoded = (json.dumps(RUN_STATE, sort_keys=True) + '\n').encode()
    require(len(encoded) <= 32768, 'Failure receipt bound exceeded')
    # Emit first so a full tmpfs cannot suppress the last bounded failure phase.
    visible = {k: RUN_STATE[k] for k in ('phase', 'outcome', 'error_type', 'error_message') if k in RUN_STATE}
    print('HARNESS_CHECKPOINT ' + json.dumps(visible, sort_keys=True), flush=True)
    if RUN_ROOT is not None:
        # The output root was checked fresh and isolated before assignment.
        temp = RUN_ROOT / 'harness-status.tmp'
        temp.write_bytes(encoded)
        os.replace(temp, RUN_ROOT / 'harness-status.json')


def package_evidence(root):
    """Copy only small named regular files as data, with no links or saves."""
    collected = []
    total = 0
    for rel in EVIDENCE_PATHS:
        # The extended manifest contains both the original and final source
        # inventories; its pre-adaptation npc manifest is redundant.
        if RUN_STATE.get('suite') in ('extended', 'bridge', 'scheduler', 'random05', 'random10', 'cardinal05', 'cardinal10', 'transition05', 'bump05', 'pair05', 'ordinary05', 'group05') and rel == 'npc-smoke/npc-manifest.json':
            continue
        path = root / rel
        if not path.exists():
            continue
        info = path.lstat()
        require(stat.S_ISREG(info.st_mode) and path.resolve().is_relative_to(root),
                'Unsafe evidence path: ' + rel)
        require(info.st_size <= 4 * 1024**2, 'Evidence file exceeds bound: ' + rel)
        total += info.st_size + 2048
        require(total <= EVIDENCE_LIMIT - 10240, 'Evidence aggregate exceeds bound')
        data = path.read_bytes()
        require(len(data) == info.st_size, 'Evidence changed while reading: ' + rel)
        collected.append((rel, data))
    require(any(name == 'harness-status.json' for name, _ in collected), 'Missing harness status')
    result = root / 'harness-evidence.tar'
    with result.open('xb') as raw:
        with tarfile.open(fileobj=raw, mode='w') as archive:
            for rel, data in collected:
                entry = tarfile.TarInfo(rel)
                entry.size = len(data)
                entry.mode = 0o600
                entry.mtime = 0
                archive.addfile(entry, io.BytesIO(data))
    require(result.stat().st_size <= EVIDENCE_LIMIT, 'Evidence archive exceeds bound')
    return {'bytes': result.stat().st_size, 'sha256': file_hash(result), 'files': len(collected)}


def emit_package(root, outcome, scratch):
    """Transfer bounded synthetic evidence through the worker's existing log stream."""
    package_evidence(root)
    raw = (root / 'harness-evidence.tar').read_bytes()
    # XZ's bounded dictionary retains the repeated source-manifest maps that
    # exceed gzip's short window; the archive itself stays byte-for-byte intact.
    zipped = lzma.compress(raw, format=lzma.FORMAT_XZ, preset=6)
    complete = len(zipped) <= LOG_EVIDENCE_LIMIT
    if not complete:
        # Retain the full status plus bounded tails, explicitly disallowing a pass.
        compact = io.BytesIO()
        with tarfile.open(fileobj=io.BytesIO(raw), mode='r:') as original, \
             tarfile.open(fileobj=compact, mode='w') as reduced:
            for item in original.getmembers():
                data = original.extractfile(item).read()
                if item.name != 'harness-status.json':
                    data = data[-8192:]
                entry = tarfile.TarInfo(item.name); entry.size = len(data); entry.mode = 0o600
                reduced.addfile(entry, io.BytesIO(data))
        raw = compact.getvalue()
        zipped = lzma.compress(raw, format=lzma.FORMAT_XZ, preset=6)
    require(len(zipped) <= LOG_EVIDENCE_LIMIT, 'Compact evidence exceeds log bound')
    encoded = base64.b64encode(zipped).decode('ascii')
    parts = [encoded[i:i+8192] for i in range(0, len(encoded), 8192)]
    for index, part in enumerate(parts, 1):
        print('HARNESS_EVIDENCE_PART ' + str(index) + '/' + str(len(parts)) + ' ' + part, flush=True)
    package = {'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest(),
               'compressed_bytes': len(zipped), 'parts': len(parts), 'complete': complete,
               'compression': 'xz'}
    print('HARNESS_EVIDENCE_READY ' + json.dumps({'outcome': outcome, 'package': package,
          'scratch': scratch}, sort_keys=True), flush=True)


def validate_envelope(*, uid, interfaces, memory, swap, pids, cpu, disk_bytes,
                      scratch_mount, scratch_empty, source_readonly, bin_readonly,
                      archive_readonly, cgroup_pids, own_pid, effective_caps,
                      no_new_privs, cgroup_writable):
    require(uid != 0, 'Test worker must be unprivileged')
    require(effective_caps == '0000000000000000' and no_new_privs == '1',
            'Worker must have no effective capabilities and no-new-privileges')
    require(not cgroup_writable, 'Worker may not alter or leave its cgroup')
    require(set(interfaces) == {'lo'}, 'Only an isolated loopback interface is permitted')
    require(memory.isdigit() and 0 < int(memory) <= MAX_MEMORY, 'Missing 3 GiB cgroup memory cap')
    require(swap == '0', 'Worker cgroup must have zero swap')
    require(pids.isdigit() and 1 < int(pids) <= MAX_PIDS, 'Missing 64-process cgroup cap')
    fields = cpu.split()
    require(len(fields) == 2 and all(x.isdigit() for x in fields), 'Missing finite cgroup CPU cap')
    quota, period = map(int, fields)
    require(quota > 0 and period > 0 and quota <= 2 * period, 'CPU cap exceeds two cores')
    require(scratch_mount and scratch_empty and 0 < disk_bytes <= MAX_DISK,
            'Scratch must be a fresh dedicated filesystem of at most 1 GiB')
    require(source_readonly and bin_readonly and archive_readonly,
            'Reviewed source, binary directory and archive must be mounted read-only')
    require(set(cgroup_pids) == {own_pid}, 'Dedicated cgroup must contain only this supervisor at start')


def current_cgroup():
    membership = Path('/proc/self/cgroup').read_text().splitlines()
    rows = [line.split(':', 2)[2] for line in membership if line.startswith('0::')]
    require(len(rows) == 1, 'A unified cgroup-v2 membership is required')
    root = Path('/sys/fs/cgroup').resolve()
    # The mounted cgroup namespace may present our cgroup as its root.
    group = (root / rows[0].lstrip('/')).resolve()
    require(group.is_relative_to(root) and group.is_dir(), 'Unresolvable cgroup-v2 path')
    return group


def pids_in(group):
    return [int(x) for x in (group / 'cgroup.procs').read_text().split()]


def read_only(path):
    return bool(os.statvfs(path).f_flag & os.ST_RDONLY)


def check_environment(scratch, binary, archive):
    group = current_cgroup()
    fs = os.statvfs(scratch)
    status = {}
    for line in Path('/proc/self/status').read_text().splitlines():
        key, _, value = line.partition(':')
        if key in ('CapEff', 'NoNewPrivs'):
            status[key] = value.strip()
    envelope = dict(uid=os.geteuid(), interfaces=os.listdir('/sys/class/net'),
        memory=(group / 'memory.max').read_text().strip(),
        swap=(group / 'memory.swap.max').read_text().strip(),
        pids=(group / 'pids.max').read_text().strip(),
        cpu=(group / 'cpu.max').read_text().strip(),
        disk_bytes=fs.f_blocks * fs.f_frsize, scratch_mount=os.path.ismount(scratch),
        scratch_empty=not any(scratch.iterdir()), source_readonly=read_only(ROOT),
        bin_readonly=read_only(binary), archive_readonly=read_only(archive),
        cgroup_pids=pids_in(group), own_pid=os.getpid(),
        effective_caps=status.get('CapEff'), no_new_privs=status.get('NoNewPrivs'),
        cgroup_writable=os.access(group, os.W_OK) or os.access(group / 'cgroup.procs', os.W_OK))
    validate_envelope(**envelope)
    return group, envelope


def require_only_supervisor(group):
    require(set(pids_in(group)) == {os.getpid()},
            'Child escaped process-group cleanup; destroy the isolated cloud worker')


def run_owned_phase(legacy, group, command, cwd, name, deadline):
    try:
        return legacy.run_process(command, cwd, name, deadline)
    finally:
        # The legacy runner kills its owned process group on success or error.
        # A different-group escape is reported for the cloud provider to destroy.
        require_only_supervisor(group)


def check_clean_exact(head):
    require(re.fullmatch('[0-9a-f]{40}', head) is not None, 'Expected full exact commit')
    observed = subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], timeout=10).decode().strip()
    require(observed == head, 'Git HEAD differs from reviewed commit')
    dirty = subprocess.check_output(['git', '-C', str(ROOT), 'status', '--porcelain=v1', '--untracked-files=all'], timeout=30)
    require(not dirty, 'Source tree must be clean')


def file_hash(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


class ScratchMeter:
    """Sample filesystem allocation; the tmpfs quota is the actual hard bound."""
    def __init__(self, root):
        self.root = root
        self.peak = 0
        self.samples = 0
        self.error = None
        self.stop_event = threading.Event()
        self.thread = threading.Thread(target=self.run, daemon=True)

    def sample(self):
        stats = os.statvfs(self.root)
        self.peak = max(self.peak, (stats.f_blocks - stats.f_bfree) * stats.f_frsize)
        self.samples += 1

    def run(self):
        try:
            while not self.stop_event.wait(.25):
                self.sample()
        except BaseException as exc:
            self.error = type(exc).__name__

    def start(self):
        self.sample()
        self.thread.start()

    def finish(self):
        self.stop_event.set()
        self.thread.join(timeout=2)
        self.sample()
        require(not self.thread.is_alive() and not self.error, 'Scratch observation failed')
        return {'sampled_peak_bytes': self.peak, 'samples': self.samples, 'period_seconds': .25,
                'limitation': 'Sampled allocation may miss short peaks; tmpfs is the hard bound.'}


def prepare_linked_runtime(out, stage, dme, name):
    """Share the immutable DMB; give each runtime an independent writable RSC."""
    work = out / name
    work.mkdir()
    artifacts = {}
    for extension in ('.dmb', '.rsc'):
        source = dme.with_suffix(extension)
        info = source.lstat()
        require(stat.S_ISREG(info.st_mode) and 0 < info.st_size <= MAX_DISK,
                'Missing or oversized compiled fixture artifact')
        target = work / source.name
        if extension == '.dmb':
            os.chmod(source, 0o444)
            os.link(source, target)
            require(os.path.samefile(source, target), 'Fixture artifact hardlink mismatch')
        else:
            require(shutil.disk_usage(work).free >= info.st_size, 'Insufficient bounded scratch for resource copy')
            # BYOND's resource cache can be modified by the running world. A
            # shared hardlink would couple the two tests and the compiler output.
            with source.open('rb') as reader, target.open('xb') as writer:
                shutil.copyfileobj(reader, writer, length=1024*1024)
            os.chmod(target, 0o600)
            require(not os.path.samefile(source, target), 'Resource copy must be independent')
        require(target.stat().st_size == info.st_size and file_hash(target) == file_hash(source),
                'Compiled fixture copy mismatch')
        artifacts[target.name] = {'bytes': info.st_size, 'sha256': file_hash(target),
                                  'mode': stat.S_IMODE(target.stat().st_mode)}
    shutil.copytree(stage / 'config', work / 'config')
    return work, work / dme.with_suffix('.dmb').name, artifacts


def verify_linked_runtime(work, artifacts):
    for name, expected in artifacts.items():
        path = work / name
        info = path.lstat()
        require(stat.S_ISREG(info.st_mode) and info.st_size == expected['bytes'] and
                (not name.endswith('.dmb') or stat.S_IMODE(info.st_mode) == expected['mode']) and
                file_hash(path) == expected['sha256'], 'Compiled fixture artifact changed: ' + name)


def resource_observation(path, expected):
    info = path.lstat()
    require(stat.S_ISREG(info.st_mode) and 0 < info.st_size <= MAX_DISK and
            stat.S_IMODE(info.st_mode) == expected['mode'], 'Invalid runtime resource cache')
    return {'bytes': info.st_size, 'sha256': file_hash(path), 'mode': stat.S_IMODE(info.st_mode)}


def run_checked_runtime(legacy, group, command, work, dme, peer, artifacts, peer_expected, label, records, timeout=90):
    """Record mutable own cache even on failure; protect compiler artifacts and peer."""
    resource = dme.with_suffix('.rsc').name
    binary = dme.with_suffix('.dmb').name
    own = work / resource
    peer_resource = peer / resource
    compiler_resource = dme.with_suffix('.rsc')
    verify_linked_runtime(work, artifacts)
    verify_linked_runtime(dme.parent, artifacts)
    verify_linked_runtime(peer, {binary: artifacts[binary]})
    require(resource_observation(peer_resource, artifacts[resource]) == peer_expected and
            not os.path.samefile(own, compiler_resource) and not os.path.samefile(own, peer_resource) and
            not os.path.samefile(peer_resource, compiler_resource), 'Runtime resources are not isolated')
    before = resource_observation(own, artifacts[resource])
    records[label] = {'before': before, 'integrity_verified': False}
    checkpoint(label + '-daemon', runtime_resources=records)
    try:
        return run_owned_phase(legacy, group, command, work, 'daemon', timeout)
    except BaseException as exc:
        records[label]['daemon_error'] = type(exc).__name__ + ': ' + str(exc)[:512]
        raise
    finally:
        try:
            after = resource_observation(own, artifacts[resource])
            records[label]['after'] = after
            records[label]['changed'] = after != before
            require(not os.path.samefile(own, compiler_resource) and not os.path.samefile(own, peer_resource) and
                    not os.path.samefile(peer_resource, compiler_resource),
                    'Runtime resource cache is shared')
            verify_linked_runtime(work, {binary: artifacts[binary]})
            verify_linked_runtime(dme.parent, artifacts)
            verify_linked_runtime(peer, {binary: artifacts[binary]})
            require(resource_observation(peer_resource, artifacts[resource]) == peer_expected,
                    'Other runtime resource cache changed')
            records[label]['integrity_verified'] = True
        except BaseException as exc:
            records[label]['integrity_error'] = type(exc).__name__ + ': ' + str(exc)[:512]
            raise
        finally:
            checkpoint(label + '-daemon', runtime_resources=records)


def parse_ldd(text):
    require('not found' not in text.lower(), 'Unresolved shared library')
    paths=[]
    for line in text.splitlines():
        match=re.search(r'(?:=>\s*)?(/\S+)\s+\(0x[0-9a-fA-F]+\)', line)
        if match:
            paths.append(match.group(1))
    require(paths, 'Missing dynamic loader observations')
    return paths


def collect_abi(legacy, group, scratch, binary):
    """After admission, trace dynamic loaders in-container; no BYOND process runs."""
    git=shutil.which('git')
    ldd=shutil.which('ldd')
    require(git and ldd, 'Pinned image must provide Git and ldd')
    targets=[Path(git), Path(sys.executable), *(binary/name for name in
             ('DreamMaker','DreamDaemon','libbyond.so','libext.so'))]
    directory=scratch/'abi'
    directory.mkdir()
    inventory={}
    for index,target in enumerate(targets):
        if index == 2:
            checkpoint('byond-abi-preflight')
        resolved=target.resolve()
        with resolved.open('rb') as stream:
            header=stream.read(20)
        require(len(header)==20 and header[:5]==b'\x7fELF\x01' and header[5]==1 and
                struct.unpack('<H',header[18:20])[0] == 3 and read_only(resolved),
                'Expected read-only i386 ELF: ' + str(target))
        run_owned_phase(legacy,group,[ldd,str(target)],directory,'abi-'+str(index),10)
        stdout=(directory/('abi-'+str(index)+'-stdout.log')).read_text(errors='replace')
        stderr=(directory/('abi-'+str(index)+'-stderr.log')).read_text(errors='replace')
        libraries=[]
        for raw in parse_ldd(stdout+'\n'+stderr):
            path=Path(raw).resolve()
            require(path.is_file() and read_only(path) and path.stat().st_size <= 32*1024**2,
                    'Untrusted dynamic library: ' + raw)
            libraries.append({'path':str(path),'sha256':file_hash(path),'bytes':path.stat().st_size})
        inventory[str(target)]={'sha256':file_hash(resolved),'bytes':resolved.stat().st_size,'libraries':libraries}
    return inventory


def validate_wildlife_receipt(row, head):
    require(type(row) is dict and row.get('head') == head and row.get('error') is None and
            row.get('port') == 0 and (row.get('byond_version'), row.get('byond_build')) == (516, 1688),
            'Wrong wildlife source/engine or failed fixture')
    require(row.get('cloud_wildlife_checks') == 9 and row.get('npc_checks') == 0,
            'Incomplete wildlife or mixed vendor assertions')


def timeout_handler(_signal, _frame):
    raise TimeoutError('Entire 600-second envelope expired')


def interrupt_handler(signum, _frame):
    raise InterruptedError('Supervisor received signal ' + str(signum))


def run_extended(args, scratch, binary, archive, group, envelope, identity, abi, began, npc, runtime, legacy):
    """One full-source observation daemon and one standalone geometry daemon."""
    checkpoint('extended-staging', suite='extended')
    ext = load_module('extended_contract', HERE / 'cloud_wildlife_extended.py')
    out = scratch / 'npc-smoke'
    manifest = npc.prepare(out)
    require(manifest['head'] == args.head, 'Staged commit differs from reviewed commit')
    ext.adapt_extended(out, manifest, npc.current)
    (out / 'cloud-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    stage, dme = out / 'stage', out / manifest['dme']
    geometry_stage = out/'geometry-stage'; geometry_stage.mkdir()
    geometry_inputs = {}
    for name in ('large_geometry.dm','large_geometry.dme'):
        rel='tests/subtile_movement/'+name
        data=subprocess.check_output(['git','-C',str(ROOT),'show',args.head+':'+rel],timeout=10)
        require(len(data) <= 1024**2 and data == (ROOT/rel).read_bytes(), 'Geometry source differs from exact Git: '+rel)
        (geometry_stage/name).write_bytes(data)
        geometry_inputs[name]={'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}
    (geometry_stage/'manifest.json').write_text(json.dumps({'head':args.head,'inputs':geometry_inputs},indent=2)+'\n')
    geometry_dme=geometry_stage/'large_geometry.dme'
    checkpoint('geometry-fixture-compile')
    runtime.verify_linux(binary, archive)
    geometry_build=run_owned_phase(legacy,group,[str(binary/'DreamMaker'),'-max_errors','0',str(geometry_dme)],geometry_stage,'compile',120)
    geometry_log=''.join((geometry_stage/('compile-'+part+'.log')).read_text(errors='replace') for part in ('stdout','stderr'))
    legacy.validate_compile(geometry_log,'large_geometry.dmb')
    for name, expected in geometry_inputs.items():
        p=geometry_stage/name
        require(p.stat().st_size == expected['bytes'] and file_hash(p) == expected['sha256'], 'Compiler changed geometry input: '+name)
    geometry=out/'geometry';geometry.mkdir()
    for extension in ('.dmb','.rsc'):
        source=geometry_dme.with_suffix(extension)
        if extension == '.rsc' and not source.exists():
            continue
        require(source.is_file() and 0 < source.stat().st_size <= MAX_DISK, 'Missing geometry artifact')
        shutil.copy2(source,geometry/source.name)
        require(file_hash(source)==file_hash(geometry/source.name), 'Geometry artifact copy mismatch')
    checkpoint('geometry-daemon')
    runtime.verify_linux(binary, archive)
    geometry_result=run_owned_phase(legacy,group,[str(binary/'DreamDaemon'),str(geometry/'large_geometry.dmb'),'59474','-ip','127.0.0.1',
        '-trusted','-params','tested_commit='+args.head,'-log','runtime.log'],geometry,'daemon',90)
    legacy.inspect_logs(geometry)
    require((geometry/'port-closed.txt').read_bytes()==b'closed\n' and (geometry/'result.txt').read_bytes()==b'PASS\n',
            'Geometry fixture result/port failed')
    geometry_receipt=json.loads((geometry/'receipt.json').read_text())
    ext.validate_geometry(geometry_receipt,args.head)
    checkpoint('geometry-complete', geometry_receipt_sha256=file_hash(geometry/'receipt.json'))
    checkpoint('extended-fixture-compile')
    build = run_owned_phase(legacy, group, [str(binary/'DreamMaker'), '-max_errors', '0', str(dme)], stage, 'compile', 120)
    compile_log = ''.join((stage/('compile-'+part+'.log')).read_text(errors='replace') for part in ('stdout','stderr'))
    legacy.validate_compile(compile_log, dme.with_suffix('.dmb').name)
    for rel, expected in manifest['stage_files'].items():
        p = stage/rel
        require(p.stat().st_size == expected['bytes'] and file_hash(p) == expected['sha256'], 'Compiler changed fixture input: '+rel)
    work, dmb, artifacts = prepare_linked_runtime(out, stage, dme, 'runtime')
    peer, peer_dmb, peer_artifacts = prepare_linked_runtime(out, stage, dme, 'runtime-wildlife')
    require(artifacts == peer_artifacts and not os.path.samefile(dmb.with_suffix('.rsc'),peer_dmb.with_suffix('.rsc')),
            'Extended resource copies differ or share an inode')
    checkpoint('extended-runtime-staged', runtime_artifacts=artifacts, resource_copies_independent=True)
    resource_states = {}
    checkpoint('extended-daemon')
    runtime.verify_linux(binary, archive)
    result = run_checked_runtime(legacy, group, [str(binary/'DreamDaemon'),str(dmb),'59474','-ip','127.0.0.1',
        '-trusted','-params','tested_commit='+args.head+';wildlife_extended=1','-log','runtime.log'],
        work,dme,peer,artifacts,artifacts[dme.with_suffix('.rsc').name],'extended',resource_states)
    legacy.inspect_logs(work)
    require((work/'port-closed.txt').read_bytes() == b'closed\n' and (work/'result.txt').read_bytes() == b'PASS\n',
            'Extended fixture result/port failed')
    receipt = json.loads((work/'receipt.json').read_text())
    ext.validate_extended(receipt,args.head)
    summary=dict(head=args.head,accepted=True,suite='extended',fixture_dme_only=True,identity=identity,abi=abi,envelope=envelope,
        compile=build,geometry_compile=geometry_build,artifacts=artifacts,resource_states=resource_states,
        results={'extended':dict(daemon=result,receipt_sha256=file_hash(work/'receipt.json')),
                 'geometry':dict(daemon=geometry_result,receipt_sha256=file_hash(geometry/'receipt.json'))},
        scope=ext.SCOPE,seconds=time.monotonic()-began)
    (scratch/'smoke-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps(summary))
    checkpoint('complete',outcome='passed',fixture_dme_only=True,suite='extended')


def run_bridge(args, scratch, binary, archive, group, envelope, identity, abi, began, npc, runtime, legacy):
    """One bounded full-source bridge fixture, without unrelated smoke reruns."""
    checkpoint('bridge-staging', suite='bridge')
    bridge = load_module('bridge_contract', HERE / 'cloud_wildlife_bridge.py')
    out = scratch / 'npc-smoke'
    manifest = npc.prepare(out)
    require(manifest['head'] == args.head, 'Staged commit differs from reviewed commit')
    bridge.adapt_bridge(out, manifest, npc.current)
    (out / 'cloud-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    stage, dme = out / 'stage', out / manifest['dme']
    checkpoint('bridge-fixture-compile')
    runtime.verify_linux(binary, archive)
    build = run_owned_phase(legacy, group, [str(binary/'DreamMaker'), '-max_errors', '0', str(dme)], stage, 'compile', 120)
    compile_log = ''.join((stage/('compile-'+part+'.log')).read_text(errors='replace') for part in ('stdout','stderr'))
    legacy.validate_compile(compile_log, dme.with_suffix('.dmb').name)
    for rel, expected in manifest['stage_files'].items():
        p = stage/rel
        require(p.stat().st_size == expected['bytes'] and file_hash(p) == expected['sha256'], 'Compiler changed fixture input: '+rel)
    work, dmb, artifacts = prepare_linked_runtime(out, stage, dme, 'runtime')
    peer, peer_dmb, peer_artifacts = prepare_linked_runtime(out, stage, dme, 'runtime-wildlife')
    require(artifacts == peer_artifacts and not os.path.samefile(dmb.with_suffix('.rsc'), peer_dmb.with_suffix('.rsc')),
            'Bridge resource copies differ or share an inode')
    checkpoint('bridge-runtime-staged', runtime_artifacts=artifacts, resource_copies_independent=True)
    resource_states = {}
    checkpoint('bridge-daemon')
    runtime.verify_linux(binary, archive)
    result = run_checked_runtime(legacy, group, [str(binary/'DreamDaemon'),str(dmb),'59474','-ip','127.0.0.1',
        '-trusted','-params','tested_commit='+args.head,'-log','runtime.log'],
        work,dme,peer,artifacts,artifacts[dme.with_suffix('.rsc').name],'bridge',resource_states)
    legacy.inspect_logs(work)
    require((work/'port-closed.txt').read_bytes() == b'closed\n' and (work/'result.txt').read_bytes() == b'PASS\n',
            'Bridge fixture result/port failed')
    receipt = json.loads((work/'receipt.json').read_text())
    bridge.validate_bridge(receipt,args.head)
    summary=dict(head=args.head,accepted=True,suite='bridge',fixture_dme_only=True,identity=identity,abi=abi,envelope=envelope,
        compile=build,artifacts=artifacts,resource_states=resource_states,
        results={'bridge':dict(daemon=result,receipt_sha256=file_hash(work/'receipt.json'))},
        scope=bridge.SCOPE,seconds=time.monotonic()-began)
    (scratch/'smoke-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps(summary))
    checkpoint('complete',outcome='passed',fixture_dme_only=True,suite='bridge')


def run_scheduler(args,scratch,binary,archive,group,envelope,identity,abi,began,npc,runtime,legacy):
    """One fixture build, two sequential fresh daemons, paired insect oracle."""
    checkpoint('scheduler-staging',suite='scheduler')
    scheduler=load_module('scheduler_contract',HERE/'cloud_wildlife_scheduler_draft.py')
    out=scratch/'npc-smoke';manifest=npc.prepare(out)
    require(manifest['head']==args.head,'Staged commit differs from reviewed commit')
    scheduler.adapt_scheduler(out,manifest,npc.current)
    (out/'cloud-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    stage=out/'stage';dme=out/manifest['dme']
    checkpoint('scheduler-fixture-compile')
    runtime.verify_linux(binary,archive)
    build=run_owned_phase(legacy,group,[str(binary/'DreamMaker'),'-max_errors','0',str(dme)],stage,'compile',120)
    log=''.join((stage/('compile-'+part+'.log')).read_text(errors='replace') for part in ('stdout','stderr'))
    legacy.validate_compile(log,dme.with_suffix('.dmb').name)
    for rel,expected in manifest['stage_files'].items():
        path=stage/rel
        require(path.stat().st_size==expected['bytes'] and file_hash(path)==expected['sha256'],'Compiler changed fixture input: '+rel)
    work,dmb,artifacts=prepare_linked_runtime(out,stage,dme,'runtime')
    peer,peer_dmb,peer_artifacts=prepare_linked_runtime(out,stage,dme,'runtime-wildlife')
    resource=dme.with_suffix('.rsc').name
    require(artifacts==peer_artifacts and not os.path.samefile(dmb.with_suffix('.rsc'),peer_dmb.with_suffix('.rsc')),
            'Scheduler runtime resource copies differ or share an inode')
    checkpoint('scheduler-runtime-staged',runtime_artifacts=artifacts,resource_copies_independent=True)
    states={};results={};receipts={};peer_states={'legacy':dict(artifacts[resource]),'smooth':dict(artifacts[resource])}
    for label,folder,local_dmb,other,other_label in (('legacy',work,dmb,peer,'smooth'),('smooth',peer,peer_dmb,work,'legacy')):
        checkpoint('scheduler-'+label+'-daemon')
        require(not any(folder.rglob('*.sav')),'Scheduler daemon must begin with fresh save state')
        runtime.verify_linux(binary,archive)
        params='tested_commit='+args.head+';scheduler_mode='+label
        result=run_checked_runtime(legacy,group,[str(binary/'DreamDaemon'),str(local_dmb),'59474','-ip','127.0.0.1',
            '-trusted','-params',params,'-log','runtime.log'],folder,dme,other,artifacts,peer_states[other_label],label,states)
        peer_states[label]=dict(states[label]['after'])
        legacy.inspect_logs(folder)
        require((folder/'port-closed.txt').read_bytes()==b'closed\n' and (folder/'result.txt').read_bytes()==b'PASS\n',
                'Scheduler fixture result/port failed: '+label)
        path=folder/'receipt.json'
        require(path.stat().st_size<=4*1024**2,'Scheduler receipt exceeds evidence member bound')
        receipts[label]=json.loads(path.read_text())
        scheduler.validate_run(receipts[label],args.head,label)
        results[label]=dict(daemon=result,receipt_sha256=file_hash(path))
    comparison=scheduler.compare_pair(receipts['legacy'],receipts['smooth'],args.head)
    summary=dict(head=args.head,accepted=True,suite='scheduler',fixture_dme_only=True,identity=identity,abi=abi,envelope=envelope,
        compile=build,artifacts=artifacts,resource_states=states,results=results,comparison=comparison,
        scope=scheduler.SCOPE,seconds=time.monotonic()-began)
    (scratch/'smoke-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps(summary))
    checkpoint('complete',outcome='passed',fixture_dme_only=True,suite='scheduler')


def run_random_cadence(args,scratch,binary,archive,group,envelope,identity,abi,began,npc,runtime,legacy):
    """Two exact source variants, three isolated daemons; observations only."""
    contract=load_module('random_contract',HERE/'random_cadence_contract.py')
    settings=contract.budget()
    require(args.work_deadline is not None and time.monotonic()+settings['maximum_accounted_work_seconds'] <= args.work_deadline,
            'Insufficient shared deadline for bounded comparison')
    random_began=time.monotonic();child_elapsed=0.0
    def check_setup():
        return contract.setup_used(time.monotonic()-random_began,child_elapsed)
    tick=contract.selection(args.suite)
    parent=contract.HANDOFF_BASE
    git=['git','-C',str(ROOT)]
    require(subprocess.check_output(git+['rev-parse',parent+'^{tree}'],timeout=10).decode().strip()==contract.HANDOFF_BASE_TREE,
            'Handoff baseline tree mismatch')
    require(subprocess.run(git+['merge-base','--is-ancestor',parent,args.head],capture_output=True,timeout=10).returncode==0,
            'Fixture head must descend from the published compile parent')
    changed=set(subprocess.check_output(git+['diff','--name-only',parent,args.head],timeout=30).decode().splitlines())
    require(changed==contract.HANDOFF_FILES,
            'Unexpected changes in comparison head')
    require(subprocess.check_output(git+['rev-parse',args.head+':'+contract.CANDIDATE_TEST],timeout=10).decode().strip()
            ==contract.CANDIDATE_TEST_BLOB,'Candidate regression test blob differs')
    originals={};candidate_blobs={}
    for rel in contract.SPECIES:
        require(subprocess.check_output(git+['rev-parse',parent+':'+rel],timeout=10).decode().strip()
                ==contract.CANDIDATE_BLOBS[rel],'Baseline species blob differs')
        originals[rel]=subprocess.check_output(git+['show',parent+':'+rel],timeout=10)
        require(subprocess.check_output(git+['rev-parse',args.head+':'+rel],timeout=10).decode().strip()
                ==contract.CANDIDATE_BLOBS[rel],'Candidate species blob differs')
        candidate_blobs[rel]=subprocess.check_output(git+['show',args.head+':'+rel],timeout=10)
    for revision, blob, outmap in ((parent,contract.PARENT_MOVEMENT_BLOB,originals),
                                   (args.head,contract.CANDIDATE_MOVEMENT_BLOB,candidate_blobs)):
        require(subprocess.check_output(git+['rev-parse',revision+':'+contract.MOVEMENT],timeout=10).decode().strip()==blob,
                'Handoff movement blob differs')
        outmap[contract.MOVEMENT]=subprocess.check_output(git+['show',revision+':'+contract.MOVEMENT],timeout=10)
    require(subprocess.check_output(git+['rev-parse',args.head+':'+contract.PARENT_FIXTURE],timeout=10).decode().strip()
            ==contract.PARENT_MOVEMENT_BLOB,'Stored parent fixture blob differs')
    checkpoint('random-staging',suite=args.suite)
    out=scratch/'npc-smoke';manifest=npc.prepare(out)
    require(manifest['head']==args.head,'Staged head differs')
    parent_out,parent_manifest=contract.prepare_pair(out,manifest,npc.current,originals,candidate_blobs)
    for label,folder,m in (('parent',parent_out,parent_manifest),('candidate',out,manifest)):
        m['random_source_variant']=label;m['parent_commit']=parent;m['candidate_local_commit']=contract.LOCAL_CANDIDATE
        m['candidate_blobs']=contract.CANDIDATE_BLOBS
        m['movement_blobs']={'parent':contract.PARENT_MOVEMENT_BLOB,'candidate':contract.CANDIDATE_MOVEMENT_BLOB}
        (folder/'cloud-manifest.json').write_text(json.dumps(m,indent=2)+'\n')
    check_setup()
    def check_inputs(folder,m):
        for rel,expected in m['stage_files'].items():
            p=folder/'stage'/rel
            require(p.is_file() and p.stat().st_size==expected['bytes'] and file_hash(p)==expected['sha256'],
                    'Fixture input changed: '+rel)
    builds={}
    for label,folder,m in (('parent',parent_out,parent_manifest),('candidate',out,manifest)):
        checkpoint('random-'+label+'-compile')
        stage=folder/'stage';dme=folder/m['dme']
        check_inputs(parent_out,parent_manifest);check_inputs(out,manifest)
        runtime.verify_linux(binary,archive)
        builds[label]=run_owned_phase(legacy,group,[str(binary/'DreamMaker'),'-max_errors','0',str(dme)],
                                      stage,'compile',contract.COMPILE_SECONDS)
        require(contract.finite(builds[label].get('seconds')) and 0<=builds[label]['seconds']<=contract.COMPILE_SECONDS,
                'Invalid compile duration')
        child_elapsed+=builds[label]['seconds']
        log=''.join((stage/('compile-'+part+'.log')).read_text(errors='replace') for part in ('stdout','stderr'))
        legacy.validate_compile(log,dme.with_suffix('.dmb').name)
        check_inputs(parent_out,parent_manifest);check_inputs(out,manifest)
        check_setup()
    stages={}
    for label,folder,m in (('parent',parent_out,parent_manifest),('candidate',out,manifest)):
        dme=folder/m['dme'];stage=folder/'stage'
        work,dmb,artifacts=prepare_linked_runtime(folder,stage,dme,'runtime')
        peer,peer_dmb,peer_artifacts=prepare_linked_runtime(folder,stage,dme,'runtime-wildlife')
        require(artifacts==peer_artifacts and not os.path.samefile(dmb.with_suffix('.rsc'),peer_dmb.with_suffix('.rsc')),
                'Fixture resource copies differ or share inode')
        stages[label]={'dme':dme,'work':work,'dmb':dmb,'peer':peer,'peer_dmb':peer_dmb,'artifacts':artifacts}
    check_setup()
    results={};receipts={};states={}
    for mode,stage_label,swap in (('legacy','parent',False),('parent','parent',True),('candidate','candidate',False)):
        stage=stages[stage_label];work=stage['peer'] if swap else stage['work'];peer=stage['work'] if swap else stage['peer']
        dmb=stage['peer_dmb'] if swap else stage['dmb'];artifacts=stage['artifacts'];dme=stage['dme']
        resource=dme.with_suffix('.rsc').name
        expected_peer=states['legacy']['after'] if swap else dict(artifacts[resource])
        checkpoint('random-'+mode+'-daemon')
        require(not any(work.rglob('*.sav')),'Random daemon must begin with fresh save state')
        runtime.verify_linux(binary,archive)
        params='tested_commit='+args.head+';random_mode='+mode+';random_tick='+str(tick)
        result=run_checked_runtime(legacy,group,[str(binary/'DreamDaemon'),str(dmb),'59474','-ip','127.0.0.1',
            '-trusted','-params',params,'-log','runtime.log'],work,dme,peer,artifacts,expected_peer,mode,states,
            timeout=contract.DAEMON_SECONDS)
        require(contract.finite(result.get('seconds')) and 0<=result['seconds']<=contract.DAEMON_SECONDS,
                'Invalid daemon duration')
        child_elapsed+=result['seconds']
        legacy.inspect_logs(work)
        require((work/'port-closed.txt').read_bytes()==b'closed\n' and (work/'result.txt').read_bytes()==b'PASS\n',
                'Random fixture result/port failed: '+mode)
        path=work/'receipt.json';require(path.stat().st_size<=contract.MAX_RECEIPT,'Random receipt byte bound')
        receipts[mode]=json.loads(path.read_text());contract.validate(receipts[mode],args.head,mode,tick)
        results[mode]={'daemon':result,'receipt_sha256':file_hash(path)}
        check_inputs(parent_out,parent_manifest);check_inputs(out,manifest)
        check_setup()
    comparison=contract.compare(receipts,args.head,tick)
    comparison_elapsed=time.monotonic()-random_began
    setup_seconds=contract.setup_used(comparison_elapsed,child_elapsed)
    summary=dict(head=args.head,suite=args.suite,fixture_dme_only=True,observation_complete=True,
                 parity_established=False,tick=tick,budget=settings,identity=identity,abi=abi,envelope=envelope,
                 setup_seconds=setup_seconds,comparison_elapsed=comparison_elapsed,child_elapsed=child_elapsed,
                 compiles=builds,artifacts={k:v['artifacts'] for k,v in stages.items()},resource_states=states,
                 results=results,comparison=comparison,scope=contract.SCOPE,seconds=time.monotonic()-began)
    (scratch/'smoke-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    checkpoint('complete',outcome='passed',fixture_dme_only=True,suite=args.suite)


def run_production_compile(args,scratch,binary,archive,group,envelope,identity,abi,began,runtime,legacy):
    """Compile the unmodified complete tracked game DME; never launch it."""
    production=load_module('production_stage',HERE/'cloud_production_compile.py')
    checkpoint('production-staging',suite='production_compile',fixture_dme_only=False)
    out=scratch/'production'
    manifest=production.prepare(ROOT,out,args.head)
    (out/'source-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    require_only_supervisor(group)
    stage=out/'stage';dme=stage/'civ13.dme'
    checkpoint('production-compile')
    runtime.verify_linux(binary,archive)
    result=run_owned_phase(legacy,group,[str(binary/'DreamMaker'),'-max_errors','0',str(dme)],stage,'compile',120)
    log=''.join((stage/('compile-'+part+'.log')).read_text(errors='replace') for part in ('stdout','stderr'))
    legacy.validate_compile(log,'civ13.dmb')
    production.verify_source(stage,manifest)
    (out/'source-compact.json').write_text(json.dumps(production.compact_manifest(manifest),separators=(',',':'))+'\n')
    artifacts={}
    for suffix in ('.dmb','.rsc'):
        path=dme.with_suffix(suffix)
        require(path.is_file() and 0 < path.stat().st_size <= MAX_DISK,'Missing production compiler artifact')
        artifacts[path.name]={'bytes':path.stat().st_size,'sha256':file_hash(path)}
    summary=dict(head=args.head,tree=manifest['tree'],accepted=True,suite='production_compile',fixture_dme_only=False,
        scope='unmodified full tracked production DME compile only; no daemon or game acceptance',
        source_manifest_sha256=file_hash(out/'source-manifest.json'),source_file_count=len(manifest['files']),
        source_bytes=manifest['bytes'],compile=result,artifacts=artifacts,identity=identity,abi=abi,envelope=envelope,
        seconds=time.monotonic()-began)
    (scratch/'smoke-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps(summary))
    checkpoint('complete',outcome='passed',fixture_dme_only=False,suite='production_compile')


def main():
    global RUN_ROOT, RUN_STARTED, SCRATCH_METER
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--head', required=True, help='full reviewed exact Git commit')
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--byond-archive', required=True, type=Path)
    parser.add_argument('--scratch-root', required=True, type=Path,
                        help='fresh dedicated <=1 GiB mount; evidence remains inside it')
    parser.add_argument('--reviewed-cloud-envelope', action='store_true',
                        help='operator confirms separate cloud isolation review')
    parser.add_argument('--suite', choices=('random05','random10','cardinal05','cardinal10','transition05','bump05','pair05','ordinary05','group05'), required=True)
    parser.add_argument('--work-deadline', type=float)
    args = parser.parse_args()
    require(sys.platform == 'linux', 'Cloud smoke supports Linux only')
    require(args.reviewed_cloud_envelope, 'Separate cloud envelope review is required')
    signal.signal(signal.SIGALRM, timeout_handler)
    signal.signal(signal.SIGTERM, interrupt_handler)
    signal.signal(signal.SIGINT, interrupt_handler)
    signal.alarm(MAX_SECONDS)
    began = time.monotonic()
    RUN_STARTED = began
    scratch, binary, archive = (args.scratch_root.resolve(), args.byond_bin.resolve(), args.byond_archive.resolve())
    require(scratch.is_dir() and binary.is_dir() and archive.is_file(), 'Missing reviewed paths')
    require(not ROOT.is_relative_to(scratch) and not scratch.is_relative_to(ROOT) and not binary.is_relative_to(scratch) and
            not archive.is_relative_to(scratch), 'Scratch must not contain source or toolchain')
    group, envelope = check_environment(scratch, binary, archive)
    RUN_ROOT = scratch
    SCRATCH_METER = ScratchMeter(scratch)
    SCRATCH_METER.start()
    checkpoint('envelope-accepted', head=args.head, envelope=envelope)
    home, temp = scratch / 'home', scratch / 'tmp'
    home.mkdir()
    temp.mkdir()
    # Native children receive only these values, never the caller's credentials.
    os.environ.clear()
    os.environ.update({'PATH': '/usr/bin:/bin', 'HOME': str(home), 'TMPDIR': str(temp),
                       'LANG': 'C.UTF-8', 'LD_LIBRARY_PATH': str(binary)})
    check_clean_exact(args.head)
    checkpoint('staging')
    npc = load_module('cloud_npc', HERE / 'run-npc.py')
    runtime = load_module('cloud_byond_runtime', ROOT / 'scripts/byond_runtime.py')
    legacy = npc.current.legacy
    identity = runtime.verify_linux(binary, archive)
    require(file_hash(archive) == EXPECTED_ARCHIVE, 'Wrong archive bytes')
    checkpoint('base-image-preflight')
    abi=collect_abi(legacy,group,scratch,binary)
    if args.suite == 'extended':
        return run_extended(args,scratch,binary,archive,group,envelope,identity,abi,began,npc,runtime,legacy)
    if args.suite == 'bridge':
        return run_bridge(args,scratch,binary,archive,group,envelope,identity,abi,began,npc,runtime,legacy)
    if args.suite == 'scheduler':
        return run_scheduler(args,scratch,binary,archive,group,envelope,identity,abi,began,npc,runtime,legacy)
    if args.suite == 'group05':
        worker = load_module('group_worker', HERE/'group_worker.py')
        return worker.run(sys.modules[__name__],args,scratch,binary,archive,group,envelope,identity,abi,began,npc,runtime,legacy)
    if args.suite == 'ordinary05':
        worker = load_module('ordinary_bump_worker', HERE/'ordinary_bump_worker.py')
        return worker.run(sys.modules[__name__],args,scratch,binary,archive,group,envelope,identity,abi,began,npc,runtime,legacy)
    if args.suite == 'pair05':
        worker = load_module('pair_worker', HERE/'pair_worker.py')
        return worker.run(sys.modules[__name__],args,scratch,binary,archive,group,envelope,identity,abi,began,npc,runtime,legacy)
    if args.suite == 'bump05':
        worker = load_module('bump_worker', HERE/'bump_worker.py')
        return worker.run(sys.modules[__name__],args,scratch,binary,archive,group,envelope,identity,abi,began,npc,runtime,legacy)
    if args.suite == 'transition05':
        worker = load_module('transition_worker', HERE/'transition_worker.py')
        return worker.run(sys.modules[__name__],args,scratch,binary,archive,group,envelope,identity,abi,began,npc,runtime,legacy)
    if args.suite in ('cardinal05','cardinal10'):
        worker = load_module('cardinal_worker', HERE/'cardinal_worker.py')
        return worker.run(sys.modules[__name__],args,scratch,binary,archive,group,envelope,identity,abi,began,npc,runtime,legacy)
    if args.suite in ('random05','random10'):
        return run_random_cadence(args,scratch,binary,archive,group,envelope,identity,abi,began,npc,runtime,legacy)
    if args.suite == 'production_compile':
        return run_production_compile(args,scratch,binary,archive,group,envelope,identity,abi,began,runtime,legacy)
    out = scratch / 'npc-smoke'
    manifest = npc.prepare(out)
    require(manifest['head'] == args.head, 'Staged commit differs from reviewed commit')
    require_only_supervisor(group)
    stage, dme = out / 'stage', out / manifest['dme']
    npc.current.adapt(out, manifest, 'tests/human_subtile/probe.dm',
        '\t\t\tnpc_subtile_fixture()',
        '\t\t\tif (world.params["cloud_wildlife"])\n\t\t\t\tcloud_wildlife_fixture()\n\t\t\telse\n\t\t\t\tnpc_subtile_fixture()')
    npc.current.adapt(out, manifest, 'tests/human_subtile/probe.dm',
        '"npc_checks" = npc_subtile_checks,',
        '"cloud_wildlife_checks" = cloud_wildlife_checks, "npc_checks" = npc_subtile_checks,')
    npc.current.adapt(out, manifest, 'tests/human_subtile/probe.dm',
        '"scope" = "actual human/codec; headless authority adapter"',
        '"scope" = (world.params["cloud_wildlife"] ? "wildlife owner/contact helper only; no Life/bite acceptance" : "vendor AI pulses and owned-offset codec; no wildlife acceptance")')
    with dme.open('a', encoding='utf-8') as stream:
        stream.write('\n#include "tests\\human_subtile\\cloud_wildlife.dm"\n')
    for rel in ('tests/human_subtile/probe.dm', 'human_subtile.dme'):
        path = stage / rel
        manifest['stage_files'][rel] = dict(bytes=path.stat().st_size, sha256=file_hash(path))
    manifest['cloud_scope'] = 'two separate vendor and minimal wildlife-owner fixtures'
    (out / 'cloud-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    runtime.verify_linux(binary, archive)
    checkpoint('fixture-compile')
    compile_result = run_owned_phase(legacy, group, [str(binary / 'DreamMaker'), '-max_errors', '0', str(dme)], stage, 'compile', 120)
    log = ''.join((stage / ('compile-' + part + '.log')).read_text(errors='replace') for part in ('stdout', 'stderr'))
    legacy.validate_compile(log, dme.with_suffix('.dmb').name)
    for rel, expected in manifest['stage_files'].items():
        path = stage / rel
        require(path.stat().st_size == expected['bytes'] and file_hash(path) == expected['sha256'],
                'Compiler changed fixture input: ' + rel)
    # Separate fresh save/log directories share only the read-only DMB. The
    # resource caches are isolated and writable within the same tmpfs quota.
    vendor_work, vendor_dmb, artifacts = prepare_linked_runtime(out, stage, dme, 'runtime')
    wild_work, wild_dmb, wild_artifacts = prepare_linked_runtime(out, stage, dme, 'runtime-wildlife')
    require(artifacts == wild_artifacts, 'Fixture artifact identities differ')
    checkpoint('runtime-staged', runtime_artifacts=artifacts,
               resource_copies_independent=not os.path.samefile(vendor_dmb.with_suffix('.rsc'), wild_dmb.with_suffix('.rsc')))
    require(RUN_STATE['resource_copies_independent'], 'Runtime resource copies share an inode')
    results = {}
    resource_states = {}
    resource_name = dme.with_suffix('.rsc').name
    peer_states = {'vendor': dict(artifacts[resource_name]), 'wildlife': dict(artifacts[resource_name])}
    for label, work, dmb in (('vendor', vendor_work, vendor_dmb), ('wildlife', wild_work, wild_dmb)):
        checkpoint(label + '-daemon')
        require(not any(work.rglob('*.sav')), 'Runtime save directory must begin empty')
        verify_linked_runtime(work, artifacts)
        runtime.verify_linux(binary, archive)
        params = 'tested_commit=' + args.head + (';cloud_wildlife=1' if label == 'wildlife' else '')
        peer_label, peer_work = ('wildlife', wild_work) if label == 'vendor' else ('vendor', vendor_work)
        result = run_checked_runtime(legacy, group, [str(binary / 'DreamDaemon'), str(dmb), '59474', '-ip', '127.0.0.1',
            '-trusted', '-params', params, '-log', 'runtime.log'], work, dme, peer_work, artifacts,
            peer_states[peer_label], label, resource_states)
        peer_states[label] = dict(resource_states[label]['after'])
        legacy.inspect_logs(work)
        require((work / 'port-closed.txt').read_bytes() == b'closed\n', 'Missing fixture port closure')
        require((work / 'result.txt').read_bytes() == b'PASS\n', 'Missing exact PASS marker')
        receipt_path = work / 'receipt.json'
        require(receipt_path.stat().st_size <= 64 * 1024, 'Receipt exceeds bound')
        receipt = json.loads(receipt_path.read_text())
        if label == 'vendor':
            npc.validate_npc_receipt(receipt, args.head)
            require(receipt.get('cloud_wildlife_checks') == 0, 'Vendor suite unexpectedly ran wildlife fixture')
            require(receipt.get('scope') == 'vendor AI pulses and owned-offset codec; no wildlife acceptance', 'Incorrect vendor scope')
        else:
            validate_wildlife_receipt(receipt, args.head)
            require(receipt.get('scope') == 'wildlife owner/contact helper only; no Life/bite acceptance', 'Incorrect wildlife scope')
        results[label] = dict(daemon=result, receipt_sha256=file_hash(receipt_path))
    summary = dict(head=args.head, accepted=True, identity=identity, abi=abi, envelope=envelope,
        compile=compile_result, results=results, artifacts=artifacts, resource_states=resource_states,
        scope='Vendor 46 and separate nine minimal owner/contact assertions; no bite, disease or runtime save acceptance beyond vendor codec.',
        seconds=time.monotonic() - began,
        limitation='Provider must independently verify sealed namespace, no host socket mounts, and container cleanup.')
    (scratch / 'smoke-summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary))
    checkpoint('complete', outcome='passed', fixture_dme_only=True)


def guarded_entry():
    error = None
    try:
        main()
    except BaseException as exc:
        error = exc
        # No environment, arguments or traceback contents are captured here.
        try:
            checkpoint(RUN_STATE['phase'], outcome='failed', error_type=type(exc).__name__,
                       error_message=str(exc)[:1024])
        except BaseException as receipt_error:
            print('HARNESS_RECEIPT_FAILED ' + type(receipt_error).__name__, file=sys.stderr, flush=True)
    finally:
        # The bounded log stream survives the tmpfs and worker's exit.
        if RUN_ROOT is not None and RUN_STARTED is not None:
            try:
                scratch_observation = SCRATCH_METER.finish() if SCRATCH_METER else None
                emit_package(RUN_ROOT, RUN_STATE['outcome'], scratch_observation)
            except BaseException as hold_error:
                print('HARNESS_EVIDENCE_UNAVAILABLE ' + type(hold_error).__name__, file=sys.stderr, flush=True)
        signal.alarm(0)
    if error is not None:
        raise error


if __name__ == '__main__':
    guarded_entry()
