"""Write code/modules/persistence/world_links.dm from world_links.json.

    python3 tools/world_links/build.py           # rewrite the DM table
    python3 tools/world_links/build.py --check   # exit 1 when it is stale
"""
import argparse
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

from world_links.links import crossings, load  # noqa: E402

ROOT = HERE.parents[1]
OUT = ROOT / 'code/modules/persistence/world_links.dm'


def num(v):
    v = float(v)
    return str(int(v)) if v == int(v) else ('%g' % v)


def render(table):
    lines = [
        '// ============================================================',
        '// The world links (docs/world-links.md)',
        '// ------------------------------------------------------------',
        '// Written by tools/world_links/build.py from tools/world_links/world_links.json.',
        '// Do not edit by hand: change the JSON and run the script.',
        '// ============================================================',
        '',
        '// Region id = the map edges that lead on, in the shape of',
        '// /obj/map_metadata/var/edge_crossings (region_edge.dm): side = list(region id =',
        '// list(from, to)), the stretch of that edge counted west to east or south to north.',
        'var/global/list/world_links = list(',
    ]
    table_links = crossings(table)
    regions = sorted(table_links)
    for i, rid in enumerate(regions):
        sides = table_links[rid]
        parts = []
        for side in sorted(sides):
            dests = ', '.join('"%s" = list(%s, %s)' % (s[0], num(s[1]), num(s[2])) for s in sides[side])
            parts.append('"%s" = list(%s)' % (side, dests))
        lines.append('\t"%s" = list(%s)%s' % (rid, ', '.join(parts), ',' if i < len(regions) - 1 else ''))
    lines += [
        ')',
        '',
        '// id = list(x, y, coasts, flight): x grows east, y grows north. coasts: the map',
        '// edges with open deep water along them, best first. flight: TRUE when the map',
        '// has a standing open-air level that aircraft fly on (aircraft_crossing.dm).',
        'var/global/list/continent_layout = list(',
    ]
    lands = list(table['lands'].items())
    for i, (rid, land) in enumerate(lands):
        coasts = ', '.join('"%s"' % c for c in land.get('coasts', []))
        lines.append('\t"%s" = list(%d, %d, list(%s), %s)%s' % (
            rid, land['chart'][0], land['chart'][1], coasts, 'TRUE' if land.get('flight') else 'FALSE',
            ',' if i < len(lands) - 1 else ''))
    lines.append(')')
    return '\n'.join(lines) + '\n'


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--check', action='store_true', help='exit 1 if the DM table is stale')
    args = parser.parse_args(argv)
    text = render(load())
    current = OUT.read_text(encoding='utf-8').replace('\r\n', '\n') if OUT.exists() else None
    if args.check:
        if current != text:
            print('%s is stale: run python3 tools/world_links/build.py' % OUT.relative_to(ROOT))
            return 1
        return 0
    if current != text:
        OUT.write_text(text, encoding='utf-8', newline='\n')
        print('wrote', OUT.relative_to(ROOT))
    return 0


if __name__ == '__main__':
    sys.exit(main())
