"""Bounded Linux writer/fresh-reader probe; native execution requires approval."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import time

import stage

MAX_FILE = 256 * 1024**2
MAX_OUTPUT = 256 * 1024**2  # sampled, not an aggregate filesystem quota
MAX_LOG = 8 * 1024**2
MAX_ENTRIES = 4096
MAX_DEPTH = 16
MAX_AS = 1024**3
NATIVE_SECONDS = 360
PHASE_SECONDS = 120
DIAGNOSTIC = re.compile(
    r'infinite[ _]loop|switching proc to background|runtime error|unexpected runtime|'
    r'\bBad ref\b|\bBad loc\b|Cannot read null|Cannot execute null|\bBUG:|'
    r'##\s*ERROR\s*:|uncaught exception|fatal error|segmentation|assertion failed|\bRUNTIME:|'
    r'\bOOM\b|out of memory|access violation|\bCRASH(?:ED)?\b|invalid file', re.I)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def bounded_bytes(path, maximum):
    require(path.is_file() and not path.is_symlink(), 'missing or non-regular file')
    with path.open('rb') as stream:
        data = stream.read(maximum + 1)
    require(len(data) <= maximum, 'file exceeded read budget')
    return data


def copy_name_data(staged, work, deadline):
    """Copy only committed fixture name data with explicit size and entry limits."""
    source = staged / 'config' / 'names'
    require(not (staged / 'config').is_symlink() and source.is_dir() and not source.is_symlink(), 'invalid name data root')
    target = work / 'config' / 'names'
    target.mkdir(parents=True)
    total = count = 0
    with os.scandir(source) as entries:
        for entry in entries:
            require(time.monotonic() < deadline, 'name data deadline')
            count += 1
            require(count <= 512 and not entry.is_symlink() and entry.is_file(follow_symlinks=False), 'invalid name data entry')
            data = bounded_bytes(Path(entry.path), 8 * 1024**2 - total)
            total += len(data)
            (target / entry.name).write_bytes(data)
    require(count > 0, 'name data absent')


def inventory(root, deadline):
    stack, rows, total = [(root, 0)], {}, 0
    while stack:
        require(time.monotonic() < deadline, 'inventory deadline')
        directory, depth = stack.pop()
        require(depth <= MAX_DEPTH, 'output depth exceeded')
        with os.scandir(directory) as it:
            for entry in it:
                require(time.monotonic() < deadline and len(rows) < MAX_ENTRIES, 'output inventory bound')
                require(not entry.is_symlink(), 'output symlink refused')
                p = Path(entry.path)
                name = p.relative_to(root).as_posix()
                if entry.is_dir(follow_symlinks=False):
                    rows[name + '/'] = None
                    stack.append((p, depth + 1))
                else:
                    require(entry.is_file(follow_symlinks=False), 'non-file output refused')
                    size = entry.stat(follow_symlinks=False).st_size
                    require(size <= MAX_FILE and (p.suffix != '.log' or size <= MAX_LOG), 'file budget')
                    total += size
                    require(total <= MAX_OUTPUT, 'sampled aggregate output budget')
                    rows[name] = size
    return rows


def file_hash(path):
    return hashlib.sha256(bounded_bytes(path, MAX_FILE)).hexdigest()


def saved_hashes(directory):
    # Exact list: neither unexpected extra save files nor missing files are ignored.
    expected = {'map.txt', 'round.json', '1.sav', 'save_complete.txt'}
    require(directory.is_dir() and not directory.is_symlink(), 'save directory absent')
    require({p.name for p in directory.iterdir()} == expected, 'unexpected save inventory')
    return {name: file_hash(directory / name) for name in sorted(expected)}


def read_receipt(path, phase, head, reviewed_scope):
    row = json.loads(bounded_bytes(path, 1024**2))
    require(type(row) is dict and row.get('phase') == phase and row.get('head') == head and row.get('scope') == reviewed_scope, 'receipt identity')
    require((row.get('byond_version'), row.get('byond_build'), row.get('port')) == (516, 1688, 0), 'wrong engine or port')
    require(row.get('error') is None, 'fixture error: ' + str(row.get('error'))[:512])
    return row


def validate_compile(log):
    lines = log.splitlines()
    banners = [line for line in lines if re.search(r'DM compiler version', line, re.I)]
    results = [line for line in lines if re.search(r'\berrors?\b|\bwarnings?\b', line, re.I)]
    require(banners == ['DM compiler version 516.1688'], 'compiler identity')
    summary = r'human_subtile\.dmb - 0 errors, 0 warnings(?: \(\d{1,2}/\d{1,2}/\d{2,4} \d{1,2}:\d{2}(?::\d{2})? (?:am|pm)\))?'
    require(len(results) == 1 and re.fullmatch(summary, results[0]) and lines.index(banners[0]) < lines.index(results[0]), 'compiler diagnostics')


class RuntimeIdentity:
    """Reverify the archive's two executables and two libraries before launch."""
    def __init__(self, byond, archive, reviewed_scope, output, verifier=None):
        self.byond, self.archive = byond, archive
        self.scope, self.output = reviewed_scope, output
        if verifier is None:
            spec = importlib.util.spec_from_file_location('debug_fixture_runtime_identity', stage.ROOT / 'scripts/byond_runtime.py')
            verifier = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(verifier)
        self.verifier = verifier
        self.identity = verifier.verify_linux(byond, archive)
        require(self.identity.get('version') == '516.1688', 'runtime pin mismatch')
        require(set(self.identity.get('members', {})) == {'DreamMaker', 'DreamDaemon', 'libbyond.so', 'libext.so'}, 'runtime members incomplete')
        self.checked = []

    def before(self, role):
        try:
            require(stage.scope()['sha256'] == self.scope, 'reviewed input scope changed')
            require(self.verifier.verify_linux(self.byond, self.archive) == self.identity, 'runtime identity changed')
            self.checked.append(role)
            record = {'identity': self.identity, 'verified_before': self.checked}
        except Exception as exc:
            record = {'identity': self.identity, 'verified_before': self.checked, 'error': str(exc)[:1024]}
            (self.output / 'runtime-identity.json').write_text(json.dumps(record, indent=2), encoding='utf-8')
            raise
        (self.output / 'runtime-identity.json').write_text(json.dumps(record, indent=2), encoding='utf-8')


