"""Dyed custom clothing and attached accessories across a whole-world save/load.

Compiles the production game types and persistence code with normal startup
disabled, builds a synthetic 6x4x1 world with dyed, undyed and previously
flipped custom garments plus a garment with accessories attached, then runs
Save_World, ClearMap and Load_World in temporary storage. Prints the evidence
directory.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import uuid

APPAREL = 'code/modules/1713/custom_apparel.dm'
ACCESSORIES = 'code/game/objects/items/clothing/clothing_accessories.dm'
# Each control removes one part of the fix and must fail: (file, old, new).
CONTROLS = {
    'dye-flag-in-new': (APPAREL, '\ton_runtime_spawn()\n\t\t..()\n\t\tspawn(5)\n\t\t\tuncolored = TRUE\n',
                        '\tNew()\n\t\t..()\n\t\tspawn(5)\n\t\t\tuncolored = TRUE\n'),
    'no-dye-repair': (APPAREL, '/obj/item/clothing/proc/repair_restored_dye()\n',
                      '/obj/item/clothing/proc/repair_restored_dye()\n\treturn\n'),
    'no-verb-rebuild': (ACCESSORIES, '\tverbs |= /obj/item/clothing/proc/removetie_verb\n\tfor',
                        '\tfor'),
}


_compiler_spec = importlib.util.spec_from_file_location(
    'fixture_compiler_output', Path(__file__).resolve().parents[2] / 'scripts/fixture_compiler_output.py')
_compiler_output = importlib.util.module_from_spec(_compiler_spec)
_compiler_spec.loader.exec_module(_compiler_output)
compiler_matches = _compiler_output.compiler_matches

_global_spec = importlib.util.spec_from_file_location(
    'fixture_global_initialization', Path(__file__).resolve().parents[2] / 'scripts/fixture_global_initialization.py')
_global_initialization = importlib.util.module_from_spec(_global_spec)
_global_spec.loader.exec_module(_global_initialization)
isolate_global_initialization = _global_initialization.isolate_global_initialization


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--negative-control', choices=sorted(CONTROLS))
    parser.add_argument('--expected-byond-version', default='516.1688')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    stem = '.custom_clothing_load_' + uuid.uuid4().hex
    generated = {suffix: root / (stem + suffix) for suffix in
                 ('.dme', '_world.dm', '_globals.dm', '_helpers.dm', '.dmb', '.rsc')}
    output = Path(tempfile.mkdtemp(prefix='civ13-custom-clothing-load-'))
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
        generated['_globals.dm'].write_text(isolate_global_initialization(globals_source), encoding='utf-8')
        source = (root / 'civ13.dme').read_text(encoding='utf-8')
        replacements = [('code\\world.dm', '_world.dm'), ('code\\controllers\\mc\\globals.dm', '_globals.dm')]
        if args.negative_control:
            target, old, new = CONTROLS[args.negative_control]
            helpers = (root / target).read_text(encoding='utf-8')
            if old not in helpers:
                raise RuntimeError('Negative-control target missing')
            # The first match is the base type the probe's garments inherit from.
            generated['_helpers.dm'].write_text(helpers.replace(old, new, 1), encoding='utf-8')
            replacements.append((target.replace('/', '\\'), '_helpers.dm'))
        for original, suffix in replacements:
            if source.count(original) != 1:
                raise RuntimeError(f'Include {original} missing from civ13.dme')
            source = source.replace(original, generated[suffix].name)
        source = re.sub(r'^#include ".*\.dmm"\s*$', '', source, flags=re.M)
        generated['.dme'].write_text(source + '\n#include "tests/custom_clothing_load/probe.dm"\n', encoding='utf-8')
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
        result = (output / 'clothing_result.txt').read_text(encoding='utf-8')
        print(result, flush=True)
        expected = 'FAIL:' if args.negative_control else 'PASS:'
        if runtime.returncode or not result.startswith(expected) or any(x in log.lower() for x in ('runtime error:', '## error:', 'bug:')):
            raise RuntimeError('Custom clothing load probe failed')
        if args.negative_control:
            print('PASS: negative control failed as expected', flush=True)
        (output / 'metadata.json').write_text(json.dumps({'negative_control': args.negative_control, 'result': 'passed'}), encoding='utf-8')
    finally:
        for path in generated.values():
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
