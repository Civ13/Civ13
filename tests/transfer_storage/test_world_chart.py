"""World chart: templates rolled once on discovery, kept until an admin reroll,
per-owner charts, and the chart reaching every agent."""
import json
import os
import sqlite3
import subprocess
import sys
import tempfile
import threading
import unittest
from unittest.mock import patch

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, ROOT)
from tools.transfer_storage import world_chart as wc  # noqa: E402
from tools.transfer_storage.agent import make_server  # noqa: E402
from tools.transfer_storage.coordinator import Coordinator, call  # noqa: E402
from tools.transfer_storage.region import RegionStore  # noqa: E402

TOKENS = {'alpha': 'a' * 40, 'beta': 'b' * 40}


def chart(seed='fixed-seed', mainland='alpha', slots=(), expeditions=None):
    db = sqlite3.connect(':memory:', isolation_level=None)
    db.execute('CREATE TABLE chart_meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)')
    db.execute("INSERT INTO chart_meta VALUES ('seed', ?)", (seed,))
    return wc.WorldChart(db, mainland, slots, expeditions)


def slot_record(expeditions, slot, **values):
    path = os.path.join(expeditions, 'slots', slot + '.json')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(dict({'region': slot}, **values), f)


def first_land(c, coastal=True):
    for y in range(wc.CHART_HEIGHT):
        for x in range(wc.CHART_WIDTH):
            if c.terrain(x, y) not in ('OCEAN', 'MAINLAND') and bool(c.coast(x, y)) == coastal:
                return x, y
    raise AssertionError('no such land on this chart')



class SlotWorldNamesTests(unittest.TestCase):
    """Every ore, rare find and game name the chart rolls is one the land
    world can place (code/modules/naval/land_resources.dm)."""

    def read(self, path):
        with open(os.path.join(ROOT, path), encoding='utf-8') as f:
            return f.read()

    def test_ores_rare_finds_and_game_are_placeable(self):
        import re
        lodes = self.read('code/modules/naval/land_resources.dm')
        kinds = set(re.findall(r'^\t"([a-z]+)" = list\(/obj/item/stack/ore/', lodes, re.M)) | {'flint'}
        self.assertTrue(set(wc.ORES) | {'obsidian'} <= kinds, sorted(set(wc.ORES) - kinds))
        for rare in wc.RARE_FINDS:
            self.assertIn('"%s" in rare' % rare, lodes)
        species = set(re.findall(r'eco_species\("([^"]+)"', self.read('code/modules/ecology/ecology_spawning.dm')))
        for biome, game in wc.GAME.items():
            self.assertTrue(set(game) <= species, (biome, sorted(set(game) - species)))

class ChartTests(unittest.TestCase):
    def test_the_same_seed_draws_the_same_chart_and_the_mainland_sits_in_open_water(self):
        a, b = chart(), chart()
        self.assertEqual(a.text_rows(), b.text_rows())
        self.assertNotEqual(a.text_rows(), chart('other-seed').text_rows())
        mx, my = a.pins()['alpha']
        self.assertEqual('MAINLAND', a.terrain(mx, my))
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if dx or dy:
                    self.assertEqual('OCEAN', a.terrain(mx + dx, my + dy))
        rows = a.text_rows()
        self.assertEqual((wc.CHART_HEIGHT, wc.CHART_WIDTH), (len(rows), len(rows[0])))
        land = sum(ch not in '.@' for row in rows for ch in row) / float(wc.CHART_WIDTH * wc.CHART_HEIGHT)
        self.assertTrue(0.1 < land < 0.6, land)

    def test_existing_claim_gets_stable_incarnation_on_migration(self):
        db = sqlite3.connect(':memory:', isolation_level=None)
        db.execute('CREATE TABLE chart_claim(faction TEXT PRIMARY KEY, x INTEGER, y INTEGER, by TEXT, at INTEGER)')
        faction = 'civ:alpha:Rome Empire'
        db.execute('INSERT INTO chart_claim VALUES (?, 1, 2, ?, 2000)', (faction, 'val'))
        c = wc.WorldChart(db)
        token = c.snapshot()['claim_incarnations'][faction]
        self.assertRegex(token, r'^[0-9a-f]{32}$')
        self.assertEqual({faction: '1,2'}, c.claims())
        self.assertEqual(1, c.rev())
        reopened = wc.WorldChart(db)
        self.assertEqual(token, reopened.claim_incarnation(faction))
        self.assertEqual(c.key(), reopened.key())

    def test_a_template_is_rolled_once_on_discovery_and_kept(self):
        c = chart()
        x, y = first_land(c)
        self.assertIsNone(c.template(x, y), 'nothing is stored before a ship sees it')
        rolled = c.reveal('faction:rome', x, y, radius=0)
        template = rolled['%d,%d' % (x, y)]
        self.assertEqual('CHARTED', c.template(x, y)['state'])
        # Another ship seeing it later changes nothing.
        self.assertEqual({}, c.reveal('faction:gaul', x, y, radius=0))
        self.assertEqual(template, c.template(x, y)['template'])
        self.assertIn(template['size'], wc.SIZES_ENABLED)
        self.assertEqual(c.coast(x, y), template['coast'])
        self.assertEqual(template, wc.roll_template(c.seed, x, y, 0, template['biome'], template['coast']))

    def test_every_size_of_land_is_rolled(self):
        sizes = {wc.roll_template('s', x, 1, 0, 'GRASSLAND', ['N'])['size'] for x in range(300)}
        self.assertEqual(set(wc.SIZES), sizes)
        for x in range(50):
            t = wc.roll_template('s', x, 2, 0, 'BOREAL', ['S'])
            base_w, base_h = wc.SIZE_TILES[t['size']]
            self.assertTrue(base_w * 0.85 - 1 <= t['width'] <= base_w * 1.15 + 1)
            self.assertTrue(base_h * 0.85 - 1 <= t['height'] <= base_h * 1.15 + 1)
        self.assertEqual((200, 200), wc.SIZE_TILES['TINY'])
        self.assertEqual((500, 350), wc.SIZE_TILES['MEDIUM'], 'medium is Gaia-sized')

    def test_smaller_lands_are_richer_and_land_types_follow_the_biome(self):
        order = ['poor', 'thin', 'fair', 'good', 'rich']
        ore = [order.index(wc.SIZE_ORE[s]) for s in wc.SIZES]
        self.assertEqual(sorted(ore, reverse=True), ore)
        fertility = [order.index(wc.SIZE_FERTILITY[s]) for s in wc.SIZES]
        self.assertEqual(sorted(fertility), fertility)
        kinds = {wc.roll_template('s', x, 3, 0, 'DESERT', ['E'])['land_type'] for x in range(300)}
        self.assertNotIn('FJORD_COAST', kinds)
        self.assertNotIn('MARSH', kinds)

    def test_reroll_changes_a_charted_template_but_never_one_with_a_world(self):
        c = chart()
        x, y = first_land(c)
        c.reveal('crew:val', x, y, radius=0)
        before = c.template(x, y)['template']
        rev = c.rev()
        after = c.reroll(x, y, 'adminkey')
        self.assertIsNotNone(after)
        self.assertNotEqual(before['seed'], after['seed'])
        self.assertEqual(1, c.template(x, y)['reroll'])
        self.assertGreater(c.rev(), rev)
        self.assertIsNone(c.reroll(x, y, 'Not A Key'))
        ox, oy = c.pins()['alpha']
        self.assertIsNone(c.reroll(ox + 1, oy, 'adminkey'), 'ocean has no template')
        c.db.execute("UPDATE chart_tile SET state = 'LANDED', region = 'far1' WHERE x = ? AND y = ?", (x, y))
        self.assertIsNone(c.reroll(x, y, 'adminkey'), 'a land with a world keeps its template')

    def test_each_owner_sees_only_its_own_chart(self):
        c = chart()
        x, y = first_land(c)
        c.reveal('faction:rome', x, y)
        rome, gaul = c.text_rows('faction:rome'), c.text_rows('faction:gaul')
        self.assertTrue(all(ch == wc.UNSEEN for row in gaul for ch in row))
        row = rome[wc.CHART_HEIGHT - 1 - y]
        self.assertNotEqual(wc.UNSEEN, row[x])
        self.assertEqual({}, c.snapshot('faction:gaul')['tiles'])
        self.assertIn('%d,%d' % (x, y), c.snapshot('faction:rome')['tiles'])
        self.assertIsNone(c.reveal('Rome!', x, y))

    def test_pins_refuse_a_charted_or_taken_tile(self):
        c = chart()
        x, y = first_land(c)
        c.reveal('admin', x, y, radius=0)
        self.assertFalse(c.pin('beta', x, y))
        ox, oy = c.pins()['alpha']
        self.assertFalse(c.pin('beta', ox, oy))
        self.assertTrue(c.pin('beta', 2, 2))
        self.assertEqual('MAINLAND', c.terrain(2, 2))


