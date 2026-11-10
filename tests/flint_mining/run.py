"""Flint mining and knapping regressions.

Source checks: mined rock rolls flint independently of the ore table, stags
drop antler picks, the wooden spade is craftable at age 0, knapped flint
arrowheads fit arrows and bolts, and knapping falls back to the existing flint
whetstone behavior. Native (with --byond-bin): the nodule roll and antler
counts, compiled from procs extracted from the real source.

    python3 tests/flint_mining/run.py [--byond-bin DIR]
"""
import argparse
import glob
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
FLINT = 'code/modules/1713/flint_mining.dm'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def block(source, start):
    """The definition that starts at `start`, up to the next top-level line."""
    index = source.index(start)
    end = re.search(r'\n(?=[/\w#])', source[index + len(start):])
    return source[index:index + len(start) + (end.start() if end else len(source))]


def fletching_checks(ammo):
    """Check the shared fletching contract without launching the game."""
    failures = []
    helper = block(ammo, '/obj/item/ammo_casing/proc/attach_arrowhead(')
    if not helper.rstrip().endswith('\treturn TRUE'):
        failures.append('non-denied interactions must continue through the caller')
    flint = helper[:helper.index('\n\tif (istype(W, /obj/item/stack/arrowhead))')]
    stack = helper[len(flint):]
    if not re.search(r'if \(F\.sharpened\)\n\t\t\tvar/result = "\[shaft_path\]/flint"\n\t\t\tif \(!crafting_recipe_allowed\(user, result\)\) return FALSE\n\t\t\tvar/result_type = text2path\(result\)\n\t\t\tnew result_type\(user.loc\)\n\t\t\tqdel\(F\)', flint):
        failures.append('sharpened flint must be gated before output and consumption')
    if '\n\t\t\tqdel(src)' not in flint or '\n\t\tqdel(src)' in flint:
        failures.append('unsharpened flint must not delete the shaft')
    mappings = re.findall(r'istype\(W, /obj/item/stack/arrowhead/(\w+)\)\)\n\t\t\tmaterial = "(\w+)"', stack)
    expected = [(name, name) for name in ('stone', 'flint', 'copper', 'iron', 'bronze', 'steel', 'vial')]
    if mappings != expected or 'var/material = "gods"' not in stack:
        failures.append('arrowhead material mapping or default changed')
    steps = ('var/result = "[shaft_path]/[material]"',
             'if (!crafting_recipe_allowed(user, result)) return FALSE',
             'var/result_type = text2path(result)', 'new result_type(user.loc)',
             'AH.amount--', 'if (AH.amount<1)', 'qdel(AH)', 'qdel(src)')
    positions = [stack.find(step) for step in steps]
    if -1 in positions or positions != sorted(positions):
        failures.append('stack research, output and consumption order changed')
    for kind in ('arrow', 'bolt'):
        caller = block(ammo, f'/obj/item/ammo_casing/{kind}/attackby(')
        if f'if (!attach_arrowhead(W, user, "/obj/item/ammo_casing/{kind}"))\n\t\treturn' not in caller:
            failures.append(f'{kind} must stop on denied attachment')
        for material in ('gods', 'stone', 'flint', 'copper', 'iron', 'bronze', 'steel', 'vial'):
            if f'/obj/item/ammo_casing/{kind}/{material}\n' not in ammo:
                failures.append(f'missing {kind}/{material} output type')
        if ('if (istype(W, /obj/item/weapon/reagent_containers))' not in caller
                or not caller.rstrip().endswith('..()')):
            failures.append(f'{kind} must retain reagent and parent dispatch')
    return failures


