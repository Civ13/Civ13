"""Bounded production accessory removal; preparation never executes BYOND."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts/gameplay_bridge'))
from prepare_native import isolated_startup

ACCESSORY = 'code/game/objects/items/clothing/under/accessories/accessory.dm'
PREFIX = '.accessory_removal_ci'
CONTROLS = {
    'original-usr': 'tie/different_usr/actor_custody',
    'fork-guard': 'tie/null_user_other_usr/actor_custody',
}


def replace_once(source, old, new):
    if source.count(old) != 1:
        raise ValueError('Missing or ambiguous source anchor: ' + old)
    return source.replace(old, new, 1)


def sources(root=ROOT, control=None):
    if control is not None and control not in CONTROLS:
        raise ValueError('Unknown control')
    world, globals_source = isolated_startup(
        (root / 'code/world.dm').read_text(encoding='utf-8'),
        (root / 'code/controllers/mc/globals.dm').read_text(encoding='utf-8'))
    accessory = (root / ACCESSORY).read_text(encoding='utf-8')
    if '\t\tuser.put_in_hands(src)\n' not in accessory:
        raise ValueError('Explicit actor source premise changed')
    if control:
        accessory = replace_once(accessory, '\t\tuser.put_in_hands(src)\n',
                                 '\t\tusr.put_in_hands(src)\n')
    if control == 'fork-guard':
        accessory = replace_once(accessory, '\tif (user)\n', '\tif (usr)\n')
    dme = (root / 'civ13.dme').read_text(encoding='utf-8')
    for old, new in [('code\\world.dm', PREFIX + '_world.dm'),
                     ('code\\controllers\\mc\\globals.dm', PREFIX + '_globals.dm'),
                     (ACCESSORY.replace('/', '\\'), PREFIX + '_accessory.dm')]:
        dme = replace_once(dme, old, new)
    dme = re.sub(r'^#include ".*\.dmm".*$', '', dme, flags=re.M)
    dme += '\n#include "tests/accessory_removal/probe.dm"\n'
    return {PREFIX + '_world.dm': world, PREFIX + '_globals.dm': globals_source,
            PREFIX + '_accessory.dm': accessory, PREFIX + '.dme': dme}


def prepare(evidence, control=None, root=ROOT):
    if evidence.exists() and any(evidence.iterdir()):
        raise ValueError('Preserve existing evidence')
    generated = sources(root, control)
    evidence.mkdir(parents=True, exist_ok=True)
    for name, value in generated.items():
        (evidence / name).write_text(value, encoding='utf-8', newline='\n')
    paths = [ACCESSORY, 'code/game/objects/items/clothing/clothing_accessories.dm',
             'code/game/objects/items/clothing/under/accessories/holster.dm',
             'code/game/objects/items/clothing/under/accessories/sheaths.dm',
             'code/game/mob/inventory.dm', 'code/game/mob/living/carbon/human/human.dm',
             'tests/accessory_removal/probe.dm', 'scripts/gameplay_bridge/prepare_native.py']
    metadata = dict(head=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
                    control=control, required_failure=CONTROLS.get(control),
                    source_sha256={p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in paths},
                    generated_sha256={p: hashlib.sha256(s.encode()).hexdigest() for p, s in generated.items()},
                    seams=['existing isolated_startup world/global constructor adapter',
                           'human New and inventory icon updates only; production hand placement retained',
                           'fingerprint argument recorder, no DNA/account attribution claim',
                           'fixture attachment setup and clothing icon-update counter'],
                    limits='No normal clients, strip UI, DNA fingerprints, full-game startup, persistence or performance proof.')
    (evidence / 'metadata.json').write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')
    return generated, metadata


def verify_result(result, control):
    if result.get('case_count') != 27 or result.get('check_count') != 270 or result.get('runtime_error'):
        raise ValueError('Incomplete fixture or unexpected native runtime error')
    checks = result.get('checks', [])
    if len(checks) != 270 or len({c['label'] for c in checks}) != 270:
        raise ValueError('Missing or repeated native oracle labels')
    failed = result.get('failed_labels', [])
    if failed != [c['label'] for c in checks if not c['passed']]:
        raise ValueError('Failure list disagrees with native checks')
    if control:
        if CONTROLS[control] not in failed:
            raise ValueError('Control missed its named actor-custody oracle')
    elif failed:
        raise ValueError('Production actor contracts failed: ' + ', '.join(failed))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--evidence-dir', type=Path, required=True)
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--negative-control', choices=CONTROLS)
    args = parser.parse_args()
    if not args.prepare_only and not args.byond_bin:
        parser.error('Explicit pinned BYOND bin required for native execution')
    evidence = args.evidence_dir.resolve()
    generated, metadata = prepare(evidence, args.negative_control)
    if args.prepare_only:
        print('PASS source preparation; native compilation/runtime UNRUN')
        return
    owned = [ROOT / p for p in generated] + [ROOT / (PREFIX + ext) for ext in ('.dmb', '.rsc')]
    if any(p.exists() for p in owned):
        raise ValueError('Preserve existing generated probe files')
    binary = args.byond_bin.resolve()
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    try:
        for name, value in generated.items():
            (ROOT / name).write_text(value, encoding='utf-8', newline='\n')
        compiler = binary / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
        build = subprocess.run([str(compiler), '-max_errors', '0', PREFIX + '.dme'], cwd=ROOT,
                               capture_output=True, text=True, timeout=180, creationflags=flags)
        log = build.stdout + build.stderr
        (evidence / 'compile.log').write_text(log, encoding='utf-8')
        print(log, flush=True)
        if build.returncode or '516.1681' not in log or '0 errors, 0 warnings' not in log:
            raise ValueError('Pinned compilation failed')
        for ext in ('.dmb', '.rsc'):
            shutil.copy2(ROOT / (PREFIX + ext), evidence / (PREFIX + ext))
        shutil.copytree(ROOT / 'config/names', evidence / 'config/names')
        (evidence / 'config/config.txt').write_text('# Offline accessory fixture\n', encoding='utf-8')
        daemon = binary / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
        runtime = subprocess.run([str(daemon), PREFIX + '.dmb', '-invisible', '-close', '-trusted',
                                  '-params', 'tested_commit=' + metadata['head'], '-log', 'runtime.log'],
                                 cwd=evidence, capture_output=True, timeout=60, creationflags=flags)
        (evidence / 'daemon.log').write_bytes(runtime.stdout + runtime.stderr)
        diagnostics = (evidence / 'runtime.log').read_text(encoding='utf-8', errors='replace')
        diagnostics += (runtime.stdout + runtime.stderr).decode(errors='replace')
        if runtime.returncode or re.search(r'runtime error|Bad ref|Bad loc|BUG:|## ERROR:', diagnostics, re.I):
            raise ValueError('Unexpected native diagnostics; inspect retained logs')
        result = json.loads((evidence / 'result.json').read_text(encoding='utf-8'))
        if result.get('commit') != metadata['head'] or 'COMPLETE accessory actor fixture' not in diagnostics:
            raise ValueError('Wrong source or missing terminal oracle')
        verify_result(result, args.negative_control)
        print(json.dumps(result, sort_keys=True), flush=True)
        print('PASS ' + (args.negative_control or 'production accessory actor consistency'), flush=True)
    finally:
        for path in owned:
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