class CourseTests(unittest.TestCase):
    """A ship sets course for a land: a free slot is asked for its world, and
    the course is ready once the host has started it."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.exp = os.path.join(self.tmp.name, 'expeditions')
        self.c = chart(slots=['far1', 'far2'], expeditions=self.exp)
        self.x, self.y = first_land(self.c)
        self.c.reveal('faction:rome', self.x, self.y)

    def tearDown(self):
        self.tmp.cleanup()

    def wanted(self, slot):
        path = os.path.join(self.exp, 'wanted', slot + '.json')
        if not os.path.exists(path):
            return None
        with open(path, encoding='utf-8') as f:
            return json.load(f)

    def test_a_course_opens_a_free_slot_and_is_ready_once_the_host_starts_it(self):
        course = self.c.set_course('alpha-1-1', 'faction:rome', self.x, self.y, 'alpha', now=1000)
        self.assertEqual(('ASSIGNED', 'far1', 'alpha'), (course['state'], course['region'], course['origin']))
        wanted = self.wanted('far1')
        self.assertEqual('%d,%d' % (self.x, self.y), wanted['key'])
        self.assertEqual(self.c.template(self.x, self.y)['template'], wanted['template'])
        self.assertEqual(('LANDED', 'far1'), (self.c.template(self.x, self.y)['state'], self.c.template(self.x, self.y)['region']))
        # A second ship for the same land takes the same slot; asking again changes nothing.
        self.assertEqual('far1', self.c.set_course('alpha-2-2', 'faction:rome', self.x, self.y, now=1001)['region'])
        self.assertEqual(course, self.c.set_course('alpha-1-1', 'faction:rome', self.x, self.y, now=1002))
        self.assertFalse(self.c.refresh_courses(now=1003))
        # The host takes the wish, builds the land, then starts the slot.
        os.remove(os.path.join(self.exp, 'wanted', 'far1.json'))
        slot_record(self.exp, 'far1', state='LAND', key='%d,%d' % (self.x, self.y), phase='building')
        self.assertFalse(self.c.refresh_courses(now=1004))
        slot_record(self.exp, 'far1', state='LAND', key='%d,%d' % (self.x, self.y), phase='started')
        rev = self.c.rev()
        self.assertTrue(self.c.refresh_courses(now=1005))
        self.assertGreater(self.c.rev(), rev)
        snapshot = self.c.snapshot()
        self.assertEqual('READY', snapshot['courses']['alpha-1-1']['state'])
        self.assertEqual('READY', snapshot['courses']['alpha-2-2']['state'])
        # Old courses are forgotten.
        self.assertTrue(self.c.refresh_courses(now=1005 + wc.COURSE_KEEP_SECONDS + 10))
        self.assertEqual({}, self.c.courses())

    def test_a_failed_land_refuses_its_courses_and_frees_the_tile(self):
        self.c.set_course('v1', 'faction:rome', self.x, self.y, now=10)
        os.remove(os.path.join(self.exp, 'wanted', 'far1.json'))
        failed = os.path.join(self.exp, 'failed', 'far1.json')
        os.makedirs(os.path.dirname(failed))
        with open(failed, 'w', encoding='utf-8') as f:
            json.dump({'key': '%d,%d' % (self.x, self.y), 'reason': 'compile failed'}, f)
        self.assertTrue(self.c.refresh_courses(now=11))
        course = self.c.course('v1')
        self.assertEqual('REFUSED', course['state'])
        self.assertIn('compile failed', course['reason'])
        self.assertFalse(os.path.exists(failed))
        tile = self.c.template(self.x, self.y)
        self.assertEqual(('CHARTED', None), (tile['state'], tile['region']))
        # The next try gets a slot again, with the same template.
        self.assertEqual('ASSIGNED', self.c.set_course('v2', 'faction:rome', self.x, self.y, now=12)['state'])

    def test_courses_are_refused_without_a_slot_or_a_reachable_charted_land(self):
        for slot in ('far1', 'far2'):
            slot_record(self.exp, slot, state='LAND', key='0,0')
        refused = self.c.set_course('v1', 'faction:rome', self.x, self.y, now=1)
        self.assertEqual(('REFUSED', None), (refused['state'], refused['region']))
        # Every slot holds a land and none can be laid up: the host is asked for one more.
        self.assertEqual(wc.GROWING, refused['reason'])
        with open(os.path.join(self.exp, 'grow', 'request.json'), encoding='utf-8') as f:
            self.assertEqual(2, json.load(f)['slots'])
        self.assertEqual(wc.GROWING, self.c.set_course('v1b', 'faction:rome', self.x, self.y, now=2)['reason'], 'asked once')
        self.assertIsNone(self.wanted('far1'))
        self.assertIn('does not show', self.c.set_course('v2', 'faction:gaul', self.x, self.y, now=1)['reason'])
        self.assertIn('no charted land', self.c.set_course('v3', 'faction:rome', 0, 0, now=1)['reason'])
        inland = first_land(self.c, coastal=False)
        self.c.reveal('faction:rome', *inland)
        self.assertIn('no coast', self.c.set_course('v4', 'faction:rome', inland[0], inland[1], now=1)['reason'])
        self.assertIsNone(self.c.set_course('Bad Voyage!', 'faction:rome', self.x, self.y))
        self.assertIsNone(self.c.set_course('v5', 'everyone', self.x, self.y))
        # A chart with no slots refuses every new land.
        bare = chart()
        bare.reveal('admin', self.x, self.y)
        self.assertIn('harbour master', bare.set_course('v1', 'admin', self.x, self.y)['reason'])

    def test_the_snapshot_carries_each_owners_seen_tiles(self):
        mask = int(self.c.snapshot()['seen']['faction:rome'], 16)
        for x, y in self.c.seen('faction:rome'):
            self.assertTrue(mask >> (y * wc.CHART_WIDTH + x) & 1)
        self.assertEqual(len(self.c.seen('faction:rome')), bin(mask).count('1'))
        self.assertEqual(wc.CHART_WIDTH * wc.CHART_HEIGHT // 4, len(self.c.snapshot()['seen']['faction:rome']))
        self.assertNotIn('seen', self.c.snapshot('faction:rome'))


class LandChoiceTests(unittest.TestCase):
    """A land opened for a ship is settled, claimed or abandoned by its crew,
    or abandoned after 7 days with nobody there."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.exp = os.path.join(self.tmp.name, 'expeditions')
        self.c = chart(slots=['far1', 'far2'], expeditions=self.exp)
        self.x, self.y = first_land(self.c)
        self.c.reveal('faction:rome', self.x, self.y)
        self.c.set_course('v1', 'faction:rome', self.x, self.y, now=1000)

    def tearDown(self):
        self.tmp.cleanup()

    def state(self):
        return self.c.template(self.x, self.y)['state']

    def test_settling_then_claiming_keeps_the_land(self):
        self.assertEqual((self.x, self.y), self.c.land_in('far1')[:2])
        self.assertFalse(self.c.settle('far2'))
        self.assertTrue(self.c.settle('far1', 'val'))
        self.assertFalse(self.c.settle('far1', 'val'))
        self.assertEqual('SETTLED', self.state())
        self.assertFalse(self.c.claim('far1', 'not a faction'))
        self.assertTrue(self.c.claim('far1', 'civ:gaia:Rome Empire', 'val'))
        self.assertEqual('CLAIMED', self.state())
        self.assertEqual({'civ:gaia:Rome Empire': '%d,%d' % (self.x, self.y)}, self.c.snapshot()['claims'])
        # One faction per land; a settled or claimed land is never abandoned or expired.
        self.assertFalse(self.c.claim('far1', 'civ:gaia:Carthage'))
        self.assertFalse(self.c.abandon('far1'))
        self.assertEqual([], self.c.expire(now=1000 + wc.UNVISITED_SECONDS + 10))

    def test_one_claim_per_faction(self):
        self.assertTrue(self.c.claim('far1', 'civ:gaia:Rome Empire'))
        other = next((x, y) for y in range(wc.CHART_HEIGHT) for x in range(wc.CHART_WIDTH)
                     if (x, y) != (self.x, self.y) and self.c.terrain(x, y) not in ('OCEAN', 'MAINLAND') and self.c.coast(x, y))
        self.c.reveal('faction:rome', *other)
        self.assertEqual('far2', self.c.set_course('v2', 'faction:rome', other[0], other[1],
                                                 now=1000 + wc.OPEN_COOLDOWN_SECONDS)['region'])
        self.assertFalse(self.c.claim('far2', 'civ:gaia:Rome Empire'))
        self.assertEqual('LANDED', self.c.template(*other)['state'])

    def test_a_faction_gives_up_its_claim_and_may_claim_another(self):
        self.assertFalse(self.c.unclaim('far1', 'civ:gaia:Rome Empire'))
        self.assertTrue(self.c.claim('far1', 'civ:gaia:Rome Empire', 'val'))
        self.assertFalse(self.c.unclaim('far1', 'civ:gaia:Carthage'))
        self.assertTrue(self.c.unclaim('far1', 'civ:gaia:Rome Empire', 'val'))
        self.assertEqual('SETTLED', self.state())
        self.assertEqual({}, self.c.snapshot()['claims'])
        self.assertFalse(self.c.abandon('far1'), 'the land stays')
        self.assertTrue(self.c.claim('far1', 'civ:gaia:Carthage'))

    def test_a_claimed_island_keeps_who_may_land_until_the_claim_ends(self):
        faction = 'civ:gaia:Rome Empire'
        self.assertFalse(self.c.change_access(faction, {'mode': 'OPEN'}), 'no claim, no border')
        self.assertTrue(self.c.claim('far1', faction, 'val'))
        self.assertEqual({faction: {'mode': 'GUESTS', 'people': [], 'passes': {}}}, self.c.access(), 'members and guests by default')
        rev = self.c.rev()
        self.assertTrue(self.c.change_access(faction, {'mode': 'MEMBERS'}, 'val', now=2000))
        self.assertGreater(self.c.rev(), rev, 'worlds hear of the change')
        self.assertTrue(self.c.change_access(faction, {'add_guest': 'kim'}, 'val', now=2000))
        self.assertTrue(self.c.change_access(faction, {'add_guest': 'ana'}, 'val', now=2000))
        self.assertFalse(self.c.change_access(faction, {'mode': 'EVERYONE'}))
        self.assertFalse(self.c.change_access(faction, {'add_guest': 'Not A Key'}))
        self.assertTrue(self.c.grant_pass(faction, 'bob', 24, 'val', now=2000))
        self.assertFalse(self.c.grant_pass(faction, 'bob', wc.ACCESS_PASS_HOURS_MAX + 1, 'val', now=2000))
        self.assertEqual({'mode': 'MEMBERS', 'people': ['ana', 'kim'], 'passes': {'bob': 2000 + 24 * 3600}},
                         self.c.access(now=2001)[faction])
        self.assertEqual({}, self.c.access(now=2000 + 24 * 3600)[faction]['passes'], 'a pass runs out')
        self.assertTrue(self.c.grant_pass(faction, 'bob', 0, 'val', now=2100))
        self.assertEqual({}, self.c.access(now=2101)[faction]['passes'], 'a pass taken back')
        self.assertIn(faction, self.c.snapshot()['access'])
        # A player's own land has no border to keep.
        self.assertFalse(self.c.change_access('crew:val', {'mode': 'OPEN'}))
        self.assertTrue(self.c.unclaim('far1', faction, 'val'))
        self.assertEqual({}, self.c.access())
        self.assertTrue(self.c.claim('far1', faction, 'val'))
        self.assertEqual('GUESTS', self.c.access()[faction]['mode'], 'a new claim starts from the default')

    def test_guest_cap_and_idempotent_delta_edits(self):
        faction = 'civ:gaia:Rome Empire'
        self.assertTrue(self.c.claim('far1', faction, 'val'))
        for i in range(wc.ACCESS_PEOPLE_MAX):
            self.assertTrue(self.c.change_access(faction, {'add_guest': 'p%d' % i}))
        rev = self.c.rev()
        self.assertFalse(self.c.change_access(faction, {'add_guest': 'extra'}))
        self.assertTrue(self.c.change_access(faction, {'add_guest': 'p0'}))
        self.assertTrue(self.c.change_access(faction, {'remove_guest': 'absent'}))
        self.assertTrue(self.c.change_access(faction, {'mode': 'GUESTS'}))
        self.assertEqual(rev, self.c.rev())
        self.assertTrue(self.c.change_access(faction, {'remove_guest': 'p0'}))
        self.assertTrue(self.c.change_access(faction, {'add_guest': 'extra'}))
        people = self.c.access()[faction]['people']
        self.assertEqual(wc.ACCESS_PEOPLE_MAX, len(people))
        self.assertIn('extra', people)
        self.assertNotIn('p0', people)

    def test_a_player_claims_one_land_and_their_faction_another(self):
        self.assertFalse(self.c.claim('far1', 'crew:Bad Key'))
        self.assertTrue(self.c.claim('far1', 'crew:val', 'val'))
        self.assertEqual('CLAIMED', self.state())
        self.assertFalse(self.c.claim('far1', 'civ:gaia:Rome Empire'), 'one claimant a land')
        self.assertEqual([], self.c.expire(now=1000 + wc.UNVISITED_SECONDS + 10))
        other = next((x, y) for y in range(wc.CHART_HEIGHT) for x in range(wc.CHART_WIDTH)
                     if (x, y) != (self.x, self.y) and self.c.terrain(x, y) not in ('OCEAN', 'MAINLAND') and self.c.coast(x, y))
        self.c.reveal('faction:rome', *other)
        self.assertEqual('far2', self.c.set_course('v2', 'faction:rome', other[0], other[1],
                                                 now=1000 + wc.OPEN_COOLDOWN_SECONDS)['region'])
        self.assertFalse(self.c.claim('far2', 'crew:val'), 'one land each')
        self.assertTrue(self.c.claim('far2', 'civ:gaia:Rome Empire', 'val'), "the faction's claim is separate")
        self.assertEqual({'crew:val': '%d,%d' % (self.x, self.y), 'civ:gaia:Rome Empire': '%d,%d' % other},
                         self.c.snapshot()['claims'])
        self.assertTrue(self.c.unclaim('far1', 'crew:val', 'val'))
        self.assertEqual('SETTLED', self.state())

    def test_abandoning_loses_the_land_and_frees_its_slot_once_archived(self):
        self.assertTrue(self.c.abandon('far1', 'val', now=2000))
        tile = self.c.template(self.x, self.y)
        self.assertEqual(('LOST', None), (tile['state'], tile['region']))
        with open(os.path.join(self.exp, 'abandon', 'far1.json'), encoding='utf-8') as f:
            self.assertEqual('%d,%d' % (self.x, self.y), json.load(f)['key'])
        self.assertEqual('REFUSED', self.c.course('v1')['state'])
        # Nobody sails to a lost land; the slot waits for the host to archive it.
        self.assertIn('abandoned', self.c.set_course('v3', 'faction:rome', self.x, self.y, now=2001)['reason'])
        self.assertFalse(self.c.slot_free('far1'))
        os.remove(os.path.join(self.exp, 'abandon', 'far1.json'))
        os.remove(os.path.join(self.exp, 'wanted', 'far1.json'))
        self.assertTrue(self.c.slot_free('far1'))

    def test_a_land_nobody_visits_for_7_days_is_abandoned(self):
        self.assertEqual([], self.c.expire(now=1000 + wc.UNVISITED_SECONDS - 10))
        self.assertTrue(self.c.visit('far1', now=5000))
        self.assertEqual([], self.c.expire(now=1000 + wc.UNVISITED_SECONDS + 10))
        self.assertEqual(['far1'], self.c.expire(now=5000 + wc.UNVISITED_SECONDS + 10))
        self.assertEqual('LOST', self.state())


