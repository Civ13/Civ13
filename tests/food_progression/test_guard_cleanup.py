"""Offline failure-path controls. No native process or filesystem deletion."""
import unittest

from guard_cleanup import finish_owned_run


class GuardCleanupTests(unittest.TestCase):
    def run_cleanup(self, *, terminate=True, inventory=None, unlink=None, child=None,
                    close_ok=True):
        self.seconds = 0
        self.closed = False
        self.receipts = []
        self.removed = []

        def sleep(seconds):
            self.seconds += seconds

        def close():
            self.closed = True
            return close_ok

        return finish_owned_run(
            receipt={}, terminate=lambda: terminate,
            inventory=inventory or (lambda: []), close_job=close, child=child,
            paths=['first', 'second'], unlink=unlink or self.removed.append,
            deadline=5, process_deadline=2, started=0, utc=lambda: 'test-time',
            write_receipt=lambda value: self.receipts.append(value.copy()),
            clock=lambda: self.seconds, sleep=sleep)

    def test_success_confirms_exit_and_cleans_all_known_files(self):
        receipt = self.run_cleanup()
        self.assertTrue(receipt['termination_succeeded'])
        self.assertTrue(receipt['process_cleanup_confirmed'])
        self.assertIsNone(receipt['cleanup_error'])
        self.assertEqual(self.removed, ['first', 'second'])
        self.assertEqual(len(self.receipts), 1)

    def test_inventory_error_does_not_claim_exit_or_skip_receipt(self):
        def inventory():
            raise OSError('injected inventory failure')

        receipt = self.run_cleanup(inventory=inventory)
        self.assertFalse(receipt['process_cleanup_confirmed'])
        self.assertIsNone(receipt['remaining_owned_pids'])
        self.assertIn('inventory failure', receipt['cleanup_error'])
        self.assertTrue(self.closed)
        self.assertEqual(len(self.receipts), 1)

    def test_handle_close_failure_remains_failure(self):
        receipt = self.run_cleanup(close_ok=False)
        self.assertIn('CloseHandle returned failure', receipt['cleanup_error'])
        self.assertEqual(len(self.receipts), 1)

    def test_failed_termination_remains_failure_and_exit_inventory_is_bounded(self):
        receipt = self.run_cleanup(terminate=False, inventory=lambda: [123])
        self.assertFalse(receipt['termination_succeeded'])
        self.assertFalse(receipt['process_cleanup_confirmed'])
        self.assertIn('TerminateJobObject', receipt['cleanup_error'])
        self.assertLessEqual(self.seconds, 2)
        self.assertTrue(self.closed)
        self.assertEqual(len(self.receipts), 1)

    def test_unlink_failure_does_not_skip_other_files_or_final_receipt(self):
        def unlink(path):
            if path == 'first':
                raise PermissionError('injected locked file')
            self.removed.append(path)

        receipt = self.run_cleanup(unlink=unlink)
        self.assertEqual(self.removed, ['second'])
        self.assertEqual(receipt['deferred_generated_files'], ['first'])
        self.assertIn('locked file', receipt['cleanup_error'])
        self.assertEqual(len(self.receipts), 1)

    def test_root_timeout_still_checks_descendants_and_writes_receipt(self):
        class Child:
            def wait(self, timeout):
                raise TimeoutError('injected root wait timeout')

        receipt = self.run_cleanup(child=Child())
        self.assertTrue(receipt['process_cleanup_confirmed'])
        self.assertIn('root wait timeout', receipt['cleanup_error'])
        self.assertTrue(self.closed)
        self.assertEqual(len(self.receipts), 1)

    def test_cleanup_deadline_defers_files_instead_of_extending_lease(self):
        def unlink(path):
            self.removed.append(path)
            self.seconds = 5

        receipt = self.run_cleanup(unlink=unlink)
        self.assertEqual(self.removed, ['first'])
        self.assertEqual(receipt['deferred_generated_files'], ['second'])
        self.assertTrue(receipt['cleanup_deadline_reached'])
        self.assertEqual(len(self.receipts), 1)


if __name__ == '__main__':
    unittest.main()
