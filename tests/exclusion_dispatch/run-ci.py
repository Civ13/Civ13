"""Bounded Linux CI parity; separate from the held Windows grant runner."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
DIAGNOSTIC = re.compile(r'\bBUG\b|runtime error|Bad ref|Bad loc|Cannot read null|Cannot execute null|segmentation|fatal error|infinite loop', re.I)
MODES = ('parity', 'omit', 'parent', 'eager')
VERSION = '516.1688'


def runtime_module():
    path = HERE.parents[1] / 'scripts/byond_runtime.py'
    spec = importlib.util.spec_from_file_location('exclusion_runtime_pin', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def verify_runtime(byond, archive, expected=None):
    identity = runtime_module().verify_linux(byond, archive)
    if identity['version'] != VERSION or expected is not None and identity != expected:
        raise RuntimeError('Pinned 516.1688 runtime identity required; drift refused')
    return identity


def validate_compiler(code, log):
    if (code or re.findall(r'^DM compiler version[^\r\n]*', log, re.M) != ['DM compiler version ' + VERSION]
            or not re.search(r'^probe.dmb - 0 errors, 0 warnings \(.+\)$', log, re.M)
            or DIAGNOSTIC.search(log)):
        raise RuntimeError('Pinned clean generated-source compilation required')


def validate_runtime_banner(log):
    banners = re.findall(r'^Welcome BYOND![^\r\n]*', log, re.M)
    if not banners or any(value != 'Welcome BYOND! (5.0 Public Version ' + VERSION + ')' for value in banners):
        raise RuntimeError('Pinned native runtime banner required')


def limits():
    import resource
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
    # Git otherwise maps up to 1 GiB of a packed repository per window,
    # exceeding the child's 512 MiB address-space bound during source reads.
    environment = dict(os.environ, GIT_CONFIG_COUNT='2',
                       GIT_CONFIG_KEY_0='core.packedGitWindowSize', GIT_CONFIG_VALUE_0='16m',
                       GIT_CONFIG_KEY_1='core.packedGitLimit', GIT_CONFIG_VALUE_1='32m')
    try:
        with (work / (role + '.stdout')).open('w') as out, (work / (role + '.stderr')).open('w') as err:
            child = subprocess.Popen(command, cwd=work, stdout=out, stderr=err,
                                     start_new_session=True, preexec_fn=limits, env=environment)
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
    out = (work / (role + '.stdout')).read_text(errors='replace')
    return out + ('\n' if out and not out.endswith('\n') else '') + (work / (role + '.stderr')).read_text(errors='replace')


def validate_result(mode, result, log):
    if DIAGNOSTIC.search(log):
        raise RuntimeError('Unexpected native diagnostic')
    if result.get('cases', 0) < 800:
        raise RuntimeError('Incomplete native parity coverage')
    failures = result.get('failures')
    if not isinstance(failures, int) or (failures != 0 if mode == 'parity' else failures <= 0):
        raise RuntimeError('Parity failed or mutation control survived')
    # world.address reports the host interface on Linux even with -ip loopback.
    # Require the engine's actual bind diagnostic instead, retaining the DM
    # address as audit data and checking the resulting closed-port state.
    bindings = re.findall(r'World opened on network port [0-9]+ for address ([^\s]+)\.', log)
    if not bindings or any(address != '127.0.0.1' for address in bindings):
        raise RuntimeError('Native startup did not establish IPv4 loopback binding')
    network = result['network']
    if (network['closed_port'] != 0
            or network['reopen_result'] != 0 or network['after_reopen_port'] != 0):
        raise RuntimeError('Closed-port fixture contract failed')
    if result.get('samples'):
        raise RuntimeError('Benchmark execution is outside this CI lane')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--byond-archive', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if sys.platform != 'linux':
        parser.error('This separate runner supports Linux only')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    byond = args.byond_bin.absolute()
    compiler, daemon = byond / 'DreamMaker', byond / 'DreamDaemon'
    identity = verify_runtime(byond, args.byond_archive.absolute())
    binaries = {name: identity['members'][name]['sha256'] for name in ('DreamMaker', 'DreamDaemon')}
    deadline = time.monotonic() + 180
    summary = dict(status='incomplete', binaries=binaries, runtime_identity=identity, native_execution=False,
                   scope='isolated Linux hook parity and controls; no benchmark or deployment', modes={})
    try:
        for mode in MODES:
            packet = output / (mode + '.json')
            command = [sys.executable, str(HERE / 'run.py'), '--source-only', '--output', str(packet)]
            if mode != 'parity':
                command += ['--negative-control', mode]
            run(command, output, mode + '-prepare', deadline)
            work = packet.with_suffix('.sources')
            verify_runtime(byond, args.byond_archive.absolute(), identity)
            build = run([str(compiler), '-max_errors', '0', 'probe.dme'], work, 'compile', deadline)
            validate_compiler(0, build)
            verify_runtime(byond, args.byond_archive.absolute(), identity)
            summary['native_execution'] = True
            log = run([str(daemon), 'probe.dmb', '-ip', '127.0.0.1', '-invisible', '-close',
                       '-trusted', '-log', 'runtime.log'], work, 'daemon', deadline)
            log += (work / 'runtime.log').read_text(errors='replace')
            verify_runtime(byond, args.byond_archive.absolute(), identity)
            validate_runtime_banner(log)
            if DIAGNOSTIC.search(log):
                raise RuntimeError('Unexpected native diagnostic; see retained runtime.log')
            result = json.loads((work / 'result.json').read_text())
            validate_result(mode, result, log)
            summary['modes'][mode] = result
        summary['status'] = 'passed'
    finally:
        (output / 'native-ci.json').write_text(json.dumps(summary, indent=2))
    print('PASS: native exclusion parity and omit/parent/eager controls; no performance claim')


if __name__ == '__main__':
    main()
