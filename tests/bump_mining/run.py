"""Extract production mining/Bump/wait bodies; prepare-only never starts native tools."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def block(text, start, end):
    return text[text.index(start):text.index(end, text.index(start))]


def source(control=None):
    files = {p: (ROOT / p).read_text(encoding='utf-8') for p in (
        'code/game/mob/living/carbon/carbon.dm', 'code/game/turfs/floor_attackby.dm', 'code/_helpers/mobs.dm', 'code/_onclick/adjacent.dm', 'code/modules/persistence/functions.dm')}
    bump = block(files['code/game/mob/living/carbon/carbon.dm'], '/mob/living/human/Bump(', '/mob/living/human/slip(')
    mining = block(files['code/game/turfs/floor_attackby.dm'], '/mob/var/tmp/datum/pickaxe_mining_action/', '/turf/proc/extracting_proc(')
    wait = block(files['code/_helpers/mobs.dm'], '/mob/var/may_do_after', '//Returns a list of all mobs')
    expected = None
    if control == 'dispatch':
        assert '\tif (try_bump_mining(AM))\n\t\treturn\n' in bump
        bump = bump.replace('\tif (try_bump_mining(AM))\n\t\treturn\n', '')
        expected = 'bump_starts_once'
    elif control == 'reservation':
        assert 'H.pickaxe_mining_action || ' in mining
        mining = mining.replace('H.pickaxe_mining_action || ', '')
        expected = 'different_wall_cannot_queue'
    elif control == 'position':
        assert 'actor.step_x == sx && actor.step_y == sy && ' in mining
        mining = mining.replace('actor.step_x == sx && actor.step_y == sy && ', '')
        expected = 'subtile_motion_cancels'
    adjacency = files['code/_onclick/adjacent.dm']
    adjacent = '/atom/proc/Adjacent(atom/neighbor)\n\treturn FALSE\n'
    adjacent += block(adjacency, '/turf/Adjacent(', '/turf/rangedAdjacent(')
    adjacent += block(adjacency, '/atom/movable/Adjacent(', '/*\n\tSpecial case:')
    adjacent += block(adjacency, '/turf/proc/ClickCross(', '/*\n\tAside:')
    persistence = files['code/modules/persistence/functions.dm']
    policy = block(persistence, '/datum/proc/persistence_runtime_var(key)', '/datum/proc/get_saved_vars()')
    policy += block(persistence, '/atom/persistence_runtime_var(key)', '// Lighting graphs')
    policy += block(persistence, '/turf/persistence_runtime_var(key)', '// HUD objects')
    policy += block(persistence, '/mob/persistence_runtime_var(key)', '/obj/screen')
    if control == 'persistence':
        assert ' || key == "mining_in_progress"' in policy
        policy = policy.replace(' || key == "mining_in_progress"', '')
        expected = 'runtime_import_rejects_busy'
    return bump + mining + wait + adjacent + policy, expected, files


def prepare(output, control=None):
    output = Path(output)
    if output.exists(): raise ValueError('fresh output required')
    output.mkdir(parents=True)
    generated, expected, files = source(control)
    for name in ('support.dm', 'probe.dm'):
        shutil.copyfile(Path(__file__).with_name(name), output / name)
    (output / 'production.dm').write_text(generated, encoding='utf-8')
    (output / 'probe.dme').write_text('#include "support.dm"\n#include "production.dm"\n#include "probe.dm"\n')
    asset = 'sound/effects/pickaxe.ogg'
    (output / asset).parent.mkdir(parents=True)
    shutil.copyfile(ROOT / asset, output / asset)
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    manifest = dict(head=head, control=control, expected_failure=expected, byond='516.1681',
                    source_sha256={p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in files},
                    generated_sha256={p.relative_to(output).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in output.rglob('*') if p.is_file()},
                    resource_sha256={asset: hashlib.sha256((ROOT / asset).read_bytes()).hexdigest()},
                    scope='extracted production Bump/mining/wait; inert human/tool/output/authority boundaries',
                    subtile_3228='not integrated; offset cancellation tested, not opt-in transaction acceptance')
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    return manifest


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--prepare-only', action='store_true')
    p.add_argument('--byond-bin', type=Path)
    p.add_argument('--negative-control', choices=('dispatch', 'reservation', 'position', 'persistence'))
    a = p.parse_args()
    M = prepare(a.output, a.negative_control)
    if a.prepare_only: return
    if a.byond_bin is None: p.error('--byond-bin required for native execution')
    binaries = a.byond_bin.resolve()
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    C = subprocess.run([str(binaries / ('dm.exe' if os.name == 'nt' else 'DreamMaker')), '-max_errors', '0', 'probe.dme'], cwd=a.output, capture_output=True, timeout=120, creationflags=flags)
    log = (C.stdout + C.stderr).decode(errors='replace')
    (a.output / 'compiler.log').write_text(log)
    print(log)
    if C.returncode or '516.1681' not in log or not re.search(r'\b0 errors,\s*0 warnings\b', log): raise RuntimeError('pinned compilation failed')
    R = subprocess.run([str(binaries / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')), 'probe.dmb', '59478', '-ip', '127.0.0.1', '-invisible', '-close', '-trusted', '-params', 'tested_commit=' + M['head'], '-log', 'runtime.log'], cwd=a.output, capture_output=True, timeout=100, creationflags=flags)
    log = (a.output / 'runtime.log').read_text(errors='replace') + (R.stdout + R.stderr).decode(errors='replace')
    (a.output / 'complete-runtime.log').write_text(log)
    result = json.loads((a.output / 'result.json').read_text())
    print(json.dumps(result))
    errors = a.output / 'errors.txt'
    if errors.exists() and errors.stat().st_size: raise RuntimeError('fixture error handler fired')
    if R.returncode or re.search(r'BUG:|##\s*error|runtime error|bad ref|bad loc|cannot (?:read|execute) null', log, re.I): raise RuntimeError('unexpected native diagnostic')
    if result['head'] != M['head'] or result['build'] != 1681: raise RuntimeError('native identity mismatch')
    if result['checks'] != 32: raise RuntimeError('incomplete named oracle coverage')
    failures = result['failures']
    if M['expected_failure']:
        if M['expected_failure'] not in failures: raise RuntimeError('named negative control escaped')
    elif failures:
        raise RuntimeError('native oracles failed')


if __name__ == '__main__': main()
