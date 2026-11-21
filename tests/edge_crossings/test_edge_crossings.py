"""Walking between lands over shared map edges (code/modules/persistence/region_edge.dm).

Every edge crossing a map names must be answered by the land beyond it on the
facing edge, and both stretches must have dry ground to walk onto.
Run: python3 -m unittest discover -s tests/edge_crossings
"""
import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))

from world_links import OPPOSITE, crossings, load  # noqa: E402
from world_links import build  # noqa: E402

# Region id (earth.json) = the map that region runs.
MAPS = {
    'northamerica': 'maps/nomads/nomads_americas_north.dmm',
    'southamerica': 'maps/nomads/nomads_americas_south.dmm',
    # The Earth-shaped lands (docs/earth-continents.md); Africa takes the place
    # of the older Desert and Jungle regions.
    'europe': 'maps/nomads/nomads_earth_europe.dmm',
    'africa': 'maps/nomads/nomads_earth_africa.dmm',
    'asia': 'maps/nomads/nomads_earth_asia.dmm',
    'oceania': 'maps/nomads/nomads_earth_oceania.dmm',
    'greenland': 'maps/nomads/nomads_earth_greenland.dmm',
    'antarctica': 'maps/nomads/nomads_earth_antarctica.dmm',
    'gaia': 'maps/nomads/nomads_gaia.dmm',
}
# The land links walked over (only where the land carries on).
EXPECTED = {
    ('northamerica', 'south', 'southamerica'), ('southamerica', 'north', 'northamerica'),
    ('europe', 'east', 'asia'), ('asia', 'west', 'europe'),
    ('asia', 'west', 'africa'), ('africa', 'east', 'asia'),
}
SURFACE_Z = {'gaia': 2}


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
    @classmethod
    def setUpClass(cls):
        cls.table = load()
        cls.links = crossings(cls.table)
        cls.levels = {}

    def level(self, region):
        if region not in self.levels:
            self.levels[region] = load_level(MAPS[region], SURFACE_Z.get(region, 1))
        return self.levels[region]

    def test_dm_table_is_written_from_the_json(self):
        self.assertEqual(build.main(['--check']), 0)
        dm = (ROOT / 'code/modules/persistence/world_links.dm').read_text(encoding='utf-8')
        self.assertIn('#include "code\\modules\\persistence\\world_links.dm"', (ROOT / 'civ13.dme').read_text(encoding='utf-8'))
        self.assertIn('var/global/list/world_links = list(', dm)
        self.assertIn('var/global/list/continent_layout = list(', dm)
        lanes = (ROOT / 'code/modules/naval/sea_lanes.dm').read_text(encoding='utf-8')
        self.assertNotIn('var/global/list/continent_layout', lanes)

    def test_walk_links_are_the_land_links(self):
        found = set()
        for region, sides in self.links.items():
            for side, stretches in sides.items():
                for s in stretches:
                    if s[3] == 'walk':
                        found.add((region, side, s[0]))
        self.assertEqual(found, EXPECTED)

    def test_every_walk_link_has_dry_ground_both_ends(self):
        for link in self.table['links']:
            if link['kind'] != 'walk':
                continue
            for region, side, lo, hi in (link['a'], link['b']):
                with self.subTest(region=region, side=side):
                    ground = stretch_dry(self.level(region), side, lo, hi)
                    self.assertGreaterEqual(len(ground), 10, f'{region} {side} stretch has little dry ground')

    def test_ends_face_each_other(self):
        for link in self.table['links']:
            self.assertEqual(link['b'][1], OPPOSITE[link['a'][1]])

    def test_coasts_face_open_sea(self):
        for region, land in self.table['lands'].items():
            if region not in MAPS:
                continue  # retired lands (desert, jungle) keep their chart place only
            rows = self.level(region)
            for coast in land['coasts']:
                side = {'N': 'north', 'S': 'south', 'E': 'east', 'W': 'west'}[coast]
                row = edge_row(rows, side)
                sea = sum(('saltwater' in t or 'ice/salty' in t or 'beach/water' in t) for t in row) / len(row)
                with self.subTest(region=region, coast=coast):
                    self.assertGreater(sea, 0.5)

    def test_metadata_no_longer_names_links(self):
        for f in ('nomads_earth.dm', 'nomads_americas.dm'):
            text = (ROOT / 'code/game/objects/map_metadata/nomads' / f).read_text(encoding='utf-8')
            self.assertNotIn('edge_crossings =', text)
            self.assertNotIn('sea_coasts =', text)
        edge = (ROOT / 'code/modules/persistence/region_edge.dm').read_text(encoding='utf-8')
        self.assertIn('var/list/links = world_links[shard_group.region]', edge)
        self.assertNotIn('map.edge_crossings[', edge)

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
        pack = crossing.split('/proc/sea_crossing_pack(')[1].split('\n/proc/')[0]
        self.assertIn('region_travel_ignorable(M)', pack)
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
        self.assertLess(pack.index('region_travel_ignorable(M)'), pack.index('if (ismob(M))'))

    def test_refused_things_are_marked_on_deck(self):
        crossing = (ROOT / 'code/modules/naval/ship_crossing.dm').read_text(encoding='utf-8')
        pack = crossing.split('/proc/sea_crossing_pack(')[1].split('\n/proc/')[0]
        self.assertEqual(pack.count('refused |= '), pack.count('blocking |= '))
        self.assertLess(pack.index('sea_crossing_mark(blocking)'), pack.index('return "Put these ashore first'))
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
