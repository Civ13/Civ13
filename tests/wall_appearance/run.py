"""Pinned native production-wall appearance and neighbor-work comparison."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

BASELINE = 'e3c8d02f31f1a23c1320eaec949fb4af56e964f3'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--byond-bin', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--negative-control', choices=['smoothing', 'duplicate', 'overlay'])
args = parser.parse_args()
repo = Path(__file__).resolve().parents[2]
path = 'code/game/turfs/wall_icon_exp.dm'
baseline = subprocess.check_output(['git', 'show', BASELINE + ':' + path], cwd=repo, text=True)
current = (repo / path).read_text()
# Fail closed if this patch grows beyond the measured removal.
removed = '\tupdate_material()\n\tcheck_relatives(1,1)\n'
assert baseline.count(removed) == 1
assert current == baseline.replace(removed, '\tupdate_material()\n'), 'Unexpected production drift'
candidate = current
if args.negative_control == 'duplicate':
    candidate = baseline
elif args.negative_control == 'smoothing':
    needle = '\tupdate_icon()\n\tcheck_relatives(1,1)\n'
    assert candidate.count(needle) == 1
    candidate = candidate.replace(needle, '\tupdate_icon()\n')
elif args.negative_control == 'overlay':
    needle = '\t\t\t\toverlays += line_ov\n'
    assert candidate.count(needle) == 1
    candidate = candidate.replace(needle, '\t\t\t\tvar/list/reordered = list(line_ov)\n\t\t\t\treordered += overlays\n\t\t\t\toverlays = reordered\n')

def variant(text, name):
    text = re.sub(r'/turf/wall(?=[/\s)]|$)', '/turf/wall/' + name, text)
    text = text.replace('\tvar/junction\n', '\tprobe_checks++\n\tvar/junction\n')
    text = text.replace('\toverlays.Cut()\n', '\tprobe_rebuilds++\n\toverlays.Cut()\n')
    return text

types = (repo / 'code/game/turfs/wall_types.dm').read_text()
abashiri = re.search(r'^/turf/wall/abashiri/update_icon\(\)\n[\s\S]*?(?=^/turf/wall/abashiri/New)', types, re.M).group()
old_stone = re.search(r'^/turf/wall/old_stone/update_icon\(\)\n\treturn\n', types, re.M).group()
walls = (repo / 'code/game/turfs/walls.dm').read_text()
constructor = re.search(r'^/turf/wall/New\([\s\S]*?(?=^/turf/wall/Destroy)', walls, re.M).group()
abashiri_new = re.search(r'^/turf/wall/abashiri/New\(\)\n[\s\S]*?(?=^/turf/wall/abashiri/Destroy)', types, re.M).group()
old_new = re.search(r'^/turf/wall/old_stone/New\(\)\n\treturn\n', types, re.M).group()
source = ''.join(variant(body + abashiri + old_stone + constructor + abashiri_new + old_new, name) for name, body in [('baseline', baseline), ('candidate', candidate)])
probe = Path(__file__).with_name('probe.dm').read_text()
head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip()
if args.output.exists():
    parser.error('Evidence output must be fresh')
args.output.parent.mkdir(parents=True, exist_ok=True)
logs = args.output.with_suffix('.logs')
logs.mkdir(exist_ok=False)
flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
with tempfile.TemporaryDirectory(prefix='civ13-wall-appearance-') as temp:
    root = Path(temp)
    (root / 'icons/turf').mkdir(parents=True)
    for asset in ('wall_masks.dmi', 'walls.dmi'):
        shutil.copyfile(repo / 'icons/turf' / asset, root / 'icons/turf' / asset)
    support = ['code/predefines.dm', 'tests/world_save/stubs.dm', 'code/modules/multiz/world_z_budget.dm', 'code/modules/persistence/functions.dm', 'code/modules/persistence/saving.dm', 'code/modules/persistence/loading.dm']
    for i, support_path in enumerate(support):
        shutil.copyfile(repo / support_path, root / f'support-{i}.dm')
    (root / 'probe.dm').write_text(probe)
    (root / 'production.dm').write_text(source)
    includes = '#define TRUE 1\n#define FALSE 0\n#define TICK_CHECK fixture_tick_check()\n#define TICK_LIMIT_TO_RUN 100\n#define EXCEPTION(message) new /exception(message)\n'
    includes += ''.join(f'#include "support-{i}.dm"\n' for i in range(len(support)))
    (root / 'probe.dme').write_text(includes + '#include "probe.dm"\n#include "production.dm"\n')
    compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    build = subprocess.run([str(compiler), '-max_errors', '0', 'probe.dme'], cwd=root, capture_output=True, text=True, timeout=60, creationflags=flags)
    build_log = build.stdout + build.stderr
    (logs / 'compile.log').write_text(build_log)
    if build.returncode or '516.1681' not in build_log or '0 errors, 0 warnings' not in build_log:
        raise SystemExit(build_log)
    run = subprocess.run([str(daemon), 'probe.dmb', '-invisible', '-close', '-trusted', '-log', 'runtime.log'], cwd=root, capture_output=True, timeout=60, creationflags=flags)
    runtime_log = (root / 'runtime.log').read_text(errors='replace') + (run.stdout + run.stderr).decode(errors='replace')
    (logs / 'runtime.log').write_text(runtime_log)
    if run.returncode or re.search(r'runtime error|Bad ref|Bad loc|Cannot read null|Cannot execute null', runtime_log, re.I):
        raise SystemExit(runtime_log)
    result = json.loads((root / 'result.json').read_text())
    result.update(head_sha=head, baseline_sha=BASELINE, source_sha256=hashlib.sha256(current.encode()).hexdigest(), compiled_sha256=hashlib.sha256(source.encode()).hexdigest(), probe_sha256=hashlib.sha256(probe.encode()).hexdigest(), byond='516.1681', platform=os.name, dimensions=[32,32,1], negative_control=args.negative_control, support_sha256={p: hashlib.sha256((repo / p).read_bytes()).hexdigest() for p in support}, resource_sha256={p: hashlib.sha256((repo / 'icons/turf' / p).read_bytes()).hexdigest() for p in ('wall_masks.dmi','walls.dmi')})
    args.output.write_text(json.dumps(result, indent=2))
    (logs / 'dirty.patch').write_bytes(subprocess.check_output(['git', 'diff', 'HEAD'], cwd=repo))
    assert result['scenes'] == 1536 and result['comparisons'] == 4608, 'Incomplete fixture'
    if args.negative_control:
        assert result['appearance_failures'] + result['count_failures'] > 0, 'Control escaped detection'
        if args.negative_control in ('smoothing','overlay'):
            assert result['appearance_failures'] > 0, 'Visual control escaped appearance comparison'
        if args.negative_control == 'duplicate':
            assert result['appearance_failures'] == 0 and result['count_failures'] > 0
    else:
        assert result['appearance_failures'] == result['count_failures'] == 0, 'Comparison failed'
    assert result['save_comparisons'] == 4, 'Incomplete native save/load work'
    if not args.negative_control:
        assert result['save_failures'] == 0, 'Save parity failed'
    print(json.dumps({k: v for k, v in result.items() if k != 'failure_samples'}))
