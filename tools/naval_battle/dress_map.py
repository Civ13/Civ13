#!/usr/bin/env python3
"""Naval Battle (maps/1713/naval.dmm): art and level-design pass.

Rewrites the map in place so the two moored ships read as 18th-century
warships: real masts with yards and sails, standing rigging, bowsprit rigging,
a helm with wheel and binnacle, a capstan, a belfry, hatch gratings, anchors,
ready shot and sponge buckets at the guns, a dressed great cabin and a lapping
waterline. Every prop is an existing type with an existing sprite. One tile of
hull behind the pirates' foremost engaged gun becomes deck so its crew can
reach it.

Nothing that decides the round is touched, and the script refuses to write
if any of it changed: areas (grace wall, win conditions, the ship areas the
broadside code reads), spawn landmarks, ladders, guns, cannonball crates and
the map metadata object all have to be identical before and after.

The edits only ever "ensure" a state, so running the script twice gives the
same file as running it once.

    python3 tools/naval_battle/dress_map.py            # rewrite the map
    python3 tools/naval_battle/dress_map.py --check    # exit 1 if it would change
"""
import argparse
import re
import string
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAP = ROOT / "maps" / "1713" / "naval.dmm"
DECK_Z = 4

DECK = "/turf/floor/wood/ship"
WATER = "/turf/floor/beach/water/deep/saltwater"

# --- props (all existing types) ---------------------------------------------
MAST = "/obj/structure/barricade/ship/mast/large"
SHROUD = "/obj/structure/voyage/ropeladder/thin"
BOW = "/obj/structure/ship_bow"
ANCHOR = "/obj/structure/voyage/anchor"
CHAIR = "/obj/structure/bed/chair/wood"
CAPSTAN = "/obj/structure/voyage/anchor_capstan"
SEXTANT = "/obj/structure/voyage/sextant"
GRID = "/obj/structure/voyage/grid"
GRID_MID = "/obj/structure/voyage/grid/middle"
WAKE = "/obj/effect/sailing_effect"
LANTERN = "/obj/item/flashlight/lantern/on/anchored"
SHOT = "/obj/item/cannon_ball"
BUCKET = "/obj/item/weapon/reagent_containers/glass/bucket"
MOP = "/obj/item/weapon/mop"
ROPE = "/obj/item/stack/material/rope{amount = 10}"
POWDER = "/obj/item/weapon/reagent_containers/glass/barrel/gunpowder"
TABLE = "/obj/structure/table/wood"
# The voyage wheel steers the Voyage map and has no business here, so the helm
# is the inert voyage base type wearing the same wheel sprite.
WHEEL = ('/obj/structure/voyage{anchored = 1; density = 1; desc = "The helm. '
         'Moored alongside, it has nothing to steer."; dir = 4; '
         "icon = 'icons/obj/vehicles/vehicleparts_boats.dmi'; "
         'icon_state = "ship_wheel"; layer = 2.99; name = "ship\'s wheel"}')


# --- DMM reading and writing ---------------------------------------------------
def split_atoms(text):
    """Split a key's contents on the commas that separate atoms."""
    atoms, depth, quote, start = [], 0, None, 0
    for i, ch in enumerate(text):
        if quote:
            if ch == quote and text[i - 1] != "\\":
                quote = None
        elif ch in "\"'":
            quote = ch
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
        elif ch == "," and depth == 0:
            atoms.append(text[start:i])
            start = i + 1
    atoms.append(text[start:])
    return tuple(atoms)


