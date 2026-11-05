"""Generate maps/EFT/crossroads_mall.dmm: an original mall raid and loot test range.

The layout is authored here as code so the DMM stays reproducible. Coordinates
are one-based BYOND tiles; (1,1) is the bottom-left corner. Run with a verified
interpreter from the repository root:

    python3 -I -B tests/crossroads_mall/build.py

Do not hand-edit the generated map; change this file and regenerate.
"""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / 'maps' / 'EFT' / 'crossroads_mall.dmm'

WIDTH = 160
HEIGHT = 150

# Turfs
GRASS = '/turf/floor/grass'
DIRT = '/turf/floor/dirt'
ROAD = '/turf/floor/plating/road'
WHITE = '/turf/floor/plating/road/whiteline'
YELLOW = '/turf/floor/plating/road/yellowline_center'
CONCRETE = '/turf/floor/plating/concrete'
DARK = '/turf/floor/plating/dark'
MARBLE = '/turf/floor/plating/marble/tile'
TILED = '/turf/floor/plating/tiled'
TILED_DARK = '/turf/floor/plating/tiled/dark'
WOODTILE = '/turf/floor/plating/tiled/woodh'
WHITEFLOOR = '/turf/floor/plating/white'
BROKEN = '/turf/floor/broken_floor'
BORDER = '/turf/wall/indestructable'
WALL = '/turf/wall/cement'
PARTITION = '/turf/wall/tiles'
BLOCKS = '/turf/wall/concrete_blocks'

# Areas
OUTSIDE = '/area/caribbean'
INTERIOR = '/area/caribbean/crossroads_mall'
RANGE = '/area/caribbean/crossroads_mall/range'
GRACE = '/area/caribbean/no_mans_land/invisible_wall'
EXTRACTS = {
    'westbound': '/area/caribbean/extract/crossroads/westbound',
    'northbound': '/area/caribbean/extract/crossroads/northbound',
    'delivery': '/area/caribbean/extract/crossroads/delivery',
    'culvert': '/area/caribbean/extract/crossroads/culvert',
    'range': '/area/caribbean/extract/crossroads/range',
}

# Objects
STORE_DOOR = '/obj/structure/simple_door/key_door/anyone/doubledoor/steel/store_door'
HOUSE_DOOR = '/obj/structure/simple_door/key_door/anyone/singledoor/housedoor'
WINDOW = '/obj/structure/window_frame/metal'
GLASS = '/obj/structure/window/classic/metal'
SHELF = '/obj/structure/table/rack/shelf/store'
RACK = '/obj/structure/table/rack/shelf'
TABLE = '/obj/structure/table/modern/table'
COUNTER = '/obj/structure/table/modern'
CHAIR = '/obj/structure/bed/chair/office/light'
CRATE = '/obj/structure/closet/crate/empty'
LARGECRATE = '/obj/structure/largecrate'
PALLET = '/obj/structure/shelf/palette'
DUMPSTER = '/obj/structure/closet/crate/dumpster'
BARREL = '/obj/structure/props/barrel'
FUELTANK = '/obj/structure/props/fueltank'
JUNK = '/obj/structure/props/junk'
JERSEY = '/obj/structure/window/barrier/jersey'
CONCRETE_BARRIER = '/obj/structure/window/barrier/concrete'
CHAINLINK = '/obj/structure/grille/chainlinkfence'
CHAINLINK_DOOR = '/obj/structure/grille/chainlinkfence/door/opened'
IRONFENCE = '/obj/structure/grille/ironfence'
SHUTTER_OPEN = '/obj/structure/gate/blast/garage/open'
SHUTTER = '/obj/structure/gate/blast/garage'
CAR = '/obj/structure/props/car_wreck'
CAR_ALT = '/obj/structure/props/car_wreck/alt'
VAN = '/obj/structure/props/car_wreck/van'
VAN_ALT = '/obj/structure/props/car_wreck/van/alt'
TRUCK = '/obj/structure/props/car_wreck/truck'
CAR_VERT = '/obj/structure/props/car_wreck/vertical'
TREE = '/obj/random/plants/tree'
FILING = '/obj/structure/filingcabinet/filingcabinet'
SAFE = '/obj/structure/closet/safe'
OPTABLE = '/obj/structure/optable'
SERVER = '/obj/structure/props/server'
COMPUTER = '/obj/structure/props/computerprops/modern'
LANDMARK = '/obj/effect/landmark'
METADATA = '/obj/map_metadata/eft_factory/crossroads_mall'
PAD = '/obj/effect/crossroads_loot_pad'
SIGN = '/obj/structure/sign/crossroads'
SIGN_STORE = '/obj/structure/sign/crossroads/store'
SIGN_EXTRACT = '/obj/structure/sign/crossroads/extract'
SIGN_PHARMACY = '/obj/structure/sign/crossroads/pharmacy'
SIGN_HARDWARE = '/obj/structure/sign/crossroads/hardware'
SIGN_FOOD = '/obj/structure/sign/crossroads/food'
SIGN_SECURE = '/obj/structure/sign/crossroads/secure'
SIGN_WARNING = '/obj/structure/sign/crossroads/warning'
SIGN_RANGE = '/obj/structure/sign/crossroads/range'
MEDBAG = '/obj/item/weapon/storage/eft/medical'

