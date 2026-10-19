"""Bounded Linux CI parity; separate from the held Windows grant runner."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import resource
import signal
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
DIAGNOSTIC = re.compile(r'\bBUG\b|runtime error|Bad ref|Bad loc|Cannot read null|Cannot execute null|segmentation|fatal error|infinite loop', re.I)
MODES = ('parity', 'omit', 'parent', 'eager')


def limits():
    resource.setrlimit(resource.RLIMIT_CPU, (40, 40))
    resource.setrlimit(resource.RLIMIT_AS, (512 * 1024**2, 512 * 1024**2))
    resource.setrlimit(resource.RLIMIT_FSIZE, (16 * 1024**2, 16 * 1024**2))
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))


def run(command, work, role, deadline):
    remaining = min(40, deadline - time.monotonic())
    if remaining <= 0:
        raise RuntimeError('Aggregate CI deadline expired before launch')
    receipt = dict(command=command, reaped=False)
    child = None
    started = time.monotonic()
    try:
        with (work / (role + '.stdout')).open('w') as out, (work / (role + '.stderr')).open('w') as err:
            child = subprocess.Popen(command, cwd=work, stdout=out, stderr=err,
                                     start_new_session=True, preexec_fn=limits)
            receipt['pid'] = child.pid
            child.wait(timeout=remaining)
            if child.returncode:
                raise RuntimeError(f'{role} exited {child.returncode}; see retained logs')
    except BaseException as error:
        receipt['error'] = str(error)
        raise
    finally:
        if child is not None:
            try:
                os.killpg(child.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            child.wait()
            receipt.update(returncode=child.returncode, reaped=True)
        receipt['wall_seconds'] = time.monotonic() - started
        (work / (role + '-process.json')).write_text(json.dumps(receipt, indent=2))
    return (work / (role + '.stdout')).read_text(errors='replace') + (work / (role + '.stderr')).read_text(errors='replace')


def validate_result(mode, result, log):
    if DIAGNOSTIC.search(log):
        raise RuntimeError('Unexpected native diagnostic')
    if result.get('cases', 0) < 800:
        raise RuntimeError('Incomplete native parity coverage')
    failures = result.get('failures')
    if not isinstance(failures, int) or (failures != 0 if mode == 'parity' else failures <= 0):
        raise RuntimeError('Parity failed or mutation control survived')
    network = result['network']
    if (network['preclose_address'] != '127.0.0.1' or network['closed_port'] != 0
            or network['reopen_result'] != 0 or network['after_reopen_port'] != 0):
        raise RuntimeError('Closed-port fixture contract failed')
    if result.get('samples'):
        raise RuntimeError('Benchmark execution is outside this CI lane')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if sys.platform != 'linux':
        parser.error('This separate runner supports Linux only')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    byond = args.byond_bin.resolve(strict=True)
    compiler, daemon = byond / 'DreamMaker', byond / 'DreamDaemon'
    binaries = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in (compiler, daemon)}
    deadline = time.monotonic() + 180
    summary = dict(status='incomplete', binaries=binaries, native_execution=False,
                   scope='isolated Linux hook parity and controls; no benchmark or deployment', modes={})
    try:
        for mode in MODES:
            packet = output / (mode + '.json')
            command = [sys.executable, str(HERE / 'run.py'), '--source-only', '--output', str(packet)]
            if mode != 'parity':
                command += ['--negative-control', mode]
            run(command, output, mode + '-prepare', deadline)
            work = packet.with_suffix('.sources')
            build = run([str(compiler), '-max_errors', '0', 'probe.dme'], work, 'compile', deadline)
            if '516.1681' not in build or '0 errors, 0 warnings' not in build or DIAGNOSTIC.search(build):
                raise RuntimeError('Pinned clean generated-source compilation required')
            summary['native_execution'] = True
            log = run([str(daemon), 'probe.dmb', '-ip', '127.0.0.1', '-invisible', '-close',
                       '-trusted', '-log', 'runtime.log'], work, 'daemon', deadline)
            log += (work / 'runtime.log').read_text(errors='replace')
            if '516.1681' not in log:
                raise RuntimeError('Pinned native runtime banner required')
            result = json.loads((work / 'result.json').read_text())
            validate_result(mode, result, log)
            summary['modes'][mode] = result
        summary['status'] = 'passed'
    finally:
        (output / 'native-ci.json').write_text(json.dumps(summary, indent=2))
    print('PASS: native exclusion parity and omit/parent/eager controls; no performance claim')


if __name__ == '__main__':
    main()
