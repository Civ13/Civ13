"""Walking between lands over shared map edges (code/modules/persistence/region_edge.dm).

Every edge crossing a map names must be answered by the land beyond it on the
facing edge, and both stretches must have dry ground to walk onto.
Run: python3 -m unittest discover -s tests/edge_crossings
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
META = ROOT / 'code/game/objects/map_metadata/nomads'

# Region id (earth.json, continent_layout) = (metadata file, map type, map file).
REGIONS = {
    'northamerica': ('nomads_americas.dm', 'americas_north', 'maps/nomads/nomads_americas_north.dmm'),
    'southamerica': ('nomads_americas.dm', 'americas_south', 'maps/nomads/nomads_americas_south.dmm'),
    # The Earth-shaped Europe, Asia and Africa (docs/earth-continents.md); Africa
    # takes the place of the older Desert and Jungle regions.
    'europe': ('nomads_earth.dm', 'earth_europe', 'maps/nomads/nomads_earth_europe.dmm'),
    'africa': ('nomads_earth.dm', 'earth_africa', 'maps/nomads/nomads_earth_africa.dmm'),
    'asia': ('nomads_earth.dm', 'earth_asia', 'maps/nomads/nomads_earth_asia.dmm'),
    'gaia': ('nomads_gaia.dm', None, 'maps/nomads/nomads_gaia.dmm'),
}
OPPOSITE = {'north': 'south', 'south': 'north', 'east': 'west', 'west': 'east'}
# The land links walked over (only where the land carries on).
EXPECTED = {
    ('northamerica', 'south', 'southamerica'), ('southamerica', 'north', 'northamerica'),
    ('europe', 'east', 'asia'), ('asia', 'west', 'europe'),
    ('asia', 'west', 'africa'), ('africa', 'east', 'asia'),
}


def metadata_block(region):
    file, kind, _ = REGIONS[region]
    text = (META / file).read_text(encoding='utf-8')
    if kind:
        text = text.split(f'/obj/map_metadata/nomads/{kind}\n', 1)[1].split('\n/obj/', 1)[0]
    else:
        text = text.split('\n/obj/map_metadata/nomads/', 2)[1] if text.count('\n/obj/map_metadata/nomads/') > 1 else text
    return text


def parse_crossings(region):
    """{side: [(id, lo, hi)]} and the crossing level for a region."""
    block = metadata_block(region)
    m = re.search(r'^\tedge_crossings = list\((.*)\)$', block, re.M)
    z = re.search(r'^\tedge_crossing_z = (\d+)$', block, re.M)
    out = {}
    if m:
        body = m.group(1)
        for side, rest in re.findall(r'"(north|south|east|west)" = ("[a-z]+"|list\((?:[^()]|\([^()]*\))*\))', body):
            if rest.startswith('"'):
                out[side] = [(rest.strip('"'), 0.0, 1.0)]
            else:
                out[side] = [(i, float(a), float(b)) for i, a, b in re.findall(r'"([a-z]+)" = list\(([\d.]+), ([\d.]+)\)', rest)]
    return out, int(z.group(1)) if z else 1


def load_level(path, z):
    text = (ROOT / path).read_text(encoding='utf-8')
    keys = {}
    for m in re.finditer(r'^"(\w+)" = \((.*)\)$', text, re.M):
        keys[m.group(1)] = next((p for p in re.findall(r'(/[\w/]+)', m.group(2)) if p.startswith('/turf')), '')
    width = len(next(iter(keys)))
    m = re.search(r'^\(1,1,%d\) = \{"\n(.*?)\n"\}' % z, text, re.M | re.S)
    rows = [[keys[r[i:i + width]] for i in range(0, len(r), width)] for r in m.group(1).split('\n')]
    return rows[::-1]  # rows[y - 1][x - 1], y counted north


def dry(turf):
    return (turf.startswith('/turf/floor') and not turf.startswith('/turf/floor/dirt/underground')
            and 'lava' not in turf and not turf.startswith('/turf/floor/beach/water'))


def edge_row(rows, side):
    if side == 'south':
        return rows[0]
    if side == 'north':
        return rows[-1]
    return [r[0] if side == 'west' else r[-1] for r in rows]


def stretch_dry(rows, side, lo, hi):
    row = edge_row(rows, side)
    n = len(row)
    first = min(max(round(lo * n) + 1, 1), n)
    last = min(max(round(hi * n), first), n)
    return [a for a in range(first, last + 1) if dry(row[a - 1])]


class EdgeCrossingTests(unittest.TestCase):
    def test_links_are_the_land_links(self):
        found = set()
        for region in REGIONS:
            crossings, _ = parse_crossings(region)
            for side, stretches in crossings.items():
                for dest, _, _ in stretches:
                    found.add((region, side, dest))
        self.assertEqual(found, EXPECTED)

    def test_every_link_is_answered_and_walkable(self):
        cache = {}
        for region, side, dest in sorted(EXPECTED):
            crossings, z = parse_crossings(region)
            stretch = next(s for s in crossings[side] if s[0] == dest)
            back, _ = parse_crossings(dest)
            self.assertIn(region, [s[0] for s in back.get(OPPOSITE[side], [])], f'{dest} does not lead back to {region}')
            key = (region, z)
            if key not in cache:
                cache[key] = load_level(REGIONS[region][2], z)
            ground = stretch_dry(cache[key], side, stretch[1], stretch[2])
            self.assertGreaterEqual(len(ground), 10, f'{region} {side} edge toward {dest} has little dry ground')

    def test_stretches_on_one_edge_do_not_overlap(self):
        for region in REGIONS:
            crossings, _ = parse_crossings(region)
            for side, stretches in crossings.items():
                spans = sorted((lo, hi) for _, lo, hi in stretches)
                for (a_lo, a_hi), (b_lo, b_hi) in zip(spans, spans[1:]):
                    self.assertLessEqual(a_hi, b_lo, f'{region} {side} stretches overlap')

    def test_source_walks_the_surface_level(self):
        edge = (ROOT / 'code/modules/persistence/region_edge.dm').read_text(encoding='utf-8')
        wagon = (ROOT / 'code/modules/persistence/region_edge_carriage.dm').read_text(encoding='utf-8')
        self.assertIn('/obj/map_metadata/var/edge_crossing_z = 1', edge)
        self.assertIn('T.z != map.edge_crossing_z', edge)
        self.assertIn('z != map.edge_crossing_z', wagon)
        self.assertNotIn('T.z != 1', edge)
        # The crossing carries the land it led to, so a walker turned back
        # comes out on the stretch they left from.
        self.assertIn('gate.crossing = list(side, region_edge_fraction(side, id, T), id)', edge)
        self.assertIn('gate.crossing = list(side, region_edge_fraction(side, id, T), id)', wagon)
        self.assertIn('E.len == 3', edge)
        self.assertIn('var/id = incoming ? P["from"] : E[3]', edge)


class SeaEdgeTests(unittest.TestCase):
    """Ships at the sea's edge: the helm, the hint and what counts as cargo."""

    def test_leftover_animation_is_not_cargo(self):
        crossing = (ROOT / 'code/modules/naval/ship_crossing.dm').read_text(encoding='utf-8')
        # Packing reads each deck and hold tile through sea_crossing_pack_tile().
        pack = crossing.split('/proc/sea_crossing_pack(')[1].split('\n/proc/')[0]
        self.assertIn('sea_crossing_pack_tile(', pack)
        tile = crossing.split('/proc/sea_crossing_pack_tile(')[1].split('\n/proc/')[0]
        self.assertIn('region_travel_ignorable(M)', tile)
        self.assertIn('!M.craft_cargo()', tile)
        generic = (ROOT / 'code/modules/persistence/region_travel_generic.dm').read_text(encoding='utf-8')
        ignorable = generic.split('/proc/region_travel_ignorable(')[1].split('\n/proc/')[0]
        for kind in ('/atom/movable/overlay', '/obj/chat_text', '/obj/effect', '/mob/observer'):
            self.assertIn('istype(M, %s)' % kind, ignorable)
        bubble = (ROOT / 'code/game/mob/living/chat_overlay.dm').read_text(encoding='utf-8')
        new = bubble.split('/obj/chat_text/New(')[1].split('\n/')[0]
        self.assertLess(new.index('loc = null'), new.index('..()'))
        self.assertNotIn('Destroy()', new)
        self.assertIn('/obj/chat_text/forceMove(', bubble)
        living = (ROOT / 'code/game/mob/living/living.dm').read_text(encoding='utf-8')
        self.assertNotIn('CT.forceMove(', living)
        # Ghosts and admin observers are not cargo either.
        self.assertLess(tile.index('region_travel_ignorable(M)'), tile.index('if (ismob(M))'))

    def test_refused_things_are_marked_on_deck(self):
        crossing = (ROOT / 'code/modules/naval/ship_crossing.dm').read_text(encoding='utf-8')
        pack = crossing.split('/proc/sea_crossing_pack(')[1].split('\n/proc/')[0]
        tile = crossing.split('/proc/sea_crossing_pack_tile(')[1].split('\n/proc/')[0]
        self.assertEqual(tile.count('refused |= '), tile.count('blocking |= '))
        self.assertLess(pack.index('sea_crossing_mark(S["blocking"])'), pack.index('return "Put these ashore first'))
        mark = crossing.split('/proc/sea_crossing_mark(')[1].split('\n/proc/')[0]
        self.assertIn('new(T)', mark)
        self.assertIn('QDEL_IN(P, 100)', mark)

    def test_big_maps_cross_and_bad_records_never_strip(self):
        crossing = (ROOT / 'code/modules/naval/ship_crossing.dm').read_text(encoding='utf-8')
        ok = crossing.split('/proc/sea_crossing_record_ok(')[1].split('\n/proc/')[0]
        self.assertNotIn('v > 1000', ok)
        self.assertIn('v > 4096', ok)
        # The packing half of a crossing (after any wake) is cross_away().
        cross = crossing.split('/obj/structure/hull_tiller/proc/cross_away(')[1].split('\n/')[0]
        self.assertLess(cross.index('if (!sea_crossing_record_ok(record))'), cross.index('sea_crossing_strip(src, TRUE, gate)'))
        self.assertIn('stays behind from the', cross)

    def test_spare_oar_points_to_the_helm(self):
        hull = (ROOT / 'code/modules/naval/built_hull.dm').read_text(encoding='utf-8')
        hand = hull.split('/obj/structure/hull_tiller/attack_hand(')[1].split('\n/obj/')[0]
        self.assertLess(hand.index('craft_at(get_turf(src))'), hand.index('commission_menu(H)'))
        self.assertIn('does not steer the [aboard.name]', hand)

    def test_edge_of_the_world_names_the_voyage(self):
        under_way = (ROOT / 'code/modules/craft/under_way.dm').read_text(encoding='utf-8')
        self.assertIn('last_refusal == "the edge of the world" && istype(body, /datum/craft_body/built)', under_way)
        self.assertIn('Set out on a voyage', under_way)


if __name__ == '__main__':
    unittest.main()
