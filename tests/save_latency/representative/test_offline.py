"""Injected controls only: no sockets, native process, compiler or private input."""
from copy import deepcopy
import hashlib
import importlib.util
import json
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import files
import protocol
import sampler
import source


def identity(number=1):
    return {'version': 1, 'generation': 'round-v2:' + str(number) * 32,
            'metadata': 'a' * 32, 'round': 'b' * 32}


def process(pid=1):
    return {'pid': pid, 'started_utc': '2026-10-21T12:00:00Z', 'binary_sha256': 'a' * 64}


def status(phase='idle', marker=0, generation='', session='writer'):
    return {'source': source.CANDIDATE, 'session': session, 'clients': 0,
            'save_busy': 0, 'restart_busy': 0, 'restart_hold': 0, 'intent': 0,
            'import_complete': 1, 'playing': 1, 'ready': 1, 'generation': generation,
            'map': 'NOMADS_EUROPE', 'maxx': 375, 'maxy': 447, 'maxz': 2, 'game_id': 'round',
            'fixture': {'seeded': 1, 'crates': 1, 'nested_knives': 1, 'baseline': {'crate': 'actual crate'}},
            'representative': {'phase': phase, 'marker': marker, 'heartbeat': 3,
                               'receipt': {'identity': identity(marker), 'marker': marker, 'session': session}}}


class Host:
    def __init__(self):
        self.actions = []
    def status(self):
        return status()
    def query(self, action, session):
        self.actions.append((action, session))
        return status(action + '_pending')
    def poll(self, phase, session, deadline):
        marker = 1 if phase == 'first_complete' else 2
        return status(phase, marker, identity(marker)['generation'])


class Clock:
    def __init__(self):
        self.now = 0.0
    def __call__(self):
        return self.now
    def wait(self, seconds):
        self.now += seconds


class SourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Harmless local Git reads only. No preparation exports or native tools.
        cls.repo = HERE.parents[2]
        paths = ('civ13.dme', 'code/world.dm', 'code/game/gameticker.dm',
                 'code/modules/1713/roundstart_etc.dm', source.MAP, *source.PRODUCTION)
        cls.cache = {(commit, path): source.git_source(cls.repo, commit, path)
                     for commit in (source.REFERENCE, source.CANDIDATE) for path in paths}
        for name in ('prepare.py', 'control.dm', 'query.py', 'run.py'):
            path = 'tests/world_save/full_map_lifecycle/' + name
            cls.cache[(source.HELPERS, path)] = source.git_source(cls.repo, source.HELPERS, path)

    def reader(self, repo, commit, path):
        return self.cache[(commit, path)]

    def test_both_actual_sources_prepare_without_effects(self):
        with tempfile.TemporaryDirectory() as temporary:
            for commit in (source.REFERENCE, source.CANDIDATE):
                output = Path(temporary) / commit
                with patch.object(subprocess, 'Popen', side_effect=AssertionError('native process forbidden')), patch.object(socket, 'socket', side_effect=AssertionError('socket forbidden')):
                    manifest = source.prepare(self.repo, commit, output, self.reader)
                self.assertFalse(manifest['execution_ready'])
                self.assertFalse(manifest['production_serializer_modified'])
                for path in source.PRODUCTION:
                    self.assertEqual(manifest['source_sha256'][path], source.sha(self.cache[(commit, path)]))
                dme = (output / 'representative.dme').read_text()
                self.assertIn('#include "maps\\nomads\\nomads_europe.dmm"', dme)
                self.assertIn('#include "representative/probe.dm"', dme)
                self.assertIn('return representative_save_action', (output / 'control.dm').read_text())
                self.assertNotIn('saving.dm', manifest['generated_sha256'])

    def test_real_unsupported_anchor_refuses_before_writing(self):
        def missing(repo, commit, path):
            data = self.reader(repo, commit, path)
            return data.replace(b'/world/Topic(T, addr, master, key)', b'/world/Topic_CHANGED(T, addr, master, key)') if path == 'code/world.dm' else data
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / 'refused'
            with self.assertRaisesRegex(ValueError, 'Expected one production'):
                source.prepare(self.repo, source.CANDIDATE, output, missing)
            self.assertFalse(output.exists())

    def test_preserves_existing_output_and_refuses_unknown_commit(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary)
            (path / 'keep').write_text('untouched')
            with self.assertRaises(ValueError):
                source.prepare(self.repo, source.CANDIDATE, path, self.reader)
            with self.assertRaises(ValueError):
                source.prepare(self.repo, 'f' * 40, path / 'new', self.reader)
            self.assertEqual((path / 'keep').read_text(), 'untouched')

    def test_actual_dm_phase_calls_production_and_is_private_test_only(self):
        dm = (HERE / 'probe.dm').read_text()
        self.assertEqual(dm.count('ticker.savemap()'), 1)
        self.assertIn('persistence_restart.current_identity()', dm)
        self.assertIn('fexists("map_saves/save_complete.txt")', dm)
        self.assertNotIn('persistence_restart.execute()', dm)
        self.assertNotIn('TICK_CHECK', dm)


