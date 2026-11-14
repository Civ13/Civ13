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


def chart(seed='fixed-seed', mainland='alpha'):
    db = sqlite3.connect(':memory:', isolation_level=None)
    db.execute('CREATE TABLE chart_meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)')
    db.execute("INSERT INTO chart_meta VALUES ('seed', ?)", (seed,))
    return wc.WorldChart(db, mainland)


def first_land(c, coastal=True):
    for y in range(wc.CHART_HEIGHT):
        for x in range(wc.CHART_WIDTH):
            if c.terrain(x, y) not in ('OCEAN', 'MAINLAND') and bool(c.coast(x, y)) == coastal:
                return x, y
    raise AssertionError('no such land on this chart')


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

    def test_only_tiny_and_small_lands_are_rolled_for_now(self):
        sizes = {wc.roll_template('s', x, 1, 0, 'GRASSLAND', ['N'])['size'] for x in range(300)}
        self.assertEqual({'TINY', 'SMALL'}, sizes)
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
        self.assertEqual(['TINY', 'SMALL'], seen['sizes_enabled'])
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
