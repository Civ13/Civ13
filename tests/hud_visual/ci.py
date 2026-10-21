"""Pinned, headless HUD fixture for disposable CI runners (not the Windows grant runner)."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

from run import BASE, ROOT

PREFIX = '.hud_visual_ci'
PRODUCTION = ('civ13.dme', 'code/world.dm', 'code/_onclick/hud/base_screen_objects.dm',
              'code/game/mob/living/carbon/human/human_hud.dm',
              'code/game/mob/living/carbon/human/human_life.dm',
              'code/game/mob/living/carbon/human/human.dm', 'code/modules/organs/organ.dm',
              'code/game/mob/living/carbon/human/traits.dm', 'icons/mob/screen1_full.dmi')


def sources():
    for name in PRODUCTION:
        baseline = subprocess.check_output(['git', 'show', BASE + ':' + name], cwd=ROOT)
        if (ROOT / name).read_bytes().replace(b'\r\n', b'\n') != baseline.replace(b'\r\n', b'\n'):
            raise ValueError('Changed reviewed production input: ' + name)
    world = (ROOT / 'code/world.dm').read_text(encoding='utf-8')
    anchor = world.index('/world/New()')
    parent = world.index('\n\t..()', anchor)
    world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
    world = world.replace('/world/New()', '/world/proc/unused_hud_probe_startup()', 1)
    world = world.replace('/world/Topic(T, addr, master, key)', '/world/proc/unused_hud_probe_topic(T, addr, master, key)', 1)
    dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
    dme = dme.replace('code\\world.dm', PREFIX + '_world.dm')
    dme = re.sub(r'^#include\s+"[^"\n]+\.dmm"\s*$', '', dme, flags=re.M)
    generated = {}
    for index, path in enumerate(('code/modules/client/client_procs.dm', 'code/modules/client/movement.dm')):
        original = (ROOT / path).read_text(encoding='utf-8')
        isolated, count = re.subn(r'(?ms)^/client/New\([^\n]*\)\n.*?(?=^/(?!/)|\Z)', '', original)
        if count != 1:
            raise ValueError('Client entry isolation drift: ' + path)
        name = PREFIX + '_client_' + str(index) + '.dm'
        generated[name] = isolated
        dme = dme.replace(path.replace('/', '\\'), name)
    dme += '\n#include "tests/hud_visual/probe.dm"\n'
    world += '\n/client/New(TopicData)\n\treturn FALSE\n'
    generated.update({PREFIX + '_world.dm': world, PREFIX + '.dme': dme})
    return generated


def verify(result, cases, logs):
    match = re.fullmatch(r'PASS assertions=(\d+) tagged_faults=3 headless_only=1\s*', result)
    if not match or int(match[1]) != len(cases) or len(cases) < 173:
        raise ValueError('Missing/incomplete native HUD verdict')
    if not all(c.get('pass') is True or c.get('pass') == 1 for c in cases):
        raise ValueError('Failed native HUD assertion')
    if not any('unrelated appearance observed' in c.get('assertion', '') for c in cases):
        raise ValueError('Missing appearance oracle coverage')
    if re.search(r'BUG:|UNEXPECTED|Runtime in|runtime error|Bad ref|Bad loc|FAIL ', logs, re.I):
        raise ValueError('Unexpected native diagnostics')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not args.prepare_only and not args.byond_bin:
        parser.error('Native execution requires --byond-bin')
    generated = sources()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    for name, value in generated.items():
        (out / name).write_text(value, encoding='utf-8')
    metadata = {'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                'base': BASE, 'sha256': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest()
                                      for p in (*PRODUCTION, 'tests/hud_visual/probe.dm')}}
    (out / 'metadata.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
    if args.prepare_only:
        print('PASS source preparation; native execution UNRUN')
        return
    owned = [ROOT / name for name in generated] + [ROOT / (PREFIX + ext) for ext in ('.dmb', '.rsc')]
    if any(p.exists() for p in owned):
        raise ValueError('Preserve existing compiler inputs')
    binary = args.byond_bin.resolve()
    try:
        for name, value in generated.items():
            (ROOT / name).write_text(value, encoding='utf-8')
        build = subprocess.run([str(binary / 'DreamMaker'), '-max_errors', '0', PREFIX + '.dme'],
                               cwd=ROOT, capture_output=True, text=True, timeout=180)
        log = build.stdout + build.stderr
        (out / 'compile.log').write_text(log, encoding='utf-8')
        print(log, flush=True)
        if build.returncode or 'DM compiler version 516.1681' not in log or '0 errors, 0 warnings' not in log:
            raise ValueError('Pinned warning-free compilation failed')
        for ext in ('.dmb', '.rsc'):
            shutil.copy2(ROOT / (PREFIX + ext), out / (PREFIX + ext))
        shutil.copytree(ROOT / 'config/names', out / 'config/names')
        (out / 'config/config.txt').write_text('server_name Isolated HUD fixture\n', encoding='utf-8')
        runtime = subprocess.run([str(binary / 'DreamDaemon'), PREFIX + '.dmb', '-invisible', '-close',
                                  '-trusted', '-log', 'runtime.log'], cwd=out,
                                 capture_output=True, text=True, timeout=60)
        log = runtime.stdout + runtime.stderr
        (out / 'daemon.log').write_text(log, encoding='utf-8')
        if runtime.returncode:
            raise ValueError('Native process failed')
        log += (out / 'runtime.log').read_text(encoding='utf-8', errors='replace')
        result = (out / 'result.txt').read_text(encoding='utf-8')
        cases = [json.loads(line) for line in (out / 'cases.jsonl').read_text(encoding='utf-8').splitlines()]
        verify(result, cases, log)
        print(result)
    finally:
        for path in owned:
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