def source_checks():
    failures = []
    flint = read(FLINT)
    dme = read('civ13.dme').splitlines()
    try:
        own = dme.index('#include "code\\modules\\1713\\flint_mining.dm"')
        for earlier in ('code\\game\\objects\\structures\\rocks.dm',
                        'code\\game\\objects\\items\\weapons\\material\\ooga_booga_weapons.dm',
                        'code\\modules\\1713\\animal_harvest.dm'):
            if dme.index(f'#include "{earlier}"') > own:
                failures.append(f'flint_mining.dm must be included after {earlier} so its overrides call ..()')
    except ValueError as error:
        failures.append(f'missing include: {error}')
    floor = read('code/game/turfs/floor_attackby.dm')
    mining = block(floor, '/turf/proc/mining_proc(')
    call = mining.find('mining_flint_nodules(H, area_above)')
    if call < 0:
        failures.append('mining_proc must roll flint nodules')
    elif call > mining.find('if (prob(12))'):
        failures.append('the flint roll must come before the ore rolls so every mined wall gets it')
    if '#define FLINT_NODULE_CHANCE 20' not in flint or '#define FLINT_NODULE_CHANCE_SANDY 5' not in flint:
        failures.append('flint nodule chances changed; update docs/flint-mining.md with them')
    harvest = block(flint, '/mob/living/simple_animal/deer/harvest_products(')
    if '..()' not in harvest or '/obj/item/weapon/material/pickaxe/antler' not in harvest:
        failures.append('butchered deer must keep the normal products and add antler picks')
    antler = block(flint, '/obj/item/weapon/material/pickaxe/antler\n')
    if 'usespeed = 0.8' not in antler:
        failures.append('antler pick speed should sit between nothing and the bone pickaxe (0.8)')
    knap = block(flint, '/obj/item/weapon/flint/attackby(')
    if 'return' not in knap or not knap.rstrip().endswith('..()'):
        failures.append('flint attackby must fall back to the whetstone repair behavior')
    failures.extend(fletching_checks(read('code/modules/projectiles/_ammo_casing.dm')))
    if '/obj/item/stack/arrowhead/flint = "flint"' not in read('code/game/objects/structures/blacksmithing/dedicated_workbenches.dm'):
        failures.append('the fletching bench must accept knapped flint arrowheads')
    spade = '/obj/item/weapon/material/shovel/spade/wood'
    research = read('code/modules/research_tree/research_node.dm')
    if f'"{spade}" = "basic_tools"' not in research:
        failures.append('wooden spade must be mapped to Basic Toolmaking (age 0)')
    row = f'RECIPE: /material/wood/,wooden spade,{spade},3,60,0,1,tools,0,0,0,8,wood'
    for path in sorted(glob.glob(str(ROOT / 'config/crafting/material_recipes_*.txt'))):
        text = Path(path).read_text(encoding='utf-8')
        if 'RECIPE: /material/wood/,hammer,' in text and row not in text:
            failures.append(f'{Path(path).name}: missing the wooden spade recipe')
    striker = 'RECIPE: /material/steel/,fire striker,/obj/item/weapon/flame/lighter/striker,1,40,0,1,tools,0,0,0,8,null'
    for path in sorted(glob.glob(str(ROOT / 'config/crafting/material_recipes_*.txt'))):
        text = Path(path).read_text(encoding='utf-8')
        if 'RECIPE: /material/steel/,zippo lighter,' in text and striker not in text:
            failures.append(f'{Path(path).name}: missing the fire striker recipe')
    if '"/obj/item/weapon/flame/lighter/striker" = "iron_tools"' not in research:
        failures.append('fire striker must be mapped to Iron Tools')
    if 'var/obj/item/weapon/flint/F = user.get_inactive_hand()' not in block(flint, '/obj/item/weapon/flame/lighter/striker/attack_self('):
        failures.append('the striker must need a flint in the other hand')
    if 'max_fuel = 0' not in block(flint, '/obj/item/weapon/flame/lighter/striker\n'):
        failures.append('the striker burns no lighter fluid (max_fuel = 0)')
    fuel = read('code/modules/1713/light_fuel.dm')
    if 'if (max_fuel > 0 && istype(W, /obj/item/weapon/reagent_containers)' not in fuel or 'if (max_fuel <= 0)' not in block(fuel, '/obj/item/weapon/flame/lighter/examine('):
        failures.append('lighter fluid examine and refill must skip fluid-less strikers')
    if 'gunflint_aim_check = TRUE' not in block(flint, '/obj/item/weapon/gun/projectile/flintlock/can_hit('):
        failures.append('aiming checks must not roll gunflint misfires')
    dme_text = read('civ13.dme')
    if dme_text.index('flintlock.dm"') > dme_text.index('flint_mining.dm"'):
        failures.append('flint_mining.dm must be included after flintlock.dm')
    icons = (ROOT / 'icons/obj/flint_mining.dmi').read_bytes()
    for state in ('antler_pick', 'wooden_spade', 'flint_arrowheads', 'flint_spearhead', 'striker'):
        if f'icon_state = "{state}"' not in flint + read('code/modules/1713/tools.dm'):
            failures.append(f'{state} is not used')
    if not icons.startswith(b'\x89PNG'):
        failures.append('flint_mining.dmi is not a PNG')
    return failures