KEYED_DOORS = {
    'security': '/obj/structure/simple_door/key_door/crossroads/security',
    'management': '/obj/structure/simple_door/key_door/crossroads/management',
    'cage': '/obj/structure/simple_door/key_door/crossroads/cage',
    'range': '/obj/structure/simple_door/key_door/crossroads/range',
    'test': '/obj/structure/simple_door/key_door/crossroads/test',
}
KEYS = {name: '/obj/item/weapon/key/modern/crossroads/' + name for name in KEYED_DOORS}

# Loot tables that get a labelled pad in the range. Every concrete /obj/random
# and lootdrop spawner in the source must appear here; the test enforces it.
LOOTDROP_TABLES = (
    ('guns', '/obj/effect/spawner/lootdrop/guns'),
    ('guns industrial', '/obj/effect/spawner/lootdrop/guns/industrial'),
    ('guns medieval', '/obj/effect/spawner/lootdrop/guns/medieval'),
    ('melee', '/obj/effect/spawner/lootdrop/melee'),
    ('melee medieval', '/obj/effect/spawner/lootdrop/melee/medieval'),
    ('melee clash', '/obj/effect/spawner/lootdrop/melee/medieval/clash'),
    ('ammo', '/obj/effect/spawner/lootdrop/ammo'),
    ('ammo industrial', '/obj/effect/spawner/lootdrop/ammo/industrial'),
    ('ammo medieval', '/obj/effect/spawner/lootdrop/ammo/medieval'),
    ('armor', '/obj/effect/spawner/lootdrop/armor'),
    ('armor industrial', '/obj/effect/spawner/lootdrop/armor/industrial'),
    ('armor medieval', '/obj/effect/spawner/lootdrop/armor/medieval'),
    ('accessories', '/obj/effect/spawner/lootdrop/accessories'),
    ('explosives', '/obj/effect/spawner/lootdrop/explosives'),
)
RANDOM_WEAPON_TABLES = (
    ('random ak', '/obj/random/gun/random_ak'),
    ('ak47', '/obj/random/gun/ak47'),
    ('ak74', '/obj/random/gun/ak74'),
    ('modern ak', '/obj/random/gun/ak_modern'),
    ('western gun', '/obj/random/gun/western_random'),
    ('german gun', '/obj/random/gun/german_random'),
    ('funny gun', '/obj/random/gun/funny_random'),
    ('ak47 magazine', '/obj/random/magazine/ak47'),
    ('ak74 magazine', '/obj/random/magazine/ak74'),
    ('western magazine', '/obj/random/magazine/western_random'),
    ('german magazine', '/obj/random/magazine/german'),
    ('random melee', '/obj/random/melee'),
    ('random armor', '/obj/random/armor'),
    ('random accessories', '/obj/random/accessories'),
)
RANDOM_SUPPORT_TABLES = (
    ('random explosives', '/obj/random/explosives'),
    ('bandages', '/obj/random/medical/bandage'),
    ('drugs', '/obj/random/medical/drugs'),
    ('medical bag', MEDBAG),
    ('barricade', '/obj/random/barricade/random'),
    ('tree', '/obj/random/plants/tree'),
    ('tree low chance', '/obj/random/plants/tree_lowchance'),
    ('snowy tree', '/obj/random/plants/tree_snow'),
    ('snowy tree low chance', '/obj/random/plants/tree_snow_lowchance'),
    ('AP mine', '/obj/random/mine/ap'),
    ('booby trap', '/obj/random/mine/booby'),
)
PAD_TABLES = LOOTDROP_TABLES + RANDOM_WEAPON_TABLES + RANDOM_SUPPORT_TABLES

# Walkability model for the offline route checks. Every /obj/structure blocks
# unless listed here; unkeyed doors, open gates, junk and signs are passable.
# Random spawners and trees block because their output may be dense.
PASSABLE_STRUCTURES = {JUNK, STORE_DOOR, HOUSE_DOOR, CHAINLINK_DOOR, SHUTTER_OPEN}
BLOCKING_PADS = {path for _, path in RANDOM_SUPPORT_TABLES if 'plants' in path or 'barricade' in path or 'mine' in path}


def blocks(path, keyed_open=False):
    base = path.split('{', 1)[0]
    if base in KEYED_DOORS.values():
        return not keyed_open
    if base.startswith('/obj/structure/sign'):
        return False
    if base.startswith('/obj/structure'):
        return base not in PASSABLE_STRUCTURES
    if base.startswith('/obj/random'):
        return True
    if base == PAD:
        return any(('"' + table + '"') in path for table in BLOCKING_PADS)
    return False
