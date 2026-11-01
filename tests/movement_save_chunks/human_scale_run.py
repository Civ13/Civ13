"""Fixed hosted Linux scale comparison. Native execution needs separate approval.

The driver never downloads a toolchain, accepts no command or remote endpoint,
and only writes a new direct child of the hosted runner's temporary directory.
The two source variants differ only by the experimental macro. Sampling is not a
hard aggregate disk quota or a network sandbox.
"""
from __future__ import annotations
import argparse
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
import human_scale_stage as stage_adapter
import human_spatial_run as common

GIB = 1024**3
MEMORY = 2 * GIB
FILE_BYTES = 2 * GIB
RUNTIME_BYTES = 3 * GIB
STAGE_BYTES = 2 * GIB
MIN_FREE_START = 16 * GIB
MIN_FREE_DURING = 2 * GIB
JOB_SECONDS = 3600
COMPILE_SECONDS = 120
DAEMON_SECONDS = 900
MAX_FILES = 4096
MAX_LOG = 8 * 1024**2
MAX_MEMORY_OBSERVATIONS = 20000
PLAN = ('compile-disabled', 'compile-enabled', 'disabled-writer', 'disabled-reader',
        'enabled-writer', 'enabled-reader')


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


def verify_review(head, scope):
    require(re.fullmatch(r'[0-9a-f]{40}', head or '') is not None, 'reviewed full head required')
    require(re.fullmatch(r'[0-9a-f]{64}', scope or '') is not None, 'reviewed scope required')
    actual = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, timeout=15).decode().strip()
    require(actual == head, 'reviewed head mismatch')
    for command in (['git', 'diff', '--quiet', 'HEAD', '--'], ['git', 'diff', '--cached', '--quiet']):
        require(subprocess.run(command, cwd=ROOT, timeout=15).returncode == 0, 'tracked source is dirty')
    untracked = subprocess.check_output(['git', 'ls-files', '--others', '--exclude-standard', '-z'], cwd=ROOT, timeout=15)
    # The canonical bootstrap creates this one nonignored installation tree.
    # Its reviewed archive and four native members are reverified before each
    # launch; system libraries and other archive members are not certified.
    require(all(path.startswith(b'BYOND/') for path in untracked.split(b'\0') if path), 'untracked source exists')
    current = stage_adapter.review_scope()
    require(current['sha256'] == scope, 'reviewed scope mismatch')
    return current


def checked_output(output, environment):
    require(environment.get('GITHUB_ACTIONS') == 'true', 'hosted CI context required')
    raw_temp = environment.get('RUNNER_TEMP')
    require(bool(raw_temp), 'runner temporary root required')
    temp = Path(raw_temp)
    require(temp.is_absolute() and temp.is_dir() and not temp.is_symlink(), 'invalid runner temporary root')
    temp = temp.resolve(strict=True)
    output = Path(output)
    try:
        direct_parent = output.is_absolute() and output.parent.resolve(strict=True) == temp
    except OSError:
        direct_parent = False
    require(direct_parent, 'output must be a direct runner-temp child')
    require(not output.exists() and not output.is_symlink(), 'output already exists')
    return output


def free_space(path, minimum):
    available = shutil.disk_usage(path).free
    require(available >= minimum, 'insufficient available disk space')
    return available


def pinned_runtime_paths(byond_bin, archive):
    expected_root = ROOT / 'BYOND'
    expected_bin = expected_root / 'byond/bin'
    expected_archive = expected_root / 'pinned.zip'
    require(all(not path.is_symlink() for path in (expected_root, expected_root / 'byond', expected_bin, expected_archive)), 'linked runtime path refused')
    require(expected_bin.is_dir() and expected_archive.is_file(), 'canonical bootstrap paths missing')
    try:
        matches = (Path(byond_bin).resolve(strict=True) == expected_bin.resolve(strict=True) and
                   Path(archive).resolve(strict=True) == expected_archive.resolve(strict=True))
    except OSError:
        matches = False
    require(matches, 'noncanonical runtime path refused')
    return expected_bin, expected_archive


def check_deadline(deadline):
    require(time.monotonic() < deadline, 'native sequence deadline exceeded during file work')


def bounded_digest(path, deadline):
    """Stream a stable regular file under the per-file and sequence limits."""
    import hashlib
    check_deadline(deadline)
    require(path.is_file() and not path.is_symlink(), 'invalid hash input')
    before = path.stat().st_size
    require(before <= FILE_BYTES, 'hash input exceeds per-file limit')
    digest = hashlib.sha256()
    total = 0
    with path.open('rb') as handle:
        while True:
            check_deadline(deadline)
            chunk = handle.read(1024 * 1024)
            if not chunk:
                break
            total += len(chunk)
            require(total <= FILE_BYTES, 'hash input grew beyond per-file limit')
            digest.update(chunk)
    require(total == before and path.stat().st_size == before and not path.is_symlink(), 'hash input changed')
    check_deadline(deadline)
    return digest.hexdigest()


