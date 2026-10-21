"""Adapter-only tests: no WinDLL binding, subprocess, compiler or server."""
from pathlib import Path
import tempfile
import unittest

from guard import CAP, FLOOR, WATCHER_RESERVE, Command, GuardFailure, confined, run


class Fake:
    def __init__(self, fault=None):
        self.fault = fault
        self.clock = 0
        self.calls = []
        self.running = []
        self.notifications = []
        self.codes = {}
        self.assigned = set()
        self.resumed = False
        self.next_pid = 10
        self.closed = []
        self.checked = []
        self.total_assigned = 0

    def now(self): return self.clock
    def free_memory(self): return FLOOR - 1 if self.resumed and self.fault == 'floor' else FLOOR
    def watcher_private(self): return WATCHER_RESERVE + 1 if self.resumed and self.fault == 'watcher' else 100
    def new_job(self, cap):
        self.calls.append(('job', cap))
        return 'job'
    def new_process(self, argv, cwd, env):
        assert not self.running, 'Overlapping command roots'
        pid = self.next_pid
        self.next_pid += 2
        self.calls.append(('create-suspended', pid))
        self.running.append(pid)
        return pid, 'thread-'+str(pid), pid
    def assign(self, job, handle):
        self.calls.append(('assign', handle))
        if self.fault == 'assignment': raise GuardFailure('assignment rejected')
        self.assigned.add(handle)
        self.total_assigned += 1
        self.notifications.append(('new', handle))
    def in_job(self, job, handle):
        self.calls.append(('membership', handle))
        return handle in self.assigned and not (handle % 2 and self.fault == 'ownership')
    def resume(self, thread):
        self.calls.append(('resume', thread))
        self.resumed = True
        child = self.running[0]+1
        self.running.append(child)
        self.assigned.add(child)
        self.total_assigned += 1
        self.notifications.append(('new', child))
    def events(self, job):
        rows, self.notifications = self.notifications, []
        return rows
    def active_pids(self, job): return list(self.running)
    def assigned_count(self, job):
        return self.total_assigned + (1 if self.fault == 'missing-child' and self.resumed else 0)
    def open_owned(self, job, pid):
        self.calls.append(('retain', pid))
        return pid
    def private(self, handle):
        if self.fault == 'unknown' and self.resumed: return None
        if self.fault in ('cap','cap-terminate') and self.resumed: return CAP
        return 100
    def pause(self, seconds):
        self.clock += 871 if self.fault == 'deadline' else seconds
        if self.fault in ('deadline', 'cleanup'): return
        for pid in self.running:
            self.codes[pid] = 9 if self.fault == 'child-exit' and pid % 2 else 0
            self.notifications.append(('exit', pid))
        self.running.clear()
    def exit_code(self, handle):
        self.checked.append(handle)
        if handle not in self.codes: raise GuardFailure('active/unknown exit')
        return self.codes[handle]
    def terminate(self, job):
        self.calls.append(('terminate-job', job))
        if self.fault in ('terminate','cap-terminate'): raise GuardFailure('termination failed')
        if self.fault == 'cleanup': return
        for pid in self.running: self.codes[pid] = 125
        self.running.clear()
    def stop_unassigned(self, handle):
        self.calls.append(('stop-fresh-suspended', handle))
        self.codes[handle] = 125
        self.running.remove(handle)
    def wait(self, handle, seconds):
        if handle not in self.codes:
            self.clock += seconds
            return False
        return True
    def close(self, handle): self.closed.append(handle)
    def close_job(self, job):
        self.calls.append(('close-job-kill',job))
        for pid in self.running: self.codes[pid]=125
        self.running.clear()
        self.closed.extend([job, 'port'])


class Tests(unittest.TestCase):
    def invoke(self, fake, count=1):
        with tempfile.TemporaryDirectory() as parent:
            command = Command((str(Path(parent)/'trusted-sdk.exe'), 'build'))
            def stage(root): (root/'source').mkdir()
            root, result = run(fake, parent, [command]*count, {'PATH':'trusted'}, b'caller-frozen-proof', stage)
            self.assertTrue((root/'guard-result.json').is_file())
            return result

    def test_assignment_membership_before_resume_serialized_and_children_checked(self):
        fake = Fake()
        result = self.invoke(fake, 2)
        self.assertTrue(result['success'], result)
        self.assertEqual(fake.calls[0], ('job', CAP-WATCHER_RESERVE))
        for pid in (10, 12):
            assignment = fake.calls.index(('assign', pid))
            membership = fake.calls.index(('membership', pid))
            resume = fake.calls.index(('resume', 'thread-'+str(pid)))
            self.assertLess(assignment, membership)
            self.assertLess(membership, resume)
        self.assertTrue({10,11,12,13}.issubset(fake.checked))
        self.assertEqual(set(fake.closed), {10,11,12,13,'thread-10','thread-12','job','port'})

    def test_assignment_failure_never_resumes_and_closes_fresh_handles(self):
        fake = Fake('assignment')
        result = self.invoke(fake)
        self.assertFalse(result['success'])
        self.assertFalse(fake.resumed)
        self.assertIn(('stop-fresh-suspended',10), fake.calls)
        self.assertIn(10, fake.checked)
        self.assertEqual(set(fake.closed), {10,'thread-10','job','port'})

    def test_fail_closed_memory_deadline_floor_unknown_child_and_ownership(self):
        for fault in ('cap','floor','watcher','unknown','deadline','ownership','child-exit','missing-child'):
            with self.subTest(fault=fault):
                fake = Fake(fault)
                result = self.invoke(fake, 2)
                self.assertFalse(result['success'], result)
                self.assertIn(('terminate-job','job'), fake.calls)
                self.assertEqual(sum(row[0]=='create-suspended' for row in fake.calls),1)
                self.assertIn('job',fake.closed)
                self.assertTrue({10,11}.issubset(fake.checked))

    def test_cleanup_failure_not_success_and_all_handles_closed(self):
        fake = Fake('cleanup')
        result = self.invoke(fake)
        self.assertFalse(result['success'])
        self.assertTrue(result['cleanup_errors'])
        self.assertLessEqual(result['elapsed'],900)
        self.assertEqual(set(fake.closed),{10,11,'thread-10','job','port'})

    def test_termination_failure_still_checks_exits_and_closes(self):
        fake = Fake('cap-terminate')
        result = self.invoke(fake)
        self.assertFalse(result['success'])
        self.assertTrue({10,11}.issubset(fake.checked))
        self.assertIn('job',fake.closed)
        self.assertEqual(result['elapsed'],0)
        self.assertEqual({row['exit_code'] for row in result['owned_exits']},{125})

    def test_path_escape(self):
        with tempfile.TemporaryDirectory() as root:
            for path in ('../other',str(Path(root).absolute())):
                with self.assertRaises(GuardFailure): confined(root,path)

if __name__ == '__main__': unittest.main()