class OpenLandRuleTests(unittest.TestCase):
    """Crews open lands with no admin deciding: one undecided land an owner, a
    wait between new lands, and stale empty lands give way when slots run out."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.exp = os.path.join(self.tmp.name, 'expeditions')
        self.c = chart(slots=['far1', 'far2'], expeditions=self.exp)
        self.lands = [(x, y) for y in range(wc.CHART_HEIGHT) for x in range(wc.CHART_WIDTH)
                      if self.c.terrain(x, y) not in ('OCEAN', 'MAINLAND') and self.c.coast(x, y)][:4]
        for owner in ('faction:rome', 'faction:gaul', 'crew:val', 'crew:kim'):
            for land in self.lands:
                self.c.reveal(owner, *land)
        self.wait = wc.OPEN_COOLDOWN_SECONDS

    def tearDown(self):
        self.tmp.cleanup()

    def course(self, voyage, owner, land, now, by=None):
        return self.c.set_course(voyage, owner, land[0], land[1], now=now, by=by)

    def archived(self, slot):
        """The host archived the given-up land in slot."""
        for folder in ('abandon', 'wanted'):
            path = os.path.join(self.exp, folder, slot + '.json')
            if os.path.exists(path):
                os.remove(path)

    def test_one_undecided_land_an_owner(self):
        self.assertEqual('far1', self.course('v1', 'faction:rome', self.lands[0], 1000, 'val')['region'])
        refused = self.course('v2', 'faction:rome', self.lands[1], 1000 + self.wait, 'kim')
        self.assertEqual('REFUSED', refused['state'])
        self.assertIn('undecided', refused['reason'])
        self.assertIn('%d,%d' % self.lands[0], refused['reason'])
        # The account that opened it is held to it under another owner too.
        self.assertIn('undecided', self.course('v3', 'crew:val', self.lands[1], 1000 + self.wait, 'val')['reason'])
        # Her own undecided land can always be sailed for, and so can another crew's new land.
        self.assertEqual('far1', self.course('v4', 'faction:rome', self.lands[0], 1001, 'val')['region'])
        self.assertEqual('far2', self.course('v5', 'faction:gaul', self.lands[1], 1002, 'ann')['region'])
        # Settled, the first land no longer holds its crew back.
        self.assertTrue(self.c.settle('far1'))
        self.assertNotIn('undecided', self.course('v6', 'faction:rome', self.lands[2], 1000 + self.wait, 'val')['reason'])

    def test_a_wait_between_new_lands(self):
        self.course('v1', 'faction:rome', self.lands[0], 1000, 'val')
        self.assertTrue(self.c.abandon('far1', 'val', now=1500))
        self.archived('far1')
        refused = self.course('v2', 'faction:rome', self.lands[1], 1000 + self.wait - 600, 'kim')
        self.assertIn('about 10 minutes', refused['reason'])
        self.assertIn('not long ago', self.course('v3', 'crew:val', self.lands[1], 1000 + self.wait - 600, 'val')['reason'])
        self.assertEqual('ASSIGNED', self.course('v4', 'faction:rome', self.lands[1], 1000 + self.wait, 'kim')['state'])
        # expire() forgets the record only once the wait is over.
        self.c.expire(now=1000 + self.wait + 5)
        self.assertIn('undecided', self.course('v5', 'faction:rome', self.lands[2], 1000 + 3 * self.wait, 'kim')['reason'])

    def test_a_land_that_could_not_be_made_costs_no_wait(self):
        self.course('v1', 'faction:rome', self.lands[0], 1000, 'val')
        os.makedirs(os.path.join(self.exp, 'failed'), exist_ok=True)
        with open(os.path.join(self.exp, 'failed', 'far1.json'), 'w', encoding='utf-8') as f:
            json.dump({'region': 'far1', 'key': '%d,%d' % self.lands[0], 'reason': 'compile failed'}, f)
        os.remove(os.path.join(self.exp, 'wanted', 'far1.json'))
        self.assertTrue(self.c.refresh_courses(now=1010))
        self.assertEqual('ASSIGNED', self.course('v2', 'faction:rome', self.lands[1], 1020, 'val')['state'])

    def test_a_settled_land_is_on_every_chart(self):
        self.course('v1', 'faction:rome', self.lands[0], 1000, 'val')
        self.assertIn('does not show', self.course('v2', 'faction:nobody', self.lands[0], 1001, 'bob')['reason'])
        self.assertTrue(self.c.settle('far1'))
        self.assertEqual('far1', self.course('v3', 'faction:nobody', self.lands[0], 1002, 'bob')['region'])

    # -- parking: slots are the lands awake at once, not the lands there are --

    def slot_record(self, slot, **record):
        os.makedirs(os.path.join(self.exp, 'slots'), exist_ok=True)
        with open(os.path.join(self.exp, 'slots', slot + '.json'), 'w', encoding='utf-8') as f:
            json.dump(dict({'region': slot, 'history': []}, **record), f)

    def started(self, slot, land):
        """The host built the land wanted in slot and started it."""
        self.archived(slot)
        self.slot_record(slot, state='LAND', key='%d,%d' % land, phase='started')

    def wish(self, folder, name):
        return os.path.join(self.exp, folder, name + '.json')

    def host_parks(self, slot):
        os.remove(self.wish('park', slot))
        self.slot_record(slot, state='FREE')

    def two_lands(self):
        self.course('v1', 'faction:rome', self.lands[0], 1000, 'val')
        self.course('v2', 'faction:gaul', self.lands[1], 2000, 'ann')
        self.started('far1', self.lands[0])
        self.started('far2', self.lands[1])
        self.assertTrue(self.c.settle('far1'))

    def test_the_land_empty_longest_is_parked_when_no_slot_is_free(self):
        hour, late = wc.PARK_IDLE_SECONDS, 2000 + wc.COURSE_UNDER_WAY_SECONDS
        self.two_lands()
        # Ships were on their way to both a moment ago: nothing is parked under them, and one more slot is asked for.
        self.assertEqual(wc.GROWING, self.course('v3', 'crew:kim', self.lands[2], 2000 + hour, 'kim')['reason'])
        self.assertTrue(self.c.visit('far1', now=late))
        self.assertTrue(self.c.visit('far2', now=late + 10))
        # Both visited within the hour: nothing is parked.
        self.assertEqual(wc.GROWING, self.course('v4', 'crew:kim', self.lands[2], late + hour - 10, 'kim')['reason'])
        # The settled land has stood empty an hour: it is asked to give its slot up, and loses nothing.
        cleared = self.course('v5', 'crew:kim', self.lands[2], late + hour, 'kim')
        self.assertEqual(wc.CLEARING, cleared['reason'])
        with open(self.wish('park', 'far1'), encoding='utf-8') as f:
            self.assertEqual('%d,%d' % self.lands[0], json.load(f)['key'])
        self.assertFalse(os.path.exists(self.wish('park', 'far2')))
        # While the host parks it nothing else is asked, and the land is still in its slot.
        self.assertEqual(wc.CLEARING, self.course('v6', 'crew:kim', self.lands[2], late + 3 * hour, 'kim')['reason'])
        self.assertFalse(os.path.exists(self.wish('park', 'far2')))
        self.assertEqual('far1', self.c.template(*self.lands[0])['region'])
        self.host_parks('far1')
        self.assertTrue(self.c.refresh_courses(now=late + 3 * hour))
        tile = self.c.template(*self.lands[0])
        self.assertEqual(('SETTLED', None, True), (tile['state'], tile['region'], tile['parked']))
        self.assertEqual([('far1', ) + self.lands[0]], self.c.parked_now)
        self.c.expire(now=late + 400 * 86400)
        self.assertEqual('SETTLED', self.c.template(*self.lands[0])['state'], 'a parked settled land is never lost')
        # The freed slot takes the new land.
        self.assertEqual('far1', self.course('v7', 'crew:kim', self.lands[2], late + 3 * hour, 'kim')['region'])
        with open(self.wish('wanted', 'far1'), encoding='utf-8') as f:
            self.assertFalse(json.load(f)['parked'])

    def test_a_parked_land_is_restored_into_any_free_slot_for_a_ship(self):
        late = 2000 + wc.COURSE_UNDER_WAY_SECONDS + wc.PARK_IDLE_SECONDS
        self.two_lands()
        self.course('v3', 'crew:kim', self.lands[2], late, 'kim')
        self.host_parks('far1')
        self.c.refresh_courses(now=late)
        self.c.parked_now = []
        self.c.keep(*self.lands[0], '{"stage": "FRONTIER"}')
        # The other land is abandoned and archived: its slot is free.
        self.assertTrue(self.c.abandon('far2', 'ann', now=late))
        self.archived('far2')
        self.slot_record('far2', state='FREE')
        # Anyone may sail for the settled land; it costs no new-land wait and comes back with its state.
        self.course('v4', 'faction:gaul', self.lands[3], late + 5, 'ann')  # takes far1
        self.started('far1', self.lands[3])
        self.assertTrue(self.c.abandon('far1', 'ann', now=late + 6))
        self.archived('far1')
        self.slot_record('far1', state='FREE')
        back = self.course('v5', 'faction:gaul', self.lands[0], late + 10, 'ann')
        self.assertEqual(('ASSIGNED', 'far1'), (back['state'], back['region']))
        tile = self.c.template(*self.lands[0])
        self.assertEqual(('SETTLED', 'far1'), (tile['state'], tile['region']))
        self.assertNotIn('parked', tile)
        with open(self.wish('wanted', 'far1'), encoding='utf-8') as f:
            wanted = json.load(f)
        self.assertEqual((True, '%d,%d' % self.lands[0]), (wanted['parked'], wanted['key']))
        self.assertEqual([('far1',) + self.lands[0] + ('{"stage": "FRONTIER"}',)], self.c.restored_now)
        # A restore that failed leaves it parked, and her course says so.
        os.remove(self.wish('wanted', 'far1'))
        os.makedirs(os.path.join(self.exp, 'failed'), exist_ok=True)
        with open(self.wish('failed', 'far1'), 'w', encoding='utf-8') as f:
            json.dump({'region': 'far1', 'key': '%d,%d' % self.lands[0], 'reason': 'compile failed', 'parked': True}, f)
        self.assertTrue(self.c.refresh_courses(now=late + 20))
        tile = self.c.template(*self.lands[0])
        self.assertEqual(('SETTLED', None, True), (tile['state'], tile['region'], tile.get('parked')))
        self.assertIn('could not be made ready', self.c.course('v5')['reason'])

    def test_a_parking_called_off_or_never_done_is_forgotten(self):
        late = 2000 + wc.COURSE_UNDER_WAY_SECONDS + wc.PARK_IDLE_SECONDS
        self.two_lands()
        self.course('v3', 'crew:kim', self.lands[2], late, 'kim')
        # Somebody was there after all: the host drops the wish and keeps the land.
        os.remove(self.wish('park', 'far1'))
        self.c.refresh_courses(now=late + 30)
        self.assertEqual([], self.c.parked_now)
        self.assertEqual('far1', self.c.template(*self.lands[0])['region'])
        self.assertFalse(self.c.clearing())
        # A host that never answers: the wish is taken back after an hour.
        self.c.visit('far1', now=late + 40)
        self.course('v4', 'crew:kim', self.lands[2], late + 50, 'kim')
        self.assertTrue(os.path.exists(self.wish('park', 'far2')))
        self.c.refresh_courses(now=late + 50 + wc.PARK_GIVE_UP_SECONDS + 1)
        self.assertFalse(os.path.exists(self.wish('park', 'far2')))
        self.assertEqual('far2', self.c.template(*self.lands[1])['region'])

    def test_a_resident_summons_a_parked_land_and_an_undecided_one_still_runs_out(self):
        late = 2000 + wc.COURSE_UNDER_WAY_SECONDS + wc.PARK_IDLE_SECONDS
        self.two_lands()
        self.c.visit('far1', now=late)
        # The undecided land is the one empty longest now: parked, it stays its opener's one undecided land.
        self.course('v3', 'crew:kim', self.lands[2], late, 'kim')
        self.host_parks('far2')
        self.c.refresh_courses(now=late)
        self.assertEqual('LANDED', self.c.template(*self.lands[1])['state'])
        self.assertIn('undecided', self.course('v4', 'faction:gaul', self.lands[3], late + wc.OPEN_COOLDOWN_SECONDS, 'ann')['reason'])
        self.assertFalse(self.c.summon(*self.lands[3]), 'only a land that was opened can be summoned')
        self.assertTrue(self.c.summon(*self.lands[0]), 'a land in its slot needs nothing')
        self.assertTrue(self.c.summon(*self.lands[1], now=late + 60))
        self.assertEqual('far2', self.c.template(*self.lands[1])['region'])
        with open(self.wish('wanted', 'far2'), encoding='utf-8') as f:
            self.assertTrue(json.load(f)['parked'])
        # Parked again and left 7 days, nobody having settled it, it is lost and its folder discarded.
        self.started('far2', self.lands[1])
        self.c.restored_now = []
        self.c.visit('far1', now=late + 2 * wc.COURSE_UNDER_WAY_SECONDS + 2 * wc.PARK_IDLE_SECONDS)
        self.course('v5', 'crew:kim', self.lands[2], late + 2 * wc.COURSE_UNDER_WAY_SECONDS + 2 * wc.PARK_IDLE_SECONDS, 'kim')
        self.host_parks('far2')
        self.c.refresh_courses(now=late + 9000)
        self.assertEqual([], self.c.expire(now=late + 60 + wc.UNVISITED_SECONDS - 10))
        self.assertEqual([wc.land_home(*self.lands[1])], self.c.expire(now=late + 60 + wc.UNVISITED_SECONDS + 10))
        self.assertEqual('LOST', self.c.template(*self.lands[1])['state'])
        with open(self.wish('discard', '%d-%d' % self.lands[1]), encoding='utf-8') as f:
            self.assertEqual('%d,%d' % self.lands[1], json.load(f)['key'])

class ChartAgentTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.stores, self.servers, self.urls = {}, {}, {}
        for name in TOKENS:
            store = RegionStore(os.path.join(self.tmp.name, name + '.sqlite'), name, 'g')
            server = make_server(store, TOKENS[name])
            threading.Thread(target=server.serve_forever, kwargs={'poll_interval': 0.01}, daemon=True).start()
            self.stores[name], self.servers[name] = store, server
            self.urls[name] = 'http://127.0.0.1:%d' % server.server_address[1]
        self.db = os.path.join(self.tmp.name, 'coordinator.sqlite')
        self.coordinator = Coordinator(self.db, 'g', 'alpha', bootstrap_new_group=True)
        for name in self.stores:
            self.coordinator.enroll(name, self.urls[name], TOKENS[name])
        self.coordinator.homes_once()

    def tearDown(self):
        for name in list(self.servers):
            self.servers[name].shutdown()
            self.servers[name].server_close()
            self.stores[name].close()
        self.coordinator.close()
        self.tmp.cleanup()

    def chart(self, region):
        answer = call(self.urls[region], TOKENS[region], '/chart')
        self.assertTrue(answer.get('ok'), answer)
        return answer['result']

    def test_visitor_pass_receipt_distinguishes_queue_refusal_grant_and_revoke(self):
        directory = self.coordinator.chart
        x, y = first_land(directory)
        owner = 'civ:alpha:Rome'
        directory.reveal('crew:val', x, y)
        directory.db.execute("UPDATE chart_tile SET state='LANDED', region='beta' WHERE x=? AND y=?", (x, y))
        self.assertTrue(directory.claim('beta', owner, 'val'))

        def queue(hours, account='visitor'):
            answer = call(self.urls['alpha'], TOKENS['alpha'], '/chart/request',
                          {'op': 'pass', 'owner': owner, 'x': x, 'y': y, 'admin': 'val',
                           'data': {'account': account, 'hours': hours,
                                    'incarnation': directory.claim_incarnation(owner)}})
            self.assertTrue(answer['ok'], answer)
            return answer['result']['id']

        def status(request_id, actor='val'):
            answer = call(self.urls['alpha'], TOKENS['alpha'], '/chart/pass-result', {'id': request_id, 'actor': actor})
            self.assertTrue(answer['ok'], answer)
            return answer['result']['status']

        grant = queue(6)
        self.assertEqual('pending', status(grant))
        self.assertEqual('unknown', status(grant, 'visitor'))
        self.assertNotIn('visitor', directory.access()[owner]['passes'])
        real_call = call

        def lost_homes(url, token, path, body=None, timeout=5):
            if url == self.urls['alpha'] and path == '/homes':
                raise OSError('simulated reply loss before the agent receives it')
            return real_call(url, token, path, body, timeout)

        with patch('tools.transfer_storage.coordinator.call', side_effect=lost_homes):
            self.coordinator.homes_once()
        self.assertEqual('pending', status(grant))
        expiry = directory.access()[owner]['passes']['visitor']
        self.coordinator.close()
        self.coordinator = Coordinator(self.db, 'g', 'alpha')
        directory = self.coordinator.chart
        with patch.object(directory, 'grant_pass', side_effect=AssertionError('decided pass replayed')):
            self.coordinator.homes_once()
        self.assertEqual('applied', status(grant))
        self.assertEqual('unknown', status(grant, 'visitor'))
        self.assertEqual(expiry, directory.access()[owner]['passes']['visitor'])
        self.assertEqual(expiry, self.chart('alpha')['chart']['access'][owner]['passes']['visitor'])
        self.coordinator.homes_once()
        self.assertEqual([], list(self.coordinator.db.execute('SELECT id FROM chart_pass_result')))
        origin_copy = RegionStore(os.path.join(self.tmp.name, 'alpha.sqlite'), 'alpha', 'g')
        try:
            self.assertEqual({'status': 'applied'}, origin_copy.chart_pass_result(grant, 'val'))
        finally:
            origin_copy.close()

        for i in range(wc.ACCESS_PASSES_MAX - 1):
            self.assertTrue(directory.grant_pass(owner, f'guest{i}', 1, 'val'))
        refused = queue(6, 'extra')
        self.assertEqual('pending', status(refused))
        self.coordinator.homes_once()
        self.assertEqual('refused', status(refused))
        self.assertNotIn('extra', directory.access()[owner]['passes'])

        revoke = queue(0)
        self.assertEqual('pending', status(revoke))
        self.coordinator.homes_once()
        self.assertEqual('applied', status(revoke))
        self.assertNotIn('visitor', directory.access()[owner]['passes'])
        self.assertEqual('refused', status(refused), 'each receipt remains specific to its request')

    def test_legacy_chart_ack_is_not_a_visitor_pass_success(self):
        store = self.stores['alpha']
        answer = store.request_chart('pass', 0, 0, 'val', 'civ:alpha:Rome', data={'account': 'visitor', 'hours': 1, 'incarnation': '0' * 32})
        request_id = answer['id']
        self.assertEqual({'status': 'pending'}, store.chart_pass_result(request_id, 'val'))
        homes = store.account_requests()
        store.apply_homes(homes['epoch'], homes['rev'], [], [], chart_done=[request_id])
        self.assertEqual({'status': 'unknown'}, store.chart_pass_result(request_id, 'val'))

    def test_every_agent_gets_the_chart_and_admin_requests_wait_for_the_pass(self):
        seen = self.chart('beta')['chart']
        self.assertEqual(self.coordinator.chart.key(), seen['key'])
        self.assertEqual(list(wc.SIZES), seen['sizes_enabled'])
        self.assertEqual(list(self.coordinator.chart.pins()['alpha']), seen['pins']['alpha'])
        x, y = first_land(self.coordinator.chart)
        answer = call(self.urls['alpha'], TOKENS['alpha'], '/chart/request',
                      {'op': 'reveal', 'x': x, 'y': y, 'owner': 'admin', 'admin': 'val'})
        self.assertTrue(answer.get('ok'), answer)
        self.assertEqual(1, len(self.chart('alpha')['pending']))
        self.coordinator.homes_once()
        for region in TOKENS:
            self.assertIn('%d,%d' % (x, y), self.chart(region)['chart']['tiles'])
        self.assertEqual([], self.chart('alpha')['pending'])
        # Reroll from a world; decided requests never replay.
        seed = self.chart('beta')['chart']['tiles']['%d,%d' % (x, y)]['template']['seed']
        call(self.urls['beta'], TOKENS['beta'], '/chart/request', {'op': 'reroll', 'x': x, 'y': y, 'admin': 'val'})
        self.coordinator.homes_once()
        self.coordinator.homes_once()
        tile = self.chart('alpha')['chart']['tiles']['%d,%d' % (x, y)]
        self.assertEqual(1, tile['reroll'])
        self.assertNotEqual(seed, tile['template']['seed'])

    def test_a_ship_sets_course_through_its_agent(self):
        exp = os.path.join(self.tmp.name, 'expeditions')
        self.coordinator.chart.slots, self.coordinator.chart.expeditions = ['far1'], wc.Path(exp)
        x, y = first_land(self.coordinator.chart)
        call(self.urls['alpha'], TOKENS['alpha'], '/chart/request', {'op': 'scout', 'x': x, 'y': y, 'owner': 'crew:val', 'admin': 'val'})
        self.coordinator.homes_once()
        self.assertIn('%d,%d' % (x, y), self.chart('alpha')['chart']['tiles'])
        answer = call(self.urls['alpha'], TOKENS['alpha'], '/chart/request',
                      {'op': 'course', 'x': x, 'y': y, 'owner': 'crew:val', 'admin': 'val', 'voyage': 'alpha-5-6'})
        self.assertTrue(answer.get('ok'), answer)
        self.coordinator.homes_once()
        course = self.chart('beta')['chart']['courses']['alpha-5-6']
        self.assertEqual(('ASSIGNED', 'far1', 'alpha'), (course['state'], course['region'], course['origin']))
        slot_record(exp, 'far1', state='LAND', key='%d,%d' % (x, y), phase='started')
        self.coordinator.homes_once()
        self.assertEqual('READY', self.chart('alpha')['chart']['courses']['alpha-5-6']['state'])
        self.assertFalse(call(self.urls['alpha'], TOKENS['alpha'], '/chart/request',
                              {'op': 'course', 'x': x, 'y': y, 'owner': 'crew:val', 'admin': 'val'}).get('ok'))

    def test_a_lands_world_settles_or_abandons_it_and_homes_go_back_to_the_mainland(self):
        exp = os.path.join(self.tmp.name, 'expeditions')
        chart_ = self.coordinator.chart
        chart_.slots, chart_.expeditions = ['beta'], wc.Path(exp)
        x, y = first_land(chart_)
        chart_.reveal('crew:val', x, y)
        self.assertEqual('beta', chart_.set_course('alpha-1-1', 'crew:val', x, y, 'alpha')['region'])
        self.coordinator._set_home('val', 'beta')
        # A request naming another tile than the land it holds is ignored.
        call(self.urls['beta'], TOKENS['beta'], '/chart/request', {'op': 'settle', 'x': x + 1, 'y': y, 'admin': 'val'})
        self.coordinator.homes_once()
        self.assertEqual('LANDED', chart_.template(x, y)['state'])
        call(self.urls['beta'], TOKENS['beta'], '/chart/request', {'op': 'abandon', 'x': x, 'y': y, 'admin': 'val'})
        self.coordinator.homes_once()
        self.assertEqual('LOST', self.chart('alpha')['chart']['tiles']['%d,%d' % (x, y)]['state'])
        self.assertEqual('alpha', self.coordinator.home('val'))
        self.assertFalse(call(self.urls['beta'], TOKENS['beta'], '/chart/request',
                              {'op': 'claim', 'x': x, 'y': y, 'admin': 'val', 'owner': 'faction:rome'}).get('ok'))

    def test_homes_and_the_land_stage_follow_a_parked_land_to_its_next_slot(self):
        exp = os.path.join(self.tmp.name, 'expeditions')
        chart_ = self.coordinator.chart
        chart_.slots, chart_.expeditions = ['beta'], wc.Path(exp)
        x, y = first_land(chart_)
        chart_.reveal('crew:val', x, y)
        chart_.set_course('alpha-1-1', 'crew:val', x, y, 'alpha', now=1000)
        self.coordinator._set_home('val', 'beta')
        call(self.urls['beta'], TOKENS['beta'], '/chart/request', {'op': 'settle', 'x': x, 'y': y, 'admin': 'val'})
        self.coordinator.homes_once()
        self.assertEqual('FRONTIER', self.coordinator.lands()['beta']['stage'])
        # The host parked it (the chart asked while another crew wanted the slot).
        chart_._park('beta', x, y, 5000)
        self.coordinator.homes_once()
        home = wc.land_home(x, y)
        self.assertEqual(home, self.coordinator.home('val'))
        self.assertNotEqual('FRONTIER', self.coordinator.lands()['beta']['stage'], "the slot's next land starts unexplored")
        self.coordinator.homes_once()
        self.assertEqual({'verdict': 'ELSEWHERE', 'home': home},
                         call(self.urls['alpha'], TOKENS['alpha'], '/account', {'ckey': 'val', 'op': 'claim'})['result'])
        # Somebody else cannot wake it; its resident can, from any world.
        call(self.urls['alpha'], TOKENS['alpha'], '/chart/request', {'op': 'summon', 'x': x, 'y': y, 'admin': 'bob'})
        self.coordinator.homes_once()
        self.assertIsNone(chart_.template(x, y)['region'])
        os.remove(os.path.join(exp, 'wanted', 'beta.json'))
        call(self.urls['alpha'], TOKENS['alpha'], '/chart/request', {'op': 'summon', 'x': x, 'y': y, 'admin': 'val'})
        self.coordinator.homes_once()
        self.assertEqual('beta', chart_.template(x, y)['region'])
        self.assertEqual('beta', self.coordinator.home('val'))
        self.assertEqual('FRONTIER', self.coordinator.lands()['beta']['stage'])

    def test_settling_and_claiming_set_the_land_stage(self):
        exp = os.path.join(self.tmp.name, 'expeditions')
        chart_ = self.coordinator.chart
        chart_.slots, chart_.expeditions = ['beta'], wc.Path(exp)
        x, y = first_land(chart_)
        chart_.reveal('crew:val', x, y)
        chart_.set_course('alpha-1-1', 'crew:val', x, y, 'alpha')
        call(self.urls['beta'], TOKENS['beta'], '/chart/request', {'op': 'settle', 'x': x, 'y': y, 'admin': 'val'})
        self.coordinator.homes_once()
        self.assertEqual('FRONTIER', self.coordinator.lands()['beta']['stage'])
        call(self.urls['beta'], TOKENS['beta'], '/chart/request',
             {'op': 'claim', 'x': x, 'y': y, 'admin': 'val', 'owner': 'civ:alpha:Rome Empire'})
        self.coordinator.homes_once()
        self.assertEqual('COLONY', self.coordinator.lands()['beta']['stage'])
        self.assertEqual({'civ:alpha:Rome Empire': '%d,%d' % (x, y)}, self.chart('alpha')['chart']['claims'])
        # Giving the claim up: the land drops back to the frontier and stays.
        call(self.urls['beta'], TOKENS['beta'], '/chart/request',
             {'op': 'unclaim', 'x': x, 'y': y, 'admin': 'val', 'owner': 'civ:alpha:Rome Empire'})
        self.coordinator.homes_once()
        self.assertEqual('FRONTIER', self.coordinator.lands()['beta']['stage'])
        self.assertEqual({}, self.chart('alpha')['chart']['claims'])
        self.assertEqual('SETTLED', chart_.template(x, y)['state'])

    def test_any_land_sets_the_border_of_its_factions_island(self):
        exp = os.path.join(self.tmp.name, 'expeditions')
        chart_ = self.coordinator.chart
        chart_.slots, chart_.expeditions = ['beta'], wc.Path(exp)
        x, y = first_land(chart_)
        chart_.reveal('faction:rome', x, y)
        chart_.set_course('alpha-1-1', 'faction:rome', x, y, 'alpha')
        faction = 'civ:alpha:Rome Empire'
        call(self.urls['beta'], TOKENS['beta'], '/chart/request', {'op': 'claim', 'x': x, 'y': y, 'admin': 'val', 'owner': faction})
        self.coordinator.homes_once()
        token = self.chart('alpha')['chart']['claim_incarnations'][faction]
        self.assertEqual(token, self.chart('beta')['chart']['claim_incarnations'][faction])
        # From the faction's own land, not the island's: the leader keeps the border from anywhere.
        def edit(shard, officer, data):
            return call(self.urls[shard], TOKENS[shard], '/chart/request',
                        {'op': 'access', 'x': x, 'y': y, 'admin': officer, 'owner': faction, 'data': dict(data, incarnation=token) if type(data) is dict else data})

        # These officers submit without seeing each other's edits. Neither
        # guest addition replaces the other, nor can it overwrite a mode edit.
        for shard, officer, data in (('alpha', 'val', {'mode': 'MEMBERS'}),
                                     ('alpha', 'ana', {'add_guest': 'lee'}),
                                     ('beta', 'kim', {'add_guest': 'kim'})):
            answer = edit(shard, officer, data)
            self.assertTrue(answer.get('ok'), answer)
        call(self.urls['alpha'], TOKENS['alpha'], '/chart/request',
             {'op': 'pass', 'x': x, 'y': y, 'admin': 'val', 'owner': faction, 'data': {'incarnation': token, 'account': 'bob', 'hours': 6}})
        # Another faction's island is out of reach, and so is a tile the faction does not claim.
        call(self.urls['alpha'], TOKENS['alpha'], '/chart/request',
             {'op': 'access', 'x': x, 'y': y, 'admin': 'kim', 'owner': 'civ:alpha:Carthage', 'data': {'incarnation': token, 'mode': 'MEMBERS'}})
        call(self.urls['alpha'], TOKENS['alpha'], '/chart/request',
             {'op': 'access', 'x': (x + 1) % wc.CHART_WIDTH, 'y': y, 'admin': 'val', 'owner': faction, 'data': {'incarnation': token, 'mode': 'MEMBERS'}})
        self.coordinator.homes_once()
        access = self.chart('beta')['chart']['access']
        self.assertEqual(['civ:alpha:Rome Empire'], list(access))
        self.assertEqual('MEMBERS', access[faction]['mode'])
        self.assertEqual(['kim', 'lee'], access[faction]['people'])
        self.assertEqual(['bob'], list(access[faction]['passes']))

        for shard, officer, data in (('alpha', 'ana', {'remove_guest': 'lee'}),
                                     ('beta', 'kim', {'add_guest': 'jo'}),
                                     ('beta', 'val', {'mode': 'OPEN'})):
            answer = edit(shard, officer, data)
            self.assertTrue(answer.get('ok'), answer)
        self.coordinator.homes_once()
        access = self.chart('alpha')['chart']['access'][faction]
        self.assertEqual('OPEN', access['mode'])
        self.assertEqual(['jo', 'kim'], access['people'])
        self.assertEqual(['bob'], list(access['passes']))

        legacy = {'mode': 'OPEN', 'people': ['kim']}
        for data in (legacy, {'mode': 'open'}, {'add_guest': 'Not A Key'}, {'remove_guest': None},
                     {'mode': 'OPEN', 'add_guest': 'kim'}, {}, 'OPEN'):
            self.assertFalse(edit('alpha', 'val', data).get('ok'), data)
        # A pre-upgrade queued snapshot may have passed the old agent's schema.
        self.assertFalse(self.coordinator.chart_request(
            {'op': 'access', 'x': x, 'y': y, 'admin': 'val', 'owner': faction, 'data': dict(legacy, incarnation=token)}, 'alpha'))
        self.assertEqual(['jo', 'kim'], chart_.access()[faction]['people'])
        for data in ({'account': 'bob', 'hours': 1}, {'incarnation': token, 'account': 'bob', 'hours': 169},
                     {'incarnation': token, 'account': 'bob'}, {'incarnation': token, 'account': 'Bob!', 'hours': 1}):
            self.assertFalse(call(self.urls['alpha'], TOKENS['alpha'], '/chart/request',
                                  {'op': 'pass', 'x': x, 'y': y, 'admin': 'val', 'owner': faction, 'data': data}).get('ok'), data)
        self.assertFalse(call(self.urls['alpha'], TOKENS['alpha'], '/chart/request',
                              {'op': 'access', 'x': x, 'y': y, 'admin': 'val', 'owner': 'crew:val',
                                'data': {'incarnation': token, 'mode': 'OPEN'}}).get('ok'), "a player's own land has no border")

    def test_queued_border_and_pass_do_not_apply_to_reclaimed_island(self):
        chart_ = self.coordinator.chart
        chart_.slots, chart_.expeditions = ['beta'], wc.Path(self.tmp.name) / 'expeditions'
        x, y = first_land(chart_)
        chart_.reveal('faction:rome', x, y)
        chart_.set_course('alpha-1-1', 'faction:rome', x, y, 'alpha')
        faction = 'civ:alpha:Rome Empire'
        self.assertTrue(chart_.claim('beta', faction, 'val', now=2000))
        self.coordinator.homes_once()
        old = self.chart('alpha')['chart']['claim_incarnations'][faction]
        for op, data in [('access', {'mode': 'OPEN'}),
                         ('pass', {'account': 'bob', 'hours': 1})]:
            result = call(self.urls['alpha'], TOKENS['alpha'], '/chart/request',
                          {'op': op, 'x': x, 'y': y, 'admin': 'val', 'owner': faction,
                           'data': dict(data, incarnation=old)})
            self.assertTrue(result.get('ok'), result)

        self.assertTrue(chart_.unclaim('beta', faction, 'val', now=2000))
        self.assertTrue(chart_.claim('beta', faction, 'val', now=2000))
        self.assertNotEqual(old, chart_.claim_incarnation(faction), 'same-second reclaim is still a new claim')
        self.coordinator.homes_once()
        self.assertEqual({'mode': 'GUESTS', 'people': [], 'passes': {}},
                         self.chart('beta')['chart']['access'][faction])
        self.assertEqual([], self.chart('alpha')['pending'])

    def test_a_player_claims_only_for_themself(self):
        exp = os.path.join(self.tmp.name, 'expeditions')
        chart_ = self.coordinator.chart
        chart_.slots, chart_.expeditions = ['beta'], wc.Path(exp)
        x, y = first_land(chart_)
        chart_.reveal('crew:val', x, y)
        chart_.set_course('alpha-1-1', 'crew:val', x, y, 'alpha')
        # The agent takes crew:<ckey> only from that same account.
        self.assertFalse(call(self.urls['beta'], TOKENS['beta'], '/chart/request',
                              {'op': 'claim', 'x': x, 'y': y, 'admin': 'val', 'owner': 'crew:kim'}).get('ok'))
        call(self.urls['beta'], TOKENS['beta'], '/chart/request',
             {'op': 'claim', 'x': x, 'y': y, 'admin': 'val', 'owner': 'crew:val'})
        self.coordinator.homes_once()
        self.assertEqual('CLAIMED', chart_.template(x, y)['state'])
        self.assertEqual('FRONTIER', self.coordinator.lands()['beta']['stage'], "a player's own land is no colony")
        self.assertEqual({'crew:val': '%d,%d' % (x, y)}, self.chart('alpha')['chart']['claims'])
        # The coordinator refuses a claim for another account even if one reaches it.
        self.assertFalse(self.coordinator.chart_request({'op': 'unclaim', 'x': x, 'y': y, 'admin': 'kim', 'owner': 'crew:val'}, 'beta'))
        call(self.urls['beta'], TOKENS['beta'], '/chart/request',
             {'op': 'unclaim', 'x': x, 'y': y, 'admin': 'val', 'owner': 'crew:val'})
        self.coordinator.homes_once()
        self.assertEqual('SETTLED', chart_.template(x, y)['state'])
        self.assertEqual({}, self.chart('alpha')['chart']['claims'])

    def test_an_unchanged_chart_is_not_sent_again(self):
        self.assertEqual(self.coordinator.chart.key(), self.stores['alpha'].account_requests()['chart_rev'])
        before = self.stores['alpha'].chart()['chart']
        self.coordinator.homes_once()
        self.assertEqual(before, self.stores['alpha'].chart()['chart'])

    def test_bad_chart_requests_are_refused(self):
        for body in ({'op': 'burn', 'x': 1, 'y': 1, 'admin': 'val'},
                     {'op': 'reroll', 'x': 'a', 'y': 1, 'admin': 'val'},
                     {'op': 'reroll', 'x': 1, 'y': 1, 'admin': 'Not A Key'},
                     {'op': 'reveal', 'x': 1, 'y': 1, 'admin': 'val', 'owner': 'everyone'}):
            self.assertFalse(call(self.urls['alpha'], TOKENS['alpha'], '/chart/request', body).get('ok'), body)

    def test_command_line_prints_reveals_and_rerolls(self):
        self.coordinator.close()
        script = os.path.join(ROOT, 'tools', 'transfer_storage', 'coordinator.py')
        base = [sys.executable, '-I', script, '--db', self.db, '--group', 'g', '--mainland', 'alpha']
        text = subprocess.run(base + ['--chart'], capture_output=True, text=True, check=True).stdout.split('\n')
        self.assertEqual(wc.CHART_WIDTH, len(text[0]))
        self.assertIn('@', ''.join(text))
        out = subprocess.run(base + ['--chart-reveal', 'faction:rome=24,16'], capture_output=True, text=True, check=True).stdout
        self.assertTrue(out.startswith('charted '))
        snapshot = json.loads(subprocess.run(base + ['--chart', 'faction:rome', '--chart-json'],
                                             capture_output=True, text=True, check=True).stdout)
        self.assertEqual(wc.CHART_HEIGHT, len(snapshot['rows']))
        bad = subprocess.run(base + ['--chart-reroll', '0,0'], capture_output=True, text=True)
        self.assertNotEqual(0, bad.returncode)
        self.coordinator = Coordinator(self.db, 'g', 'alpha')


if __name__ == '__main__':
    unittest.main()
