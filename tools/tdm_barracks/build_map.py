"""Generate maps/special/tdm_barracks.dmm, the TDM Barracks world.

    python3 tools/tdm_barracks/build_map.py            # write the map
    python3 tools/tdm_barracks/build_map.py --check    # fail if the map is stale

The layout follows the design in docs/tdm-barracks.md: three levels of 100 x 80
tiles, each inside an indestructible outer ring two tiles thick.

1. The Barracks: four rows of zones (ranges; practice yards; the barracks
   building; social rooms and the football pitch) joined by two corridors.
2. The annex, up the stairs in the arrival hall: the Red and Blue faction
   conference rooms and a joint briefing room, a race circuit and an airfield.
3. Open sky over the annex, where planes fly.

Coordinates are BYOND tiles (x east, y north, 1-based). Edit this file, not the .dmm.
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
ANNEX = '/area/caribbean/barracks/annex'
BRIEFING = '/area/caribbean/barracks/annex/briefing'
RED_ROOM = '/area/caribbean/barracks/annex/faction_room/red'
BLUE_ROOM = '/area/caribbean/barracks/annex/faction_room/blue'
TRACK = '/area/caribbean/barracks/annex/track'
AIRFIELD = '/area/caribbean/barracks/annex/airfield'
SKY_AREA = '/area/caribbean/barracks/annex/sky'
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
LAWN = '/turf/floor/grass'
SKY = '/turf/sky/building'
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
    def __init__(self, turf=RING, area=NOPASS):
        self.turf = {}
        self.area = {}
        self.objs = {}
        for x, y in itertools.product(range(1, W + 1), range(1, H + 1)):
            self.turf[x, y] = turf
            self.area[x, y] = area
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

    # Stairs up to the annex
    g.put(ANNEX_STAIRS[0], ANNEX_STAIRS[1], '/obj/structure/multiz/ladder/ww2/stairsup{ladder_id = "%s"; area_id = "%s"}' % (STAIRS_AREA_ID, STAIRS_AREA_ID))
    g.put(ANNEX_STAIRS[0] + 1, ANNEX_STAIRS[1], sign('Annex stairs', 'Upstairs: the race circuit, the airfield and the faction conference rooms.'))

    # The map's metadata object sits in the arrival hall.
    g.put(38, 26, '/obj/map_metadata/tdm_barracks')
    return g


ANNEX_STAIRS = (57, 28)
STAIRS_AREA_ID = 'barracks_annex'

COORD_ROOM = '/area/caribbean/barracks/annex/faction_room/coordinator'
FACTION_DOOR = '/obj/structure/simple_door/key_door/faction_door/barracks/'
OFFICE_CHAIR = '/obj/structure/bed/chair/office/dark/anchored'
WINDOW = '/obj/structure/window/classic/reinforced'
RUNWAY = '/obj/covers/roads/modern/runway'
TIRES = '/obj/structure/barricade/tires'
CENTRAL = '/obj/structure/sign/traffic/central'
SIDE = '/obj/structure/sign/traffic/side'
ZEBRA = '/obj/structure/sign/traffic/zebracrossing'
PARKING = '/obj/structure/sign/traffic/parking'
SMALL_WHITE = '/obj/structure/lamp/lamp_small/alwayson/white'
SMALL_RED = '/obj/structure/lamp/lamp_small/alwayson/red'
JERRYCAN = '/obj/item/weapon/reagent_containers/glass/barrel/jerrycan/gasoline'
TIMING = '/obj/effect/step_trigger/barracks_timing'
BAY = '/obj/structure/barracks/vehicle_bay'
PAPER = '/obj/item/weapon/paper'
PEN = '/obj/item/weapon/pen'
TOOLS = ('/obj/item/weapon/storage/toolbox', '/obj/item/weapon/wrench', '/obj/item/weapon/weldingtool')


def timing(track, role):
    return '%s{track = "%s"; role = "%s"}' % (TIMING, track, role)


def window(g, x, y, floor, area):
    """Open a wall tile and glaze it."""
    g.fill(x, y, x, y, floor, area)
    g.objs[x, y] = [WINDOW]


def conference_room(g, side):
    """The Red room as designed; Blue is its mirror image (x' = 101 - x)."""
    red = side == 'red'
    m = (lambda x: x) if red else (lambda x: 101 - x)
    floor = REDCARPET if red else BLUECARPET
    area = RED_ROOM if red else BLUE_ROOM
    name = 'Red' if red else 'Blue'
    door = FACTION_DOOR + side
    x1, x2 = sorted((m(3), m(28)))
    g.room(x1, 3, x2, 21, floor, area)
    a, b = sorted((m(14), m(15)))
    g.door(a, 22, b, 23, floor, ANNEX, door)
    # A second door straight onto the briefing floor (the door sits on the room side).
    g.door(min(m(29), m(30)), 10, max(m(29), m(30)), 11, floor, BRIEFING, None, across=True)
    for y in (10, 11):
        g.objs[m(29), y] = [door]
    for x in range(9, 23):
        g.put(m(x), 11, WOODTABLE)
        g.put(m(x), 12, WOODTABLE)
        g.put(m(x), 10, OFFICE_CHAIR + '{dir = 1}')
        g.put(m(x), 13, OFFICE_CHAIR)
    g.put(m(8), 11, OFFICE_CHAIR + '{dir = %d}' % (4 if red else 8))
    g.put(m(23), 12, OFFICE_CHAIR + '{dir = %d}' % (8 if red else 4))
    poster = '/obj/structure/poster/faction/%s/' % side
    g.put(m(3), 21, '/obj/structure/flag/pole/custom')
    g.put(m(6), 21, poster + 'mil1')
    g.put(m(10), 21, '/obj/structure/barracks/status_board')
    g.put(m(13), 21, '/obj/structure/sign/map')
    g.put(m(16), 21, '/obj/structure/barracks/orders_board/' + side)
    g.put(m(19), 21, '/obj/structure/noticeboard')
    g.put(m(23), 21, poster + 'mil2')
    g.put(m(28), 21, '/obj/structure/flag/pole/custom')
    g.put(m(15), 19, TABLE)
    g.put(m(15), 20, OFFICE_CHAIR)
    for x in (5, 6, 7):
        for y in (16, 17):
            g.put(m(x), y, TABLE)
    g.put(m(6), 16, PAPER, PAPER, PAPER, PAPER, PEN, PEN)
    for x, y, d in ((4, 16, 4), (4, 17, 4), (8, 16, 8), (8, 17, 8)):
        g.put(m(x), y, OFFICE_CHAIR + '{dir = %d}' % (d if red else 12 - d))
    banner = '/obj/structure/banner/faction/team/' + ('team1' if red else 'team2')
    g.put(m(4), 20, banner)
    g.put(m(27), 20, banner)
    for x in (24, 25, 26):
        g.put(m(x), 5, '/obj/structure/bed/chair/comfy/fancy_sofa')
    g.put(m(25), 7, WOODTABLE)
    g.put(m(27), 4, '/obj/structure/chemical_dispenser/coffee')
    g.put(m(28), 3, LANTERN)
    g.put(m(3), 4, '/obj/structure/closet/cabinet')
    g.put(m(4), 4, '/obj/structure/closet/cabinet')
    g.put(m(6), 4, RACK)
    g.put(m(7), 4, RACK)
    g.put(m(4), 21, sign('%s conference room' % name, 'For the %s faction on event days. The doors open for the %s roster, coordinators and admins. Orders are on the board; the roster is kept in the briefing room.' % (name, name), PLAQUE))
    for x, y in ((3, 3), (9, 21), (22, 21)):
        g.put(m(x), y, LAMP)


def build_annex():
    g = Grid()
    g.wall(3, 3, 98, 78, ANNEX)

    # ---- conference wing (y 3-21) ----------------------------------------
    g.room(31, 3, 70, 21, TILED, BRIEFING)
    conference_room(g, 'red')
    conference_room(g, 'blue')

    # Briefing room and the coordinators' office in its north-east corner
    g.fill(43, 18, 58, 20, MARBLE)
    g.fill(49, 3, 52, 17, REDCARPET)
    g.door(50, 22, 51, 23, TILED, ANNEX)
    g.wall(61, 14, 70, 14, BRIEFING)
    g.wall(61, 15, 61, 21, BRIEFING)
    g.fill(62, 15, 70, 21, DARK, COORD_ROOM)
    g.door(61, 17, 61, 18, DARK, BRIEFING, FACTION_DOOR + 'coordinator', across=True)
    for x in (63, 65, 67, 69):
        window(g, x, 14, DARK, COORD_ROOM)
    g.put(51, 19, TABLE)
    g.put(51, 20, OFFICE_CHAIR)
    g.put(45, 19, '/obj/structure/bell_stand')
    g.put(44, 20, '/obj/structure/banner/faction/team/team1')
    g.put(58, 20, '/obj/structure/banner/faction/team/team2')
    g.put(50, 21, '/obj/structure/barracks/faction_roster')
    g.put(53, 21, '/obj/structure/barracks/status_board')
    g.put(47, 21, '/obj/structure/sign/map')
    g.put(56, 21, '/obj/structure/barracks/orders_board')
    g.put(44, 21, '/obj/structure/noticeboard')
    g.put(59, 21, '/obj/structure/sign/clock')
    for y in range(5, 16, 2):
        for x in list(range(34, 49)) + list(range(53, 68)):
            if y != 15 or x < 61:
                g.put(x, y, BLEACHER + '{dir = 1}')
    g.put(32, 17, '/obj/structure/flag/pole/custom')
    g.put(69, 13, '/obj/structure/flag/pole/custom')
    g.put(32, 21, sign('Briefing room', 'Faction events start here. Coordinators keep the Red and Blue roster on the board by the lectern and the programme on the board beside it. Red sits west, Blue east.', PLAQUE))
    for x, y in ((31, 3), (70, 3), (31, 21), (42, 21)):
        g.put(x, y, LAMP)
    for x in (64, 65, 66):
        g.put(x, 18, TABLE)
        g.put(x, 17, OFFICE_CHAIR + '{dir = 1}')
        g.put(x, 19, OFFICE_CHAIR)
    g.put(65, 18, PAPER, PAPER, PAPER, PAPER, PEN, PEN, TOOLS[0])
    g.put(68, 21, '/obj/structure/barracks/status_board')
    g.put(70, 21, '/obj/structure/computer/nopower/platoontracker')
    g.put(62, 21, '/obj/structure/closet/cabinet')
    g.put(63, 21, '/obj/structure/closet/cabinet')
    g.put(65, 21, '/obj/structure/sign/map')
    g.put(70, 15, SMALL_WHITE)
    g.put(62, 15, sign("Coordinators' office", 'Staff only. The windows look onto the briefing hall.', PLAQUE))

    # ---- hallway (y 24-30) -----------------------------------------------
    g.room(3, 24, 98, 30, TILED, ANNEX)
    g.put(ANNEX_STAIRS[0], ANNEX_STAIRS[1], '/obj/structure/multiz/ladder/ww2/stairsdown{ladder_id = "%s"; area_id = "%s"}' % (STAIRS_AREA_ID, STAIRS_AREA_ID))
    g.put(ANNEX_STAIRS[0] + 1, ANNEX_STAIRS[1], sign('Stairs down', 'Back down to the arrival hall.'))
    g.put(52, 30, sign('Annex', 'North: the race circuit (doors west) and the airfield (door east). South: the Red conference room, the briefing room and the Blue conference room. Pit lane and paddock: through the grandstand door at the west end and over the crossing.', PLAQUE))
    for x in (6, 9, 20, 23, 40, 43, 64, 67, 90, 93):
        g.put(x, 24, BLEACHER + '{dir = 1}')
    g.put(60, 24, '/obj/structure/noticeboard')
    g.put(54, 24, sign('Records', 'Circuit lap records are shown on the lap board at race control; sky records in the control tower.', '/obj/structure/sign/custom/golden'))
    g.put(75, 27, '/obj/structure/fountain/no_bottom')
    for x in range(6, 98, 10):
        g.put(x, 30, LAMP)
    for x in (10, 35, 58):
        g.door(x, 31, x + 1, 32, CONCRETE, TRACK)
    g.door(84, 31, 85, 32, CONCRETE, AIRFIELD)
    g.put(12, 30, sign('Grandstand and paddock'))
    g.put(37, 30, sign('Grandstand'))
    g.put(60, 30, sign('Grandstand'))
    g.put(86, 30, sign('Airfield'))

    # ---- race circuit (x 3-68, y 33-78) ----------------------------------
    g.room(3, 33, 68, 78, LAWN, TRACK)
    g.fill(8, 33, 63, 34, CONCRETE)
    g.fill(3, 33, 7, 35, GRAVEL)
    g.fill(64, 33, 68, 35, GRAVEL)
    g.fill(3, 78, 68, 78, GRAVEL)
    g.fill(8, 35, 63, 35, CONCRETE)
    for x in range(8, 64):
        if x not in (10, 11, 35, 36, 58, 59):
            g.put(x, 33, BLEACHER + '{dir = 1}')
            g.put(x, 34, BLEACHER + '{dir = 1}')
        if x not in (10, 11):
            g.put(x, 35, RAILING + '{dir = 1}')
    for y in (33, 34):
        g.put(7, y, RAILING + '{dir = 4}')
        g.put(64, y, RAILING + '{dir = 8}')
    for x, y in ((3, 33), (68, 33), (3, 78), (68, 78)):
        g.put(x, y, FLOOD)
    g.put(7, 35, STREETLIGHT)
    g.put(64, 35, STREETLIGHT)
    g.put(6, 34, sign('Race circuit', 'Laps run anticlockwise: east along the main straight, north up the far side, west through the chicane, south down this side. Cross to the paddock on the zebra by the west aisle. Cars come from the pit garages; a lap starts and ends on the white line.', PLAQUE))

    g.fill(3, 36, 68, 42, ROAD)
    g.fill(3, 36, 9, 77, ROAD)
    g.fill(62, 36, 68, 77, ROAD)
    g.fill(3, 71, 68, 77, ROAD)
    for y in range(36, 43):
        g.put(30, y, CENTRAL + '{dir = 4}', timing('circuit', 'lap'))
        g.put(12, y, CENTRAL + '{dir = 4}', timing('drag', 'start'))
        g.put(58, y, CENTRAL + '{dir = 4}', timing('drag', 'finish'))
        g.put(10, y, ZEBRA)
        g.put(11, y, ZEBRA)
    for x, y in ((26, 37), (26, 38), (23, 40), (23, 41), (20, 37), (20, 38), (17, 40), (17, 41)):
        g.put(x, y, SIDE)
    for x, y in itertools.product((30, 31, 32), (75, 76, 77)):
        g.put(x, y, TIRES)
    for x, y in itertools.product((38, 39, 40), (71, 72, 73)):
        g.put(x, y, TIRES)
    g.put(29, 74, SIDE)
    g.put(41, 74, SIDE)
    for y in range(44, 71, 6):
        g.put(10, y, SIDE)
        g.put(61, y, SIDE)

    # Pit wall, pit lane and garages (y 43-54)
    g.fill(10, 43, 61, 48, ROAD)
    for x in range(16, 56):
        if x not in (26, 27, 28, 29, 30, 31):
            g.put(x, 43, JERSEY)
    for x in (26, 27, 28):
        g.put(x, 43, SMALL_RED)
    g.put(29, 43, '/obj/structure/barracks/lap_board{track = "circuit"}')
    g.put(30, 43, '/obj/structure/barracks/race_control')
    g.put(31, 43, sign('Race control', 'Click the console to start a race with a countdown, read the lap board, or clear abandoned cars. Pit lane is behind you; keep to gear 2 in it.', PLAQUE))
    for x in range(16, 56):
        g.put(x, 44, SIDE)
    g.put(56, 45, '/obj/structure/sign/traffic/stop')
    g.put(15, 48, '/obj/structure/sign/traffic/noentry')
    g.fill(10, 49, 61, 54, CONCRETE)
    for x, kind in ((14, 'piccolino'), (20, 'kazoku'), (26, 'quattroporte'), (32, 'type95'), (38, 'falcon'), (44, ''), (50, 'erstenklasse')):
        g.put(x, 49, BAY + ('/' + kind if kind else ''))
        g.put(x + 1, 50, SIDE)
        g.put(x + 5, 54, SIDE)
    g.put(11, 49, sign('Pit garages', 'Click a console for a fuelled car in the bay beside it; the bay must be empty and rests a minute between cars. Drive out south into the pit lane, turn east, leave by the exit at the far end. Cars nobody is driving are cleared away after ten minutes.', PLAQUE))
    g.put(13, 54, FLOOD)
    g.put(58, 50, '/obj/structure/fuelpump/premade/gasoline')
    g.put(60, 50, RACK, JERRYCAN, JERRYCAN)
    g.put(61, 50, RACK, JERRYCAN, JERRYCAN)
    g.put(58, 53, TABLE, *TOOLS)
    g.put(59, 53, TABLE)
    g.put(61, 53, '/obj/structure/closet/crate/barrel')
    g.put(56, 54, FLOOD)

    # Crossover road (club circuit) and the rally stage
    g.fill(10, 55, 61, 61, ROAD)
    g.put(9, 58, '/obj/structure/sign/traffic/waysign')
    g.put(62, 58, '/obj/structure/sign/traffic/waysign')
    g.fill(10, 62, 61, 70, GRAVEL)
    g.put(11, 62, BAY + '/wyoming')
    for x in (24, 30, 36, 42, 48, 54):
        g.put(x, 66, TIRES)
    for y in range(62, 71):
        g.put(20, y, CENTRAL + '{dir = 4}', timing('rally', 'start'))
        g.put(58, y, CENTRAL + '{dir = 4}', timing('rally', 'finish'))
    g.put(10, 70, '/obj/structure/barracks/lap_board{track = "rally"}')
    g.put(10, 69, sign('Rally stage', 'Start between the lines, weave the tyre piles, north of the first, south of the next. The clock stops on the far line.', PLAQUE))
    g.put(61, 70, FLOOD)
    g.put(61, 62, FLOOD)

    # ---- airfield (x 71-98, y 33-78) -------------------------------------
    g.room(71, 33, 98, 78, CONCRETE, AIRFIELD)
    g.line(92, 36, 96, 76, RUNWAY)
    for x in range(92, 97):
        g.put(x, 37, CENTRAL)
        g.put(x, 75, CENTRAL)
    for y in range(40, 73, 4):
        g.put(94, y, CENTRAL + '{dir = 4}')
    for x, y in ((90, 38), (91, 38), (90, 74), (91, 74)):
        g.put(x, y, CENTRAL)
    for y in (38, 46, 54, 62, 70):
        g.put(90, y, SMALL_WHITE)
        g.put(98, y, SMALL_WHITE)
    for x in (92, 94, 96):
        g.put(x, 33, SMALL_RED)
        g.put(x, 78, SMALL_RED)
    for y in range(36, 77, 2):
        g.put(87, y, SIDE)

    # Hangars, fire shed, fuel farm, control tower
    for s in (38, 44, 50, 56):
        g.wall(71, s - 2, 77, s - 2, AIRFIELD)
        g.wall(71, s + 4, 77, s + 4, AIRFIELD)
        g.put(72, s - 1, BAY + '/plane')
        g.put(77, s + 3, PARKING)
        g.put(71, s - 1 + 1, SMALL_WHITE)
    g.wall(71, 66, 77, 66, AIRFIELD)
    g.put(71, 65, '/obj/structure/closet/cabinet/first_aid')
    g.put(72, 65, '/obj/structure/closet/cabinet/first_aid')
    g.put(71, 62, '/obj/structure/bed/roller')
    g.put(71, 63, '/obj/structure/bed/roller')
    g.put(74, 65, RACK, JERRYCAN, JERRYCAN)
    g.put(75, 65, RACK, JERRYCAN, JERRYCAN)
    g.put(76, 65, TABLE, *TOOLS)
    g.put(77, 65, TABLE)
    g.put(77, 61, '/obj/structure/closet/crate/barrel')
    g.put(72, 61, sign('Fire and rescue', 'Hard landings break wheels and hurt nobody here. Patch up, then call a fresh plane from a hangar; wrecks and stranded planes are cleared away by the tower.', PLAQUE))
    g.put(72, 34, '/obj/structure/fuelpump/premade/gasoline')
    g.put(75, 34, '/obj/structure/fuelpump/premade/gasoline')
    g.put(71, 33, '/obj/structure/closet/crate/barrel')
    g.put(77, 33, '/obj/structure/closet/crate/barrel')
    g.put(78, 33, FENCE)
    g.put(78, 35, FENCE)

    g.wall(71, 67, 77, 67, AIRFIELD)
    g.wall(77, 67, 77, 78, AIRFIELD)
    g.fill(71, 68, 76, 78, DARK)
    g.door(77, 70, 77, 71, DARK, AIRFIELD, DOOR, across=True)
    for y in (73, 75, 77):
        window(g, 77, y, DARK, AIRFIELD)
    g.put(72, 78, '/obj/structure/barracks/flight_board')
    g.put(74, 78, '/obj/structure/barracks/status_board')
    g.put(76, 78, '/obj/structure/sign/map')
    g.put(71, 77, '/obj/structure/computer/nopower/platoontracker')
    g.put(73, 74, TABLE, PAPER, PAPER, PEN)
    g.put(74, 74, TABLE)
    g.put(73, 75, OFFICE_CHAIR)
    g.put(74, 75, OFFICE_CHAIR)
    g.put(71, 68, SMALL_WHITE)
    g.put(72, 68, sign('Control tower', 'Click the flight board for who is up, the sky-lap times and to clear stranded aircraft. The runway runs south from the north holding point; land southbound over the north threshold.', PLAQUE))

    for y in range(62, 66):
        for x in (79, 82):
            if y in (62, 65):
                g.put(x, y, SIDE)
    for y in (68, 71):
        g.put(79, y, SIDE)
        g.put(82, y, SIDE)
    g.put(84, 33, ZEBRA)
    g.put(85, 33, ZEBRA)
    g.put(80, 77, '/obj/structure/flag/pole/custom{name = "windsock"; desc = "An orange sock on a pole. The air here is always still."}')
    g.put(79, 34, sign('Airfield', 'Click a hangar console for a fuelled light plane. Taxi to the north holding point, turn onto the runway facing south, open the throttle to the top gear and roll: the plane climbs after eight tiles. Fly through the sky gates in order for a timed lap. To land, slow to gear 2 or lower, line up over the runway and Descend.', PLAQUE))
    for x, y in ((98, 33), (98, 78), (85, 78)):
        g.put(x, y, FLOOD)
    g.put(78, 67, STREETLIGHT)
    g.put(78, 36, STREETLIGHT)
    return g


AIR_GATES = (
    (1, [(30, y) for y in range(72, 77)]),
    (2, [(60, y) for y in range(72, 77)]),
    (3, [(x, 62) for x in range(92, 97)]),
    (4, [(x, 44) for x in range(92, 97)]),
    (5, [(80, y) for y in range(36, 41)]),
    (6, [(50, y) for y in range(36, 41)]),
    (7, [(x, 50) for x in range(4, 9)]),
)


def build_sky():
    g = Grid()
    g.wall(3, 3, 98, 32, SKY_AREA)
    for x, y in itertools.product(range(3, 99), range(3, 33)):
        g.turf[x, y] = RING
    g.fill(3, 33, 98, 78, SKY, SKY_AREA)
    for gate, tiles in AIR_GATES:
        for x, y in tiles:
            g.put(x, y, '/obj/effect/barracks_air_gate{gate = %d}' % gate)
    for x in range(4, 98, 6):
        g.put(x, 34, '/obj/effect/barracks_airspace_marker')
        g.put(x, 77, '/obj/effect/barracks_airspace_marker')
    for y in range(34, 78, 6):
        g.put(4, y, '/obj/effect/barracks_airspace_marker')
        g.put(97, y, '/obj/effect/barracks_airspace_marker')
    return g


def render(levels):
    cells = {}
    keys = {}
    alphabet = string.ascii_letters
    names = (a + b for a, b in itertools.product(alphabet, alphabet))
    for z, g in enumerate(levels, 1):
        for x, y in itertools.product(range(1, W + 1), range(1, H + 1)):
            cell = tuple(g.objs[x, y]) + (g.turf[x, y], g.area[x, y])
            if cell not in keys:
                keys[cell] = next(names)
            cells[x, y, z] = keys[cell]
    lines = ['"%s" = (%s)' % (key, ','.join(cell)) for cell, key in sorted(keys.items(), key=lambda item: item[1])]
    lines.append('')
    for z in range(1, len(levels) + 1):
        for x in range(1, W + 1):
            column = ''.join(cells[x, y, z] for y in range(H, 0, -1))
            lines.append('(%d,1,%d) = {"' % (x, z))
            lines.extend(column[i:i + 2] for i in range(0, len(column), 2))
            lines.append('"}')
    return '\n'.join(lines) + '\n'


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--check', action='store_true', help='fail when the checked-in map differs')
    args = parser.parse_args(argv)
    text = render([build(), build_annex(), build_sky()])
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
