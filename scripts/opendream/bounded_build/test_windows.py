"""Production Windows methods exercised through injected fake DLL functions.

No WinDLL construction or OS call happens, including when run on Windows.
"""
import ctypes as C
import unittest
from unittest.mock import patch
from windows import Windows, Limits, Process, Counters, Memory, Accounting
from guard import GuardFailure


class Function:
    def __init__(self, callback): self.callback = callback
    def __call__(self,*args): return self.callback(*args)


class Library:
    def __init__(self, native): self.native = native
    def __getattr__(self,name):
        value = Function(lambda *args: self.native.call(name,args))
        setattr(self,name,value)
        return value


class Native:
    def __init__(self, fault=None):
        self.fault = fault
        self.calls = []
        self.member = False
        self.closed = []
        self.job_flags = None
        self.creation_flags = None
        self.memory_cap = None

    def call(self,name,args):
        self.calls.append(name)
        if self.fault == name: return 0
        if name == 'CreateJobObjectW': return 100
        if name == 'CreateIoCompletionPort': return 200
        if name == 'SetInformationJobObject':
            if args[1] == 9:
                value = C.cast(args[2],C.POINTER(Limits)).contents
                self.job_flags = value.basic.flags
                self.memory_cap = value.job_memory
            return 1
        if name == 'CreateProcessW':
            self.creation_flags = args[5]
            assert args[4] is False, 'No inherited handles'
            value = C.cast(args[-1],C.POINTER(Process)).contents
            value.process,value.thread,value.pid,value.tid = 300,400,500,600
            return 1
        if name == 'AssignProcessToJobObject': self.member = True; return 1
        if name == 'IsProcessInJob':
            C.cast(args[2],C.POINTER(C.c_long)).contents.value = int(self.member)
            return 1
        if name == 'ResumeThread': return 1
        if name == 'GetCurrentProcess': return 700
        if name == 'GetProcessMemoryInfo':
            C.cast(args[1],C.POINTER(Counters)).contents.private = 42
            return 1
        if name == 'GlobalMemoryStatusEx':
            C.cast(args[0],C.POINTER(Memory)).contents.available = 123
            return 1
        if name == 'QueryInformationJobObject':
            C.cast(args[2],C.POINTER(Accounting)).contents.total_processes = 2
            return 1
        if name == 'WaitForSingleObject': return 0
        if name == 'GetExitCodeProcess':
            C.cast(args[1],C.POINTER(C.c_ulong)).contents.value = 0
            return 1
        if name == 'CloseHandle': self.closed.append(args[0]); return 1
        raise AssertionError('Unexpected fake API: '+name)


class Tests(unittest.TestCase):
    def setUp(self):
        # The injected DLL failure path must not consult native Windows TLS.
        self.error = patch.object(C, "get_last_error", return_value=5, create=True)
        self.error.start()
        self.addCleanup(self.error.stop)

    def adapter(self,native):
        # Tripwire proves even DLL construction is forbidden during these tests.
        with patch.object(C,'WinDLL',side_effect=AssertionError('Native binding forbidden'),create=True):
            return Windows(kernel=Library(native),psapi=Library(native))

    def test_real_methods_job_port_create_assignment_membership_resume(self):
        native = Native()
        adapter = self.adapter(native)
        job = adapter.new_job(1000)
        process,thread,pid = adapter.new_process(('C:/trusted/sdk.exe','build'),'C:/owned/source',{'PATH':'trusted'})
        adapter.assign(job,process)
        self.assertTrue(adapter.in_job(job,process))
        adapter.resume(thread)
        self.assertEqual(native.job_flags,0x2200)
        self.assertEqual(native.memory_cap,1000)
        self.assertEqual(native.creation_flags,0x08000404)
        self.assertFalse(native.creation_flags & 0x01000000)  # CREATE_BREAKAWAY_FROM_JOB
        self.assertFalse(native.job_flags & (0x800|0x1000))  # both Job breakaway flags
        self.assertLess(native.calls.index('CreateIoCompletionPort'),native.calls.index('AssignProcessToJobObject'))
        self.assertLess(native.calls.index('AssignProcessToJobObject'),native.calls.index('IsProcessInJob'))
        self.assertLess(native.calls.index('IsProcessInJob'),native.calls.index('ResumeThread'))
        self.assertEqual(adapter.assigned_count(job),2)
        self.assertEqual(adapter.watcher_private(),42)
        self.assertEqual(adapter.free_memory(),123)
        self.assertEqual(adapter.exit_code(process),0)
        adapter.close(thread)
        adapter.close(process)
        adapter.close_job(job)
        self.assertEqual(native.closed,[400,300,100,200])

    def test_real_assignment_failure_does_not_resume(self):
        native = Native('AssignProcessToJobObject')
        adapter = self.adapter(native)
        adapter.new_job(1000)
        process,thread,_ = adapter.new_process(('C:/trusted/sdk.exe',),'C:/owned',{'PATH':'trusted'})
        with self.assertRaises(OSError): adapter.assign(100,process)
        self.assertNotIn('ResumeThread',native.calls)

    def test_real_native_measure_wait_close_failures_propagate(self):
        for api, action in (
            ('GetProcessMemoryInfo',lambda adapter:adapter.private(300)),
            ('GlobalMemoryStatusEx',lambda adapter:adapter.free_memory()),
            ('CloseHandle',lambda adapter:adapter.close(300)),
        ):
            with self.subTest(api=api):
                adapter=self.adapter(Native(api))
                with self.assertRaises(OSError): action(adapter)
        native=Native()
        adapter=self.adapter(native)
        adapter.k.WaitForSingleObject = Function(lambda *args:0xffffffff)
        with self.assertRaises(OSError): adapter.wait(300,1)
        with self.assertRaises(GuardFailure): adapter.exit_code(300)

    def test_real_job_configuration_failure_closes_created_job(self):
        native=Native('SetInformationJobObject')
        adapter=self.adapter(native)
        with self.assertRaises(OSError): adapter.new_job(1000)
        self.assertEqual(native.closed,[100])


if __name__=='__main__': unittest.main()