class Dmm:
    def __init__(self, text):
        self.key_order = []
        self.keys = {}
        for m in re.finditer(r'^"(\w+)" = \((.*)\)$', text, re.M):
            self.key_order.append(m.group(1))
            self.keys[m.group(1)] = split_atoms(m.group(2))
        self.klen = len(self.key_order[0])
        self.levels = {}
        for m in re.finditer(r'^\(1,1,(\d+)\) = \{"\n(.*?)\n"\}', text, re.M | re.S):
            rows = m.group(2).split("\n")
            self.levels[int(m.group(1))] = [
                [self.keys[r[i:i + self.klen]] for i in range(0, len(r), self.klen)]
                for r in rows
            ]
        self.height = len(self.levels[1])
        self.width = len(self.levels[1][0])

    def get(self, x, y, z=DECK_Z):
        return self.levels[z][self.height - y][x - 1]

    def put(self, x, y, atoms, z=DECK_Z):
        self.levels[z][self.height - y][x - 1] = tuple(atoms)

    def tiles(self, z=None):
        for lz in sorted(self.levels):
            if z is not None and lz != z:
                continue
            for y in range(1, self.height + 1):
                for x in range(1, self.width + 1):
                    yield x, y, lz, self.get(x, y, lz)

    def dumps(self):
        by_atoms = {}
        for k in self.key_order:
            by_atoms.setdefault(self.keys[k], k)
        used = []
        seen = set()
        for _, _, _, atoms in self.tiles():
            if atoms not in seen:
                seen.add(atoms)
                used.append(atoms)
        taken = set(self.key_order)
        spare = (a + b for a in string.ascii_letters for b in string.ascii_letters)
        fresh = []
        for atoms in used:
            if atoms not in by_atoms:
                key = next(k for k in spare if k not in taken)
                taken.add(key)
                by_atoms[atoms] = key
                fresh.append(key)
        live = {by_atoms[a] for a in used}
        order = [k for k in self.key_order if k in live] + fresh
        by_key = {v: k for k, v in by_atoms.items()}
        out = ['"%s" = (%s)' % (k, ",".join(by_key[k])) for k in order]
        out.append("")
        for z in sorted(self.levels):
            out.append('(1,1,%d) = {"' % z)
            out.extend("".join(by_atoms[a] for a in row) for row in self.levels[z])
            out.append('"}')
            out.append("")
        return "\n".join(out)


# --- edit helpers (each one only ensures a state) ------------------------------
def turf_of(atoms):
    return atoms[-2]


def area_of(atoms):
    return atoms[-1]


def objs_of(atoms):
    return atoms[:-2]


def add(m, x, y, *objs):
    atoms = m.get(x, y)
    have = list(objs_of(atoms))
    for o in objs:
        if o not in have:
            have.append(o)
    m.put(x, y, have + [turf_of(atoms), area_of(atoms)])


def add_n(m, x, y, obj, n):
    """Make sure the tile holds at least n of obj (loose items stack up)."""
    atoms = m.get(x, y)
    have = list(objs_of(atoms))
    have += [obj] * max(0, n - have.count(obj))
    m.put(x, y, have + [turf_of(atoms), area_of(atoms)])


def remove(m, x, y, obj):
    atoms = m.get(x, y)
    m.put(x, y, [o for o in objs_of(atoms) if o != obj] + [turf_of(atoms), area_of(atoms)])


def to_deck(m, x, y):
    """Turn a hull-timber "mast" block into open deck, keeping its area."""
    atoms = m.get(x, y)
    m.put(x, y, list(objs_of(atoms)) + [DECK, area_of(atoms)])


def rename_wall(m, x, y, name):
    atoms = m.get(x, y)
    assert turf_of(atoms).startswith("/turf/wall/wood"), (x, y, atoms)
    m.put(x, y, list(objs_of(atoms)) + ['/turf/wall/wood{name = "%s"}' % name, area_of(atoms)])


def free(m, x, y):
    """Open deck with nothing dense or important on it."""
    atoms = m.get(x, y)
    return turf_of(atoms) == DECK and not any(
        t in o for o in objs_of(atoms)
        for t in ("landmark", "ladder", "cannon", "closet", "table", "vending", "door", "barricade", "voyage"))


def mast(m, x, y, pixel_y=0):
    """A 2x2 mast stepped at (x, y); yards and sails come with it in game."""
    for dx in (0, 1):
        for dy in (0, 1):
            atoms = m.get(x + dx, y + dy)
            if turf_of(atoms).startswith("/turf/wall/wood"):
                to_deck(m, x + dx, y + dy)
            assert not any(t in o for o in objs_of(m.get(x + dx, y + dy))
                           for t in ("landmark", "ladder", "cannon", "closet")), (x + dx, y + dy)
    add(m, x, y, MAST + ("{pixel_y = %d}" % pixel_y if pixel_y else ""))


def grating(m, x1, y1, x2, y2):
    """A hatch grating over the hold, edge pieces picked by position."""
    for x in range(x1, x2 + 1):
        for y in range(y1, y2 + 1):
            assert free(m, x, y) or any(GRID in o for o in objs_of(m.get(x, y))), (x, y)
            d = (1 if y == y2 else 2 if y == y1 else 0) | (8 if x == x1 else 4 if x == x2 else 0)
            if d == 0:
                add(m, x, y, GRID_MID)
            elif d == 2:
                add(m, x, y, GRID)
            else:
                add(m, x, y, "%s{dir = %d}" % (GRID, d))