def bounded_hashes(root, deadline, total_limit, max_entries):
    check_deadline(deadline)
    entries = common.inventory(root, total_limit=total_limit, max_entries=max_entries)
    return {name: {'bytes': row['bytes'], 'sha256': bounded_digest(root / name, deadline)}
            for name, row in entries.items()}


def copy_file_bounded(source, target, deadline, disk_root):
    """Copy a regular file without overwriting, checking limits while streaming."""
    import hashlib
    check_deadline(deadline)
    require(source.is_file() and not source.is_symlink(), 'invalid copy input')
    free_space(disk_root, MIN_FREE_DURING)
    size = source.stat().st_size
    require(size <= FILE_BYTES and not target.exists() and not target.is_symlink(), 'invalid copy size or destination')
    digest = hashlib.sha256()
    total = 0
    with source.open('rb') as src, target.open('xb') as dst:
        while True:
            check_deadline(deadline)
            chunk = src.read(1024 * 1024)
            if not chunk:
                break
            total += len(chunk)
            require(total <= size and total <= FILE_BYTES, 'copy input grew')
            dst.write(chunk)
            digest.update(chunk)
            if total % (16 * 1024**2) == 0:
                free_space(disk_root, MIN_FREE_DURING)
    require(total == size and source.stat().st_size == size and not source.is_symlink(), 'copy input changed')
    free_space(disk_root, MIN_FREE_DURING)
    check_deadline(deadline)
    return {'bytes': total, 'sha256': digest.hexdigest()}


def copy_tree_bounded(source, target, deadline, disk_root, total_limit, max_entries):
    check_deadline(deadline)
    entries = common.inventory(source, total_limit=total_limit, max_entries=max_entries)
    require(not target.is_symlink() and (not target.exists() or (target.is_dir() and not any(target.iterdir()))), 'copy tree destination is not empty')
    target.mkdir(parents=True, exist_ok=True)
    copied = {}
    for name, row in entries.items():
        check_deadline(deadline)
        destination = target / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        copied[name] = copy_file_bounded(source / name, destination, deadline, disk_root)
        require(copied[name]['bytes'] == row['bytes'], 'copy tree input changed')
    return copied


def bounded_child():
    import resource
    resource.setrlimit(resource.RLIMIT_AS, (MEMORY, MEMORY))
    resource.setrlimit(resource.RLIMIT_FSIZE, (FILE_BYTES, FILE_BYTES))


def record_memory(samples, memory, elapsed):
    observations = samples.setdefault('observations', [])
    require(len(observations) < MAX_MEMORY_OBSERVATIONS, 'memory observation budget exceeded')
    # Preserve the raw available /proc measurements, including empty/missing
    # observations, before applying any acceptance or resource checks.
    observation = {'elapsed_seconds': elapsed, 'memory': dict(memory)}
    observations.append(observation)
    require(all(type(value) is int and value >= 0 for value in memory.values()), 'invalid memory observation')
    return observation


def reconcile_rss(pid, samples, cutoff, clock=time.monotonic, sleeper=time.sleep, phase_started=None):
    require(samples['count'] > 0, 'RSS was not previously sampled')
    require('missing_rss_probes' not in samples, 'repeated RSS sampling unavailable')
    started = clock()
    if phase_started is None:
        phase_started = started
    cutoff = min(cutoff, started + 0.1)
    probes = samples['missing_rss_probes'] = []
    for _ in range(10):
        if clock() >= cutoff:
            break
        exited = common.child_exited_unreaped(pid)
        memory = {} if exited else benchmark.proc_memory(pid)
        record_memory(samples, memory, clock() - phase_started)
        probes.append({'waitid_exit_observed': exited, 'rss_bytes': memory.get('rss_bytes'),
                       'later_proc_state': common.observed_proc_state(pid), 'elapsed_seconds': clock() - started})
        if clock() >= cutoff:
            break
        if exited:
            samples['rss_exit_race'] = True
            return
        if memory.get('rss_bytes', 0) > 0:
            require(memory['rss_bytes'] <= MEMORY, 'sampled RSS exceeded')
            samples['count'] += 1
            samples['peak_rss'] = max(samples['peak_rss'], memory['rss_bytes'])
            samples['rss_recovered'] = True
            return
        remaining = cutoff - clock()
        if remaining > 0:
            sleeper(min(0.01, remaining))
    raise RuntimeError('RSS sampling unavailable')


