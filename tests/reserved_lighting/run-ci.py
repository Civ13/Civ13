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
            'refusal-owner': 'FAIL: assertion: refused constructor detached before deferred deletion'}
DIAGNOSTIC = re.compile(r'runtime error|Runtime in|BUG:|CRASH|Infinite loop|Cannot read null|PORT_OPEN', re.I)


def validate_runtime(result, work, name):
    log = result.stdout + result.stderr + (work/'runtime.log').read_text(errors='replace')
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
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    spec = importlib.util.spec_from_file_location('startup_runner', ROOT/'tests/lighting_startup/run.py')
    runner = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(runner)
    compiler = args.byond_bin.resolve()/('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = args.byond_bin.resolve()/('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    flags = 0x8 if os.name == 'nt' else 0
    for name in EXPECTED:
        work = out/name
        prepare(ROOT, work, None if name in ('baseline', 'candidate') else name)
        result = runner.run_logged([str(compiler), '-max_errors', '0', 'probe.dme'], work, 'compile.log', 180, flags)
        log = result.stdout + result.stderr
        if result.returncode or 'DM compiler version 516.1681' not in log or not re.search(r'^probe.dmb - 0 errors, 0 warnings \(.+\)$', log, re.M):
            raise RuntimeError('Fixture compilation failed: ' + log)
        result = runner.run_logged([str(daemon), 'probe.dmb', '-close', '-trusted', '-log', 'runtime.log',
                                   '-params', 'reserved=' + ('0' if name == 'baseline' else '1')],
                                  work, 'daemon.log', 180, flags)
        validate_runtime(result, work, name)
    parity = compare(out/'baseline/states.jsonl', out/'candidate/states.jsonl')
    try:
        compare(out/'baseline/states.jsonl', out/'virtual-master/states.jsonl')
    except ValueError as error:
        if not str(error).startswith('Native snapshot mismatch:'):
            raise
    else:
        raise RuntimeError('Virtual-master mutation survived the complete comparison')
    (out/'parity.json').write_text(json.dumps(parity, indent=2))
    print('PASS native reserved-lighting state parity and three causal controls', parity)


if __name__ == '__main__':
    main()
