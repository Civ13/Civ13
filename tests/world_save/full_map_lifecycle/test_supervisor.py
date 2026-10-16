"""Offline acceptance controls; these never compile or launch BYOND."""
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from prepare import BASE, HOOK, instrument_lifecycle, instrument_world, prepare
from query import request
from run import compare, diagnostic_failures, owned_daemon, verify_completed_files
from replay import replay


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


class CompletedFileIdentity(unittest.TestCase):
    def test_replay_rejects_each_missing_diagnostic_log(self):
        required = ('daemon.stdout.log', 'daemon.stderr.log', 'game/native.log')
        for missing in required:
            with self.subTest(missing=missing), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                for relative in required:
                    target = root / relative
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_text('Retained log\n', encoding='utf-8')
                (root / missing).unlink()
                with self.assertRaisesRegex(FileNotFoundError, 'Incomplete diagnostic evidence'):
                    replay(root)

    def test_raw_parity_and_normalized_text_identity(self):
        for newline in (b'\n', b'\r\n'):
            with self.subTest(newline=newline), tempfile.TemporaryDirectory() as temp:
                game = Path(temp)
                saves = game / 'map_saves'
                saves.mkdir()
                payloads = {'map.txt': b'NOMADS_EUROPE' + newline,
                            'round.json': b'{"round":"saved"}' + newline,
                            '1.sav': b'\x00\r\n\xff'}
                receipt = {'files_md5': {}}
                for name, content in payloads.items():
                    (saves / name).write_bytes(content)
                    receipt['files_md5'][name] = hashlib.md5(content).hexdigest()
                for key, name in (('metadata', 'map.txt'), ('round', 'round.json')):
                    receipt[key] = hashlib.md5(payloads[name].replace(b'\r\n', b'\n')).hexdigest()
                verify_completed_files(game, receipt)
                for key in ('metadata', 'round'):
                    changed = copy.deepcopy(receipt)
                    changed[key] = 'wrong'
                    with self.assertRaises(AssertionError):
                        verify_completed_files(game, changed)
                for name, content in payloads.items():
                    (saves / name).write_bytes(content + b'changed')
                    with self.assertRaises(AssertionError):
                        verify_completed_files(game, receipt)
                    (saves / name).write_bytes(content)
                if newline == b'\r\n':
                    # Even a text-equivalent newline rewrite must fail raw parity.
                    (saves / 'map.txt').write_bytes(payloads['map.txt'].replace(b'\r\n', b'\n'))
                    with self.assertRaises(AssertionError):
                        verify_completed_files(game, receipt)


class ProductionInstrumentation(unittest.TestCase):
    def test_prepared_trace_preserves_observers_and_staged_inputs(self):
        repository = Path(__file__).resolve().parents[3]
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / 'packet'
            manifest = prepare(repository, output)
            game = output / 'game'
            trace = manifest['startup_trace']
            self.assertFalse(manifest['launched'])
            self.assertFalse(trace['native_execution'])
            for name, expected in trace['inputs_sha256'].items():
                self.assertEqual(hashlib.sha256((game / name).read_bytes()).hexdigest(), expected)
            entry = (game / manifest['entrypoint']).read_text(encoding='utf-8')
            for include in ('full-map-probe.dm', 'tests/world_save/progress-probe.dm'):
                self.assertIn(f'#include "{include}"', entry)
            for name in ('code/world.dm', 'code/game/objects/map_metadata/_map_metadata.dm',
                         'code/game/objects/map_metadata/nomads/nomads.dm'):
                observed = (output / 'startup-trace' / ('trace-' + Path(name).name)).read_text(encoding='utf-8')
                restored = ''.join(line for line in observed.splitlines(keepends=True)
                                   if '"startup-construction-trace.log")' not in line)
                self.assertEqual(restored, (game / name).read_text(encoding='utf-8'))
            self.assertIn(HOOK, (output / 'startup-trace/trace-world.dm').read_text(encoding='utf-8'))
            with self.assertRaises(FileExistsError):
                prepare(repository, output)

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
