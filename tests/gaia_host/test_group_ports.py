"""Offline tests for scripts/shard-group/group_ports.py (ports, set-gate, set-port) with the fake machine."""
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import test_shard_group as base  # noqa: E402

shard_group = base.shard_group
group_ports = shard_group.group_ports
Refused = shard_group.Refused
REPOSITORY_CONFIG = 'ALLOWED_GAMEMODES ALL\n#WEBHOOK_CAN_FIRE\n#WEBHOOK_ADDRESS http://127.0.0.1:55555/webhook/nomads\n#WEBHOOK_KEY\n'


class Machine(base.FakeMachine):
    """Worlds stop and start when the worker waits, as their detached workers would."""

    def __init__(self):
        super().__init__()
        self.reloaded = []
        self.old_builds = set()  # ports of worlds built before reload_group
        self.done = 0

    def query(self, port, token, action='status', operation=None, session=None, extra=None):
        answer = {'ok': True, 'ready': True, 'busy': False, 'session': 'b' * 32, 'clients': 2}
        if action == 'reload_group':
            self.reloaded.append(port)
            if port not in self.old_builds:
                answer['reload'] = 'reloaded'
        return answer

    def sleep(self, seconds):
        self.clock += seconds
        for argv in self.detached[self.done:]:
            host = json.loads(Path(argv[argv.index('--config') + 1]).read_text())
            action = argv[argv.index('--worker') + 1]
            if action == 'stop':
                self.up.discard(host['port'])
            elif action == 'start':
                self.up.add(host['port'])
            (Path(host['state_dir']) / 'action.lock').unlink(missing_ok=True)
        self.done = len(self.detached)


class GroupPortsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        (self.base / 'repo').mkdir()
        self.overlays = self.base / 'overlay'
        regions = []
        for index, (name, kind) in enumerate((('gaia', 'SURFACE'), ('north', 'SURFACE'), ('moon', 'OTHER'), ('school', 'TUTORIAL'))):
            regions.append({'id': name, 'name': name.title(), 'kind': kind, 'port': 1720 + index, 'transfer_port': 1740 + index,
                            'map': 'maps/small/tiny.dmm', 'overlay': str(self.overlays / name)})
            (self.overlays / name / 'config').mkdir(parents=True)
            (self.overlays / name / 'config' / 'config.local.txt').write_text('# %s\nDAYNIGHT_CLIENT_TINT\n' % name)
        regions[1]['public'] = True
        (self.overlays / 'north' / 'config' / 'config.local.txt').write_text(
            '# north\nWEBHOOK_CAN_FIRE\nWEBHOOK_ADDRESS http://127.0.0.1:55555/webhook/nomads\nWEBHOOK_KEY secret\nDAYNIGHT_CLIENT_TINT\n')
        self.group = {'group': 'earth', 'repository': str(self.base / 'repo'), 'root': str(self.base / 'regions'),
                      'compiler': 'DreamMaker', 'daemon': 'DreamDaemon', 'git': 'git', 'public_host': '203.0.113.5',
                      'relay_port': 1730, 'mainland': 'gaia', 'gate': 'north', 'shutdown_warning_seconds': 0, 'regions': regions}
        self.path = self.base / 'group.json'
        self.machine = Machine()
        loaded = self.write()
        shard_group.setup(loaded, self.machine)
        for region in regions:
            folder = self.base / 'regions' / region['id']
            (folder / 'config' / 'config.txt').write_text(REPOSITORY_CONFIG)
            self.machine.restore[str(folder)] = REPOSITORY_CONFIG
        (self.base / 'regions' / 'north' / 'SQL').mkdir()
        (self.base / 'regions' / 'north' / 'SQL' / 'admins.txt').write_text('val;Host;65535|||\n')

    def tearDown(self):
        self.tmp.cleanup()

    def write(self):
        self.path.write_text(json.dumps(self.group))
        return shard_group.load_group(self.path)

    def load(self):
        return shard_group.load_group(self.path)

    def run_plan(self, plan):
        started = []
        answer = group_ports.apply(shard_group, self.load(), plan, start=lambda argv, cwd, log: started.append(argv) or 777)
        self.assertEqual(['--ports-worker', answer['operation']], started[0][-2:])
        worker = group_ports.Worker(shard_group, self.load(), answer['operation'], self.machine,
                                    sleep=self.machine.sleep, clock=self.machine.now)
        worker.run()
        return json.loads((self.base / 'regions' / 'port-change.json').read_text())

    def settings(self, region):
        return json.loads((self.base / 'regions' / region / 'config' / 'shard_region.json').read_text())

    def test_ports_lists_every_port_and_what_to_forward(self):
        self.machine.up = {1721, 1730}
        report = group_ports.report(shard_group, self.load(), self.machine)
        self.assertEqual(('north', [1713, 1721, 1730], []), (report['gate'], report['public_ports'], report['problems']))
        rows = {(row['port'], row['use']): row for row in report['ports']}
        self.assertEqual((True, True, True), (rows[(1721, 'game')]['gate'], rows[(1721, 'game')]['public'], rows[(1721, 'game')]['listening']))
        self.assertEqual((False, False), (rows[(1720, 'game')]['public'], rows[(1720, 'game')]['listening']))
        self.assertEqual('gaia', rows[(1740, 'transfer agent')]['region'])
        self.assertIn((1731, 'relay control'), rows)
        self.assertIsNone(report['change'])
        # Two uses of one port are reported whoever wrote the file.
        self.assertEqual(['port 5 is used twice: game of a and relay'],
                         group_ports.clashes([{'port': 5, 'use': 'game', 'region': 'a'}, {'port': 5, 'use': 'relay', 'region': None}]))

    def test_the_plan_swaps_the_two_game_ports_and_changes_nothing(self):
        self.machine.up = {1720, 1721}
        before = self.path.read_text()
        plan = group_ports.plan_gate(shard_group, self.load(), 'gaia', self.machine)
        self.assertEqual({'gaia': {'port': [1720, 1721], 'public': [None, True]}, 'north': {'port': [1721, 1720]}}, plan['changes'])
        self.assertEqual((['north', 'gaia'], [], [1713, 1721, 1730]), (plan['gate'], plan['problems'], plan['public_ports']))
        self.assertEqual(('awake', 2), (plan['regions']['gaia']['state'], plan['regions']['gaia']['players']))
        self.assertEqual({'keys': ['WEBHOOK_ADDRESS', 'WEBHOOK_CAN_FIRE', 'WEBHOOK_KEY'], 'files': ['admins.txt', 'magic_whitelist.txt'],
                          'folder': str(self.base / 'regions' / 'front-door')}, plan['front_door'])
        self.assertIn("The bot link settings (WEBHOOK_ADDRESS, WEBHOOK_CAN_FIRE, WEBHOOK_KEY) and the shared admins files move to "
                      "the group's front-door folder, where they follow whichever region is the front door.", plan['steps'])
        self.assertFalse((self.base / 'regions' / 'front-door').exists(), 'a plan moves nothing')
        self.assertNotIn('secret', json.dumps(plan), 'the webhook key never leaves the overlay files')
        self.assertIn('Gaia becomes the front door on port 1721; North moves behind the relay.', plan['steps'])
        self.assertEqual(before, self.path.read_text())
        self.assertFalse((self.base / 'regions' / 'port-change.json').exists())
        with mock.patch.object(shard_group, 'Platform', return_value=self.machine), \
                mock.patch('sys.stdout', new_callable=io.StringIO) as out:
            self.assertEqual(0, shard_group.main(['--config', str(self.path), 'set-gate', '--region', 'gaia']))
        answer = json.loads(out.getvalue())
        self.assertEqual((True, False, 'set-gate'), (answer['ok'], answer['applied'], answer['plan']['kind']))

    def test_refusals_and_problems(self):
        group = self.load()
        with self.assertRaisesRegex(Refused, 'TUTORIAL region cannot be the front door'):
            group_ports.plan_gate(shard_group, group, 'school', self.machine)
        with self.assertRaisesRegex(Refused, 'no region mars'):
            group_ports.plan_gate(shard_group, group, 'mars', self.machine)
        with self.assertRaisesRegex(Refused, 'nothing to change'):
            group_ports.plan_port(shard_group, group, 'moon', port=1722, platform=self.machine)
        with self.assertRaisesRegex(Refused, '1024 to 65535'):
            group_ports.plan_port(shard_group, group, 'moon', port=80, platform=self.machine)
        # A port another region, the relay or the doorman holds is a problem, not a crash.
        for port, text in ((1720, 'unique port'), (1740, 'unique transfer_port'), (1730, 'relay_port must be a free port'),
                           (1713, 'is the doorman port')):
            plan = group_ports.plan_port(shard_group, group, 'moon', port=port, platform=self.machine)
            self.assertTrue(any(text in problem for problem in plan['problems']), (port, plan['problems']))
            with self.assertRaises(Refused):
                group_ports.apply(shard_group, group, plan)
        # So is a port some other program on the machine listens on.
        self.machine.up = {1900}
        plan = group_ports.plan_port(shard_group, group, 'moon', port=1900, platform=self.machine)
        self.assertEqual(['port 1900 (for moon) is in use by another program on this machine'], plan['problems'])
        # A host service from before port changes would keep watching the old ports.
        self.machine.up = {1713}
        plan = group_ports.plan_gate(shard_group, group, 'gaia', self.machine)
        self.assertTrue(any('restart it first' in problem for problem in plan['problems']), plan['problems'])
        # A world in the middle of an action, or one that cannot save now.
        self.machine.up = {1720}
        (self.base / 'regions' / 'gaia' / 'data' / 'shard-host' / 'action.lock').write_text('x')
        plan = group_ports.plan_gate(shard_group, group, 'gaia', self.machine)
        self.assertTrue(any('gaia is running an action' in problem for problem in plan['problems']), plan['problems'])
        # A group without the relay has no front door to move.
        del self.group['relay_port'], self.group['gate']
        with self.assertRaisesRegex(Refused, 'no routing relay'):
            group_ports.plan_gate(shard_group, self.write(), 'gaia', self.machine)

    def test_set_gate_stops_writes_starts_and_tells_in_order(self):
        self.machine.up = {1720, 1721, 1722}  # gaia, north (the gate) and the moon run; the school does not
        self.machine.old_builds = set()
        profile = self.base / 'profile.json'
        north = (self.base / 'regions' / 'north').as_posix()
        profile.write_text(json.dumps({'servers': {
            'pers': {'basedir': north, 'region_group': str(self.path), 'ip': '127.0.0.1', 'port': 1721,
                     'admin_file': north + '/SQL/admins.txt', 'gaia_host': {'enabled': True, 'config': north + '/data/shard-host/host.json'}},
            'tdm': {'basedir': '/elsewhere', 'port': 1714}}}))
        self.group['bot_profile'] = str(profile)
        plan = group_ports.plan_gate(shard_group, self.write(), 'gaia', self.machine)
        self.assertEqual([], plan['problems'])
        self.assertEqual(['admin_file', 'basedir', 'gaia_host.config'], sorted(plan['bot']['servers']['pers']))
        journal = self.run_plan(plan)
        self.assertEqual(('done', None, True), (journal['phase'], journal['error'], journal['changed']), journal)
        # Both worlds were saved and stopped before anything was written, then started, the new gate first.
        actions = [(argv[argv.index('--worker') + 1], Path(argv[argv.index('--config') + 1]).parts[-4]) for argv in self.machine.detached]
        self.assertEqual([('stop', 'gaia'), ('stop', 'north'), ('start', 'gaia'), ('start', 'north')], actions)
        written = json.loads(self.path.read_text())
        ports = {region['id']: region['port'] for region in written['regions']}
        self.assertEqual(({'gaia': 1721, 'north': 1720, 'moon': 1722, 'school': 1723}, 'gaia', True),
                         (ports, written['gate'], written['regions'][0]['public']))
        self.assertEqual(1, len(list(self.base.glob('group.json.bak-*'))), 'the old group file is kept')
        self.assertEqual({1720, 1721, 1722}, self.machine.up)
        # Every region's generated config names the new gate and addresses, the stopped school's too.
        for region in ('gaia', 'north', 'moon', 'school'):
            settings = self.settings(region)
            addresses = {entry['id']: entry['address'] for entry in settings['regions']}
            self.assertEqual(('gaia', '203.0.113.5:1721', '203.0.113.5:1720'), (settings['gate'], addresses['gaia'], addresses['north']))
        hosts = {region: json.loads((self.base / 'regions' / region / 'data' / 'shard-host' / 'host.json').read_text())
                 for region in ('gaia', 'north')}
        self.assertEqual(((1721, False, True), (1720, True, False)),
                         tuple((hosts[r]['port'], hosts[r]['routed'], hosts[r]['public']) for r in ('gaia', 'north')))
        # The moon kept running and was told; no region needs a restart.
        self.assertEqual(([1722], []), (self.machine.reloaded, journal['restart_needed']))
        # The bot link settings and the shared admins files left the old gate for the group's
        # front-door folder: no region's overlay holds them, and the front door's config gets them.
        front = self.base / 'regions' / 'front-door'
        self.assertEqual('# gaia\nDAYNIGHT_CLIENT_TINT\n', (self.overlays / 'gaia' / 'config' / 'config.local.txt').read_text())
        self.assertEqual('# north\nDAYNIGHT_CLIENT_TINT\n', (self.overlays / 'north' / 'config' / 'config.local.txt').read_text())
        self.assertEqual(['WEBHOOK_CAN_FIRE', 'WEBHOOK_ADDRESS http://127.0.0.1:55555/webhook/nomads', 'WEBHOOK_KEY secret'],
                         (front / 'config.local.txt').read_text().splitlines()[1:])
        self.assertIn('WEBHOOK_KEY secret', (self.base / 'regions' / 'gaia' / 'config' / 'config.txt').read_text())
        self.assertIn('#WEBHOOK_KEY', (self.base / 'regions' / 'north' / 'config' / 'config.txt').read_text())
        self.assertEqual('val;Host;65535|||\n', (front / 'SQL' / 'admins.txt').read_text())
        self.assertEqual(shard_group.MAGIC_WHITELIST_HEADER, (front / 'SQL' / 'magic_whitelist.txt').read_text())
        self.assertEqual(front / 'SQL' / 'magic_whitelist.txt', shard_group.magic_whitelist_path(self.load()))
        # The bot profile watches the new gate's folder; other servers are left alone.
        servers = json.loads(profile.read_text())['servers']
        gaia = (self.base / 'regions' / 'gaia').as_posix()
        self.assertEqual((gaia, front.as_posix() + '/SQL/admins.txt', gaia + '/data/shard-host/host.json', 1721, '/elsewhere'),
                         (servers['pers']['basedir'], servers['pers']['admin_file'], servers['pers']['gaia_host']['config'],
                          servers['pers']['port'], servers['tdm']['basedir']))
        self.assertTrue(journal['bot']['restart'])
        self.assertEqual(1, len(list(self.base.glob('profile.json.bak-*'))))
        self.assertNotIn('secret', json.dumps(journal))
        # Running it again finds nothing to move and only checks that everything is in place.
        again = group_ports.plan_gate(shard_group, self.load(), 'gaia', self.machine)
        self.assertEqual((True, {}, [], None), (again['already'], again['changes'], again['problems'], again['front_door']))
        self.assertEqual({}, again['bot']['servers'])
        count = len(self.machine.detached)
        self.assertEqual('done', self.run_plan(again)['phase'])
        self.assertEqual(count, len(self.machine.detached), 'no world is stopped or started when all is in place')
        report = group_ports.report(shard_group, self.load(), self.machine)
        self.assertEqual(('gaia', 'done', False), (report['gate'], report['change']['phase'], report['change']['running']))

    def test_a_later_move_carries_nothing_between_regions(self):
        self.machine.up = {1720, 1721}
        self.assertEqual('done', self.run_plan(group_ports.plan_gate(shard_group, self.load(), 'gaia', self.machine))['phase'])
        front = self.base / 'regions' / 'front-door'
        (front / 'SQL' / 'admins.txt').write_text('val;Host;65535|||\nada;Admin;8191|||\n')  # the bot's later edit
        back = group_ports.plan_gate(shard_group, self.load(), 'north', self.machine)
        self.assertEqual(([], None), (back['problems'], back['front_door']))
        self.assertEqual('done', self.run_plan(back)['phase'])
        # Only the generated configs changed hands: the bot link is north's again, the files stayed put.
        self.assertIn('WEBHOOK_KEY secret', (self.base / 'regions' / 'north' / 'config' / 'config.txt').read_text())
        self.assertIn('#WEBHOOK_KEY', (self.base / 'regions' / 'gaia' / 'config' / 'config.txt').read_text())
        self.assertIn('ada;Admin', (front / 'SQL' / 'admins.txt').read_text())
        self.assertEqual('# north\nDAYNIGHT_CLIENT_TINT\n', (self.overlays / 'north' / 'config' / 'config.local.txt').read_text())
        # A bot that works its paths out from the group file has no path keys: nothing to rewrite.
        self.assertEqual({'port': 1721}, group_ports.bot_wanted(shard_group, self.load(), 'north', {'region_group': str(self.path)}))
        # A bot that follows the front door keeps its profile as written, and is restarted after a move.
        profile = self.base / 'profile.json'
        entry = {'basedir': '/old', 'admin_file': '/old/SQL/admins.txt', 'port': 1721, 'region_group': str(self.path), 'follow_front_door': True}
        profile.write_text(json.dumps({'servers': {'pers': entry}}))
        plan = group_ports.plan_gate(shard_group, self.load(), 'gaia', self.machine, bot_profile=str(profile))
        self.assertEqual(({}, True), (plan['bot']['servers'], plan['bot']['restart']))
        journal = self.run_plan(plan)
        self.assertEqual(('done', True, entry), (journal['phase'], journal['bot']['restart'], json.loads(profile.read_text())['servers']['pers']))
        self.assertFalse(group_ports.plan_gate(shard_group, self.load(), 'gaia', self.machine, bot_profile=str(profile))['bot']['restart'])

    def test_a_move_that_is_run_again_still_finds_the_old_front_doors_files(self):
        # The group file already names the new gate (the first run stopped after writing it).
        self.group['gate'] = 'gaia'
        group = self.write()
        moved = shard_group.adopt_front_door(group, 'stamp', ['north', 'gaia'])
        self.assertEqual(['SQL/magic_whitelist.txt', 'SQL/admins.txt', 'config.local.txt'], moved)
        front = self.base / 'regions' / 'front-door'
        self.assertEqual('val;Host;65535|||\n', (front / 'SQL' / 'admins.txt').read_text())
        self.assertIn('WEBHOOK_KEY secret', (front / 'config.local.txt').read_text())
        self.assertEqual([], shard_group.adopt_front_door(group, 'stamp', ['north', 'gaia']))
        with self.assertRaisesRegex(ValueError, 'front-door'):
            shard_group.check_group(dict(self.group, regions=self.group['regions'] + [dict(self.group['regions'][2], id='front-door', port=1790, transfer_port=1791)]), self.path)

    def test_ports_the_file_leaves_out_are_chosen_and_kept(self):
        busy = {1726, 1734}
        raw = {'live': False, 'transfers': True, 'relay_port': 'auto', 'mainland': 'gaia', 'gate': 'north',
               'regions': [{'id': 'gaia'}, {'id': 'north'}, {'id': 'moon', 'port': 1800, 'transfer_port': 1735}]}
        chosen = shard_group.fill_ports(raw, listening=busy.__contains__)
        ports = {r['id']: (r['port'], r['transfer_port']) for r in raw['regions']}
        # The front door first from the lowest port already in the file; 1726 belongs to another
        # program, so no port lands there; a port in the file is never moved.
        self.assertEqual({'north': (1800 + 1, 1811), 'gaia': (1802, 1812), 'moon': (1800, 1735)}, ports)
        self.assertEqual((1813, 1814), (raw['relay_port'], raw['relay_control_port']))
        self.assertEqual(5, len(chosen))
        self.assertEqual([], shard_group.fill_ports(raw, listening=busy.__contains__), 'nothing is chosen twice')
        fresh = {'regions': [{'id': 'a'}, {'id': 'b'}]}
        shard_group.fill_ports(fresh, listening=busy.__contains__)
        self.assertEqual([1724, 1725], [r['port'] for r in fresh['regions']])
        self.assertNotIn('transfer_port', fresh['regions'][0])
        live = {'live': True, 'transfers': True, 'regions': [{'id': 'a'}, {'id': 'b'}]}
        shard_group.fill_ports(live, listening=busy.__contains__)
        self.assertEqual([(1714, 1724), (1715, 1725)], [(r['port'], r['transfer_port']) for r in live['regions']])
        # load_group keeps what it chose: the next load, and every other reader, sees the same ports.
        for region in self.group['regions']:
            del region['port'], region['transfer_port']
        self.group.update(transfers=True, relay_port='auto')
        self.path.write_text(json.dumps(self.group))
        with mock.patch.object(shard_group.Platform, 'listening', return_value=False):
            loaded = shard_group.load_group(self.path)
        kept = json.loads(self.path.read_text())
        self.assertEqual([r['port'] for r in loaded['regions']], [r['port'] for r in kept['regions']])
        self.assertEqual((1724, kept['relay_port']), (next(r['port'] for r in kept['regions'] if r['id'] == 'north'), loaded['relay_port']))
        self.assertEqual(kept, json.loads(self.path.read_text()) if shard_group.load_group(self.path) else None)

    def test_a_sleeping_or_stopped_gate_and_worlds_on_older_builds(self):
        # North (the gate) is stopped and Gaia is not running either; the moon runs an older build.
        self.machine.up = {1722}
        self.machine.old_builds = {1722}
        journal = self.run_plan(group_ports.plan_gate(shard_group, self.load(), 'gaia', self.machine))
        self.assertEqual('done', journal['phase'], journal)
        actions = [(argv[argv.index('--worker') + 1], Path(argv[argv.index('--config') + 1]).parts[-4]) for argv in self.machine.detached]
        self.assertEqual([('start', 'gaia')], actions, 'only the new front door is brought up')
        self.assertEqual(['moon'], journal['restart_needed'])

    def test_a_stopped_group_only_changes_ports(self):
        # Every world is down for maintenance: the gate moves and nothing is launched.
        self.machine.up = set()
        plan = group_ports.plan_gate(shard_group, self.load(), 'gaia', self.machine)
        self.assertFalse(plan['regions']['gaia']['start'])
        journal = self.run_plan(plan)
        self.assertEqual('done', journal['phase'], journal)
        self.assertEqual([], self.machine.detached, 'nothing is started')
        self.assertEqual('gaia', self.load()['gate'])

    def test_a_failed_stop_starts_the_stopped_world_again_and_changes_nothing(self):
        self.machine.up = {1720, 1721}
        before = self.path.read_text()
        plan = group_ports.plan_gate(shard_group, self.load(), 'gaia', self.machine)
        real_sleep = self.machine.sleep
        def sleep(seconds):
            # Gaia stops; North's save fails.
            for argv in self.machine.detached[self.machine.done:]:
                host = json.loads(Path(argv[argv.index('--config') + 1]).read_text())
                if host['region'] == 'north' and argv[argv.index('--worker') + 1] == 'stop':
                    state = Path(host['state_dir']) / 'operation.json'
                    state.write_text(json.dumps(dict(json.loads(state.read_text()), phase='failed', error='the save failed')))
            real_sleep(seconds)
            self.machine.up.add(1721)
        self.machine.sleep = sleep
        journal = self.run_plan(plan)
        self.assertEqual(('failed', False), (journal['phase'], journal['changed']))
        self.assertIn('north did not stop: the save failed; nothing was changed', journal['error'])
        self.assertEqual(before, self.path.read_text())
        actions = [(argv[argv.index('--worker') + 1], Path(argv[argv.index('--config') + 1]).parts[-4]) for argv in self.machine.detached]
        self.assertEqual(('start', 'gaia'), actions[-1], 'the world this run stopped is started again on its old port')
        self.assertEqual('north', self.settings('gaia')['gate'])

    def test_set_port_moves_one_region_and_its_agent(self):
        self.machine.up = {1722, 1742}
        ended = []
        plan = group_ports.plan_port(shard_group, self.load(), 'moon', port=1800, transfer_port=1801, standby_port=1802,
                                     platform=self.machine)
        self.assertEqual(({'moon': {'port': [1722, 1800], 'transfer_port': [1742, 1801], 'standby_port': [None, 1802]}}, []),
                         (plan['changes'], plan['problems']))
        with mock.patch.object(shard_group.RegionPlatform, 'listener_pids', lambda self, port: [4141] if port == 1742 else []), \
                mock.patch.object(shard_group.RegionPlatform, 'terminate', lambda self, pid: ended.append(pid)):
            journal = self.run_plan(plan)
        self.assertEqual('done', journal['phase'], journal)
        moon = next(region for region in json.loads(self.path.read_text())['regions'] if region['id'] == 'moon')
        self.assertEqual((1800, 1801, 1802), (moon['port'], moon['transfer_port'], moon['standby_port']))
        self.assertEqual([4141], ended, 'the agent on the old port is ended; the host service starts one on the new port')
        self.assertEqual(1801, json.loads((self.base / 'regions' / 'moon' / 'config' / 'transfer_agent.json').read_text())['port'])
        self.assertIn(1800, self.machine.up)
        self.assertNotIn(1722, self.machine.up)
        # Moving the front door's own port is allowed, with a warning about the router and the Play button.
        plan = group_ports.plan_port(shard_group, self.load(), 'north', port=1900, platform=self.machine)
        self.assertTrue(any('forward port 1900 on the router' in warning for warning in plan['warnings']), plan['warnings'])
        # A standby port alone stops nothing.
        plan = group_ports.plan_port(shard_group, self.load(), 'gaia', standby_port=1950, platform=self.machine)
        self.assertEqual({}, plan['regions'])

    def test_the_worker_waits_for_the_host_service_to_load_the_new_ports(self):
        self.machine.up = set()
        record = self.base / 'regions' / 'host-service.json'
        record.write_text(json.dumps({'pid': 4321, 'signature': 'stale'}))
        real_sleep, waits = self.machine.sleep, []
        def sleep(seconds):
            waits.append(seconds)
            if len(waits) == 2:  # the service notices the changed file on a later pass
                record.write_text(json.dumps({'pid': 4321, 'signature': group_ports.signature(self.path)}))
            real_sleep(seconds)
        self.machine.sleep = sleep
        with mock.patch.object(shard_group, 'process_alive', lambda pid: pid == 4321):
            plan = group_ports.plan_gate(shard_group, self.load(), 'gaia', self.machine)
            self.assertEqual('reloads', plan['host_service'])
            journal = self.run_plan(plan)
            self.assertEqual('done', journal['phase'], journal)
            self.assertIn('host service loaded the new ports', journal['log'])
            # A service that never loads them leaves the change written and says what to do.
            record.write_text(json.dumps({'pid': 4321, 'signature': 'stale'}))
            journal = self.run_plan(group_ports.plan_gate(shard_group, self.load(), 'north', self.machine))
        self.assertEqual(('failed', True), (journal['phase'], journal['changed']))
        self.assertIn('restart it', journal['error'])
        self.assertEqual('north', json.loads(self.path.read_text())['gate'])

    def test_main_applies_and_reports(self):
        self.machine.up = set()
        started = []
        with mock.patch.object(shard_group, 'Platform', return_value=self.machine), \
                mock.patch.object(shard_group, 'detach', lambda argv, cwd, log: started.append(argv) or 99), \
                mock.patch('sys.stdout', new_callable=io.StringIO) as out:
            self.assertEqual(0, shard_group.main(['--config', str(self.path), 'set-gate', '--region', 'gaia', '--apply']))
            answer = json.loads(out.getvalue())
            self.assertEqual((True, True), (answer['ok'], answer['accepted']))
            self.assertEqual(['--config', str(self.path.resolve()), '--ports-worker', answer['operation']], started[0][-4:])
            out.seek(0), out.truncate()
            self.assertEqual(1, shard_group.main(['--config', str(self.path), 'set-port', '--region', 'moon', '--port', '1720', '--apply']))
            self.assertIn('unique port', json.loads(out.getvalue())['refused'])
            out.seek(0), out.truncate()
            self.assertEqual(0, shard_group.main(['--config', str(self.path), 'ports']))
            change = json.loads(out.getvalue())['change']
            self.assertEqual(('accepted', True), (change['phase'], change['running']), 'a change just accepted counts as running')
            out.seek(0), out.truncate()
            self.assertEqual(1, shard_group.main(['--config', str(self.path), 'set-gate', '--region', 'gaia', '--apply']))
            self.assertIn('another port change is still running', json.loads(out.getvalue())['refused'])


