"""Offline tests for scripts/gaia-host/gaia_host.py with a fake machine."""
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('gaia_host', ROOT / 'scripts/gaia-host/gaia_host.py')
gaia_host = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(gaia_host)

TOKEN = 'a' * 32
SESSION = 'b' * 32
REVISION = 'c' * 40
MARKER = 'round-v2:' + 'd' * 32


class FakeMachine:
    def __init__(self):
        self.up = False
        self.calls = []
        self.detached = []
        self.task_is_ready = True
        self.clock = 0.0
        self.compile_output = 'civ13.dmb - 0 errors, 0 warnings'
        self.save_error = None
        self.on_save = None
        self.clients = 2
        self.pid = 4242
        self.suspended = 0
        self.peers = []
        self.latest = REVISION  # origin/master after a fetch
        self.merged = False  # HEAD follows origin/master once merged
        self.hung = False  # the process holds the port but never answers
        self.busy = False
        self.free_mb = None

    def run(self, argv, cwd=None, timeout=1800, low_priority=False):
        self.calls.append(list(argv))
        if argv[1:] == ['rev-parse', 'HEAD'] or argv[1:] == ['rev-parse', 'origin/master']:
            return 0, (self.latest if argv[-1] != 'HEAD' or self.merged else REVISION) + '\n'
        if argv[1:3] == ['merge', '--ff-only']:
            self.merged = True
        if argv[-1] == 'civ13.dme':
            ok = '0 errors' in self.compile_output
            if ok and cwd:
                (Path(cwd) / 'civ13.dmb').write_bytes(b'build %d' % len(self.calls))
            return (0 if ok else 1), self.compile_output
        return 0, ''

    def listening(self, port):
        return self.up

    def query(self, port, token, action='status', operation=None, session=None):
        self.calls.append(['query', action, token])
        if token != TOKEN:
            raise RuntimeError('Lifecycle request rejected')
        if action == 'save_shutdown':
            if self.on_save:
                self.on_save()
            self.up = False
            return {'ok': True, 'operation': operation}
        if self.suspended:
            raise RuntimeError('a frozen world never answers')
        if self.hung:
            raise OSError('timed out')
        return {'ok': True, 'ready': True, 'busy': self.busy, 'session': SESSION, 'clients': self.clients, 'map': 'NOMADS_GAIA',
                'generation': MARKER, 'revision': REVISION, 'error': self.save_error}

    def start_task(self, name):
        self.calls.append(['schtasks', name])
        self.up = True
        return 0, 'SUCCESS'

    def task_ready(self, name):
        return self.task_is_ready

    def detach(self, argv):
        self.detached.append(argv)

    def sleep(self, seconds):
        self.clock += seconds

    def server_pid(self, port):
        return self.pid if self.up else None

    def connections(self, port):
        return list(self.peers)

    def alive(self, pid):
        return self.up and pid == self.pid

    def suspend(self, pid, trim=True):
        self.calls.append(['suspend', pid, trim])
        self.suspended += 1

    def resume(self, pid):
        self.calls.append(['resume', pid])
        self.suspended -= 1

    def kill_tree(self, pid):
        self.calls.append(['kill_tree', pid])
        self.up = False
        self.suspended = 0

    def now(self):
        return self.clock

    def free_memory_mb(self):
        return self.free_mb


def write_save(saves, marker=MARKER, levels=2, intent=None):
    saves.mkdir(parents=True, exist_ok=True)
    (saves / 'map.txt').write_text('NOMADS_GAIA\n', encoding='utf-8')
    metadata = hashlib.md5(b'NOMADS_GAIA\n').hexdigest()
    (saves / 'round.json').write_text(json.dumps({'version': 2, 'generation': marker, 'maxz': levels,
                                                  'metadata': metadata}), encoding='utf-8')
    (saves / 'save_complete.txt').write_text(marker, encoding='utf-8')
    for z in range(1, levels + 1):
        (saves / ('%d.sav' % z)).write_bytes(b'level %d' % z)
    if intent is not None:
        (saves / 'restart_intent.json').write_text(json.dumps({'version': 1, 'generation': intent}), encoding='utf-8')


class GaiaHostTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.repo = self.root / 'repo'
        (self.repo / 'config').mkdir(parents=True)
        (self.repo / 'map_saves').mkdir()
        self.config = {'repository': str(self.repo), 'port': 1714, 'task': 'Civ13 Gaia On-Demand',
                       'compiler': 'dm.exe', 'git': 'git', 'state_dir': str(self.root / 'state'),
                       'save_timeout_seconds': 60, 'start_timeout_seconds': 10, 'backups_kept': 2, 'branch': 'master',
                       '_path': str(self.root / 'gaia-host.json')}
        self.machine = FakeMachine()
        self.host = gaia_host.Host(self.config, self.machine, script=Path('gaia_host.py'))

    def tearDown(self):
        self.tmp.cleanup()

    def give_token(self):
        (self.repo / 'config' / 'lifecycle-token.txt').write_text(TOKEN + '\n', encoding='utf-8')

    def accept(self, action):
        result = self.host.request(action)
        self.assertTrue(result['accepted'])
        self.assertEqual(self.machine.detached[-1][-2:], [action, result['operation']])
        return result['operation']

    def test_check_update_fetches_and_compares_without_touching_the_world(self):
        newer = 'd' * 40
        real = self.machine.run
        def run(argv, cwd=None, timeout=1800):
            if argv[1:] == ['rev-parse', 'origin/master']:
                self.machine.calls.append(list(argv))
                return 0, newer + '\n'
            if argv[1:3] == ['rev-list', '--count']:
                self.machine.calls.append(list(argv))
                return 0, '3\n'
            return real(argv, cwd, timeout)
        self.machine.run = run
        answer = self.host.check_update()
        self.assertEqual({'component': 'server', 'current': REVISION, 'available': newer, 'behind': 3,
                          'can_update': True, 'reason': None}, answer)
        self.assertIn(['git', 'fetch', 'origin', 'master'], self.machine.calls)
        self.assertFalse(any(call[1:2] in (['merge'], ['checkout']) for call in self.machine.calls))
        self.machine.up = True
        self.assertEqual((False, 'stop the server before updating'), (self.host.check_update()['can_update'],
                                                                        self.host.check_update()['reason']))
        self.machine.run = real
        self.machine.up = False
        self.machine.latest = 'not a commit'
        with self.assertRaisesRegex(RuntimeError, 'could not read the commits'):
            self.host.check_update()  # origin/master did not resolve

    def test_status_changes_nothing(self):
        report = self.host.status()
        self.assertEqual((report['listening'], report['busy'], report['operation']), (False, False, None))
        self.assertFalse((self.root / 'state').exists())
        self.give_token()
        self.machine.up = True
        self.assertEqual(self.host.status()['world']['clients'], 2)

    def test_start_fresh_world_writes_revision_and_runs_the_task(self):
        operation = self.accept('start')
        self.host.work('start', operation)
        self.assertEqual(self.host.read_state()['phase'], 'done')
        self.assertIn(['schtasks', 'Civ13 Gaia On-Demand'], self.machine.calls)
        self.assertEqual((self.repo / 'config' / 'lifecycle-revision.txt').read_text().strip(), REVISION)
        self.assertFalse(self.host.lock.exists())

    def test_start_refusals_leave_no_lock(self):
        self.machine.up = True
        with self.assertRaisesRegex(gaia_host.Refused, 'already running'):
            self.host.request('start')
        self.assertFalse(self.host.lock.exists())
        self.machine.up = False
        self.machine.task_is_ready = False
        with self.assertRaisesRegex(gaia_host.Refused, 'not Ready'):
            self.host.request('start')
        self.machine.task_is_ready = True
        write_save(self.repo / 'map_saves', intent='round-v2:' + 'e' * 32)
        with self.assertRaisesRegex(gaia_host.Refused, 'another save'):
            self.host.request('start')
        (self.repo / 'map_saves' / 'restart_intent.json').unlink()
        (self.repo / 'map_saves' / '2.sav').write_bytes(b'')
        with self.assertRaisesRegex(gaia_host.Refused, 'level 2'):
            self.host.request('start')
        (self.repo / 'map_saves' / 'map.txt').write_text('OTHER\n')
        with self.assertRaisesRegex(gaia_host.Refused, 'map.txt'):
            self.host.request('start')
        self.assertEqual(self.machine.detached, [])

    def test_start_accepts_a_matching_restart_intent(self):
        write_save(self.repo / 'map_saves', intent=MARKER)
        self.host.work('start', self.accept('start'))
        self.assertEqual(self.host.read_state()['generation'], MARKER)

    def test_one_action_at_a_time(self):
        self.accept('start')
        with self.assertRaisesRegex(gaia_host.Refused, 'still running: start'):
            self.host.request('update')

    def test_stop_saves_and_keeps_a_verified_copy(self):
        self.give_token()
        self.machine.up = True
        self.machine.on_save = lambda: write_save(self.repo / 'map_saves', intent=MARKER)
        operations = []
        for _ in range(3):
            self.machine.up = True
            operations.append(self.accept('stop'))
            self.host.work('stop', operations[-1])
            self.assertEqual(self.host.read_state()['phase'], 'done', self.host.read_state())
        self.assertIn(['query', 'save_shutdown', TOKEN], self.machine.calls)
        backups = sorted(p.name for p in (self.root / 'state' / 'backups').iterdir())
        self.assertEqual(len(backups), 2)
        receipt = json.loads((self.root / 'state' / 'backups' / operations[-1] / 'backup-receipt.json').read_text())
        self.assertEqual(receipt['1.sav'], hashlib.sha256(b'level 1').hexdigest())

    def test_stop_refused_without_token(self):
        self.machine.up = True
        with self.assertRaisesRegex(gaia_host.Refused, 'lifecycle-token'):
            self.host.request('stop')

    def test_stop_reports_a_save_error_and_releases_the_lock(self):
        self.give_token()
        self.machine.up = True
        operation = self.accept('stop')
        self.machine.query = lambda *a, **k: {'ok': True, 'operation': 'f' * 32, 'session': SESSION}
        self.host.work('stop', operation)
        state = self.host.read_state()
        self.assertEqual(state['phase'], 'failed')
        self.assertIn('did not accept', state['error'])
        self.assertFalse(self.host.lock.exists())

    def test_restart_saves_then_starts(self):
        self.give_token()
        self.machine.up = True
        self.machine.on_save = lambda: write_save(self.repo / 'map_saves', intent=MARKER)
        self.host.work('restart', self.accept('restart'))
        self.assertEqual(self.host.read_state()['phase'], 'done')
        actions = [c[1] if c[0] == 'query' else c[0] for c in self.machine.calls]
        self.assertLess(actions.index('save_shutdown'), actions.index('schtasks'))

    def test_update_needs_a_stopped_server_and_a_clean_compile(self):
        self.machine.up = True
        with self.assertRaisesRegex(gaia_host.Refused, 'stop the server'):
            self.host.request('update')
        self.machine.up = False
        self.host.work('update', self.accept('update'))
        self.assertEqual(self.host.read_state()['phase'], 'done')
        self.assertIn(['git', 'merge', '--ff-only', 'origin/master'], self.machine.calls)
        self.machine.compile_output = 'civ13.dmb - 3 errors, 0 warnings'
        self.host.work('update', self.accept('update'))
        self.assertEqual(self.host.read_state()['phase'], 'failed')
        self.assertIn('compile failed', self.host.read_state()['error'])

    def compiles(self):
        return sum(1 for call in self.machine.calls if call[-1:] == ['civ13.dme'])

    def test_start_pulls_and_compiles_before_running_a_stale_build(self):
        self.host.work('start', self.accept('start'))
        self.assertEqual(self.host.read_state()['phase'], 'done', self.host.read_state())
        calls = self.machine.calls
        self.assertLess(calls.index(['git', 'merge', '--ff-only', 'origin/master']), calls.index(['dm.exe', 'civ13.dme']))
        self.assertLess(calls.index(['dm.exe', 'civ13.dme']), calls.index(['schtasks', 'Civ13 Gaia On-Demand']))
        self.assertEqual(json.loads((self.root / 'state' / 'build.json').read_text())['revision'], REVISION)

    def test_start_skips_the_compile_only_while_the_build_is_of_the_latest_pull(self):
        self.host.work('update', self.accept('update'))
        self.assertEqual(self.compiles(), 1)
        self.host.work('start', self.accept('start'))
        self.assertEqual((self.host.read_state()['phase'], self.compiles()), ('done', 1))
        self.assertIn(['git', 'fetch', 'origin', 'master'], self.machine.calls[-6:])
        # master moved on: the next start pulls and compiles again
        self.machine.up, self.machine.merged, self.machine.latest = False, False, 'e' * 40
        real = self.machine.run
        def run(argv, cwd=None, timeout=1800):
            if argv[1:] == ['rev-parse', 'HEAD'] and self.machine.merged:
                self.machine.calls.append(list(argv))
                return 0, self.machine.latest + '\n'
            return real(argv, cwd, timeout)
        self.machine.run = run
        self.host.work('start', self.accept('start'))
        self.assertEqual((self.host.read_state()['phase'], self.compiles()), ('done', 2))
        # a hand compile since the last recorded build is not trusted either
        self.machine.up = False
        (self.repo / 'civ13.dmb').write_bytes(b'hand built')
        self.host.work('start', self.accept('start'))
        self.assertEqual((self.host.read_state()['phase'], self.compiles()), ('done', 3))

    def test_a_failed_pull_or_compile_never_starts_the_server(self):
        self.machine.compile_output = 'civ13.dmb - 2 errors, 0 warnings'
        self.host.work('start', self.accept('start'))
        self.assertEqual(self.host.read_state()['phase'], 'failed')
        self.assertIn('compile failed', self.host.read_state()['error'])
        self.assertNotIn(['schtasks', 'Civ13 Gaia On-Demand'], self.machine.calls)
        real = self.machine.run
        self.machine.run = lambda argv, cwd=None, timeout=1800: (1, 'could not resolve host') if argv[1:2] == ['fetch'] else real(argv, cwd, timeout)
        self.machine.compile_output = 'civ13.dmb - 0 errors, 0 warnings'
        self.host.work('start', self.accept('start'))
        self.assertIn('git fetch failed', self.host.read_state()['error'])
        self.assertNotIn(['schtasks', 'Civ13 Gaia On-Demand'], self.machine.calls)

    def test_restart_pulls_and_compiles_between_save_and_start(self):
        self.give_token()
        self.machine.up = True
        self.machine.on_save = lambda: write_save(self.repo / 'map_saves', intent=MARKER)
        self.host.work('restart', self.accept('restart'))
        self.assertEqual(self.host.read_state()['phase'], 'done', self.host.read_state())
        actions = [c[1] if c[0] == 'query' else (c[-1] if c[0] == 'dm.exe' else c[0]) for c in self.machine.calls]
        self.assertLess(actions.index('save_shutdown'), actions.index('civ13.dme'))
        self.assertLess(actions.index('civ13.dme'), actions.index('schtasks'))

    def test_worker_ignores_a_stale_operation(self):
        operation = self.accept('start')
        self.host.work('start', 'f' * 32)
        self.assertTrue(self.host.lock.exists())
        self.assertEqual(self.host.read_state()['operation'], operation)

    def test_cli_reports_refusals_as_json(self):
        path = self.root / 'gaia-host.json'
        config = dict(self.config)
        config.pop('_path')
        path.write_text(json.dumps(config))
        from io import StringIO
        from contextlib import redirect_stdout
        out = StringIO()
        with redirect_stdout(out):
            code = gaia_host.main(['--config', str(path), 'status'])
        self.assertEqual(code, 0)
        self.assertTrue(json.loads(out.getvalue())['ok'])
        path.write_text(json.dumps({'port': 'x'}))
        out = StringIO()
        with redirect_stdout(out):
            self.assertEqual(gaia_host.main(['--config', str(path), 'status']), 2)


    # -- freezing ----------------------------------------------------------
    def running(self, clients=0):
        self.give_token()
        self.machine.up = True
        self.machine.clients = clients
        self.host.log = lambda values: None

    def test_freeze_refused_while_players_are_online(self):
        self.running(clients=1)
        with self.assertRaisesRegex(gaia_host.Refused, 'client'):
            self.host.freeze()
        self.assertEqual(self.machine.suspended, 0)

    def test_freeze_refused_during_another_action(self):
        self.running()
        self.host.state_dir.mkdir(parents=True)
        self.host.lock.write_text('x')
        with self.assertRaises(gaia_host.Refused):
            self.host.freeze()

    def test_freeze_and_thaw_the_same_process_once(self):
        self.running()
        self.machine.clock = 100
        self.assertEqual(self.host.freeze()['pid'], 4242)
        self.assertEqual(self.machine.suspended, 1)
        with self.assertRaisesRegex(gaia_host.Refused, 'already frozen'):
            self.host.freeze()
        status = self.host.status()
        self.assertEqual(status['frozen']['pid'], 4242)
        self.assertNotIn(['query', 'status', TOKEN], self.machine.calls[-1:])
        self.machine.clock = 400
        thawed = self.host.thaw()
        self.assertEqual((thawed['frozen_seconds'], self.machine.suspended), (300, 0))
        with self.assertRaisesRegex(gaia_host.Refused, 'not frozen'):
            self.host.thaw()

    def test_a_restarted_server_is_not_thawed(self):
        self.running()
        self.host.freeze()
        self.machine.pid = 5555  # dd.exe was killed and started again
        self.assertIsNone(self.host.frozen())
        self.assertFalse(self.host.freeze_file.exists())

    def test_stop_thaws_first(self):
        self.running()
        self.host.freeze()
        self.accept('stop')
        self.assertEqual(self.machine.suspended, 0)

    def test_watch_freezes_after_idle_minutes_and_wakes_on_a_player(self):
        self.running()
        idle, wait = self.host.watch_step(None)
        self.assertEqual(idle, 0)
        self.machine.clock = 14 * 60
        idle, wait = self.host.watch_step(idle)
        self.assertEqual(self.machine.suspended, 0)
        self.machine.clock = 15 * 60
        idle, wait = self.host.watch_step(idle)
        self.assertEqual((self.machine.suspended, wait), (1, 1))
        self.machine.peers = ['127.0.0.1']  # the bot polling status does not wake it
        self.host.watch_step(None)
        self.assertEqual(self.machine.suspended, 1)
        self.machine.peers = ['127.0.0.1', '203.0.113.9']
        self.host.watch_step(None)
        self.assertEqual(self.machine.suspended, 0)

    def test_watch_resets_idle_time_when_someone_plays(self):
        self.running()
        idle, _ = self.host.watch_step(None)
        self.machine.clients = 1
        idle, _ = self.host.watch_step(idle)
        self.assertIsNone(idle)

    def test_parse_netstat(self):
        text = """
Active Connections

  Proto  Local Address          Foreign Address        State           PID
  TCP    0.0.0.0:1714           0.0.0.0:0              LISTENING       4242
  TCP    192.168.1.5:1714       203.0.113.9:50112      ESTABLISHED     4242
  TCP    [::1]:1714             [::1]:50113            ESTABLISHED     4242
"""
        self.assertEqual(gaia_host.parse_netstat(text), [(1714, '0.0.0.0', 'LISTENING', 4242),
                                                        (1714, '203.0.113.9', 'ESTABLISHED', 4242),
                                                        (1714, '::1', 'ESTABLISHED', 4242)])

    def test_parse_proc_net(self):
        text = ("  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode\n"
                "   0: 00000000:06B2 00000000:0000 0A 00000000:00000000 00:00000000 00000000     0        0 111 1\n"
                "   1: 0100007F:06B2 0971000A:C3C0 01 00000000:00000000 00:00000000 00000000     0        0 222 1\n")
        self.assertEqual(gaia_host.parse_proc_net(text), [(1714, '0.0.0.0', 'LISTENING', 111),
                                                         (1714, '10.0.113.9', 'ESTABLISHED', 222)])


    def test_parse_tcp_table(self):
        import socket
        import struct
        v4 = struct.pack('<I', 2)
        v4 += struct.pack('<IIIIII', 2, 0, socket.htons(1714), 0, 0, 4242)
        v4 += struct.pack('<IIIIII', 5, 0, socket.htons(1714),
                          struct.unpack('<I', socket.inet_aton('203.0.113.9'))[0], socket.htons(50112), 4242)
        self.assertEqual(gaia_host.parse_tcp_table(v4), [(1714, '0.0.0.0', 'LISTENING', 4242),
                                                         (1714, '203.0.113.9', 'ESTABLISHED', 4242)])
        mapped = socket.inet_pton(socket.AF_INET6, '::ffff:198.51.100.7')
        v6 = struct.pack('<I', 1) + b'\0' * 16 + struct.pack('<II', 0, socket.htons(1714)) + mapped
        v6 += struct.pack('<IIII', 0, socket.htons(40000), 5, 4242)
        self.assertEqual(gaia_host.parse_tcp_table(v6, ipv6=True), [(1714, '198.51.100.7', 'ESTABLISHED', 4242)])
        with self.assertRaises(ValueError):
            gaia_host.parse_tcp_table(struct.pack('<I', 3) + v4[4:])

    def test_freeze_keeps_memory_resident_by_default(self):
        self.running()
        self.host.freeze()
        self.assertIn(['suspend', 4242, False], self.machine.calls)
        self.machine.peers = ['203.0.113.9']
        self.assertEqual(self.host.watch_step(None), (None, 0.2))




