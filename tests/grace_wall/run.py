"""Native equivalence check for the shared faction grace wall.

Compiles the live check_faction_grace_wall helper and every map's current
check_caribbean_block body next to its frozen pre-refactor body
(legacy_bodies.json), then runs both in DreamDaemon over every invisible-wall
area, faction and grace-timer combination and fails on any difference.

    python3 tests/grace_wall/run.py --byond-bin <BYOND bin dir>
    python3 tests/grace_wall/run.py --byond-bin <dir> --negative-control

The negative control swaps the two wall factions in the live helper and must
report mismatches. Stubs replace the map, mob, turf and get_area; nothing else
from the game is compiled.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
MAPS = ROOT / 'code/game/objects/map_metadata'
HELPER = '/obj/map_metadata/proc/check_faction_grace_wall('
HEADER = '/check_caribbean_block(var/mob/living/human/H, var/turf/T)'


def proc_block(source, header_prefix):
    match = re.search(r'(?m)^' + re.escape(header_prefix) + r'.*\n((?:\t.*\n|[ \t]*\n)*)', source + '\n')
    if not match:
        raise SystemExit(f'missing {header_prefix}')
    return match.group(0).rstrip('\n') + '\n'


def current_body(entry):
    source = (ROOT / entry['file']).read_text(encoding='utf-8')
    block = proc_block(source, entry['type'] + HEADER)
    return block.split('\n', 1)[1].rstrip('\n')


def wall_areas():
    source = (ROOT / 'code/game/area/caribbean.dm').read_text(encoding='utf-8')
    return sorted(set(re.findall(r'(?m)^(/area/caribbean/no_mans_land/invisible_wall[\w/]*)\s*$', source)))


def build(negative_control):
    helper = proc_block((MAPS / '_map_metadata.dm').read_text(encoding='utf-8'), HELPER)
    if negative_control:
        before = 'return H.faction_text == one_faction'
        if before not in helper:
            raise SystemExit('negative-control anchor missing')
        helper = helper.replace(before, 'return H.faction_text == two_faction', 1)
    entries = json.loads((HERE / 'legacy_bodies.json').read_text(encoding='utf-8'))
    areas = wall_areas() + ['/area/caribbean/grace_probe_outside']
    out = ['/world/loop_checks = 0', '/world/maxx = 1', '/world/maxy = 1', '/world/maxz = 1', '/area', '/turf/var/area/probe_area',
           '/area/caribbean/grace_probe_outside']
    out += sorted({a for a in areas})
    out += ['/proc/get_area(atom/A)', '\treturn A:probe_area',
            '/mob/living/human/var/faction_text',
            '/obj/map_metadata/var/faction1 = "F1"', '/obj/map_metadata/var/faction2 = "F2"',
            '/obj/map_metadata/var/g1 = FALSE', '/obj/map_metadata/var/g2 = FALSE',
            '/obj/map_metadata/proc/faction1_can_cross_blocks()', '\treturn g1',
            '/obj/map_metadata/proc/faction2_can_cross_blocks()', '\treturn g2',
            '/obj/map_metadata/proc/check_caribbean_block(var/mob/living/human/H, var/turf/T)',
            '\treturn FALSE', helper]
    pairs = []
    for i, entry in enumerate(entries):
        out += [f'/obj/map_metadata/live_{i}/check_caribbean_block(var/mob/living/human/H, var/turf/T)',
                current_body(entry),
                f'/obj/map_metadata/legacy_{i}/check_caribbean_block(var/mob/living/human/H, var/turf/T)',
                entry['old']]
        pairs.append(i)
    out += ['/world/New()', '\tvar/turf/T = locate(1, 1, 1)', '\tvar/mob/living/human/H = new',
            '\tvar/checks = 0', '\tvar/bad = 0',
            '\tvar/list/areas = list(' + ', '.join(areas) + ')',
            '\tvar/list/types = list(' + ', '.join(f'"{i}"' for i in pairs) + ')',
            '\tvar/list/names = list(' + ', '.join(json.dumps(e['type']) for e in entries) + ')',
            '\tfor (var/n = 1 to types.len)',
            '\t\tvar/live_type = text2path("/obj/map_metadata/live_[types[n]]")',
            '\t\tvar/old_type = text2path("/obj/map_metadata/legacy_[types[n]]")',
            '\t\tvar/obj/map_metadata/live = new live_type',
            '\t\tvar/obj/map_metadata/old = new old_type',
            '\t\tfor (var/area_type in areas)',
            '\t\t\tT.probe_area = new area_type',
            '\t\t\tfor (var/f in list("F1", "F2", "CIV", null))',
            '\t\t\t\tH.faction_text = f',
            '\t\t\t\tfor (var/g in 0 to 3)',
            '\t\t\t\t\tlive.g1 = g & 1; old.g1 = g & 1',
            '\t\t\t\t\tlive.g2 = g & 2; old.g2 = g & 2',
            '\t\t\t\t\tchecks++',
            '\t\t\t\t\tvar/a = live.check_caribbean_block(H, T)',
            '\t\t\t\t\tvar/b = old.check_caribbean_block(H, T)',
            '\t\t\t\t\tif (!a != !b)',
            '\t\t\t\t\t\tbad++',
            '\t\t\t\t\t\tif (bad <= 20)',
            '\t\t\t\t\t\t\tworld.log << "MISMATCH [names[n]] [area_type] [f] [g] live=[a] old=[b]"',
            '\t\t\tvar/probe = T.probe_area',
            '\t\t\tT.probe_area = null',
            '\t\t\tdel(probe)',
            '\t\tif (live.check_caribbean_block(null, T) || old.check_caribbean_block(null, T))',
            '\t\t\tbad++',
            '\t\t\tworld.log << "MISMATCH [names[n]] null mob"',
            '\tworld.log << "RESULT checks=[checks] mismatches=[bad] maps=[types.len]"',
            '\tdel(world)']
    return '\n'.join(out) + '\n', len(entries)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--negative-control', action='store_true')
    args = parser.parse_args()
    source, count = build(args.negative_control)
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        (tmp / 'probe.dm').write_text(source, encoding='utf-8')
        (tmp / 'probe.dme').write_text('#define FALSE 0\n#define TRUE 1\n#include "probe.dm"\n', encoding='utf-8')
        compiled = subprocess.run([str(args.byond_bin / 'DreamMaker'), 'probe.dme'], cwd=tmp,
                                  capture_output=True, text=True)
        print(compiled.stdout.strip().splitlines()[-1] if compiled.stdout.strip() else compiled.stderr)
        if compiled.returncode:
            print(compiled.stdout + compiled.stderr)
            return 1
        ran = subprocess.run([str(args.byond_bin / 'DreamDaemon'), 'probe.dmb', '-trusted', '-invisible'],
                             cwd=tmp, capture_output=True, text=True, timeout=300)
    log = ran.stdout + ran.stderr
    lines = [line for line in log.splitlines() if 'MISMATCH' in line or 'RESULT' in line]
    print('\n'.join(lines))
    result = re.search(r'RESULT checks=(\d+) mismatches=(\d+) maps=(\d+)', log)
    if not result or int(result.group(3)) != count or int(result.group(1)) == 0:
        print(log)
        return 1
    mismatches = int(result.group(2))
    if args.negative_control:
        return 0 if mismatches else 1
    return 1 if mismatches else 0


if __name__ == '__main__':
    sys.exit(main())
