"""Injected fake processes only: no engine, subprocess, socket or live state."""
import copy
import json
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest.mock import patch

import measurement as m


class Fake:
    def __init__(self, fault=None):
        self.fault, self.launched, self.cleaned = fault, [], []

    def launch(self, packet, root, work, mode):
        child = SimpleNamespace(identity={'pid':len(self.launched)+1, 'start_ticks':100}, mode=mode, tick=0)
        self.launched.append(child)
        if self.fault == 'launch':
            raise ValueError('launch failed after retention')
        return child

    def sample(self, child):
        child.tick += 1
        row = {'identity':child.identity, 'cpu':child.tick*.1, 'wall':child.tick*.2,
               'private':20 if child.mode=='baseline' else 10, 'children':[], 'sockets':[],
               'private_sampled':child.tick==1, 'exited':child.tick==2, 'exit_code':0}
        if self.fault == 'attribution': row['identity']={'pid':999, 'start_ticks':100}
        if self.fault == 'private': row['private']=10**10
        if self.fault == 'cpu': row['cpu']=11
        if self.fault == 'wall': row['wall']=31
        if self.fault == 'socket': row['sockets']=['bad']
        if self.fault == 'child': row['children']=[42]
        if self.fault == 'exit': row['exit_code']=1
        return row

    def cleanup(self, child):
        self.cleaned.append(child)
        return {'all_exited':self.fault != 'cleanup', 'empty':True, 'errors':[]}