class NoConsoleWindowTests(unittest.TestCase):
    def test_console_programs_run_without_a_window(self):
        # The windowless host service (pythonw) would flash a console for every
        # git/dm.exe/schtasks/tasklist/netstat call without CREATE_NO_WINDOW.
        import subprocess
        from unittest import mock
        seen = []
        def fake_run(argv, **kwargs):
            seen.append(kwargs.get('creationflags'))
            return subprocess.CompletedProcess(argv, 0, '', '')
        with mock.patch.object(gaia_host.subprocess, 'run', fake_run):
            gaia_host.Platform().run(['git', 'status'])
        self.assertEqual(seen, [gaia_host.NO_WINDOW])
        self.assertEqual(gaia_host.NO_WINDOW, 0x08000000 if gaia_host.os.name == 'nt' else 0)

    def test_staged_compiles_run_below_normal_priority(self):
        import subprocess
        from unittest import mock
        seen = []
        def fake_run(argv, **kwargs):
            seen.append(kwargs)
            return subprocess.CompletedProcess(argv, 0, '', '')
        with mock.patch.object(gaia_host.subprocess, 'run', fake_run):
            gaia_host.Platform().run(['dm', 'region.dme'], low_priority=True)
        if gaia_host.os.name == 'nt':
            self.assertEqual(seen[0]['creationflags'], gaia_host.NO_WINDOW | gaia_host.BELOW_NORMAL_PRIORITY)
        else:
            self.assertTrue(callable(seen[0]['preexec_fn']))

    def test_console_programs_never_inherit_stdin(self):
        # Started by the launcher, this script inherits the launcher's console input; subprocess
        # duplicated that handle for git and check-update failed with WinError 50.
        import subprocess
        from unittest import mock
        seen = []
        def fake_run(argv, **kwargs):
            seen.append(kwargs.get('stdin', 'inherited'))
            return subprocess.CompletedProcess(argv, 0, '', '')
        with mock.patch.object(gaia_host.subprocess, 'run', fake_run):
            gaia_host.Platform().run(['git', 'fetch'])
        self.assertEqual(seen, [subprocess.DEVNULL])

    def test_detached_children_keep_a_hidden_console(self):
        # DETACHED_PROCESS left DreamDaemon without a console, so every shell() it ran
        # (the save memory probe's cmd /c tasklist) opened a visible window.
        from unittest import mock
        seen = []
        with mock.patch.object(gaia_host.subprocess, 'Popen', lambda argv, **kwargs: seen.append(kwargs['creationflags'])):
            gaia_host.Platform().detach(['dd.exe'])
        self.assertEqual(seen, [gaia_host.DETACH_FLAGS])
        if gaia_host.os.name == 'nt':
            self.assertEqual(gaia_host.DETACH_FLAGS & 0x08000000, 0x08000000)
            self.assertEqual(gaia_host.DETACH_FLAGS & 0x00000008, 0)


