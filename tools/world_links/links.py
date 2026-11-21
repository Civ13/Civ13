"""Read and check the world links table (docs/world-links.md).

The table names every land and ocean of the earth group (region ids as in the
host's earth.json) and the stretches of map edge that lead from one to another.
It is the one source for code/modules/persistence/world_links.dm (written by
build.py), the shard-group tools and the launcher.
"""
import json
from pathlib import Path

TABLE = Path(__file__).resolve().with_name('world_links.json')
SIDES = ('north', 'south', 'east', 'west')
OPPOSITE = {'north': 'south', 'south': 'north', 'east': 'west', 'west': 'east'}
COASTS = ('N', 'S', 'E', 'W')
KINDS = ('walk', 'sail')


def _end(end, where):
    if not (isinstance(end, list) and len(end) == 4):
        raise ValueError('%s: an end is [region, side, from, to]' % where)
    region, side, lo, hi = end
    if not isinstance(region, str) or not region:
        raise ValueError('%s: no region id' % where)
    if side not in SIDES:
        raise ValueError('%s: side %r is not one of %s' % (where, side, ', '.join(SIDES)))
    if not all(isinstance(v, (int, float)) and not isinstance(v, bool) for v in (lo, hi)) or not 0 <= lo < hi <= 1:
        raise ValueError('%s: stretch %r to %r is not inside 0 to 1' % (where, lo, hi))
    return region, side, float(lo), float(hi)


def load(path=TABLE):
    """The checked table: {'lands': {...}, 'links': [{'kind', 'a', 'b'}]}."""
    data = json.loads(Path(path).read_text(encoding='utf-8'))
    lands = data.get('lands')
    if not isinstance(lands, dict) or not lands:
        raise ValueError('no lands')
    for rid, land in lands.items():
        chart = land.get('chart')
        if not (isinstance(chart, list) and len(chart) == 2 and all(isinstance(v, int) for v in chart)):
            raise ValueError('%s: chart is [x, y]' % rid)
        coasts = land.get('coasts', [])
        if not isinstance(coasts, list) or any(c not in COASTS for c in coasts) or len(set(coasts)) != len(coasts):
            raise ValueError('%s: coasts are distinct N, S, E or W' % rid)
        if not isinstance(land.get('flight', False), bool):
            raise ValueError('%s: flight is true or false' % rid)
    oceans = data.get('oceans', {})
    if not isinstance(oceans, dict):
        raise ValueError('oceans is a table')
    for oid, ocean in oceans.items():
        if oid in lands:
            raise ValueError('%s is both a land and an ocean' % oid)
        size = ocean.get('size')
        if not (isinstance(size, list) and len(size) == 2 and all(isinstance(v, int) and 100 <= v <= 2000 for v in size)):
            raise ValueError('%s: size is [width, height], 100 to 2000 tiles' % oid)
        if not isinstance(ocean.get('name'), str) or not ocean['name']:
            raise ValueError('%s: no name' % oid)
        chart = ocean.get('chart')
        if not (isinstance(chart, list) and len(chart) == 2 and all(isinstance(v, int) for v in chart)):
            raise ValueError('%s: chart is [x, y]' % oid)
        for side in ocean.get('wrap', []):
            if side not in ('west', 'south'):
                raise ValueError('%s: wrap names west (joins east) or south (joins north)' % oid)
        ice = ocean.get('ice')
        if ice is not None and not (isinstance(ice, list) and len(ice) == 2 and ice[0] in SIDES and isinstance(ice[1], int)):
            raise ValueError('%s: ice is [side, depth]' % oid)
        boxes = []
        for inset in ocean.get('insets', []):
            land = inset.get('land')
            box = inset.get('box')
            if land not in lands:
                raise ValueError('%s: inset land %r is not a land' % (oid, land))
            if not (isinstance(box, list) and len(box) == 4 and all(isinstance(v, int) for v in box)):
                raise ValueError('%s: inset box is [x0, y0, x1, y1]' % oid)
            x0, y0, x1, y1 = box
            # Room all round: ships come out beside it, never on the map's edge.
            if not (10 < x0 < x1 < size[0] - 10 and 10 < y0 < y1 < size[1] - 10):
                raise ValueError('%s: the %s inset must lie inside the map with room round it' % (oid, land))
            for other in boxes:
                if not (x1 + 10 < other[0] or other[2] + 10 < x0 or y1 + 10 < other[1] or other[3] + 10 < y0):
                    raise ValueError('%s: insets lie too close together' % oid)
            boxes.append(box)
    regions = set(lands) | set(oceans)
    links = []
    for i, link in enumerate(data.get('links', [])):
        where = 'link %d' % (i + 1)
        if link.get('kind') not in KINDS:
            raise ValueError('%s: kind is one of %s' % (where, ', '.join(KINDS)))
        a = _end(link.get('a'), where)
        b = _end(link.get('b'), where)
        if a[0] == b[0]:
            raise ValueError('%s: a region does not link to itself' % where)
        if b[1] != OPPOSITE[a[1]]:
            raise ValueError('%s: %s %s must face %s %s' % (where, a[0], a[1], b[0], OPPOSITE[a[1]]))
        for end in (a, b):
            if end[0] not in regions:
                raise ValueError('%s: %s is not a land or ocean in the table' % (where, end[0]))
        links.append({'kind': link['kind'], 'a': a, 'b': b})
    # Stretches of one edge never overlap, and a region leads only once to another per edge.
    spans = {}
    for link in links:
        for here, there in ((link['a'], link['b']), (link['b'], link['a'])):
            spans.setdefault((here[0], here[1]), []).append((here[2], here[3], there[0]))
    for (rid, side), stretches in spans.items():
        stretches.sort()
        names = [s[2] for s in stretches]
        if len(set(names)) != len(names):
            raise ValueError('%s %s leads to the same region twice' % (rid, side))
        for (_, a_hi, _), (b_lo, _, _) in zip(stretches, stretches[1:]):
            if a_hi > b_lo:
                raise ValueError('%s %s: stretches overlap' % (rid, side))
    return {'lands': lands, 'oceans': oceans, 'links': links}


def crossings(table, kind=None):
    """{region: {side: [(dest, from, to, kind, dest_from, dest_to)]}}, both ways round.
    With kind, only links of that kind."""
    out = {}
    for link in table['links']:
        if kind and link['kind'] != kind:
            continue
        for here, there in ((link['a'], link['b']), (link['b'], link['a'])):
            out.setdefault(here[0], {}).setdefault(here[1], []).append(
                (there[0], here[2], here[3], link['kind'], there[2], there[3]))
    for sides in out.values():
        for stretches in sides.values():
            stretches.sort(key=lambda s: s[1])
    return out