# Car wrecks occupy a footprint anchored at their bottom-left tile.
FOOTPRINTS = {CAR: (3, 2), CAR_ALT: (3, 2), VAN: (3, 2), VAN_ALT: (3, 2), TRUCK: (4, 2), CAR_VERT: (1, 3)}
DENSE_TURFS = (BORDER, WALL, PARTITION, BLOCKS)


class Grid:
    def __init__(self):
        self.turf = [[GRASS] * (WIDTH + 1) for _ in range(HEIGHT + 1)]
        self.area = [[OUTSIDE] * (WIDTH + 1) for _ in range(HEIGHT + 1)]
        self.objects = [[[] for _ in range(WIDTH + 1)] for _ in range(HEIGHT + 1)]

    def check(self, x, y):
        if not (1 <= x <= WIDTH and 1 <= y <= HEIGHT):
            raise ValueError(f'Out of bounds: {x},{y}')

    def fill(self, x1, y1, x2, y2, turf=None, area=None):
        for y in range(y1, y2 + 1):
            for x in range(x1, x2 + 1):
                self.check(x, y)
                if turf:
                    self.turf[y][x] = turf
                if area:
                    self.area[y][x] = area

    def box(self, x1, y1, x2, y2, turf):
        """Walls on the rectangle outline only."""
        for x in range(x1, x2 + 1):
            self.turf[y1][x] = turf
            self.turf[y2][x] = turf
        for y in range(y1, y2 + 1):
            self.turf[y][x1] = turf
            self.turf[y][x2] = turf

    def put(self, x, y, path, **variables):
        self.check(x, y)
        if variables:
            parts = []
            for key, value in variables.items():
                if isinstance(value, str):
                    value = '"' + value.replace('"', '') + '"'
                parts.append(f'{key} = {value}')
            path = path + '{' + '; '.join(parts) + '}'
        self.objects[y][x].append(path)

    def clear_objects(self, x, y):
        self.objects[y][x] = []

    def row(self, x1, x2, y, path, **variables):
        for x in range(x1, x2 + 1):
            self.put(x, y, path, **variables)

    def column(self, x, y1, y2, path, **variables):
        for y in range(y1, y2 + 1):
            self.put(x, y, path, **variables)

    def door(self, x, y, path=HOUSE_DOOR, turf=None):
        self.turf[y][x] = turf or self.turf[y][x]
        self.put(x, y, path)

    def glazing(self, cells, turf):
        for x, y in cells:
            self.turf[y][x] = turf
            self.put(x, y, WINDOW)
            self.put(x, y, GLASS)


def highways(g):
    # South highway, two carriageways separated by a jersey-barrier median.
    g.fill(2, 3, WIDTH - 1, 3, CONCRETE)
    g.fill(2, 4, WIDTH - 1, 12, ROAD)
    g.fill(2, 13, WIDTH - 1, 13, CONCRETE)
    for x in range(2, WIDTH):
        if x % 4 in (0, 1):
            g.turf[6][x] = WHITE
            g.turf[10][x] = WHITE
        g.turf[8][x] = YELLOW
    for x in range(12, 144):
        if x % 2 == 0 and not 74 <= x <= 86:
            g.put(x, 8, JERSEY)
    # East highway, north-south.
    g.fill(147, 2, 147, HEIGHT - 1, CONCRETE)
    g.fill(148, 2, 156, HEIGHT - 1, ROAD)
    g.fill(157, 2, 157, HEIGHT - 1, CONCRETE)
    for y in range(2, HEIGHT):
        if y % 4 in (0, 1):
            g.turf[y][150] = WHITE
            g.turf[y][154] = WHITE
        g.turf[y][152] = YELLOW
    for y in range(16, 136):
        if y % 2 == 0 and not 28 <= y <= 36:
            g.put(152, y, JERSEY)
    # Interchange: the crossing is plain road so both ramps meet.
    g.fill(147, 3, 157, 13, ROAD)
    # Ramps: parking-lot driveways onto both highways.
    g.fill(76, 14, 83, 15, ROAD)
    g.fill(141, 29, 147, 32, ROAD)
    # Abandoned traffic on the highways.
    for x, y, kind in ((20, 4, CAR), (31, 11, VAN), (58, 4, TRUCK), (97, 11, CAR_ALT),
                       (118, 5, VAN_ALT), (132, 11, CAR)):
        g.put(x, y, kind)
    for x, y, kind in ((149, 50, CAR_VERT), (155, 70, CAR_VERT), (149, 100, CAR_VERT), (155, 120, CAR_VERT)):
        g.put(x, y, kind)