if __name__ == '__main__':
    unittest.main()


class ForcedStopTests(GaiaHostTests):
    """kill ends a hung world without saving; force-restart then starts it from the
    last completed save. Neither writes to map_saves."""

    def test_kill_ends_the_server_without_a_save(self):
        self.machine.up = True
        write_save(self.repo / 'map_saves')
        before = sorted(p.name for p in (self.repo / 'map_saves').iterdir())
        result = self.host.kill()
        self.assertEqual(result, {'killed': True, 'pid': 4242, 'reason': 'forced stop'})
        self.assertIn(['kill_tree', 4242], self.machine.calls)
        self.assertFalse(any(call[:2] == ['query', 'save_shutdown'] for call in self.machine.calls))
        self.assertEqual(sorted(p.name for p in (self.repo / 'map_saves').iterdir()), before)
        self.assertEqual(self.host.read_state()['phase'], 'killed')
        self.assertEqual(self.host.status()['state'], 'stopped')

    def test_kill_refuses_a_stopped_server(self):
        with self.assertRaisesRegex(gaia_host.Refused, 'not running'):
            self.host.kill()

    def test_kill_leaves_a_stuck_save_worker_its_record(self):
        self.give_token()
        self.machine.up = True
        operation = self.accept('stop')
        self.host.kill()
        self.assertEqual(self.host.read_state()['operation'], operation)
        self.assertTrue(self.host.lock.exists())

    def test_force_restart_waits_for_the_stuck_worker_then_starts(self):
        self.machine.up = True
        self.host.lock.parent.mkdir(parents=True, exist_ok=True)
        self.host.lock.write_text('stuck', encoding='utf-8')
        real_sleep = self.machine.sleep
        def sleep(seconds):
            real_sleep(seconds)
            self.host.lock.unlink(missing_ok=True)  # the worker sees the port close and fails
        self.machine.sleep = sleep
        result = self.host.force_restart()
        self.assertTrue(result['accepted'] and result['killed'])
        self.assertEqual(self.machine.detached[-1][-2], 'start')

    def test_force_restart_of_a_stopped_server_is_a_start(self):
        result = self.host.force_restart()
        self.assertTrue(result['accepted'])
        self.assertFalse(result['killed'])
        self.assertNotIn(['kill_tree', 4242], self.machine.calls)

    def test_force_restart_gives_up_on_a_lock_that_never_clears(self):
        self.host.lock.parent.mkdir(parents=True, exist_ok=True)
        self.host.lock.write_text('stuck', encoding='utf-8')
        with self.assertRaisesRegex(gaia_host.Refused, 'still has an action running'):
            self.host.force_restart(lock_wait_seconds=10)


