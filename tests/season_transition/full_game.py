"""Bounded full-source largest-map constructor benchmark; no live server/client."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
import uuid

MAP = 'maps/nomads/nomads_persistence_beta.dmm'
METADATA = 'code/game/objects/map_metadata/_map_metadata.dm'
STARTUP = 'code/setup.dm'
WORLD = 'code/world.dm'
DIAGNOSTICS = re.compile(r'Infinite loop suspected|switching proc to background|runtime error|\bBad ref\b|\bBad loc\b|Cannot read null|Cannot execute null|\bBUG:|##\s*ERROR:', re.I)
SCOPE = 'Full-source actual terrain constructors and headless humans in pregame; no connected players, roundstart mapgen, client rendering, long-term memory or production acceptance'

def git(repo, *args):
    return subprocess.check_output(['git', '-C', str(repo), *args], text=True, encoding='utf-8')

def digest(data):
    return hashlib.sha256(data).hexdigest()

def generate(repo, output, prefix, negative, created, service_negative=False):
    dme = (repo / 'civ13.dme').read_text(encoding='utf-8-sig')
    map_include = re.compile(r'^#include "maps[\\/]nomads[\\/]nomads\.dmm"$', re.M)
    if len(map_include.findall(dme)) != 1:
        raise RuntimeError('Expected one default Nomads map include')
    dme = map_include.sub('#include "' + MAP + '"', dme)
    source = (repo / METADATA).read_text(encoding='utf-8-sig')
    old = '''/obj/map_metadata/proc/season_schedule_phase(var/delay, var/phase, var/epoch)
	if (!season_worker_valid(epoch))
		return
	spawn(delay)
		if (!season_worker_valid(epoch))
			return
		season_queue += list(phase, epoch, FALSE, FALSE)
		season_run_queue()
'''
    new = '''/obj/map_metadata/proc/season_schedule_phase(var/delay, var/phase, var/epoch)
	if (!season_worker_valid(epoch))
		return
	full_season_probe.original_phase_delays += delay
	full_season_probe.pending_phases++
	spawn(30 + delay / 100)
		if (!season_worker_valid(epoch))
			full_season_probe.pending_phases--
			return
		season_queue += list(phase, epoch, FALSE, FALSE)
		season_run_queue()
		full_season_probe.pending_phases--
'''
    if source.count(old) != 1:
        raise RuntimeError('Unexpected production delayed phase source')
    adapted = source.replace(old, new)
    token = '\t\t\t\t\tseason_apply(force, advance_decay, epoch)'
    if adapted.count(token) != 1:
        raise RuntimeError('Unexpected transition application call')
    adapted = adapted.replace(token, '\t\t\t\t\tfull_season_probe.main_started = world.time\n\t\t\t\t\tfull_season_probe.main_started_tod = world.timeofday\n' + token + '\n\t\t\t\t\tfull_season_probe.main_finished = world.time\n\t\t\t\t\tfull_season_probe.main_finished_tod = world.timeofday\n\t\t\t\t\tfull_season_probe.mark(replacetext(full_season_probe.phase, "_main", "_phases"))')
    # Generated adaptations must leave every production worker/terrain body unchanged.
    restored = adapted.replace(new, old)
    restored = re.sub(r'^\t+full_season_probe\.main_(?:started|finished)(?:_tod)? = world\.(?:time|timeofday)\n', '', restored, flags=re.M)
    restored = re.sub(r'^\t+full_season_probe\.mark\([^\n]+\)\n', '', restored, flags=re.M)
    if restored != source:
        raise RuntimeError('Generated production adaptation exceeded timing instrumentation')
    setup = (repo / STARTUP).read_text(encoding='utf-8-sig')
    if not setup.rstrip().endswith('sleep(-1)'):
        raise RuntimeError('Unexpected setup completion boundary')
    setup_adapted = setup.rstrip() + '\n\tfull_season_probe.setup_complete = TRUE\n\ttext2file(json_encode(list("world_time_ds" = world.time, "timeofday_ds" = world.timeofday)), "setup-ready.json")\n'
    world_source = (repo / WORLD).read_text(encoding='utf-8-sig')
    loop_write = '\tif (map && istype(map,/obj/map_metadata/nomads/persistence_beta))\n\t\tloop_checks = FALSE\n'
    loop_adapter = '\t// Isolated -trusted benchmark retains native long-loop protection.\n'
    if world_source.count(loop_write) != 1:
        raise RuntimeError('Unexpected Beta native loop-check assignment boundary')
    world_adapted = world_source.replace(loop_write, loop_adapter)
    if world_adapted.replace(loop_adapter, loop_write) != world_source:
        raise RuntimeError('Generated world startup adaptation exceeded native loop-check permission adapter')
    adaptations = {METADATA: adapted, STARTUP: setup_adapted, WORLD: world_adapted}
    for index, (original, content) in enumerate(adaptations.items()):
        generated = repo / (prefix + '_' + str(index) + '.dm')
        generated.write_text(content, encoding='utf-8')
        created.append(generated)
        shutil.copy2(generated, output / ('generated-' + Path(original).name))
        (output / ('original-' + Path(original).name)).write_text((repo / original).read_text(encoding='utf-8-sig'), encoding='utf-8')
        tokens = ['"' + original + '"', '"' + original.replace('/', '\\') + '"']
        present = [item for item in tokens if item in dme]
        if len(present) != 1 or dme.count(present[0]) != 1:
            raise RuntimeError('Production include mismatch: ' + original)
        dme = dme.replace(present[0], '"' + generated.name + '"')
    probe = (repo / 'tests/season_transition/full_game_probe.dm').read_text(encoding='utf-8-sig')
    if negative:
        token = '\t\tpopulation_constructed = TRUE\n'
        if probe.count(token) != 1:
            raise RuntimeError('Population negative-control anchor missing')
        probe = probe.replace(token, token + '\t\titems.Cut(items.len, items.len+1) // Generated population conservation defect.\n')
    if service_negative:
        token = '\t\t\tactors += H\n'
        if probe.count(token) != 1:
            raise RuntimeError('Natural service negative-control anchor missing')
        probe = probe.replace(token, token + '\t\t\tif (i == 80)\n\t\t\t\tliving_mob_list -= H\n\t\t\t\tif (processes.mob.current_list)\n\t\t\t\t\tprocesses.mob.current_list -= H\n\t\t\t\tH.probe_lives = 0\n')
    generated_probe = repo / (prefix + '_probe.dm')
    generated_probe.write_text(probe, encoding='utf-8')
    created.append(generated_probe)
    shutil.copy2(generated_probe, output / 'generated-probe.dm')
    dme += '\n#include "' + generated_probe.name + '"\n'
    source_path = repo / (prefix + '.dme')
    source_path.write_text(dme, encoding='utf-8')
    created.append(source_path)
    shutil.copy2(source_path, output / 'generated.dme')
    # Save original path/hash for every transitive include, including actual DMM.
    pending = [source_path]
    hashes = {}
    while pending:
        file = pending.pop()
        key = file.relative_to(repo).as_posix()
        if key in hashes:
            continue
        data = file.read_bytes()
        hashes[key] = digest(data)
        if file.suffix.lower() in ('.dm', '.dme'):
            clean = re.sub(r'/\*.*?\*/', '', data.decode('utf-8-sig'), flags=re.S)
            for include in re.findall(r'^\s*#include\s+"([^"]+)"', clean, re.M):
                path = (file.parent / include.replace('\\', '/')).resolve()
                if not path.is_relative_to(repo):
                    raise RuntimeError('Include escapes selected checkout')
                pending.append(path)
    return source_path, created, hashes

def child_sample(process):
    if os.name == 'nt':
        from ctypes import wintypes
        class Memory(ctypes.Structure):
            _fields_ = [('cb', wintypes.DWORD), ('faults', wintypes.DWORD)] + [(name, ctypes.c_size_t) for name in ('peak_working_set', 'working_set', 'peak_paged', 'paged', 'peak_nonpaged', 'nonpaged', 'pagefile', 'peak_pagefile', 'private')]
        mem = Memory(); mem.cb = ctypes.sizeof(mem)
        handle = ctypes.c_void_p(int(process._handle))
        if not ctypes.windll.psapi.GetProcessMemoryInfo(handle, ctypes.byref(mem), mem.cb):
            raise ctypes.WinError()
        times = (ctypes.c_ulonglong * 4)()
        if not ctypes.windll.kernel32.GetProcessTimes(handle, ctypes.byref(times, 0), ctypes.byref(times, 8), ctypes.byref(times, 16), ctypes.byref(times, 24)):
            raise ctypes.WinError()
        return {'rss_bytes': mem.working_set, 'lifetime_high_water_bytes': mem.peak_working_set, 'private_bytes': mem.private, 'cpu_seconds': (times[2] + times[3]) / 10000000}
    try:
        rows = (Path('/proc') / str(process.pid) / 'status').read_text().splitlines()
        memory = {row.split(':', 1)[0]: int(row.split()[1]) * 1024 for row in rows if row.startswith(('VmRSS:', 'VmHWM:'))}
        # comm can contain spaces/parentheses; fields after final ')' begin with state.
        fields = (Path('/proc') / str(process.pid) / 'stat').read_text().rsplit(')', 1)[1].split()
        cpu = (int(fields[11]) + int(fields[12])) / os.sysconf('SC_CLK_TCK')
        return {'rss_bytes': memory['VmRSS'], 'lifetime_high_water_bytes': memory['VmHWM'], 'cpu_seconds': cpu}
    except (FileNotFoundError, ProcessLookupError, KeyError, ValueError):
        return None

def summarize(samples, result):
    summaries = {}
    for phase in dict.fromkeys(row['phase'] for row in samples):
        os_rows = [row for row in samples if row['phase'] == phase]
        native = [row['awake_gap_ds'] for row in result.get('heartbeats', []) if row['phase'] == phase]
        native.sort()
        summaries[phase] = {'os_samples': len(os_rows), 'sampled_cpu_seconds': os_rows[-1]['cpu_seconds'] - os_rows[0]['cpu_seconds'], 'sampled_wall_seconds': os_rows[-1]['elapsed_seconds'] - os_rows[0]['elapsed_seconds'], 'sampled_peak_rss_bytes': max(row['rss_bytes'] for row in os_rows), 'lifetime_high_water_bytes': max(row['lifetime_high_water_bytes'] for row in os_rows), 'heartbeat_samples': len(native), 'heartbeat_max_ds': max(native) if native else None, 'heartbeat_p95_ds': native[min(len(native)-1, int(.95*len(native)))] if native else None}
    return summaries

def diagnostic_chunk(path, offset, tail):
    """Inspect at most 64 KiB per poll; retain 1 KiB for split diagnostic text."""
    try:
        with path.open('rb') as stream:
            if path.stat().st_size < offset:
                offset, tail = 0, ''
            stream.seek(offset)
            chunk = stream.read(65536)
            offset = stream.tell()
    except FileNotFoundError:
        return None, offset, tail
    text = tail + chunk.decode('utf-8', errors='replace')
    match = DIAGNOSTICS.search(text)
    return (match.group(0) if match else None), offset, text[-1024:]

def run_daemon(command, output, negative):
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    samples = []
    result = {}
    started = time.monotonic()
    failure = None
    last_phase = 'startup'
    diagnostic_offsets = {name: (0, '') for name in ('startup.log', 'full-season-runtime-error.txt')}
    with (output / 'stdout.log').open('w') as stdout, (output / 'stderr.log').open('w') as stderr:
        process = subprocess.Popen(command, cwd=output, stdout=stdout, stderr=stderr, creationflags=flags)
        try:
            while process.poll() is None:
                for name, (offset, tail) in diagnostic_offsets.items():
                    diagnostic, offset, tail = diagnostic_chunk(output / name, offset, tail)
                    diagnostic_offsets[name] = (offset, tail)
                    if diagnostic:
                        raise RuntimeError('Native diagnostic detected before deadline: ' + name + ': ' + diagnostic)
                elapsed = time.monotonic() - started
                if elapsed > 900:
                    raise RuntimeError('Whole-daemon 900-second deadline')
                if elapsed > 300 and not (output / 'setup-ready.json').exists():
                    raise RuntimeError('Startup 300-second deadline')
                sample = child_sample(process)
                if sample is not None:
                    try:
                        last_phase = json.loads((output / 'phase.json').read_text())['phase']
                    except (FileNotFoundError, json.JSONDecodeError):
                        pass
                    sample.update({'elapsed_seconds': elapsed, 'phase': last_phase})
                    samples.append(sample)
                    if sample['lifetime_high_water_bytes'] > 2 * 1024**3:
                        raise RuntimeError('Own-child 2-GiB memory cap')
                time.sleep(.1)
        except Exception as error:
            failure = str(error)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=10)
            (output / 'os-samples.json').write_text(json.dumps(samples), encoding='utf-8')
            (output / 'daemon.json').write_text(json.dumps({'returncode': process.returncode, 'wall_seconds': time.monotonic()-started, 'failure': failure, 'sample_interval_seconds': .1, 'phase_boundary_uncertainty': 'one poll plus file visibility/write/scheduling delay', 'metric': 'own-child Windows working set/private bytes or Linux RSS/high-water; CPU kernel+user'}, indent=2), encoding='utf-8')
    if failure:
        raise RuntimeError(failure)
    logs = '\n'.join(path.read_text(errors='replace') for path in output.rglob('*') if path.is_file() and (path.suffix in ('.log', '.txt') or path.name.endswith('-runtime.txt')) and path.name != 'compile.log')
    if DIAGNOSTICS.search(logs):
        raise RuntimeError('Native runtime/engine diagnostics invalidate evidence')
    if negative:
        text = (output / 'result.txt').read_text() if (output / 'result.txt').exists() else ''
        expected = 'FAIL: Initial natural Life service deadline' if negative == 'service' else 'FAIL: Finite population count mismatch'
        if process.returncode or (output / 'result.json').exists() or text.strip() != expected:
            raise RuntimeError('Negative control failed for an unrelated reason')
        if negative == 'service':
            failure = json.loads((output / 'service-failure.json').read_text())
            if failure['unserviced_actors'] != [80] or failure['wait_wall_ds'] < 300:
                raise RuntimeError('Withheld natural service control receipt inconsistent')
        return {'negative_control_detected': True, 'defect': 'generated omission from natural mob scheduling for retained actor80' if negative == 'service' else 'generated omission from the 20000-item ownership list'}, samples
    if process.returncode or not (output / 'result.json').exists():
        raise RuntimeError('Native result missing or failed: ' + ((output / 'result.txt').read_text() if (output / 'result.txt').exists() else str(process.returncode)))
    result = json.loads((output / 'result.json').read_text())
    initial_service = json.loads((output / 'service-ready.json').read_text())
    if len(initial_service['life_calls']) != 80 or min(initial_service['life_calls']) < 1 or initial_service['wait_wall_ds'] >= 300:
        raise RuntimeError('Initial natural Life readiness receipt inconsistent')
    if not result.get('passed') or not result.get('completed') or result.get('dead_humans') != 0 or result.get('native_loop_checks') != 1 or result.get('port') or result.get('connected_clients') or result.get('dimensions') != [660, 550, 1] or len(result.get('cycles', [])) != 4:
        raise RuntimeError('Native result invariants failed')
    if any(not cycle.get('movement_completed') or cycle.get('movement_busy_operations', 0) < 1 or len(cycle.get('human_life_advances', [])) != 80 or min(cycle['human_life_advances']) < 1 for cycle in result['cycles']):
        raise RuntimeError('Concurrent movement or per-cycle human Life evidence missing')
    movement = result.get('movement_rows', [])
    if len(movement) != 80:
        raise RuntimeError('Finite concurrent callback evidence missing')
    for cycle in result['cycles']:
        rows = [row for row in movement if row.get('cycle') == cycle['cycle']]
        busy_rows = [row for row in rows if row.get('busy_before') and row.get('busy_after')]
        if len(rows) != 20 or [row.get('iteration') for row in rows] != list(range(1, 21)) or len(busy_rows) != cycle['movement_busy_operations'] or not busy_rows or any(not row.get('item_on_drop_turf') or not row.get('actor_ref') or not row.get('item_ref') for row in rows) or len({row['actor_ref'] for row in rows}) != 1 or len({row['item_ref'] for row in rows}) != 1:
            raise RuntimeError('Concurrent callback identity/busy evidence inconsistent')
    if not samples or not any(row['cpu_seconds'] > 0 for row in samples):
        raise RuntimeError('Own-child CPU/RSS measurements missing')
    return result, samples

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--prepare-only', action='store_true')
    controls = parser.add_mutually_exclusive_group()
    controls.add_argument('--negative-control', action='store_true')
    controls.add_argument('--service-negative-control', action='store_true')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[2]
    output = (args.output or Path(tempfile.gettempdir()) / ('civ13-full-season-' + uuid.uuid4().hex)).resolve()
    if output.exists() and any(output.iterdir()):
        raise RuntimeError('Output evidence directory must be fresh')
    output.mkdir(parents=True, exist_ok=True)
    prefix = '.full_season_' + uuid.uuid4().hex
    created = []
    try:
        source, created, hashes = generate(repo, output, prefix, args.negative_control, created, args.service_negative_control)
        head = git(repo, 'rev-parse', 'HEAD').strip()
        manifest = {'tested_commit': head, 'working_tree_status': git(repo, 'status', '--porcelain'), 'source_hashes': hashes, 'map_source': MAP, 'map_sha256': hashes[MAP], 'scope': SCOPE, 'negative_control': args.negative_control, 'limits': {'startup_seconds': 300, 'whole_daemon_seconds': 900, 'memory_bytes': 2 * 1024**3}, 'execution_context': {'daemon_safe_mode': True, 'native_loop_checks': True, 'world_startup_adapter': 'Only the Beta conditional assignment disabling loop_checks is omitted; exact source restoration asserted'}, 'adapters': ['closed port; no clients', 'safe-mode native loop protection retained instead of production Beta loop_checks FALSE; every other world startup statement unchanged', 'webhooks/ToRban disabled before and after ordinary world startup', 'temporary cwd/config/state with persistence saving disabled', 'pregame round_progressing FALSE', 'human ssd_check FALSE only; inherited constructor/Life', 'only seasonal delayed-start spawn(delay) becomes spawn(30 + delay / 100); relative delay lengths preserved; callback firing order may differ; original delays recorded; real worker pauses unchanged', 'setup completion and main/pending callback timing instrumentation', 'unexpected reboot fails']}
        manifest['service_negative_control'] = args.service_negative_control
        manifest['initial_service'] = 'Wait up to 30 real seconds for all 80 inherited Life callbacks through ordinary mob scheduler; actor identity/location/death checked every poll; no direct Life calls'
        (output / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
        (output / 'tested.patch').write_text(git(repo, 'diff', 'HEAD'), encoding='utf-8')
        shutil.copy2(__file__, output / 'runner.py')
        if args.prepare_only:
            print(json.dumps({'prepared': True, 'output': str(output), 'source_files': len(hashes), 'map_sha256': hashes[MAP], 'native_launched': False}))
            return
        if args.byond_bin is None:
            raise RuntimeError('--byond-bin required for native execution')
        byond = args.byond_bin.resolve()
        compiler = byond / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
        daemon = byond / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
        if not compiler.is_file() or not daemon.is_file():
            raise RuntimeError('Pinned BYOND compiler/daemon missing')
        created += [source.with_suffix('.dmb'), source.with_suffix('.rsc')]
        build = subprocess.run([str(compiler), '-max_errors', '0', str(source)], cwd=repo, capture_output=True, text=True, timeout=300, creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
        compile_log = build.stdout + build.stderr
        (output / 'compile.log').write_text(compile_log, encoding='utf-8')
        if build.returncode or 'DM compiler version 516.1681' not in compile_log or '0 errors, 0 warnings' not in compile_log:
            raise RuntimeError('Pinned zero-error/zero-warning compilation failed')
        for suffix in ('.dmb', '.rsc'):
            shutil.copy2(source.with_suffix(suffix), output / ('probe' + suffix))
        for path in git(repo, 'ls-files', '--', 'config').splitlines():
            dest = output / path
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(repo / path, dest)
        command = [str(daemon), 'probe.dmb']
        if os.name == 'nt':
            command += ['-invisible', '-close']
        command += ['-trusted', '-params', 'tested_commit=' + head, '-log', 'startup.log']
        result, samples = run_daemon(command, output, 'service' if args.service_negative_control else ('population' if args.negative_control else None))
        if not args.negative_control and not args.service_negative_control and result['tested_commit'] != head:
            raise RuntimeError('Native exact-head receipt mismatch')
        (output / 'phase-summary.json').write_text(json.dumps(summarize(samples, result), indent=2), encoding='utf-8')
        print(json.dumps({'passed': True, 'output': str(output), 'tested_commit': head, 'negative_control': args.negative_control, 'service_negative_control': args.service_negative_control, 'scope': SCOPE}))
    finally:
        for path in created:
            if path.exists():
                path.unlink()

if __name__ == '__main__':
    main()
