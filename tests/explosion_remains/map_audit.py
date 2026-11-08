"""Classify every multi-level map's levels the way explosion_remains.dm does.

A level is above the ground when it has a level below and at least 1/20 of
the cells sampled every 4 tiles are open air (broken_floor or /turf/sky).
Explosions there leave plating instead of the area's earth base turf.

    python3 tests/explosion_remains/map_audit.py            # table
    python3 tests/explosion_remains/map_audit.py --check    # exit 1 on a known map regression
"""
import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STEP = 4
RATIO = 20
OPEN = re.compile(r'/turf/floor/broken_floor\b|/turf/sky\b')
# Levels players reported or that must keep ground behaviour.
EXPECTED = {
    'maps/1943/reichstag.dmm': {1: False, 2: True, 3: True, 4: True},
    'maps/1943/reichflakturm.dmm': {1: False, 2: True, 3: True, 4: True, 5: True},
    'maps/1969/yeltsin.dmm': {1: False, 2: True, 3: True, 4: True},
    'maps/1943/pavlov_house.dmm': {1: False, 2: True},
    'maps/2013/capitol_hill.dmm': {1: False, 2: False, 3: True, 4: True},
    'maps/nomads/nomads_gaia.dmm': {1: False, 2: False},
    'maps/1943/iwo_jima.dmm': {1: False, 2: False},
    'maps/1969/pepelsibirsk.dmm': {1: False, 2: False, 3: True},
}


def levels(path):
    text = path.read_text(encoding='utf-8', errors='replace')
    keys = {m.group(1): m.group(2) for m in re.finditer(r'^"(\w+)" = \((.*?)\)\n', text, re.M | re.S)}
    if not keys:
        return {}
    width = len(next(iter(keys)))
    grids = {}
    for m in re.finditer(r'^\((\d+),(\d+),(\d+)\) = \{"\n(.*?)\n"\}', text, re.M | re.S):
        x0, y0, z = int(m.group(1)), int(m.group(2)), int(m.group(3))
        rows = m.group(4).split('\n')
        cells = grids.setdefault(z, {})
        height = len(rows)
        for row_index, row in enumerate(rows):
            y = y0 + height - 1 - row_index
            for column in range(0, len(row), width):
                cells[(x0 + column // width, y)] = keys.get(row[column:column + width], '')
    return grids


def classify(path):
    grids = levels(path)
    result = {}
    for z, cells in sorted(grids.items()):
        if z == 1:
            result[z] = (False, 0, 0)
            continue
        maxx = max(x for x, _ in cells)
        maxy = max(y for _, y in cells)
        total = opened = 0
        for x in range(1, maxx + 1, STEP):
            for y in range(1, maxy + 1, STEP):
                total += 1
                if OPEN.search(cells.get((x, y), '')):
                    opened += 1
        result[z] = (bool(total) and opened * RATIO >= total, opened, total)
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    failures = []
    for path in sorted((ROOT / 'maps').rglob('*.dmm')):
        rel = path.relative_to(ROOT).as_posix()
        if '/WIP/' in rel or rel.startswith('maps/zones/variations/'):
            continue
        result = classify(path)
        if len(result) < 2:
            continue
        if not args.check:
            print(rel + '  ' + ' '.join(f'z{z}:{"AIR" if above else "ground"}({opened}/{total})' for z, (above, opened, total) in result.items()))
        for z, expected in EXPECTED.get(rel, {}).items():
            if result.get(z, (None,))[0] != expected:
                failures.append(f'{rel} z{z}: expected {"above ground" if expected else "ground"}')
    missing = [rel for rel in EXPECTED if not (ROOT / rel).is_file()]
    failures += [f'{rel}: missing' for rel in missing]
    for failure in failures:
        print('FAIL ' + failure)
    if failures:
        return 1
    print('PASS explosion remains map audit')
    return 0


if __name__ == '__main__':
    sys.exit(main())
