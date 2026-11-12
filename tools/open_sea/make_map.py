#!/usr/bin/env python3
"""Writes maps/sea/open_sea.dmm, the map of an open-sea region.

The map is one level of rock under one level of deep salt water, cut into
square sea cells by tide races (code/modules/naval/open_sea.dm). Its only
land is the home island, drawn here in the middle of the home waters; the game
raises islands and wrecks in the other cells as ships reach them.

The cell size and tide race width must match SEA_CELL_PITCH and
SEA_CELL_MARGIN in code/__defines/naval.dm; --check compares them.

    python3 tools/open_sea/make_map.py            # rewrite the map
    python3 tools/open_sea/make_map.py --check    # exit 1 if it is stale
"""
import argparse
import math
import random
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "maps" / "sea" / "open_sea.dmm"
DEFINES = ROOT / "code" / "__defines" / "naval.dm"
CELLS = 5  # cells along each side

KEYS = {
    "a": "(/turf/floor/dirt/underground,/area/caribbean/void/caves)",
    "b": "(/obj/map_metadata/nomads/open_sea,/turf/floor/dirt/underground,/area/caribbean/void/caves)",
    "c": "(/turf/floor/beach/water/deep/saltwater,/area/caribbean/nomads/forest)",
    "d": "(/turf/floor/beach/water/deep/saltwater/tide_race,/area/caribbean/nomads/forest)",
    "e": '(/obj/effect/landmark{icon_state = "x3"; name = "JoinLateCiv"},/turf/floor/grass,/area/caribbean/nomads/forest)',
    # The home island.
    "f": "(/turf/floor/beach/water/shallowsaltwater,/area/caribbean/nomads/forest)",
    "g": "(/turf/floor/beach/sand,/area/caribbean/nomads/forest)",
    "h": "(/turf/floor/grass,/area/caribbean/nomads/forest)",
    "i": "(/turf/floor/beach/water,/area/caribbean/nomads/forest)",
    "j": "(/turf/floor/dirt/underground,/area/caribbean/nomads/forest)",
    "k": "(/obj/structure/wild/tree/live_tree,/turf/floor/grass,/area/caribbean/nomads/forest)",
    "l": "(/obj/structure/wild/rock,/turf/floor/grass,/area/caribbean/nomads/forest)",
    "m": "(/obj/structure/wild/berrybush/tinto,/turf/floor/grass,/area/caribbean/nomads/forest)",
    "n": "(/obj/structure/wild/tallgrass,/turf/floor/grass,/area/caribbean/nomads/forest)",
    "o": "(/obj/structure/wild/palm,/turf/floor/beach/sand,/area/caribbean/nomads/forest)",
    "p": "(/obj/structure/wild/rock,/turf/floor/beach/sand,/area/caribbean/nomads/forest)",
    "q": "(/obj/effect/spawner/mobspawner/turkeys,/turf/floor/grass,/area/caribbean/nomads/forest)",
    "r": "(/obj/structure/sea_office,/turf/floor/grass,/area/caribbean/nomads/forest)",
}

ISLAND_SEED = 13
ISLAND_CLEAR = 12     # Open water kept between the island's widest cape and the tide race.