class InterruptedSaveTests(GaiaHostTests):
    """A crash during a save leaves map_saves/ without a marker; the completed
    generation in map_backups/ is swapped back in before the start."""

    def interrupt(self, backup_marker=MARKER):
        saves = self.repo / 'map_saves'
        write_save(self.repo / 'map_backups', marker=backup_marker)
        (saves / 'map.txt').write_text('NOMADS_GAIA\n', encoding='utf-8')
        (saves / '1.sav').write_bytes(b'half written')
        return saves

    def test_start_swaps_the_completed_backup_in(self):
        saves = self.interrupt()
        self.machine.clock = 86400.0
        operation = self.accept('start')
        self.host.work('start', operation)
        self.assertEqual(self.host.read_state()['generation'], MARKER)
        self.assertEqual((saves / 'save_complete.txt').read_text(encoding='utf-8'), MARKER)
        self.assertEqual((saves / '2.sav').read_bytes(), b'level 2')
        self.assertFalse((self.repo / 'map_backups').exists())
        kept = list(self.repo.glob('map_saves.interrupted-*'))
        self.assertEqual(len(kept), 1)
        self.assertEqual((kept[0] / '1.sav').read_bytes(), b'half written')
        self.assertFalse((kept[0] / 'save_complete.txt').exists())

    def test_only_the_newest_interrupted_copy_is_kept(self):
        older = self.repo / 'map_saves.interrupted-20260101-000000'
        older.mkdir()
        (older / '1.sav').write_bytes(b'old')
        self.interrupt()
        self.host.work('start', self.accept('start'))
        self.assertFalse(older.exists())
        self.assertEqual(len(list(self.repo.glob('map_saves.interrupted-*'))), 1)

    def test_an_unusable_backup_leaves_the_interrupted_save_alone(self):
        saves = self.interrupt()
        (self.repo / 'map_backups' / '2.sav').write_bytes(b'')
        with self.assertRaisesRegex(gaia_host.Refused, 'round.json and save_complete.txt'):
            self.host.request('start')
        self.assertEqual((saves / '1.sav').read_bytes(), b'half written')
        self.assertTrue((self.repo / 'map_backups' / 'map.txt').exists())
        self.assertEqual(list(self.repo.glob('map_saves.interrupted-*')), [])

    def test_a_restart_intent_is_never_recovered_over(self):
        saves = self.interrupt()
        (saves / 'restart_intent.json').write_text(json.dumps({'version': 1, 'generation': MARKER}), encoding='utf-8')
        with self.assertRaises(gaia_host.Refused):
            self.host.request('start')
        self.assertTrue((self.repo / 'map_backups' / 'save_complete.txt').exists())
        self.assertEqual((saves / '1.sav').read_bytes(), b'half written')

    def test_a_completed_save_is_not_touched(self):
        write_save(self.repo / 'map_saves')
        write_save(self.repo / 'map_backups', marker='round-v2:' + 'f' * 32)
        self.host.work('start', self.accept('start'))
        self.assertEqual(self.host.read_state()['generation'], MARKER)
        self.assertTrue((self.repo / 'map_backups' / 'save_complete.txt').exists())


