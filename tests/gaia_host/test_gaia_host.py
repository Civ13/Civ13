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

    def run(self, argv, cwd=None, timeout=1800):
        self.calls.append(list(argv))
        if argv[1:] == ['rev-parse', 'HEAD']:
            return 0, REVISION + '\n'
        if argv[-1] == 'civ13.dme':
            return (0 if '0 errors' in self.compile_output else 1), self.compile_output
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
        return {'ok': True, 'ready': True, 'busy': False, 'session': SESSION, 'clients': 2, 'map': 'NOMADS_GAIA',
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

    def now(self):
        return self.clock


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


if __name__ == '__main__':
    unittest.main()
