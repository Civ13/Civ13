"""Prepare actual NanoUI sources; native execution needs the coordinator's slot."""
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

PREFIX = '.faction_ui_assets_ci'
ASSETS = 'code/modules/client/asset_cache.dm'
CREATION = 'code/game/mob/groups/faction_creation.dm'
OMISSION_FAILURES = {
    'cold lookup registers once', 'cold cache contains JavaScript',
    'cold cache contains faction templates', 'cold common contains styles',
    'repeat lookup and disconnected sends do not register again',
}


def replace_once(text, before, after):
    if text.count(before) != 1:
        raise ValueError('Missing or ambiguous source anchor: ' + before)
    return text.replace(before, after, 1)


def sources(omit_registration=False):
    world, globals_source = isolated_startup(
        (ROOT / 'code/world.dm').read_text(encoding='utf-8'),
        (ROOT / 'code/controllers/mc/globals.dm').read_text(encoding='utf-8'))
    assets = (ROOT / ASSETS).read_text(encoding='utf-8')
    if omit_registration:
        assets = replace_once(assets, '\t\tA.register()\n\t\treturn A\n', '\t\treturn A\n')
    # Read-only registration count; original flist/fcopy_rsc/cache code remains.
    assets = replace_once(assets, '/datum/asset/nanoui/register()\n',
                          '/datum/asset/nanoui/register()\n\tfaction_ui_registrations++\n')
    creation = replace_once((ROOT / CREATION).read_text(encoding='utf-8'),
                            'ui = new(user, src, ui_key, "faction_creation.tmpl", name, 620, 900)',
                            'ui = new /datum/nanoui/faction_assets_probe(user, src, ui_key, "faction_creation.tmpl", name, 620, 900)')
    dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
    replacements = [('code/world.dm', '_world.dm'), ('code/controllers/mc/globals.dm', '_globals.dm'),
                    (ASSETS, '_assets.dm'), (CREATION, '_creation.dm')]
    for path, suffix in replacements:
        dme = replace_once(dme, path.replace('/', '\\'), PREFIX + suffix)
    dme = re.sub(r'^#include ".*\.dmm".*$', '', dme, flags=re.M)
    dme += '\n#include "tests/faction_ui_assets/probe.dm"\n'
    return {PREFIX + '_world.dm': world, PREFIX + '_globals.dm': globals_source,
            PREFIX + '_assets.dm': assets, PREFIX + '_creation.dm': creation, PREFIX + '.dme': dme}


def prepare(destination, omit_registration=False):
    if destination.exists() and any(destination.iterdir()):
        raise ValueError('Preserve existing evidence')
    generated = sources(omit_registration)
    destination.mkdir(parents=True, exist_ok=True)
    for name, text in generated.items():
        (destination / name).write_text(text, encoding='utf-8', newline='\n')
    source_paths = [ASSETS, CREATION, 'code/game/mob/groups/factions.dm',
                    'code/game/gameticker.dm', 'code/modules/nano/_nanoui.dm',
                    'code/modules/nano/nanomanager.dm', 'code/modules/nano/modules/nano_module.dm',
                    'tests/faction_ui_assets/probe.dm', 'tests/faction_ui_assets/run.py']
    source_paths += [p.relative_to(ROOT).as_posix() for p in (ROOT / 'UI').rglob('*') if p.is_file()]
    metadata = dict(head=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                    dirty_diff_sha256=hashlib.sha256(subprocess.check_output(['git', 'diff', '--binary'], cwd=ROOT)).hexdigest(),
                    omit_registration=omit_registration,
                    source_sha256={p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in source_paths},
                    generated_sha256={p: hashlib.sha256(s.encode()).hexdigest() for p, s in generated.items()},
                    seams=['existing isolated_startup disables game/global startup and all maps',
                           'inert human/map subtype constructors; simulated restored phase',
                           'read-only NanoUI register counter',
                           'UI subtype captures actual get_html instead of browse/winset',
                           'port always closed; Topic refused'],
                    limits='No client/resource-arrival acknowledgement, game Topic action, full save import, browser DOM or live acceptance')
    (destination / 'metadata.json').write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')
    return generated, metadata