def extracts(g):
    g.fill(3, 4, 8, 12, area=EXTRACTS['westbound'])
    g.put(9, 8, SIGN_EXTRACT, name='Westbound shoulder extraction')
    g.fill(148, 140, 156, 148, area=EXTRACTS['northbound'])
    g.put(150, 139, SIGN_EXTRACT, name='Northbound ramp extraction')
    g.fill(14, 121, 19, 127, DIRT, EXTRACTS['delivery'])
    g.put(20, 124, SIGN_EXTRACT, name='Delivery gate extraction')
    g.fill(3, 60, 6, 66, DIRT, EXTRACTS['culvert'])
    g.put(7, 63, SIGN_EXTRACT, name='Storm culvert extraction')


def west_strip(g):
    # Scrub between the highway and the mall, with a tree line away from routes.
    for y in range(20, 110, 6):
        for x in (4, 9, 14):
            if 56 <= y <= 70:
                continue
            g.put(x, y, TREE)
    for x, y in ((11, 40), (6, 90), (16, 104)):
        g.put(x, y, JUNK)


def parking(g):
    g.fill(22, 16, 146, 48, ROAD)
    g.fill(22, 49, 146, 53, CONCRETE)
    bays = (19, 24, 29, 34, 39, 44)
    for base in bays:
        for x in range(24, 144, 4):
            g.turf[base][x] = WHITE
            g.turf[base + 1][x] = WHITE
    # Main north-south drive aisles stay clear of stripes.
    for base in bays:
        for x in list(range(48, 51)) + list(range(80, 83)) + list(range(112, 115)):
            g.turf[base][x] = ROAD
            g.turf[base + 1][x] = ROAD
    # Lot perimeter barriers with gaps for the driveways and pedestrian routes.
    for x in range(22, 147):
        if x < 76 or x > 83:
            g.put(x, 15, CONCRETE_BARRIER)
    for y in range(16, 49):
        if not 29 <= y <= 32:
            g.put(146, y, CONCRETE_BARRIER)
        g.put(22, y, CONCRETE_BARRIER)
    wrecks = (
        (25, 19, CAR), (33, 24, VAN), (57, 19, CAR_ALT), (65, 29, CAR), (73, 24, VAN_ALT),
        (89, 19, CAR), (97, 34, TRUCK), (105, 24, CAR_ALT), (121, 29, VAN), (129, 19, CAR),
        (137, 39, CAR_ALT), (41, 39, TRUCK), (61, 44, CAR), (93, 44, VAN), (117, 44, CAR_ALT),
        (29, 34, CAR_ALT), (133, 34, CAR), (69, 39, VAN_ALT), (101, 29, CAR),
    )
    for x, y, kind in wrecks:
        g.put(x, y, kind)
    for x, y in ((36, 21), (52, 46), (84, 31), (108, 41), (124, 21), (140, 26), (45, 50), (118, 51)):
        g.put(x, y, JUNK)
    # Cart corrals and a bus shelter on the frontage walkway.
    for x in (40, 100):
        g.row(x, x + 3, 50, IRONFENCE)
    g.row(60, 64, 52, CONCRETE_BARRIER)
    g.row(104, 108, 52, CONCRETE_BARRIER)
    # Parking security booth: the Security office key is kept here.
    g.fill(132, 49, 138, 53, DARK)
    g.box(132, 49, 138, 53, BLOCKS)
    g.door(135, 49, HOUSE_DOOR, DARK)
    g.put(134, 52, COUNTER)
    g.put(136, 52, COUNTER)
    g.put(134, 52, KEYS['security'])
    g.put(136, 52, '/obj/random/medical/bandage')
    g.put(133, 51, FILING)
    g.put(137, 51, CHAIR)
    g.put(135, 50, SIGN_SECURE, name='Parking security booth')
    # PMC spawns at the two lot entrances, inside grace walls.
    for x, y in ((28, 17), (34, 17), (139, 46), (143, 44)):
        g.put(x, y, LANDMARK, name='JoinLatePMC')
    g.fill(24, 16, 38, 23, area=GRACE)
    g.fill(25, 17, 37, 22, area=OUTSIDE)
    g.fill(136, 40, 146, 48, area=GRACE)
    g.fill(137, 41, 145, 47, area=OUTSIDE)


def mall_shell(g):
    g.fill(24, 54, 140, 118, TILED, INTERIOR)
    g.box(24, 54, 140, 118, WALL)
    # South entrance with glazing on both sides of the doors.
    for x in range(80, 84):
        g.door(x, 54, STORE_DOOR, MARBLE)
    g.glazing([(x, 54) for x in list(range(74, 80)) + list(range(84, 90))], MARBLE)
    g.put(82, 52, SIGN, name='Crossroads Mall')
    g.fill(25, 55, 139, 117, TILED, INTERIOR)