class WatchdogTests(unittest.TestCase):
    """The watch loop starts a world again that exited on its own, and force-restarts one
    that stopped answering, from its last completed save (ideas from tgstation-server)."""

    tearDown = GaiaHostTests.tearDown
    give_token = GaiaHostTests.give_token
    accept = GaiaHostTests.accept

    def setUp(self):
        GaiaHostTests.setUp(self)
        self.logged = []
        self.host.log = self.logged.append
        self.give_token()
        write_save(self.repo / 'map_saves')
        self.machine.up = True
        self.machine.clients = 1

    def starts(self):
        return [argv for argv in self.machine.detached if argv[-2] == 'start']

    def test_a_crashed_world_is_started_again_after_the_grace(self):
        self.host.watch_step(None)
        self.assertTrue(self.host.running_file.exists(), 'a world seen answering is one that should run')
        self.machine.up = False
        self.assertEqual(self.host.watch_step(None), (None, 10))
        self.machine.clock += 119
        self.host.watch_step(None)
        self.assertEqual(self.starts(), [], 'a reboot closes the port for a moment')
        self.machine.clock += 1
        self.host.watch_step(None)
        self.assertEqual(len(self.starts()), 1)
        record = json.loads(self.host.watchdog_file.read_text())
        self.assertEqual((record['last_event'], record['restarts']), ('crash', [120]))
        self.assertEqual(self.host.status()['watchdog']['last_event'], 'crash')

    def test_a_stopped_or_killed_world_stays_down(self):
        self.host.watch_step(None)
        self.machine.clients = 0
        self.host.work('stop', self.accept('stop'))
        self.assertFalse(self.host.running_file.exists())
        self.machine.up = True
        self.host.watch_step(None)
        self.host.kill()
        self.assertFalse(self.host.running_file.exists())
        for _ in range(5):
            self.machine.clock += 300
            self.host.watch_step(None)
        self.assertEqual(self.starts(), [])

    def test_the_watchdog_gives_up_after_too_many_restarts_in_an_hour(self):
        self.host.watch_step(None)
        for expected in (1, 2, 3, 3):
            self.machine.up = False
            self.host.lock.unlink(missing_ok=True)  # the start worker finished
            self.host.watch_step(None)
            self.machine.clock += 120
            self.host.watch_step(None)
            self.assertEqual(len(self.starts()), expected)
            self.machine.clock += 60
        self.assertIn('gave_up', json.loads(self.host.watchdog_file.read_text()))
        self.assertFalse(self.host.running_file.exists())
        # A start by a person watches it again.
        self.machine.up = False
        self.host.lock.unlink(missing_ok=True)
        self.host.do_start('op')
        self.assertNotIn('gave_up', json.loads(self.host.watchdog_file.read_text()))

    def test_a_hung_world_is_force_restarted_from_its_save(self):
        self.host.watch_step(None)
        self.machine.hung = True
        self.machine.clock += 9 * 60
        self.host.watch_step(None)
        self.assertNotIn(['kill_tree', 4242], self.machine.calls)
        self.machine.clock += 60
        self.host.watch_step(None)
        self.assertIn(['kill_tree', 4242], self.machine.calls)
        self.assertFalse(any(call[:2] == ['query', 'save_shutdown'] for call in self.machine.calls))
        self.assertEqual(len(self.starts()), 1)
        self.assertTrue(self.host.running_file.exists())
        self.assertEqual(json.loads(self.host.watchdog_file.read_text())['last_event'], 'hang')

    def test_a_world_busy_saving_gets_the_save_timeout(self):
        self.config['save_timeout_seconds'] = 3600
        self.machine.busy = True
        self.host.watch_step(None)
        self.machine.hung = True
        self.machine.clock += 59 * 60
        self.host.watch_step(None)
        self.assertNotIn(['kill_tree', 4242], self.machine.calls)
        self.machine.clock += 60
        self.host.watch_step(None)
        self.assertIn(['kill_tree', 4242], self.machine.calls)

    def test_a_world_that_never_answered_is_left_alone(self):
        self.machine.hung = True
        self.host.mark_running()
        for _ in range(10):
            self.machine.clock += 600
            self.host.watch_step(None)
        self.assertNotIn(['kill_tree', 4242], self.machine.calls)

    def test_a_thawed_world_gets_a_fresh_allowance(self):
        self.machine.clients = 0
        self.host.watch_step(None)
        self.machine.clock += 15 * 60
        (self.repo / 'map_saves' / 'save_complete.txt').touch()
        self.host.freeze()
        self.host.watch_step(None)
        self.machine.clock += 3600
        self.host.thaw()
        self.machine.hung = True
        self.host.watch_step(None)
        self.assertNotIn(['kill_tree', 4242], self.machine.calls)

    def test_low_memory_leaves_a_crashed_world_cold(self):
        self.host.watch_step(None)
        self.machine.up = False
        self.machine.free_mb = 500
        self.host.watch_step(None)
        self.machine.clock += 120
        self.host.watch_step(None)
        self.assertEqual(self.starts(), [])
        self.assertEqual(self.host.status()['state'], 'cold')

    def test_a_refused_start_is_tried_again_later(self):
        self.host.watch_step(None)
        self.machine.up = False
        self.machine.task_is_ready = False
        self.host.watch_step(None)
        self.machine.clock += 120
        self.assertEqual(self.host.watch_step(None), (None, 300))
        self.assertIn('not Ready', json.loads(self.host.watchdog_file.read_text())['last_refusal'])
        self.machine.task_is_ready = True
        self.host.watch_step(None)
        self.machine.clock += 120
        self.host.watch_step(None)
        self.assertEqual(len(self.starts()), 1)

    def test_the_watchdog_can_be_switched_off(self):
        self.config['watchdog'] = False
        self.host.watch_step(None)
        self.machine.up = False
        for _ in range(3):
            self.machine.clock += 300
            self.host.watch_step(None)
        self.assertEqual(self.starts(), [])

    def test_a_plain_host_has_no_staged_builds(self):
        with self.assertRaisesRegex(gaia_host.Refused, 'region host'):
            self.host.request_stage()
        self.assertFalse(self.host.update_pending())
