"""Offline executor tests. Every child/Win32 dependency is injected; no BYOND."""
import ctypes as C
import json
from pathlib import Path
import tempfile
import threading
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import executor as ex
import prepare
import windows_job as win


BATCHES = ''.join(f'CHECK wolf cave batch count={n} full={f}\n' for n in (1, 3, 10) for f in (0, 1))
COMPILE = 'DM compiler version 516.1681\nprobe.dmb - 0 errors, 0 warnings\n'


class Clock:
    def __init__(self): self.value = 0
    def now(self): return self.value
    def pause(self, seconds): self.value += seconds


class FakeWatchdog:
    def __init__(self, adapter, child, seconds): self.fired = False; self.errors = []
    def start(self): pass
    def stop(self): pass


class FakeBackend:
    """Records fake-process actions; never calls any OS launch function."""
    def __init__(self, fault=None): self.fault = fault; self.actions = []; self.active = False; self.children = 0
    def resources(self):
        return dict(available_bytes=0 if self.fault == 'resources' else 2**31,
                    commit_available_bytes=2**31, allowed_cpus=2, system_cpu_times=[1, 2, 3])
    def start_suspended(self, argv, cwd, logs):
        if self.active: raise AssertionError('Concurrent child')
        self.active = True; self.children += 1; self.actions.append('create'); self.polls = 0
        child = SimpleNamespace(identity={'pid': 1000+self.children}, argv=argv)
        (logs / 'stderr.log').write_text('')
        if Path(argv[0]).name == 'dm.exe':
            (logs / 'stdout.log').write_text(COMPILE if self.fault != 'compiler' else 'fatal error: simulated\n')
            (cwd / 'probe.dmb').write_bytes(b'fake-compiled-artifact')
        else:
            (logs / 'stdout.log').write_text('')
            case = cwd.parent.parent.name
            result = BATCHES + ('PASS wolf cave ownership\n' if ex.EXPECTED[case] is None else
                f'FAIL wolf cave: {ex.EXPECTED[case]}\nFAIL wolf cave ownership\n')
            (cwd / 'runtime.log').write_text(result)
        return child
    def resume(self, child):
        self.actions.append('resume')
        if self.fault == 'resume': raise RuntimeError('resume fault')
    def exited(self, child):
        self.polls += 1
        return self.fault != 'timeout' and self.polls > 2
    def sample(self, child):
        if self.fault == 'sample': raise RuntimeError('sample fault')
        return dict(private_bytes=ex.POLICY['child_bytes']+1 if self.fault == 'memory' else 1024,
                    active=1, pids=[child.identity['pid']], cpu_seconds=.01)
    def sockets(self, child): return [{'listener': True}] if self.fault == 'socket' else []
    def exit_code(self, child): return 0
    def cleanup(self, child):
        self.actions.append('cleanup'); self.active = False
        return dict(all_exited=self.fault != 'cleanup', errors=[])
    def terminate(self, child): self.actions.append('terminate')
    def watchdog_handle(self, child): self.actions.append('duplicate-watchdog'); return 987
    def watchdog_terminate(self, handle): self.actions.append(('watchdog-terminate', handle))
    def watchdog_close(self, handle): self.actions.append(('watchdog-close', handle))


class ExecutorTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.tripwire = patch.object(C, 'WinDLL', side_effect=AssertionError('Native binding forbidden'), create=True)
        self.tripwire.start(); self.addCleanup(self.tripwire.stop)

    def packet(self):
        prepared = self.root / 'prepared'; prepare.prepare(prepared)
        tools = self.root / 'bin'; tools.mkdir()
        for name in ('dm.exe', 'dd.exe', 'byondcore.dll'): (tools / name).write_bytes(name.encode())
        pin = patch.object(ex, 'PINNED', {p.name: ex.digest(p) for p in tools.iterdir()})
        pin.start(); self.addCleanup(pin.stop)
        result = ex.freeze(prepared, tools, self.root / 'frozen')
        return Path(result['packet']), result['packet_sha256']

    def test_freeze_validates_all_seven_cases_and_each_mutation_is_rejected(self):
        path, sha = self.packet()
        packet = ex.verify_packet(path, sha)
        self.assertEqual(len(packet['files']), 28)
        for target in (Path(packet['sources']) / 'fixed/probe.dm',
                       Path(packet['bin']) / 'byondcore.dll', path):
            before = target.read_bytes(); target.write_bytes(before+b'changed')
            with self.subTest(target=target), self.assertRaises(RuntimeError): ex.verify_packet(path, sha)
            target.write_bytes(before)
        (Path(packet['bin']) / 'extra.dll').write_bytes(b'injected')
        with self.assertRaisesRegex(RuntimeError, 'DLL set changed'): ex.verify_packet(path, sha)

    def test_freeze_rejects_wrong_tools_and_changed_prepared_bytes(self):
        prepared = self.root / 'prepared'; prepare.prepare(prepared)
        tools = self.root / 'bin'; tools.mkdir()
        with self.assertRaisesRegex(RuntimeError, 'tools differ'): ex.freeze(prepared, tools, self.root / 'wrong')
        for name in ex.PINNED: (tools / name).write_bytes(name.encode())
        with patch.object(ex, 'PINNED', {p.name: ex.digest(p) for p in tools.iterdir()}):
            (prepared / 'fixed/production.dm').write_text('mutated')
            with self.assertRaisesRegex(RuntimeError, 'fixture changed'): ex.freeze(prepared, tools, self.root / 'changed')

    def test_policy_or_oracles_changed_even_with_new_packet_digest_are_rejected(self):
        path, _ = self.packet(); original = path.read_bytes()
        for key in ('policy', 'expected', 'cases'):
            packet = json.loads(original)
            packet[key] = {} if key != 'cases' else ['fixed']
            path.write_text(json.dumps(packet))
            with self.subTest(key=key), self.assertRaises(RuntimeError): ex.verify_packet(path, ex.digest(path))
        path.write_bytes(original)

    def test_fourteen_simulated_phases_are_sequential_fresh_and_cleanup_is_recorded(self):
        path, sha = self.packet(); adapter, clock = FakeBackend(), Clock()
        result = ex.run_packet(path, sha, path.parent / 'execution', adapter,
                               now=clock.now, pause=clock.pause, watchdog_factory=FakeWatchdog)
        self.assertEqual(result['result'], 'passed'); self.assertEqual(adapter.children, 14)
        self.assertEqual(adapter.actions, ['create', 'resume', 'cleanup']*14)
        self.assertFalse(adapter.active)
        for row in result['cases']:
            self.assertEqual(row['result'], 'passed')
            self.assertTrue(all(p['cleanup']['all_exited'] for p in row['phases']))
            runtime = row['phases'][1]['argv']
            self.assertEqual(runtime[1:], ['probe.dmb', '-close', '-invisible', '-trusted', '-log', 'runtime.log'])
            self.assertNotIn('-safe', runtime)
        with self.assertRaises(FileExistsError): ex.run_packet(path, sha, path.parent/'execution', adapter)
        with self.assertRaisesRegex(RuntimeError, 'packet-local'): ex.run_packet(path, sha, self.root/'other', adapter)

    def test_phase_failures_keep_receipts_and_clean_created_child_once(self):
        for fault in ('resources', 'resume', 'sample', 'memory', 'socket', 'timeout', 'cleanup'):
            with self.subTest(fault=fault):
                work = self.root/fault; work.mkdir(); receipt = {}; clock = Clock(); adapter = FakeBackend(fault)
                with self.assertRaises(RuntimeError):
                    ex.phase(adapter, ['dm.exe'], work, receipt, lambda: None, .11,
                             now=clock.now, pause=clock.pause, watchdog_factory=FakeWatchdog)
                self.assertEqual(adapter.actions.count('cleanup'), 0 if fault == 'resources' else 1)
                self.assertFalse(adapter.active)

    def test_changed_input_after_creation_is_never_resumed_and_child_is_cleaned(self):
        work = self.root/'phase'; work.mkdir(); adapter = FakeBackend(); receipt = {}; calls = []
        def verify():
            calls.append(1)
            if len(calls) == 3: raise RuntimeError('changed before resume')
        with self.assertRaisesRegex(RuntimeError, 'changed before resume'):
            ex.phase(adapter, ['dm.exe'], work, receipt, verify, 60, watchdog_factory=FakeWatchdog)
        self.assertEqual(adapter.actions, ['create', 'cleanup'])
        self.assertIn('changed before resume', receipt['error'])

    def test_compile_diagnostic_retained_stops_without_runtime_or_retry(self):
        path, sha = self.packet(); adapter = FakeBackend('compiler'); clock = Clock()
        with self.assertRaisesRegex(RuntimeError, 'Compiler exit or diagnostic'):
            ex.run_packet(path, sha, path.parent/'execution', adapter,
                          now=clock.now, pause=clock.pause, watchdog_factory=FakeWatchdog)
        self.assertEqual(adapter.children, 1)
        receipt = json.loads((path.parent/'execution/receipt.json').read_text())
        self.assertEqual(receipt['result'], 'failed')
        self.assertTrue(receipt['cases'][0]['phases'][0]['cleanup']['all_exited'])
        self.assertIn('fatal error', (path.parent/'execution/fixed/compile/world/stdout.log').read_text())

    def test_corrupted_copy_cannot_define_its_own_trusted_hash(self):
        for destination in ('fixed', 'world'):
            with self.subTest(destination=destination), tempfile.TemporaryDirectory() as directory:
                old_root=self.root;self.root=Path(directory)
                try:
                    path,sha=self.packet();adapter=FakeBackend()
                    original=ex.shutil.copyfile
                    def copy(source,target):
                        result=original(source,target)
                        target=Path(target)
                        if target.name=='production.dm' and target.parent.name==destination:
                            target.write_bytes(b'corrupted copy')
                        return result
                    with patch.object(ex.shutil,'copyfile',side_effect=copy), self.assertRaisesRegex(RuntimeError,'changed'):
                        ex.run_packet(path,sha,path.parent/'execution',adapter,watchdog_factory=FakeWatchdog)
                    self.assertEqual(adapter.children,0)
                finally: self.root=old_root

    def test_exact_compiler_banner_warnings_and_unrelated_errors_fail(self):
        ex.compiler_result(0, COMPILE)
        for log in (COMPILE.replace('516.1681', '516.1682'), COMPILE.replace('0 warnings', '1 warning'),
                    COMPILE+COMPILE, COMPILE+'runtime error: injected\n'):
            with self.subTest(log=log), self.assertRaises(RuntimeError): ex.compiler_result(0, log)

    def test_corrupted_artifact_copy_stops_before_any_runtime_child(self):
        path,sha=self.packet();adapter=FakeBackend();clock=Clock()
        original=ex.shutil.copyfile
        def copy(source,target):
            result=original(source,target);target=Path(target)
            if target.name=='probe.dmb' and target.parent.name=='fixed': target.write_bytes(b'corrupted artifact')
            return result
        with patch.object(ex.shutil,'copyfile',side_effect=copy), self.assertRaisesRegex(RuntimeError,'artifact copy changed'):
            ex.run_packet(path,sha,path.parent/'execution',adapter,now=clock.now,pause=clock.pause,watchdog_factory=FakeWatchdog)
        self.assertEqual(adapter.children,1)
        self.assertFalse(adapter.active)

    def test_named_negative_oracle_required_and_collateral_is_retained(self):
        for case, expected in ex.EXPECTED.items():
            if not expected: continue
            log=BATCHES+f'FAIL wolf cave: {expected}\nFAIL wolf cave: collateral\nFAIL wolf cave ownership\n'
            result=ex.native_result(case, 0, log)
            self.assertEqual(result['collateral'], ['collateral'])
            self.assertEqual(result['first_failure'], expected)
            for changed in (log.replace(expected, 'unrelated'), log+'PASS wolf cave ownership\n',
                            log+'FAIL wolf cave runtime: exception\n', log.replace(BATCHES, ''), log+'FAIL other\n'):
                with self.subTest(case=case), self.assertRaises(RuntimeError): ex.native_result(case, 0, changed)

    def test_fixed_pass_requires_six_batches_no_failures_and_successful_exit(self):
        ex.native_result('fixed', 0, BATCHES+'PASS wolf cave ownership\n')
        for code, text in ((1, BATCHES+'PASS wolf cave ownership\n'), (0, 'PASS wolf cave ownership\n'),
                           (0, BATCHES+'FAIL wolf cave: nope\nPASS wolf cave ownership\n')):
            with self.assertRaises(RuntimeError): ex.native_result('fixed', code, text)

    def test_independent_watchdog_owns_a_duplicate_handle_and_closes_it(self):
        adapter = FakeBackend(); watchdog = ex.WallWatchdog(adapter, SimpleNamespace(), 0)
        watchdog.start(); watchdog.thread.join(timeout=1); watchdog.stop()
        self.assertTrue(watchdog.fired)
        self.assertEqual(adapter.actions, ['duplicate-watchdog', ('watchdog-terminate',987), ('watchdog-close',987)])

    def test_failed_sample_is_on_disk_before_teardown_and_primary_error_survives(self):
        path,sha=self.packet();clock=Clock();saved=path.parent/'execution/receipt.json'
        primary=RuntimeError('membership sentinel')
        primary.sample_diagnostic={'pid_list':{'assigned':2,'count':1,'return_length':16},'wait_after':{'result':0}}
        observed=[]
        class Backend(FakeBackend):
            def sample(self,child): raise primary
            def cleanup(self,child):
                # This executes BEFORE cleanup: evidence must already be on disk.
                before=json.loads(saved.read_text())['cases'][0]['phases'][0]
                observed.append(before)
                super().cleanup(child)
                raise RuntimeError('cleanup sentinel')
        class Watchdog(FakeWatchdog):
            def stop(self): raise RuntimeError('watchdog sentinel')
        backend=Backend()
        with self.assertRaises(RuntimeError) as caught:
            ex.run_packet(path,sha,path.parent/'execution',backend,now=clock.now,pause=clock.pause,watchdog_factory=Watchdog)
        self.assertIs(caught.exception,primary)
        self.assertEqual(observed[0]['failed_sample'],primary.sample_diagnostic)
        self.assertEqual(observed[0]['error'],'membership sentinel')
        self.assertNotIn('cleanup',observed[0])
        final=json.loads(saved.read_text())
        phase=final['cases'][0]['phases'][0]
        self.assertEqual(final['error'],'membership sentinel')
        self.assertEqual(phase['error'],'membership sentinel')
        self.assertEqual([error['stage'] for error in phase['teardown_errors']],['watchdog','cleanup'])
        self.assertFalse(phase['cleanup']['all_exited'])
        self.assertFalse(backend.active)

    def test_persistence_failure_does_not_skip_cleanup_or_replace_primary(self):
        work=self.root/'phase';work.mkdir();backend=FakeBackend('sample');receipt={}
        def persist(): raise OSError('disk sentinel')
        with self.assertRaisesRegex(RuntimeError,'sample fault'):
            ex.phase(backend,['dm.exe'],work,receipt,lambda:None,60,
                     watchdog_factory=FakeWatchdog,persist=persist)
        self.assertEqual(receipt['persistence_error']['message'],'disk sentinel')
        self.assertTrue(receipt['cleanup']['all_exited'])
        self.assertFalse(backend.active)

    def test_unannotated_adapter_exception_is_also_saved_before_cleanup(self):
        path,sha=self.packet();saved=path.parent/'execution/receipt.json';observed=[]
        class Backend(FakeBackend):
            def cleanup(self,child):
                before=json.loads(saved.read_text())['cases'][0]['phases'][0]
                observed.append(before['error'])
                return super().cleanup(child)
        backend=Backend('sample')
        with self.assertRaisesRegex(RuntimeError,'sample fault'):
            ex.run_packet(path,sha,path.parent/'execution',backend,watchdog_factory=FakeWatchdog)
        self.assertEqual(observed,['sample fault'])
        self.assertFalse(backend.active)

    def test_reviewed_limits_are_unchanged_by_diagnostics(self):
        self.assertEqual(ex.POLICY,{'child_bytes':268435456,'compile_seconds':60,'runtime_seconds':20,
                                   'cleanup_seconds':5,'max_cells':144,'sample_seconds':.05,
                                   'min_free_bytes':1073741824,'max_output_bytes':16777216})
        self.assertEqual((win.CAP,win.FLAGS,win.CREATE_FLAGS),(268435456,0x2308,0x08080404))