def concourse(g):
    g.fill(52, 55, 111, 92, MARBLE)
    # Lobby and spine; kiosks interrupt sightlines along the spine.
    g.fill(76, 55, 87, 77, MARBLE)
    for x in (62, 76, 90, 104):
        g.put(x, 81, SHELF)
        g.put(x + 1, 81, SHELF)
        g.put(x, 84, SHELF)
        g.put(x + 1, 84, SHELF)
    g.put(62, 82, SIGN_STORE, name='Shade Stand sunglasses kiosk')
    g.put(76, 82, SIGN_STORE, name='Keycut and Repair kiosk')
    g.put(90, 82, SIGN_STORE, name='Pocket Charms phone cases kiosk')
    g.put(104, 82, SIGN_STORE, name='Pretzel Point kiosk')
    g.put(63, 82, '/obj/random/accessories')
    g.put(91, 82, '/obj/random/accessories')
    for x, y in ((70, 79), (97, 85), (58, 86), (108, 79), (82, 61), (79, 72)):
        g.put(x, y, JUNK)
    # Scav spawn in the middle of the spine.
    g.put(82, 83, LANDMARK, name='JoinLateScav')
    # Food hall north of the spine.
    g.fill(52, 87, 111, 92, WOODTILE)
    g.put(54, 92, SIGN_FOOD, name='The Crossing Food Hall')
    for x in range(56, 108, 8):
        g.put(x, 89, TABLE)
        g.put(x - 1, 89, CHAIR)
        g.put(x + 1, 89, CHAIR)
    g.put(53, 91, '/obj/structure/vending/sales/menu/pizza')
    g.put(53, 90, SIGN_FOOD, name='Pepper and Pie pizza counter')
    g.put(110, 91, '/obj/structure/vending/sales/drinks/hot')
    g.put(110, 90, SIGN_FOOD, name='Kettle Corner coffee')
    g.put(66, 92, '/obj/structure/vending/sales/food/snacks')
    g.put(96, 92, '/obj/structure/vending/sales/drinks/cola')
    g.put(72, 92, KEYS['management'])
    g.put(72, 92, TABLE)
    g.put(88, 92, COUNTER)
    g.put(88, 92, '/obj/structure/vending/sales/moneycounter')


def south_stores(g):
    """Six small stores facing the spine, each with a back stockroom."""
    stores = (
        (52, 59, 'Willowbrook Pharmacy', SIGN_PHARMACY,
         ('/obj/random/medical/bandage', '/obj/random/medical/drugs', MEDBAG)),
        (60, 67, 'Pagecount Books', SIGN_STORE, (JUNK, '/obj/random/accessories')),
        (68, 75, 'Stride Footwear', SIGN_STORE, ('/obj/random/armor',)),
        (88, 95, 'Lumen Mobile', SIGN_STORE, ('/obj/random/accessories', '/obj/random/magazine/western_random')),
        (96, 103, 'Threadline Apparel', SIGN_STORE, ('/obj/random/armor', '/obj/random/accessories')),
        (104, 111, 'Brightside Toys', SIGN_STORE, ('/obj/random/gun/funny_random', JUNK)),
    )
    for x1, x2, name, sign, loot in stores:
        g.fill(x1, 55, x2, 76, TILED)
        g.fill(x1, 77, x2, 77, PARTITION)
        if x1 > 52:
            g.fill(x1 - 1, 55, x1 - 1, 77, PARTITION)
        if x2 < 111:
            g.fill(x2 + 1, 55, x2 + 1, 77, PARTITION)
        centre = (x1 + x2) // 2
        g.door(centre, 77, STORE_DOOR, TILED)
        g.glazing([(centre - 2, 77), (centre + 2, 77)], TILED)
        g.put(centre, 78, sign, name=name)
        # Stockroom partition with a staff door.
        g.fill(x1, 62, x2, 62, PARTITION)
        g.door(x2 - 1, 62, HOUSE_DOOR, TILED)
        g.fill(x1, 55, x2, 61, DARK)
        # Sales floor shelving along the side walls and an island.
        g.column(x1, 65, 74, SHELF)
        g.column(x2, 65, 74, SHELF)
        g.row(x1 + 2, x2 - 2, 70, SHELF)
        g.put(x1 + 1, 75, JUNK)
        for index, path in enumerate(loot):
            g.put(x1 + 1 + index * 2, 57, path)
        g.put(x1 + 1, 59, CRATE)
        g.put(x2 - 1, 59, RACK)
    for x, y in ((56, 66), (100, 66), (64, 80), (98, 85), (82, 70)):
        g.turf[y][x] = BROKEN
    g.put(70, 73, LANDMARK, name='JoinLateScav')


