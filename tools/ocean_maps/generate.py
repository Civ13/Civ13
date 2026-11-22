"""Write the ocean region maps (maps/nomads/nomads_ocean_<id>.dmm) from the world links table.

An ocean is one level of deep salt water (docs/ocean-regions.md). The map holds
nothing else but a small rock in the middle where a traveller with nowhere
better to stand is put down, pack ice where the table asks for it, and
breakers round each inset (an island land's waters inside this ocean: sailing
into them crosses to that land). Islets, reefs and wrecks are not drawn here;
the game raises them near ships.

    python3 tools/ocean_maps/generate.py            # rewrite every ocean map
    python3 tools/ocean_maps/generate.py --check    # exit 1 if any is stale
"""
import argparse
import random
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE.parent))

from world_links.links import load  # noqa: E402

OUT = ROOT / 'maps' / 'nomads'
WATER = '/turf/floor/beach/water/deep/saltwater'
ICE = '/turf/floor/beach/water/ice/salty'
BREAKERS = '/turf/floor/beach/water/deep/saltwater/breakers'
SAND = '/turf/floor/beach/sand'
ROCK = '/obj/structure/wild/rock'


def area(ocean):
    return '/area/caribbean/nomads/ocean/cold' if ocean.get('cold') else '/area/caribbean/nomads/ocean'


def keys_for(oid, ocean):
    a = area(ocean)
    return {
        'a': '(%s,%s)' % (WATER, a),
        'b': '(/obj/map_metadata/nomads/ocean/%s,%s,%s)' % (oid, WATER, a),
        'c': '(%s,%s)' % (BREAKERS, a),
        'd': '(%s,%s)' % (ICE, a),
        'e': '(%s,%s)' % (SAND, a),
        'f': '(%s,%s,%s)' % (ROCK, SAND, a),
        'g': '(/obj/effect/landmark{icon_state = "x3"; name = "JoinLateCiv"},%s,%s)' % (SAND, a),
    }


def grid(oid, ocean):
    """rows[y - 1][x - 1] of keys, y counted north."""
    w, h = ocean['size']
    rows = [['a'] * w for _ in range(h)]
    dice = random.Random(ocean.get('seed', 1))
    ice = ocean.get('ice')
    if ice:
        # Pack ice along one edge that leads nowhere: solid near the edge, its
        # margin wandering in and out, then loose floes with leads of open water.
        side, depth = ice
        reach = depth // 2
        for x in range(w):
            reach = max(depth // 4, min(depth, reach + dice.choice((-1, 0, 0, 1))))
            for d in range(reach):
                y = h - 1 - d if side == 'north' else d
                rows[y][x] = 'd'
        for _ in range(w * depth // 60):
            fx = dice.randrange(w)
            fd = dice.randrange(depth // 2, depth * 2)
            r = dice.randint(1, 4)
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    if dx * dx + dy * dy <= r * r and 0 <= fx + dx < w and 0 <= fd + dy < h // 2:
                        y = h - 1 - (fd + dy) if side == 'north' else fd + dy
                        rows[y][fx + dx] = 'd'
    for inset in ocean.get('insets', []):
        x0, y0, x1, y1 = inset['box']
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                rows[y - 1][x - 1] = 'c'
    # The rock in the middle: a few tiles of sand, two outcrops, one landing spot.
    cx, cy = ocean.get('rock', (w // 2, h // 2))
    for dy in range(-3, 4):
        for dx in range(-3, 4):
            if abs(dx) + abs(dy) <= 4:
                rows[cy + dy - 1][cx + dx - 1] = 'e'
    rows[cy + 1 - 1][cx - 2 - 1] = 'f'
    rows[cy - 2 - 1][cx + 1 - 1] = 'f'
    rows[cy - 1][cx - 1] = 'g'
    rows[0][0] = 'b'
    return rows


def render(oid, ocean):
    rows = grid(oid, ocean)
    w, h = ocean['size']
    head = ['// Ocean region map: %s, %d x %d, one level of deep salt water (docs/ocean-regions.md).' % (ocean['name'], w, h),
            '// Written by tools/ocean_maps/generate.py from tools/world_links/world_links.json; do not edit by hand.']
    used = sorted({k for r in rows for k in r})
    keys = keys_for(oid, ocean)
    head += ['"%s" = %s' % (k, keys[k]) for k in used]
    body = '\n'.join(''.join(r) for r in reversed(rows))
    return '\n'.join(head) + '\n\n(1,1,1) = {"\n' + body + '\n"}\n'


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--check', action='store_true', help='exit 1 if any ocean map is stale')
    args = parser.parse_args(argv)
    table = load()
    stale = []
    for oid, ocean in table['oceans'].items():
        path = OUT / ('nomads_ocean_%s.dmm' % oid)
        text = render(oid, ocean)
        current = path.read_text(encoding='utf-8').replace('\r\n', '\n') if path.exists() else None
        if current == text:
            continue
        if args.check:
            stale.append(str(path.relative_to(ROOT)))
        else:
            OUT.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding='utf-8', newline='\n')
            print('wrote', path.relative_to(ROOT))
    if stale:
        print('stale: %s; run python3 tools/ocean_maps/generate.py' % ', '.join(stale))
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
