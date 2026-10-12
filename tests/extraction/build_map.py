"""Deterministic original district and fixed private-room pool, without assets."""
from pathlib import Path

SIZE = 96


def build():
    definitions = {}
    layers = []

    def tile(*atoms):
        value = '(' + ','.join(atoms) + ')'
        if value not in definitions:
            index = len(definitions)
            definitions[value] = chr(97 + index // 26) + chr(97 + index % 26)
        return definitions[value]

    floor = '/turf/floor/plating/dark'
    district = '/area/extraction_district'
    wall = '/obj/covers/generic_wall'
    raid = [[tile(floor, district) for _ in range(SIZE)] for _ in range(SIZE)]

    def put(x, y, *objects):
        raid[y-1][x-1] = tile(*objects, floor, district)

    # Boundary and separated warehouses, with four doors each and wide streets.
    for n in range(1, SIZE + 1):
        for x, y in ((n, 1), (n, SIZE), (1, n), (SIZE, n)):
            put(x, y, wall)
    for left in (18, 42, 66):
        for bottom in (18, 42, 66):
            for n in range(17):
                if n == 8:
                    continue
                for x, y in ((left+n, bottom), (left+n, bottom+16),
                             (left, bottom+n), (left+16, bottom+n)):
                    put(x, y, wall)
            put(left+4, bottom+4, '/obj/effect/extraction_loot_marker', '/obj/structure/shelf/palette')
            put(left+12, bottom+12, '/obj/effect/extraction_loot_marker', '/obj/structure/props/barrel')
            put(left+8, bottom+8, '/obj/effect/extraction_npc_marker')
    for x, y in ((8, 8), (88, 8), (8, 88), (88, 88)):
        put(x, y, '/obj/effect/extraction_raid_marker')
    for x, y, kind in ((48, 5, ''), (48, 91, '/pmc'), (5, 48, '/scav'), (91, 48, '/manhole')):
        put(x, y, '/obj/effect/extraction_exit' + kind)
    put(2, 2, '/obj/map_metadata/extraction_survival')
    put(3, 3, '/obj/effect/landmark{name = "JoinLateExtraction"}')
    put(48, 10, '/obj/effect/extraction_drop_box')
    # One bounded, single-door room. The player must unlock, enter, close and lock.
    secure = '/area/extraction_lock_room'
    for y in range(43, 48):
        for x in range(7, 12):
            boundary = x in (7, 11) or y in (43, 47)
            raid[y-1][x-1] = tile(*([wall] if boundary else []), floor, secure)
    raid[42][8] = tile('/obj/structure/simple_door/key_door/extraction_room', floor, secure)
    raid[43][8] = tile('/obj/effect/extraction_exit/locked_room', floor, secure)
    put(12, 42, '/obj/item/weapon/key/extraction_room')
    layers.append(raid)

    houses = '/area/extraction_houses'
    private = '/turf/floor/plating/extraction_house'
    house = [[tile(wall, floor, houses) for _ in range(SIZE)] for _ in range(SIZE)]
    for room in range(16):
        cx, cy = 12 + (room % 4)*22, 12 + (room // 4)*22
        for y in range(cy-4, cy+5):
            for x in range(cx-4, cx+5):
                house[y-1][x-1] = tile(private, houses)
        house[cy-1][cx-1] = tile(f'/obj/effect/extraction_house_marker{{room = {room+1}}}', private, houses)
    layers.append(house)
    # Shared demilitarized concourse, physically separated from private storage.
    hub_area = '/area/extraction_hub'
    hub = [[tile(wall, floor, hub_area) for _ in range(SIZE)] for _ in range(SIZE)]
    for y in range(34, 63):
        for x in range(30, 67):
            hub[y-1][x-1] = tile(floor, hub_area)
    for x in (32, 64):
        for y in (38, 44, 50, 56):
            hub[y-1][x-1] = tile('/obj/structure/shelf/palette', floor, hub_area)
    hub[47][47] = tile('/obj/effect/extraction_hub_terminal', floor, hub_area)
    layers.append(hub)
    result = [f'"{key}" = {value}' for value, key in definitions.items()]
    for z, layer in enumerate(layers, 1):
        result += ['', f'(1,1,{z}) = {{"', *(''.join(row) for row in reversed(layer)), '"}']
    return '\n'.join(result) + '\n'


if __name__ == '__main__':
    path = Path(__file__).resolve().parents[2] / 'maps/extraction/industrial_district.dmm'
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(build(), encoding='utf-8')
