"""Armor families: protection by construction and material, open era windows.

Compiles the production game with normal startup disabled and checks, on a
synthetic 6x4x1 world, the family values for cut, pierce, blunt and arrow,
that every look in a family protects the same, that forging sets the tier
from the metal, and that armor recipes stay craftable in later eras. Prints
the evidence directory.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import uuid

# Each control restores one part of the old behavior and must fail.
CONTROLS = {
    'no-family': ('code/game/mob/living/carbon/human/human_defense.dm',
                  'protection += C.armor_value(type)', 'protection += armor_rating(C.armor, type)', 'FAIL:'),
    'no-forge-tier': ('code/modules/1713/steel_grades.dm',
                      '\t\t\tC.armor_tier = tier\n', '\t\t\tC.armor_tier = C.armor_tier\n', 'FAIL:'),
    'era-closed': ('code/game/objects/structures/blacksmithing/blacksmithing.dm',
                   '"4+" = list("cancel","helmets","other helmets","armor",', '"4" = list("cancel","helmets","other helmets","armor",', 'FAIL:'),
    'full-underlayer': ('code/game/objects/armor_families.dm',
                        '\tif (armor_underlayer && (type == HIT_CUT || type == HIT_PIERCE))\n\t\treturn 0\n', '', 'FAIL:'),
}


def compiler_matches(text, returncode, version):
    return (returncode == 0 and
            re.search(r'^DM compiler version ' + re.escape(version) + r'\b', text, re.MULTILINE) is not None and
            re.search(r'\b0 errors,\s*0 warnings\b', text) is not None)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--negative-control', choices=sorted(CONTROLS))
    parser.add_argument('--expected-byond-version', default='516.1688')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    stem = '.armor_families_' + uuid.uuid4().hex
    generated = {suffix: root / (stem + suffix) for suffix in
                 ('.dme', '_world.dm', '_globals.dm', '_helpers.dm', '.dmb', '.rsc')}
    output = Path(tempfile.mkdtemp(prefix='civ13-armor-families-'))
    print(f'Evidence: {output}', flush=True)
    try:
        world = (root / 'code/world.dm').read_text(encoding='utf-8')
        start = world.index('/world/New()')
        parent = world.index('\n\t..()', start)
        world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
        world = world.replace('/world/New()', '/world/proc/unused_roof_startup()', 1)
        world = world.replace('/datum/global_init/New()\n', '/datum/global_init/New()\n\treturn\n', 1)
        generated['_world.dm'].write_text(world, encoding='utf-8')
        globals_source = (root / 'code/controllers/mc/globals.dm').read_text(encoding='utf-8')
        marker = '/datum/controller/global_vars/New()\n'
        if globals_source.count(marker) != 1:
            raise RuntimeError('Global isolation marker changed')
        generated['_globals.dm'].write_text(globals_source.replace(marker, marker + '\treturn\n'), encoding='utf-8')
        source = (root / 'civ13.dme').read_text(encoding='utf-8')
        replacements = [('code\\world.dm', '_world.dm'), ('code\\controllers\\mc\\globals.dm', '_globals.dm')]
        if args.negative_control:
            target, old, new, _ = CONTROLS[args.negative_control]
            helpers = (root / target).read_text(encoding='utf-8')
            if helpers.count(old) != 1:
                raise RuntimeError('Negative-control target missing or ambiguous')
            generated['_helpers.dm'].write_text(helpers.replace(old, new, 1), encoding='utf-8')
            replacements.append((target.replace('/', '\\'), '_helpers.dm'))
        for original, suffix in replacements:
            if source.count(original) != 1:
                raise RuntimeError(f'Include {original} missing from civ13.dme')
            source = source.replace(original, generated[suffix].name)
        source = re.sub(r'^#include ".*\.dmm"\s*$', '', source, flags=re.M)
        generated['.dme'].write_text(source + '\n#include "tests/armor_families/probe.dm"\n', encoding='utf-8')
        compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
        daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
        build = subprocess.run([str(compiler), '-max_errors', '0', str(generated['.dme'])], cwd=root,
                               capture_output=True, text=True, timeout=300)
        text = build.stdout + build.stderr
        (output / 'compile.log').write_text(text, encoding='utf-8')
        print(text, flush=True)
        if not compiler_matches(text, build.returncode, args.expected_byond_version):
            raise RuntimeError('Pinned production-source compilation failed')
        for suffix in ('.dmb', '.rsc'):
            shutil.copy2(generated[suffix], output / generated[suffix].name)
        for rel in subprocess.check_output(['git', 'ls-files', 'config/names'], cwd=root, text=True).splitlines():
            destination = output / rel
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(root / rel, destination)
        (output / 'data').mkdir(exist_ok=True)
        command = [str(daemon), str(output / generated['.dmb'].name)]
        if os.name == 'nt':
            command += ['-invisible', '-close']
        runtime = subprocess.run(command + ['-trusted', '-log', 'runtime.log'], cwd=output,
                                 capture_output=True, text=True, timeout=120)
        (output / 'daemon.log').write_text(runtime.stdout + runtime.stderr, encoding='utf-8')
        log = (output / 'runtime.log').read_text(encoding='utf-8', errors='replace')
        print(log, flush=True)
        result = (output / 'armor_family_result.txt').read_text(encoding='utf-8')
        print(result, flush=True)
        expected = CONTROLS[args.negative_control][3] if args.negative_control else 'PASS:'
        if runtime.returncode or not result.startswith(expected) or any(x in log.lower() for x in ('runtime error:', '## error:', 'bug:')):
            raise RuntimeError('Armor family probe failed')
        if args.negative_control:
            print('PASS: negative control failed as expected', flush=True)
        (output / 'metadata.json').write_text(json.dumps({'negative_control': args.negative_control, 'result': 'passed'}), encoding='utf-8')
    finally:
        for path in generated.values():
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