def monitor_for(folder, started, deadline, expected_entry=None, stage_bytes=0):
    samples = {'count': 0, 'peak_rss': 0, 'entry_observed_seconds': None}
    def monitor(pid, cwd):
        require(time.monotonic() < deadline, 'phase or job deadline exceeded')
        memory = benchmark.proc_memory(pid)
        observation = record_memory(samples, memory, time.monotonic() - started)
        if memory.get('rss_bytes', 0) > 0:
            require(memory['rss_bytes'] <= MEMORY, 'sampled RSS exceeded')
            samples['count'] += 1
            samples['peak_rss'] = max(samples['peak_rss'], memory['rss_bytes'])
        elif time.monotonic() - started > 1:
            reconcile_rss(pid, samples, deadline, phase_started=started)
        observation['free_bytes'] = free_space(folder, MIN_FREE_DURING)
        if expected_entry is None:
            entries = common.inventory(folder, total_limit=stage_bytes + RUNTIME_BYTES, max_entries=12000)
        else:
            entries = common.inventory(folder, total_limit=RUNTIME_BYTES, max_entries=MAX_FILES)
        observation['directory_files'] = len(entries)
        observation['directory_bytes'] = sum(row['bytes'] for row in entries.values())
        if expected_entry is not None:
            path = folder / 'human-scale-entry.json'
            if samples['entry_observed_seconds'] is None and path.exists():
                require(path.is_file() and not path.is_symlink() and path.stat().st_size <= 4096, 'invalid entry receipt')
                try:
                    row = json.loads(path.read_text(encoding='utf-8'))
                except (OSError, ValueError):
                    return  # Writer may still be flushing; the phase deadline remains active.
                validate_entry(row, *expected_entry)
                samples['entry_observed_seconds'] = time.monotonic() - started
    return monitor, samples


def launch(command, cwd, label, seconds, job_deadline, byond_bin, expected_entry=None, stage_bytes=0):
    start = time.monotonic()
    require(start < job_deadline, 'native sequence deadline exceeded before launch')
    phase_deadline = min(job_deadline, start + seconds)
    monitor, samples = monitor_for(cwd, start, phase_deadline, expected_entry, stage_bytes)
    env = {'PATH': '/usr/bin:/bin', 'HOME': str(cwd), 'TMPDIR': str(cwd),
           'LANG': 'C', 'LC_ALL': 'C', 'LD_LIBRARY_PATH': str(byond_bin)}
    trace = {'events': [], 'status': 'starting', 'memory': samples}
    def event(name, value):
        trace['events'].append({'event': name, 'value': value})
    try:
        # Use the existing cleanup owner and its strict native diagnostic scanner.
        name = 'compile' if expected_entry is None else expected_entry[1]
        row = common.legacy.run_process(command, cwd, name, phase_deadline - start,
                 preexec_fn=bounded_child, monitor=monitor, env=env, retain_leader=True, on_event=event)
        require(samples['count'] > 0, 'RSS was not sampled')
        require(time.monotonic() < job_deadline, 'native sequence deadline exceeded after phase')
        if expected_entry is not None:
            require(samples['entry_observed_seconds'] is not None, 'startup entry was not observed')
            common.inventory(cwd, total_limit=RUNTIME_BYTES, max_entries=MAX_FILES)
        row['memory'] = samples
        trace.update(status='exited', process=row)
        return row
    except Exception as exc:
        trace.update(status='failed', error=str(exc))
        raise
    finally:
        (cwd / (label + '-supervision.json')).write_text(json.dumps(trace, indent=2) + '\n', encoding='utf-8')


def validate_entry(row, head, phase, variant):
    require(type(row) is dict and row.get('head') == head and row.get('phase') == phase and row.get('variant') == variant,
            'entry identity mismatch')
    require((row.get('byond_version'), row.get('byond_build'), row.get('port')) == (516, 1688, 0), 'entry engine or port mismatch')


