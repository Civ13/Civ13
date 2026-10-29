"""Injected same-command admission controls; never query the host or launch BYOND."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch
import run
import same_command as command


class SameCommandContracts(unittest.TestCase):
    def setUp(self):
        self.root = Path(self.enterContext(tempfile.TemporaryDirectory())).resolve()
        self.ledger = self.root / 'ledger'; self.ledger.mkdir()
        self.path = self.root / 'owner.json'
        self.clock = [0.0, 1000.0]
        self.enterContext(patch.object(command.time, 'monotonic', side_effect=lambda: self.clock[0]))
        self.enterContext(patch.object(command.time, 'time', side_effect=lambda: self.clock[1]))
        self.enterContext(patch.dict(command.os.environ, COMPUTERNAME='host', USERDOMAIN='domain', USERNAME='user'))
        self.packet = dict(schema=1, scope='dreamseeker-smoke-local-installed',
            host='host', account='domain\\user', one_use_id='b08a4280-eaef-4efe-a78d-47b1fd563035',
            task_root=str(self.root), ledger=str(self.ledger), output=str(self.root / 'output'),
            python=dict(path='sealed-python', sha256='0' * 64), pillow_version='sealed', pillow_sha256={},
            installed_manifest='sealed-installed', runtime=dict(manifest='sealed-runtime', sha256='0' * 64),
            dependency_record=dict(path='sealed-dependencies', sha256='0' * 64),
            source_sha256=run.source_identity(), issued_unix=None, expires_unix=None, resources=None,
            profile=dict(decision='shared_effects_explicitly_accepted', accepted_effects=run.SHARED_EFFECTS,
                         evidence_reference='external reviewed effects'),
            review=dict(reference='independent owner review', reviewer='reviewer', resource_owner='owner',
                        executor='executor', desktop_owner='executor', native_execution_approved=True,
                        exclusive_desktop_approved=True, socket_polling_limitation_accepted=True),
            limits=dict(run_seconds=150, cleanup_seconds_per_job=5, cpu_seconds_per_process=60, **run.LIMITS))
        self.envelope = dict(schema=1, scope='dreamseeker-smoke-same-command-owner', enabled=True,
            authority_reference='NEW external human attempt approval; synthetic test only',
            not_before_unix=990, expires_unix=1200, dynamic_fields=command.DYNAMIC,
            sampling_policy=dict(sample_seconds=1, max_cpu_busy_fraction=.1,
                                 min_free_ram_bytes=2 * 1024**3, min_free_disk_bytes=1024**3,
                                 max_sample_age_seconds=5), admission=self.packet)
        self.sample = Mock(side_effect=self.good_sample)
        self.runner = self.enterContext(patch.object(run, 'run', side_effect=self.injected_runner))
        self.observed = []

    def advance(self, seconds, wall=True):
        self.clock[0] += seconds
        if wall:
            self.clock[1] += seconds

    def good_sample(self, root, budget):
        budget.check(); self.advance(1); budget.check()
        return dict(measured_unix=self.clock[1], free_ram_bytes=3 * 1024**3,
                    free_disk_bytes=2 * 1024**3, cpu_busy_fraction=.05,
                    input_unchanged=True, foreground_stable=True, input_desktop_access=True,
                    conflicts_absent=True, host='host', account='domain\\user')

    def injected_runner(self, output, admission, digest, *, budget):
        budget.check()
        packet = run.read_json(admission)
        run.local_deadline(dict(packet=packet, budget=budget))
        self.observed.append((budget, packet, output, digest))
        return 'injected runner only'

    def write(self):
        self.path.write_text(json.dumps(self.envelope))
        return run.digest(self.path)

    def invoke(self, **kwargs):
        return command.execute(self.path, self.write(), enabled=True, sampler=self.sample, **kwargs)

    def test_fast_path_uses_same_original_budget_and_only_delegated_fields(self):
        budget = run.Budget()
        self.invoke(budget=budget)
        self.assertIs(self.observed[0][0], budget)
        self.assertEqual(budget.started_monotonic, 0)
        self.assertEqual(budget.full_end, 165)
        actual = self.observed[0][1]
        for key, value in self.packet.items():
            if key not in command.DYNAMIC:
                self.assertEqual(actual[key], value)
        self.assertEqual(actual['issued_unix'], 1001)
        self.assertEqual(actual['expires_unix'], 1165)
        self.assertTrue(actual['resources']['cpu_headroom_accepted'])
        self.sample.assert_called_once()
        finalization = run.read_json(self.root / 'same-command-finalization.json')
        self.assertEqual(finalization['owner_envelope_sha256'], run.digest(self.path))
        self.assertEqual(finalization['admission_sha256'], self.observed[0][3])

    def test_default_off_and_unreviewed_digest_never_sample(self):
        digest = self.write()
        with self.assertRaisesRegex(RuntimeError, 'OFF'):
            command.execute(self.path, digest, sampler=self.sample)
        with self.assertRaisesRegex(RuntimeError, 'envelope changed'):
            command.execute(self.path, '0' * 64, enabled=True, sampler=self.sample)
        self.sample.assert_not_called(); self.runner.assert_not_called()

    def test_old_handoff_117_seconds_after_sample_refuses_before_runner(self):
        def delayed(root, budget):
            row = self.good_sample(root, budget); self.advance(117); return row
        self.sample.side_effect = delayed
        with self.assertRaisesRegex(RuntimeError, 'sample stale'):
            self.invoke()
        self.runner.assert_not_called(); self.sample.assert_called_once()

    def test_pre_sample_117_seconds_remain_charged(self):
        original = run.source_identity
        calls = [0]
        def slow_identity():
            calls[0] += 1
            if calls[0] == 1:
                self.advance(117)
            return original()
        self.write()
        with patch.object(run, 'source_identity', side_effect=slow_identity):
            command.execute(self.path, run.digest(self.path), enabled=True, sampler=self.sample)
        budget = self.observed[0][0]
        self.assertEqual(budget.started_monotonic, 0)
        self.assertEqual(budget.full_end, 165)
        self.assertEqual(budget.remaining(work=True), 31)

    def test_pre_sample_work_exhaustion_never_samples(self):
        self.write(); original = run.source_identity
        def slow():
            self.advance(150); return original()
        with patch.object(run, 'source_identity', side_effect=slow):
            with self.assertRaisesRegex(RuntimeError, 'budget exhausted'):
                command.execute(self.path, run.digest(self.path), enabled=True, sampler=self.sample)
        self.sample.assert_not_called(); self.runner.assert_not_called()

    def test_expired_or_refused_owner_never_samples(self):
        original = copy.deepcopy(self.envelope)
        mutations = [lambda e: e.update(expires_unix=999), lambda e: e.update(enabled=False),
                     lambda e: e['admission']['review'].update(native_execution_approved=False),
                     lambda e: e.update(dynamic_fields=['source_sha256']),
                     lambda e: e['sampling_policy'].update(sample_seconds=2),
                     lambda e: e['sampling_policy'].update(max_cpu_busy_fraction=float('nan')),
                     lambda e: e['admission'].update(unreviewed='extra')]
        for mutate in mutations:
            self.envelope = copy.deepcopy(original); mutate(self.envelope)
            with self.assertRaises(RuntimeError):
                self.invoke()
        self.sample.assert_not_called(); self.runner.assert_not_called()

    def test_actual_resource_input_access_or_host_refusal_consumes_entry(self):
        for field, value in [('input_unchanged', False), ('foreground_stable', False),
                             ('input_desktop_access', False), ('conflicts_absent', False),
                             ('host', 'other'), ('free_ram_bytes', 1), ('free_disk_bytes', 1),
                             ('cpu_busy_fraction', .5), ('cpu_busy_fraction', True)]:
            # Separate fresh sealed run for each independent injected failure.
            with self.subTest(field=field, value=value):
                case = self.root / str(len(list(self.root.iterdir()))); case.mkdir()
                self.packet['task_root'] = str(case); self.packet['ledger'] = str(case / 'ledger')
                self.packet['output'] = str(case / 'output'); (case / 'ledger').mkdir()
                def failed(root, budget):
                    row = self.good_sample(root, budget); row[field] = value; return row
                self.sample.side_effect = failed
                with self.assertRaises(RuntimeError):
                    self.invoke()
                self.assertEqual(len(list((case / 'ledger').glob('*.entry.json'))), 1)
                with self.assertRaises(FileExistsError):
                    self.invoke()
        self.runner.assert_not_called()

    def test_mutation_during_sample_and_final_write_cannot_reach_runner(self):
        def mutate(root, budget):
            row = self.good_sample(root, budget)
            self.envelope['admission']['review']['executor'] = 'other'
            self.path.write_text(json.dumps(self.envelope)); return row
        self.sample.side_effect = mutate
        with self.assertRaisesRegex(RuntimeError, 'envelope changed'):
            self.invoke()
        self.runner.assert_not_called()

    def test_final_fsync_delay_and_policy_expiry_refuse(self):
        original = command.os.fsync; calls = [0]
        def slow(fd):
            original(fd); calls[0] += 1
            if calls[0] == 3:
                self.advance(117)
        with patch.object(command.os, 'fsync', side_effect=slow):
            with self.assertRaisesRegex(RuntimeError, 'sample stale'):
                self.invoke()
        self.runner.assert_not_called()

    def test_uncertain_entry_write_remains_durable_no_resample(self):
        with patch.object(command.os, 'fsync', side_effect=OSError('uncertain entry write')):
            with self.assertRaisesRegex(OSError, 'uncertain entry write'):
                self.invoke()
        self.assertEqual(len(list(self.ledger.glob('*.entry.json'))), 1)
        with self.assertRaises(FileExistsError):
            self.invoke()
        self.sample.assert_not_called(); self.runner.assert_not_called()

    def test_primary_runner_error_preserved_if_receipt_fails(self):
        self.runner.side_effect = RuntimeError('primary injected runner failure')
        with patch.object(command, '_result', side_effect=OSError('receipt refused')):
            with self.assertRaisesRegex(RuntimeError, 'primary injected runner failure') as caught:
                self.invoke()
        self.assertTrue(any('receipt refused' in note for note in caught.exception.__notes__))
        self.sample.assert_called_once()

    def test_final_receipt_overrun_cannot_return_success(self):
        original = command._result
        def slow(*args):
            original(*args); self.advance(166)
        with patch.object(command, '_result', side_effect=slow):
            with self.assertRaisesRegex(RuntimeError, 'budget exhausted'):
                self.invoke()

    def test_delay_after_finalization_is_rejected_by_actual_harness_deadline(self):
        runner = self.injected_runner
        def delayed(*args, **kwargs):
            self.advance(117)
            return runner(*args, **kwargs)
        self.runner.side_effect = delayed
        with self.assertRaisesRegex(RuntimeError, 'Fresh admitted resources unavailable'):
            self.invoke()
        self.assertFalse(self.observed)
        self.sample.assert_called_once()

    def test_owner_expiry_during_sample_refuses(self):
        self.envelope['expires_unix'] = 1020
        def delayed(root, budget):
            row = self.good_sample(root, budget); self.advance(20); return row
        self.sample.side_effect = delayed
        with self.assertRaises(RuntimeError):
            self.invoke()
        self.sample.assert_called_once()
        self.runner.assert_not_called()

    def test_owner_mutation_after_final_write_refuses(self):
        original = command.os.fsync; calls = [0]
        def mutate(fd):
            original(fd); calls[0] += 1
            if calls[0] == 3:
                altered = copy.deepcopy(self.envelope)
                altered['admission']['limits']['run_seconds'] = 999
                self.path.write_text(json.dumps(altered))
        with patch.object(command.os, 'fsync', side_effect=mutate):
            with self.assertRaisesRegex(RuntimeError, 'envelope changed'):
                self.invoke()
        self.runner.assert_not_called()

    def test_unsealed_profile_bool_schema_and_extra_sample_fields_refuse(self):
        self.envelope['schema'] = True
        with self.assertRaises(RuntimeError):
            self.invoke()
        self.envelope['schema'] = 1
        self.packet['profile']['decision'] = 'unresolved'
        with self.assertRaisesRegex(RuntimeError, 'profile refusal'):
            self.invoke()
        self.packet['profile']['decision'] = 'shared_effects_explicitly_accepted'
        def extra(root, budget):
            row = self.good_sample(root, budget); row['cpu_headroom_accepted'] = True; return row
        self.sample.side_effect = extra
        with self.assertRaisesRegex(RuntimeError, 'sample fields'):
            self.invoke()
        self.sample.assert_called_once(); self.runner.assert_not_called()

    def test_utc_forward_jump_then_rollback_cannot_restore_original_budget(self):
        budget = run.Budget()
        self.clock[1] += 140
        budget.remaining()
        self.clock[1] -= 140
        self.assertLessEqual(budget.remaining(work=True), 9)
        self.advance(10)
        with self.assertRaisesRegex(RuntimeError, 'budget exhausted'):
            self.invoke(budget=budget)
        self.runner.assert_not_called()

    def test_duplicate_and_linked_owner_inputs_never_sample(self):
        self.path.write_text('{"schema":1,"schema":1}')
        with self.assertRaisesRegex(RuntimeError, 'Duplicate'):
            command.execute(self.path, run.digest(self.path), enabled=True, sampler=self.sample)
        digest = self.write()
        with patch.object(Path, 'is_symlink', return_value=True):
            with self.assertRaisesRegex(RuntimeError, 'Linked'):
                command.execute(self.path, digest, enabled=True, sampler=self.sample)
        self.sample.assert_not_called()

    def test_real_sampler_with_injected_windows_calls_allows_null_foreground(self):
        self.assert_sampler()

    def test_real_sampler_conflict_refuses_without_sleep_or_retry(self):
        self.assert_sampler(conflict=True)

    def test_real_sampler_access_refuses_without_sleep_or_retry(self):
        self.assert_sampler(access=False)

    def test_actual_sampler_and_wrapper_reject_delayed_second_snapshot(self):
        self.assert_sampler(scan_delay=117, through_wrapper=True)

    def test_actual_sampler_and_wrapper_reject_delayed_first_snapshot(self):
        self.assert_sampler(scan_delay=117, scan_index=1, through_wrapper=True)

    def test_actual_sampler_and_wrapper_reject_delayed_desktop_access(self):
        self.assert_sampler(access_delay=117, through_wrapper=True)

    def test_actual_final_digest_cannot_reseal_rewritten_executor(self):
        original = run.digest
        rewritten = []
        def coherent_rewrite(path):
            if Path(path).name == 'same-command-admission.json' and not rewritten:
                packet = run.read_json(Path(path))
                packet['review']['executor'] = 'UNDELEGATED_EXECUTOR'
                Path(path).write_text(json.dumps(packet, indent=2) + '\n')
                rewritten.append(True)
            return original(path)
        with patch.object(run, 'digest', side_effect=coherent_rewrite):
            with self.assertRaisesRegex(RuntimeError, 'Final admission changed'):
                self.invoke()
        self.assertEqual(rewritten, [True])
        self.runner.assert_not_called()

    def test_actual_first_entry_digest_cannot_reseal_wrong_envelope(self):
        original = run.digest
        rewritten = []
        owner_hash = self.write()
        def coherent_rewrite(path):
            if Path(path).name.endswith('.entry.json') and not rewritten:
                entry = run.read_json(Path(path))
                entry['owner_envelope_sha256'] = '0' * 64
                Path(path).write_text(json.dumps(entry, indent=2) + '\n')
                rewritten.append(True)
            return original(path)
        with patch.object(run, 'digest', side_effect=coherent_rewrite):
            with self.assertRaisesRegex(RuntimeError, 'Entry claim changed'):
                command.execute(self.path, owner_hash, enabled=True, sampler=self.sample)
        self.assertEqual(rewritten, [True])
        self.assertEqual(original(self.path), owner_hash)
        self.assertFalse((self.root / 'same-command-admission.json').exists())
        self.sample.assert_not_called(); self.runner.assert_not_called()

    def test_actual_sampler_retains_primary_conflict_on_close_failure(self):
        self.assert_sampler(conflict=True, close_failure=True)

    def test_actual_sampler_close_failure_alone_stays_fatal(self):
        self.assert_sampler(close_failure=True)

    def assert_sampler(self, conflict=False, access=True, scan_delay=0, scan_index=2,
                       access_delay=0, close_failure=False, through_wrapper=False):
        import ctypes as c
        from types import SimpleNamespace
        k, u = Mock(), Mock()
        snapshots = [0]
        def snapshot(*args):
            snapshots[0] += 1
            if snapshots[0] == scan_index:
                self.advance(scan_delay)
            return 1
        k.CreateToolhelp32Snapshot.side_effect = snapshot
        if close_failure:
            k.CloseHandle.side_effect = OSError('injected snapshot CloseHandle failure')
        else:
            k.CloseHandle.return_value = True
        def first(handle, pointer):
            pointer._obj.exe = 'dd.exe' if conflict else 'unrelated.exe'
            return True
        k.Process32FirstW.side_effect = first
        k.Process32NextW.return_value = False
        def memory(pointer):
            pointer._obj.values[1] = 3 * 1024**3; return True
        k.GlobalMemoryStatusEx.side_effect = memory
        calls = [0]
        def times(*pointers):
            calls[0] += 1
            for pointer, value in zip(pointers, [190, 100, 100]):
                pointer._obj.value = value * calls[0]
            return True
        k.GetSystemTimes.side_effect = times
        def desktop(*args):
            self.advance(access_delay)
            return 1 if access else 0
        u.OpenInputDesktop.side_effect = desktop
        u.CloseDesktop.return_value = True
        u.GetLastInputInfo.return_value = True
        u.GetForegroundWindow.return_value = None
        sleep = Mock(side_effect=lambda seconds: self.advance(seconds))
        with patch.object(c, 'WinDLL', side_effect=lambda name, **kw: k if name == 'kernel32' else u, create=True), \
             patch.object(c, 'get_last_error', return_value=18, create=True), \
             patch.object(c, 'WinError', side_effect=lambda value: OSError('access denied'), create=True), \
             patch.object(command.os, 'name', 'nt'), \
             patch.object(command.time, 'sleep', sleep), \
             patch('shutil.disk_usage', return_value=SimpleNamespace(free=2 * 1024**3)):
            if through_wrapper:
                self.sample.side_effect = command.sample_resources
                with self.assertRaisesRegex(RuntimeError, 'sample aged during collection'):
                    self.invoke()
                self.runner.assert_not_called()
                self.sample.assert_called_once()
                early = access_delay or scan_index == 1
                self.assertEqual(snapshots[0], 1 if early else 2)
                self.assertEqual(self.clock[1], 1117 if early else 1118)
            elif conflict or not access or close_failure:
                with self.assertRaises((RuntimeError, OSError)) as caught:
                    command.sample_resources(self.root, run.Budget())
                if conflict and close_failure:
                    self.assertEqual(str(caught.exception), 'Conflicting process observed')
                    self.assertTrue(any('CloseHandle failure' in note for note in caught.exception.__notes__))
                elif close_failure:
                    self.assertIsInstance(caught.exception, OSError)
                sleep.assert_not_called()
            else:
                row = command.sample_resources(self.root, run.Budget())
                self.assertEqual(row['measured_unix'], 1000)
                self.assertEqual(self.clock[1], 1001)
                self.assertTrue(row['input_unchanged'])
                self.assertTrue(row['foreground_stable'])
                self.assertTrue(row['conflicts_absent'])
                sleep.assert_called_once_with(1)
                self.assertEqual(k.CloseHandle.call_count, 2)


if __name__ == '__main__':
    unittest.main()
