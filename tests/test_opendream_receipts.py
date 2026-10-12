"""Durable lifecycle boundaries with injected effects and isolated storage."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('receipt_control', Path(__file__).resolve().parents[1] / 'scripts/opendream/control.py')
control = importlib.util.module_from_spec(spec)
spec.loader.exec_module(control)


class Receipts(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.store = control.OperationStore(self.temp.name, 'a' * 64)
        self.request = {'id': 'operation-1', 'action': 'restart', 'map': None}
        self.effects = 0

    def tearDown(self):
        self.temp.cleanup()

    def effect(self):
        self.effects += 1
        self.assertEqual('pending', self.store.inspect('operation-1')['outcome'])
        return {'ok': True, 'running': True}

    def test_pending_before_effect_and_immutable_terminal_replay(self):
        first = self.store.perform(self.request, 'cli', self.effect)
        second = self.store.perform(self.request, 'cli', self.effect)
        self.assertEqual(first, second)
        self.assertEqual(1, self.effects)
        self.assertEqual('committed', first['receipt']['outcome'])
        for field, value in [('action', 'stop'), ('profile_digest', 'b' * 64)]:
            with self.assertRaises(ValueError):
                self.store.perform(dict(self.request, **{field: value}), 'cli', self.effect)
        with self.assertRaises(ValueError):
            self.store.perform(self.request, 'game', self.effect)
        self.assertEqual(1, self.effects)

    def test_crash_boundaries_never_reexecute_uncertain_effect(self):
        for phase, expected_effects in [('pending_published', 0), ('effect_completed', 1)]:
            with self.subTest(phase=phase):
                with tempfile.TemporaryDirectory() as directory:
                    def crash(actual):
                        if actual == phase:
                            raise KeyboardInterrupt('injected crash')
                    store = control.OperationStore(directory, 'a' * 64, crash)
                    effects = []
                    with self.assertRaises(KeyboardInterrupt):
                        store.perform(self.request, 'cli', lambda: effects.append('effect') or {'ok': True})
                    recovered = control.OperationStore(directory, 'a' * 64)
                    reply = recovered.perform(self.request, 'cli', lambda: self.fail('uncertain effect replayed'))
                    self.assertEqual('operation_pending', reply['error'])
                    self.assertEqual(expected_effects, len(effects))

    def test_crash_after_terminal_recovers_original_result(self):
        def crash(phase):
            if phase == 'terminal_published':
                raise KeyboardInterrupt('before transport publication')
        self.store.checkpoint = crash
        with self.assertRaises(KeyboardInterrupt):
            self.store.perform(self.request, 'cli', self.effect)
        recovered = control.OperationStore(self.temp.name, 'a' * 64)
        reply = recovered.perform(self.request, 'cli', lambda: self.fail('terminal effect replayed'))
        self.assertTrue(reply['ok'])
        self.assertEqual(1, self.effects)

    def test_writer_exclusion_partial_receipt_and_path_rejection(self):
        lock = self.store.path('operation-1').with_suffix('.lock')
        lock.write_text('owned writer', encoding='ascii')
        with self.assertRaises(FileExistsError):
            self.store.perform(self.request, 'cli', self.effect)
        self.assertEqual('owned writer', lock.read_text())
        lock.unlink()
        self.store.path('operation-1').write_text('{', encoding='ascii')
        with self.assertRaises(ValueError):
            self.store.perform(self.request, 'cli', self.effect)
        self.assertEqual(0, self.effects)
        for identity in ['../escape', '', 'x' * 81]:
            with self.assertRaises(ValueError):
                self.store.path(identity)

    def test_full_history_retains_pending_barrier(self):
        from unittest.mock import patch
        self.store.checkpoint = lambda phase: (_ for _ in ()).throw(KeyboardInterrupt())
        with self.assertRaises(KeyboardInterrupt):
            self.store.perform(self.request, 'cli', self.effect)
        with patch.object(control, 'MAX_OPERATIONS', 1):
            with self.assertRaisesRegex(ValueError, 'history full'):
                self.store.perform(dict(self.request, id='operation-2'), 'cli', self.effect)
        self.assertEqual('pending', self.store.inspect('operation-1')['outcome'])


if __name__ == '__main__':
    unittest.main()
