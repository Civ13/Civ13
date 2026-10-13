"""Native production parry wear and break boundaries, with pre-fix controls."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--byond-bin', type=Path, required=True)
parser.add_argument('--negative-control', choices=['sword', 'twohanded'])
args = parser.parse_args()
repo = Path(__file__).resolve().parents[2]
source = 'var/list/alldirs = list(1,2,4,8)\n'
for kind, filename in [('sword', 'swords'), ('twohanded', 'twohanded')]:
    text = (repo / f'code/game/objects/items/weapons/material/{filename}.dm').read_text()
    body = re.search(r'^/obj/item/weapon/material/' + kind + r'/handle_shield\([^\n]*\n(?:[^/\n][^\n]*\n|\n)*', text, re.M).group()
    if args.negative_control == kind:
        assert '\t\tcheck_health()' in body
        body = body.replace('\t\tcheck_health()\n', '')
    # Audio is an external-effect adapter; all decisions/wear bodies remain production.
    body = re.sub(r"'sound/[^']+'", 'null', body)
    source += body
text = (repo / 'code/game/objects/items/weapons/material/material_weapons.dm').read_text()
source += re.search(r'^/obj/item/weapon/material/proc/check_health[^\n]*\n(?:\t[^\n]*\n)*', text, re.M).group()
flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
with tempfile.TemporaryDirectory(prefix='civ13-parry-') as temp:
    root = Path(temp)
    (root / 'production.dm').write_text(source)
    (root / 'probe.dm').write_text(Path(__file__).with_name('probe.dm').read_text())
    (root / 'probe.dme').write_text('#include "probe.dm"\n#include "production.dm"\n')
    compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    build = subprocess.run([str(compiler), '-max_errors', '0', 'probe.dme'], cwd=root, capture_output=True, text=True, timeout=60, creationflags=flags)
    log = build.stdout + build.stderr
    if build.returncode or '516.1681' not in log or '0 errors, 0 warnings' not in log:
        raise SystemExit(log)
    run = subprocess.run([str(daemon), 'probe.dmb', '-invisible', '-close', '-safe', '-log', 'runtime.log'], cwd=root, capture_output=True, timeout=60, creationflags=flags)
    log = (root / 'runtime.log').read_text(errors='replace') + (run.stdout + run.stderr).decode(errors='replace')
    if run.returncode or re.search(r'runtime error|Bad ref|Bad loc|Cannot read null', log, re.I):
        raise SystemExit(log)
    result = json.loads((root / 'result.json').read_text())
    assert result['scenarios'] == 32, result
    assert bool(result['failures']) == bool(args.negative_control), result
    print(json.dumps(dict(result, negative_control=args.negative_control, byond='516.1681')))
