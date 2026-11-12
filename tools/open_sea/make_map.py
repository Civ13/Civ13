#!/usr/bin/env python3
"""Writes maps/sea/open_sea.dmm, the map of an open-sea region.

The map is one level of rock under one level of deep salt water, cut into
square sea cells by tide races (code/modules/naval/open_sea.dm). It holds no
land: the game raises the home island in the middle cell the first time the
world boots, and islands and wrecks in the other cells as ships reach them.

The cell size and tide race width must match SEA_CELL_PITCH and
SEA_CELL_MARGIN in code/__defines/naval.dm; --check compares them.

    python3 tools/open_sea/make_map.py            # rewrite the map
    python3 tools/open_sea/make_map.py --check    # exit 1 if it is stale
"""
import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "maps" / "sea" / "open_sea.dmm"
DEFINES = ROOT / "code" / "__defines" / "naval.dm"
CELLS = 4  # cells along each side

KEYS = {
    "a": "(/turf/floor/dirt/underground,/area/caribbean/void/caves)",
    "b": "(/obj/map_metadata/nomads/open_sea,/turf/floor/dirt/underground,/area/caribbean/void/caves)",
    "c": "(/turf/floor/beach/water/deep/saltwater,/area/caribbean/nomads/forest)",
    "d": "(/turf/floor/beach/water/deep/saltwater/tide_race,/area/caribbean/nomads/forest)",
    "e": '(/obj/effect/landmark{icon_state = "x3"; name = "JoinLateCiv"},/turf/floor/beach/water/deep/saltwater,/area/caribbean/nomads/forest)',
}


def define(name):
    found = re.search(r"^#define %s (\d+)" % name, DEFINES.read_text(encoding="utf-8"), re.M)
    if not found:
        raise SystemExit("%s is not defined in %s" % (name, DEFINES))
    return int(found.group(1))


def build():
    pitch = define("SEA_CELL_PITCH")
    margin = define("SEA_CELL_MARGIN")
    size = pitch * CELLS
    # The home waters are the middle cell, as sea_home_cell() picks it.
    home = (CELLS // 2) * CELLS + CELLS // 2
    hx = (home % CELLS) * pitch + (1 + pitch) // 2
    hy = (home // CELLS) * pitch + (1 + pitch) // 2
    lines = ["// Open-sea region map: %d x %d, %d by %d sea cells of %d tiles with a %d-tile tide race" % (size, size, CELLS, CELLS, pitch, margin),
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
            if px < margin or py < margin or px >= pitch - margin or py >= pitch - margin:
                row.append("d")
            elif abs(x - hx) <= 1 and abs(y - hy) <= 1:
                row.append("e")
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