def child_environment(byond, cwd):
    # Match the existing isolated fixture's minimal environment; no caller
    # environment, credentials or inherited loader settings are passed in.
    return {'PATH': '/usr/bin:/bin', 'HOME': str(cwd), 'TMPDIR': str(cwd),
            'LANG': 'C', 'LC_ALL': 'C', 'LD_LIBRARY_PATH': str(byond)}


def validate_human_writer(writer):
    tile = writer.get('human_tile')
    require(type(tile) is list and len(tile) == 3 and all(type(v) is int for v in tile) and 1 <= tile[0] <= 18 and 1 <= tile[1] <= 14 and tile[2] == 1, 'invalid captured human tile')
    require(type(writer.get('human_handoffs')) is int and writer['human_handoffs'] == 1, 'second-attempt human handoff absent')
    require(type(writer.get('human_pulses_after')) is int and writer['human_pulses_after'] > 0, 'human did not continue after handoff')


def validate_writer(writer, seed, backup, marker, seed_marker):
    require(seed == backup, 'writer changed previous backup')
    require(seed_marker == writer.get('seed_generation'), 'seed marker mismatch')
    require(marker == writer.get('generation') and marker != writer.get('seed_generation'), 'writer marker mismatch')
    require(writer.get('fixture_moves') == 2, 'writer did not reach both capture faults')
    validate_human_writer(writer)
    require(writer.get('controls') == {'unsupported_contents': True, 'missing_child': True, 'nested_list': True, 'owner_bound': True, 'owner_lost': True}, 'writer controls incomplete')
    audit = writer.get('audit')
    require(type(audit) is dict and audit.get('generation') == marker and audit.get('attempt') == 2, 'writer audit binding')