def native(byond_bin):
    flint = read(FLINT)
    defines = ('FLINT_NODULE_CHANCE 20', 'FLINT_NODULE_CHANCE_SANDY 5', 'GUNFLINT_SHOTS_MIN 25',
               'GUNFLINT_SHOTS_MAX 40', 'GUNFLINT_WORN_MISFIRE 50')
    gun = '/obj/item/weapon/gun/projectile/flintlock'
    procs = '\n'.join(['#define ' + name for name in defines] + [
        block(flint, '/turf/proc/mining_flint_nodules('),
        block(flint, '/mob/living/simple_animal/deer/proc/antler_count()'),
        block(flint, '// half the time until a new sharpened flint is fitted.\n' + gun + '\n'),
        block(flint, gun + '/proc/gunflint_left()'),
        block(flint, gun + '/special_check('),
        block(flint, gun + '/can_hit('),
        block(flint, gun + '/handle_post_fire()'),
    ])
    # Sound resources are files the fixture does not ship; pass them as text.
    procs = re.sub(r"'(sound/[^']+)'", r'"\1"', procs)
    for name in defines:
        if f'#define {name}' not in flint:
            return ['probe constants are out of date']
    win = os.name == 'nt'
    compiler = byond_bin / ('dm.exe' if win else 'DreamMaker')
    daemon = byond_bin / ('dd.exe' if win else 'DreamDaemon')
    with tempfile.TemporaryDirectory(prefix='civ13-flint-mining-') as directory:
        temp = Path(directory)
        (temp / 'probe.dm').write_text((HERE / 'probe.dm').read_text(encoding='utf-8'), encoding='utf-8')
        (temp / 'flint.dm').write_text(procs + '\n', encoding='utf-8')
        (temp / 'probe.dme').write_text('#include "probe.dm"\n#include "flint.dm"\n', encoding='utf-8')
        built = subprocess.run([str(compiler), 'probe.dme'], cwd=temp, capture_output=True, text=True, timeout=120)
        print(built.stdout, end='')
        if built.returncode or '0 errors' not in built.stdout:
            return ['fixture compile failed: ' + built.stdout + built.stderr]
        subprocess.run([str(daemon), 'probe.dmb', '-invisible', '-trusted', '-log', 'runtime.log'],
                       cwd=temp, capture_output=True, timeout=120)
        log = (temp / 'runtime.log').read_text(encoding='utf-8', errors='replace')
        print(log, end='')
        failures = re.findall(r'^FAIL (.+)$', log, re.M)
        if re.search(r'runtime error', log, re.I):
            failures.append('runtime error in probe')
        if 'PASS flint mining probe' not in log:
            failures.append('probe did not pass')
        return failures


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', type=Path)
    args = parser.parse_args()
    failures = source_checks()
    if args.byond_bin:
        failures += native(args.byond_bin)
    for failure in failures:
        print('FAIL', failure)
    if failures:
        return 1
    print('PASS flint mining' + (' (source + native)' if args.byond_bin else ' (source)'))
    return 0


if __name__ == '__main__':
    sys.exit(main())