class GroupWatchTests(unittest.TestCase):
    """The host service takes a changed group file by itself (gaia_host.GroupWatch, Doorman.reload_groups)."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        (self.base / 'repo').mkdir()
        self.group = {'group': 'earth', 'repository': str(self.base / 'repo'), 'root': str(self.base / 'regions'),
                      'compiler': 'DreamMaker', 'daemon': 'DreamDaemon', 'git': 'git', 'public_host': '203.0.113.5',
                      'relay_port': 1730, 'gate': 'gaia',
                      'regions': [{'id': 'gaia', 'name': 'Gaia', 'kind': 'SURFACE', 'port': 1720, 'map': 'maps/small/tiny.dmm'},
                                  {'id': 'north', 'name': 'North', 'kind': 'SURFACE', 'port': 1721, 'map': 'maps/small/tiny.dmm'}]}
        self.path = self.base / 'group.json'
        self.path.write_text(json.dumps(self.group))

    def tearDown(self):
        self.tmp.cleanup()

    def test_the_service_follows_a_region_to_its_new_port(self):
        gaia_host = shard_group.gaia_host
        import doorman
        watch = gaia_host.GroupWatch(self.path, shard_group)
        record = json.loads((self.base / 'regions' / 'host-service.json').read_text())
        self.assertEqual(group_ports.signature(self.path), record['signature'])
        machine = base.FakeMachine()
        door = doorman.Doorman(watch.hosts, machine, clock=lambda: 0.0, wall=lambda: 0.0, groups=[watch])
        self.assertEqual([1720, 1721], sorted(door.instances))
        door.instances[1720].status = {'players': 3}
        door.instances[1720].status_at = 5
        self.assertIsNone(watch.poll(), 'an unchanged file is not loaded again')
        # The front door moves: the two regions swap ports.
        self.group['regions'][0]['port'], self.group['regions'][1]['port'], self.group['gate'] = 1721, 1720, 'north'
        self.path.write_text(json.dumps(self.group, indent=2))
        with mock.patch('builtins.print'):
            door.reload_groups()
        self.assertEqual({1720: 'north', 1721: 'gaia'}, {port: i.host.config['region'] for port, i in door.instances.items()})
        self.assertEqual({'players': 3}, door.instances[1721].status, 'what was known of Gaia follows it')
        self.assertEqual((False, True), (door.instances[1720].host.config['routed'], door.instances[1721].host.config['routed']))
        record = json.loads((self.base / 'regions' / 'host-service.json').read_text())
        self.assertEqual(group_ports.signature(self.path), record['signature'])
        self.assertEqual('north', watch.group['gate'], 'the supervisor works from the new group too')
        # A file that does not load keeps the ports it had, and the next good one is taken.
        self.path.write_text('{"half": ')
        with mock.patch('builtins.print') as printed:
            door.reload_groups()
        self.assertIn('group_reload_error', printed.call_args[0][0])
        self.assertEqual([1720, 1721], sorted(door.instances))
        self.group['regions'][1]['port'] = 1790
        self.path.write_text(json.dumps(self.group))
        with mock.patch('builtins.print'):
            door.reload_groups()
        self.assertEqual([1721, 1790], sorted(door.instances))


class ReloadGroupSourceTests(unittest.TestCase):
    """The world's side: a running region takes the new directory without a restart."""

    def test_the_lifecycle_action_reloads_addresses_gate_and_shared_files(self):
        root = Path(__file__).resolve().parents[2]
        lifecycle = (root / 'code/modules/persistence/nomads_lifecycle.dm').read_text(encoding='utf-8')
        self.assertIn('if(action == "reload_group") allowed = list("nomads_lifecycle", "token", "action")', lifecycle)
        self.assertIn('reloaded["reload"] = shard_group ? shard_group.reload_directory() : "refused:no_group"', lifecycle)
        group = (root / 'code/modules/persistence/shard_group.dm').read_text(encoding='utf-8')
        body = group[group.index('/datum/shard_group/proc/reload_directory()'):group.index('/datum/shard_group/proc/region_name')]
        # Another group's or region's file changes nothing, and nothing is changed before the file validates.
        self.assertIn('settings["group"] != group || settings["region"] != region', body)
        self.assertLess(body.index('return "refused:bad_address"'), body.index('address = entry["address"]'))
        self.assertIn('peer["address"] = entry["address"]', body)
        self.assertIn('configure_relay(settings)', body)
        # The shared admins file and whitelist are found again from the new gate.
        for line in ('admins_file_path = null', 'magic_whitelist_path = null', 'load_admins()', 'return "reloaded"'):
            self.assertIn(line, body)
        self.assertIn("'reload_group'", (root / 'scripts/shard-group/group_ports.py').read_text(encoding='utf-8'))


if __name__ == '__main__':
    unittest.main()