def validate_evidence(writer, reader, seed, backup, current):
    require(seed == backup, 'retained backup bytes differ from seed')
    validate_human_writer(writer)
    require(type(writer.get('human_tile')) is list and reader.get('human_tile') == writer['human_tile'], 'restored human tile differs from writer handoff')
    for key in ('human_centered', 'human_art_and_inventory'):
        value = reader.get(key)
        require(value is True or (type(value) is int and value == 1), 'restored human evidence absent: ' + key)
    generation = writer.get('generation')
    require(isinstance(generation, str) and re.fullmatch(r'round-v2:[0-9a-f]{32}', generation), 'writer generation')
    require(reader.get('generation') == generation and current == generation, 'reader/marker generation mismatch')
    require(writer.get('seed_generation') != generation, 'candidate did not replace seed')
    require(writer.get('fixture_moves') == 2, 'actual failed save and debug attempt not both reached')
    require(writer.get('controls') == {'unsupported_contents': True, 'missing_child': True, 'nested_list': True, 'owner_bound': True, 'owner_lost': True}, 'refusal controls incomplete')
    audit = writer.get('audit')
    require(type(audit) is dict and audit == reader.get('audit'), 'reader audit differs')
    require(audit.get('mode') == 'debug_lossy' and audit.get('outcome') == 'candidate_commit_intent' and audit.get('generation') == generation and audit.get('attempt') == 2, 'audit binding')
    incidents, omissions, history = audit.get('incidents'), audit.get('omissions'), audit.get('attempt_history')
    require(type(incidents) is list and len(incidents) == 1 and type(omissions) is list and 1 <= len(omissions) <= 256 and type(history) is list and len(history) == 1, 'audit counts')
    incident = incidents[0]
    require(incident.get('kind') == 'moved_leaf_animal' and incident.get('action') == 'omit_entity_and_replace_references_with_null' and incident.get('child_type') == '/mob/living/simple_animal/debug_save_fixture', 'wrong omitted identity')
    require(history[0].get('outcome') == 'failed_retryable' and history[0].get('attempt') == 1, 'missing failed attempt')
    require(all(type(row) is dict and row.get('target_ref') == incident.get('child_ref') and row.get('target_type') == incident.get('child_type') and row.get('replacement') in {'null_reference', 'omitted_content', 'roster_not_admitted'} for row in omissions), 'unaccounted omission')
    require(any(row.get('source_type') == '/obj/structure/debug_save_fixture' and row.get('source_ref') == incident.get('parent_ref') and row.get('field') == 'fixture_reference' and row.get('replacement') == 'null_reference' for row in omissions), 'fixture reference omission not audited')
    # BYOND serializes TRUE as the JSON integer 1. Accept only that integer or
    # a literal JSON true; do not accept floats, strings, or missing values.
    def reader_true(value):
        return value is True or (type(value) is int and value == 1)
    require(all(reader_true(reader.get(key)) for key in ('retained_box', 'retained_item', 'retained_control_item', 'omitted_animal', 'reference_null')), 'fresh reader graph')
    return True


def limit_child():
    import resource
    resource.setrlimit(resource.RLIMIT_AS, (MAX_AS, MAX_AS))
    resource.setrlimit(resource.RLIMIT_FSIZE, (MAX_FILE, MAX_FILE))
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))


def owned(command, cwd, role, output, deadline, data_root=None, extra_logs=(), env=None):
    """Linux-only group owner. No success from receipt without owned exit."""
    require(os.name == 'posix' and hasattr(os, 'waitid') and hasattr(os, 'WNOWAIT'), 'Linux owned-child wait unavailable')
    require(time.monotonic() < deadline, 'combined deadline elapsed before launch')
    stdout, stderr = output / (role + '.stdout.log'), output / (role + '.stderr.log')
    record = {'role': role, 'pid': None, 'exit': None, 'timeout': False, 'error': None, 'cleanup': None}
    process = None
    try:
        with stdout.open('wb') as out, stderr.open('wb') as err:
            process = subprocess.Popen(command, cwd=cwd, stdout=out, stderr=err,
                                       start_new_session=True, preexec_fn=limit_child, env=env)
            record['pid'] = process.pid
            phase_deadline = min(deadline, time.monotonic() + PHASE_SECONDS)
            while True:
                if time.monotonic() >= phase_deadline:
                    record['timeout'] = True
                    raise TimeoutError(role + ' deadline')
                if os.waitid(os.P_PID, process.pid, os.WEXITED | os.WNOHANG | os.WNOWAIT) is not None:
                    break
                for log in (stdout, stderr):
                    require(log.stat().st_size <= MAX_LOG, 'sampled log budget')
                for log in extra_logs:
                    if log.exists(): require(log.is_file() and not log.is_symlink() and log.stat().st_size <= MAX_LOG, 'sampled native log budget')
                if data_root is not None:
                    inventory(data_root, phase_deadline)
                time.sleep(.05)
    except Exception as exc:
        record['error'] = str(exc)
    finally:
        if process is not None:
            try:
                os.killpg(process.pid, signal.SIGKILL)
                record['cleanup'] = 'group_signal_sent'
            except ProcessLookupError:
                record['cleanup'] = 'group_absent'
            except OSError as exc:
                record['cleanup'] = 'group_signal_error: ' + str(exc)
            try:
                record['exit'] = process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                record['cleanup'] = 'owned_leader_not_reaped'
        (output / (role + '.process.json')).write_text(json.dumps(record, indent=2), encoding='utf-8')
    require(not record['error'] and record['exit'] == 0 and record['cleanup'] in ('group_signal_sent', 'group_absent'), 'process failure: ' + json.dumps(record))
    for log in (stdout, stderr):
        data = bounded_bytes(log, MAX_LOG).decode(errors='replace')
        require(not DIAGNOSTIC.search(data), 'unexpected native diagnostic')
    return record


