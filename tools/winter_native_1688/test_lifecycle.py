"""Offline injected winter lifecycle/plan tests. Never native execution."""
import json
import tempfile
import unittest
from pathlib import Path
from audit_offline import install, guard
install()
from prepare import bounded_file, safe_root, digest
from plan import (PHASES, PROFILES, TOTAL_WALL_SECONDS, CLEANUP_RESERVE_SECONDS,
                  copy_restart, RESTART_FILES, activation_gate, proposed_plan)
from receipts import LifecycleModel
BINDING = 'a' * 64

def process_receipt(pid=123):
    return dict(process_started=True, pid=pid, termination_observed=True, leader_reaped=True,
                cleanup_verified=True, cleanup_no_observed_live_descendants=True,
                cleanup_process_group_absent=True, owned_child_listing_available=True,
                owned_observation_trusted=True, signal_handlers_restored=True,
                exit_code=0, stop_reason=None, log_truncated=False, cleanup_errors=[])


class LifecycleTests(unittest.TestCase):
    def test_complete_fixed_order_is_explicitly_synthetic(self):
        model = LifecycleModel(BINDING)
        for n, (phase, role, variant, mode) in enumerate(PHASES):
            model.attempt(phase, n); model.started(123); model.process_returned(process_receipt())
            model.validate('causal-control-detected' if role == 'daemon' and variant != 'baseline' else 'passed', n + 0.5)
        self.assertEqual(model.state['status'], 'completed')
        self.assertIn('not-native-execution', model.state['evidence_kind'])
        self.assertTrue(model.state['compiler_completed']); self.assertTrue(model.state['daemon_completed'])
        with self.assertRaises(ValueError): model.attempt(PHASES[0][0], 100)

    def test_attempt_is_not_start_or_completion(self):
        model = LifecycleModel(BINDING); model.attempt(PHASES[0][0], 0)
        self.assertTrue(model.state['compiler_attempted']); self.assertFalse(model.state['compiler_started'])
        self.assertFalse(model.state['native_executed'])
        with self.assertRaises(ValueError): model.process_returned(process_receipt())
        model.fail('spawn rejected')
        self.assertFalse(model.state['compiler_started']); self.assertEqual(model.state['status'], 'failed')

    def test_start_fact_survives_failure_receipt_io(self):
        model = LifecycleModel(BINDING); model.attempt(PHASES[0][0], 0)
        model.fail('write failed', {'process_started': True, 'pid': 123})
        self.assertTrue(model.state['compiler_started']); self.assertTrue(model.state['native_executed'])
        self.assertFalse(model.state['compiler_completed']); self.assertFalse(model.state['phases'][0]['cleanup_verified'])

    def test_cleanup_failures_cannot_advance(self):
        required = ('termination_observed', 'leader_reaped', 'cleanup_verified', 'cleanup_no_observed_live_descendants',
                    'cleanup_process_group_absent', 'owned_child_listing_available', 'owned_observation_trusted', 'signal_handlers_restored')
        for key, value in [(k, False) for k in required] + [('exit_code', 1), ('exit_code', False), ('stop_reason', 'timeout'),
                                                         ('log_truncated', True), ('cleanup_errors', ['still alive'])]:
            with self.subTest(key=key):
                model = LifecycleModel(BINDING); model.attempt(PHASES[0][0], 0); model.started(123)
                receipt = process_receipt(); receipt[key] = value
                with self.assertRaises(ValueError): model.process_returned(receipt)
                self.assertEqual(model.state['status'], 'failed')
                with self.assertRaises(ValueError): model.attempt(PHASES[1][0], 1)

    def test_phase_order_and_pid_identity(self):
        model = LifecycleModel(BINDING)
        with self.assertRaises(ValueError): model.attempt(PHASES[1][0], 0)
        model.attempt(PHASES[0][0], 0)
        for pid in [True, 0, -1, '123']:
            with self.assertRaises(ValueError): model.started(pid)
        model.started(123)
        with self.assertRaises(ValueError): model.started(123)
        with self.assertRaises(ValueError): model.process_returned(process_receipt(124))
        with self.assertRaises(ValueError): model.fail('wrong invocation', process_receipt(124))

    def test_deadlines_and_verdict(self):
        model = LifecycleModel(BINDING)
        with self.assertRaises(ValueError): model.attempt(PHASES[0][0], TOTAL_WALL_SECONDS - CLEANUP_RESERVE_SECONDS)
        for verdict, now in [('causal-control-detected', 1), ('passed', TOTAL_WALL_SECONDS + 1), ('unknown', 1)]:
            model = LifecycleModel(BINDING); model.attempt(PHASES[0][0], 0); model.started(123); model.process_returned(process_receipt())
            with self.subTest(verdict=verdict, now=now), self.assertRaises(ValueError): model.validate(verdict, now)


