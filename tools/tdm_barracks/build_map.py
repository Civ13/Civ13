"""Generate maps/special/tdm_barracks.dmm, the TDM Barracks world.

    python3 tools/tdm_barracks/build_map.py            # write the map
    python3 tools/tdm_barracks/build_map.py --check    # fail if the map is stale

The layout follows the design in docs/tdm-barracks.md: 100 x 80 tiles on one
level, an indestructible outer ring two tiles thick, and four rows of zones
(ranges; practice yards; the barracks building; social rooms and the parade
ground) joined by two east-west corridors. Coordinates are BYOND tiles
(x east, y north, 1-based). Edit this file, not the .dmm.
"""
import argparse
import itertools
import string
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'maps' / 'special' / 'tdm_barracks.dmm'
W, H = 100, 80

RING = '/turf/wall/indestructable/black'
WALL = '/turf/wall/indestructable'
NOPASS = '/area/caribbean/football/nopass'
SAFE = '/area/caribbean/barracks'
RANGE = '/area/caribbean/barracks/range'
LANES = '/area/caribbean/barracks/range/lanes'
COMBAT = '/area/caribbean/barracks/combat'
RED = '/area/caribbean/barracks/combat/team1'
BLUE = '/area/caribbean/barracks/combat/team2'
ADMIN = '/area/caribbean/admin'
PITCH = '/area/caribbean/barracks/pitch'

CONCRETE = '/turf/floor/plating/concrete'
TILED = '/turf/floor/plating/tiled'
DARK = '/turf/floor/plating/tiled/dark'
WHITE = '/turf/floor/plating/white'
MARBLE = '/turf/floor/plating/marble'
ROAD = '/turf/floor/plating/road'
BLUECARPET = '/turf/floor/carpet/bluecarpet'
REDCARPET = '/turf/floor/carpet/redcarpet'
WOOD = '/turf/floor/wood'
DIRT = '/turf/floor/dirt'
MUD = '/turf/floor/dirt/flooded'
GRAVEL = '/turf/floor/gravel'
SAND = '/turf/floor/beach/sand'
TRENCH = '/turf/floor/trench'
GRASS = '/turf/floor/grass{name = "pitch"}'

DOOR = '/obj/structure/simple_door/key_door/anyone/wood'
BLAST = '/obj/structure/simple_door/key_door/anyone/blast'
LOCKED = '/obj/structure/simple_door/key_door/anyone/high_sec'
SANDBAG = '/obj/structure/window/barrier/sandbag'
JERSEY = '/obj/structure/window/barrier/jersey'
RAILING = '/obj/structure/window/barrier/railing'
FENCE = '/obj/structure/grille/chainlinkfence'
WIRE = '/obj/structure/barbwire'
TARGET = '/obj/structure/practice_dummy/target/human/indestructible/scored'
DUMMY = '/obj/structure/practice_dummy/indestructible'
SOFT_DUMMY = '/obj/structure/practice_dummy'
RACK = '/obj/structure/table/rack'
TABLE = '/obj/structure/table/modern'
WOODTABLE = '/obj/structure/table/wood'
CHAIR = '/obj/structure/bed/chair/wood'
BLEACHER = '/obj/structure/bed/chair/wood/bleacher'
LAMP = '/obj/structure/lamp/lamp_big/alwayson'
TORCH = '/obj/structure/torch_stand/full'
LANTERN = '/obj/structure/torch_stand/lantern'
FLOOD = '/obj/structure/floodlight/on'
STREETLIGHT = '/obj/structure/lamp/streetlight/alwayson'
SIGN = '/obj/structure/sign/custom'
PLAQUE = '/obj/structure/sign/custom/plaque'


def quote(text):
    return '"' + text.replace('\\', '\\\\').replace('"', '\\"') + '"'


def sign(name, desc=None, kind=SIGN):
    vars_ = ['name = ' + quote(name)]
    if desc:
        vars_.append('desc = ' + quote(desc))
    return kind + '{' + '; '.join(vars_) + '}'