def verify_result(result, omission):
    checks = result.get('checks', [])
    if result.get('port') != 0 or result.get('check_count') != 18 or len(checks) != 18:
        raise ValueError('Incomplete or listening native fixture')
    if len({c['label'] for c in checks}) != len(checks):
        raise ValueError('Repeated native labels')
    failed = result.get('failed_labels')
    if failed != [c['label'] for c in checks if not c['passed']]:
        raise ValueError('Inconsistent failed labels')
    if set(failed) != (OMISSION_FAILURES if omission else set()):
        raise ValueError('Unexpected native failures: ' + repr(failed))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--evidence-dir', type=Path, required=True)
    parser.add_argument('--omit-registration', action='store_true')
    args = parser.parse_args()
    if not args.prepare_only and not args.byond_bin:
        parser.error('Native execution requires an explicit pinned BYOND bin and coordinator slot')
    evidence = args.evidence_dir.resolve()
    generated, metadata = prepare(evidence, args.omit_registration)
    print(json.dumps(dict(head=metadata['head'], omit_registration=args.omit_registration,
                          generated_sha256=metadata['generated_sha256']), sort_keys=True), flush=True)
    if args.prepare_only:
        print('PASS preparation only; compiler/native/browser UNRUN')
        return
    owned = [ROOT / p for p in generated] + [ROOT / (PREFIX + ext) for ext in ('.dmb', '.rsc')]
    if any(p.exists() for p in owned):
        raise ValueError('Preserve existing root compiler inputs')
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    binary = args.byond_bin.resolve()
    try:
        for name, text in generated.items():
            (ROOT / name).write_text(text, encoding='utf-8', newline='\n')
        compiler = binary / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
        build = subprocess.run([str(compiler), '-max_errors', '0', PREFIX + '.dme'], cwd=ROOT,
                               capture_output=True, text=True, timeout=180, creationflags=flags)
        log = build.stdout + build.stderr
        (evidence / 'compile.log').write_text(log, encoding='utf-8')
        print(log, flush=True)
        if build.returncode or 'DM compiler version 516.1681' not in log or '0 errors, 0 warnings' not in log:
            raise ValueError('Pinned compilation failed')
        for ext in ('.dmb', '.rsc'):
            shutil.copy2(ROOT / (PREFIX + ext), evidence / (PREFIX + ext))
        shutil.copytree(ROOT / 'UI', evidence / 'UI')
        shutil.copytree(ROOT / 'config/names', evidence / 'config/names')
        (evidence / 'config/config.txt').write_text('# Isolated UI fixture\n', encoding='utf-8')
        (evidence / 'browser').mkdir()
        daemon = binary / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
        runtime = subprocess.run([str(daemon), PREFIX + '.dmb', '-invisible', '-close', '-trusted',
                                  '-params', 'tested_commit=' + metadata['head'], '-log', 'runtime.log'],
                                 cwd=evidence, capture_output=True, timeout=60, creationflags=flags)
        (evidence / 'daemon.log').write_bytes(runtime.stdout + runtime.stderr)
        diagnostics = (evidence / 'runtime.log').read_text(encoding='utf-8', errors='replace')
        diagnostics += (runtime.stdout + runtime.stderr).decode(errors='replace')
        if runtime.returncode or re.search(r'runtime error|Bad ref|Bad loc|BUG:|## ERROR:', diagnostics, re.I):
            raise ValueError('Unexpected native diagnostics')
        result = json.loads((evidence / 'result.json').read_text(encoding='utf-8'))
        print(json.dumps(result, sort_keys=True), flush=True)
        if result.get('commit') != metadata['head'] or 'COMPLETE faction UI assets' not in diagnostics:
            raise ValueError('Wrong source or missing terminal result')
        verify_result(result, args.omit_registration)
        print('PASS ' + ('named registration omission control' if args.omit_registration else 'production faction UI assets'))
    finally:
        for path in owned:
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
