"""ctypes fixtures + fake kernel only. The real Adapter constructor is never run."""
import ctypes as c
from ctypes import wintypes as w
import hashlib
import struct
import threading
import unittest
from pathlib import Path
from unittest.mock import patch
from types import SimpleNamespace

import client_debug as d
import client_debug_windows as n
from windows import Adapter, ProcessInfo
from test_client_debug import Clock, IDENTITY, BINDING


def pe():
    raw=bytearray(256);raw[:2]=b'MZ'
    struct.pack_into('<I',raw,60,128);raw[128:132]=b'PE\0\0'
    struct.pack_into('<H',raw,152,0x10b);struct.pack_into('<I',raw,208,4096)
    return bytes(raw)


def raw_event(code,tid=11):
    value=n.DebugEvent();value.code=code;value.pid=10;value.tid=tid
    if code==3:
        value.data.create.file=9;value.data.create.process=1;value.data.create.thread=2
        value.data.create.base=0x400000
    elif code==5:value.data.exit=1
    return value


class Kernel:
    def __init__(self,clock,events):
        self.clock=clock;self.events=list(events);self.raw=None;self.waits=0
        self.closed=[];self.auto_closed=[];self.duplicates=[];self.continued=[]
        self.current=False;self.exited=False;self.exit_code=1;self.fail_close=None
        self.files={9:dict(path=r'C:\pkg\dreamseeker.exe',data=pe(),pos=0)}
        self.debug_handles=(1,2);self.thread_handles={}
    def WaitForDebugEvent(self,pointer,milliseconds):
        self.waits+=1;self.clock.value+=.001
        if not self.events:
            self.clock.value+=milliseconds/1000;c.set_last_error(121);return 0
        self.raw=self.events.pop(0)
        if self.raw.code==3:self.debug_handles=(self.raw.data.create.process,self.raw.data.create.thread)
        if self.raw.code==2:self.thread_handles[self.raw.tid]=self.raw.data.thread.thread
        c.memmove(pointer,c.byref(self.raw),c.sizeof(self.raw));return 1
    def ContinueDebugEvent(self,pid,tid,status):
        self.continued.append((self.raw.code,status))
        if self.raw.code==5:
            self.exited=True;self.exit_code=int(self.raw.data.exit);self.auto_closed.extend(self.debug_handles)
        if self.raw.code==4:self.auto_closed.append(self.thread_handles.pop(tid))
        return 1
    def GetCurrentProcess(self):return 999
    def GetProcessId(self,handle):return 10
    def GetThreadId(self,handle):return 11
    def DuplicateHandle(self,current,source,target,pointer,*rest):
        value=source+100;self.duplicates.append((source,value))
        c.cast(pointer,c.POINTER(w.HANDLE))[0]=w.HANDLE(value);return 1
    def GetFinalPathNameByHandleW(self,handle,buffer,count,flags):
        buffer.value=self.files[handle]['path'];return len(buffer.value)
    def GetFileSizeEx(self,handle,pointer):
        c.cast(pointer,c.POINTER(c.c_longlong))[0]=len(self.files[handle]['data']);return 1
    def SetFilePointerEx(self,handle,offset,pointer,method):
        self.files[handle]['pos']=0;return 1
    def ReadFile(self,handle,buffer,count,pointer,overlap):
        row=self.files[handle];data=row['data'][row['pos']:row['pos']+count];row['pos']+=len(data)
        c.memmove(buffer,data,len(data));c.cast(pointer,c.POINTER(w.DWORD))[0]=len(data);return 1
    def CloseHandle(self,handle):
        self.closed.append(handle);return 0 if handle==self.fail_close else 1
    def TerminateJobObject(self,job,code):
        if not self.exited and not any(ev.code==5 for ev in self.events):
            self.events.append(raw_event(5))
        return 1
    def WaitForSingleObject(self,handle,milliseconds):return 0 if self.exited else 258
    def GetExitCodeProcess(self,handle,pointer):
        c.cast(pointer,c.POINTER(w.DWORD))[0]=self.exit_code;return 1
    def GetProcessTimes(self,handle,*pointers):
        for index,pointer in enumerate(pointers):
            c.cast(pointer,c.POINTER(c.c_ulonglong))[0]=20 if index==0 else 0
        return 1


def fixture(events):
    clock=Clock();kernel=Kernel(clock,events)
    adapter=Adapter.__new__(Adapter)  # No WinDLL, global API or native process.
    process=ProcessInfo();process.process=1;process.thread=2;process.pid=10;process.tid=11
    process._identity=(1,2,10,20,r'C:\pkg\dreamseeker.exe')
    process._debug_only_this_process=True;process._debug_creator_thread=threading.get_ident()
    process._debug_started=0.
    adapter.k=kernel;adapter.job=3;adapter.retained=[process];adapter.now=clock
    native=n.Native(adapter,process,r'C:\pkg',api=kernel,clock=clock,
                    pins={'dreamseeker.exe':hashlib.sha256(pe()).hexdigest()})
    trace=d.Trace(IDENTITY,BINDING);process._debug_backend=native;process._debug_trace=trace
    return clock,kernel,adapter,process,native,trace