class Grid:
    def __init__(self):
        self.turf = {}
        self.area = {}
        self.objs = {}
        for x, y in itertools.product(range(1, W + 1), range(1, H + 1)):
            self.turf[x, y] = RING
            self.area[x, y] = NOPASS
            self.objs[x, y] = []

    def fill(self, x1, y1, x2, y2, turf=None, area=None):
        for x, y in itertools.product(range(x1, x2 + 1), range(y1, y2 + 1)):
            if turf:
                self.turf[x, y] = turf
            if area:
                self.area[x, y] = area

    def room(self, x1, y1, x2, y2, floor, area):
        """Floor the interior and wall the one-tile border just outside it, where it is still ring."""
        self.fill(x1, y1, x2, y2, floor, area)

    def wall(self, x1, y1, x2, y2, area=SAFE):
        self.fill(x1, y1, x2, y2, WALL, area)
        for x, y in itertools.product(range(x1, x2 + 1), range(y1, y2 + 1)):
            self.objs[x, y] = []

    def door(self, x1, y1, x2, y2, floor=CONCRETE, area=SAFE, kind=DOOR, across=False):
        """Open a wall: floor across it, with doors on its first row (or its first column
        when across is true, for a passage through a north-south wall)."""
        self.fill(x1, y1, x2, y2, floor, area)
        for x, y in itertools.product(range(x1, x2 + 1), range(y1, y2 + 1)):
            first = x == x1 if across else y == y1
            self.objs[x, y] = [kind] if kind and first else []

    def put(self, x, y, *objs):
        assert self.turf[x, y] != RING and self.turf[x, y] != WALL, ('object in a wall', x, y, objs)
        self.objs[x, y].extend(objs)

    def line(self, x1, y1, x2, y2, obj, step=1):
        for x in range(x1, x2 + 1, step):
            for y in range(y1, y2 + 1, step):
                self.put(x, y, obj)