class Function:
    def __init__(self, callback): self.callback=callback
    def __call__(self,*args): return self.callback(*args)


class Library:
    def __init__(self, native): self.native=native
    def __getattr__(self,name):
        value=Function(lambda *args:self.native.call(name,args));setattr(self,name,value);return value


class Native:
    def __init__(self,fault=None):
        self.fault=fault;self.calls=[];self.closed=[];self.member=False;self.dead=False;self.nextfile=10
        self.limits=None;self.creation_flags=None;self.image=None;self.socket_rows={}
    def call(self,name,args):
        self.calls.append((name,args))
        if self.fault==name: return 0xffffffff if name=='ResumeThread' else 0
        if name=='CreateJobObjectW': return 100
        if name=='SetInformationJobObject': self.limits=C.string_at(args[2],args[3]);return 1
        if name=='QueryInformationJobObject':
            if args[1]==9: C.memmove(args[2],self.limits,len(self.limits))
            elif args[1]==1:
                value=C.cast(args[2],C.POINTER(win.Accounting)).contents
                value.total=1;value.active=0 if self.dead else 1
            elif args[1]==3:
                value=C.cast(args[2],C.POINTER(win.Members)).contents
                value.assigned=value.count=0 if self.dead else 1;value.pids[0]=500
                C.cast(args[4],C.POINTER(win.U32)).contents.value=C.sizeof(win.Members)
            return 1
        if name=='CreateFileW':
            self.nextfile+=1;return self.nextfile
        if name=='InitializeProcThreadAttributeList':
            C.cast(args[3],C.POINTER(C.c_size_t)).contents.value=128;return int(args[0] is not None)
        if name=='UpdateProcThreadAttribute':

            self.inherited=list(C.cast(args[3],C.POINTER(win.HANDLE*3)).contents);return 1
        if name=='DeleteProcThreadAttributeList': return 1
        if name=='CreateProcessW':
            self.image=args[0];self.creation_flags=args[5]
            self.inherit=args[4];self.environment=args[6][:]
            self.startup=win.Startup.from_buffer_copy(C.string_at(args[-2],C.sizeof(win.Startup)))
            value=C.cast(args[-1],C.POINTER(win.ProcessInfo)).contents
            value.process,value.thread,value.pid,value.tid=300,400,500,600;return 1
        if name=='AssignProcessToJobObject': self.member=True;return 1
        if name=='IsProcessInJob': C.cast(args[2],C.POINTER(win.BOOL)).contents.value=self.member;return 1
        if name=='QueryFullProcessImageNameW': args[2].value=self.image;return 1
        if name=='GetProcessTimes': C.cast(args[1],C.POINTER(C.c_uint64)).contents.value=123;return 1
        if name=='ResumeThread': return 1
        if name in ('TerminateJobObject','TerminateProcess'): self.dead=True;return 1
        if name=='WaitForSingleObject': return 0 if self.dead else 258
        if name=='GetExitCodeProcess': C.cast(args[1],C.POINTER(win.U32)).contents.value=0;return 1
        if name=='CloseHandle': self.closed.append(args[0]);return 1
        if name=='GetCurrentProcess': return 700
        if name=='GlobalMemoryStatusEx':
            value=C.cast(args[0],C.POINTER(win.HostMemory)).contents;value.available=value.page_available=2**31;return 1
        if name=='GetProcessAffinityMask': C.cast(args[1],C.POINTER(C.c_size_t)).contents.value=3;return 1
        if name=='GetSystemTimes':
            for index,arg in enumerate(args): C.cast(arg,C.POINTER(C.c_uint64)).contents.value=index+1
            return 1
        if name=='GetProcessMemoryInfo': C.cast(args[1],C.POINTER(win.Memory)).contents.private=1024;return 1
        if name=='DuplicateHandle': C.cast(args[3],C.POINTER(win.HANDLE)).contents.value=800;return 1
        if name in ('GetExtendedTcpTable','GetExtendedUdpTable'):
            raw=self.socket_rows.get((args[3],name), b'\0'*4)
            C.cast(args[1],C.POINTER(win.U32)).contents.value=len(raw)
            if args[0] is None: return 122
            C.memmove(args[0],raw,len(raw));return 0
        raise AssertionError('Unexpected API '+name)


class WindowsTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)
        self.tripwire=patch.object(C,'WinDLL',side_effect=AssertionError('Native binding forbidden'),create=True)
        self.tripwire.start();self.addCleanup(self.tripwire.stop)
        self.env=patch.dict('os.environ',{'SystemRoot':'C:/Windows'});self.env.start();self.addCleanup(self.env.stop)
    def backend(self,native):
        library=Library(native)
        return win.WindowsJob(library,library,library,error=lambda:OSError('injected Win32 failure'))
    def create(self,native):
        return self.backend(native).start_suspended([str(self.root/'dm.exe'),'probe.dme'],self.root,self.root)

    def pid_variant(self,work,assigned,count,length,result=1,exit_after=False):
        native=Native();adapter=self.backend(native)
        child=adapter.start_suspended([str(work/'dm.exe')],work,work)
        original=native.call
        def call(name,args):
            value=original(name,args)
            if name=='QueryInformationJobObject' and args[1]==3:
                members=C.cast(args[2],C.POINTER(win.Members)).contents
                members.assigned,members.count=assigned,count
                C.cast(args[4],C.POINTER(win.U32)).contents.value=length
                if exit_after:native.dead=True
                return result
            return value
        native.call=call
        return adapter,child,native

    def test_short_successful_and_empty_pid_lists_keep_original_acceptance(self):
        for assigned,count,length,ended in ((1,1,16,False),(1,1,24,False),(0,0,8,True),(0,0,16,True)):
            with self.subTest(values=(assigned,count,length,ended)), tempfile.TemporaryDirectory() as directory:
                adapter,child,_=self.pid_variant(Path(directory),assigned,count,length,exit_after=ended)
                sample=adapter.sample(child);raw=sample['diagnostic']
                self.assertEqual(raw['pid_list']['assigned'],assigned)
                self.assertEqual(raw['pid_list']['count'],count)
                self.assertEqual(raw['pid_list']['return_length'],length)
                self.assertEqual(raw['wait_before']['result'],258)
                self.assertEqual(raw['wait_after']['result'],0 if ended else 258)
                if ended:self.assertEqual(raw['exit_after']['exit_code'],0)
                self.assertTrue(adapter.cleanup(child)['all_exited'])

    def test_rejected_counts_lengths_and_truncation_keep_raw_snapshot(self):
        for assigned,count,length in ((1,1,8),(1,1,25),(1,0,8),(2,2,24),(3,3,32)):
            with self.subTest(values=(assigned,count,length)), tempfile.TemporaryDirectory() as directory:
                adapter,child,_=self.pid_variant(Path(directory),assigned,count,length)
                with self.assertRaisesRegex(RuntimeError,'membership unavailable') as caught:adapter.sample(child)
                raw=caught.exception.sample_diagnostic
                self.assertEqual((raw['pid_list']['assigned'],raw['pid_list']['count'],raw['pid_list']['return_length']),
                                 (assigned,count,length))
                self.assertLessEqual(len(raw['pid_list']['buffer_prefix']),2)
                self.assertEqual(raw['layout'],{'buffer_bytes':24,'alignment':8,'pid_offset':8,'pointer_bytes':8,
                                               'offsets':{'assigned':0,'count':4,'pids':8}})
                self.assertEqual(raw['pid_list']['query_result'],1)
                self.assertEqual(raw['accounting']['total'],1)
                self.assertTrue(adapter.cleanup(child)['all_exited'])

    def test_exit_race_is_recorded_without_bypassing_truncated_list_rejection(self):
        adapter,child,_=self.pid_variant(self.root,1,0,8,exit_after=True)
        with self.assertRaisesRegex(RuntimeError,'membership unavailable') as caught:adapter.sample(child)
        raw=caught.exception.sample_diagnostic
        self.assertEqual(raw['wait_before']['result'],258)
        self.assertEqual(raw['wait_after']['result'],0)
        self.assertEqual(raw['exit_after']['exit_code'],0)
        self.assertTrue(adapter.cleanup(child)['all_exited'])

    def test_failed_query_keeps_original_api_exception_and_partial_buffer(self):
        adapter,child,_=self.pid_variant(self.root,2,1,16,result=0)
        primary=OSError('query sentinel');adapter.error=lambda:primary
        with self.assertRaises(OSError) as caught:adapter.sample(child)
        self.assertIs(caught.exception,primary)
        raw=primary.sample_diagnostic
        self.assertEqual(raw['pid_list']['query_result'],0)
        self.assertEqual((raw['pid_list']['assigned'],raw['pid_list']['count'],raw['pid_list']['return_length']),(2,1,16))
        self.assertEqual(raw['pid_list']['error']['message'],'query sentinel')
        self.assertTrue(adapter.cleanup(child)['all_exited'])

    def test_suspended_creation_exact_job_limits_membership_and_resume_order(self):
        native=Native();adapter=self.backend(native)
        child=adapter.start_suspended([str(self.root/'dm.exe'),'probe.dme'],self.root,self.root)
        names=[name for name,_ in native.calls]
        self.assertNotIn('ResumeThread',names)
        self.assertLess(names.index('AssignProcessToJobObject'),names.index('IsProcessInJob'))
        limits=win.Limits.from_buffer_copy(native.limits)
        self.assertEqual((limits.basic.flags,limits.basic.active,limits.process_memory,limits.job_memory),
                         (win.FLAGS,1,256*1024**2,256*1024**2))
        self.assertFalse(limits.basic.flags & (0x800|0x1000))
        self.assertEqual(native.creation_flags,win.CREATE_FLAGS)
        self.assertFalse(native.creation_flags & 0x01000000)
        self.assertTrue(native.inherit)
        self.assertEqual(native.inherited,[11,12,13])
        self.assertEqual((native.startup.stdin,native.startup.stdout,native.startup.stderr),(13,11,12))
        self.assertEqual((native.startup.flags,native.startup.show),(0x101,0))
        self.assertIn('USERPROFILE='+str(self.root/'environment'),native.environment)
        self.assertNotIn('CODEX_HOME=',native.environment)
        adapter.resume(child)
        self.assertEqual(adapter.sample(child)['private_bytes'],1024)
        self.assertEqual(adapter.resources()['allowed_cpus'],2)
        self.assertEqual(adapter.sockets(child),[])
        result=adapter.cleanup(child)
        self.assertTrue(result['all_exited']);self.assertEqual(result['active_processes'],0)
        self.assertTrue(all(handle in native.closed for handle in (100,300,400)))

    def test_creation_faults_never_resume_and_all_created_handles_are_closed(self):
        for fault in ('SetInformationJobObject','CreateProcessW','AssignProcessToJobObject',
                      'IsProcessInJob','QueryFullProcessImageNameW','GetProcessTimes'):
            with self.subTest(fault=fault), tempfile.TemporaryDirectory() as directory:
                native=Native(fault);adapter=self.backend(native);work=Path(directory)
                with self.assertRaises(OSError): adapter.start_suspended([str(work/'dm.exe')],work,work)
                self.assertNotIn('ResumeThread',[n for n,_ in native.calls])
                self.assertIn(100,native.closed)
                if native.image:
                    self.assertTrue(native.dead)
                    self.assertTrue(all(h in native.closed for h in (300,400)))

    def test_query_limit_tampering_fails_before_process_creation(self):
        native=Native();original=native.call
        def call(name,args):
            result=original(name,args)
            if name=='QueryInformationJobObject' and args[1]==9:
                C.cast(args[2],C.POINTER(win.Limits)).contents.process_memory+=1
            return result
        native.call=call
        with self.assertRaisesRegex(RuntimeError,'limits differ'): self.create(native)
        self.assertNotIn('CreateProcessW',[n for n,_ in native.calls])
        self.assertIn(100,native.closed)

    def test_membership_rejection_and_resume_failure_leave_owned_cleanup_possible(self):
        native=Native();adapter=self.backend(native)
        child=adapter.start_suspended([str(self.root/'dm.exe')],self.root,self.root)
        native.fault='ResumeThread'
        with self.assertRaises(OSError): adapter.resume(child)
        self.assertTrue(adapter.cleanup(child)['all_exited'])

    def test_duplicate_watchdog_handle_is_independent_and_owned(self):
        native=Native();adapter=self.backend(native)
        child=adapter.start_suspended([str(self.root/'dm.exe')],self.root,self.root)
        handle=adapter.watchdog_handle(child);self.assertEqual(handle,800)
        adapter.watchdog_terminate(handle);adapter.watchdog_close(handle)
        self.assertTrue(adapter.cleanup(child)['all_exited'])

    def test_ipv4_listener_census_matches_owned_pid_only(self):
        native=Native();adapter=self.backend(native)
        child=adapter.start_suspended([str(self.root/'dm.exe')],self.root,self.root)
        import struct
        row=struct.pack('<6I',2,0,0,0,0,500)
        native.socket_rows[(2,'GetExtendedTcpTable')]=struct.pack('<I',1)+row
        self.assertEqual(adapter.sockets(child),[{'family':2,'protocol':'tcp','state':2,'listener':True}])
        native.socket_rows[(2,'GetExtendedTcpTable')]=struct.pack('<I',1)+struct.pack('<6I',2,0,0,0,0,999)
        self.assertEqual(adapter.sockets(child),[])
        self.assertTrue(adapter.cleanup(child)['all_exited'])

    def test_cleanup_errors_are_reported_without_skipping_other_handle_closes(self):
        native=Native();adapter=self.backend(native)
        child=adapter.start_suspended([str(self.root/'dm.exe')],self.root,self.root)
        native.fault='TerminateJobObject';native.dead=True
        result=adapter.cleanup(child)
        self.assertFalse(result['all_exited'])
        self.assertTrue(all(h in native.closed for h in (100,300,400)))

    def test_log_handle_failure_after_successful_creation_still_cleans_suspended_child(self):
        native=Native();original=native.call
        def call(name,args):
            if name=='CloseHandle' and args[0]==11: return 0
            return original(name,args)
        native.call=call
        with self.assertRaisesRegex(RuntimeError,'log-handle cleanup failed'): self.create(native)
        self.assertTrue(native.dead)
        self.assertTrue(all(h in native.closed for h in (100,300,400)))
        self.assertNotIn('ResumeThread',[n for n,_ in native.calls])

    def test_cleanup_wait_failure_is_not_reported_as_a_pass_and_handles_still_close(self):
        native=Native();adapter=self.backend(native)
        child=adapter.start_suspended([str(self.root/'dm.exe')],self.root,self.root)
        original=native.call
        native.call=lambda name,args:258 if name=='WaitForSingleObject' else original(name,args)
        result=adapter.cleanup(child)
        self.assertFalse(result['all_exited']);self.assertTrue(result['errors'])
        self.assertTrue(all(h in native.closed for h in (100,300,400)))

    def test_socket_census_truncation_fails_closed_without_attaching_or_retry(self):
        native=Native();adapter=self.backend(native)
        child=adapter.start_suspended([str(self.root/'dm.exe')],self.root,self.root)
        native.socket_rows[(2,'GetExtendedTcpTable')]=b'\x01\x00\x00\x00'
        with self.assertRaisesRegex(RuntimeError,'Truncated socket census'): adapter.sockets(child)
        self.assertNotIn('OpenProcess',[n for n,_ in native.calls])
        self.assertTrue(adapter.cleanup(child)['all_exited'])

    def test_unexpected_owned_membership_is_rejected(self):
        native=Native();adapter=self.backend(native)
        child=adapter.start_suspended([str(self.root/'dm.exe')],self.root,self.root)
        original=native.call
        def call(name,args):
            result=original(name,args)
            if name=='QueryInformationJobObject' and args[1]==3:
                C.cast(args[2],C.POINTER(win.Members)).contents.pids[0]=999
            return result
        native.call=call
        with self.assertRaisesRegex(RuntimeError,'Unexpected owned Job process'): adapter.sample(child)
        self.assertTrue(adapter.cleanup(child)['all_exited'])


if __name__=='__main__': unittest.main()
