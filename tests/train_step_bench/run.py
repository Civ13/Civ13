"""Train step benchmark: compiles the full DME without maps and runs bench.dm.

python3 tests/train_step_bench/run.py --byond-bin <pinned bin> --evidence-dir <fresh dir>
--prepare-only writes the generated sources without invoking BYOND.

Prints the cost of one train step in milliseconds for each scenario and writes
result.json and table.md to the evidence directory. Timings depend on the
machine, so the runner checks that every scenario ran in full and that cost
grows with train length; it sets no time limit.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
_spec = importlib.util.spec_from_file_location('train_platforms_run', ROOT / 'tests/train_platforms/run.py')
platforms = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(platforms)

PREFIX = '.train_step_bench_ci'
PROBE = 'tests/train_platforms/probe.dm'
BENCH = 'tests/train_step_bench/bench.dm'
EXPECTED_ROWS = 21


def sources(root=ROOT):
    generated = {}
    for name, value in platforms.sources(root).items():
        name = name.replace(platforms.PREFIX, PREFIX)
        if name.endswith('.dme'):
            value = platforms.replace_once(value, PROBE, BENCH)
            for part in ('_world.dm', '_globals.dm'):
                value = platforms.replace_once(value, platforms.PREFIX + part, PREFIX + part)
        generated[name] = value
    return generated


def verify_result(result):
    rows = result.get('rows', [])
    if result.get('runtime_error') or len(rows) != EXPECTED_ROWS or len({r['name'] for r in rows}) != EXPECTED_ROWS:
        raise ValueError('Incomplete benchmark or unexpected native runtime error')
    short = [r['name'] for r in rows if r['steps'] != result['steps'] or r['mean_ms'] <= 0]
    if short:
        raise ValueError('Scenarios that did not run in full: ' + ', '.join(short))
    by_name = {r['name']: r for r in rows}
    for kind in ('flatbed', 'coach'):
        if not by_name['%s x24' % kind]['mean_ms'] > by_name['%s x3' % kind]['mean_ms']:
            raise ValueError('Step cost did not grow with train length for ' + kind)


def table(result):
    lines = ['| Train | Sections | Parts | Carried | Mean ms | Worst ms | Clearance ms |',
             '| --- | --- | --- | --- | --- | --- | --- |']
    for r in result['rows']:
        lines.append('| %s | %d | %d | %d | %.2f | %.2f | %.2f |' % (
            r['name'], r['sections'], r['parts'], r['load'], r['mean_ms'], r['worst_ms'], r['clearance_ms']))
    return '\n'.join(lines) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--evidence-dir', type=Path, required=True)
    parser.add_argument('--prepare-only', action='store_true')
    args = parser.parse_args()
    if not args.prepare_only and not args.byond_bin:
        parser.error('Explicit pinned BYOND bin required for native execution')
    evidence = args.evidence_dir.resolve()
    if evidence.exists() and any(evidence.iterdir()):
        raise ValueError('Preserve existing evidence')
    evidence.mkdir(parents=True, exist_ok=True)
    generated = sources()
    for name, value in generated.items():
        (evidence / name).write_text(value, encoding='utf-8', newline='\n')
    if args.prepare_only:
        print('PASS source preparation; native compilation/runtime UNRUN')
        return
    owned = [ROOT / p for p in generated] + [ROOT / (PREFIX + ext) for ext in ('.dmb', '.rsc')]
    if any(p.exists() for p in owned):
        raise ValueError('Preserve existing generated benchmark files')
    binary = args.byond_bin.resolve()
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    pin = json.loads((ROOT / 'tools/byond/version.json').read_text(encoding='utf-8'))
    version = '%s.%s' % (pin['major'], pin['minor']) if 'major' in pin else str(pin.get('version', ''))
    try:
        for name, value in generated.items():
            (ROOT / name).write_text(value, encoding='utf-8', newline='\n')
        compiler = binary / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
        build = subprocess.run([str(compiler), '-max_errors', '0', PREFIX + '.dme'], cwd=ROOT,
                               capture_output=True, text=True, timeout=300, creationflags=flags)
        log = build.stdout + build.stderr
        (evidence / 'compile.log').write_text(log, encoding='utf-8')
        print(log, flush=True)
        if build.returncode or (version and version not in log) or '0 errors, 0 warnings' not in log:
            raise ValueError('Pinned compilation failed')
        for ext in ('.dmb', '.rsc'):
            shutil.copy2(ROOT / (PREFIX + ext), evidence / (PREFIX + ext))
        shutil.copytree(ROOT / 'config/names', evidence / 'config/names')
        (evidence / 'config/config.txt').write_text('# Offline train step benchmark\n', encoding='utf-8')
        daemon = binary / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
        runtime = subprocess.run([str(daemon), PREFIX + '.dmb', '-invisible', '-close', '-trusted',
                                  '-params', 'tested_commit=' + head, '-log', 'runtime.log'],
                                 cwd=evidence, capture_output=True, timeout=300, creationflags=flags)
        (evidence / 'daemon.log').write_bytes(runtime.stdout + runtime.stderr)
        diagnostics = (evidence / 'runtime.log').read_text(encoding='utf-8', errors='replace')
        diagnostics += (runtime.stdout + runtime.stderr).decode(errors='replace')
        if runtime.returncode or re.search(r'runtime error|Bad ref|Bad loc|BUG:|## ERROR:', diagnostics, re.I):
            raise ValueError('Unexpected native diagnostics; inspect retained logs')
        result = json.loads((evidence / 'result.json').read_text(encoding='utf-8'))
        if result.get('commit') != head or 'COMPLETE train step benchmark' not in diagnostics:
            raise ValueError('Wrong source or missing terminal oracle')
        verify_result(result)
        text = table(result)
        (evidence / 'table.md').write_text(text, encoding='utf-8')
        print(text, flush=True)
        print('PASS train step benchmark (%d scenarios)' % EXPECTED_ROWS, flush=True)
    finally:
        for path in owned:
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