def ready_shot(m, x, y, bucket=False):
    """Two balls ready by a gun, and for some crews a sponge bucket."""
    add_n(m, x, y, SHOT, 2)
    if bucket:
        add(m, x, y, BUCKET)


# --- the pass -------------------------------------------------------------------
def french_ship(m):
    # Masts. The old ones were blocks of hull timber named "mast".
    for x, y in ((37, 17), (37, 18)):
        to_deck(m, x, y)          # the main mast was three tiles wide
    mast(m, 28, 17)               # mizzen
    mast(m, 38, 17)               # main
    mast(m, 47, 17)               # fore

    # Helm just forward of the mizzen: wheel, binnacle, the captain's glass.
    add(m, 31, 18, WHEEL)
    add(m, 31, 17, TABLE, SEXTANT, "/obj/item/weapon/compass")
    # Capstan in the waist, belfry abaft the foremast, grating over the hold.
    add(m, 34, 18, CAPSTAN)
    grating(m, 41, 17, 42, 18)

    # Shrouds, where they do not hide a ladder or a gun crew.
    add(m, 30, 13, SHROUD)                    # mizzen, seaward side
    add(m, 39, 13, SHROUD)                    # main, seaward side
    add(m, 44, 13, SHROUD)                    # fore, seaward side
    add(m, 40, 21, SHROUD + "{dir = 1}")      # main, engaged side

    # Ready shot at every gun. Engaged battery (deck row 22, guns face north).
    for i, x in enumerate((33, 36, 38, 43, 46, 48)):
        ready_shot(m, x, 22, bucket=i % 2 == 0)
    add(m, 40, 22, POWDER)
    add(m, 46, 21, POWDER)
    # Seaward battery (guns set into the hull at row 12).
    for i, x in enumerate((33, 38, 43)):
        ready_shot(m, x, 13, bucket=i == 1)

    # Working deck: swabs, coiled falls at the foot of each mast.
    add(m, 30, 19, ROPE)
    add(m, 37, 18, ROPE)
    add(m, 45, 19, MOP, BUCKET)
    add(m, 35, 14, ROPE)
    # Bower anchors catted at the bows.
    add(m, 57, 22, ANCHOR)
    add(m, 57, 13, ANCHOR)

    # The great cabin: carpet, the captain's table, a cot, his sea chest.
    for x in range(21, 26):
        for y in range(16, 20):
            add(m, x, y, "/obj/covers/carpet/bluecarpet")
    for x in (22, 23):
        add(m, x, 17, "/obj/structure/table/fancy")
    add(m, 22, 17, "/obj/item/weapon/globe")
    add(m, 23, 17, "/obj/item/weapon/flame/candle", "/obj/item/weapon/paper_bin")
    add(m, 22, 16, CHAIR + "{dir = 1}")
    add(m, 23, 18, CHAIR)
    add(m, 21, 17, CHAIR + "{dir = 4}")
    add(m, 24, 17, CHAIR + "{dir = 8}")
    add(m, 26, 13, "/obj/structure/bed/padded", "/obj/item/weapon/bedsheet/captain")
    add(m, 24, 13, "/obj/structure/closet/crate/chest")
    add(m, 22, 13, "/obj/structure/potted_plant")
    add(m, 19, 17, LANTERN)
    add(m, 19, 20, LANTERN)


