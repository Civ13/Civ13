"""Native modern bridge fixture: compiles the full DME without maps, runs probe.dm.

python3 tests/modern_bridges/run.py --byond-bin <pinned bin> --evidence-dir <fresh dir>
--prepare-only writes the generated sources without invoking BYOND.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts/gameplay_bridge'))
from prepare_native import isolated_startup  # noqa: E402

PREFIX = '.modern_bridges_ci'
EXPECTED_CHECKS = 16


def replace_once(source, old, new):
    if source.count(old) != 1:
        raise ValueError('Missing or ambiguous source anchor: ' + old)
    return source.replace(old, new, 1)


def sources(root=ROOT):
    world, globals_source = isolated_startup(
        (root / 'code/world.dm').read_text(encoding='utf-8'),
        (root / 'code/controllers/mc/globals.dm').read_text(encoding='utf-8'))
    dme = (root / 'civ13.dme').read_text(encoding='utf-8')
    for old, new in [('code\\world.dm', PREFIX + '_world.dm'),
                     ('code\\controllers\\mc\\globals.dm', PREFIX + '_globals.dm')]:
        dme = replace_once(dme, old, new)
    dme = re.sub(r'^#include ".*\.dmm".*$', '', dme, flags=re.M)
    dme += '\n#include "tests/modern_bridges/probe.dm"\n'
    return {PREFIX + '_world.dm': world, PREFIX + '_globals.dm': globals_source, PREFIX + '.dme': dme}


def verify_result(result):
    checks = result.get('checks', [])
    if result.get('runtime_error') or len(checks) != EXPECTED_CHECKS or len({c['label'] for c in checks}) != EXPECTED_CHECKS:
        raise ValueError('Incomplete fixture or unexpected native runtime error')
    failed = [c['label'] for c in checks if not c['passed']]
    if failed != result.get('failed_labels') or failed:
        raise ValueError('Modern bridge checks failed: ' + ', '.join(failed))


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
        raise ValueError('Preserve existing generated probe files')
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
        (evidence / 'config/config.txt').write_text('# Offline modern bridge fixture\n', encoding='utf-8')
        daemon = binary / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
        runtime = subprocess.run([str(daemon), PREFIX + '.dmb', '-invisible', '-close', '-trusted',
                                  '-params', 'tested_commit=' + head, '-log', 'runtime.log'],
                                 cwd=evidence, capture_output=True, timeout=120, creationflags=flags)
        (evidence / 'daemon.log').write_bytes(runtime.stdout + runtime.stderr)
        diagnostics = (evidence / 'runtime.log').read_text(encoding='utf-8', errors='replace')
        diagnostics += (runtime.stdout + runtime.stderr).decode(errors='replace')
        if runtime.returncode or re.search(r'runtime error|Bad ref|Bad loc|BUG:|## ERROR:', diagnostics, re.I):
            raise ValueError('Unexpected native diagnostics; inspect retained logs')
        result = json.loads((evidence / 'result.json').read_text(encoding='utf-8'))
        print(json.dumps(result, sort_keys=True), flush=True)
        if result.get('commit') != head or 'COMPLETE modern bridge fixture' not in diagnostics:
            raise ValueError('Wrong source or missing terminal oracle')
        verify_result(result)
        print('PASS modern bridge fixture (%d checks)' % EXPECTED_CHECKS, flush=True)
    finally:
        for path in owned:
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
