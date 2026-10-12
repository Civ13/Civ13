"""Scale-aware original mall geometry using native Civ13 assets."""
import argparse
from pathlib import Path
import re
from build_map import build as build_homes

SIZE = 256
ROAD_ENTRIES = ((10, 12), (150, 148))
FOOT_ENTRIES = ((12, 148), (148, 12), (12, 80), (148, 80))
STAIRS = ((30, 30), (130, 30), (30, 94), (130, 94), (54, 126), (106, 126))
HIGHWAY_EXITS = ((10, 8), (150, 152))


def coordinate(value, size=SIZE):
    return 1 + round((value-1) * (size-1) / 159)


def build(size=SIZE):
    if not 160 <= size <= 512:
        raise ValueError('Supported square sizes: 160..512')
    c = lambda value: coordinate(value, size)
    definitions = {}
    wall = '/obj/covers/generic_wall'
    concrete = '/turf/floor/plating/concrete'
    dark = '/turf/floor/plating/dark'
    areas = {1: '/area/extraction_mall/parking', 4: '/area/extraction_mall/retail', 5: '/area/extraction_mall/gallery'}

    def tile(value):
        if value not in definitions:
            i = len(definitions)
            if i >= 676:
                raise ValueError('Two-character tile dictionary exhausted')
            definitions[value] = chr(97 + i // 26) + chr(97 + i % 26)
        return definitions[value]

    def atoms(z, objects=(), floor=concrete):
        return '(' + ','.join((*objects, floor, areas[z])) + ')'

    layers = {z: [[tile(atoms(z, () if z == 1 else (wall,))) for _ in range(size)] for _ in range(size)] for z in areas}

    def raw(z, x, y, *objects, floor=concrete):
        layers[z][y-1][x-1] = tile(atoms(z, objects, floor))

    def put(z, x, y, *objects, floor=concrete):
        raw(z, c(x), c(y), *objects, floor=floor)

    def rect(z, x1, y1, x2, y2, floor=concrete, objects=()):
        for y in range(c(y1), c(y2)+1):
            for x in range(c(x1), c(x2)+1):
                raw(z, x, y, *objects, floor=floor)

    for box in ((4, 4, 156, 18), (4, 142, 156, 156), (4, 4, 18, 156), (142, 4, 156, 156)):
        rect(1, *box, dark)
    for n in range(1, size+1):
        for x, y in ((n, 1), (n, size), (1, n), (size, n)):
            raw(1, x, y, wall)
    for x in (44, 66, 94, 116):
        for y in (44, 66, 88, 110):
            rect(1, x, y, x+1, y+1, objects=(wall,))
            rect(1, x-8, y+4, x-3, y+7, dark)
    for y in (24, 136):
        rect(1, 20, y, 140, y+3, dark)

    loot_id = 0

    def store(z, box, name, pool, palette, shelves=True):
        nonlocal loot_id
        left, bottom, right, top = box
        rect(z, left, bottom, right, top, palette)
        middle, middle_y = (left+right)//2, (bottom+top)//2
        for x in range(c(left), c(right)+1):
            for y in (c(bottom), c(top)):
                if not c(middle-2) <= x <= c(middle+2):
                    raw(z, x, y, wall, floor=palette)
        for y in range(c(bottom), c(top)+1):
            for x in (c(left), c(right)):
                if not c(middle_y-2) <= y <= c(middle_y+2):
                    raw(z, x, y, wall, floor=palette)
        put(z, middle, bottom+2, f'/obj/effect/extraction_mall_sign{{name = "{name}"}}', floor=palette)
        if shelves:
            for y in range(c(bottom+6), c(top-4), 6):
                for x in range(c(left+5), c(right-4)):
                    if abs(x-c(middle)) < 4 or x % 12 in (0, 1, 2):
                        continue
                    raw(z, x, y, '/obj/structure/table/wood', floor=palette)
        for x, y in ((left+8, bottom+6), (right-8, top-6)):
            loot_id += 1
            put(z, x, y, f'/obj/effect/extraction_loot_marker{{container_id = {loot_id}; pool_kind = "{pool}"}}', floor=palette)
        put(z, middle, middle_y, '/obj/effect/extraction_npc_marker', floor=palette)

    for z in (4, 5):
        rect(z, 24, 24, 136, 136)
        for side in ((24, 24, 136, 24), (24, 136, 136, 136), (24, 24, 24, 136), (136, 24, 136, 136)):
            rect(z, *side, objects=(wall,))
        rect(z, 76, 26, 84, 134, dark)
        rect(z, 26, 76, 134, 84, dark)
        if z == 4:
            store(z, (26, 26, 68, 72), 'Hearth furnishings', 'supplies', '/turf/floor/wood/fancywood')
            store(z, (92, 26, 134, 72), 'Foundry hardware', 'workshop', dark)
            store(z, (26, 108, 134, 134), 'Harvest hypermarket', 'supplies', '/turf/floor/wood')
            for i, box in enumerate([(26+22*i, 88, 44+22*i, 104) for i in range(5)]):
                store(z, box, ('Book exchange', 'Travel goods', 'Transit security', 'Radio repair', 'Field clinic')[i], ('supplies', 'supplies', 'armory', 'workshop', 'supplies')[i], concrete, shelves=False)
        else:
            for i, box in enumerate([(26+22*i, y, 44+22*i, y+18) for y in (26, 50, 88, 112) for i in range(5)]):
                store(z, box, ('Electronics', 'Pharmacy', 'Outfitter', 'Cafe', 'Service office')[i % 5] + f' {i//5+1}', ('workshop', 'supplies', 'armory', 'supplies', 'ammunition')[i % 5], '/turf/floor/wood' if i % 5 == 3 else concrete, shelves=False)
                if i % 5 == 3:
                    left, bottom, _, _ = box
                    for dx in (5, 13):
                        put(z, left+dx, bottom+6, '/obj/structure/table/wood')
                        put(z, left+dx, bottom+8, '/obj/structure/bed/chair')
        label = 'retail' if z == 4 else 'upper gallery'
        put(z, 80, 80, f'/obj/effect/extraction_mall_sign{{name = "Central concourse - {label}"}}', floor=dark)
        for x in (70, 88):
            rect(z, x, 26, x+2, 134)
        for y in (74, 106):
            rect(z, 26, y, 134, y+1)

    for x, y in STAIRS:
        for z in areas:
            for yy in range(c(y)-2, c(y)+3):
                for xx in range(c(x)-2, c(x)+5):
                    raw(z, xx, yy)
        for source, target, offset in ((1, 4, 0), (4, 1, 0), (4, 5, 2), (5, 4, 2)):
            label = {1: 'parking', 4: 'retail', 5: 'upper gallery'}[target]
            raw(source, c(x)+offset, c(y), f'/obj/structure/extraction_mall_stairs{{destination_z = {target}; name = "Stairs - {label}"}}')
    for x, y in ROAD_ENTRIES:
        put(1, x, y, '/obj/effect/extraction_raid_marker/road', floor=dark)
    for x, y in FOOT_ENTRIES:
        put(1, x, y, '/obj/effect/extraction_raid_marker', floor=dark)
    for (x, y), name in zip(HIGHWAY_EXITS, ('West highway', 'East highway')):
        put(1, x, y, f'/obj/effect/extraction_exit/highway{{name = "{name} - foot or car"}}', floor=dark)
    for x, y, name in ((80, 150, 'Rail embankment'), (150, 80, 'Service footgate')):
        put(1, x, y, f'/obj/effect/extraction_exit/mall_foot{{name = "{name} - foot only"}}', floor=dark)
    put(1, 8, 80, '/obj/effect/extraction_exit/manhole{name = "Drain access - no backpacks or cars"}', floor=dark)
    put(1, 2, 2, '/obj/map_metadata/extraction_survival/mall')
    put(1, 3, 3, '/obj/effect/landmark{name = "JoinLateExtraction"}')
    put(1, 80, 12, '/obj/effect/extraction_drop_box', floor=dark)
    homes = build_homes()
    old_defs = dict(re.findall(r'^"([a-z]{2})" = (.*)$', homes, re.M))
    for z, body in re.findall(r'\(1,1,(\d+)\) = \{"\n(.*?)\n"\}', homes, re.S):
        if int(z) not in (2, 3):
            continue
        protected_area = '/area/extraction_houses' if int(z) == 2 else '/area/extraction_hub'
        layers[int(z)] = [[tile(f'({wall},{dark},{protected_area})') for _ in range(size)] for _ in range(size)]
        for y, row in enumerate(reversed(body.splitlines())):
            for x in range(96):
                layers[int(z)][y][x] = tile(old_defs[row[x*2:x*2+2]])
    result = [f'"{key}" = {value}' for value, key in definitions.items()]
    for z in sorted(layers):
        result += ['', f'(1,1,{z}) = {{"', *(''.join(row) for row in reversed(layers[z])), '"}']
    return '\n'.join(result) + '\n'


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--size', type=int, default=SIZE)
    args = parser.parse_args()
    (Path(__file__).resolve().parents[2] / 'maps/extraction/interchange_mall.dmm').write_text(build(args.size), encoding='utf-8')
