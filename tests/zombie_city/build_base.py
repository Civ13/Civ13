"""Generate maps/zombie_city/zombie_city.dmm, the blank plain the city is made on.

The map is 200 x 200 tiles of dirt inside an indestructible rim, with the Zombie
City metadata object on the bottom-left rim tile, under a second level of open
sky for the upper floors. Everything else is made at round start by
code/modules/zombie_city/generator.dm. Run from the
repository root with a verified interpreter:

    python3 -I -B tests/zombie_city/build_base.py [--check]

Do not hand-edit the generated map; change this file and regenerate.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
MAP_PATH = ROOT / "maps/zombie_city/zombie_city.dmm"

WIDTH = 200
HEIGHT = 200
AREA = "/area/caribbean/zombie_city"
DIRT = "/turf/floor/dirt"
RIM = "/turf/wall/indestructable"
METADATA = "/obj/map_metadata/nomads/zombie_city"
SKY = "/turf/sky"
LEVELS = 2


def build() -> str:
    definitions = [
        ('"a"', f"({DIRT},{AREA})"),
        ('"b"', f"({RIM},{AREA})"),
        ('"c"', f"({METADATA},{RIM},{AREA})"),
        ('"d"', f"({SKY},{AREA})"),
    ]
    lines = [f"{key} = {value}" for key, value in definitions]
    lines.append("")
    lines.append('(1,1,1) = {"')
    for y in range(HEIGHT, 0, -1):
        row = []
        for x in range(1, WIDTH + 1):
            if x == 1 and y == 1:
                row.append("c")
            elif x in (1, WIDTH) or y in (1, HEIGHT):
                row.append("b")
            else:
                row.append("a")
        lines.append("".join(row))
    lines.append('"}')
    for level in range(2, LEVELS + 1):
        lines.append("")
        lines.append(f'(1,1,{level}) = {{"')
        for y in range(HEIGHT):
            lines.append("d" * WIDTH)
        lines.append('"}')
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="fail if the checked-in map differs")
    args = parser.parse_args()
    text = build()
    if args.check:
        current = MAP_PATH.read_text(encoding="utf-8") if MAP_PATH.exists() else None
        if current != text:
            print(f"{MAP_PATH} differs from build_base.py output", file=sys.stderr)
            return 1
        print(f"{MAP_PATH} matches")
        return 0
    MAP_PATH.parent.mkdir(parents=True, exist_ok=True)
    MAP_PATH.write_text(text, encoding="utf-8", newline="\n")
    print(f"wrote {MAP_PATH} ({WIDTH}x{HEIGHT}x{LEVELS})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
