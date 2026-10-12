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
            number = ((left-18)//24)*3 + (bottom-18)//24
            put(left+4, bottom+4, f'/obj/effect/extraction_loot_marker{{container_id = {number*2+1}; pool_kind = "workshop"}}')
            kind = 'ammunition' if number % 2 else 'armory'
            put(left+12, bottom+12, f'/obj/effect/extraction_loot_marker{{container_id = {number*2+2}; pool_kind = "{kind}"}}')
            put(left+8, bottom+8, '/obj/effect/extraction_npc_marker')
            put(left+5, bottom+4, '/obj/structure/component_workbench')
            put(left+12, bottom+4, f'/obj/effect/extraction_loot_marker{{container_id = {19+number}; pool_kind = "supplies"}}')
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
        house[cy-1][cx] = tile(f'/obj/effect/extraction_secure_crate{{room = {room+1}}}', private, houses)
        house[cy+2][cx+2] = tile(f'/obj/structure/component_workbench/extraction_private{{room = {room+1}}}', private, houses)
    layers.append(house)
    # Shared demilitarized concourse, physically separated from private storage.
    hub_area = '/area/extraction_hub'
    hub = [[tile(wall, floor, hub_area) for _ in range(SIZE)] for _ in range(SIZE)]
    for y in range(28, 73):
        for x in range(22, 75):
            hub[y-1][x-1] = tile(floor, hub_area)
    # Lounge west, workshop reference east, operations north. Four-wide
    # passages preserve a clear central meeting square and return desk.
    for x in (38, 58):
        for y in range(28, 73):
            if y not in range(46, 50):
                hub[y-1][x-1] = tile(wall, floor, hub_area)
    for x in range(39, 58):
        if x not in range(46, 50):
            hub[59][x-1] = tile(wall, floor, hub_area)
    for x in (26, 32, 64, 70):
        for y in (36, 42, 54):
            hub[y-1][x-1] = tile('/obj/structure/bed/chair', floor, hub_area)
    hub[47][29] = tile('/obj/effect/extraction_hub_guide/lounge', floor, hub_area)
    hub[47][65] = tile('/obj/effect/extraction_hub_guide/workshop', floor, hub_area)
    hub[66][47] = tile('/obj/effect/extraction_hub_guide/operations', floor, hub_area)
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
