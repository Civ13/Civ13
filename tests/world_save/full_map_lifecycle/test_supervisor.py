"""Offline acceptance controls; these never compile or launch BYOND."""
import copy
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from prepare import BASE, HOOK, instrument_lifecycle, instrument_world
from query import request
from run import compare, diagnostic_failures, owned_daemon


class RecoveryAcceptance(unittest.TestCase):
    def setUp(self):
        self.before = dict(session='old', source=BASE, map='NOMADS_EUROPE',
                           maxx=4, maxy=4, maxz=1, game_id='durable', playing=True,
                           import_complete=False, save_busy=False, restart_busy=False,
                           restart_hold=False, intent=False, error=None, storage_error=None,
                           generation='round-v2:old', clients=0, season='SPRING', time_of_day='Midday',
                           research_clock=100, fixture=dict(seeded=True, crates=1,
                           nested_knives=1, baseline=dict(crate='owned', knife='nested', x=20)))
        self.after = copy.deepcopy(self.before)
        self.after.update(session='new', import_complete=True, generation='round-v2:new')
        self.receipt = dict(generation='round-v2:new', status=copy.deepcopy(self.before))
        self.receipt['saved_environment'] = {k: self.before[k] for k in
                                            ('season', 'time_of_day', 'research_clock')}

    def test_complete_recovery(self):
        compare(self.before, self.after, self.receipt)

    def test_incomplete_or_corrupt_recovery_controls(self):
        mutations = [('session', 'old'), ('source', 'other'), ('maxx', 5),
                     ('game_id', 'fresh'), ('playing', False), ('import_complete', False),
                     ('save_busy', True), ('restart_busy', True), ('restart_hold', True),
                     ('intent', True), ('generation', 'different'), ('error', 'failure'),
                     ('storage_error', 'failure'), ('research_clock', 99), ('season', 'WINTER'), ('clients', 1)]
        for key, value in mutations:
            with self.subTest(key=key):
                changed = copy.deepcopy(self.after)
                changed[key] = value
                with self.assertRaises(AssertionError):
                    compare(self.before, changed, self.receipt)
        for key in ('session', 'source', 'game_id', 'maxx'):
            changed = copy.deepcopy(self.receipt)
            changed['status'][key] = 'wrong'
            with self.subTest(receipt=key), self.assertRaises(AssertionError):
                compare(self.before, self.after, changed)
        for key, value in [('crates', 0), ('nested_knives', 2), ('seeded', False),
                           ('baseline', {'crate': 'replacement'})]:
            with self.subTest(fixture=key):
                changed = copy.deepcopy(self.after)
                changed['fixture'][key] = value
                with self.assertRaises(AssertionError):
                    compare(self.before, changed, self.receipt)


class ProductionInstrumentation(unittest.TestCase):
    def test_frozen_anchors_and_reversible_observers(self):
        repository = Path(__file__).resolve().parents[3]
        paths = ('code/world.dm', 'code/game/gameticker.dm',
                 'code/modules/1713/roundstart_etc.dm',
                 'code/modules/persistence/restart_transaction.dm')
        for path in paths:
            source = subprocess.check_output(['git', '-C', str(repository), 'show',
                                              f'{BASE}:{path}']).decode('utf-8').replace('\r\n', '\n')
            with self.subTest(path=path):
                observed = instrument_world(source) if path == paths[0] else instrument_lifecycle(path, source)
                if path == paths[0]:
                    restored = observed.replace(HOOK, '')
                else:
                    restored = ''.join(line for line in observed.splitlines(keepends=True)
                                       if 'full_map_probe_' not in line)
                self.assertEqual(source, restored)
                with self.assertRaises(ValueError):
                    (instrument_world if path == paths[0] else
                     lambda s: instrument_lifecycle(path, s))(source + source)


class Framing(unittest.TestCase):
    def send(self, body):
        class Connection:
            def __init__(self):
                import struct
                self.data = bytearray(b'\0\x83' + struct.pack('>H', len(body)) + body)
            def __enter__(self): return self
            def __exit__(self, *args): pass
            def sendall(self, data): self.sent = data
            def recv(self, count):
                count = min(count, 2)
                data = self.data[:count]
                del self.data[:count]
                return bytes(data)
        with patch('query.socket.create_connection', return_value=Connection()):
            return request(18463, 'private', 'status', 'observe')

    def test_fragmented_response_and_refusal(self):
        self.assertEqual(self.send(b'\x06{"ok":1}\0'), {'ok': 1})
        with self.assertRaises(PermissionError): self.send(b'\x06rejected\0')
        with self.assertRaises(RuntimeError): self.send(b'\x06[]\0')
        with self.assertRaises(RuntimeError): self.send(b'\x02bad\0')
        with self.assertRaises(json.JSONDecodeError): self.send(b'\x06{partial\0')


class ProcessAndDiagnosticControls(unittest.TestCase):
    def test_launch_record_failure_stops_only_new_handle(self):
        class Process:
            stopped = False
            def poll(self): return None if not self.stopped else 0
            def terminate(self): self.stopped = True
            def wait(self, timeout): return 0
        process = Process()
        with patch('run.subprocess.Popen', return_value=process) as spawn:
            with self.assertRaises(OSError):
                with owned_daemon(['owned-only']):
                    raise OSError('Injected host receipt write failure')
        self.assertTrue(process.stopped)
        spawn.assert_called_once_with(['owned-only'])

    def test_engine_diagnostic_controls(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            log = root / 'daemon.stderr.log'
            log.write_text('Normal startup\n', encoding='utf-8')
            self.assertEqual(diagnostic_failures(root), [])
            for marker in ('runtime error:', 'Bad ref', 'Bad loc', '##ERROR', 'BUG:',
                           '[timestamp] Runtime in saving.dm,12: exception',
                           'Uncaught exception:', '## ERROR:'):
                log.write_text(f'Normal startup\n{marker} injected\n', encoding='utf-8')
                with self.subTest(marker=marker):
                    self.assertEqual(diagnostic_failures(root)[0]['line'], 2)
            log.write_text('Normal startup\n', encoding='utf-8')
            for relative in ('game/native.log', 'game/data/logs/runtime/probe-runtime.txt'):
                target = root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text('[timestamp] Runtime in saving.dm,12: exception\n', encoding='utf-8')
                with self.subTest(path=relative):
                    self.assertTrue(any(row['path'] == str(Path(relative)) for row in diagnostic_failures(root)))
                target.write_text('Normal startup\n', encoding='utf-8')


if __name__ == '__main__':
    unittest.main(verbosity=2)