def west_anchor(g):
    """Northlight Electronics with the management and security suite behind it."""
    g.fill(25, 55, 50, 96, TILED_DARK)
    g.fill(51, 55, 51, 117, PARTITION)
    for y in range(80, 85):
        g.door(51, y, STORE_DOOR, TILED_DARK)
    g.glazing([(51, 78), (51, 79), (51, 85), (51, 86)], TILED_DARK)
    g.put(50, 82, SIGN_STORE, name='Northlight Electronics')
    # Demo wall of dead displays and three shelf aisles.
    for x in range(27, 49, 3):
        g.put(x, 95, COMPUTER)
    for x in (30, 37, 44):
        g.column(x, 60, 74, SHELF)
        g.column(x + 1, 60, 74, SHELF)
    g.put(28, 90, COUNTER)
    g.put(29, 90, COUNTER)
    g.put(28, 90, '/obj/random/accessories')
    g.put(33, 90, SERVER)
    g.put(34, 90, SERVER)
    g.put(35, 90, '/obj/structure/props/computerprops/terminal')
    g.put(46, 58, CRATE)
    g.put(47, 58, '/obj/random/accessories')
    g.put(27, 58, '/obj/random/magazine/ak74')
    g.put(29, 58, '/obj/random/gun/ak74')
    g.put(40, 88, JUNK)
    g.put(33, 78, JUNK)
    g.put(40, 75, LANDMARK, name='JoinLateScav')
    # Management suite and security office, both keyed, above the store.
    g.fill(25, 97, 50, 97, PARTITION)
    g.fill(25, 98, 50, 117, DARK)
    g.fill(38, 98, 38, 117, PARTITION)
    g.door(32, 97, KEYED_DOORS['management'], DARK)
    g.door(44, 97, KEYED_DOORS['security'], DARK)
    g.put(32, 96, SIGN_SECURE, name='Mall management suite')
    g.put(44, 96, SIGN_SECURE, name='Security office')
    # Management: offices with a safe and explosives in the manager's cabinet.
    g.put(26, 115, FILING)
    g.put(27, 115, FILING)
    g.put(30, 110, TABLE)
    g.put(31, 110, CHAIR)
    g.put(30, 110, '/obj/random/explosives')
    g.put(36, 116, SAFE)
    g.put(35, 116, KEYS['cage'])
    g.put(28, 103, '/obj/structure/bed/chair/comfy/fancy_sofa/l')
    g.put(29, 103, '/obj/structure/bed/chair/comfy/fancy_sofa/r')
    g.put(33, 100, JUNK)
    # Security: armoury racks with modern rifles, ammunition and armour.
    g.row(40, 48, 115, RACK)
    for x, path in ((40, '/obj/random/gun/ak_modern'), (42, '/obj/random/magazine/ak74'),
                    (44, '/obj/random/armor'), (46, '/obj/random/gun/western_random'),
                    (48, '/obj/random/magazine/western_random')):
        g.put(x, 115, path)
    g.put(41, 100, TABLE)
    g.put(42, 100, CHAIR)
    g.put(41, 100, '/obj/random/medical/drugs')
    g.put(47, 100, '/obj/structure/props/computerprops/terminal')
    g.put(44, 108, '/obj/effect/spawner/lootdrop/ammo')
    # Service door from the suite to the loading yard, keyed like the front.
    g.door(30, 118, KEYED_DOORS['management'], DARK)


def east_anchor(g):
    """Ironbark Hardware and Garden with the stock cage and dock office behind it."""
    g.fill(113, 55, 139, 96, CONCRETE)
    g.fill(112, 55, 112, 117, PARTITION)
    for y in range(80, 85):
        g.door(112, y, STORE_DOOR, CONCRETE)
    g.glazing([(112, 78), (112, 79), (112, 85), (112, 86)], CONCRETE)
    g.put(113, 82, SIGN_HARDWARE, name='Ironbark Hardware and Garden')
    for x in (117, 124, 131):
        g.column(x, 60, 74, SHELF)
        g.column(x + 1, 60, 74, SHELF)
    g.put(116, 57, '/obj/random/melee')
    g.put(118, 57, '/obj/random/barricade/random')
    g.put(126, 57, '/obj/random/melee')
    g.put(134, 57, LARGECRATE)
    g.put(136, 57, '/obj/random/explosives')
    # Garden centre corner fenced off with its own tree stock.
    g.row(128, 138, 88, IRONFENCE)
    g.column(128, 89, 91, IRONFENCE)
    g.column(128, 93, 95, IRONFENCE)
    g.put(128, 92, CHAINLINK_DOOR)
    g.put(131, 91, TREE)
    g.put(135, 93, TREE)
    g.put(133, 90, BARREL)
    g.put(114, 92, COUNTER)
    g.put(115, 92, COUNTER)
    g.put(114, 92, '/obj/random/accessories')
    g.put(120, 90, JUNK)
    g.put(125, 78, JUNK)
    g.put(125, 75, LANDMARK, name='JoinLateScav')
    # Stock cage and dock office above the store.
    g.fill(113, 97, 139, 97, PARTITION)
    g.fill(113, 98, 139, 117, DARK)
    g.fill(126, 98, 126, 117, PARTITION)
    g.door(119, 97, KEYED_DOORS['cage'], DARK)
    g.door(133, 97, HOUSE_DOOR, DARK)
    g.put(119, 96, SIGN_SECURE, name='Ironbark stock cage')
    g.put(133, 96, SIGN, name='Dock office')
    # Cage: pallets of tools, weapons and ammunition.
    g.row(114, 124, 115, PALLET)
    for x, path in ((114, '/obj/random/gun/western_random'), (116, '/obj/random/magazine/western_random'),
                    (118, '/obj/random/gun/german_random'), (120, '/obj/random/magazine/german'),
                    (122, '/obj/effect/spawner/lootdrop/explosives'), (124, '/obj/random/armor')):
        g.put(x, 115, path)
    g.put(115, 102, LARGECRATE)
    g.put(117, 102, LARGECRATE)
    g.put(121, 102, '/obj/random/accessories')
    g.put(116, 108, JUNK)
    # Dock office: desk, filing and a medical bag.
    g.put(130, 110, TABLE)
    g.put(131, 110, CHAIR)
    g.put(130, 110, MEDBAG)
    g.put(137, 115, FILING)
    g.put(138, 115, FILING)
    g.put(129, 100, '/obj/random/accessories')
    g.put(135, 104, JUNK)
    g.door(132, 118, HOUSE_DOOR, DARK)


