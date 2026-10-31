"""Offline event fixtures only; no Win32 process, debugger or global policy call."""
import copy
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import client_debug as d
import activation

IDENTITY={'pid':10,'creation_filetime':20,'image':r'C:\pkg\dreamseeker.exe'}
BINDING={'controller':'a'*40,'run_id':'123','client_startup_diagnostic':True}


class Clock:
    value=0.
    def __init__(self): self.value=0.
    def __call__(self): return self.value


def image(base=0x400000,name='dreamseeker.exe',origin='package',selected=True,**extra):
    return dict(base=base,name=name,size=0x10000,origin=origin,selected=selected,
                sha256='a'*64,matches_pin=True,**extra)


def event(code,**extra):
    return dict(code=code,pid=10,tid=11,**extra)


class Backend:
    def __init__(self,events,clock):
        self.events=copy.deepcopy(events);self.clock=clock;self.started=clock()
        self.pending=None;self.handle_errors=[];self.acks=[];self.image_reads=0
        self.adopted=0;self.fail_ack=False
    def next(self,milliseconds):
        assert self.pending is None
        if not self.events:
            self.clock.value+=max(.001,milliseconds/1000)
            return None
        self.clock.value+=.001
        self.pending=self.events.pop(0)
        return self.pending
    def ack(self,status):
        if self.fail_ack: raise OSError('never-export-this-text')
        self.acks.append((self.pending['code'],status))
        self.pending=None
    def image(self,ev):
        self.image_reads+=1
        return ev.get('image',{'base':0x400000,'name':None,'size':None})
    def adopt(self,ev,*,cleanup=False): self.adopted+=1


class Modes(unittest.TestCase):
    def test_held_command_and_backend_guard_do_not_query_or_launch(self):
        with patch.object(d,'CLIENT_STARTUP_DIAGNOSTIC_ENABLED',False), \
             patch.object(activation,'require_runtime',side_effect=AssertionError('unexpected runtime')):
            with self.assertRaisesRegex(d.DiagnosticError,'held_client'):
                d.require_command([r'C:\pkg\dreamseeker.exe','byond://127.0.0.1:1234##guest'],'client',True)
    def test_coherent_and_mismatched_states(self):
        for enabled in (False,True):
            with patch.object(d,'CLIENT_STARTUP_DIAGNOSTIC_ENABLED',enabled):
                d.mode(enabled,{'client_startup_diagnostic':enabled})
                for request,admitted in [(not enabled,enabled),(enabled,not enabled),(1,enabled),(enabled,1)]:
                    with self.subTest(values=(enabled,request,admitted)),self.assertRaises(d.DiagnosticError):
                        d.mode(request,{'client_startup_diagnostic':admitted})
    def test_exact_command_only(self):
        good=[r'C:\pkg\dreamseeker.exe','byond://127.0.0.1:1234##guest']
        with patch.object(d,'CLIENT_STARTUP_DIAGNOSTIC_ENABLED',True),patch.object(activation,'require_runtime',return_value=BINDING):
            self.assertEqual(d.require_command(good,'client',True),BINDING)
            for args,phase,visible in [(good,'server',True),(good,'client',False),
                ([good[0],'byond://other:1234##guest'],'client',True),
                ([good[0],'byond://127.0.0.1:99##guest'],'client',True),
                (good+['extra'],'client',True),([r'C:\pkg\dd.exe',good[1]],'client',True)]:
                with self.subTest(args=args),self.assertRaises(d.DiagnosticError):
                    d.require_command(args,phase,visible)
    def test_actual_source_flags_and_json_agree(self):
        a=json.loads(Path(__file__).with_name('activation.json').read_text())
        self.assertIs(d.CLIENT_STARTUP_DIAGNOSTIC_ENABLED,a['client_startup_diagnostic'])
        self.assertFalse(__import__('deferred_recording').NATIVE_RELEASED)