def build():
    g = Grid()
    # The interior is 3..98 x 3..78; inner walls everywhere first, rooms carve it.
    g.wall(3, 3, 98, 78)

    # ---- north row: ranges (y 66-78) -------------------------------------
    g.room(3, 66, 5, 78, GRAVEL, RANGE)           # rifle firing line
    g.room(6, 66, 70, 78, DIRT, LANES)            # rifle lanes, shooting east
    for y in range(67, 78, 3):
        g.put(5, y, SANDBAG)                      # shooting points between bags
    for i, (x, y) in enumerate([(16, 76), (26, 73), (36, 70), (46, 77), (56, 68), (66, 74)]):
        g.put(x, y, TARGET)
    for i, x in enumerate(range(15, 70, 10)):
        g.put(x, 78, sign('%d tiles' % ((i + 1) * 10), 'Distance from the firing line.'))
        g.put(x, 66, sign('%d tiles' % ((i + 1) * 10), 'Distance from the firing line.'))
    g.put(4, 78, FLOOD)
    g.put(4, 66, FLOOD)
    g.put(3, 72, '/obj/structure/closet/crate/ww2/mosin_ammo')
    g.put(3, 70, '/obj/structure/closet/crate/scopes/pu')
    g.put(4, 72, sign('Rifle range', 'Shoot east from the gravel line. Targets stand from 10 to 60 tiles out; each hit tells you the distance.', PLAQUE))

    g.room(73, 66, 98, 67, CONCRETE, RANGE)       # pistol firing line
    g.room(73, 68, 98, 78, CONCRETE, LANES)       # pistol lanes, shooting north
    for x in (79, 85, 91):
        g.line(x, 68, x, 78, FENCE)
    for lane in ((73, 78), (80, 84), (86, 90), (92, 98)):
        middle = (lane[0] + lane[1]) // 2
        for y in (72, 76):
            g.put(middle, y, TARGET)
        g.put(middle, 66, TABLE)
    g.put(76, 66, '/obj/item/weapon/gun/projectile/pistol/m9beretta', '/obj/item/ammo_magazine/m9beretta', '/obj/item/ammo_magazine/m9beretta')
    g.put(82, 66, '/obj/item/weapon/gun/projectile/revolver/peacemaker', '/obj/item/ammo_magazine/c45')
    g.put(88, 66, '/obj/item/weapon/gun/projectile/submachinegun/ak47', '/obj/item/ammo_magazine/ak47')
    g.put(95, 66, '/obj/item/weapon/gun/projectile/submachinegun/m16', '/obj/item/ammo_magazine/m16')
    g.put(74, 67, sign('Pistol range', 'Shoot north. Targets at 5 and 9 tiles.', PLAQUE))
    g.put(98, 67, LAMP)
    # Doors from the corridors into the firing lines (the lanes are reached only through them).
    g.door(3, 64, 4, 65, GRAVEL, RANGE)
    g.door(73, 64, 74, 65, CONCRETE, RANGE)

    # ---- middle row: practice yards (y 47-63) ----------------------------
    g.room(3, 45, 4, 63, CONCRETE, SAFE)          # west corridor
    g.room(73, 45, 74, 63, CONCRETE, SAFE)        # range corridor
    g.room(3, 43, 98, 44, CONCRETE, SAFE)         # north corridor
    for x in range(10, 98, 12):
        g.put(x, 44, '/obj/structure/lamp/lamppost_small/alwayson')

    # Grenade and mortar pit
    g.room(7, 47, 20, 63, DIRT, COMBAT)
    g.door(9, 45, 10, 46, DIRT, COMBAT, BLAST)
    g.line(7, 50, 12, 50, SANDBAG)
    g.put(8, 48, '/obj/structure/cannon/mortar')
    g.put(7, 47, '/obj/effect/landmark/barracks_respawner/grenades', '/obj/structure/closet/crate/grenades')
    g.put(7, 48, '/obj/effect/landmark/barracks_respawner/mortar_shells', '/obj/structure/closet/crate/ww2/mortar_shells')
    g.put(11, 47, sign('Grenade pit', 'Throw from behind the sandbags. The dummies come back a minute after they break. Blasts stay inside the pit.', PLAQUE))
    for x, y in ((14, 58), (18, 55), (10, 61), (16, 61)):
        g.put(x, y, '/obj/effect/landmark/barracks_respawner', SOFT_DUMMY)
    g.put(20, 63, FLOOD)

    # Obstacle course
    g.room(23, 47, 48, 63, DIRT, COMBAT)
    g.door(23, 45, 24, 46, DIRT, COMBAT)
    g.put(24, 48, '/obj/effect/step_trigger/barracks_course')
    g.put(24, 49, sign('Obstacle course', 'Step on the start pad here and run north: trench, sandbags, wire, barriers. The clock stops at the far pad.', PLAQUE))
    g.fill(26, 51, 46, 52, TRENCH)
    g.fill(30, 55, 34, 56, MUD)
    g.fill(40, 55, 44, 56, MUD)
    g.line(26, 54, 46, 54, SANDBAG, 2)
    g.line(26, 58, 46, 58, WIRE)
    for x in (27, 31, 35, 39, 43):
        g.put(x, 61, JERSEY)
    g.line(25, 50, 25, 62, FENCE)
    g.put(46, 63, '/obj/effect/step_trigger/barracks_course/finish')
    g.put(47, 63, sign('Finish', 'The course clock stops on the pad beside this sign.'))

    # Melee yard and gym
    g.room(51, 47, 70, 63, DIRT, COMBAT)
    g.door(63, 45, 64, 46, DIRT, COMBAT)
    for x in (54, 58, 62):
        g.put(x, 61, DUMMY)
    g.put(66, 61, '/obj/structure/fitness/punchingbag')
    g.put(68, 61, '/obj/structure/fitness/punchingbag')
    g.put(66, 56, '/obj/structure/fitness/weightlifter')
    g.put(68, 56, '/obj/structure/fitness/weightlifter')
    g.put(60, 52, '/obj/structure/bell_stand')
    g.put(52, 48, RACK, '/obj/item/weapon/material/sword/armingsword', '/obj/item/weapon/material/sword/gladius')
    g.put(53, 48, RACK, '/obj/item/weapon/material/sword/katana', '/obj/item/weapon/material/spear/dory')
    g.put(54, 48, RACK, '/obj/item/weapon/shield/iron', '/obj/item/weapon/shield/iron')
    g.put(56, 48, sign('Melee yard', 'Hit the dummies with blades and fists, use the bags and weights. Ring the bell to call a sparring match.', PLAQUE))
    for x, y in ((51, 63), (70, 63), (51, 47), (70, 47)):
        g.put(x, y, TORCH)

    # Team skirmish arena: red and blue ready rooms behind fences, an open middle and a flag.
    g.room(77, 47, 98, 63, DIRT, COMBAT)
    g.fill(77, 47, 80, 63, CONCRETE, RED)
    g.fill(95, 47, 98, 63, CONCRETE, BLUE)
    for y in range(47, 64):
        if y not in (54, 55, 56):
            g.put(81, y, FENCE)
            g.put(94, y, FENCE)
    g.door(77, 45, 78, 46, CONCRETE, RED, BLAST)
    g.door(97, 45, 98, 46, CONCRETE, BLUE, BLAST)
    g.put(78, 60, '/obj/structure/banner/faction/team/team1')
    g.put(96, 60, '/obj/structure/banner/faction/team/team2')
    g.put(77, 62, '/obj/structure/closet/crate/pepelsibirsk/ak74')
    g.put(98, 62, '/obj/structure/closet/crate/pepelsibirsk/ak74')
    g.put(77, 61, '/obj/structure/closet/crate/ww2/vietnam/us_ammo')
    g.put(98, 61, '/obj/structure/closet/crate/ww2/vietnam/us_ammo')
    g.put(79, 48, sign('Red ready room', 'Gear up, then fight for the flag in the middle. Deaths send you to the arrival hall.', PLAQUE))
    g.put(96, 48, sign('Blue ready room', 'Gear up, then fight for the flag in the middle. Deaths send you to the arrival hall.', PLAQUE))
    for x, y in ((84, 50), (84, 60), (91, 50), (91, 60), (87, 52), (88, 58)):
        g.put(x, y, JERSEY)
    g.put(85, 55, SANDBAG)
    g.put(90, 55, SANDBAG)
    g.put(88, 55, '/obj/structure/flag/objective/one')
    g.put(83, 63, STREETLIGHT)
    g.put(92, 47, STREETLIGHT)

    # ---- building row (y 25-40) ------------------------------------------
    g.room(3, 21, 98, 22, CONCRETE, SAFE)         # south corridor
    for x in range(10, 98, 12):
        g.put(x, 22, '/obj/structure/lamp/lamppost_small/alwayson')

    # Armory and quartermaster
    g.room(3, 25, 18, 40, CONCRETE, SAFE)
    g.door(7, 41, 8, 42)
    g.door(7, 23, 8, 24)
    crates = ['/obj/structure/closet/crate/muskets', '/obj/structure/closet/crate/musketball',
              '/obj/structure/closet/crate/pistols', '/obj/structure/closet/crate/bayonets',
              '/obj/structure/closet/crate/ww2/mosin', '/obj/structure/closet/crate/ww2/mosin_ammo',
              '/obj/structure/closet/crate/ww2/mp40', '/obj/structure/closet/crate/ww2/ppsh',
              '/obj/structure/closet/crate/ww2/vietnam/akm', '/obj/structure/closet/crate/ww2/vietnam/us_ammo',
              '/obj/structure/closet/crate/pepelsibirsk/ak74', '/obj/structure/closet/crate/pepelsibirsk/svd',
              '/obj/structure/closet/crate/pepelsibirsk/makarov', '/obj/structure/closet/crate/arrows/steel']
    for i, crate in enumerate(crates):
        g.put(3 + (i % 7) * 2, 39 - (i // 7) * 2, crate)
    racks = [('/obj/item/weapon/gun/projectile/flintlock/brownbess',), ('/obj/item/weapon/gun/projectile/revolver/peacemaker', '/obj/item/ammo_magazine/c45'),
             ('/obj/item/weapon/gun/projectile/boltaction/mosin', '/obj/item/ammo_magazine/mosin'),
             ('/obj/item/weapon/gun/projectile/submachinegun/ak47', '/obj/item/ammo_magazine/ak47'),
             ('/obj/item/weapon/gun/projectile/submachinegun/m16', '/obj/item/ammo_magazine/m16'),
             ('/obj/item/weapon/gun/projectile/pistol/m9beretta', '/obj/item/ammo_magazine/m9beretta')]
    for i, items in enumerate(racks):
        g.put(4 + i * 2, 30, RACK, *items)
    for i, era in enumerate(('era1713', 'era1873', 'era1943', 'era1969', '')):
        g.put(18, 36 - i * 2, '/obj/structure/barracks/kit_locker' + ('/' + era if era else ''))
    g.put(16, 27, sign('Armory', 'Free practice gear. Crates and racks by era; the quartermaster lockers on the east wall hand out a whole kit.', PLAQUE))
    g.put(3, 26, LAMP)
    g.put(17, 39, LAMP)

    # War room: the live battle board
    g.room(21, 25, 34, 40, BLUECARPET, SAFE)
    g.door(35, 31, 36, 32, BLUECARPET, across=True)
    for x in range(25, 31):
        g.put(x, 40, '/obj/structure/barracks/status_board')
    for x in range(25, 31):
        g.put(x, 32, TABLE)
    for x in range(25, 31):
        g.put(x, 31, '/obj/structure/bed/chair/office/dark/anchored')
        g.put(x, 33, '/obj/structure/bed/chair/office/dark/anchored{dir = 2}')
    g.put(22, 26, sign('War room', 'Click the board on the north wall for the battle: map, phase, clock, both sides and the score.', PLAQUE))
    g.put(21, 40, LAMP)
    g.put(34, 25, LAMP)

    # Arrival hall: spawn, the deployment gate, the practice console
    g.room(37, 25, 60, 40, TILED, SAFE)
    g.door(39, 41, 40, 42, TILED)
    g.door(61, 31, 62, 32, TILED, across=True)
    g.door(47, 23, 48, 24, TILED)
    for x, y in itertools.product((41, 42, 43, 44), (30, 31)):
        g.put(x, y, '/obj/effect/landmark{name = "JoinLateCivA"}')
    g.put(48, 40, '/obj/structure/barracks/deploy_gate')
    g.put(49, 40, '/obj/structure/barracks/deploy_gate')
    g.put(47, 40, sign('Deployment gate', 'Click the gate to join the battle, or to switch auto-join.', PLAQUE))
    g.put(50, 40, sign('To the battle', 'The battle world is through this gate.'))
    g.put(56, 40, '/obj/structure/barracks/practice_console')
    g.put(57, 40, sign('Training rooms', 'Guided practice rooms open from the lobby panel (Practice Room).'))
    g.put(44, 34, sign('Welcome to the Barracks', 'Wait here between battles. Ranges and yards are north, the armory west, the war room and hall of fame either side, the mess hall and tavern south. Deaths here cost nothing: you are back in this hall at once.', PLAQUE))
    g.put(52, 34, '/obj/structure/noticeboard')
    for x, y in ((37, 25), (60, 25), (37, 40), (60, 40)):
        g.put(x, y, LAMP)
    for x in range(38, 60, 3):
        g.put(x, 25, BLEACHER)
    g.fill(48, 26, 49, 39, REDCARPET)             # a runner from the south door to the gate
    for y in (33, 36):
        for x in list(range(39, 47, 2)) + list(range(51, 59, 2)):
            g.put(x, y, BLEACHER + '{dir = 1}')
    g.put(38, 39, '/obj/structure/flag/pole/custom')
    g.put(59, 39, '/obj/structure/flag/pole/custom')
    g.put(53, 29, '/obj/structure/fountain/no_bottom')

    # Hall of fame: the leaderboards
    g.room(63, 25, 76, 40, REDCARPET, SAFE)
    g.put(66, 40, '/obj/structure/barracks/leaderboard')
    g.put(69, 40, '/obj/structure/barracks/leaderboard/record')
    g.put(72, 40, '/obj/structure/barracks/leaderboard/history')
    g.put(64, 26, sign('Hall of fame', 'The leaderboard, your own service record and the last battles fought.', PLAQUE))
    for x, y in ((63, 25), (76, 25), (63, 39), (76, 39)):
        g.put(x, y, LANTERN)
    g.put(69, 33, '/obj/structure/flag/pole/custom')

    # Medical training bay and the admin observation room
    g.room(79, 25, 98, 40, WHITE, SAFE)
    g.door(83, 41, 84, 42, WHITE)
    g.door(85, 23, 86, 24, WHITE)
    for x in (81, 84, 87):
        g.put(x, 27, '/obj/structure/bed/roller')
    g.put(80, 39, '/obj/structure/closet/cabinet/first_aid')
    g.put(81, 39, '/obj/structure/closet/cabinet/first_aid')
    g.put(84, 33, TABLE, '/obj/item/stack/medical/bruise_pack', '/obj/item/stack/medical/bruise_pack', '/obj/item/stack/medical/splint')
    g.put(85, 33, TABLE, '/obj/item/stack/medical/advanced/ointment', '/obj/item/stack/medical/bruise_pack')
    g.put(80, 30, sign('Medical training', 'Bring a hurt partner from the yards. Bandage bleeding first, then splint broken limbs; aim at the hurt part with the body doll.', PLAQUE))
    g.put(90, 26, LAMP)
    g.wall(92, 33, 98, 33)
    g.wall(92, 34, 92, 40)
    g.fill(93, 34, 98, 40, None, ADMIN)
    g.door(92, 36, 92, 36, WHITE, ADMIN, LOCKED, across=True)
    g.put(95, 37, TABLE)
    g.put(95, 38, '/obj/structure/bed/chair/office/dark/anchored')
    g.put(97, 39, LAMP)

    # ---- bottom row (y 3-18) ---------------------------------------------
    # Duel arena with bleachers
    g.room(3, 3, 24, 18, SAND, COMBAT)
    g.fill(3, 3, 6, 18, WOOD, SAFE)
    g.fill(21, 3, 24, 18, WOOD, SAFE)
    g.door(5, 19, 6, 20, WOOD)
    g.door(13, 19, 14, 20, SAND, COMBAT)
    for y in range(4, 18, 2):
        g.put(4, y, BLEACHER + '{dir = 4}')
        g.put(23, y, BLEACHER + '{dir = 8}')
    for y in range(3, 19):
        if y != 10:
            g.put(7, y, RAILING + '{dir = 4}')
            g.put(20, y, RAILING + '{dir = 8}')
    g.put(13, 4, '/obj/structure/bell_stand')
    g.put(10, 17, RACK, '/obj/item/weapon/gun/projectile/flintlock/duellingpistol', '/obj/item/weapon/gun/projectile/flintlock/duellingpistol')
    g.put(16, 17, RACK, '/obj/item/weapon/material/sword/cutlass', '/obj/item/weapon/material/sword/cutlass')
    g.put(3, 17, sign('Duelling ring', 'Fighters step into the sand; the rest watch from the stands. Ring the bell to start.', PLAQUE))
    for x, y in ((8, 3), (19, 3), (8, 18), (19, 18)):
        g.put(x, y, TORCH)

    # Mess hall
    g.room(27, 3, 48, 18, DARK, SAFE)
    g.door(37, 19, 38, 20, DARK)
    g.put(28, 18, '/obj/structure/oven')
    g.put(30, 18, '/obj/structure/oven/griddle')
    g.put(32, 18, '/obj/structure/oven/fryer')
    g.put(34, 18, '/obj/structure/fountain/no_bottom')
    g.put(44, 18, '/obj/structure/closet/crate/rations/biscuits')
    g.put(46, 18, '/obj/structure/closet/crate/rations/fruits')
    for x, y in itertools.product((30, 35, 40, 45), (6, 10, 14)):
        g.put(x, y, WOODTABLE)
        g.put(x - 1, y, CHAIR + '{dir = 4}')
        g.put(x + 1, y, CHAIR + '{dir = 8}')
    g.put(28, 4, sign('Mess hall', 'Eat, sit and talk while the next battle forms.', PLAQUE))
    for x, y in ((27, 3), (48, 3), (27, 16), (48, 16)):
        g.put(x, y, LAMP)

    # Tavern
    g.room(51, 3, 72, 18, WOOD, SAFE)
    g.door(61, 19, 62, 20, WOOD)
    g.line(53, 16, 60, 16, WOODTABLE)
    g.put(54, 18, '/obj/structure/chemical_dispenser/alcohol')
    g.put(57, 18, '/obj/structure/chemical_dispenser/coffee')
    g.put(60, 18, '/obj/structure/closet/crate/rations/beer')
    g.put(66, 10, '/obj/structure/table/modern/billiard')
    g.put(67, 10, '/obj/structure/table/modern/billiard')
    for x, y in itertools.product((54, 59), (6, 10)):
        g.put(x, y, WOODTABLE)
        g.put(x - 1, y, CHAIR + '{dir = 4}')
        g.put(x + 1, y, CHAIR + '{dir = 8}')
    g.put(71, 4, '/obj/structure/oven/fireplace')
    g.put(52, 4, '/obj/structure/noticeboard')
    g.put(52, 13, '/obj/structure/sign/bar')
    for x, y in ((51, 3), (72, 3), (51, 18), (72, 15)):
        g.put(x, y, LANTERN)

    # Football pitch (the old parade ground): the football map's ball, boots and
    # goalposts, with goals that keep a pitch score.
    POST = '/obj/structure/goalpost'
    g.room(75, 3, 98, 18, CONCRETE, SAFE)
    g.door(85, 19, 86, 20, CONCRETE)
    g.fill(77, 4, 96, 16, GRASS, PITCH)
    g.fill(75, 8, 76, 13, GRASS, PITCH)
    g.fill(97, 8, 98, 13, GRASS, PITCH)
    for mouth, back, goal, top, side, bottom in (
            (76, 75, 'blue', 9, 8, 10),
            (97, 98, 'red', 5, 4, 6)):
        g.put(mouth, 13, POST + '{dir = 1}')
        g.put(mouth, 8, POST)
        g.put(back, 13, POST + '{dir = %d}' % top)
        g.put(back, 8, POST + '{dir = %d}' % bottom)
        for y in range(9, 13):
            g.put(mouth, y, '/obj/effect/step_trigger/goal/barracks/' + goal, POST + '/inner')
            g.put(back, y, POST + '{dir = %d}' % side)
    g.put(86, 10, '/obj/effect/landmark/barracks_ball_spot', '/obj/item/football')
    for x in list(range(77, 84)) + list(range(88, 95)):
        g.put(x, 17, BLEACHER)
        g.put(x, 3, BLEACHER + '{dir = 1}')
    g.put(79, 18, '/obj/structure/barracks/kit_locker/football_red')
    g.put(92, 18, '/obj/structure/barracks/kit_locker/football_blue')
    g.put(88, 18, '/obj/structure/barracks/football_board')
    for x, y in ((75, 3), (98, 3), (75, 18), (98, 18)):
        g.put(x, y, STREETLIGHT)
    g.put(76, 18, sign('Football pitch', 'Take football boots and a jersey from a locker; only boots can kick. Walk into the ball to dribble, click a tile to pass or shoot. Red defends the west goal, Blue the east.', PLAQUE))

    # The map's metadata object sits in the arrival hall.
    g.put(38, 26, '/obj/map_metadata/tdm_barracks')
    return g


def render(g):
    cells = {}
    keys = {}
    alphabet = string.ascii_letters
    names = (a + b for a, b in itertools.product(alphabet, alphabet))
    for x, y in itertools.product(range(1, W + 1), range(1, H + 1)):
        cell = tuple(g.objs[x, y]) + (g.turf[x, y], g.area[x, y])
        if cell not in keys:
            keys[cell] = next(names)
        cells[x, y] = keys[cell]
    lines = ['"%s" = (%s)' % (key, ','.join(cell)) for cell, key in sorted(keys.items(), key=lambda item: item[1])]
    lines.append('')
    for x in range(1, W + 1):
        column = ''.join(cells[x, y] for y in range(H, 0, -1))
        lines.append('(%d,1,1) = {"' % x)
        lines.extend(column[i:i + 2] for i in range(0, len(column), 2))
        lines.append('"}')
    return '\n'.join(lines) + '\n'


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--check', action='store_true', help='fail when the checked-in map differs')
    args = parser.parse_args(argv)
    text = render(build())
    if args.check:
        if not OUT.exists() or OUT.read_text(encoding='utf-8') != text:
            print('%s is stale: run python3 tools/tdm_barracks/build_map.py' % OUT.relative_to(ROOT))
            return 1
        print('%s is current' % OUT.relative_to(ROOT))
        return 0
    OUT.write_text(text, encoding='utf-8', newline='\n')
    print('wrote %s' % OUT.relative_to(ROOT))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
