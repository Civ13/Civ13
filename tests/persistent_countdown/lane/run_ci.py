"""Proposed reviewed Linux CI runner; never invoke on the user desktop."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import resource
import shutil
import socket
import subprocess
import sys
import time
import signal

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import prepare

WORK_SECONDS = 330
COMPILE_SECONDS = 30
DAEMON_SECONDS = 12
CHILD_ENV = {'PATH': '/usr/bin:/bin', 'LANG': 'C', 'LC_ALL': 'C',
             'LD_LIBRARY_PATH': '/runtime/byond/bin', 'TMPDIR': '/tmp',
             'PYTHONDONTWRITEBYTECODE': '1'}
CASES = {
    'none': ['boot', 'latch', 'vote', 'admission', 'ordinary', 'manual', 'guards', 'hold'],
    'boot': ['boot'], 'postvote': ['vote'], 'postadmission': ['admission'], 'latch': ['latch'],
}
EXPECTED_FAILURES = {'boot': {'boot_armed'}, 'postvote': {'vote_no_setup'},
                     'postadmission': {'admission_rejected'},
                     'latch': {'latch_cancelled', 'latch_no_setup'}}
DIAGNOSTIC = re.compile(r'runtime error:|BUG:|Bad ref|Unhandled exception', re.I)

def limits():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    resource.setrlimit(resource.RLIMIT_FSIZE, (16 * 1024 * 1024, 16 * 1024 * 1024))
    resource.setrlimit(resource.RLIMIT_AS, (1024**3, 1024**3))
    resource.setrlimit(resource.RLIMIT_CPU, (45, 45))

def remaining(deadline, cap):
    available = deadline - time.monotonic()
    if available <= 0: raise TimeoutError('aggregate native deadline')
    return min(cap, available)

def terminate_group(proc):
    try: os.killpg(proc.pid, signal.SIGKILL)
    except ProcessLookupError: pass
    proc.wait(timeout=5)

def validate_result(result, control, case):
    match = re.fullmatch(r'(PASS|FAIL):([^:]+):([^ ]*) (.*)', result)
    if not match or match[2] != case: raise RuntimeError('invalid result: ' + result)
    failures = set(filter(None, match[3].split(',')))
    expected = EXPECTED_FAILURES.get(control, set())
    if failures != expected or match[1] != ('FAIL' if expected else 'PASS'):
        raise RuntimeError('wrong assertions: ' + result)
    if not re.search(r'\bport=0\b', match[4]): raise RuntimeError('world port was not closed')

def process(argv, cwd, deadline, outfile):
    with outfile.open('xb') as f:
        proc = subprocess.Popen(argv, cwd=cwd, stdin=subprocess.DEVNULL, stdout=f,
                                stderr=subprocess.STDOUT, env=CHILD_ENV,
                                start_new_session=True, preexec_fn=limits)
        try:
            proc.wait(timeout=remaining(deadline, COMPILE_SECONDS))
        finally:
            terminate_group(proc)
    data = outfile.read_bytes()
    if len(data) > 16 * 1024 * 1024: raise RuntimeError('output cap exceeded')
    return proc.returncode, data.decode('utf-8', errors='replace')

def daemon_process(argv, cwd, deadline):
    case_deadline = time.monotonic() + remaining(deadline, DAEMON_SECONDS)
    samples = 0
    with (cwd / 'daemon.log').open('xb') as f:
        proc = subprocess.Popen(argv, cwd=cwd, stdin=subprocess.DEVNULL, stdout=f,
                                stderr=subprocess.STDOUT, env=CHILD_ENV,
                                start_new_session=True, preexec_fn=limits)
        try:
            while proc.poll() is None:
                if time.monotonic() >= case_deadline: raise TimeoutError('daemon deadline')
                if (cwd / 'ready.txt').exists():
                    for path in ('/proc/net/tcp', '/proc/net/tcp6'):
                        rows = Path(path).read_text(encoding='ascii').splitlines()[1:]
                        if any(len(row.split()) > 3 and row.split()[3] == '0A' for row in rows):
                            raise RuntimeError('TCP listener during critical fixture phase')
                    samples += 1
                time.sleep(0.05)
        finally:
            terminate_group(proc)
    if samples < 3: raise RuntimeError('insufficient zero-listener samples')
    (cwd / 'socket-census.json').write_text(json.dumps({'zero_listener_samples': samples, 'interval_seconds': 0.05}) + '\n', encoding='utf-8')
    return proc.returncode, (cwd / 'daemon.log').read_text(encoding='utf-8', errors='replace')

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--repo', required=True, type=Path, help='Exact source checkout for existing pinned runtime verifier')
    p.add_argument('--byond-bin', required=True, type=Path)
    p.add_argument('--byond-archive', required=True, type=Path)
    p.add_argument('--output', required=True, type=Path, help='New, isolated artifact directory')
    a = p.parse_args()
    if sys.platform != 'linux': raise RuntimeError('Linux CI only')
    # Fresh, isolated CI network namespace required. No interface except loopback.
    if {name for _, name in socket.if_nameindex()} != {'lo'}:
        raise RuntimeError('CI network namespace is not loopback-only')
    if a.output.exists(): raise RuntimeError('Refusing existing output directory')
    repo, binary = a.repo.resolve(), a.byond_bin.resolve()
    spec = importlib.util.spec_from_file_location('current_runtime', repo / 'tests/world_save/current_runtime.py')
    runtime_module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(runtime_module)
    runtime = runtime_module.select(binary, a.byond_archive.resolve())
    head = subprocess.check_output(['/usr/bin/git', 'rev-parse', 'HEAD'], cwd=repo, text=True, timeout=10, env=CHILD_ENV).strip()
    if head != '304a95ef5bd0dfa7bdadd511bca6cb740d4f0167':
        raise RuntimeError('checkout is not the reviewed PR head')
    if subprocess.check_output(['/usr/bin/git', 'status', '--porcelain'], cwd=repo, text=True, timeout=10, env=CHILD_ENV).strip():
        raise RuntimeError('checkout must be clean')
    # Verify the source under test in the checkout as well as the frozen review packet.
    for name, digest in prepare.EXPECTED.items():
        import hashlib
        if hashlib.sha256((repo / name).read_bytes()).hexdigest() != digest:
            raise RuntimeError('checkout source mismatch: ' + name)
    a.output.mkdir(parents=True)
    (a.output / 'checkout.txt').write_text(head + '\n', encoding='utf-8')
    deadline = time.monotonic() + WORK_SECONDS
    for control, cases in CASES.items():
        stage = a.output / control
        subprocess.run([sys.executable, '-B', str(Path(prepare.__file__)), '--control', control, '--output', str(stage)],
                       check=True, timeout=remaining(deadline, 10), env=CHILD_ENV)
        runtime.before_launch('compile-' + control, stage)
        code, log = process([str(binary / 'DreamMaker'), '-max_errors', '0', 'probe.dme'], stage, deadline, stage / 'compile.log')
        runtime.validate_compile(code, log, 'probe.dmb')
        for case in cases:
            out = stage / case
            out.mkdir()
            (out / 'map_saves').mkdir()
            shutil.copy2(stage / 'probe.dmb', out / 'probe.dmb')
            if (stage / 'probe.rsc').exists(): shutil.copy2(stage / 'probe.rsc', out / 'probe.rsc')
            runtime.before_launch('daemon-' + control + '-' + case, out)
            code, log = daemon_process([str(binary / 'DreamDaemon'), 'probe.dmb', '-ip', '127.0.0.1',
                                        '-nowebclient', '-trusted', '-params', 'case=' + case,
                                        '-log', 'runtime.log'], out, deadline)
            runtime_log = (out / 'runtime.log').read_text(encoding='utf-8', errors='replace')
            if code or DIAGNOSTIC.search(log + runtime_log): raise RuntimeError('daemon failure or diagnostic: ' + case)
            result = (out / 'result.txt').read_text(encoding='utf-8').strip()
            validate_result(result, control, case)
            print(control, result, flush=True)
    (a.output / 'complete.json').write_text(json.dumps({'head': head, 'variants': 5, 'cases': 12}) + '\n', encoding='utf-8')

if __name__ == '__main__': main()
