"""Closed-port native parity on ephemeral CI; no live server or client access."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re

from prepare import prepare
from compare import compare

ROOT = Path(__file__).resolve().parents[2]
EXPECTED = {'baseline': 'PASS', 'candidate': 'PASS', 'virtual-master': 'PASS',
            'halo': 'FAIL: assertion: overlay allocation count',
            'refusal-owner': 'FAIL: assertion: refused constructor detached before deferred deletion',
            'owner-identity': 'FAIL: assertion: superseded cleanup preserves owner',
            'lumcount-guard': 'PASS'}
DIAGNOSTIC = re.compile(r'runtime error|Runtime in|BUG:|CRASH|Infinite loop|Cannot read null|PORT_OPEN', re.I)


# Resource literals in included DM files resolve relative to the generated DME,
# not the original included source. Bind only immutable checkout resources.
RESOURCE_DIRECTORIES = ('icons', 'sound', 'UI', 'interface', 'code/js')
VERSION = '516.1688'


def runtime_module():
    spec = importlib.util.spec_from_file_location('reserved_runtime_pin', ROOT / 'scripts/byond_runtime.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def verify_runtime(byond, archive, expected=None):
    identity = runtime_module().verify_linux(byond, archive)
    if identity['version'] != VERSION or expected is not None and identity != expected:
        raise RuntimeError('Pinned 516.1688 runtime identity required; drift refused')
    return identity


def combined_output(result):
    return result.stdout + ('\n' if result.stdout and not result.stdout.endswith('\n') else '') + result.stderr


def validate_compiler(code, log):
    if (code or re.findall(r'^DM compiler version[^\r\n]*', log, re.M) != ['DM compiler version ' + VERSION]
            or not re.search(r'^probe.dmb - 0 errors, 0 warnings \(.+\)$', log, re.M)
            or DIAGNOSTIC.search(log)):
        raise RuntimeError('Pinned clean fixture compilation required')


def validate_runtime_banner(log):
    banners = re.findall(r'^Welcome BYOND![^\r\n]*', log, re.M)
    if not banners or any(value != 'Welcome BYOND! (5.0 Public Version ' + VERSION + ')' for value in banners):
        raise RuntimeError('Pinned native runtime banner required')


def bind_resources(repo, work):
    for relative in RESOURCE_DIRECTORIES:
        source = (repo/relative).resolve(strict=True)
        target = work/relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.symlink_to(source, target_is_directory=True)


def validate_runtime(result, work, name):
    log = combined_output(result) + '\n' + (work/'runtime.log').read_text(errors='replace')
    validate_runtime_banner(log)
    if result.returncode or DIAGNOSTIC.search(log):
        raise RuntimeError('Unexpected native diagnostic: ' + log)
    if (work/'port-closed.txt').read_text().strip() != 'closed':
        raise RuntimeError('Fixture port was not closed')
    actual = (work/'result.txt').read_text().strip()
    if actual != EXPECTED[name]:
        raise RuntimeError(f'{name}: expected {EXPECTED[name]!r}, got {actual!r}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--byond-archive', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    spec = importlib.util.spec_from_file_location('startup_runner', ROOT/'tests/lighting_startup/run.py')
    runner = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(runner)
    byond = args.byond_bin.absolute()
    compiler = byond/('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = byond/('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    flags = 0x8 if os.name == 'nt' else 0
    identity = verify_runtime(args.byond_bin.absolute(), args.byond_archive.absolute())
    (out/'runtime-identity.json').write_text(json.dumps(identity, indent=2))
    for name in EXPECTED:
        work = out/name
        prepare(ROOT, work, None if name in ('baseline', 'candidate') else name)
        bind_resources(ROOT, work)
        verify_runtime(args.byond_bin.absolute(), args.byond_archive.absolute(), identity)
        result = runner.run_logged([str(compiler), '-max_errors', '0', 'probe.dme'], work, 'compile.log', 180, flags)
        validate_compiler(result.returncode, combined_output(result))
        verify_runtime(args.byond_bin.absolute(), args.byond_archive.absolute(), identity)
        result = runner.run_logged([str(daemon), 'probe.dmb', '-close', '-trusted', '-log', 'runtime.log',
                                   '-params', 'reserved=' + ('0' if name == 'baseline' else '1')],
                                  work, 'daemon.log', 180, flags)
        verify_runtime(args.byond_bin.absolute(), args.byond_archive.absolute(), identity)
        validate_runtime(result, work, name)
    parity = compare(out/'baseline/states.jsonl', out/'candidate/states.jsonl')
    try:
        compare(out/'baseline/states.jsonl', out/'virtual-master/states.jsonl')
    except ValueError as error:
        if not str(error).startswith('Native snapshot mismatch:'):
            raise
    else:
        raise RuntimeError('Virtual-master mutation survived the complete comparison')
    try:
        compare(out/'baseline/states.jsonl', out/'lumcount-guard/states.jsonl')
    except ValueError as error:
        if not str(error).startswith('Native lumcount mismatch:'):
            raise
    else:
        raise RuntimeError('Old lumcount fallback mutation survived all-cell semantic comparison')
    (out/'parity.json').write_text(json.dumps(parity, indent=2))
    print('PASS native reserved-lighting state/lumcount parity and five causal controls', parity)


if __name__ == '__main__':
    main()