def island(cx, cy, half):
    """The home island as {(x, y): key}: a wobbly shore with a ring of
    shallows, sand, then grass with woods, ponds, outcrops of rock to mine and
    a clearing where arrivals land. The same every time."""
    dice = random.Random(ISLAND_SEED)
    # The shore wanders out to 1.2 times the half-width and the shallows 1.08 times past that.
    radius = int((half - ISLAND_CLEAR) / (1.2 * 1.08))
    phases = [dice.uniform(0, 2 * math.pi) for _ in range(4)]

    def blobs(count, low, high, keep_out):
        found = []
        while len(found) < count:
            bx = dice.randint(-radius * 2 // 3, radius * 2 // 3)
            by = dice.randint(-radius * 2 // 3, radius * 2 // 3)
            br = dice.randint(low, high)
            if math.hypot(bx, by) < keep_out + br:
                continue
            found.append((bx, by, br))
        return found

    ponds = blobs(12, 2, 6, 8)
    outcrops = blobs(10, 4, 8, 16)
    woods = blobs(20, 8, 18, 10)

    def inside(dx, dy, group):
        return any((dx - bx) ** 2 + (dy - by) ** 2 <= br * br for bx, by, br in group)

    tiles = {}
    grass = []
    for dx in range(-half, half + 1):
        for dy in range(-half, half + 1):
            angle = math.atan2(dy, dx)
            shape = (1 + 0.1 * math.sin(3 * angle + phases[0]) + 0.06 * math.sin(5 * angle + phases[1])
                     + 0.03 * math.sin(9 * angle + phases[2]) + 0.01 * math.sin(14 * angle + phases[3]))
            d = math.hypot(dx, dy) / radius / shape
            if d > 1.08:
                continue
            clear = abs(dx) <= 4 and abs(dy) <= 4
            if d > 1:
                key = "f"
            elif d > 0.93:
                key = "o" if dice.random() < 0.04 else "p" if dice.random() < 0.01 else "g"
            elif d < 0.8 and inside(dx, dy, ponds):
                key = "i"
            elif d < 0.8 and inside(dx, dy, outcrops):
                key = "j"
            elif clear:
                key = "h"
            else:
                thick = inside(dx, dy, woods)
                roll = dice.random()
                if roll < (0.22 if thick else 0.05):
                    key = "k"
                elif roll < (0.25 if thick else 0.07):
                    key = "l"
                elif roll < (0.28 if thick else 0.09):
                    key = "m"
                elif roll < (0.34 if thick else 0.13):
                    key = "n"
                else:
                    key = "h"
                    grass.append((cx + dx, cy + dy))
            tiles[(cx + dx, cy + dy)] = key
    for spot in dice.sample(grass, 10):
        tiles[spot] = "q"
    tiles[(cx + 3, cy + 3)] = "r"
    return tiles


def define(name):
    found = re.search(r"^#define %s (\d+)" % name, DEFINES.read_text(encoding="utf-8"), re.M)
    if not found:
        raise SystemExit("%s is not defined in %s" % (name, DEFINES))
    return int(found.group(1))


def build():
    pitch = define("SEA_CELL_PITCH")
    margin = define("SEA_CELL_MARGIN")
    span = define("SEA_HOME_SPAN")
    size = pitch * CELLS
    # The home waters: a block of cells round the middle one, as sea_home_block() picks it.
    reach = (max(1, span) - 1) // 2
    lo = max(0, CELLS // 2 - reach)
    hi = min(CELLS - 1, CELLS // 2 + reach)
    # The home waters are the middle cell, as sea_home_cell() picks it.
    home = (CELLS // 2) * CELLS + CELLS // 2
    hx = (home % CELLS) * pitch + (1 + pitch) // 2
    hy = (home // CELLS) * pitch + (1 + pitch) // 2
    land = island(hx, hy, ((hi - lo + 1) * pitch - 2 * margin) // 2)
    lines = ["// Open-sea region map: %d x %d, %d by %d sea cells of %d tiles with a %d-tile tide race, the middle %d by %d the home waters" % (size, size, CELLS, CELLS, pitch, margin, hi - lo + 1, hi - lo + 1),
             "// (code/modules/naval/open_sea.dm). Written by tools/open_sea/make_map.py; do not edit by hand."]
    lines += ['"%s" = %s' % (key, KEYS[key]) for key in sorted(KEYS)]
    lines.append("")
    under = []
    sea = []
    for y in range(size, 0, -1):
        under.append("".join("b" if (x, y) == (1, 1) else "a" for x in range(1, size + 1)))
        row = []
        for x in range(1, size + 1):
            px = (x - 1) % pitch
            py = (y - 1) % pitch
            if lo <= (x - 1) // pitch <= hi and lo <= (y - 1) // pitch <= hi:
                race = (x <= lo * pitch + margin or y <= lo * pitch + margin
                        or x > (hi + 1) * pitch - margin or y > (hi + 1) * pitch - margin)
            else:
                race = px < margin or py < margin or px >= pitch - margin or py >= pitch - margin
            if race:
                row.append("d")
            elif abs(x - hx) <= 1 and abs(y - hy) <= 1:
                row.append("e")
            elif (x, y) in land:
                row.append(land[(x, y)])
            else:
                row.append("c")
        sea.append("".join(row))
    for z, rows in ((1, under), (2, sea)):
        lines.append('(1,1,%d) = {"' % z)
        lines += rows
        lines.append('"}')
        lines.append("")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="exit 1 if the map on disk differs")
    args = parser.parse_args()
    text = build()
    if args.check:
        if not OUT.exists() or OUT.read_text(encoding="utf-8") != text:
            print("maps/sea/open_sea.dmm is stale: run python3 tools/open_sea/make_map.py")
            return 1
        print("maps/sea/open_sea.dmm is current")
        return 0
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(text, encoding="utf-8", newline="\n")
    print("wrote %s" % OUT.relative_to(ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
