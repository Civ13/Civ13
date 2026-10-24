"""Dedicated seven-case cave executor and offline packet freezer.

CLI prepares packets ONLY. run_packet needs an explicitly supplied backend and
separate parent review before any native invocation. No retries or lease handling.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sys
import threading
import time

CASES = ('fixed', 'world-scan', 'duplicate-start', 'missing-stop', 'saved-flag', 'missing-recount', 'baseline')
EXPECTED = {'fixed': None, 'world-scan': 'one initial service count=3 full=0',
            'duplicate-start': 'one chain count=1 full=0', 'missing-stop': 'Destroy stops sleeper',
            'saved-flag': 'timer excluded from custom save', 'missing-recount': 'population recount',
            'baseline': 'one chain count=1 full=0'}
PINNED = {'dm.exe': '8ad7537fc1329ada04e8e1e8835ec9cf205f3e5029461a3ead1f8f4ced7b0bb8',
          'dd.exe': '7b148eceaaae483395b636fab817609b37f8fb852f1d5aad12d29bbcaf1585ae',
          'byondcore.dll': '55cf268a4f054f02d556d2ed3c26ab01b7b0318bb3c5419e85f88e4e3b9e5898'}
FIXTURE_SHA256 = '41d2729a1be979778d6f58be5b673437b597a62fa28d10c748b3c0d7ac018abc'
POLICY = {'child_bytes': 256 * 1024**2, 'compile_seconds': 60, 'runtime_seconds': 20,
          'cleanup_seconds': 5, 'max_cells': 144, 'sample_seconds': .05,
          'min_free_bytes': 1024**3, 'max_output_bytes': 16 * 1024**2}
DIAGNOSTIC = re.compile(r'runtime error:|FAIL wolf cave runtime:|\bbad (?:ref|loc)\b|BUG:|fatal error|'
                        r'out of memory|access violation|segmentation|assertion failed|infinite loop|\bCRASH(?:ED)?\b', re.I)
HERE = Path(__file__).resolve().parent


def require(value, message):
    if not value: raise RuntimeError(message)


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def ordinary_file(path):
    path = Path(path)
    require(path.is_file(), 'Missing regular file: ' + str(path))
    for component in (path, *path.parents):
        require(not component.is_symlink() and not getattr(component, 'is_junction', lambda: False)(),
                'Linked input/output path: ' + str(component))
    return path


def verify_packet(path, expected_sha):
    require(re.fullmatch(r'[0-9a-f]{64}', expected_sha) and digest(ordinary_file(path)) == expected_sha,
            'Packet digest differs from reviewed value')
    packet = json.loads(Path(path).read_text(encoding='utf-8'))
    require(packet.get('schema') == 1 and packet.get('policy') == POLICY and packet.get('cases') == list(CASES),
            'Packet schema, cases or bounds changed')
    require(packet.get('expected') == EXPECTED, 'Negative-control oracles changed')
    require(re.fullmatch(r'[0-9a-f]{40}', packet.get('head', '')), 'Invalid exact head')
    require(packet.get('manifest_sha256') == digest(ordinary_file(packet['manifest'])), 'Source manifest changed')
    manifest = json.loads(Path(packet['manifest']).read_text())
    require(manifest['head'] == packet['head'] and manifest['bounds']['map'] == [12, 12, 1]
            and set(manifest['cases']) == set(CASES), 'Source manifest identity or dimensions changed')
    for name, expected in packet['code'].items():
        require(name in ('executor.py', 'windows_job.py') and digest(ordinary_file(HERE / name)) == expected,
                'Executor code changed: ' + name)
    require(set(packet['code']) == {'executor.py', 'windows_job.py'}, 'Incomplete executor code freeze')
    require(packet['python']['path'] == sys.executable and digest(ordinary_file(sys.executable)) == packet['python']['sha256'],
            'Interpreter changed')
    binroot = Path(packet['bin'])
    actual_names = {p.name for p in binroot.iterdir() if p.is_file() and (p.suffix.lower() == '.dll' or p.name in ('dm.exe', 'dd.exe'))}
    require(actual_names == set(packet['tools']), 'Tool DLL set changed')
    for name, sha in packet['tools'].items():
        require(Path(name).name == name and digest(ordinary_file(binroot / name)) == sha, 'Tool changed: ' + name)
    require(all(packet['tools'].get(name) == sha for name, sha in PINNED.items()), 'Unrecognized official 516.1681 tools')
    source_root = Path(packet['sources'])
    expected_names = {f'{case}/{name}' for case in CASES for name in ('parent.dm', 'production.dm', 'probe.dm', 'probe.dme')}
    require(set(packet['files']) == expected_names, 'Source packet has unexpected paths')
    actual_names = {p.relative_to(source_root).as_posix() for p in source_root.rglob('*') if p.is_file()}
    require(actual_names == expected_names, 'Frozen source set changed')
    for name, sha in packet['files'].items():
        require(digest(ordinary_file(source_root / name)) == sha, 'Frozen source changed: ' + name)
        case, filename = name.split('/')
        require(manifest['cases'][case][filename] == sha, 'Source manifest/file mismatch')
        if filename == 'probe.dm':
            require(sha == FIXTURE_SHA256, 'Fixture differs from the reviewed 144-cell lifecycle probe')
    return packet


def freeze(prepared, byond_bin, output):
    """Copy the exact seven prepared fixtures and freeze all inputs; no native APIs."""
    prepared, byond_bin, output = Path(prepared).resolve(), Path(byond_bin).resolve(), Path(output).absolute()
    manifest_path = ordinary_file(prepared / 'manifest.json')
    manifest = json.loads(manifest_path.read_text())
    require(set(manifest['cases']) == set(CASES) and manifest['bounds']['map'] == [12, 12, 1], 'Wrong prepared fixture set')
    require(not manifest['compiler_executed'] and not manifest['native_executed'], 'Expected an unexecuted preparation')
    require(set(manifest['source_sha256']) == {
        'code/game/objects/structures/animalspawner/wolfcave.dm',
        'code/game/objects/structures/animalspawner/animal_spawner.dm', 'tests/wolf_cave_ownership/probe.dm'}, 'Unexpected source manifest')
    root = HERE.parents[1]
    for name, sha in manifest['source_sha256'].items():
        require(digest(ordinary_file(root / name)) == sha, 'Production source differs from prepared case')
    tools = {p.name: digest(ordinary_file(p)) for p in byond_bin.iterdir()
             if p.is_file() and (p.suffix.lower() == '.dll' or p.name in ('dm.exe', 'dd.exe'))}
    require(all(tools.get(name) == sha for name, sha in PINNED.items()), 'Pinned official tools differ')
    output.mkdir(parents=True, exist_ok=False)
    source_root = output / 'sources'
    files = {}
    for case in CASES:
        require(set(manifest['cases'][case]) == {'parent.dm', 'production.dm', 'probe.dm', 'probe.dme'}, 'Unexpected fixture files')
        for name, sha in manifest['cases'][case].items():
            source = ordinary_file(prepared / case / name)
            require(digest(source) == sha, 'Prepared fixture changed')
            target = source_root / case / name; target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(source.read_bytes()); files[f'{case}/{name}'] = sha
    manifest_copy = output / 'source-manifest.json'; manifest_copy.write_bytes(manifest_path.read_bytes())
    packet = dict(schema=1, head=manifest['head'], policy=POLICY, cases=list(CASES), expected=EXPECTED,
                  manifest=str(manifest_copy), manifest_sha256=digest(manifest_copy), sources=str(source_root),
                  files=files, bin=str(byond_bin), tools=tools,
                  python={'path': sys.executable, 'sha256': digest(sys.executable)},
                  code={name: digest(HERE / name) for name in ('executor.py', 'windows_job.py')})
    path = output / 'executor-packet.json'; path.write_text(json.dumps(packet, indent=2) + '\n', encoding='utf-8')
    sha = digest(path); verify_packet(path, sha)
    return {'packet': str(path), 'packet_sha256': sha, 'native_executed': False}


def compiler_result(code, log):
    require(code == 0 and not DIAGNOSTIC.search(log), 'Compiler exit or diagnostic failure')
    require(re.findall(r'^DM compiler version .+$', log, re.M) == ['DM compiler version 516.1681'], 'Wrong compiler banner')
    summaries = re.findall(r'^.*\b(?:errors?|warnings?)\b.*$', log, re.M | re.I)
    require(len(summaries) == 1 and re.fullmatch(r'probe\.dmb - 0 errors, 0 warnings(?: \([^\n]+\))?', summaries[0]),
            'Compiler warnings/errors or malformed result')


def native_result(case, code, log):
    require(code == 0 and not DIAGNOSTIC.search(log), 'Runtime exit or diagnostic failure')
    failures = re.findall(r'^FAIL wolf cave: (.+)$', log, re.M)
    passes = re.findall(r'^PASS wolf cave ownership$', log, re.M)
    batches = re.findall(r'^CHECK wolf cave batch count=(\d+) full=([01])$', log, re.M)
    require(all(not line.startswith('FAIL') or line.startswith('FAIL wolf cave: ')
                or line == 'FAIL wolf cave ownership' for line in log.splitlines()), 'Unknown failure diagnostic')
    require(all(not line.startswith('PASS') or line == 'PASS wolf cave ownership' for line in log.splitlines()), 'Unknown PASS receipt')
    require(batches == [(str(n), str(f)) for n in (1, 3, 10) for f in (0, 1)], 'Incomplete native case')
    expected = EXPECTED[case]
    if expected is None:
        require(not failures and len(passes) == 1 and 'FAIL' not in log, 'Fixed case failed')
    else:
        require(expected in failures and not passes and log.splitlines().count('FAIL wolf cave ownership') == 1,
                'Missing exact named negative oracle or false PASS')
    return dict(expected_failure=expected, failures=failures,
                first_failure=failures[0] if failures else None,
                collateral=[s for s in failures if s != expected],
                scope='named oracle observed; all collateral retained' if expected else 'fixed isolated fixture')


class WallWatchdog:
    """Independent timer requests only owned-Job termination; monitor confirms exit."""
    def __init__(self, adapter, child, seconds):
        self.adapter, self.child, self.seconds = adapter, child, seconds
        self.fired = False; self.errors = []; self.done = threading.Event()
        self.started = False
        self.thread = threading.Thread(target=self.watch, daemon=True)
        self.handle = adapter.watchdog_handle(child)

    def watch(self):
        try:
            if not self.done.wait(self.seconds):
                self.fired = True
                try: self.adapter.watchdog_terminate(self.handle)
                except BaseException as error: self.errors.append(str(error))
        finally:
            try: self.adapter.watchdog_close(self.handle)
            except BaseException as error: self.errors.append(str(error))

    def start(self):
        try: self.thread.start(); self.started = True
        except BaseException:
            self.adapter.watchdog_close(self.handle)
            raise
    def stop(self):
        if not self.started: return
        self.done.set(); self.thread.join(timeout=1)
        require(not self.thread.is_alive(), 'Wall watchdog did not retire')
        require(not self.errors, 'Wall watchdog error: ' + str(self.errors))


def phase(adapter, argv, work, receipt, verify, seconds, now=time.monotonic, pause=time.sleep, watchdog_factory=WallWatchdog,
          persist=lambda: None):
    """Own before resume, bounded monitor, cleanup and diagnostics on every exit path."""
    child, watchdog, primary_error = None, None, None
    receipt.update(argv=argv, seconds=seconds, samples=[], result='failed')
    try:
        verify()
        resources = adapter.resources(); receipt['resources'] = resources
        require(resources['available_bytes'] >= POLICY['min_free_bytes'] and resources['commit_available_bytes'] >= POLICY['min_free_bytes']
                and resources['allowed_cpus'] >= 1, 'Resource admission unavailable')
        # Hash again adjacent to creation; no launch can occur after a failed check.
        verify()
        started = now(); child = adapter.start_suspended(argv, work, work)
        receipt['identity'] = child.identity
        require(now() - started < seconds, 'Creation exhausted phase deadline')
        watchdog = watchdog_factory(adapter, child, max(0, seconds - (now() - started)))
        watchdog.start()
        verify()  # A changed packet/tool between creation and resume kills the suspended child.
        require(now() - started < seconds and not watchdog.fired, 'Suspended verification exhausted deadline')
        adapter.resume(child)
        while True:
            require(now() - started < seconds and not watchdog.fired, 'Phase wall deadline')
            if adapter.exited(child): break
            sample = adapter.sample(child); sample['elapsed'] = now() - started
            sample['sockets'] = adapter.sockets(child); receipt['samples'].append(sample)
            require(not sample['sockets'], 'Owned socket observed; sampling is not continuous proof')
            require(sample['private_bytes'] <= POLICY['child_bytes'], 'Child memory ceiling')
            require(sample['active'] in (0, 1), 'Unexpected owned process count')
            require(sum(p.stat().st_size for p in work.rglob('*') if p.is_file()) <= POLICY['max_output_bytes'], 'Output bound exceeded; files retained')
            require(now() - started < seconds and not watchdog.fired, 'Phase wall deadline')
            pause(min(POLICY['sample_seconds'], max(0, seconds - (now() - started))))
        receipt['exit_code'] = adapter.exit_code(child)
        require(sum(p.stat().st_size for p in work.rglob('*') if p.is_file()) <= POLICY['max_output_bytes'],
                'Final output bound exceeded; complete files retained')
        receipt['elapsed'] = now() - started
        receipt['result'] = 'exited'
    except BaseException as error:
        primary_error = error
        receipt['error'] = str(error)
        receipt['error_type'] = type(error).__name__
        if hasattr(error, 'sample_diagnostic'):
            receipt['failed_sample'] = error.sample_diagnostic
        try: persist()  # Save the failed sample BEFORE stopping watchdog or cleaning the child.
        except BaseException as save_error:
            receipt['persistence_error'] = dict(type=type(save_error).__name__, message=str(save_error))
        raise
    finally:
        teardown_errors = []
        try:
            if watchdog:
                try: watchdog.stop()
                except BaseException as error: teardown_errors.append(dict(stage='watchdog', type=type(error).__name__, message=str(error)))
                finally: receipt['watchdog'] = dict(fired=watchdog.fired, errors=watchdog.errors)
        finally:
            if child:
                try:
                    receipt['cleanup'] = adapter.cleanup(child)
                    require(receipt['cleanup']['all_exited'], 'Owned cleanup unconfirmed: ' + str(receipt['cleanup']))
                except BaseException as error:
                    receipt.setdefault('cleanup', dict(all_exited=False, errors=[str(error)], exception_type=type(error).__name__))
                    teardown_errors.append(dict(stage='cleanup', type=type(error).__name__, message=str(error)))
        if teardown_errors:
            receipt['teardown_errors'] = teardown_errors
            if primary_error is None:
                raise RuntimeError('Owned teardown failed: ' + str(teardown_errors))
            if hasattr(primary_error, 'add_note'):
                primary_error.add_note('Separate teardown errors: ' + str(teardown_errors))


def run_packet(packet_path, expected_sha, output, adapter, *, now=time.monotonic, pause=time.sleep, watchdog_factory=WallWatchdog):
    """Library entry ONLY; injected backend mandatory. No native CLI or automatic retry."""
    packet = verify_packet(packet_path, expected_sha)
    output = Path(output).absolute()
    require(output.name == 'execution' and output.parent.resolve() == Path(packet_path).resolve().parent,
            'Execution output must be the fresh packet-local execution directory')
    output.mkdir(parents=False, exist_ok=False)
    report = dict(head=packet['head'], packet_sha256=expected_sha, result='failed', cases=[],
                  backend=type(adapter).__module__ + '.' + type(adapter).__qualname__,
                  socket_claim='spot observations only; absence between samples is not established')
    try:
        for case in CASES:
            row = dict(case=case, phases=[]); report['cases'].append(row)
            work = output / case; work.mkdir()
            for name in ('parent.dm', 'production.dm', 'probe.dm', 'probe.dme'):
                shutil.copyfile(Path(packet['sources']) / case / name, work / name)
            staged = {name: packet['files'][f'{case}/{name}']
                      for name in ('parent.dm', 'production.dm', 'probe.dm', 'probe.dme')}
            artifacts = {}
            def verify():
                verify_packet(packet_path, expected_sha)
                for name, sha in {**staged, **artifacts}.items():
                    require(digest(ordinary_file(work / name)) == sha, 'Staged input/artifact changed: ' + name)
            for label, exe, arguments in (
                ('compile', 'dm.exe', ['-max_errors', '0', 'probe.dme']),
                ('runtime', 'dd.exe', ['probe.dmb', '-close', '-invisible', '-trusted', '-log', 'runtime.log'])):
                logs = work / label; logs.mkdir()
                # Environment is phase-specific; no state from a previous child.
                phase_work = logs / 'world'; phase_work.mkdir()
                for name in (*staged, *artifacts): shutil.copyfile(work / name, phase_work / name)
                phase_inputs = {**staged, **artifacts}
                def verify_phase():
                    verify()
                    for name, sha in phase_inputs.items():
                        require(digest(ordinary_file(phase_work / name)) == sha, 'Phase input changed')
                receipt = dict(phase=label); row['phases'].append(receipt)
                def persist():
                    (output / 'receipt.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
                try:
                    phase(adapter, [str(Path(packet['bin']) / exe), *arguments], phase_work, receipt, verify_phase,
                          POLICY[label + '_seconds'], now, pause, watchdog_factory, persist=persist)
                    verify_phase()
                finally:
                    (output / 'receipt.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
                stdout = (phase_work / 'stdout.log').read_bytes()
                stderr = (phase_work / 'stderr.log').read_bytes()
                text = (stdout + stderr).decode('utf-8', errors='replace').replace('\r\n', '\n')
                if label == 'compile':
                    compiler_result(receipt['exit_code'], text)
                    require((phase_work / 'probe.dmb').is_file(), 'Compiler produced no DMB')
                    for name in ('probe.dmb', 'probe.rsc'):
                        if (phase_work / name).exists():
                            sha = digest(ordinary_file(phase_work / name))
                            shutil.copyfile(phase_work / name, work / name)
                            require(digest(ordinary_file(work / name)) == sha, 'Compiled artifact copy changed: ' + name)
                            artifacts[name] = sha
                    row['artifact_sha256'] = dict(artifacts)
                else:
                    logfile = ordinary_file(phase_work / 'runtime.log')
                    runtime = logfile.read_bytes().decode('utf-8', errors='replace').replace('\r\n', '\n')
                    require(not DIAGNOSTIC.search(text), 'Runtime stdout/stderr diagnostic')
                    row['oracle'] = native_result(case, receipt['exit_code'], runtime)
            row['result'] = 'passed'
        report['result'] = 'passed'
    except BaseException as error:
        report['error'] = str(error)
        raise
    finally:
        (output / 'receipt.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='OFFLINE preparation only; no native invocation entry point')
    parser.add_argument('--prepared', type=Path, required=True)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(freeze(args.prepared, args.byond_bin, args.output), indent=2))
