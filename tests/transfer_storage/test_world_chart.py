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
        self.assertIn('harbour master', refused['reason'])
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
        self.assertEqual('far2', self.c.set_course('v2', 'faction:rome', other[0], other[1], now=1001)['region'])
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


class ChartAgentTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.stores, self.servers, self.urls = {}, {}, {}
        for name in TOKENS:
            store = RegionStore(os.path.join(self.tmp.name, name + '.sqlite'), name, 'g')
            server = make_server(store, TOKENS[name])
            threading.Thread(target=server.serve_forever, daemon=True).start()
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