class SamplerTests(unittest.TestCase):
    def test_observed_counter_stalls_and_timeout_are_not_filled(self):
        clock = Clock()
        def request(timeout):
            clock.now += timeout
            if clock.now < .15:
                raise TimeoutError
            return 7  # Counter is deliberately stalled, never manufactured progress.
        rows = sampler.sample(request, clock, clock.wait, duration=.6, cadence=.1, max_samples=6)
        self.assertEqual(rows[0]['status'], 'timeout')
        self.assertNotIn('heartbeat', rows[0])
        self.assertTrue(all(row.get('heartbeat', 7) == 7 for row in rows))
        self.assertTrue(all(row['received'] >= row['sent'] for row in rows))

    def test_slow_transport_is_explicit_and_does_not_queue_burst(self):
        clock = Clock()
        def slow(timeout):
            clock.now += .35
            return 1
        rows = sampler.sample(slow, clock, clock.wait, duration=1, cadence=.1, max_samples=10)
        self.assertLessEqual(len(rows), 3)
        self.assertTrue(all(row['status'] == 'transport_exceeded_timeout' for row in rows))
        self.assertGreaterEqual(rows[0]['skipped_after'], 3)

    def test_bounds_refuse_before_transport(self):
        for duration, cadence, count in ((float('inf'), .1, 5), (1, 0, 5), (1, .1, 1)):
            with self.assertRaises(ValueError):
                sampler.sample(lambda _: self.fail('transport ran'), lambda: 0, lambda _: None,
                               duration=duration, cadence=cadence, max_samples=count)


class ProtocolTests(unittest.TestCase):
    def test_two_saves_uses_real_phase_order_but_never_claims_full_acceptance(self):
        host = Host()
        result = protocol.two_saves(host, source.CANDIDATE, 10, lambda: 0)
        self.assertEqual(host.actions, [('first', 'writer'), ('second', 'writer')])
        self.assertFalse(result['acceptance'])
        self.assertEqual(result['fresh_backup_reader'], 'NOT EXECUTED')

    def test_bad_source_session_and_pending_receipt_refused(self):
        valid = status('first_complete', 1, identity()['generation'])
        for mutate in (lambda s: s.update(source='f' * 40), lambda s: s.update(session='stale'),
                       lambda s: s['representative'].update(phase='first_pending'),
                       lambda s: s.update(save_busy=1), lambda s: s.update(generation='wrong')):
            value = deepcopy(valid)
            mutate(value)
            with self.assertRaises(ValueError):
                protocol.saved_receipt(value, source.CANDIDATE, 'writer', 'first_complete', 1)

    def test_reader_requires_actual_new_process_boot_graph_and_complete_import(self):
        before = status('second_complete', 2, identity(2)['generation'])
        after = status(marker=2, generation=identity(2)['generation'], session='reader')
        protocol.compare_reader(before, after, source.CANDIDATE, identity(2), 2, process(1), process(2))
        for mutate in (lambda s: s.update(session='writer'), lambda s: s.update(import_complete=0),
                       lambda s: s.update(intent=1), lambda s: s.update(maxx=2),
                       lambda s: s['fixture'].update(crates=2), lambda s: s['representative'].update(marker=1)):
            value = deepcopy(after)
            mutate(value)
            with self.assertRaises(ValueError):
                protocol.compare_reader(before, value, source.CANDIDATE, identity(2), 2, process(1), process(2))
        with self.assertRaisesRegex(ValueError, 'distinct owned'):
            protocol.compare_reader(before, after, source.CANDIDATE, identity(2), 2, process(1), process(1))
        with self.assertRaisesRegex(ValueError, 'Missing owned process'):
            protocol.compare_reader(before, after, source.CANDIDATE, identity(2), 2, 'invented writer', process(2))

    def test_expired_budget_does_not_touch_host(self):
        with self.assertRaises(TimeoutError):
            protocol.two_saves(None, source.CANDIDATE, 1, lambda: 1)


class GenerationTests(unittest.TestCase):
    def test_real_file_copy_hashes_and_identity_refuse_changed_backup(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            generation = root / 'active'
            generation.mkdir()
            I = identity()
            (generation / 'map.txt').write_bytes(b'public metadata\r\n')
            (generation / 'round.json').write_text(json.dumps({'generation': I['generation']}))
            (generation / 'save_complete.txt').write_text(I['generation'] + '\n')
            (generation / '1.sav').write_bytes(b'opaque test bytes, not native proof')
            for field, name in (('metadata', 'map.txt'), ('round', 'round.json')):
                I[field] = hashlib.md5((generation / name).read_bytes().replace(b'\r\n', b'\n')).hexdigest()
            receipt = files.freeze_generation(generation, root / 'frozen', I)
            self.assertFalse(receipt['native_contents_validated_here'])
            result = files.stage_reader(root / 'frozen', root / 'reader', receipt)
            self.assertFalse(result['native_restore_executed'])
            self.assertEqual(json.loads((root / 'reader/restart_intent.json').read_text()), I)
            (root / 'frozen/1.sav').write_bytes(b'changed backup')
            with self.assertRaisesRegex(ValueError, 'Frozen generation changed'):
                files.stage_reader(root / 'frozen', root / 'refused', receipt)
            self.assertFalse((root / 'refused').exists())

    def test_incomplete_or_unknown_outputs_are_not_accepted(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            with self.assertRaises(ValueError):
                files.inventory(root)
            (root / 'pending.sav').write_bytes(b'uncertain')
            with self.assertRaises(ValueError):
                files.inventory(root)


if __name__ == '__main__':
    unittest.main()
