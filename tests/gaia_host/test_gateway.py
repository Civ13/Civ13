"""Offline tests for the GATEWAY region kind in scripts/shard-group (shard_group.py, group_ports.py):
an always-up world on the front door's port that hosts no play and sends players on."""
import io
import json
from pathlib import Path
import sys
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import test_shard_group as base  # noqa: E402

shard_group, NEWER = base.shard_group, base.NEWER


class GatewayTests(unittest.TestCase):
    setUp = base.ShardGroupTests.setUp
    tearDown = base.ShardGroupTests.tearDown
    write_group = base.ShardGroupTests.write_group
    refuse_config = base.ShardGroupTests.refuse_config
    host = base.ShardGroupTests.host

    def gateway_group(self):
        self.group['relay_port'] = 1740
        self.group['regions'][1].update(id='door', name='Gateway', kind='GATEWAY', map='maps/small/tiny.dmm')
        return self.write_group()

    def test_config_rules(self):
        self.refuse_config('GATEWAY region sends players on through the routing relay', region_kind='GATEWAY')
        self.refuse_config('mainland cannot be a GATEWAY', relay_port=1740, mainland='deep', region_kind='GATEWAY')
        self.refuse_config('start region cannot be a GATEWAY', relay_port=1740, start_region='deep', region_kind='GATEWAY')
        self.group['regions'][0]['kind'] = 'GATEWAY'
        self.refuse_config('at most one GATEWAY', relay_port=1740, mainland='deep', region_kind='GATEWAY')
        self.group['regions'][0]['kind'] = 'SURFACE'
        group = self.gateway_group()
        self.assertEqual('gaia', group['gate'], 'a gateway becomes the front door only through set-gate')
        shard_group.setup(group, self.machine)
        settings = json.loads((self.base / 'regions' / 'door' / 'config' / 'shard_region.json').read_text())
        self.assertEqual(0, settings['save_minutes'], 'a gateway never saves')
        self.assertEqual(15, json.loads((self.base / 'regions' / 'gaia' / 'config' / 'shard_region.json').read_text())['save_minutes'])

    def test_round_never_saves(self):
        path = self.base / 'config.txt'
        path.write_text('ALLOWED_GAMEMODES PERSISTENCE\n')
        shard_group.region_mode_config({'persistent': True}, {'kind': 'GATEWAY'}, path)
        self.assertEqual(['ALLOWED_GAMEMODES ALL', 'SKIP_PERSISTENCE_SAVING'], path.read_text().splitlines())

    def test_gateway_never_sleeps(self):
        group = self.gateway_group()
        shard_group.setup(group, self.machine)
        self.assertFalse(self.host(group, 'door').may_sleep())
        self.assertFalse(self.host(group, 'gaia').may_sleep(), 'the mainland never sleeps either')
        self.assertEqual('start-current', self.host(group, 'door').automatic_start_action(), 'a crashed gateway comes back at once')

    def tutorial_group(self):
        self.group['regions'][1].update(id='door', name='Tutorial', kind='TUTORIAL', map='maps/small/tiny.dmm')
        return self.write_group()

    def test_tutorial_stays_up_and_restarts_onto_updates_when_empty(self):
        # Val (2026-11-21): the tutorial stays current and available while the lands are down.
        group = self.tutorial_group()
        shard_group.setup(group, self.machine)
        host = self.host(group, 'door')
        self.assertFalse(host.may_sleep())
        self.assertEqual('start-current', host.automatic_start_action())
        host.log = lambda values: None
        host.work('update', host.request('update')['operation'])
        self.machine.revision = NEWER
        self.machine.up = {1721}
        host.work('stage', host.request_stage()['operation'])
        self.assertTrue(group['persistent'])
        self.assertEqual(30, host.update_unsaved_while_empty())
        self.assertEqual('restart', host.read_state()['action'])

    def test_tutorial_handover_restarts_without_a_standby_and_waits_for_players(self):
        group = self.tutorial_group()
        shard_group.setup(group, self.machine)
        host = self.host(group, 'door')
        host.log = lambda values: None
        host.work('update', host.request('update')['operation'])
        self.machine.revision = NEWER
        self.machine.up = {1721}
        self.machine.pids_by_port = {1721: 100}
        host.work('stage', host.request_stage()['operation'])
        clients = [2]
        self.machine.query = lambda port, token, action='status', operation=None, session=None, extra=None: {
            'ok': True, 'ready': True, 'busy': False, 'session': 'b' * 32, 'clients': clients[0], 'persistence_mode': 0}
        with self.assertRaisesRegex(RuntimeError, 'players are in the tutorial'):
            host.do_handover('x', automatic=True)
        clients[0] = 0
        start = self.machine.start_task

        def start_task(name, dmb='region.dmb'):
            self.machine.up.add(1721)
            return start(name, dmb)
        self.machine.start_task = start_task
        host.precheck_handover()
        host.work('handover', host.request('handover')['operation'])
        self.assertEqual(('done', NEWER), (host.read_state()['phase'], host.built_revision()))
        self.assertFalse([argv for argv, _ in self.machine.calls if argv[0] == 'standby'])

    def test_mainland_never_sleeps(self):
        # Val (2026-11-21): Gaia is the mainland, so it never sleeps; other lands still do.
        group = self.write_group()
        shard_group.setup(group, self.machine)
        other = group['regions'][1]['id']
        self.assertFalse(self.host(group, 'gaia').may_sleep())
        self.assertTrue(self.host(group, other).may_sleep())
        host = self.host(group, 'gaia')
        host.log = lambda values: None
        self.machine.up = {group['regions'][0]['port']}
        idle, _ = host.watch_step(None)
        for _ in range(4):
            self.machine.clock += 15 * 60
            idle, _ = host.watch_step(idle)
        self.assertFalse(host.frozen(), 'an idle mainland is never frozen')

    def test_tutorial_update_restarts_on_its_own_port_without_a_standby(self):
        group = self.tutorial_group()
        shard_group.setup(group, self.machine)
        host = self.host(group, 'door')
        host.log = lambda values: None
        host.work('update', host.request('update')['operation'])
        self.machine.revision = NEWER
        self.machine.up = {1721}
        self.machine.pids_by_port = {1721: 100}
        start = self.machine.start_task

        def start_task(name, dmb='region.dmb'):
            self.machine.up.add(1721)
            return start(name, dmb)
        self.machine.start_task = start_task
        # Its round never saves (persistence_mode 0), so stopping it ends it.
        self.machine.query = lambda port, token, action='status', operation=None, session=None, extra=None: {
            'ok': True, 'ready': True, 'busy': False, 'session': 'b' * 32, 'clients': 0, 'persistence_mode': 0}
        host.work('stage', host.request_stage()['operation'])
        self.assertTrue(host.update_pending(), host.read_json(host.stage_file))
        host.precheck_handover()  # no standby port or second world's memory needed
        host.work('handover', host.request('handover')['operation'])
        state = host.read_state()
        self.assertEqual(('done', NEWER), (state['phase'], host.built_revision()), state)
        commands = [argv for argv, _ in self.machine.calls]
        self.assertFalse([argv for argv in commands if argv[0] == 'standby'], 'never a standby that rebinds the port')
        self.assertEqual('start', commands[-1][0])
        self.assertIn(1721, self.machine.up)

    def test_an_empty_gateway_never_stages_or_restarts_itself(self):
        # Val (2026-11-21): the gateway must always stay on its port; it never updates itself.
        group = self.gateway_group()
        shard_group.setup(group, self.machine)
        host = self.host(group, 'door')
        host.log = lambda values: None
        host.work('update', host.request('update')['operation'])
        self.machine.revision = NEWER
        self.machine.up = {1721}
        self.assertFalse(host.stage_if_behind(), 'no background build for the gateway')
        self.assertFalse(host.stage_lock.exists())
        for urgent in (False, True):
            with self.assertRaisesRegex(shard_group.Refused, 'never stages'):
                host.request_stage(urgent=urgent)
        self.assertIsNone(host.update_unsaved_while_empty())
        self.assertIsNone(host.update_while_empty())
        self.assertIsNone(host.idle_update_action())
        self.assertNotEqual('restart', (host.read_state() or {}).get('action'))
        self.assertIsNone(self.host(group, 'gaia').update_unsaved_while_empty(), 'saving lands still hand over')

    def test_an_empty_restart_installs_the_staged_build_without_compiling(self):
        # The TDM front door was shut for 35 seconds while a restart compiled a revision
        # newer than the staged build (2026-11-21): an always-up world installs what is staged.
        group = self.tutorial_group()
        shard_group.setup(group, self.machine)
        host = self.host(group, 'door')
        host.log = lambda values: None
        host.work('update', host.request('update')['operation'])
        self.machine.revision = NEWER
        self.machine.up = {1721}
        self.machine.pids_by_port = {1721: 100}
        start = self.machine.start_task

        def start_task(name, dmb='region.dmb'):
            self.machine.up.add(1721)
            return start(name, dmb)
        self.machine.start_task = start_task
        self.machine.query = lambda port, token, action='status', operation=None, session=None, extra=None: {
            'ok': True, 'ready': True, 'busy': False, 'session': 'b' * 32, 'clients': 0, 'persistence_mode': 0}
        host.work('stage', host.request_stage()['operation'])
        self.assertTrue(host.update_pending())
        self.machine.revision = 'f' * 40  # master moved on after the stage
        self.machine.calls.clear()
        host.work('restart', host.request('restart')['operation'])
        state = host.read_state()
        self.assertEqual(('done', NEWER), (state['phase'], host.built_revision()), state)
        commands = [argv for argv, _ in self.machine.calls]
        self.assertFalse([argv for argv in commands if argv[0] == 'DreamMaker'], 'no compile with the port closed')
        self.assertEqual('start', commands[-1][0])

    def test_group_wide_restart_and_update_leave_the_gateway_running(self):
        group = self.gateway_group()
        shard_group.setup(group, self.machine)
        requested = []

        def request(host, action):
            requested.append((host.config['region'], action))
            return {'accepted': True, 'action': action}

        def request_stage(host, urgent=False):
            requested.append((host.config['region'], 'stage'))
            return {'accepted': True, 'action': 'stage'}

        def run(*argv):
            requested.clear()
            out = io.StringIO()
            with mock.patch.object(shard_group.RegionHost, 'request', request), \
                    mock.patch.object(shard_group.RegionHost, 'request_stage', request_stage), \
                    mock.patch.object(shard_group, 'ensure_coordinator', return_value=False), \
                    mock.patch('sys.stdout', out):
                shard_group.main(['--config', str(self.path)] + list(argv))
            return json.loads(out.getvalue())

        for action in ('restart', 'handover', 'stage', 'update'):
            result = run(action)
            self.assertIn('never stages', result['refused']['door'], action)
            self.assertEqual([('gaia', action)], requested, action)
        run('restart', '--region', 'door')
        self.assertEqual([('door', 'restart')], requested, 'naming the gateway still restarts it')

    def test_add_gateway_plans_then_adds_sets_up_and_starts_it(self):
        self.group['relay_port'] = 1740
        self.group['regions'][0]['port'] = 1714
        self.group['live'] = True
        self.machine.up = {1714}  # Gaia plays on the front door meanwhile
        group = self.write_group()
        answer = shard_group.add_gateway(group, platform=self.machine)
        self.assertFalse(answer['accepted'])
        plan = answer['plan']
        self.assertEqual(('gateway', 'gaia'), (plan['region'], plan['gate']))
        self.assertNotIn(plan['port'], (1714, 1721, 1740, 1741))
        self.assertNotIn('gateway', [r['id'] for r in json.loads(self.path.read_text())['regions']], 'a plan changes nothing')
        answer = shard_group.add_gateway(group, apply=True, platform=self.machine)
        self.assertTrue(answer['accepted'])
        written = json.loads(self.path.read_text())['regions'][-1]
        self.assertEqual(('gateway', 'GATEWAY', 'maps/special/gateway.dmm', plan['port']),
                         (written['id'], written['kind'], written['map'], written['port']))
        self.assertTrue((self.base / 'regions' / 'gateway' / '.git').exists())
        self.assertEqual(['--worker', 'start', answer['start']['operation']], self.machine.detached[-1][-3:])
        self.assertEqual('set-gate --region gateway --apply', answer['next'])
        again = shard_group.add_gateway(shard_group.load_group(self.path), platform=self.machine)
        self.assertTrue(again['plan']['already'])
        self.assertEqual('set-gate --region gateway --apply', again['next'])

    def test_add_gateway_with_the_group_stopped_only_sets_it_up(self):
        self.group['relay_port'] = 1740
        self.group['regions'][0]['port'] = 1714
        self.group['live'] = True
        group = self.write_group()
        answer = shard_group.add_gateway(group, apply=True, platform=self.machine)
        self.assertTrue(answer['accepted'] and answer['plan']['offline'])
        self.assertIsNone(answer['start'], 'nothing is launched while the group is down')
        self.assertFalse(self.machine.detached)
        self.assertTrue((self.base / 'regions' / 'gateway' / '.git').exists())
        self.assertEqual('set-gate --region gateway --apply', answer['next'])
        group = shard_group.load_group(self.path)
        plan = shard_group.group_ports.plan_gate(shard_group, group, 'gateway', platform=self.machine)
        self.assertFalse(plan['problems'], plan['problems'])
        port = answer['plan']['port']
        self.assertEqual({'gateway': [port, 1714], 'gaia': [1714, port]}, {k: v['port'] for k, v in plan['changes'].items()})
        self.assertFalse(plan['regions']['gateway']['start'], 'the whole group is down: nothing is started')

    def test_add_regions_adds_the_missing_earth_regions_stopped(self):
        self.group['regions'][0]['map'] = shard_group.EARTH_MAINLAND_MAP
        self.group['regions'][1].update(id='europe', name='Europe', kind='SURFACE', map='maps/nomads/nomads_earth_europe.dmm')
        self.group['live'] = True
        self.machine.up = {1749}  # someone else listens on the Mediterranean's usual port
        group = self.write_group()
        answer = shard_group.add_regions(group, platform=self.machine)
        self.assertFalse(answer['accepted'])
        ids = [r['id'] for r in answer['plan']['regions']]
        self.assertNotIn('europe', ids, 'a region already in the group is never added again')
        self.assertIn('mediterranean', ids)
        self.assertIn('atlantic', ids)
        ports = {r['id']: r['port'] for r in answer['plan']['regions']}
        self.assertEqual(1750, ports['atlantic'], 'the usual port when it is free')
        self.assertNotEqual(1749, ports['mediterranean'], 'another port when the usual one is taken')
        self.assertEqual(len(ports), len(set(ports.values()) - {1720, 1721}))
        self.assertFalse(answer['plan']['problems'], answer['plan']['problems'])
        self.assertEqual(2, len(json.loads(self.path.read_text())['regions']), 'a plan changes nothing')
        answer = shard_group.add_regions(group, apply=True, platform=self.machine)
        self.assertTrue(answer['accepted'])
        written = {r['id']: r for r in json.loads(self.path.read_text())['regions']}
        self.assertEqual(('OCEANIC', 'maps/nomads/nomads_ocean_pacific.dmm'), (written['pacific']['kind'], written['pacific']['map']))
        self.assertTrue((self.base / 'regions' / 'mediterranean' / '.git').exists())
        self.assertFalse(self.machine.detached, 'nothing is started')
        again = shard_group.add_regions(shard_group.load_group(self.path), platform=self.machine)
        self.assertTrue(again['plan']['already'])
        self.assertFalse(again['plan']['regions'])
        # The four slots for lands across the sea come too, stopped, on their usual ports.
        slots = {r: written[r] for r in ('far1', 'far2', 'far3', 'far4')}
        self.assertEqual({'EXPEDITION'}, {r['kind'] for r in slots.values()})
        self.assertEqual({shard_group.EXPEDITION_SLOT_MAP}, {r['map'] for r in slots.values()})
        self.assertEqual([1811, 1812, 1813, 1814], [slots[r]['port'] for r in sorted(slots)])
        self.assertEqual([1831, 1832, 1833, 1834], [slots[r]['transfer_port'] for r in sorted(slots)])

    def test_add_regions_only_for_earth(self):
        with self.assertRaisesRegex(shard_group.Refused, 'does not host Earth'):
            shard_group.add_regions(self.write_group(), platform=self.machine)

    def test_a_group_holds_up_to_32_regions(self):
        regions = [{'id': 'r%d' % n, 'name': 'R%d' % n, 'kind': 'SURFACE', 'port': 1800 + n, 'map': 'maps/a.dmm'} for n in range(33)]
        self.group['regions'] = regions[:32]
        self.group['mainland'] = 'r0'
        self.write_group()
        self.group['regions'] = regions
        with self.assertRaisesRegex(ValueError, '1 to 32 regions'):
            self.write_group()
        # The worlds (shard_group.dm) and the launcher (LocalHosting.MaxRegions) take as many.
        root = Path(__file__).resolve().parents[2]
        self.assertIn('#define SHARD_MAX_REGIONS %d' % shard_group.MAX_REGIONS,
                      (root / 'code/modules/persistence/shard_group.dm').read_text(encoding='utf-8'))
        self.assertIn('public const int MaxRegions = %d;' % shard_group.MAX_REGIONS,
                      (root / 'tools/opendream-client/native/LocalHosting.cs').read_text(encoding='utf-8'))

    def test_add_gateway_needs_the_relay(self):
        with self.assertRaisesRegex(shard_group.Refused, 'routing relay'):
            shard_group.add_gateway(self.write_group(), platform=self.machine)

    def test_set_gate_waits_for_a_running_gateway(self):
        group = self.gateway_group()
        self.machine.up = {1720}  # Gaia plays on the front door
        plan = shard_group.group_ports.plan_gate(shard_group, group, 'door', platform=self.machine)
        self.assertTrue(any('not running' in problem for problem in plan['problems']), plan['problems'])
        self.machine.up = {1720, 1721}
        plan = shard_group.group_ports.plan_gate(shard_group, group, 'door', platform=self.machine)
        self.assertFalse(any('not running' in problem for problem in plan['problems']), plan['problems'])
        self.assertEqual({'door': {'port': [1721, 1720]}, 'gaia': {'port': [1720, 1721]}},
                         {k: {'port': v['port']} for k, v in plan['changes'].items()})



class StatusHubTests(unittest.TestCase):
    def test_status_reports_the_real_hub_visibility(self):
        # The status topic read a global nothing ever set, so every world (the
        # gateway too) reported hub=0 while listed (2026-11-21).
        root = Path(__file__).resolve().parents[2]
        topic = (root / 'code' / 'datums' / 'world_topic.dm').read_text(encoding='utf-8')
        self.assertIn('.["hub"] = world.visibility ? 1 : 0', topic)
        self.assertNotIn('hub_visibility', topic)

if __name__ == '__main__':
    unittest.main()