class Measurements(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)
        self.inputs=self.root/'inputs'
        self.inputs.mkdir()
        for name in ('daemon','probe.dmb','probe.rsc','probe.dm'): (self.inputs/name).write_bytes(name.encode())
        (self.inputs/'probe.dm').write_bytes(Path(m.__file__).with_name('probe.dm').read_bytes())
        self.packet={'schema':1,'head':'a'*40,'pairs':2,'interval':.1,'fixture_sha256':'b'*64,
                     'parity_run':39347909747,'parity_head':'2d4229c2ca3062e6c358aa21575f0c203282f995',
                     'fixture':'probe.dm','daemon':'daemon','dmb':'probe.dmb','rsc':'probe.rsc',
                     'command_tail':['-close','-trusted','-log','runtime.log','-params'],
                     'files':{p.name:m.sha(p) for p in self.inputs.iterdir()},
                     'limits':{'wall':30,'cpu':10,'private':512*1024**2,'output':16*1024**2,'total_wall':960}}
        self.packet['fixture_sha256']=m.sha(self.inputs/'probe.dm')
        self.packet['execution']=m.execution_identity()
        self.out=self.root/'output'

    def execute(self, adapter, **kwargs):
        return m.run(self.packet,self.inputs,self.out,adapter,clock=lambda:0,pause=lambda _:None,
                     accept=lambda *_:None,parity=lambda *_:{'snapshots':6,'rows':1350,'equal':True},**kwargs)

    def test_pairs_warmups_attribution_and_cleanup(self):
        fake=Fake()
        result=self.execute(fake)
        self.assertTrue(result['complete'])
        self.assertEqual([r['mode'] for r in result['runs']],['baseline','candidate','baseline','candidate','candidate','baseline'])
        self.assertEqual(len(fake.cleaned),6)
        self.assertEqual(result['median_differences'],{'cpu':0,'wall':0,'sampled_private_peak':-10})
        self.assertEqual(len(result['paired_candidate_minus_baseline']),2)
        self.assertTrue(all(len(r['samples'])==2 and r['complete'] for r in result['runs']))

    def test_failed_samples_are_persisted_and_cleanup_is_mandatory(self):
        for fault in ('attribution','private','cpu','wall','socket','child','exit','cleanup','launch'):
            with self.subTest(fault=fault):
                self.out=self.root/fault
                fake=Fake(fault)
                with self.assertRaises(ValueError): self.execute(fake)
                report=json.loads((self.out/'measurement.json').read_text())
                self.assertFalse(report['complete'])
                self.assertEqual(len(fake.cleaned),1)
                self.assertEqual(len(report['runs']),1)  # never continue after failure
                self.assertIn('cleanup',report['runs'][0])
                if fault not in ('launch',): self.assertTrue(report['runs'][0]['samples'])

    def test_incomparable_packet_rejected_before_launch(self):
        for key,value in (('command_tail',['anything']),('pairs',11),('interval',0),('rsc','other.rsc')):
            original=copy.deepcopy(self.packet)
            self.packet[key]=value
            fake=Fake()
            with self.subTest(key=key),self.assertRaises(ValueError):self.execute(fake)
            self.assertFalse(fake.launched)
            self.packet=original
        (self.inputs/'probe.dmb').write_bytes(b'drift')
        with self.assertRaisesRegex(ValueError,'Input changed'):self.execute(Fake())

    def test_expired_lease_never_launches(self):
        fake=Fake()
        def expired():raise ValueError('Lease expired')
        with self.assertRaisesRegex(ValueError,'Lease expired'):self.execute(fake,lease=expired)
        self.assertFalse(fake.launched)

    def test_expiration_during_hashing_prevents_launch(self):
        fake=Fake(); expired=False
        original=m.validate_packet
        def validate(*args):
            nonlocal expired
            original(*args)
            expired=True
        calls=0
        def lease():
            nonlocal calls
            calls+=1
            if calls>1 and expired:raise ValueError('Lease expired')
        with patch.object(m,'validate_packet',side_effect=validate):
            with self.assertRaisesRegex(ValueError,'Lease expired'):self.execute(fake,lease=lease)
        self.assertFalse(fake.launched)

    def test_execution_drift_rejected_before_launch(self):
        fake=Fake()
        self.packet['execution'][str(Path(m.__file__).resolve())]='0'*64
        with self.assertRaisesRegex(ValueError,'Execution inputs changed'):self.execute(fake)
        self.assertFalse(fake.launched)

    def test_diagnostic_spacing_and_runtime_errors(self):
        for text in ('## ERROR: File not found config/config.txt','##ERROR: failure',
                     'Bad ref','Bad loc','Cannot execute null.proc()','Runtime in /proc/test'):
            with self.subTest(text=text):self.assertIsNotNone(m.DIAGNOSTIC.search(text))

    def test_outcome_rejects_fatal_diagnostics_despite_pass_artifacts(self):
        work=self.root/'fatal-outcome';work.mkdir()
        (work/'result.txt').write_text('PASS')
        (work/'port-closed.txt').write_text('closed')
        (work/'states.jsonl').write_text('fixture schema checked by injected comparator')
        logs=('runtime.log','stdout.log','stderr.log')
        for name in logs:(work/name).write_text('normal fixture completion')
        with patch.object(m,'compare') as compare:
            m.outcome(work,4096)
            compare.assert_called_once()  # positive control reaches comparison
            for name in logs:
                for diagnostic in ('## ERROR: File not found config/config.txt',
                                   'Unhandled exception in fixture','Out of memory',
                                   'Assertion failed','Access violation'):
                    with self.subTest(log=name,diagnostic=diagnostic):
                        compare.reset_mock()
                        (work/name).write_text(diagnostic)
                        with self.assertRaisesRegex(ValueError,'Native diagnostic'):
                            m.outcome(work,4096)
                        compare.assert_not_called()
                        (work/name).write_text('normal fixture completion')
            m.outcome(work,4096)
            compare.assert_called_once()  # removing diagnostic restores acceptance

    def test_reaped_parent_group_is_retired_without_double_wait(self):
        adapter=object.__new__(m.LinuxAdapter)
        adapter.child=SimpleNamespace(process=SimpleNamespace(pid=123),result=(0,.1),handles=[],identity={'pid':123,'start_ticks':100})
        with patch.object(adapter,'group_members',side_effect=[[456],[]]), \
             patch.object(m.os,'killpg',create=True) as kill, \
             patch.object(m.os,'wait4',create=True) as wait, patch.object(m.time,'sleep'), \
             patch('signal.SIGKILL',9,create=True):
            result=adapter.cleanup(None)
        self.assertTrue(result['all_exited'] and result['empty'])
        kill.assert_called_once()
        wait.assert_not_called()

    def test_surviving_group_or_changed_ownership_fails_cleanup(self):
        for changed in (False,True):
            adapter=object.__new__(m.LinuxAdapter)
            adapter.child=SimpleNamespace(process=SimpleNamespace(pid=123),result=(0,.1),handles=[],identity={'pid':123,'start_ticks':100})
            with patch.object(adapter,'group_members',side_effect=ValueError('ownership') if changed else None,
                              return_value=[456]), patch.object(m.os,'killpg',create=True) as kill, \
                 patch.object(m.time,'monotonic',side_effect=[0,6]), patch('signal.SIGKILL',9,create=True):
                result=adapter.cleanup(None)
            self.assertFalse(result['all_exited'])
            self.assertFalse(result['empty'])
            if changed:kill.assert_not_called()

    def test_group_members_validate_birth_and_session(self):
        adapter=object.__new__(m.LinuxAdapter)
        child=SimpleNamespace(process=SimpleNamespace(pid=123),identity={'pid':123,'start_ticks':100})
        for name,start,session,valid in (('456',101,123,True),('456',99,123,False),
                                        ('456',101,999,False),('123',101,123,False)):
            fields=['0']*20
            fields[2]='123';fields[3]=str(session);fields[19]=str(start)
            path=Path('/proc')/name
            with patch.object(Path,'iterdir',return_value=iter([path])), \
                 patch.object(Path,'read_text',return_value='123 (name) '+' '.join(fields)):
                if valid:self.assertEqual(adapter.group_members(child),[int(name)])
                else:
                    with self.assertRaises(ValueError):adapter.group_members(child)

    def test_counter_units_regression_and_nonfinite_rejected(self):
        self.assertEqual(m.private_bytes('Private_Clean: 2 kB\nPrivate_Dirty: 3 kB\nPrivate_Hugetlb: 4 kB\n'),9*1024)
        with self.assertRaises(ValueError):m.private_bytes('Private_Clean: 0 kB\n')
        fake=Fake(); child=fake.launch(None,None,None,'baseline')
        previous=fake.sample(child)
        for key,value in (('cpu',-.1),('private',float('nan')),('wall',float('inf'))):
            row=copy.deepcopy(previous);row[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):m.validate_sample(row,child.identity,None,self.packet['limits'])
        row=copy.deepcopy(previous);row['cpu']=0
        with self.assertRaisesRegex(ValueError,'Counter reversal'):m.validate_sample(row,child.identity,previous,self.packet['limits'])

    def test_partial_outcome_parity_failure_and_output_bound(self):
        work=self.root/'work';work.mkdir()
        (work/'result.txt').write_text('FAIL')
        with self.assertRaisesRegex(ValueError,'Partial/failed'):m.outcome(work,1024)
        (work/'big').write_bytes(b'x'*100)
        with self.assertRaisesRegex(ValueError,'Output bound'):m.output_bound(work,10)
        def fail(*_):raise ValueError('parity mismatch')
        fake=Fake()
        with self.assertRaisesRegex(ValueError,'parity mismatch'):
            m.run(self.packet,self.inputs,self.out,fake,clock=lambda:0,pause=lambda _:None,accept=lambda *_:None,parity=fail)
        self.assertEqual(len(fake.cleaned),4)
        self.assertFalse(json.loads((self.out/'measurement.json').read_text())['complete'])

    def test_sealer_is_inert_binds_artifacts_and_refuses_overwrite(self):
        build={'head':self.packet['head'],'byond_version':'516.1681','compiler_sha256':'c'*64,
               'files':{p.name:m.sha(p) for p in self.inputs.iterdir()}}
        (self.inputs/'build.json').write_text(json.dumps(build))
        with patch.object(m.LinuxAdapter,'launch',side_effect=AssertionError('Native launch forbidden')):
            packet=m.seal(self.inputs,self.packet['head'])
        m.validate_packet(packet,self.inputs)
        self.assertEqual(packet['pairs'],10)
        with self.assertRaises(FileExistsError):m.seal(self.inputs,self.packet['head'])

    def test_linux_adapter_partial_launch_retains_and_closes_handles(self):
        adapter=object.__new__(m.LinuxAdapter);adapter.child=None
        work=self.root/'launch';work.mkdir()
        with patch.dict('sys.modules',{'resource':SimpleNamespace()}), patch('subprocess.Popen',side_effect=OSError('injected launch failure')):
            with self.assertRaises(OSError):adapter.launch(self.packet,self.inputs,work,'baseline')
        handles=list(adapter.child.handles)
        result=adapter.cleanup(None)
        self.assertTrue(result['all_exited'] and result['empty'])
        self.assertTrue(all(handle.closed for handle in handles))

    def test_post_popen_identity_failure_reaps_direct_child_without_group_signal(self):
        for already_exited in (False,True):
            adapter=object.__new__(m.LinuxAdapter);adapter.child=None
            work=self.root/('post-popen-'+str(already_exited));work.mkdir()
            process=SimpleNamespace(pid=123,returncode=None)
            usage=SimpleNamespace(ru_utime=.1,ru_stime=.2)
            waits=[(123,0,usage)] if already_exited else [(0,0,None),(123,0,usage)]
            with patch.dict('sys.modules',{'resource':SimpleNamespace()}), \
                 patch('subprocess.Popen',return_value=process), \
                 patch.object(Path,'read_text',side_effect=OSError('injected stat failure')):
                with self.assertRaisesRegex(OSError,'stat failure'):
                    adapter.launch(self.packet,self.inputs,work,'baseline')
            handles=list(adapter.child.handles)
            with patch.object(m.os,'wait4',side_effect=waits,create=True) as wait, \
                 patch.object(m.os,'kill') as kill, patch.object(m.os,'killpg',create=True) as killpg, \
                 patch.object(m.os,'waitstatus_to_exitcode',return_value=0,create=True), \
                 patch.object(m.os,'WNOHANG',1,create=True), \
                 patch('signal.SIGKILL',9,create=True), patch.object(m.time,'sleep'):
                result=adapter.cleanup(None)
            self.assertEqual(wait.call_count,len(waits))
            self.assertEqual(kill.call_count,0 if already_exited else 1)
            killpg.assert_not_called()
            self.assertEqual(process.returncode,0)
            self.assertTrue(all(handle.closed for handle in handles))
            self.assertFalse(result['empty'])
            self.assertIn('containment cleanup required',result['errors'][0])

    def test_aggregate_timeout_and_source_drift_stop_after_cleanup(self):
        ticks=iter((0,0,0,0,0,0,961))
        fake=Fake()
        with self.assertRaisesRegex(ValueError,'Aggregate wall bound'):
            m.run(self.packet,self.inputs,self.out,fake,clock=lambda:next(ticks),pause=lambda _:None,accept=lambda *_:None)
        self.assertEqual(len(fake.cleaned),1)

    def test_changed_inputs_after_run_and_no_memory_sample_are_incomplete(self):
        fake=Fake()
        def drift(*_):(self.inputs/'probe.dmb').write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError,'Input changed'):
            m.run(self.packet,self.inputs,self.out,fake,clock=lambda:0,pause=lambda _:None,accept=drift)
        self.assertEqual(len(fake.cleaned),1)
        self.assertFalse(json.loads((self.out/'measurement.json').read_text())['complete'])
        (self.inputs/'probe.dmb').write_bytes(b'probe.dmb')
        fake=Fake();original=fake.sample
        def no_memory(child):
            row=original(child);row['private_sampled']=False;return row
        fake.sample=no_memory
        self.out=self.root/'no-memory'
        with self.assertRaisesRegex(ValueError,'No private memory sample'):self.execute(fake)
        self.assertEqual(len(fake.cleaned),1)

    def test_final_parity_cannot_commit_expired_or_changed_batch(self):
        for fault in ('lease', 'time', 'input', 'hashing'):
            with self.subTest(fault=fault):
                self.out = self.root / ('final-' + fault)
                fake = Fake()
                completed_parity = 0
                expired = False
                now = 0

                def parity(*_):
                    nonlocal completed_parity, expired, now
                    completed_parity += 1
                    if completed_parity == self.packet['pairs']:
                        if fault == 'lease':
                            expired = True
                        elif fault == 'time':
                            now = self.packet['limits']['total_wall'] + 1
                        elif fault == 'input':
                            (self.inputs / 'probe.dmb').write_bytes(b'changed during final parity')
                    return {'snapshots': 6, 'rows': 1350, 'equal': True}

                def lease():
                    if expired:
                        raise ValueError('Lease expired')

                original = m.validate_packet

                def validate(*args):
                    nonlocal expired
                    original(*args)
                    if fault == 'hashing' and completed_parity == self.packet['pairs']:
                        expired = True

                reason = {'lease': 'Lease expired', 'time': 'Aggregate wall bound',
                          'input': 'Input changed', 'hashing': 'Lease expired'}[fault]
                with patch.object(m, 'validate_packet', side_effect=validate), self.assertRaisesRegex(ValueError, reason):
                    m.run(self.packet, self.inputs, self.out, fake, clock=lambda: now,
                          pause=lambda _: None, accept=lambda *_: None, parity=parity, lease=lease)
                report = json.loads((self.out / 'measurement.json').read_text())
                self.assertFalse(report['complete'])
                self.assertEqual(completed_parity, self.packet['pairs'])
                self.assertEqual(len(fake.cleaned), 2 + 2 * self.packet['pairs'])
                (self.inputs / 'probe.dmb').write_bytes(b'probe.dmb')


if __name__=='__main__':unittest.main()
