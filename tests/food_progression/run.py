"""Bounded production planting/harvest probe with temporary runtime storage."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import uuid


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    control = parser.add_mutually_exclusive_group()
    control.add_argument('--negative-control', action='store_true')
    control.add_argument('--soil-negative-control', action='store_true')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    stem = '.food_progression_' + uuid.uuid4().hex
    generated = {suffix: root / (stem + suffix) for suffix in
                 ('.dme', '_world.dm', '_globals.dm', '_farming.dm', '_floor.dm', '_persistence.dm', '.dmb', '.rsc')}
    output = Path(tempfile.mkdtemp(prefix='civ13-food-progression-'))
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    print(f'Evidence: {output}', flush=True)
    try:
        world = (root / 'code/world.dm').read_text(encoding='utf-8')
        start = world.index('/world/New()')
        parent = world.index('\n\t..()', start)
        world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
        world = world.replace('/world/New()', '/world/proc/unused_food_startup()', 1)
        world = world.replace('/datum/global_init/New()\n', '/datum/global_init/New()\n\treturn\n', 1)
        generated['_world.dm'].write_text(world, encoding='utf-8')
        globals_source = (root / 'code/controllers/mc/globals.dm').read_text(encoding='utf-8')
        marker = '/datum/controller/global_vars/New()\n'
        if globals_source.count(marker) != 1:
            raise RuntimeError('Global isolation marker changed')
        generated['_globals.dm'].write_text(globals_source.replace(marker, marker + '\treturn\n'), encoding='utf-8')
        farming = (root / 'code/game/objects/farming.dm').read_text(encoding='utf-8')
        marker = '\t\tspawn(600) // 1 minute'
        if farming.count(marker) != 1:
            raise RuntimeError('Growth wait marker changed')
        generated['_farming.dm'].write_text(farming.replace(marker, '\t\tspawn(2) // accelerated fixture wait'), encoding='utf-8')
        source = (root / 'civ13.dme').read_text(encoding='utf-8')
        for original, suffix in [('code\\world.dm', '_world.dm'),
                                 ('code\\controllers\\mc\\globals.dm', '_globals.dm'),
                                 ('code\\game\\objects\\farming.dm', '_farming.dm')]:
            source = source.replace(original, generated[suffix].name)
        if args.negative_control:
            floor = (root / 'code/game/turfs/floor_attackby.dm').read_text(encoding='utf-8')
            start = floor.index('\telse if (istype(C, /obj/item/stack/farming/seeds)')
            end = floor.index('\telse if (istype(C, /obj/item/weapon/plough))', start)
            planting = floor[start:end]
            marker = '\t\t\tif (C.amount>1)\n\t\t\t\tC.amount -= 1'
            if planting.count(marker) != 1:
                raise RuntimeError('Seed-consumption mutation marker changed')
            floor = floor[:start] + planting.replace(marker, '\t\t\tif (C.amount>1)\n\t\t\t\tC.amount -= 0') + floor[end:]
            generated['_floor.dm'].write_text(floor, encoding='utf-8')
            source = source.replace('code\\game\\turfs\\floor_attackby.dm', generated['_floor.dm'].name)
        if args.soil_negative_control:
            persistence = (root / 'code/modules/persistence/functions.dm').read_text(encoding='utf-8')
            marker = '\t. |= "soil_nutrition"'
            if persistence.count(marker) != 1:
                raise RuntimeError('Soil persistence mutation marker changed')
            generated['_persistence.dm'].write_text(persistence.replace(marker, '\t// negative control omits soil nutrition'), encoding='utf-8')
            source = source.replace('code\\modules\\persistence\\functions.dm', generated['_persistence.dm'].name)
        source = re.sub(r'^#include ".*\.dmm"\s*$', '', source, flags=re.M)
        generated['.dme'].write_text(source + '\n#include "tests/food_progression/probe.dm"\n', encoding='utf-8')
        head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
        (output / 'metadata.json').write_text(json.dumps({'commit': head, 'negative_control': args.negative_control, 'soil_negative_control': args.soil_negative_control,
            'growth_wait_ticks': 2, 'normal_startup': False, 'map': 'synthetic 6x3x1 temperate plot'}), encoding='utf-8')
        (output / 'checkout.patch').write_text(subprocess.check_output(['git', 'diff', 'HEAD'], cwd=root, text=True), encoding='utf-8')
        shutil.copy2(root / 'tests/food_progression/probe.dm', output / 'probe.dm')
        for path in generated.values():
            if path.exists():
                shutil.copy2(path, output / path.name)
        compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
        daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
        build = subprocess.run([str(compiler), '-max_errors', '0', str(generated['.dme'])], cwd=root,
                               capture_output=True, text=True, timeout=120, creationflags=flags)
        text = build.stdout + build.stderr
        (output / 'compile.log').write_text(text, encoding='utf-8')
        print(text, flush=True)
        if build.returncode or 'DM compiler version 516.1681' not in text or '0 errors, 0 warnings' not in text:
            raise RuntimeError('Pinned production-source compilation failed')
        for suffix in ('.dmb', '.rsc'):
            shutil.copy2(generated[suffix], output / generated[suffix].name)
        for rel in subprocess.check_output(['git', 'ls-files', 'config/names'], cwd=root, text=True).splitlines():
            destination = output / rel
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(root / rel, destination)
        command = [str(daemon), str(output / generated['.dmb'].name)]
        if os.name == 'nt':
            command += ['-invisible', '-close']
        runtime = subprocess.run(command + ['-safe', '-log', 'runtime.log'], cwd=output,
                                 capture_output=True, text=True, timeout=30, creationflags=flags)
        (output / 'daemon.log').write_text(runtime.stdout + runtime.stderr, encoding='utf-8')
        log = (output / 'runtime.log').read_text(encoding='utf-8', errors='replace')
        print(log, flush=True)
        result = (output / 'food_result.txt').read_text(encoding='utf-8')
        print(result, flush=True)
        expected = ('FAIL: production planting consumes one seed' if args.negative_control else
                    'FAIL: full turf entry restores nondefault soil nutrition' if args.soil_negative_control else 'PASS:')
        if runtime.returncode or not result.startswith(expected) or any(x in log.lower() for x in ('runtime error:', '## error:', 'bug:')):
            raise RuntimeError('Production progression probe failed')
        if args.negative_control or args.soil_negative_control:
            print('PASS: expected regression mutation detected', flush=True)
    finally:
        for path in generated.values():
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
