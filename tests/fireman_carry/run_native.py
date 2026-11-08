"""Native fireman-carry fixture. Needs the pinned BYOND bin; not an offline suite.

Usage: python3 tests/fireman_carry/run_native.py --byond-bin <dir> --evidence-dir <empty dir>
"""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts/gameplay_bridge'))
from prepare_native import isolated_startup  # noqa: E402

PREFIX = '.fireman_carry_ci'
CHECKS = ('downed-target', 'plain-grab-delay', 'carry-starts', 'carried-on-carrier-tile',
          'carried-over-shoulders', 'carry-faster-than-grab', 'carry-follows-walk',
          'no-grip-upgrade-while-carrying', 'click-self-puts-down', 'click-self-carries-again',
          'standing-up-ends-carry', 'standing-target-not-carried', 'grab-release-clears-carry')


def sources(root=ROOT):
    world, globals_source = isolated_startup(
        (root / 'code/world.dm').read_text(encoding='utf-8'),
        (root / 'code/controllers/mc/globals.dm').read_text(encoding='utf-8'))
    dme = (root / 'civ13.dme').read_text(encoding='utf-8')
    for old, new in [('code\\world.dm', PREFIX + '_world.dm'),
                     ('code\\controllers\\mc\\globals.dm', PREFIX + '_globals.dm')]:
        if dme.count(old) != 1:
            raise ValueError('Missing dme anchor: ' + old)
        dme = dme.replace(old, new, 1)
    dme = re.sub(r'^#include ".*\.dmm".*$', '', dme, flags=re.M)
    dme += '\n#include "tests/fireman_carry/probe.dm"\n'
    return {PREFIX + '_world.dm': world, PREFIX + '_globals.dm': globals_source, PREFIX + '.dme': dme}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--evidence-dir', type=Path, required=True)
    args = parser.parse_args()
    evidence = args.evidence_dir.resolve()
    if evidence.exists() and any(evidence.iterdir()):
        raise SystemExit('Evidence directory must be empty')
    evidence.mkdir(parents=True, exist_ok=True)
    generated = sources()
    owned = [ROOT / p for p in generated] + [ROOT / (PREFIX + ext) for ext in ('.dmb', '.rsc')]
    if any(p.exists() for p in owned):
        raise SystemExit('Preserve existing generated probe files')
    exe = '.exe' if os.name == 'nt' else ''
    try:
        for name, value in generated.items():
            (ROOT / name).write_text(value, encoding='utf-8', newline='\n')
        compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
        build = subprocess.run([str(compiler), '-max_errors', '0', PREFIX + '.dme'], cwd=ROOT,
                               capture_output=True, text=True, timeout=240)
        (evidence / 'compile.log').write_text(build.stdout + build.stderr, encoding='utf-8')
        if build.returncode or '0 errors' not in build.stdout + build.stderr:
            raise SystemExit('Compile failed; see compile.log')
        for ext in ('.dmb', '.rsc'):
            shutil.copy2(ROOT / (PREFIX + ext), evidence / (PREFIX + ext))
        shutil.copytree(ROOT / 'config/names', evidence / 'config/names')
        (evidence / 'config/config.txt').write_text('# Offline fireman carry fixture\n', encoding='utf-8')
        daemon = args.byond_bin / ('dd' + exe if os.name == 'nt' else 'DreamDaemon')
        run = subprocess.run([str(daemon), PREFIX + '.dmb', '-invisible', '-close', '-trusted'],
                             cwd=evidence, capture_output=True, text=True, timeout=120)
        log = run.stdout + run.stderr
        (evidence / 'daemon.log').write_text(log, encoding='utf-8')
    finally:
        for path in owned:
            path.unlink(missing_ok=True)
    results = {label: status for status, label in re.findall(r"^CHECK (PASS|FAIL) (\S+)$", log, re.M)}
    carry_runtimes = [line for line in log.splitlines() if line.startswith('RUNTIME') and 'grab' in line]
    missing = [c for c in CHECKS if c not in results]
    failed = [c for c, s in results.items() if s != 'PASS']
    if 'COMPLETE' not in log or missing or failed or carry_runtimes:
        raise SystemExit(f'FAIL missing={missing} failed={failed} grab_runtimes={carry_runtimes}')
    print(f'PASS {len(CHECKS)} fireman carry checks')


if __name__ == '__main__':
    main()