def pirate_ship(m):
    # Masts. Nine planks of beam put the centreline on row 35, so each 2x2
    # mast is drawn half a tile down to sit on it.
    mast(m, 27, 35, pixel_y=-16)  # mizzen
    mast(m, 36, 35, pixel_y=-16)  # main
    mast(m, 44, 35, pixel_y=-16)  # fore
    # The old foremast block sits between the two fore ladders; it stays as
    # the coaming of that companionway.
    for x in (46, 47):
        rename_wall(m, x, 35, "companionway")
    # Rope that lay where the masts now stand.
    for x in (27, 36):
        remove(m, x, 36, ROPE)
    add(m, 26, 35, ROPE)
    add(m, 38, 36, ROPE)

    # Helm, capstan, belfry, main hatch.
    add(m, 30, 35, WHEEL)
    add(m, 30, 34, TABLE, SEXTANT, "/obj/item/weapon/compass")
    add(m, 32, 35, CAPSTAN)
    grating(m, 39, 34, 40, 36)

    # Shrouds.
    add(m, 29, 38, SHROUD + "{dir = 1}")      # mizzen, seaward side
    add(m, 49, 38, SHROUD + "{dir = 1}")      # fore, seaward side
    add(m, 25, 31, SHROUD)                    # mizzen, engaged side
    add(m, 31, 31, SHROUD)                    # main, engaged side

    # Ready shot. Engaged battery: guns in the hull at row 29, crews on row 30.
    for i, x in enumerate((36, 40, 41, 43, 46, 47)):
        ready_shot(m, x, 30, bucket=i % 2 == 0)
    # Seaward battery: guns on deck row 40.
    for i, x in enumerate((37, 42, 47)):
        ready_shot(m, x, 40, bucket=i == 1)

    add(m, 33, 37, MOP, BUCKET)
    add(m, 51, 37, ROPE)
    add(m, 25, 38, "/obj/item/weapon/fishing/net")
    add(m, 50, 39, ANCHOR)
    add(m, 50, 31, ANCHOR)

    # The foremost engaged gun (48,29) had hull timber where its crew should
    # stand, so nobody could reach it to load or lay it. Open that one tile to
    # deck; it stays in the ship's area, which is what the broadside reads.
    assert "/obj/structure/cannon" in m.get(48, 29)
    to_deck(m, 48, 30)


def sea(m):
    # Bowsprit rigging over the water ahead of each stem.
    add(m, 59, 14, BOW)
    add(m, 53, 32, BOW + "{pixel_y = -16}")
    # Water lapping along both hulls.
    for x, y, _, atoms in list(m.tiles(DECK_Z)):
        if turf_of(atoms) != WATER or objs_of(atoms):
            continue
        if not 11 <= y <= 42 or not 17 <= x <= 58:
            continue
        north = m.get(x, y + 1)
        south = m.get(x, y - 1)
        if turf_of(north).startswith("/turf/wall/wood") and "/ship/" in area_of(north):
            add(m, x, y, WAKE + "{dir = 1}")
        elif turf_of(south).startswith("/turf/wall/wood") and "/ship/" in area_of(south):
            add(m, x, y, WAKE)


# --- what must not change --------------------------------------------------------
def invariants(m):
    areas = {(x, y, z): area_of(a) for x, y, z, a in m.tiles()}
    kept = Counter()
    for x, y, z, atoms in m.tiles():
        for o in objs_of(atoms):
            if any(t in o for t in ("/obj/effect/landmark", "/obj/structure/multiz", "/obj/structure/cannon",
                                    "/obj/structure/closet/crate/cannonball", "/obj/map_metadata",
                                    "/obj/structure/simple_door", "/obj/structure/vending")):
                kept[(x, y, z, o)] += 1
    lower = tuple(tuple(row) for z in sorted(m.levels) if z != DECK_Z for row in m.levels[z])
    return areas, kept, lower


def facing_guns(m):
    """Count guns per ship and facing, by the rule the broadside code uses."""
    def ship(x, y):
        a = area_of(m.get(x, y))
        return a[:a.index("/ship") + 5] if "/ship" in a else None

    out = Counter()
    for x, y, _, atoms in m.tiles(DECK_Z):
        for o in objs_of(atoms):
            if o.startswith("/obj/structure/cannon"):
                north = "dir = 1" in o
                s = ship(x, y) or ship(x, y - 1 if north else y + 1)
                assert s, "gun at %d,%d belongs to no ship" % (x, y)
                out[(s, "north" if north else "south")] += 1
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--check", action="store_true", help="exit 1 if the map is not already dressed")
    args = ap.parse_args()

    before_text = MAP.read_text()
    m = Dmm(before_text)
    assert m.dumps() == Dmm(m.dumps()).dumps()
    before = invariants(m)

    french_ship(m)
    pirate_ship(m)
    sea(m)

    assert invariants(m) == before, "a gameplay invariant changed"
    guns = facing_guns(m)
    assert guns[("/area/caribbean/british/ship", "north")] >= 6, guns
    assert guns[("/area/caribbean/pirates/ship", "south")] >= 6, guns
    after_text = m.dumps()
    if args.check:
        if after_text != before_text:
            print("naval.dmm is not dressed; run tools/naval_battle/dress_map.py")
            return 1
        print("naval.dmm is dressed")
        return 0
    MAP.write_text(after_text)
    print("wrote %s (%s)" % (MAP.relative_to(ROOT), ", ".join("%s %s: %d" % (s.split("/")[3], d, n)
                                                               for (s, d), n in sorted(guns.items()))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
