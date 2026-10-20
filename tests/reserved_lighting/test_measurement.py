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

    def test_aggregate_timeout_and_source_drift_stop_after_cleanup(self):
        ticks=iter((0,0,0,0,0,961))
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


if __name__=='__main__':unittest.main()
