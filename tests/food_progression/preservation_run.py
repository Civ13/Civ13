"""Bounded production food probes with temporary runtime storage."""
import argparse
import hashlib
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
    control.add_argument('--can-negative-control', action='store_true')
    parser.add_argument('--probe', choices=('crop', 'storage', 'preservation', 'rack-save'), default='preservation')
    parser.add_argument('--preservation-control', choices=('nutrition', 'age', 'conversion'))
    parser.add_argument('--rack-control', choices=('coverage', 'runtime', 'storage', 'stale-wait', 'duplicate', 'conversion'))
    parser.add_argument('--output', type=Path)
    parser.add_argument('--stem')
    parser.add_argument('--start-gated', action='store_true')
    parser.add_argument('--prepare-only', action='store_true', help='Generate/hash isolated sources without launching BYOND')
    args = parser.parse_args()
    if args.rack_control and (args.probe != 'rack-save' or args.preservation_control):
        parser.error('Rack controls require --probe rack-save and no preservation control')
    if args.start_gated and input() != 'start':
        raise RuntimeError('Missing resource guard release')
    if args.can_negative_control:
        args.probe = 'storage'
    root = Path(__file__).resolve().parents[2]
    stem = args.stem or '.food_progression_' + uuid.uuid4().hex
    if not re.fullmatch(r'\.food_progression_[0-9a-f]{32}', stem):
        raise RuntimeError('Invalid isolated fixture stem')
    generated = {suffix: root / (stem + suffix) for suffix in
                 ('.dme', '_world.dm', '_globals.dm', '_farming.dm', '_floor.dm', '_persistence.dm', '_food.dm', '_production.dm', '.dmb', '.rsc')}
    output = args.output or Path(tempfile.mkdtemp(prefix='civ13-food-preservation-'))
    output.mkdir(parents=True, exist_ok=True)
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
        if args.probe == 'storage':
            food = (root / 'code/modules/reagents/reagent_containers/food.dm').read_text(encoding='utf-8')
            wait = 'spawn(rand(590,610))'
            if food.count(wait) != 1:
                raise RuntimeError('Food wait marker changed')
            food = food.replace(wait, 'spawn(2)')
            if args.can_negative_control:
                guard = 'else // Closed cans already returned above; opened cans age like ordinary storage.'
                if food.count(guard) != 1:
                    raise RuntimeError('Open-can control marker changed')
                food = food.replace(guard, 'else if (!istype(loc, /obj/item/weapon/can))')
            generated['_food.dm'].write_text(food, encoding='utf-8')
            source = source.replace('code\\modules\\reagents\\reagent_containers\\food.dm', generated['_food.dm'].name)
        if args.probe in ('preservation', 'rack-save'):
            production = (root / 'code/modules/1713/production.dm').read_text(encoding='utf-8')
            marker = 'spawn(150) //one tick at 15 seconds will be enough'
            if production.count(marker) != 1:
                raise RuntimeError('Production drying wait marker changed')
            if args.rack_control == 'coverage':
                coverage = ('\tfor (var/atom/movable/child in origin.contents)\n'
                            '\t\tif (!(child in paid_items))\n'
                            '\t\t\tthrow EXCEPTION("Dehydrator save has an unrepresented storage child")')
                if production.count(coverage) != 1:
                    raise RuntimeError('Rack wrapper coverage control marker changed')
                production = production.replace(coverage, '\t// omission control permits unrepresented wrapper children')
            if args.rack_control == 'stale-wait':
                wake_guard = '\t\tif (this_process != current_process_id || !isturf(loc) || !storage || storage.loc != src || storage.master_item != src)'
                if production.count(wake_guard) != 1:
                    raise RuntimeError('Rack wake ownership control marker changed')
                production = production.replace(wake_guard, '\t\tif (!storage) // omission control restores stale wake mutation')
            if args.rack_control == 'runtime':
                exclusion = '\treturn (key in list("slots", "storage", "current_process_id")) || ..()'
                if production.count(exclusion) != 1:
                    raise RuntimeError('Rack runtime exclusion control marker changed')
                production = production.replace(exclusion, '\treturn ..() // omission control restores runtime export/import')
            if args.rack_control == 'storage':
                reinit = '\t\tensure_runtime_storage()\n\t\trefill()'
                after_load = '\tcurrent_process_id = "" //Invalidate callbacks from before restoration.\n\tensure_runtime_storage()'
                if production.count(reinit) != 1 or production.count(after_load) != 1:
                    raise RuntimeError('Rack storage rebuild control markers changed')
                production = production.replace(reinit, '\t\trefill()')
                production = production.replace(after_load, '\tcurrent_process_id = "" // omission control leaves detached constructor storage')
            production_control = 'nutrition' if args.rack_control == 'conversion' else args.preservation_control
            if production_control:
                if production_control in ('nutrition', 'conversion'):
                    first = '\t\t\t\t\t\t\t// Preserve hunger value'
                    last = '\t\t\t\t\t\t\tvar/decay_offset'
                    if production.count('\n' + first) != 1 or production.count('\n' + last) != 1:
                        raise RuntimeError('Preservation nutrition control line markers changed')
                    start = production.index('\n' + first) + 1
                    end = production.index('\n' + last, start) + 1
                    replacement = ''
                    if production_control == 'conversion':
                        replacement = '\t\t\t\t\t\t\tfor (var/nutrient in list("nutriment", "protein"))\n\t\t\t\t\t\t\t\tvar/excess = output_food.reagents.get_reagent_amount(nutrient) - input_food.reagents.get_reagent_amount(nutrient)\n\t\t\t\t\t\t\t\tif (excess > 0)\n\t\t\t\t\t\t\t\t\toutput_food.reagents.remove_reagent(nutrient, excess)\n'
                    production = production[:start] + replacement + production[end:]
                else:
                    age = '\t\t\t\t\t\t\t\toutput_food.decaytimer = max(output_food.decaytimer, input_food.decaytimer * output_food.decay / original_decay)'
                    if production.count(age) != 1:
                        raise RuntimeError('Preservation age control marker changed')
                    production = production.replace(age, '\t\t\t\t\t\t\t\toutput_food.decaytimer = 0 // omission control')
            if args.probe == 'preservation':
                production = production.replace(marker, 'spawn(2) // accelerated drying wait')
            generated['_production.dm'].write_text(production, encoding='utf-8')
            source = source.replace('code\\modules\\1713\\production.dm', generated['_production.dm'].name)
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
        probe = root / 'tests/food_progression' / ('rack_save.dm' if args.probe == 'rack-save' else 'preservation.dm' if args.probe == 'preservation' else 'storage.dm' if args.probe == 'storage' else 'probe.dm')
        control_define = '#define RACK_CONTROL_DUPLICATE\n' if args.rack_control == 'duplicate' else ''
        generated['.dme'].write_text(source + '\n' + control_define + '#include "' + probe.relative_to(root).as_posix() + '"\n', encoding='utf-8')
        head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
        hash_paths = [probe, Path(__file__), Path(__file__).with_name('preservation_guard.py'), Path(__file__).with_name('guard_cleanup.py')] + [root / name for name in ('code/modules/1713/production.dm', 'code/modules/persistence/functions.dm', 'code/modules/persistence/saving.dm', 'code/modules/persistence/loading.dm', 'code/modules/reagents/reagent_containers/food/snacks.dm', 'code/modules/reagents/Chemistry-Reagents/Chemistry-Reagents-Food-Drinks.dm')]
        source_hashes = {path.relative_to(root).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest() for path in hash_paths}
        (output / 'metadata.json').write_text(json.dumps({'commit': head, 'prepare_only': args.prepare_only, 'source_hashes': source_hashes, 'rack_control': args.rack_control, 'preservation_control': args.preservation_control, 'negative_control': args.negative_control, 'soil_negative_control': args.soil_negative_control, 'can_negative_control': args.can_negative_control, 'probe': args.probe,
            'drying_wait_ticks': 2 if args.probe == 'preservation' else 150 if args.probe == 'rack-save' else None, 'runtime_timeout_seconds': 45 if args.probe == 'rack-save' else 30, 'growth_wait_ticks': 2, 'food_wait_ticks': 2 if args.probe == 'storage' else None, 'normal_startup': False, 'map': 'synthetic 6x3x1 rack/turf graph' if args.probe == 'rack-save' else 'synthetic 6x3x1 preservation fixture' if args.probe == 'preservation' else 'synthetic 6x3x1 storage fixture' if args.probe == 'storage' else 'synthetic 6x3x1 temperate plot'}), encoding='utf-8')
        (output / 'checkout.patch').write_text(subprocess.check_output(['git', 'diff', 'HEAD'], cwd=root, text=True), encoding='utf-8')
        shutil.copy2(probe, output / 'probe.dm')
        for path in generated.values():
            if path.exists():
                shutil.copy2(path, output / path.name)
        if args.prepare_only:
            print('PREPARED: isolated sources only; no compiler or daemon launched', flush=True)
            return
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
                                 capture_output=True, text=True, timeout=45 if args.probe == 'rack-save' else 30, creationflags=flags)
        (output / 'daemon.log').write_text(runtime.stdout + runtime.stderr, encoding='utf-8')
        log = (output / 'runtime.log').read_text(encoding='utf-8', errors='replace')
        print(log, flush=True)
        result = (output / 'food_result.txt').read_text(encoding='utf-8')
        print(result, flush=True)
        expected = ('FAIL: wrapper coverage refusal mode 0 reaches ownership check' if args.rack_control == 'coverage' else
                    'FAIL: rack export excludes runtime fields' if args.rack_control == 'runtime' else
                    'FAIL: restored rack rebuilds runtime storage before refill' if args.rack_control == 'storage' else
                    'FAIL: stale drying wait does not advance or consume paid input' if args.rack_control == 'stale-wait' else
                    'FAIL: restored rack contains exactly one paid input' if args.rack_control == 'duplicate' else
                    'FAIL: restored conversion retains paid nutrition' if args.rack_control == 'conversion' else
                    'FAIL: drying does not replenish consumed nutrition' if args.preservation_control == 'nutrition' else
                    'FAIL: drying retains available nutrition across reagent conversion' if args.preservation_control == 'conversion' else
                    'FAIL: drying does not erase accumulated age' if args.preservation_control == 'age' else
                    'FAIL: opened can accumulates food age' if args.can_negative_control else
                    'FAIL: production planting consumes one seed' if args.negative_control else
                    'FAIL: full turf entry restores nondefault soil nutrition' if args.soil_negative_control else 'PASS:')
        if runtime.returncode or not result.startswith(expected) or any(x in log.lower() for x in ('runtime error:', '## error:', 'bug:')):
            raise RuntimeError('Production progression probe failed')
        if args.rack_control or args.preservation_control or args.negative_control or args.soil_negative_control or args.can_negative_control:
            print('PASS: expected regression mutation detected', flush=True)
    finally:
        for path in generated.values():
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