def load_receipt(path, head, phase, variant):
    require(path.is_file() and not path.is_symlink() and path.stat().st_size <= 16384, 'missing or oversized scale receipt')
    row = json.loads(path.read_text(encoding='utf-8'))
    validate_entry(row, head, phase, variant)
    require(row.get('error') is None and row.get('heartbeat_count', 0) > 0, 'scale fixture failed or heartbeat missing')
    require(type(row.get('heartbeat_max_gap_deciseconds')) is int and row['heartbeat_max_gap_deciseconds'] >= 0, 'invalid heartbeat')
    require(row.get('heartbeat_scope') == 'post_initialization_setup_save_or_load_and_inspection', 'heartbeat scope missing')
    for field in ('setup_deciseconds', 'inspection_deciseconds', 'save_deciseconds' if phase == 'writer' else 'load_deciseconds'):
        require(type(row.get(field)) is int and row[field] >= 0, 'invalid phase timing: ' + field)
    generation = row.get('generation')
    require(isinstance(generation, str) and re.fullmatch(r'round-v[12]:[0-9a-f]{32}', generation), 'invalid generation')
    require(row.get('world_turfs') == 350000, 'world dimension count mismatch')
    require(row.get('world_turfs_basis') == 'dimension_product_not_a_restored_turf_scan', 'world count basis missing')
    if phase == 'writer':
        require(row.get('saved_turfs') == 350000 and row.get('setup_humans') == 32 and row.get('setup_ground') == 5000,
                'saved or setup count mismatch')
        require(row.get('saved_turf_slot_check') == 'positive_integer_refs_not_unique_or_type_verified', 'saved slot scope missing')
        require(type(row.get('serialization_and_flush_deciseconds')) is int and row['serialization_and_flush_deciseconds'] >= 0,
                'serialization boundary timing missing')
        if variant == 'enabled':
            require(type(row.get('human_candidate_checks_deciseconds')) is int and row['human_candidate_checks_deciseconds'] >= 0,
                    'human candidate-check timing missing')
            require(row.get('geometry_metrics') is None, 'obsolete fractional geometry metrics present')
        else:
            require(row.get('human_candidate_checks_deciseconds') is None and row.get('geometry_metrics') is None,
                    'disabled variant unexpectedly ran candidate checks')
    else:
        require(row.get('restored_humans') == 32 and row.get('restored_ground') == 5000, 'restored object count mismatch')
    return row


def read_marker(path):
    require(path.is_file() and not path.is_symlink() and path.stat().st_size <= 256, 'invalid completion marker')
    return path.read_text(encoding='utf-8').strip()


