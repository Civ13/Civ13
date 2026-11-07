"""Native fixture for the HUD layout helpers (Linux or Windows, manual).

Builds a tiny world from tests/hud_layout/fixture.dm, the helper half of
code/_onclick/hud/hud_layout.dm and the production preferences save file,
then runs it once in DreamDaemon. No game startup, map or network.
"""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SOURCE = 'code/_onclick/hud/hud_layout.dm'
SAVE = 'code/modules/client/preferencesSQLite/preferences_saving&loading&del.dm'
CUT = '////////////////////////// applying the layout'


def prepare(output):
    output.mkdir(parents=True, exist_ok=False)
    (output / 'SQL').mkdir()
    source = (ROOT / SOURCE).read_text(encoding='utf-8')
    assert source.count(CUT) == 1, 'helper/apply split marker changed'
    helpers = source.split(CUT)[0]
    # The fixture has no real client type; keep only the helper procs.
    helpers = re.sub(r'^/client\n(?:\t[^\n]*\n)+', '', helpers, flags=re.M)
    save = (ROOT / SAVE).read_text(encoding='utf-8')
    shutil.copy(Path(__file__).with_name('fixture.dm'), output / 'fixture.dm')
    (output / 'production.dm').write_text(helpers + '\n' + save, encoding='utf-8')
    (output / 'probe.dme').write_text('#include "fixture.dm"\n#include "production.dm"\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--byond-bin', type=Path, required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    prepare(out)
    exe = '.exe' if os.name == 'nt' else ''
    compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    build = subprocess.run([str(compiler), 'probe.dme'], cwd=out, capture_output=True, text=True, timeout=60)
    print(build.stdout + build.stderr)
    if build.returncode or '0 errors' not in build.stdout + build.stderr:
        raise SystemExit('fixture compile failed')
    run = subprocess.run([str(daemon), 'probe.dmb', '-trusted', '-invisible', '-close', '-log', 'runtime.log'],
                         cwd=out, capture_output=True, text=True, timeout=30)
    log = (out / 'runtime.log').read_text(errors='replace')
    print(log)
    if 'PASS hud layout:' not in log or re.search(r'FAIL|runtime error', log, re.I):
        raise SystemExit('hud layout fixture failed')


if __name__ == '__main__':
    main()
