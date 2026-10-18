"""Pure mocked Job observations; no process creation or native API calls."""
import ctypes as c
from ctypes import wintypes as w
from types import SimpleNamespace
import unittest
from owned_job import ProcessIds, query_members, validate_members, settle, capture_unexpected
import windows


EMPTY = dict(assigned=0, count=0, pids=[])


class OwnedJobTests(unittest.TestCase):
    def capture_adapter(self, membership=(True, True, True), opened=True):
        calls, belongs = [], list(membership)
        def open_process(rights, inherit, pid):
            calls.append(('open', rights, inherit, pid))
            return 101 if opened else 0
        def is_member(handle, job, pointer):
            calls.append(('membership', handle, job))
            c.cast(pointer, c.POINTER(w.BOOL)).contents.value = belongs.pop(0)
            return True
        def exit_code(handle, pointer):
            c.cast(pointer, c.POINTER(w.DWORD)).contents.value = 259
            return True
        def check(value):
            if not value:
                raise OSError('query failed')
        adapter = SimpleNamespace(job=77, retained=[], check=check,
            identity=lambda process: dict(pid=process.pid, image='owned.exe', creation_filetime=123),
            exited=lambda process: False,
            k=SimpleNamespace(OpenProcess=open_process, IsProcessInJob=is_member,
                              GetExitCodeProcess=exit_code, CloseHandle=lambda handle: calls.append(('close', handle))))
        return adapter, calls

    def test_unexpected_member_capture_is_read_only_exact_job_and_retained(self):
        adapter, calls = self.capture_adapter()
        result = capture_unexpected(adapter, 8)
        self.assertEqual(result['status'], 'verified-owned')
        self.assertTrue(result['retained_for_cleanup'])
        self.assertEqual(calls[0], ('open', 0x101000, False, 8))
        self.assertEqual(calls[1:], [('membership', 101, 77)] * 3)
        self.assertEqual(adapter.retained[0].process, 101)
        self.assertIsNone(adapter.retained[0].thread)

    def test_unavailable_or_raced_identity_never_attributed(self):
        for membership, opened, retained in (((False,), True, False), ((True, False), True, True),
                                              ((True, True, False), True, True), ((), False, False)):
            adapter, calls = self.capture_adapter(membership, opened)
            result = capture_unexpected(adapter, 8)
            self.assertEqual(result['status'], 'unavailable')
            self.assertNotIn('identity', result)
            self.assertEqual(result['retained_for_cleanup'], retained)
            if opened and not retained:
                self.assertIn(('close', 101), calls)

    def test_cleanup_waits_query_only_handle_without_null_thread_close(self):
        adapter = windows.Adapter.__new__(windows.Adapter)
        closed, waited = [], []
        adapter.job = 77
        adapter.retained = [SimpleNamespace(process=101, thread=None, pid=8)]
        def wait(handle, timeout):
            waited.append(handle)
            return 0
        def code(handle, pointer):
            c.cast(pointer, c.POINTER(w.DWORD)).contents.value = 1
            return True
        adapter.k = SimpleNamespace(TerminateJobObject=lambda job, code: True,
            CloseHandle=closed.append, WaitForSingleObject=wait, GetExitCodeProcess=code)
        adapter.identity = lambda process: dict(pid=process.pid, creation_filetime=123, image='owned.exe')
        adapter.times = lambda process: (123, 0)
        result = adapter.cleanup(None, 10)
        self.assertTrue(result['all_exited'])
        self.assertEqual(waited, [101])
        self.assertEqual(closed, [77, 101])

    def exercise(self, values, membership=None, check=None):
        clock, rows = [0.0], []
        def account():
            active = values.pop(0) if len(values) > 1 else values[0]
            return dict(active=active, terminated=0)
        def pause(seconds):
            clock[0] += seconds
        result = settle(account, lambda: EMPTY if membership is None else membership,
                        check or (lambda value: None), rows.append,
                        now=lambda: clock[0], pause=pause)
        return result, rows, clock[0]

    def test_stale_accounting_drains_with_empty_membership(self):
        result, rows, elapsed = self.exercise([1, 1, 0])
        self.assertEqual(result['active'], 0)
        self.assertEqual([row['accounting']['active'] for row in rows], [1, 1, 0])
        self.assertEqual(elapsed, .1)

    def test_persistent_active_or_unknown_pid_rejects(self):
        with self.assertRaisesRegex(RuntimeError, 'did not drain'):
            self.exercise([1])
        with self.assertRaisesRegex(RuntimeError, 'Unexpected owned Job PID'):
            self.exercise([0], dict(assigned=1, count=1, pids=[7]))
        validate_members(dict(assigned=1, count=1, pids=[7]), 7)
        with self.assertRaises(RuntimeError):
            validate_members(dict(assigned=1, count=1, pids=[8]), 7)

    def test_resource_cpu_deadline_limit_or_query_errors_reject(self):
        for message in ('CPU limit', 'wall deadline', 'watcher resource', 'Job limits', 'output bound', 'terminated'):
            def reject(value):
                raise RuntimeError(message)
            with self.assertRaisesRegex(RuntimeError, message):
                self.exercise([1, 0], check=reject)
        with self.assertRaises(OSError):
            settle(lambda: dict(active=0), lambda: (_ for _ in ()).throw(OSError('query failed')),
                   lambda value: None, lambda value: None)

    def test_membership_shape_overflow_and_truncation_reject(self):
        for row in (dict(assigned=33, count=33, pids=list(range(1, 34))),
                    dict(assigned=2, count=1, pids=[7]), dict(assigned=1, count=1, pids=[True]),
                    dict(assigned=2, count=2, pids=[7, 7])):
            with self.assertRaises(RuntimeError):
                validate_members(row, 7)

    def test_query_layout_and_exact_return_length(self):
        self.assertEqual(ProcessIds.pids.offset, 8)
        self.assertEqual(c.sizeof(ProcessIds._fields_[0][1]), 4)
        self.assertEqual(c.sizeof(ProcessIds._fields_[1][1]), 4)
        for assigned, count, length, ok in ((0, 0, 8, True), (1, 1, 8 + c.sizeof(c.c_size_t), True),
                                           (33, 33, c.sizeof(ProcessIds), False),
                                           (2, 1, c.sizeof(ProcessIds), False), (1, 1, 8, False)):
            def query(job, kind, raw, size, returned):
                self.assertEqual(kind, 3)
                value = c.cast(raw, c.POINTER(ProcessIds)).contents
                value.assigned, value.count, value.pids[0] = assigned, count, 7
                c.cast(returned, c.POINTER(c.c_uint32)).contents.value = length
                return True
            adapter = SimpleNamespace(job=1, k=SimpleNamespace(QueryInformationJobObject=query),
                                      check=lambda value: None)
            if ok:
                self.assertEqual(query_members(adapter)['count'], count)
            else:
                with self.assertRaises(RuntimeError):
                    query_members(adapter)


if __name__ == '__main__':
    unittest.main()