class FileContractTests(unittest.TestCase):
    def test_bounded_files_reject_links_and_oversize(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root); source = root/'source'; source.write_bytes(b'abcd')
            self.assertEqual(bounded_file(source, 4), b'abcd')
            with self.assertRaises(ValueError): bounded_file(source, 3)
            link = root/'link'; link.symlink_to(source)
            with self.assertRaises(ValueError): bounded_file(link)
            with self.assertRaises(ValueError): safe_root(link)
            with self.assertRaises(ValueError): bounded_file(root)

    def test_restart_copy_sealed_fixed_names(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root); writer = root/'writer'; writer.mkdir()
            files = {}
            for name in RESTART_FILES:
                data = ('synthetic ' + name).encode(); (writer/name).write_bytes(data)
                files[name] = dict(bytes=len(data), sha256=digest(data))
            receipt = dict(candidate_manifest_sha256=BINDING, phase='baseline-writer', started=True,
                           process_completed=True, cleanup_verified=True, validated=True, restart_files=files)
            copied = copy_restart(writer, root/'reader', receipt, BINDING)
            self.assertEqual(copied, files)
            self.assertEqual(json.loads((root/'reader'/'restart-copy.json').read_text())['paths_from_save_contents'], False)
            for key, value in [('cleanup_verified', False), ('validated', 1), ('candidate_manifest_sha256', 'b'*64), ('phase', 'other')]:
                bad = dict(receipt, **{key:value})
                with self.subTest(key=key), self.assertRaises(ValueError): copy_restart(writer, root/('reader-'+key), bad, BINDING)
            (writer/'winter-food.sav').write_bytes(b'changed')
            with self.assertRaises(ValueError): copy_restart(writer, root/'changed-reader', receipt, BINDING)

    def test_restart_rejects_alias_and_unsealed_members(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root); writer=root/'writer'; writer.mkdir()
            receipt=dict(candidate_manifest_sha256=BINDING, phase='baseline-writer', started=True,
                         process_completed=True, cleanup_verified=True, validated=True, restart_files={})
            for reader in [writer, writer/'nested', root]:
                with self.assertRaises(ValueError): copy_restart(writer, reader, receipt, BINDING)
            with self.assertRaises(ValueError): copy_restart(writer, root/'reader', receipt, BINDING)


class WinterPlanTests(unittest.TestCase):
    def test_exact_fixed_phase_inventory(self):
        expected = [('baseline-compile', 'compiler', 'baseline', None)]
        expected += [('baseline-' + mode, 'daemon', 'baseline', mode)
                     for mode in ('roundtrip', 'writer', 'reader')]
        for variant in ('hardiness', 'site', 'ancestry', 'payment'):
            expected += [(variant + '-compile', 'compiler', variant, None),
                         (variant + '-roundtrip', 'daemon', variant, 'roundtrip')]
        self.assertEqual(PHASES, tuple(expected))
        self.assertEqual(sum(p[1] == 'compiler' for p in PHASES), 5)
        self.assertEqual(sum(p[1] == 'daemon' for p in PHASES), 7)

    def test_limits_and_restart_files_not_broadened(self):
        self.assertEqual(PROFILES['compiler'], dict(wall_seconds=180, cpu_seconds=150,
            address_space_bytes=2*1024**3, file_bytes=512*1024**2,
            file_descriptors=256, stdout_bytes=4*1024**2))
        self.assertEqual(PROFILES['daemon'], dict(wall_seconds=45, cpu_seconds=30,
            address_space_bytes=1024**3, file_bytes=16*1024**2,
            file_descriptors=128, stdout_bytes=4*1024**2))
        self.assertEqual(TOTAL_WALL_SECONDS, 1200)
        self.assertEqual(CLEANUP_RESERVE_SECONDS, 8)
        self.assertEqual(RESTART_FILES, {'winter-food.sav': 16*1024**2,
                                         'winter-food-entries.json': 4096})
        plan = proposed_plan(BINDING)
        self.assertIs(plan['native_executed'], False)
        self.assertEqual(plan['restart_copy']['only_files'], RESTART_FILES)
        self.assertEqual(len(plan['phases']), 12)

    def test_remaining_aggregate_budget_shortens_not_extends_profile(self):
        model = LifecycleModel(BINDING)
        remaining = model.attempt(PHASES[0][0], TOTAL_WALL_SECONDS - 20)
        self.assertEqual(remaining, 12)
        self.assertLess(remaining, PROFILES['compiler']['wall_seconds'])

    def test_activation_requires_true_not_truthiness(self):
        for value in (False, None, 1, 'yes'):
            with self.subTest(value=value), self.assertRaises(RuntimeError): activation_gate(value)
        activation_gate(True)

    def test_audit_rejects_effects_without_attempting_them(self):
        for event, args in [('subprocess.Popen', ('not-executed',)),
                            ('socket.__new__', ()), ('ctypes.dlopen', ('not-loaded',)),
                            ('open', ('/proc/123/stat',)), ('os.scandir', ('/proc',))]:
            with self.subTest(event=event), self.assertRaises(RuntimeError): guard(event, args)

if __name__ == '__main__':
    unittest.main(verbosity=2)