class Events(unittest.TestCase):
    def run_trace(self,events,watch=lambda:None):
        clock=Clock();backend=Backend(events,clock);trace=d.Trace(IDENTITY,BINDING)
        record=d.collect(trace,backend,watch,clock)
        return trace,backend,clock,record
    def test_crash_localization_continues_application_exception_unhandled(self):
        ntdll=image(0x77000000,'ntdll.dll','system',False)
        dll=image(0x65000000,'d3dx9_43.dll')
        seq=[event(3,image=image()),event(6,image=ntdll),
             event(1,exception=0x80000003,address=0x77000010,first=True),
             event(6,image=dll),event(1,exception=0xc0000005,address=0x65000123,first=True),
             event(1,exception=0xc0000005,address=0x65000123,first=False),event(5,exit=0xc0000005)]
        trace,backend,_,record=self.run_trace(seq)
        self.assertEqual(record['exception']['module'],'d3dx9_43.dll')
        self.assertEqual(record['exception']['module_offset'],'0x123')
        self.assertEqual(record['exit_code'],0xc0000005)
        self.assertFalse(record['root_cause_proven'])
        self.assertEqual([status for code,status in backend.acks if code==1],
                         [d.CONTINUE,d.NOT_HANDLED,d.NOT_HANDLED])
    def test_wow64_startup_and_later_breakpoints(self):
        seq=[event(3,image=image()),event(6,image=image(0x77000000,'ntdll.dll','system',False)),
             event(1,exception=0x4000001f,address=0x77000020,first=True),
             event(1,exception=0x80000003,address=0x77000020,first=True),event(5,exit=0)]
        _,backend,_,record=self.run_trace(seq)
        self.assertEqual(record['handled_system_startup_breakpoints'],1)
        self.assertEqual([s for c,s in backend.acks if c==1],[d.CONTINUE,d.NOT_HANDLED])
    def test_application_or_untrusted_breakpoint_is_not_swallowed(self):
        for img in [image(),image(0x400000,'ntdll.dll','other',False)]:
            _,backend,_,_=self.run_trace([event(3,image=img),
                event(1,exception=0x80000003,address=0x400010,first=True),event(5,exit=1)])
            self.assertIn((1,d.NOT_HANDLED),backend.acks)
    def test_foreign_pid_or_missing_creation_never_reads_image(self):
        for seq in [[dict(event(3,image=image()),pid=999)],[event(6,image=image())]]:
            trace,backend,_,record=self.run_trace(seq)
            self.assertTrue(record['errors']);self.assertEqual(backend.image_reads,0)
    def test_null_image_is_unknown_not_a_fitted_module(self):
        _,_,_,record=self.run_trace([event(3),event(1,exception=0xc0000005,address=0x400010,first=False),event(5,exit=1)])
        self.assertIsNone(record['exception']['module']);self.assertEqual(record['unknown_images'],1)
    def test_unloaded_or_ambiguous_images_are_not_fitted(self):
        for middle in [[event(7,base=0x400000)],[event(6,image=image(0x400001,'other.dll','system',False))]]:
            _,_,_,record=self.run_trace([event(3,image=image())]+middle+
                [event(1,exception=0xc0000005,address=0x400010,first=False),event(5,exit=1)])
            self.assertIsNone(record['exception']['module'])
    def test_pin_mismatch_keeps_selected_failure_and_pending_event(self):
        bad=image();bad['matches_pin']=False
        _,backend,_,record=self.run_trace([event(3,image=bad)])
        self.assertIn('diagnostic_selected_pin_mismatch',record['errors'])
        self.assertFalse(record['selected_modules'][0]['matches_pin'])
        self.assertIsNotNone(backend.pending)
    def test_image_cap_precedes_file_inspection(self):
        seq=[event(3,image=image())]+[event(6,image=image(0x10000000+i*0x10000,'m%d.dll'%i,'system',False)) for i in range(128)]
        _,backend,_,record=self.run_trace(seq)
        self.assertEqual(record['images_seen'],128);self.assertEqual(backend.image_reads,128)
        self.assertIn('diagnostic_image_cap',record['errors'])
    def test_event_reserve_and_termination_drain_are_bounded(self):
        trace,backend,clock,record=self.run_trace([event(3,image=image())]+[event(2) for _ in range(240)])
        self.assertEqual(record['events'],240)
        # Remaining creation event and exit are cleanup-only; no image reads.
        backend.events.append(event(5,exit=1))
        self.assertTrue(d.drain(trace,backend,clock()+1,clock))
        self.assertLessEqual(trace.events,256);self.assertEqual(backend.image_reads,1)
    def test_cleanup_overflow_retains_unknown_exit(self):
        trace,backend,clock,_=self.run_trace([event(3,image=image())]+[event(2) for _ in range(256)])
        backend.events.append(event(5,exit=1))
        self.assertFalse(d.drain(trace,backend,clock()+1,clock))
        self.assertEqual(trace.events,256);self.assertFalse(trace.exit_seen)
    def test_five_second_stop_then_cleanup_exit_is_not_natural_exit(self):
        trace,backend,clock,record=self.run_trace([event(3,image=image())])
        self.assertEqual(record['outcome'],'five_second_limit')
        backend.events.append(event(5,exit=1))
        self.assertTrue(d.drain(trace,backend,clock()+1,clock))
        self.assertTrue(trace.snapshot()['exit_during_cleanup'])
    def test_watch_overrun_precedes_another_event_read(self):
        clock=Clock();backend=Backend([event(3,image=image())],clock);trace=d.Trace(IDENTITY,BINDING)
        def overrun():clock.value=6
        record=d.collect(trace,backend,overrun,clock)
        self.assertIn('diagnostic_five_second_overrun',record['errors'])
        self.assertEqual(backend.image_reads,0);self.assertIsNone(backend.pending)
    def test_ack_failure_and_file_handle_failure_are_not_clean(self):
        trace,backend,clock,_=self.run_trace([event(3,image=image()),event(5,exit=0)])
        backend.handle_errors.append('close_failed')
        self.assertFalse(d.drain(trace,backend,clock()+1,clock))
        backend=Backend([event(3,image=image())],Clock());backend.fail_ack=True
        trace=d.Trace(IDENTITY,BINDING)
        record=d.collect(trace,backend,lambda:None,backend.clock)
        self.assertEqual(record['errors'],['api_error'])
        self.assertNotIn('never-export',json.dumps(record))
    def test_byte_cap_is_failure_with_original_hash(self):
        trace=d.Trace(IDENTITY,{'huge':'x'*70000})
        record=trace.snapshot()
        self.assertEqual(record['status'],'FAILED_DIAGNOSTIC_BYTE_CAP')
        self.assertLess(len(json.dumps(record)),65536)
        self.assertEqual(len(record['original_sha256']),64)


if __name__=='__main__':unittest.main()