def execute(output, head, reviewed_scope, byond, archive):
    require(os.name == 'posix' and not output.exists(), 'fresh Linux output required')
    manifest = stage.stage(output, head, reviewed_scope)
    staged, work = output / 'stage', output / 'runtime'
    work.mkdir()
    for name in ('map_saves', 'map_backups', 'fixture_seed'): (work / name).mkdir()
    deadline = time.monotonic() + NATIVE_SECONDS
    compiler, daemon = byond / 'DreamMaker', byond / 'DreamDaemon'
    records = []
    try:
        copy_name_data(staged, work, deadline)
        require(compiler.is_file() and daemon.is_file(), 'missing pinned executables')
        runtime = RuntimeIdentity(byond, archive, reviewed_scope, output)
        runtime.before('compile')
        records.append(owned([str(compiler), '-max_errors', '0', 'human_subtile.dme'], staged, 'compile', output, deadline, env=child_environment(byond, staged)))
        build = ''.join(bounded_bytes(output / ('compile.' + part + '.log'), MAX_LOG).decode(errors='replace') for part in ('stdout', 'stderr'))
        validate_compile(build)
        for ext in ('.dmb', '.rsc'):
            data = bounded_bytes(staged / ('human_subtile' + ext), MAX_FILE)
            (work / ('human_subtile' + ext)).write_bytes(data)
        writer = None
        original_seed = None
        for phase in ('writer', 'reader'):
            require(time.monotonic() < deadline, 'combined deadline')
            params = f'phase={phase}&tested_commit={head}&scope={reviewed_scope}'
            # DreamDaemon restricts log paths to its own working directory.
            # Keep the log beside the DMB and pass only a relative basename.
            native_log = work / (phase + '.native.log')
            runtime.before(phase)
            records.append(owned([str(daemon), str(work / 'human_subtile.dmb'), '0', '-ip', '127.0.0.1', '-trusted', '-params', params, '-log', native_log.name], work, phase, output, deadline, work, (native_log,), child_environment(byond, work)))
            require(not DIAGNOSTIC.search(bounded_bytes(native_log, MAX_LOG).decode(errors='replace')), 'unexpected native log diagnostic')
            inventory(work, deadline)
            if phase == 'writer':
                writer = read_receipt(work / 'debug-fixture-writer.json', 'writer', head, reviewed_scope)
                original_seed = saved_hashes(work / 'fixture_seed')
                writer_marker = bounded_bytes(work / 'map_saves/save_complete.txt', 256).decode().strip()
                seed_marker = bounded_bytes(work / 'fixture_seed/save_complete.txt', 256).decode().strip()
                validate_writer(writer, original_seed, saved_hashes(work / 'map_backups'), writer_marker, seed_marker)
        reader = read_receipt(work / 'debug-fixture-reader.json', 'reader', head, reviewed_scope)
        marker = bounded_bytes(work / 'map_saves/save_complete.txt', 256).decode().strip()
        require(original_seed == saved_hashes(work / 'fixture_seed'), 'reader changed seed')
        validate_evidence(writer, reader, original_seed, saved_hashes(work / 'map_backups'), marker)
        require(time.monotonic() < deadline, 'combined deadline before acceptance')
        result = {'passed': True, 'head': head, 'scope': reviewed_scope, 'records': records, 'manifest_sha256': file_hash(output / 'debug-fixture-manifest.json')}
        (output / 'accepted.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
        return result
    except Exception as exc:
        (output / 'failure.json').write_text(json.dumps({'error': str(exc), 'records': records}, indent=2), encoding='utf-8')
        raise


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run-native', action='store_true', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--head', required=True)
    parser.add_argument('--scope', required=True)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--byond-archive', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(execute(args.output.resolve(), args.head, args.scope, args.byond_bin.absolute(), args.byond_archive.absolute())))