def supermarket(g):
    """Granary Market: checkouts, shelf aisles and four back rooms."""
    g.fill(52, 94, 111, 116, WHITEFLOOR)
    g.fill(52, 93, 111, 93, PARTITION)
    for x in (70, 71, 72, 90, 91, 92):
        g.door(x, 93, STORE_DOOR, WHITEFLOOR)
    g.glazing([(x, 93) for x in (66, 67, 68, 94, 95, 96)], WHITEFLOOR)
    g.put(81, 92, SIGN_FOOD, name='Granary Market')
    # Checkout lanes just inside the entrance.
    for x in range(56, 108, 6):
        g.put(x, 96, COUNTER)
        g.put(x + 1, 96, COUNTER)
        g.put(x + 2, 96, '/obj/structure/vending/sales/moneycounter')
    # Shelf aisles with a cross aisle in the middle.
    for x in range(56, 108, 6):
        for y in list(range(99, 103)) + list(range(105, 109)):
            g.put(x, y, SHELF)
            g.put(x + 1, y, SHELF)
    for x, y in ((60, 104), (84, 104), (102, 104), (73, 100), (97, 107), (65, 98)):
        g.put(x, y, JUNK)
    g.put(58, 104, '/obj/random/medical/bandage')
    g.put(76, 104, '/obj/random/accessories')
    g.put(94, 104, '/obj/random/melee')
    g.put(82, 100, LANDMARK, name='JoinLateScav')
    # Back rooms: bakery, cold storage, receiving and staff accounts.
    g.fill(52, 109, 111, 109, PARTITION)
    g.fill(52, 110, 111, 117, DARK)
    for x in (67, 82, 97):
        g.fill(x, 110, x, 117, PARTITION)
    rooms = ((52, 66, 'Bakery', 59), (68, 81, 'Cold storage', 74), (83, 96, 'Receiving', 89), (98, 111, 'Staff and accounts', 104))
    for x1, x2, name, door_x in rooms:
        g.door(door_x, 109, HOUSE_DOOR, DARK)
        g.put(door_x, 108, SIGN, name=name)
    g.put(54, 115, COUNTER)
    g.put(55, 115, COUNTER)
    g.put(54, 115, '/obj/random/medical/drugs')
    g.put(64, 112, BARREL)
    g.put(70, 115, CRATE)
    g.put(72, 115, CRATE)
    g.put(74, 115, '/obj/random/accessories')
    g.put(78, 112, '/obj/random/barricade/random')
    g.put(85, 115, PALLET)
    g.put(87, 115, PALLET)
    g.put(85, 115, '/obj/random/melee')
    g.put(93, 115, LARGECRATE)
    g.put(100, 115, FILING)
    g.put(101, 115, FILING)
    g.put(106, 113, TABLE)
    g.put(107, 113, CHAIR)
    g.put(106, 113, '/obj/random/accessories')
    g.put(109, 111, '/obj/random/magazine/ak47')
    # Receiving opens onto the loading dock through shutters.
    g.door(88, 118, SHUTTER_OPEN, DARK)
    g.door(89, 118, SHUTTER_OPEN, DARK)
    g.door(92, 118, SHUTTER, DARK)
    g.door(93, 118, SHUTTER, DARK)


def loading_yard(g):
    g.fill(23, 119, 145, 131, CONCRETE)
    g.fill(23, 118, 23, 118, CONCRETE)
    g.fill(141, 118, 145, 118, CONCRETE)
    # Chainlink fence with gates to the west and east and a gap at the range gate.
    for x in range(22, 147):
        if not 81 <= x <= 83:
            g.put(x, 132, CHAINLINK)
    g.column(22, 118, 131, CHAINLINK)
    g.column(146, 118, 131, CHAINLINK)
    g.clear_objects(22, 124)
    g.put(22, 124, CHAINLINK_DOOR)
    g.clear_objects(146, 124)
    g.put(146, 124, CHAINLINK_DOOR)
    g.put(21, 124, SIGN, name='Delivery gate')
    g.put(147, 124, SIGN, name='Service gate')
    for x, y, kind in ((60, 121, TRUCK), (96, 121, TRUCK), (120, 125, VAN), (36, 126, CAR_ALT)):
        g.put(x, y, kind)
    for x, y in ((70, 128), (104, 128)):
        g.put(x, y, DUMPSTER)
    for x, y in ((80, 120), (82, 120), (110, 123), (46, 122)):
        g.put(x, y, PALLET)
    for x, y in ((84, 125), (86, 125), (128, 129)):
        g.put(x, y, BARREL)
    g.put(140, 128, FUELTANK)
    g.put(54, 126, JUNK)
    g.put(136, 121, JUNK)
    g.put(81, 120, '/obj/random/accessories')


