"""Pure executor guards: no Windows adapter, processes or native launches."""
import copy
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('reserved_runner', Path(__file__).with_name('run-contained.py'))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class ExecutorGuards(unittest.TestCase):
    def test_extra_members_persist_then_capture_retain_then_reject(self):
        for child in (10, None):
            with self.subTest(child=child):
                adapter = SimpleNamespace(retained=[])
                record = {'membership': {'pids': [10, 20]}}
                snapshots, events = [], []

                def persist():
                    snapshots.append(copy.deepcopy(record))
                    events.append('persist')

                def capture(actual, pid):
                    self.assertIs(actual, adapter)
                    self.assertEqual(snapshots[-1]['unexpected_members'][-1]['status'], 'capture-pending')
                    self.assertEqual(snapshots[0]['membership']['pids'], [10, 20])
                    actual.retained.append(pid)
                    events.append(('capture', pid))
                    return {'pid': pid, 'status': 'verified-owned', 'retained_for_cleanup': True}

                def reject(membership, allowed):
                    self.assertEqual(allowed, child)
                    self.assertEqual(events[-1], 'persist')
                    self.assertTrue(all(row['retained_for_cleanup'] for row in snapshots[-1]['unexpected_members']))
                    events.append('reject')
                    raise RuntimeError('Unexpected owned Job PID')

                with self.assertRaisesRegex(RuntimeError, 'Unexpected owned Job PID'):
                    runner.preserve_membership(record, adapter, child, persist, capture, reject)
                self.assertEqual(adapter.retained, [20] if child == 10 else [10, 20])
                self.assertEqual(events[-1], 'reject')

    def test_expected_member_and_empty_terminal_do_not_capture(self):
        for pids, child in (([10], 10), ([], None)):
            persisted = []
            runner.preserve_membership({'membership': {'pids': pids}}, None, child,
                                       lambda: persisted.append(True),
                                       lambda *_: self.fail('Unexpected capture'), lambda *_: None)
            self.assertEqual(persisted, [True])

    def test_compiled_artifacts_rejected_using_stat_before_content_access(self):
        with tempfile.TemporaryDirectory() as directory:
            dme = Path(directory)/'probe.dme'
            runner.enforce_artifact_bounds(dme, 16)
            for suffix in ('.dmb', '.rsc'):
                artifact = dme.with_suffix(suffix)
                artifact.write_bytes(b'x' * 16)
                runner.enforce_artifact_bounds(dme, 16)
                artifact.write_bytes(b'x' * 17)
                with self.assertRaisesRegex(RuntimeError, 'Compiled resource/artifact bound'):
                    runner.enforce_artifact_bounds(dme, 16)
                artifact.unlink()


if __name__ == '__main__':
    unittest.main()
