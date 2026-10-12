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
# Keep the original shop IDs 1..56 and keyed caches 61/62 stable. Parking
# sources use the remaining journal IDs, with the same finite first-access
# contract as shop containers. Coordinates use the normalized 160-tile plan.
PARKING_LOOT = (
    (57, 27, 119, 'workshop', 'Maintenance salvage bin'),
    (58, 41, 125, 'supplies', 'Staff supply chest'),
    (59, 115, 126, 'workshop', 'Dispatch workshop salvage'),
    (60, 130, 116, 'supplies', 'Recovered delivery supplies'),
    (63, 32, 25, 'ammunition', 'Parking security ammunition case'),
    (64, 121, 36, 'workshop', 'Utility repair supplies'),
)


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
    fixtures = {
        wall: wall + '/extraction_mall',
        '/obj/structure/table/wood': '/obj/structure/table/extraction_mall',
        '/obj/structure/table/rack/shelf/store': '/obj/structure/table/extraction_mall/shelf',
        '/obj/structure/table/rack/coatrack': '/obj/structure/table/extraction_mall/coatrack',
        '/obj/structure/table/nightstand': '/obj/structure/table/extraction_mall/nightstand',
        **{f'/obj/structure/bed/{kind}': f'/obj/structure/bed/{kind}/extraction_mall'
           for kind in ('wood', 'fieldbed', 'sofa', 'chair')},
        **{f'/obj/structure/{kind}': f'/obj/structure/{kind}/extraction_mall'
           for kind in ('closet', 'closet/fridge', 'oven', 'sink', 'toilet')},
    }

    def tile(value):
        if value not in definitions:
            i = len(definitions)
            if i >= 676:
                raise ValueError('Two-character tile dictionary exhausted')
            definitions[value] = chr(97 + i // 26) + chr(97 + i % 26)
        return definitions[value]

    def atoms(z, objects=(), floor=concrete):
        fixed = []
        for obj in objects:
            path, separator, variables = obj.partition('{')
            fixed.append(fixtures.get(path, path) + (separator + variables if separator else ''))
        return '(' + ','.join((*fixed, floor, areas[z])) + ')'

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

    # All furnishings below use fixed mall variants of existing native sprites.
    # Racks have fixed sprites, tables connect to neighbours, bed/sofa/chair
    # constructors resolve their material. Ovens and plumbing are disused, and
    # closets/fridges create no stock. No equipped lockers, vending machines,
    # workbench factories or loose item spawners are used as decoration.
    shelf = '/obj/structure/table/rack/shelf/store'
    table = '/obj/structure/table/wood'
    chair = '/obj/structure/bed/chair'
    cupboard = '/obj/structure/closet'

    def sign(z, x, y, name, floor=concrete):
        put(z, x, y, f'/obj/effect/extraction_mall_sign{{name = "{name}"}}', floor=floor)

    def partition(z, x1, y1, x2, y2, door, floor=concrete):
        rect(z, x1, y1, x2, y2, floor, (wall,))
        dx, dy = door
        if y1 == y2:
            rect(z, dx-1, dy, dx+1, dy, floor)
        else:
            rect(z, dx, dy-1, dx, dy+1, floor)

    def room(z, box, name, floor=concrete):
        left, bottom, right, top = box
        rect(z, *box, floor)
        middle = (left+right)//2
        partition(z, left, bottom, right, bottom, (middle, bottom), floor)
        rect(z, left, top, right, top, floor, (wall,))
        rect(z, left, bottom+1, left, top-1, floor, (wall,))
        rect(z, right, bottom+1, right, top-1, floor, (wall,))
        sign(z, middle, bottom+1, name, floor)

    def desk(z, x, y, floor=concrete):
        rect(z, x, y, x+2, y, floor, (table,))
        put(z, x+1, y-2, chair+'{dir = 1}', floor=floor)

    def dining(z, x, y, floor=concrete):
        rect(z, x, y, x+1, y+1, floor, (table,))
        for dx, dy, direction in ((-1, 0, 4), (2, 1, 8), (0, -1, 1), (1, 2, 2)):
            put(z, x+dx, y+dy, chair+f'{{dir = {direction}}}', floor=floor)

    def racks(z, box, floor=concrete, spacing=5):
        left, bottom, right, top = box
        # Long runs are broken into islands with cross-aisles and end clearance.
        for y in range(bottom, top+1, spacing):
            for x in range(left, right+1, 10):
                rect(z, x, y, min(x+6, right), y, floor, (shelf,))

    def washrooms(z, box, floor=concrete):
        left, bottom, right, top = box
        room(z, box, 'Washrooms - cubicles and wash counter', floor)
        for x in range(left+2, right-2, 4):
            put(z, x, top-2, '/obj/structure/toilet', floor=floor)
            if x+2 < right:
                rect(z, x+2, top-3, x+2, top-1, floor, (wall,))
        # Disused plumbing keeps the native sprite without renewable water or
        # mosquito lifecycle. All fixtures remain outside the loot economy.
        for x in range(left+2, right-2, 5):
            put(z, x, bottom+2, '/obj/structure/sink', floor=floor)

    def damage(z, x, y, floor=concrete):
        for dx, dy in ((0, 0), (1, 0), (0, 1), (2, 1)):
            put(z, x+dx, y+dy, '/obj/effect/extraction_mall_rubble',
                floor='/turf/floor/wood_broken' if 'wood' in floor else '/turf/floor/gravel/dust')
        put(z, x+3, y, '/obj/effect/decal/rubbish{random = 0; icon_state = "trash_7"}', floor=floor)
        put(z, x, y+2, '/obj/effect/decal/rubbish{random = 0; icon_state = "trash_12"}', floor=floor)

    loot_id = 0

    def store(z, box, name, pool, palette, profile):
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
        if profile == 'furniture':
            # A sequence of furnished apartment-like display suites, with a
            # shared spine, not a warehouse of interchangeable shelf rows.
            for x in (left+3, left+17, left+31):
                for y in (bottom+5, bottom+20):
                    room(z, (x, y, x+9, y+12), 'Display suite', palette)
                    put(z, x+2, y+9, '/obj/structure/bed/wood', floor=palette)
                    put(z, x+4, y+9, '/obj/structure/table/nightstand', floor=palette)
                    partition(z, x+5, y+7, x+5, y+11, (x+5, y+8), palette)
                    put(z, x+7, y+10, cupboard, floor=palette)
                    rect(z, x+7, y+8, x+8, y+8, palette, (table,))
                    rect(z, x+2, y+3, x+4, y+3, palette, ('/obj/structure/bed/sofa',))
                    dining(z, x+6, y+5, palette)
            room(z, (left+2, top-9, left+15, top-1), 'Design consultation office', palette)
            desk(z, left+4, top-4, palette)
            room(z, (left+18, top-9, right-2, top-1), 'Furniture receiving and flat-pack storage', palette)
            racks(z, (left+20, top-6, right-4, top-4), palette)
        elif profile == 'hardware':
            racks(z, (left+3, bottom+7, right-3, top-15), palette, 6)
            for x in (left+4, left+14, left+24):
                rect(z, x, bottom+3, x+5, bottom+3, palette, (table,))
                put(z, x+5, bottom+2, chair, floor=palette)
            room(z, (left+2, top-12, left+16, top-1), 'Tool repair and service counter', palette)
            rect(z, left+4, top-9, left+13, top-9, palette, (table,))
            desk(z, left+5, top-4, palette)
            room(z, (left+19, top-12, right-2, top-1), 'Hardware stockroom and dispatch', palette)
            racks(z, (left+21, top-8, right-4, top-3), palette)
            # Keyed hardware cage has a clear approach at the fixed coordinate.
            room(z, (108, 35, 120, 44), 'Reserved hardware cage', palette)
            rect(z, 110, 42, 118, 42, palette, (shelf,))
        elif profile == 'grocery':
            for x in range(left+4, right-5, 9):
                rect(z, x, bottom+3, x+4, bottom+3, palette, (table,))
                rect(z, x, bottom+5, x, bottom+7, palette, (table,))
            racks(z, (left+4, bottom+10, right-4, top-10), palette, 4)
            partition(z, left+1, top-8, right-1, top-8, (middle, top-8), palette)
            for x in range(left+20, right-15, 22):
                partition(z, x, top-7, x, top-1, (x, top-4), palette)
            for x in range(left+3, right-3, 10):
                put(z, x, top-2, '/obj/structure/closet/fridge', floor=palette)
                rect(z, x+2, top-4, x+5, top-4, palette, (shelf,))
            for x, label in ((left+10, 'Bakery preparation'), (left+32, 'Cold storage'),
                             (left+54, 'Receiving'), (left+76, 'Staff lockers'), (right-10, 'Accounts office')):
                sign(z, x, top-5, label, palette)
            desk(z, right-12, top-3, palette)
            put(z, left+3, top-5, '/obj/structure/oven', floor=palette)
        else:
            # Small shops have customer space, a side counter and a separate
            # rear stock / staff room. Profiles give them distinct floorplans.
            rear = top-5
            partition(z, left+1, rear, right-1, rear, (right-3, rear), palette)
            put(z, left+2, top-2, cupboard, floor=palette)
            rect(z, left+4, top-2, right-5, top-2, palette, (shelf,))
            if profile == 'cafe':
                rect(z, left+2, rear-2, right-5, rear-2, palette, (table,))
                put(z, left+4, top-3, '/obj/structure/oven', floor=palette)
                put(z, left+7, top-3, '/obj/structure/closet/fridge', floor=palette)
                dining(z, left+4, bottom+5, palette)
                dining(z, right-6, bottom+5, palette)
            elif profile == 'office':
                for x in (left+3, right-6):
                    desk(z, x, bottom+6, palette)
                    put(z, x+1, bottom+10, cupboard, floor=palette)
                rect(z, left+3, rear-1, left+6, rear-1, palette, ('/obj/structure/bed/sofa',))
            elif profile == 'fashion':
                for x in (left+3, left+8):
                    rect(z, x, bottom+4, x, bottom+9, palette, ('/obj/structure/table/rack/coatrack',))
                room(z, (right-6, bottom+3, right-1, bottom+10), 'Fitting rooms', palette)
                put(z, right-3, bottom+8, chair, floor=palette)
            elif profile == 'clinic':
                partition(z, middle, bottom+3, middle, rear-1, (middle, bottom+5), palette)
                for x in (left+3, middle+3):
                    put(z, x, bottom+8, '/obj/structure/bed/fieldbed', floor=palette)
                    put(z, x+2, bottom+8, '/obj/structure/table/nightstand', floor=palette)
                desk(z, left+2, bottom+3, palette)
            else:
                racks(z, (left+3, bottom+4, right-4, rear-3), palette, 4)
                rect(z, left+2, rear-1, left+6, rear-1, palette, (table,))
                put(z, left+4, rear-2, chair, floor=palette)
        damage(z, left+2, bottom+2, palette)
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
            store(z, (26, 26, 68, 72), 'Hearth furnishings', 'supplies', '/turf/floor/wood/fancywood', 'furniture')
            store(z, (92, 26, 134, 72), 'Foundry hardware', 'workshop', dark, 'hardware')
            store(z, (26, 108, 134, 134), 'Harvest hypermarket', 'supplies', '/turf/floor/wood', 'grocery')
            for i, box in enumerate([(26+22*i, 88, 44+22*i, 104) for i in range(5)]):
                store(z, box, ('Book exchange', 'Travel goods', 'Transit security', 'Radio repair', 'Field clinic')[i], ('supplies', 'supplies', 'armory', 'workshop', 'supplies')[i], concrete, ('retail', 'fashion', 'office', 'retail', 'clinic')[i])
        else:
            for i, box in enumerate([(26+22*i, y, 44+22*i, y+18) for y in (26, 50, 88, 112) for i in range(5)]):
                names = ('Circuit repair', 'Apothecary', 'Winter outfitter', 'Coffee counter', 'Mall administration',
                         'Photo and optics', 'Optician clinic', 'Tailor and fitting', 'Noodle kitchen', 'Security operations',
                         'Music exchange', 'Dental aid station', 'Luggage and travel', 'Bakery cafe', 'Transit office',
                         'Sport and camping', 'First aid clinic', 'Shoe and leather', 'Canteen kitchen', 'Staff welfare')
                profiles = ('retail', 'clinic', 'fashion', 'cafe', 'office')
                store(z, box, names[i], ('workshop', 'supplies', 'armory', 'supplies', 'ammunition')[i % 5], '/turf/floor/wood' if i % 5 == 3 else concrete, profiles[i % 5])
        label = 'retail' if z == 4 else 'upper gallery'
        put(z, 80, 80, f'/obj/effect/extraction_mall_sign{{name = "Central concourse - {label}"}}', floor=dark)
        for x in (70, 88):
            rect(z, x, 26, x+2, 134)
        for y in (74, 106):
            rect(z, 26, y, 134, y+1)

        # Concourse islands stay clear of the central through routes. A food
        # court has shared seating near kitchens, rather than isolated cafes.
        for x in (36, 52, 104, 120):
            rect(z, x, 78, x+3, 78, dark, ('/obj/structure/bed/sofa',))
            rect(z, x, 82, x+3, 82, dark, ('/obj/structure/bed/sofa{dir = 1}',))
        if z == 5:
            for x in (32, 42, 54, 98, 110, 122):
                dining(z, x, 70, concrete)
            washrooms(z, (26, 136, 52, 146))
            washrooms(z, (108, 136, 134, 146))
            rect(z, 27, 135, 51, 137)
            rect(z, 109, 135, 133, 137)
            sign(z, 80, 72, 'Shared food court seating and upper shop directory')
        else:
            # Perimeter loading gallery connects receiving rooms with the
            # parking stairs. It makes the back-of-house route intentional.
            rect(z, 26, 136, 134, 143, dark)
            for x in (34, 62, 90, 118):
                rect(z, x, 138, x+7, 138, dark, (shelf,))
                damage(z, x, 140, dark)
            sign(z, 80, 140, 'Loading gallery - receiving and service stairs', dark)

    # Parking is organized into repeated bays, marked pedestrian crossings and
    # two clear circulation spines. Keep the entire highway ring unobstructed.
    for y in (40, 64, 88, 112):
        rect(1, 22, y-5, 138, y-1, dark)
        for x in range(24, 138, 7):
            rect(1, x, y, x, y+11, '/turf/floor/plating/road/whiteline')
            rect(1, x+1, y+11, x+6, y+11, '/turf/floor/plating/road/whiteline{dir = 4}')
        sign(1, 20, y+7, f'Parking row {(y-40)//24+1}', concrete)
    for x in (56, 80, 104):
        rect(1, x-2, 20, x+2, 140, dark)
    for y in (32, 56, 80, 104, 128):
        for x in range(25, 136, 4):
            rect(1, x, y, x+1, y+1, '/turf/floor/plating/white')
    room(1, (22, 106, 48, 132), 'Maintenance workshop and staff facilities')
    partition(1, 23, 121, 47, 121, (35, 121))
    partition(1, 36, 122, 36, 131, (36, 126))
    racks(1, (25, 111, 44, 118))
    desk(1, 25, 128)
    put(1, 40, 128, cupboard)
    put(1, 43, 128, cupboard)
    damage(1, 24, 108)
    room(1, (110, 112, 136, 136), 'Delivery dispatch and warehouse')
    partition(1, 111, 124, 135, 124, (123, 124))
    racks(1, (113, 128, 133, 133))
    desk(1, 114, 118)
    desk(1, 128, 118)
    damage(1, 111, 113)
    room(1, (22, 22, 42, 38), 'Parking security and ticket office')
    desk(1, 25, 27)
    desk(1, 35, 34)
    rect(1, 24, 34, 27, 34, concrete, ('/obj/structure/bed/sofa',))
    put(1, 39, 25, cupboard)
    damage(1, 23, 23)
    room(1, (116, 22, 138, 38), 'Generator service and utility store')
    racks(1, (119, 25, 134, 34))
    damage(1, 117, 23)

    # Post-war dressing stays off highway lanes and is applied before the clear
    # stair landing islands. No extra loot roots or free vehicle parts are added.
    for x, y in ((44, 44), (64, 44), (92, 44), (120, 44),
                 (30, 68), (44, 68), (64, 68), (92, 68), (120, 68),
                 (30, 92), (44, 92), (64, 92), (92, 92), (120, 92),
                 (64, 116), (92, 116)):
        put(1, x, y, '/obj/structure/props/car_wreck')
        for dx, dy in ((-2, 0), (4, 1), (1, 3)):
            put(1, x+dx, y+dy, '/obj/effect/extraction_mall_rubble', floor='/turf/floor/gravel/dust')
    for z in areas:
        for i, (x, y) in enumerate(((34, 78), (58, 82), (80, 42), (82, 96), (122, 78), (78, 128))):
            put(z, x, y, f'/obj/effect/decal/rubbish{{random = 0; icon_state = "trash_{1+i*2}"}}', floor=dark)

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
    # Clear interiors of Transit security and Foundry hardware. Add dictionary
    # entries only after importing protected home/hub grids, keeping their keys.
    for container_id, x, y, pool, name in PARKING_LOOT:
        put(1, x, y, f'/obj/effect/extraction_loot_marker{{container_id = {container_id}; pool_kind = "{pool}"; name = "{name}"}}')
    put(4, 74, 100, '/obj/effect/extraction_loot_marker/keyed/mall_security{container_id = 61}')
    put(4, 113, 40, '/obj/effect/extraction_loot_marker/keyed/mall_hardware{container_id = 62}', floor=dark)
    result = [f'"{key}" = {value}' for value, key in definitions.items()]
    for z in sorted(layers):
        result += ['', f'(1,1,{z}) = {{"', *(''.join(row) for row in reversed(layers[z])), '"}']
    return '\n'.join(result) + '\n'


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--size', type=int, default=SIZE)
    args = parser.parse_args()
    (Path(__file__).resolve().parents[2] / 'maps/extraction/interchange_mall.dmm').write_text(build(args.size), encoding='utf-8')