def loot_range(g):
    """Locked, indestructible range with one pad per loot table and a mechanics corner."""
    g.fill(24, 133, 140, 148, CONCRETE, RANGE)
    g.box(24, 133, 140, 148, BORDER)
    g.door(82, 133, KEYED_DOORS['range'], CONCRETE)
    g.put(82, 132, SIGN_RANGE, name='Loot test range gate')
    # Three labelled rows of pads.
    rows = ((145, LOOTDROP_TABLES, 'Row A: lootdrop spawners'),
            (141, RANDOM_WEAPON_TABLES, 'Row B: random weapon tables'),
            (137, RANDOM_SUPPORT_TABLES, 'Row C: random support tables and hazards'))
    pads = []
    for y, tables, label in rows:
        g.put(25, y, SIGN_RANGE, name=label)
        for index, (name, path) in enumerate(tables):
            x = 28 + index * 8
            g.put(x, y, PAD, name='loot pad: ' + name, table=path)
            pads.append((x, y, name, path))
    g.put(28 + 9 * 8, 136, SIGN_WARNING, name='Armed mine pads ahead')
    # Mechanics corner, west end of row C: keyed door, lockpick, breaching, extraction and grace wall.
    g.fill(60, 134, 66, 136, CONCRETE)
    g.box(60, 134, 66, 136, BLOCKS)
    g.door(63, 136, KEYED_DOORS['test'], CONCRETE)
    g.put(61, 135, CRATE)
    g.put(65, 135, '/obj/random/accessories')
    g.put(58, 135, TABLE)
    g.put(58, 135, KEYS['test'])
    g.put(58, 135, '/obj/item/weapon/lockpick')
    g.put(68, 135, TABLE)
    g.put(68, 135, '/obj/item/weapon/gun/projectile/shotgun/pump')
    g.put(68, 135, '/obj/item/ammo_magazine/shellbox')
    g.put(63, 137, SIGN_SECURE, name='Key, lockpick and breaching test door')
    g.fill(72, 134, 74, 135, area=EXTRACTS['range'])
    g.put(75, 134, SIGN_EXTRACT, name='Extraction test: stand here ten seconds')
    g.fill(78, 134, 78, 136, area=GRACE)
    g.put(79, 134, SIGN, name='Grace wall test strip')
    g.put(84, 135, OPTABLE)
    g.put(85, 135, SIGN, name='Medical test bench')
    g.put(84, 136, MEDBAG)
    return pads


def build():
    g = Grid()
    g.fill(1, 1, WIDTH, HEIGHT, GRASS, OUTSIDE)
    highways(g)
    extracts(g)
    west_strip(g)
    parking(g)
    mall_shell(g)
    concourse(g)
    south_stores(g)
    west_anchor(g)
    east_anchor(g)
    supermarket(g)
    loading_yard(g)
    loot_range(g)
    g.box(1, 1, WIDTH, HEIGHT, BORDER)
    # The mode metadata sits at the conventional bottom-left corner.
    g.put(1, 1, METADATA)
    return g


def render(g):
    definitions = {}
    keys = []

    def key(value):
        if value not in definitions:
            index = len(definitions)
            if index >= 676:
                raise ValueError('Two-character tile dictionary exhausted')
            definitions[value] = chr(97 + index // 26) + chr(97 + index % 26)
            keys.append(value)
        return definitions[value]

    rows = []
    for y in range(HEIGHT, 0, -1):
        row = []
        for x in range(1, WIDTH + 1):
            parts = list(g.objects[y][x]) + [g.turf[y][x], g.area[y][x]]
            row.append(key('(' + ','.join(parts) + ')'))
        rows.append(''.join(row))
    lines = [f'"{definitions[value]}" = {value}' for value in keys]
    lines.append('')
    lines.append('(1,1,1) = {"')
    lines.extend(rows)
    lines.append('"}')
    return '\n'.join(lines) + '\n'


def generate():
    return render(build())


def main(argv):
    output = OUTPUT
    if len(argv) > 1:
        output = Path(argv[1])
    text = generate()
    output.write_text(text, encoding='utf-8', newline='\n')
    print(f'Wrote {output} ({WIDTH}x{HEIGHT}, {text.count(chr(10))} lines)')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