def run(output, byond_bin, archive, reviewed_head, reviewed_scope):
    require(sys.platform.startswith('linux'), 'Linux hosted runner only')
    output = checked_output(output, os.environ)
    free_space(output.parent, MIN_FREE_START)
    verify_review(reviewed_head, reviewed_scope)
    byond_bin, archive = pinned_runtime_paths(byond_bin, archive)
    output.mkdir()
    summary = output / 'human-scale-run.json'
    result = {'head': reviewed_head, 'scope_sha256': reviewed_scope, 'execution': 'starting', 'phases': [], 'plan': list(PLAN),
              'comparison': 'fixed_stationary_single_sample', 'product_acceptance': 'not_evaluated',
              'unmeasured': ['capture_boundary', 'other_candidate_validation_boundary', 'file_write_only_boundary', 'maximum_work_slice'],
              'limits': {'job_seconds': JOB_SECONDS, 'compile_seconds': COMPILE_SECONDS,
                         'daemon_seconds': DAEMON_SECONDS, 'hard_address_space_bytes': MEMORY,
                         'hard_individual_file_bytes': FILE_BYTES, 'sampled_runtime_bytes': RUNTIME_BYTES,
                         'sampled_max_files': MAX_FILES, 'sampled_log_bytes': MAX_LOG,
                         'nominal_sample_interval_seconds': 0.05, 'rss_scope': 'sampled leader only',
                         'minimum_free_start': MIN_FREE_START, 'minimum_free_during': MIN_FREE_DURING,
                         'aggregate_disk_quota': False, 'egress_sandbox': False}}
    def record():
        summary.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    record()
    try:
        prepared = output / 'source'
        manifest = stage_adapter.prepare(prepared, reviewed_head, reviewed_scope)
        verify_review(reviewed_head, reviewed_scope)
        stage = prepared / 'stage'
        source_bytes = sum(row['bytes'] for row in manifest['stage_files'].values())
        require(source_bytes <= STAGE_BYTES, 'staged source exceeds limit')
        # Staging is outside the native-sequence watchdog; the hosted 90-minute
        # job timeout remains the outer bound. Bound this initial audit itself.
        stage_deadline = time.monotonic() + 600
        require(bounded_hashes(stage, stage_deadline, STAGE_BYTES, 12000) == manifest['stage_files'], 'staged source changed')
        compiler, daemon = byond_bin / 'DreamMaker', byond_bin / 'DreamDaemon'
        require(compiler.is_file() and daemon.is_file(), 'pinned native tools missing')
        deadline = time.monotonic() + JOB_SECONDS
        binaries = {}
        def phase(command, cwd, label, seconds, entry=None):
            verify_review(reviewed_head, reviewed_scope)
            free_space(output, MIN_FREE_DURING)
            identity = benchmark.verify_runtime(byond_bin, archive)
            item = {'name': label, 'status': 'starting', 'identity': identity}
            result['phases'].append(item)
            record()
            try:
                item['process'] = launch(command, cwd, label, seconds, deadline, byond_bin, entry, source_bytes)
                item['status'] = 'exited'
            except Exception as exc:
                item.update(status='failed', error=str(exc))
                raise
            finally:
                record()
        for variant in ('disabled', 'enabled'):
            try:
                phase([str(compiler), '-max_errors', '0', 'human_scale_' + variant + '.dme'], stage, 'compile-' + variant, COMPILE_SECONDS)
                log = (stage / 'compile-stdout.log').read_text(errors='replace') + (stage / 'compile-stderr.log').read_text(errors='replace')
                artifact = stage / ('human_scale_' + variant + '.dmb')
                common.legacy.validate_compile(log, artifact.name)
                require(artifact.is_file() and artifact.stat().st_size > 0, 'compiled scale DMB missing')
                binaries[variant] = {p.name: bounded_digest(p, deadline) for p in (artifact, artifact.with_suffix('.rsc')) if p.is_file()}
                require(all(bounded_digest(stage / name, deadline) == row['sha256'] for name, row in manifest['stage_files'].items()), 'staged source changed during compile')
            finally:
                for stream in ('stdout', 'stderr'):
                    src = stage / ('compile-' + stream + '.log')
                    if src.exists():
                        src.rename(stage / ('compile-' + variant + '-' + stream + '.log'))
        observations = {}
        for variant in ('disabled', 'enabled'):
            def workdir(phase_name):
                work = output / (variant + '-' + phase_name)
                work.mkdir()
                for name, digest in binaries[variant].items():
                    require(bounded_digest(stage / name, deadline) == digest, 'compiled artifact changed')
                    copied = copy_file_bounded(stage / name, work / name, deadline, output)
                    require(copied['sha256'] == digest, 'artifact copy changed')
                copy_tree_bounded(stage / 'config', work / 'config', deadline, output, RUNTIME_BYTES, MAX_FILES)
                (work / 'map_saves').mkdir()
                (work / 'map_backups').mkdir()
                return work
            def execute(work, phase_name):
                require(all(bounded_digest(work / name, deadline) == digest for name, digest in binaries[variant].items()), 'runtime artifact changed')
                params = 'tested_commit=' + reviewed_head + '&phase=' + phase_name + '&variant=' + variant
                phase([str(daemon), 'human_scale_' + variant + '.dmb', '-trusted', '-ip', '127.0.0.1', '-nowebclient', '-log', 'runtime.log', '-params', params], work, variant + '-' + phase_name, DAEMON_SECONDS, (reviewed_head, phase_name, variant))
                return load_receipt(work / ('human-scale-' + phase_name + '.json'), reviewed_head, phase_name, variant)
            writer = workdir('writer')
            saved = execute(writer, 'writer')
            seed = bounded_hashes(writer / 'map_saves', deadline, RUNTIME_BYTES, MAX_FILES)
            require(read_marker(writer / 'map_saves/save_complete.txt') == saved['generation'], 'writer marker mismatch')
            reader = workdir('reader')
            copied = copy_tree_bounded(writer / 'map_saves', reader / 'map_saves', deadline, output, RUNTIME_BYTES, MAX_FILES)
            require(copied == seed and bounded_hashes(reader / 'map_saves', deadline, RUNTIME_BYTES, MAX_FILES) == seed, 'reader seed differs')
            (reader / 'human-scale-expected.json').write_text(json.dumps({'generation': saved['generation']}), encoding='utf-8')
            restored = execute(reader, 'reader')
            require(restored['generation'] == saved['generation'], 'reader generation mismatch')
            require(bounded_hashes(writer / 'map_saves', deadline, RUNTIME_BYTES, MAX_FILES) == seed, 'writer seed changed')
            observations[variant] = {'writer': saved, 'reader': restored, 'saved_files': seed}
        require(time.monotonic() < deadline, 'native sequence deadline exceeded before acceptance')
        result.update(execution='completed_measurement', observations=observations)
    except Exception as exc:
        result.update(execution='failed', error=str(exc))
        raise
    finally:
        started = {row['name'] for row in result['phases']}
        result['not_started'] = [name for name in PLAN if name not in started]
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
    run(args.output, args.byond_bin, args.byond_archive, args.expected_head, args.expected_scope_sha256)
