"""Hosted Linux synthetic probe. Native execution requires separate approval.

Creates only a new isolated output directory; no downloads, live targets or
production saves. Process-group cleanup reuses human_subtile/run.py. Loopback
binding is not an egress sandbox, and sampled disk limits are not hard quotas.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
import benchmark
import human_spatial_stage

spec = importlib.util.spec_from_file_location('spatial_owned_process', ROOT / 'tests/human_subtile/run.py')
legacy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(legacy)

MAX_BYTES = 256 * 1024 * 1024
MAX_LOG = 8 * 1024 * 1024
MAX_FILES = 4096
MAX_DEPTH = 16
NEGATIVES = {
    'wall': 'Human saved tile is dense',
    'dense': 'Human saved tile has a dense object',
    'roster': 'Human roster proof has no stable owner',
    'duplicate': 'Human slot candidate has duplicate saved parents',
    'missing_roster': 'Human roster proof changed before completion',
    'invalid_density': 'Human saved tile is dense',
}


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def inventory(root, *, total_limit=MAX_BYTES, max_entries=MAX_FILES):
    """Bounded, no-symlink inventory; limits are sampled, not a disk quota."""
    out, total, seen, pending = {}, 0, 0, [(root, 0)]
    while pending:
        folder, depth = pending.pop()
        require(depth <= MAX_DEPTH, 'output depth exceeded')
        with os.scandir(folder) as entries:
            for entry in entries:
                seen += 1
                require(seen <= max_entries, 'output entry budget exceeded')
                require(not entry.is_symlink(), 'output symlink refused')
                p = Path(entry.path)
                if entry.is_dir(follow_symlinks=False):
                    pending.append((p, depth + 1))
                else:
                    require(entry.is_file(follow_symlinks=False), 'non-file output refused')
                    size = entry.stat(follow_symlinks=False).st_size
                    total += size
                    require(total <= total_limit, 'sampled output budget exceeded')
                    if p.suffix == '.log': require(size <= MAX_LOG, 'sampled log budget exceeded')
                    out[p.relative_to(root).as_posix()] = {'bytes': size}
    return out


def hashes(root, *, total_limit=MAX_BYTES, max_entries=MAX_FILES):
    entries = inventory(root, total_limit=total_limit, max_entries=max_entries)
    return {name: {'bytes': row['bytes'], 'sha256': digest(root / name)} for name, row in entries.items()}


def json_read(path):
    require(path.is_file() and path.stat().st_size <= 1024 * 1024, 'missing or oversized receipt')
    row = json.loads(path.read_text(encoding='utf-8'))
    require(isinstance(row, dict), 'invalid receipt')
    return row


def receipt(row, phase, head):
    require(row.get('phase') == phase and row.get('head') == head, 'receipt phase or source mismatch')
    require((row.get('byond_version'), row.get('byond_build'), row.get('port')) == (516, 1688, 0), 'receipt engine or port mismatch')
    require(row.get('error') is None, 'fixture error: ' + str(row.get('error')))


def writer_receipt(row, head, mode):
    receipt(row, 'writer', head)
    capsule = row.get('capsule')
    require(row.get('mode') == mode and row.get('handoffs') == 1 and row.get('pulses_after_handoff', 0) > 0 and row.get('seated_moved') == 1, 'handoff/continuation missing')
    require(isinstance(capsule, dict) and set(capsule) == {'x', 'y', 'z', 'sx', 'sy'} and all(type(v) is int for v in capsule.values()), 'invalid captured capsule')
    require(capsule['sx'] == 0 and capsule['sy'] == 0 and isinstance(row.get('generation'), str) and re.fullmatch(r'round-v[12]:[0-9a-f]{32}', row['generation']), 'invalid saved generation or tile offset')
    late = row.get('late_capsule')
    require(isinstance(late, dict) and set(late) == {'x', 'y', 'z', 'sx', 'sy'} and all(type(v) is int for v in late.values()) and late['sx'] == 0 and late['sy'] == 0 and row.get('late_pulses', 0) > 0, 'invalid late walker tile')
    return {'capsule': capsule, 'late_capsule': late, 'generation': row['generation']}


def reader_receipt(row, head, expected):
    receipt(row, 'reader', head)
    require(row.get('generation') == expected['generation'] and row.get('position') == expected['capsule'] and row.get('late_position') == expected['late_capsule'], 'reader capsule or generation mismatch')
    clearance = row.get('local_clearance_controls')
    require(clearance is True or (type(clearance) is int and clearance == 1), 'reader local clearance controls missing')


def obstruction_reader_receipt(row, head, expected):
    receipt(row, 'reader-obstruction', head)
    false = lambda v: v is False or (type(v) is int and v == 0)
    true = lambda v: v is True or (type(v) is int and v == 1)
    require(false(row.get('load_result')), 'obstructed load did not refuse')
    for field in ('afterload_created', 'guard_actor_is_target', 'solid_is_target', 'recovery_hold', 'save_hold'):
        require(true(row.get(field)), 'missing after-load obstruction evidence: ' + field)
    require(false(row.get('active_operation')), 'load owner was not released')
    require(isinstance(row.get('last_error'), str) and row['last_error'].startswith('Restored human tile is obstructed'), 'wrong obstruction refusal')
    require(row.get('generation') == expected['generation'], 'obstructed reader generation changed')


def negative_publication(current, backup, seed):
    """Refuse a new current marker independently of retained old bytes."""
    seed_hashes = hashes(seed)
    marker = seed / 'save_complete.txt'
    require(marker.is_file() and not marker.is_symlink() and marker.stat().st_size <= 256, 'seed marker unavailable')
    expected_marker = marker.read_bytes()
    current_hashes, backup_hashes = hashes(current), hashes(backup)
    current_marker = current / 'save_complete.txt'
    if current_marker.exists():
        require(current_marker.is_file() and not current_marker.is_symlink() and current_marker.stat().st_size <= 256 and current_marker.read_bytes() == expected_marker,
                'rejected candidate published a different current marker')
        require(current_hashes == seed_hashes, 'current seed marker covers changed files')
    require(current_hashes == seed_hashes or backup_hashes == seed_hashes, 'negative lost prior bytes')


def execute_negative(execute, work, seed, case, expected):
    # Preserve both execution and backup-integrity failures. Even an invalid
    # receipt or wrong rejection must not skip the independent byte check.
    try:
        row = execute(work, 'negative', '&case=' + case)
    except Exception as error:
        try:
            negative_publication(work / 'map_saves', work / 'map_backups', seed)
        except Exception as publication_error:
            raise RuntimeError('negative execution failed: ' + str(error) +
                               '; prior generation check failed: ' + str(publication_error)) from error
        raise
    negative_publication(work / 'map_saves', work / 'map_backups', seed)
    require(row.get('case') == case and row.get('rejection') == expected, 'negative failed for wrong reason')
    return row


def bounded_child():
    import resource
    limit = 1024 * 1024 * 1024
    resource.setrlimit(resource.RLIMIT_AS, (limit, limit))
    resource.setrlimit(resource.RLIMIT_FSIZE, (MAX_BYTES, MAX_BYTES))


def child_exited_unreaped(pid):
    # The owned process-group leader is not reaped until group cleanup.
    # A zombie has no RSS but its final status remains available via waitid.
    return os.waitid(os.P_PID, pid, os.WEXITED | os.WNOHANG | os.WNOWAIT) is not None


def observed_proc_state(pid):
    # Separate later observation, never an exit or process-identity proof.
    try:
        with (Path('/proc') / str(pid) / 'status').open('rb') as status:
            data = status.read(16384).decode('ascii', errors='replace')
    except OSError:
        return None
    match = re.search(r'^State:\s+([A-Za-z])(?:\s|$)', data, re.M)
    return match.group(1) if match else None


def reconcile_rss(pid, samples, started, phase_deadline, global_deadline):
    # The owned leader remains unreaped. Do not continue an unmeasured child
    # unless a fresh valid sample arrives or waitid witnesses its exit.
    require(samples['count'] > 0, 'RSS was not sampled')
    require('missing_rss_probes' not in samples, 'repeated RSS sampling unavailable')
    cutoff = min(time.monotonic() + 0.1, phase_deadline, global_deadline)
    probes = samples['missing_rss_probes'] = []
    for _ in range(10):
        if time.monotonic() >= cutoff:
            break
        exited = child_exited_unreaped(pid)
        memory = {} if exited else benchmark.proc_memory(pid)
        observation = {'elapsed_seconds': time.monotonic() - started,
                       'waitid_exit_observed': exited,
                       'later_proc_state': observed_proc_state(pid),
                       'rss_bytes': memory.get('rss_bytes')}
        probes.append(observation)
        if time.monotonic() >= cutoff:
            break
        if exited:
            samples['rss_exit_race'] = True
            return
        if 'rss_bytes' in memory:
            require(memory['rss_bytes'] <= 1024 * 1024 * 1024, 'sampled RSS exceeded')
            samples['count'] += 1
            samples['peak_rss'] = max(samples['peak_rss'], memory['rss_bytes'])
            samples['rss_recovered'] = True
            return
        remaining = cutoff - time.monotonic()
        if remaining > 0:
            time.sleep(min(0.01, remaining))
    raise RuntimeError('RSS sampling unavailable')


def monitor_for(folder, started, global_deadline, compile_mode=False, source_bytes=0, phase_deadline=None):
    if phase_deadline is None:
        phase_deadline = global_deadline
    samples = {'count': 0, 'peak_rss': 0}
    def monitor(pid, cwd):
        require(time.monotonic() < global_deadline, 'job deadline exceeded')
        memory = benchmark.proc_memory(pid)
        if 'rss_bytes' in memory:
            samples['count'] += 1
            samples['peak_rss'] = max(samples['peak_rss'], memory['rss_bytes'])
            require(memory['rss_bytes'] <= 1024 * 1024 * 1024, 'sampled RSS exceeded')
        elif time.monotonic() - started > 1:
            samples.setdefault('missing_rss_initial', {'elapsed_seconds': time.monotonic() - started,
                                                       'fields': memory})
            reconcile_rss(pid, samples, started, phase_deadline, global_deadline)
        if compile_mode:
            inventory(folder, total_limit=source_bytes + MAX_BYTES, max_entries=12000)
            for name in ('compile-stdout.log', 'compile-stderr.log', 'human_subtile.dmb', 'human_subtile.rsc'):
                p = folder / name
                if p.exists(): require(p.stat().st_size <= (MAX_LOG if p.suffix == '.log' else MAX_BYTES), 'sampled compile output exceeded')
        else:
            inventory(folder)
    return monitor, samples


def launch(command, cwd, phase, deadline, job_deadline, byond_bin, source_bytes=0):
    start = time.monotonic()
    require(start < job_deadline, 'job deadline exceeded before launch')
    phase_limit = min(deadline, job_deadline - start)
    monitor, samples = monitor_for(cwd, start, job_deadline, phase == 'compile', source_bytes, start + phase_limit)
    environment = {'PATH': '/usr/bin:/bin', 'HOME': str(cwd), 'TMPDIR': str(cwd),
                   'LANG': 'C', 'LC_ALL': 'C', 'LD_LIBRARY_PATH': str(byond_bin)}
    trace = {'events': [], 'status': 'starting', 'memory': samples}
    def event(name, value): trace['events'].append({'event': name, 'value': value})
    try:
        row = legacy.run_process(command, cwd, phase, phase_limit, preexec_fn=bounded_child, monitor=monitor, env=environment, retain_leader=True, on_event=event)
        require(samples['count'] > 0, 'RSS was not sampled')
        if phase != 'compile': inventory(cwd)
        row['memory'] = samples
        trace.update(status='exited', process=row)
        return row
    except Exception as exc:
        trace.update(status='failed', error=str(exc))
        raise
    finally:
        (cwd / (phase + '-supervision.json')).write_text(json.dumps(trace, indent=2) + '\n', encoding='utf-8')


def verify_review(expected_head, expected_scope):
    require(isinstance(expected_head, str) and re.fullmatch(r'[0-9a-f]{40}', expected_head), 'reviewed full head is required')
    require(isinstance(expected_scope, str) and re.fullmatch(r'[0-9a-f]{64}', expected_scope), 'reviewed scope SHA-256 is required')
    actual_head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, timeout=15).decode('ascii').strip()
    require(actual_head == expected_head, 'checkout differs from reviewed head')
    scope = human_spatial_stage.review_scope()
    require(scope['sha256'] == expected_scope, 'source differs from reviewed scope')
    return scope


def run(output, byond_bin, archive, expected_head, expected_scope):
    require(sys.platform.startswith('linux'), 'hosted Linux only; Windows no-listener policy unchanged')
    require(not output.exists(), 'output must not already exist')
    approved = verify_review(expected_head, expected_scope)
    try:
        manifest = human_spatial_stage.stage(output)
    except Exception as exc:
        if output.is_dir() and not output.is_symlink():
            with (output / 'human-spatial-run.json').open('x', encoding='utf-8') as f:
                json.dump({'execution': 'staging_failed', 'error': str(exc)}, f, indent=2)
        raise
    head, stage = manifest['head'], output / 'stage'
    require(head == expected_head and manifest['review_scope_sha256'] == expected_scope, 'stage differs from reviewed source')
    require(all(manifest['candidate_overlays'][p]['candidate_sha256'] == approved['files'][p]['sha256'] for p in human_spatial_stage.OVERLAY), 'staged overlay differs from reviewed scope')
    require(manifest['fixture_sha256'] == approved['files']['tests/movement_save_chunks/human_spatial_probe.dm']['sha256'], 'staged fixture differs from reviewed scope')
    require(all(value == approved['files'][p]['sha256'] for p, value in manifest['driver_inputs'].items()), 'staged driver differs from reviewed scope')
    verify_review(expected_head, expected_scope)
    source_bytes = sum(row['bytes'] for row in manifest['stage_files'].values())
    compiler, daemon = byond_bin / 'DreamMaker', byond_bin / 'DreamDaemon'
    plan = ['stage/compile', 'writer-ordinary/writer', 'reader-ordinary/reader',
            'writer-restart/writer', 'reader-restart/reader', 'reader-obstruction/reader-obstruction', 'drag/drag'] + ['negative-' + case + '/negative' for case in NEGATIVES]
    result = {'head': head, 'execution': 'running', 'plan': plan, 'phases': [],
              'boundaries': {'egress_sandbox': False, 'sampled_workdir_output_bytes': MAX_BYTES,
                             'output_scope': 'per runtime directory; compile allowance above staged source',
                             'rss_scope': 'sampled leader only; address-space limit inherited per process',
                             'sampled_log_bytes': MAX_LOG, 'hard_address_space_bytes': 1024**3,
                             'hard_individual_file_bytes': MAX_BYTES,
                             'native_sequence_seconds': 600, 'phase_seconds': 90,
                             'staging_in_sequence_deadline': False}}
    summary = output / 'human-spatial-run.json'
    job_deadline = time.monotonic() + 600
    def record(): summary.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    def phase(command, cwd, name):
        verify_review(expected_head, expected_scope)
        require(all(digest(ROOT / p) == expected for p, expected in manifest['driver_inputs'].items()), 'driver input changed')
        identity = benchmark.verify_runtime(byond_bin, archive)
        result['phases'].append({'name': name, 'key': cwd.relative_to(output).as_posix() + '/' + name, 'identity': identity, 'status': 'starting'})
        record()
        try:
            row = launch(command, cwd, name, 90, job_deadline, byond_bin, source_bytes if name == 'compile' else 0)
            result['phases'][-1].update(status='exited', process=row)
        except Exception as exc:
            result['phases'][-1].update(status='failed', error=str(exc))
            record()
            raise
        record()
    def runtime_dir(name):
        work = output / name
        work.mkdir()
        for ext in ('.dmb', '.rsc'):
            binary = stage / ('human_subtile' + ext)
            if binary.exists():
                require(digest(binary) == result['artifacts'][binary.name], 'compiled artifact changed')
                shutil.copy2(binary, work / binary.name)
                require(digest(work / binary.name) == result['artifacts'][binary.name], 'runtime artifact copy changed')
        require((work / 'human_subtile.dmb').is_file(), 'compiled DMB missing')
        shutil.copytree(stage / 'config', work / 'config')
        (work / 'map_saves').mkdir()
        (work / 'map_backups').mkdir()
        return work
    def execute(work, phase_name, extra=''):
        require(all((work / name).is_file() and digest(work / name) == value for name, value in result['artifacts'].items()), 'runtime artifact changed before launch')
        params = 'tested_commit=' + head + '&phase=' + phase_name + extra
        phase([str(daemon), 'human_subtile.dmb', '-trusted', '-ip', '127.0.0.1', '-nowebclient', '-log', 'runtime.log', '-params', params], work, phase_name)
        row = json_read(work / ('human-spatial-' + phase_name + '.json'))
        receipt(row, phase_name, head)
        return row
    try:
        record()
        require(hashes(stage, total_limit=2 * 1024**3, max_entries=12000) == manifest['stage_files'], 'staged source changed before compile')
        require(compiler.is_file() and daemon.is_file(), 'pinned BYOND binaries missing')
        phase([str(compiler), '-max_errors', '0', 'human_subtile.dme'], stage, 'compile')
        compile_log = (stage / 'compile-stdout.log').read_text(errors='replace') + (stage / 'compile-stderr.log').read_text(errors='replace')
        require(benchmark.compile_ok({'status': 'exited', 'returncode': 0}, compile_log, stage / 'human_subtile.dmb'), 'compile output failed strict validation')
        require(all((stage / name).is_file() and not (stage / name).is_symlink() and digest(stage / name) == row['sha256'] for name, row in manifest['stage_files'].items()), 'staged source changed during compilation')
        result['artifacts'] = {p.name: digest(p) for p in (stage / 'human_subtile.dmb', stage / 'human_subtile.rsc') if p.is_file()}
        require('human_subtile.dmb' in result['artifacts'], 'compiled DMB missing')
        record()
        seeds = {}
        expected_receipts = {}
        for mode in ('ordinary', 'restart'):
            writer = runtime_dir('writer-' + mode)
            saved = writer_receipt(execute(writer, 'writer', '&mode=' + mode), head, mode)
            expected_receipts[mode] = saved
            seeds[mode] = hashes(writer / 'map_saves')
            require((writer / 'map_saves/save_complete.txt').read_text().strip() == saved['generation'], 'writer marker differs from receipt')
            reader = runtime_dir('reader-' + mode)
            shutil.copytree(writer / 'map_saves', reader / 'map_saves', dirs_exist_ok=True)
            require(hashes(reader / 'map_saves') == seeds[mode], 'reader seed copy changed')
            (reader / 'human-spatial-expected.json').write_text(json.dumps(saved), encoding='utf-8')
            reader_receipt(execute(reader, 'reader'), head, saved)
            require(hashes(writer / 'map_saves') == seeds[mode], 'writer seed changed')
        seed = output / 'writer-ordinary' / 'map_saves'
        blocked_reader = runtime_dir('reader-obstruction')
        shutil.copytree(seed, blocked_reader / 'map_saves', dirs_exist_ok=True)
        require(hashes(blocked_reader / 'map_saves') == seeds['ordinary'], 'obstruction reader seed copy changed')
        (blocked_reader / 'human-spatial-expected.json').write_text(json.dumps(expected_receipts['ordinary']), encoding='utf-8')
        obstruction_reader_receipt(execute(blocked_reader, 'reader-obstruction'), head, expected_receipts['ordinary'])
        require(hashes(seed) == seeds['ordinary'] and hashes(blocked_reader / 'map_saves') == seeds['ordinary'], 'obstruction reader changed saved generation')
        drag = execute(runtime_dir('drag'), 'drag')
        require(drag.get('living_completions') == 1 and drag.get('human_completions') == 1, 'drag completion mismatch')
        for case, expected in NEGATIVES.items():
            work = runtime_dir('negative-' + case)
            shutil.copytree(seed, work / 'map_saves', dirs_exist_ok=True)
            require(hashes(work / 'map_saves') == seeds['ordinary'], 'negative seed copy changed')
            execute_negative(execute, work, seed, case, expected)
        require(time.monotonic() < job_deadline, 'native sequence deadline exceeded before final acceptance')
        result['execution'] = 'passed'
    except Exception as exc:
        result.update(execution='failed', error=str(exc))
        raise
    finally:
        started = {row['key'] for row in result['phases']}
        result['not_started'] = [key for key in plan if key not in started]
        record()
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--byond-archive', type=Path, required=True)
    parser.add_argument('--expected-head', required=True)
    parser.add_argument('--expected-scope-sha256', required=True)
    parser.add_argument('--run-native', action='store_true', required=True)
    args = parser.parse_args()
    run(args.output.resolve(), args.byond_bin.resolve(), args.byond_archive.resolve(), args.expected_head, args.expected_scope_sha256)
