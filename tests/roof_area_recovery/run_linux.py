"""Prepare, or explicitly run in reviewed secret-free Linux PR CI, roof recovery.

No workflow invokes this runner yet. Preparation never launches BYOND. Execution
reuses the accepted collector's retained-leader/group/socket cleanup primitives.
No production data/config, client, Topic, ACL change or Desktop execution.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
PORT = 19327
ENGINE = {'DreamMaker': 'b9f175ac9a24662a9ba6fa64652b669aff77ff4787b81b84497dff544f166677',
          'DreamDaemon': '112b3f4e74b95d82b7e117de35fae70f773e4b770a3302f8c0c33758f9e2f4e1'}
NEGATIVES = ('missing-roof', 'wrong-base', 'missing-scalar', 'disabled-roof', 'unrelated-area',
             'duplicate-area', 'duplicate-placement', 'empty-instance', 'postflight-empty')
PHASES = {'main': ('write', 'read', *NEGATIVES, 'write-covered', 'read-covered'),
          'projection': ('write-roofed', 'old-defect'),
          'cleanup-namespace': ('write-roofed', 'read')}
CAPS = dict(compiler_seconds=180, child_seconds=60, cleanup_seconds=30,
            process_bytes=1073741824, watcher_bytes=134217728, artifact_bytes=125829120,
            log_bytes=1048576, receipt_bytes=2097152, inventory_entries=8192,
            cpu_seconds=60, closure_seconds=10, disk_free_bytes=6442450944)


def need(value, message):
    if not value:
        raise RuntimeError(message)


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec); spec.loader.exec_module(result)
    return result


def primitives():
    return module('roof_owned_linux', ROOT / 'tests/nomads_lifecycle/run_variable_probe_linux.py')


def git(*args):
    return subprocess.check_output(['git', '-c', 'safe.directory=' + ROOT.as_posix(), *args],
                                   cwd=ROOT, timeout=30)


def atlas_command(output):
    # -I deliberately omits script-directory imports. Add only this reviewed
    # repository scripts directory, rather than inheriting PYTHONPATH or HOME.
    bootstrap = ('import pathlib,runpy,sys;'
                 'sys.path.insert(0,str(pathlib.Path(sys.argv[1]).resolve().parent));'
                 'sys.argv=sys.argv[1:];runpy.run_path(sys.argv[0],run_name="__main__")')
    return [sys.executable,'-I','-B','-c',bootstrap,str(ROOT/'scripts/build-crafting-atlas.py'),
            '--catalog-only','--game-catalog',str(output)]


def execution_contract(request, packet_dir):
    """Stable code/resource identity; UUID filenames are not an authorization."""
    prepared = packet_dir/request['prepared_directory']
    probe = next(prepared.glob('*_probe.dm'))
    prefix = probe.name.removesuffix('_probe.dm')
    roles = {p.name.removeprefix(prefix):sha(p) for p in prepared.glob('*.dm')}
    dme = (prepared/'probe.dme').read_text(encoding='utf-8').replace(prefix,'<generated-source>')
    contract = dict(head=request['head'],variant=request['variant'],caps=request['caps'],
        modes=request['modes'],port=request['port'],outer_seconds=request['outer_seconds'],
        binary_sha256=request['binary_sha256'],source_sha256=request['source_sha256'],
        code_roles_sha256=roles,dme_sha256=hashlib.sha256(dme.encode()).hexdigest(),
        atlas_sha256=sha(packet_dir/'expected-crafting-atlas.json'))
    return hashlib.sha256(json.dumps(contract,sort_keys=True,separators=(',',':')).encode()).hexdigest()


def claim_request(request_sha256, head, output, temporary):
    """One attempt per request hash on this CI runner, even across outputs/copies."""
    need(len(request_sha256)==64 and all(c in '0123456789abcdef' for c in request_sha256), 'Claim hash required')
    temporary=temporary.resolve(strict=True); output=output.resolve()
    need(output.is_relative_to(temporary) and output!=temporary, 'Claim output outside runner temp')
    folder=temporary/'roof-area-request-claims'
    need(not folder.is_symlink(), 'Claim directory symlink refused')
    folder.mkdir(exist_ok=True)
    need(folder.resolve().parent==temporary, 'Claim directory escaped runner temp')
    path=folder/(request_sha256+'.json')
    payload=dict(request_sha256=request_sha256,head=head,output=str(output),not_a_grant=True,
        github_run_id=os.environ.get('GITHUB_RUN_ID'),github_run_attempt=os.environ.get('GITHUB_RUN_ATTEMPT'))
    try:
        with path.open('x',encoding='utf-8') as stream: json.dump(payload,stream,sort_keys=True)
    except FileExistsError as error:
        raise RuntimeError('Request already consumed on this runner; preserve the claim and reconcile outcome') from error
    return path


def tree_hashes(head):
    """Hash canonical Git blobs in bounded chunks, portable across checkout EOLs."""
    rows = git('ls-tree', '-rz', '--full-tree', head).split(b'\0')
    result = {}; inputs = []
    for row in rows:
        if not row: continue
        metadata, name = row.split(b'\t', 1); mode, kind, oid = metadata.split()
        name = name.decode('utf-8'); parts = PurePosixPath(name)
        need(mode in (b'100644', b'100755') and kind == b'blob' and not parts.is_absolute()
             and '..' not in parts.parts and '\\' not in name, 'Unsupported source path/mode')
        inputs.append((oid,name))
    need(len(inputs) <= 8192, 'Source inventory bound')
    # A finite stdin file avoids thousands of Windows pipe round trips while
    # still streaming each source blob, never retaining the source tree in RAM.
    with tempfile.TemporaryFile() as requests:
        requests.write(b''.join(oid+b'\n' for oid,_ in inputs)); requests.seek(0)
        with subprocess.Popen(['git', '-c', 'safe.directory=' + ROOT.as_posix(), 'cat-file', '--batch'],
                              cwd=ROOT, stdin=requests, stdout=subprocess.PIPE) as proc:
            for oid,name in inputs:
                header = proc.stdout.readline().split()
                need(len(header) == 3 and header[0] == oid and header[1] == b'blob', 'Git blob identity differs')
                remaining = int(header[2]); digest = hashlib.sha256()
                while remaining:
                    data = proc.stdout.read(min(1048576, remaining))
                    need(data, 'Truncated Git source blob'); digest.update(data); remaining -= len(data)
                need(proc.stdout.read(1) == b'\n', 'Invalid Git blob terminator')
                result[name] = digest.hexdigest()
            need(proc.wait(timeout=10) == 0, 'Source inventory failed')
    return result


def prepare(packet_dir, head, variant):
    """Offline immutable request, not a grant. No compiler/daemon or socket call."""
    need(variant in PHASES and len(head) == 40 and all(c in '0123456789abcdef' for c in head), 'Exact head/variant required')
    need(git('rev-parse', 'HEAD').decode().strip() == head, 'Preparation source head differs')
    need(not packet_dir.exists(), 'New packet directory required')
    packet_dir.mkdir(parents=True)
    temporary = packet_dir / 'preparer-temp'; temporary.mkdir()
    env = dict(os.environ, TMPDIR=str(temporary), TEMP=str(temporary), TMP=str(temporary))
    command = [sys.executable, '-I', '-B', str(ROOT/'tests/world_save/run-durable-world.py'), '--roof-areas', '--prepare-only']
    if variant != 'main': command += ['--roof-control', variant]
    child = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True, timeout=40, check=True)
    source = Path(child.stdout.split('Retained evidence: ', 1)[1].splitlines()[0]).resolve(strict=True)
    need(source.is_relative_to(temporary.resolve()), 'Prepared sources escaped packet')
    prepared = {p.relative_to(packet_dir).as_posix(): sha(p) for p in source.iterdir() if p.is_file()}
    need(len(prepared) <= 10 and sum(p.stat().st_size for p in source.iterdir() if p.is_file()) < 4194304, 'Prepared source bound')
    expected = tree_hashes(head)
    # The normal CI bootstrap derives this public resource. Reproduce the same
    # deterministic output separately, never overwrite the source checkout.
    atlas = packet_dir/'expected-crafting-atlas.json'
    atlas_result = subprocess.run(atlas_command(atlas), cwd=ROOT,capture_output=True,text=True,timeout=40)
    (packet_dir/'atlas-preparation.stdout.log').write_text(atlas_result.stdout,encoding='utf-8')
    (packet_dir/'atlas-preparation.stderr.log').write_text(atlas_result.stderr,encoding='utf-8')
    need(atlas_result.returncode == 0, 'Public catalog preparation failed; retained logs explain the failure')
    atlas.write_text(atlas.read_text(encoding='utf-8'), encoding='utf-8', newline='\n')
    expected['UI/crafting-atlas.json'] = sha(atlas)
    prepared[atlas.name] = sha(atlas)
    for name in ('atlas-preparation.stdout.log','atlas-preparation.stderr.log'):
        prepared[name] = sha(packet_dir/name)
    request = dict(kind='review-only-synthetic-roof-request-v1', head=head, variant=variant,
        caller_sha256=expected[Path(__file__).relative_to(ROOT).as_posix()], prepared=prepared, prepared_directory=source.relative_to(packet_dir).as_posix(),
        source_sha256=expected, binary_sha256=ENGINE, port=PORT, caps=CAPS,
        modes=list(PHASES[variant]), outer_seconds=990 if variant == 'main' else 330,
        native_executed=False, grant_created=False,
        engine_pin_evidence='Civ13/Civ13 CI40019637842 artifact12530610922 source-manifest.json')
    request['execution_contract_sha256']=execution_contract(request,packet_dir)
    (packet_dir/'request.json').write_text(json.dumps(request, indent=2), encoding='utf-8')
    return request


def socket_contract(rows, runtime, closed):
    if closed or not runtime:
        need(not rows, 'Owned sockets remain after closure or during compile')
    else:
        need(len(rows) <= 1 and all(r['protocol'] == 'tcp' and r['state'] == 'listen'
             and r['address'] == '127.0.0.1' and r['port'] == PORT for r in rows), 'Unexpected startup socket')


def native_flag(value):
    # BYOND json_encode emits numeric 0/1. Accept only that exact integer
    # domain or JSON booleans, never general truthiness or numeric coercion.
    need(type(value) in (bool,int) and value in (0,1), 'Native flag must be boolean or integer 0/1')
    return bool(value)


def adjudicate(mode, variant, result):
    need(result.get('mode') == mode, 'Native mode receipt differs')
    done = native_flag(result.get('done'))
    if variant == 'cleanup-namespace' and mode == 'read':
        need(not done and result.get('error') == 'Cross-z equal numeric roof ref was retained'
             and result.get('checks') == 9, 'Cleanup control failed outside its named assertion')
        return
    minimum = {'write': 10, 'write-covered': 10, 'write-roofed': 9, 'read': 23, 'read-covered': 20}.get(mode, 6)
    need(done and result.get('checks', 0) >= minimum and 'error' not in result,
         'Native roof assertions incomplete or failed')


def child_limits():
    import resource
    for kind, value in ((resource.RLIMIT_AS, CAPS['process_bytes']), (resource.RLIMIT_CPU, CAPS['cpu_seconds']),
                        (resource.RLIMIT_FSIZE, 83886080), (resource.RLIMIT_CORE, 0)):
        resource.setrlimit(kind, (value, value))


def artifacts(output, owned, pending=0, fixed_inputs=0):
    total = entries = 0
    for path in output.rglob('*'):
        entries += 1
        need(entries <= CAPS['inventory_entries'] and not path.is_symlink(), 'Artifact inventory/link bound')
        if path.is_file():
            parts = path.relative_to(output).parts
            allowed = (len(parts) == 1 and (parts[0] in ('NATIVE_USED','result.json','failure.json') or
                any(parts[0] == label+'.'+stream+'.log' for label in ('compile',*set(sum((list(v) for v in PHASES.values()),[]))) for stream in ('stdout','stderr'))))
            allowed = allowed or parts[0] == 'environment'
            allowed = allowed or (parts[0] == 'program' and len(parts) == 2 and
                (parts[1].startswith('.durable_world_') and Path(parts[1]).suffix in ('.dmb','.rsc') or
                 any(parts[1] == 'native-'+m+'.log' for modes in PHASES.values() for m in modes)))
            if parts[0] == 'cases' and len(parts) >= 3:
                tail = parts[2:]
                allowed = parts[1] in set(sum((list(v) for v in PHASES.values()),[])) and (
                    tail in [('roof-result.json',),('probe-port-closed.txt',),('probe-port-closed.ack',),('config','tips.txt')] or
                    len(tail) == 2 and tail[0] == 'map_saves' and tail[1] in ('1.sav','2.sav','map.txt','round.json','save_complete.txt') or
                    len(tail) >= 3 and tail[:2] == ('config','names'))
            need(allowed, 'Unexpected generated file: '+path.relative_to(output).as_posix())
            if path == output/'result.json' and pending: continue
            size = path.stat().st_size; total += size
            if path.suffix == '.log': need(size <= CAPS['log_bytes'], 'Per-log byte cap')
    for path in owned:
        if path.is_file(): total += path.stat().st_size
    need(total + pending + fixed_inputs <= CAPS['artifact_bytes'], 'Aggregate generated artifact cap')
    return dict(bytes=total + pending + fixed_inputs, entries=entries)


def source_pin(request):
    need(git('rev-parse', 'HEAD').decode().strip() == request['head'], 'Source head changed')
    for name, digest in request['source_sha256'].items():
        need(sha(ROOT/name) == digest, 'Compiler input changed: ' + name)


def run(output, byond, packet_dir, head, request_sha256):
    old = primitives()
    old.native_gate(output, byond, head)  # Existing accepted isolated PR-CI gate.
    request_path = packet_dir/'request.json'
    need(sha(request_path) == request_sha256, 'External immutable request hash differs')
    request = json.loads(request_path.read_text())
    need(request['kind'] == 'review-only-synthetic-roof-request-v1', 'Fixed synthetic request scope')
    need(request['head'] == head and request['caller_sha256'] == sha(__file__), 'Exact request/caller required')
    variant = request['variant']
    need(variant in PHASES and request['modes'] == list(PHASES[variant]) and request['caps'] == CAPS
         and request['port'] == PORT and request['binary_sha256'] == ENGINE
         and request['outer_seconds'] == (990 if variant == 'main' else 330), 'Fixed request contract')
    for name, digest in request['prepared'].items():
        path = (packet_dir/name).resolve(strict=True)
        need(path.is_relative_to(packet_dir) and not path.is_symlink(), 'Prepared path escaped packet')
        need(sha(path) == digest, 'Prepared input changed')
    need(execution_contract(request,packet_dir)==request['execution_contract_sha256'], 'Prepared code contract differs')
    fixed_inputs = request_path.stat().st_size + sum((packet_dir/name).stat().st_size for name in request['prepared'])
    need(fixed_inputs <= 8388608, 'Frozen packet input byte bound')
    for name, digest in ENGINE.items(): need(sha(byond/name) == digest, 'Accepted engine changed')
    source_pin(request); need(not old.native_census(), 'Empty participating native baseline required')
    with __import__('socket').socket() as probe: probe.bind(('127.0.0.1', PORT))
    need(shutil.disk_usage(output.parent).free >= CAPS['disk_free_bytes'], 'Disk floor')
    claim=claim_request(request_sha256,head,output,Path(os.environ['RUNNER_TEMP']))
    fixed_inputs += claim.stat().st_size
    output.mkdir(parents=True, exist_ok=False)
    started = time.monotonic(); end = started + request['outer_seconds']; work_end = end - CAPS['cleanup_seconds']
    owned = []; owned_source_sha = {}
    receipt = dict(head=head, variant=variant, request_sha256=sha(request_path), success=False, children=[],
                   execution_contract_sha256=request['execution_contract_sha256'],claim_path=str(claim),claim_sha256=sha(claim),
                   scope='Synthetic roof recovery/controls only; no private save or production acceptance')

    def check(): need(time.monotonic() < work_end, 'Aggregate work deadline')
    def save():
        payload = json.dumps(receipt, indent=2).encode(); need(len(payload) <= CAPS['receipt_bytes'], 'Receipt bound')
        artifacts(output, owned, pending=len(payload),fixed_inputs=fixed_inputs); (output/'result.json').write_bytes(payload)

    def phase(argv, cwd, label, mode=None):
        import resource
        check(); need(not old.native_census(), 'Native overlap before phase')
        need(receipt.get('cleanup_seconds_used',0) < CAPS['cleanup_seconds'], 'Cleanup reserve exhausted')
        need(sha(argv[0]) == ENGINE[Path(argv[0]).name], 'Engine changed at creation')
        runtime = mode is not None; phase_start = time.monotonic()
        phase_end = min(work_end, phase_start + (CAPS['child_seconds'] if runtime else CAPS['compiler_seconds']))
        row = dict(phase=label, argv=argv, cwd=str(cwd), samples=[], cleanup=None); receipt['children'].append(row)
        before_cpu = resource.getrusage(resource.RUSAGE_CHILDREN)
        environment = output/'environment'; environment.mkdir(exist_ok=True)
        env = dict(PATH=str(byond)+':/usr/bin:/bin', LD_LIBRARY_PATH=str(byond), HOME=str(environment),
                   TMPDIR=str(environment), LANG='C.UTF-8')
        process = birth = None; closed = not runtime
        with (output/(label+'.stdout.log')).open('xb') as stdout, (output/(label+'.stderr.log')).open('xb') as stderr:
            try:
                process = subprocess.Popen(argv, cwd=cwd, stdin=subprocess.DEVNULL, stdout=stdout, stderr=stderr,
                    env=env, start_new_session=True, preexec_fn=child_limits)
                birth = old.identity(process.pid); row['identity'] = birth
                need(birth['pgrp'] == birth['session'] == process.pid, 'Dedicated child group required')
                while not old.exited_unreaped(process):
                    check(); need(time.monotonic() < phase_end, 'Phase deadline')
                    current = old.identity(process.pid)
                    need(current['start_ticks'] == birth['start_ticks'], 'Owned birth changed')
                    members = old.group_members(process.pid)
                    need(len(members) == 1 and members[0]['pid'] == process.pid, 'Unexpected owned descendant')
                    try: sockets = old.owned_sockets(process.pid, birth['start_ticks'])
                    except (FileNotFoundError, PermissionError):
                        if not old.exited_unreaped(process): raise
                        break  # Never retry a denied read; earlier closure is still required.
                    socket_contract(sockets, runtime, closed)
                    if runtime and not closed:
                        need(time.monotonic()-phase_start < CAPS['closure_seconds'], 'Closure deadline')
                        marker = cwd/'probe-port-closed.txt'
                        if marker.exists():
                            need(marker.stat().st_size <= 16 and marker.read_bytes().strip() == b'closed', 'Closure marker differs')
                            socket_contract(sockets, True, True)
                            with (cwd/'probe-port-closed.ack').open('xb') as ack: ack.write(b'closed\n')
                            closed = True; row['closure_seconds'] = time.monotonic()-phase_start
                    watcher = old.identity(os.getpid())['resident_pages'] * os.sysconf('SC_PAGE_SIZE')
                    need(watcher <= CAPS['watcher_bytes'], 'Controller memory bound')
                    cpu = current['cpu_ticks']/os.sysconf('SC_CLK_TCK')
                    need(cpu <= CAPS['cpu_seconds'], 'Observed owned CPU bound')
                    row['samples'].append(dict(seconds=time.monotonic()-phase_start, sockets=sockets, closed=closed,
                        resident_bytes=current['resident_pages']*os.sysconf('SC_PAGE_SIZE'), cpu_seconds=cpu))
                    need(len(row['samples']) <= 4000, 'Sample bound'); artifacts(output, owned,fixed_inputs=fixed_inputs); save(); time.sleep(.1)
                need(closed, 'Child exited before external closure acknowledgement')
            finally:
                cleanup_start = time.monotonic()
                if process is not None:
                    remaining_cleanup = max(0,CAPS['cleanup_seconds']-receipt.get('cleanup_seconds_used',0))
                    row['cleanup'] = (old.cleanup(process, birth, min(end,cleanup_start+remaining_cleanup))
                        if birth is not None else dict(group_empty=False, errors=['Birth unavailable; no PID fallback']))
                row['cleanup_seconds'] = time.monotonic()-cleanup_start
                receipt['cleanup_seconds_used'] = receipt.get('cleanup_seconds_used',0)+row['cleanup_seconds']
                after_cpu = resource.getrusage(resource.RUSAGE_CHILDREN)
                row['cpu_seconds'] = after_cpu.ru_utime + after_cpu.ru_stime - before_cpu.ru_utime - before_cpu.ru_stime
                row['seconds'] = time.monotonic()-phase_start; save()
        need(row['cleanup'] and row['cleanup'].get('exit_code') == 0 and row['cleanup'].get('group_empty')
             and not row['cleanup']['errors'], 'Owned phase exit/cleanup failed')
        need(row['cpu_seconds'] <= CAPS['cpu_seconds'], 'Final owned CPU bound')
        need(receipt['cleanup_seconds_used'] <= CAPS['cleanup_seconds'], 'Aggregate cleanup reserve exceeded')
        need(not old.native_census(), 'Native baseline not empty after cleanup')
        return row

    try:
        prepared = (packet_dir/request['prepared_directory']).resolve(strict=True)
        need(prepared.is_relative_to(packet_dir) and not prepared.is_symlink(), 'Prepared directory escaped packet')
        inputs = list(prepared.glob('*.dm'))
        need(3 <= len(inputs) <= 4, 'Prepared adapter count')
        prefix = next(p.name.removesuffix('_probe.dm') for p in inputs if p.name.endswith('_probe.dm'))
        import re
        need(re.fullmatch(r'\.durable_world_[a-f0-9]{32}',prefix), 'Generated source prefix differs')
        dme = ROOT/(prefix+'.dme')
        for path in [*inputs, prepared/'probe.dme']:
            target = dme if path.name == 'probe.dme' else ROOT/path.name
            need(not target.exists(), 'Owned generated source collision')
            with target.open('xb') as stream: stream.write(path.read_bytes())
            owned.append(target); owned_source_sha[target] = sha(target)
        for suffix in ('.dmb', '.rsc'):
            target = dme.with_suffix(suffix); need(not target.exists(), 'Compiled output collision'); owned.append(target)
        (output/'NATIVE_USED').open('x').close()
        phase([str(byond/'DreamMaker'), '-max_errors', '0', dme.name], ROOT, 'compile')
        evidence = module('roof_compile_evidence', ROOT/'tests/new_z_budget/z_budget_evidence.py')
        logs = ''.join((output/('compile.'+stream+'.log')).read_text(errors='replace') for stream in ('stdout','stderr'))
        evidence.validate_compile(0, logs, dme.with_suffix('.dmb').name)
        program = output/'program'; program.mkdir()
        for suffix in ('.dmb', '.rsc'):
            path = dme.with_suffix(suffix); need(path.is_file() and path.stat().st_size < 83886080, 'Compiled artifact bound')
            os.replace(path, program/path.name)  # One pair; no cross-filesystem copy fallback.
        compiled = program/dme.with_suffix('.dmb').name
        pair = {p.name:sha(p) for p in program.iterdir()}; receipt['compiled_sha256'] = pair
        seeds = {}; payloads = ('1.sav','2.sav','map.txt','round.json','save_complete.txt')
        for mode in PHASES[variant]:
            check(); case = output/'cases'/mode; case.mkdir(parents=True)
            config = case/'config'; config.mkdir(); shutil.copy2(ROOT/'config/tips.txt', config/'tips.txt')
            shutil.copytree(ROOT/'config/names', config/'names')
            writer = mode.startswith('write')
            if not writer:
                seed_name = 'write-covered' if mode == 'read-covered' else ('write' if variant == 'main' else 'write-roofed')
                seed, pins = seeds[seed_name]; (case/'map_saves').mkdir()
                for name, digest in pins.items():
                    need(sha(seed/name) == digest, 'Retained writer payload changed')
                    shutil.copy2(seed/name, case/'map_saves'/name)
            for name,digest in pair.items(): need(sha(program/name) == digest, 'Compiled pair changed')
            argv = [str(byond/'DreamDaemon'), str(compiled), str(PORT), '-ip','127.0.0.1','-trusted','-close',
                    '-cd',str(case),'-log','native-'+mode+'.log','-params','roof_mode='+mode]
            phase(argv, case, mode, mode)
            log = program/('native-'+mode+'.log')
            console = ''.join((output/(mode+'.'+s+'.log')).read_text(errors='replace') for s in ('stdout','stderr'))
            need(log.is_file() and not evidence.DIAGNOSTIC.search(log.read_text(errors='replace')+console), 'Native engine diagnostic')
            result_path = case/'roof-result.json'; need(result_path.stat().st_size <= 65536, 'Native result bound')
            result = json.loads(result_path.read_text()); adjudicate(mode, variant, result)
            receipt.setdefault('native_results',{})[mode] = dict(result=result, result_sha256=sha(result_path), log_sha256=sha(log))
            if writer:
                seed = case/'map_saves'; need(set(p.name for p in seed.iterdir()) == set(payloads), 'Unexpected writer payload')
                need(sum((seed/n).stat().st_size for n in payloads) <= 2097152, 'Synthetic save byte bound')
                seeds[mode] = (seed,{name:sha(seed/name) for name in payloads})
            for seed,pins in seeds.values():
                for name,digest in pins.items(): need(sha(seed/name) == digest, 'Writer snapshot changed during reader')
            save(); print(json.dumps(dict(phase=mode, accepted=True)), flush=True)
        source_pin(request)
        for name,digest in ENGINE.items(): need(sha(byond/name) == digest, 'Engine changed after phases')
        need(sha(request_path) == receipt['request_sha256'], 'Request changed')
        need(not old.native_census(), 'Final native baseline not empty')
        with __import__('socket').socket() as probe: probe.bind(('127.0.0.1',PORT))
        receipt['success'] = True
    except Exception as error:
        receipt['error'] = str(error)[:4096]
    finally:
        # Only fixed, exclusively created generated source names are retired.
        # All logs, failed payload copies, manifests and compiled test pair stay.
        for path in owned:
            if path.suffix in ('.dm','.dme') and path.exists():
                if sha(path) == owned_source_sha[path]: path.unlink()
                else:
                    receipt['success'] = False
                    receipt.setdefault('cleanup_errors',[]).append('Generated source changed; retained '+path.name)
        try:
            receipt['final_native_census'] = old.native_census()
            need(not receipt['final_native_census'], 'Final native census not empty after cleanup')
        except Exception as error:
            receipt['success'] = False; receipt['final_census_error'] = str(error)[:4096]
        receipt['seconds'] = time.monotonic()-started
        receipt['success'] = receipt['success'] and receipt['seconds'] <= request['outer_seconds']
        try: save()
        except Exception as error:
            receipt['success'] = False
            failure = json.dumps(dict(success=False,error=str(error)[:4096],
                original_error=receipt.get('error'),children=[dict(phase=r['phase'],identity=r.get('identity'),
                    cleanup=r.get('cleanup')) for r in receipt['children']]),indent=2).encode()
            need(len(failure) <= 65536, 'Terminal failure receipt bound')
            (output/'failure.json').write_bytes(failure)
    print(json.dumps(dict(success=receipt['success'], output=str(output))),flush=True)
    return 0 if receipt['success'] else 1


def main():
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument('--prepare-only', action='store_true')
    cli.add_argument('--packet-dir', type=Path, required=True)
    cli.add_argument('--expected-head', required=True)
    cli.add_argument('--variant', choices=tuple(PHASES), default='main')
    cli.add_argument('--output', type=Path)
    cli.add_argument('--byond-bin', type=Path)
    cli.add_argument('--request-sha256')
    args = cli.parse_args()
    if args.prepare_only:
        request = prepare(args.packet_dir.resolve(), args.expected_head, args.variant)
        print(json.dumps(dict(prepared=True,native_executed=False,packet=str(args.packet_dir),
            request_sha256=sha(args.packet_dir/'request.json'),runner_sha256=request['caller_sha256'],
            execution_contract_sha256=request['execution_contract_sha256'],variant=args.variant)))
        return 0
    if not args.output or not args.byond_bin or not args.request_sha256:
        cli.error('Execution requires --output, --byond-bin and --request-sha256 in reviewed Linux PR CI')
    return run(args.output.resolve(),args.byond_bin.resolve(),args.packet_dir.resolve(),args.expected_head,args.request_sha256)


if __name__ == '__main__':
    raise SystemExit(main())