class NativeFixtures(unittest.TestCase):
    def test_documented_x64_debug_event_layout(self):
        self.assertEqual(c.sizeof(n.ExceptionRecord),152)
        self.assertEqual(c.sizeof(n.DebugEvent),176)
        self.assertEqual(n.DebugEvent.data.offset,16)
        self.assertEqual(n.image_size(pe()),4096)
    def test_file_metadata_and_alias_handles_are_separate_from_retained_handles(self):
        clock,kernel,adapter,process,native,trace=fixture([raw_event(3),raw_event(5)])
        record=d.collect(trace,native,lambda:None,clock)
        self.assertFalse(record['errors']);self.assertTrue(record['selected_modules'][0]['matches_pin'])
        self.assertEqual((process.process,process.thread),(101,102))
        self.assertEqual(kernel.closed,[9])
        self.assertEqual(kernel.auto_closed,[1,2])
        result=adapter.cleanup(process,1)
        self.assertTrue(result['all_exited']);self.assertTrue(result['exits'][0]['debug_events_drained'])
        self.assertEqual(kernel.closed.count(101),1);self.assertEqual(kernel.closed.count(102),1)
        self.assertNotIn(1,kernel.closed);self.assertNotIn(2,kernel.closed)
    def test_thread_event_handles_are_auto_closed_without_context_reads(self):
        create=raw_event(2,12);create.data.thread.thread=77
        clock,kernel,adapter,process,native,trace=fixture([raw_event(3),create,raw_event(4,12),raw_event(5)])
        d.collect(trace,native,lambda:None,clock)
        self.assertIn(77,kernel.auto_closed);self.assertNotIn(77,kernel.closed)
        self.assertTrue(adapter.cleanup(process,1)['all_exited'])
    def test_timeout_terminates_then_drains_exit_before_retained_wait(self):
        clock,kernel,adapter,process,native,trace=fixture([raw_event(3)])
        record=d.collect(trace,native,lambda:None,clock)
        self.assertEqual(record['outcome'],'five_second_limit');self.assertFalse(kernel.exited)
        result=adapter.cleanup(process,1)
        self.assertTrue(kernel.exited);self.assertTrue(result['all_exited'])
        self.assertTrue(trace.exit_during_cleanup)
    def test_deadline_before_first_event_still_protects_aliases_during_cleanup(self):
        clock,kernel,adapter,process,native,trace=fixture([raw_event(3)])
        clock.value=6
        d.collect(trace,native,lambda:None,clock)
        self.assertFalse(trace.created);self.assertFalse(native.adopted)
        result=adapter.cleanup(process,1)
        self.assertTrue(native.adopted);self.assertTrue(result['all_exited'])
        self.assertNotIn(1,kernel.closed);self.assertNotIn(2,kernel.closed)
    def test_image_close_failure_is_not_verified_cleanup(self):
        clock,kernel,adapter,process,native,trace=fixture([raw_event(3),raw_event(5)])
        kernel.fail_close=9
        d.collect(trace,native,lambda:None,clock)
        result=adapter.cleanup(process,1)
        self.assertFalse(result['all_exited'])
        self.assertEqual(kernel.closed.count(9),1)
        self.assertIn('diagnostic_event_handle_cleanup',trace.errors)
    def test_creator_thread_change_is_rejected_before_wait(self):
        clock,kernel,_,process,native,_=fixture([raw_event(3)])
        process._debug_creator_thread=-1
        with self.assertRaisesRegex(d.DiagnosticError,'diagnostic_creator_thread'):native.next(1)
        self.assertEqual(kernel.waits,0)
    def test_bad_module_path_pin_and_header_fail_closed_but_cleanup_closes_file(self):
        for key,value in [('path',r'\\remote\bad.dll'),('data',b'not a PE'),('path',r'C:\Windows\dreamseeker.exe')]:
            with self.subTest(case=(key,str(value)[:20])):
                clock,kernel,adapter,process,native,trace=fixture([raw_event(3)])
                kernel.files[9][key]=value
                result=d.collect(trace,native,lambda:None,clock)
                self.assertTrue(result['errors']);self.assertIsNotNone(native.pending)
                self.assertTrue(adapter.cleanup(process,1)['all_exited'])
                self.assertEqual(kernel.closed.count(9),1)
    def test_diagnostic_native_constructor_is_held_without_runtime_query(self):
        with patch.object(d,'CLIENT_STARTUP_DIAGNOSTIC_ENABLED',False), \
             patch.object(activation_module(),'require_runtime',side_effect=AssertionError('unexpected runtime')):
            with self.assertRaisesRegex(d.DiagnosticError,'held_client'):
                n.Native(SimpleNamespace(now=lambda:0),None,Path('C:/pkg'),pins={})


def activation_module():
    import activation
    return activation


if __name__=='__main__':unittest.main()
