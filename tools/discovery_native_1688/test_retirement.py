"""Synthetic task-copy retirement tests. No native execution or process observation."""
import copy
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from audit_offline import install
install()
import backend_proposal as backend
from prepare import digest


def receipt(phase='baseline-compile', role='compiler'):
    return {'phase': phase, 'role': role, 'pid': 123, 'started': True, 'terminated': True,
            'process_completed': True, 'cleanup_verified': True, 'validated': True,
            'verdict': 'causal-control-detected' if phase == 'smell-roundtrip' else 'passed',
            'process_receipt': {'process_started': True, 'pid': 123, 'termination_observed': True,
                'leader_reaped': True, 'cleanup_verified': True, 'cleanup_no_observed_live_descendants': True,
                'cleanup_process_group_absent': True, 'owned_child_listing_available': True,
                'owned_observation_trusted': True, 'signal_handlers_restored': True,
                'cleanup_errors': [], 'stop_reason': None, 'exit_code': 0, 'log_truncated': False}}


class RetirementTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.work = self.root/'baseline-compile'; self.work.mkdir()
        self.contents = {'code/a.dm': b'synthetic A', 'code/b.dm': b'synthetic B',
                         'discovery1688.dmb': b'synthetic compiled DMB', 'discovery1688.rsc': b'synthetic compiled RSC',
                         'discovery1688-probe.dm': b'generated probe', 'stdout.log': b'synthetic transcript',
                         'discovery-native-result.json': b'{}', 'discovery-mind.sav': b'synthetic save',
                         'discovery-mind-entries.json': b'synthetic entry'}
        for name, data in self.contents.items():
            target = self.work/name; target.parent.mkdir(parents=True, exist_ok=True); target.write_bytes(data)
        self.inputs = {name: {'bytes':len(data), 'sha256':digest(data)} for name,data in self.contents.items()}
        self.manifest = {name: {'size':len(self.contents[name]), 'sha256':digest(self.contents[name])}
                         for name in ['code/a.dm', 'code/b.dm']}
        self.phase = receipt()

    def retire(self):
        return backend.retire_reproducible_inputs(self.work, self.phase, self.manifest, self.inputs)

    def assert_no_deletion(self):
        for name in self.contents: self.assertTrue((self.work/name).exists(), name)
        self.assertFalse((self.work/'retired-inputs.json').exists())

    def test_compile_only_manifest_copies_retired_precise_ledger(self):
        ledger = self.retire()
        names = sorted(self.manifest)
        self.assertEqual(ledger, {'phase':'baseline-compile', 'status':'completed',
            'files':{name:self.inputs[name] for name in names}, 'retired':names,
            'unique_evidence_retired':False, 'reconstruct_from':'exact production checkout'})
        self.assertEqual(json.loads((self.work/'retired-inputs.json').read_text()), ledger)
        for name,data in self.contents.items():
            if name in names: self.assertFalse((self.work/name).exists())
            else: self.assertEqual((self.work/name).read_bytes(), data)

    def test_daemon_only_compiled_pair_retired(self):
        new = self.root/'baseline-reader'; self.work.rename(new); self.work=new
        self.phase=receipt('baseline-reader', 'daemon')
        ledger=self.retire()
        self.assertEqual(ledger['retired'], ['discovery1688.dmb', 'discovery1688.rsc'])
        self.assertEqual(ledger['reconstruct_from'], 'baseline-compile sealed DMB/RSC')
        self.assertFalse(ledger['unique_evidence_retired'])
        for name,data in self.contents.items():
            if name in ledger['retired']: self.assertFalse((self.work/name).exists())
            else: self.assertEqual((self.work/name).read_bytes(), data)

    def test_control_requires_detected_verdict(self):
        new=self.root/'smell-roundtrip'; self.work.rename(new); self.work=new
        self.phase=receipt('smell-roundtrip', 'daemon'); self.phase['verdict']='passed'
        with self.assertRaises(ValueError): self.retire()
        self.assert_no_deletion()
        self.phase['verdict']='causal-control-detected'
        self.assertEqual(self.retire()['status'], 'completed')

    def test_all_phase_flags_missing_false_or_nonbool_rejected_before_delete(self):
        original=copy.deepcopy(self.phase)
        for flag in ['started','terminated','process_completed','cleanup_verified','validated']:
            for value in ['missing',False,1,None]:
                self.phase=copy.deepcopy(original)
                if value == 'missing': del self.phase[flag]
                else: self.phase[flag]=value
                with self.subTest(flag=flag,value=value), self.assertRaises(ValueError): self.retire()
                self.assert_no_deletion()

    def test_phase_role_verdict_rejected_before_delete(self):
        original=copy.deepcopy(self.phase)
        for key,value in [('phase','baseline-writer'),('role','daemon'),('verdict','failed'),
                          ('verdict','causal-control-detected'),('verdict',None)]:
            self.phase=copy.deepcopy(original); self.phase[key]=value
            with self.subTest(key=key,value=value), self.assertRaises(ValueError): self.retire()
            self.assert_no_deletion()

    def test_process_cleanup_exit_and_terminal_flags_rejected_before_delete(self):
        original=copy.deepcopy(self.phase)
        required=['termination_observed','leader_reaped','cleanup_verified','cleanup_no_observed_live_descendants',
                  'cleanup_process_group_absent','owned_child_listing_available','owned_observation_trusted','signal_handlers_restored']
        mutations=[(key,value) for key in required for value in ['missing',False,1]]
        mutations += [('cleanup_errors',['error']),('cleanup_errors',None),('stop_reason','timeout'),
                      ('exit_code',1),('exit_code',False),('exit_code',None),('log_truncated',True),('log_truncated',0)]
        for key,value in mutations:
            self.phase=copy.deepcopy(original)
            if value == 'missing': del self.phase['process_receipt'][key]
            else: self.phase['process_receipt'][key]=value
            with self.subTest(key=key,value=value), self.assertRaises(ValueError): self.retire()
            self.assert_no_deletion()

    def test_actual_start_and_pid_identity_rejected_before_delete(self):
        original=copy.deepcopy(self.phase)
        mutations=[('phase','pid',value) for value in [None,True,0,-1,124,'123']]
        mutations += [('process','pid',value) for value in [None,True,0,-1,124,'123']]
        mutations += [('process','process_started',value) for value in [None,False,1]]
        for location,key,value in mutations:
            self.phase=copy.deepcopy(original)
            target=self.phase if location == 'phase' else self.phase['process_receipt']
            target[key]=value
            with self.subTest(location=location,key=key,value=value), self.assertRaises(ValueError): self.retire()
            self.assert_no_deletion()

    def test_preexisting_regular_ledger_rejected_before_delete(self):
        ledger=self.work/'retired-inputs.json'; ledger.write_bytes(b'preexisting unique evidence')
        with self.assertRaises(ValueError): self.retire()
        self.assertEqual(ledger.read_bytes(),b'preexisting unique evidence')
        for name,data in self.contents.items(): self.assertEqual((self.work/name).read_bytes(),data)

    def test_preexisting_symlink_ledger_rejected_before_delete(self):
        outside=self.root/'unique-evidence.json'; outside.write_bytes(b'outside unique evidence')
        ledger=self.work/'retired-inputs.json'; ledger.symlink_to(outside)
        with self.assertRaises(ValueError): self.retire()
        self.assertTrue(ledger.is_symlink()); self.assertEqual(outside.read_bytes(),b'outside unique evidence')
        for name,data in self.contents.items(): self.assertEqual((self.work/name).read_bytes(),data)

    def test_rehashed_source_row_cannot_override_manifest(self):
        self.inputs['code/b.dm']={'bytes':7,'sha256':digest(b'changed')}
        (self.work/'code/b.dm').write_bytes(b'changed')
        with self.assertRaises(ValueError): self.retire()
        self.assert_no_deletion()

    def test_tampered_later_target_causes_zero_deletions(self):
        (self.work/'code/b.dm').write_bytes(b'tampered')
        with self.assertRaises(ValueError): self.retire()
        self.assert_no_deletion()

    def test_symlink_target_causes_zero_deletions(self):
        outside=self.root/'outside.dm'; outside.write_bytes(self.contents['code/b.dm'])
        target=self.work/'code/b.dm'; target.unlink(); target.symlink_to(outside)
        with self.assertRaises(ValueError): self.retire()
        self.assert_no_deletion(); self.assertEqual(outside.read_bytes(),self.contents['code/b.dm'])

    def test_hardlinked_target_causes_zero_deletions(self):
        os.link(self.work/'code/b.dm', self.root/'hardlink.dm')
        with self.assertRaises(ValueError): self.retire()
        self.assert_no_deletion()

    def test_unsafe_manifest_path_causes_zero_deletions(self):
        original=copy.deepcopy(self.manifest)
        for name in ['../outside.dm','/tmp/outside.dm','.git/config']:
            self.manifest=dict(original); self.manifest[name]=dict(original['code/a.dm'])
            self.inputs[name]=dict(self.inputs['code/a.dm'])
            with self.subTest(name=name), self.assertRaises(ValueError): self.retire()
            self.assert_no_deletion()

    def test_unlink_failure_retains_precise_partial_ledger_and_unique_evidence(self):
        original_unlink=Path.unlink
        def unlink(path,*args,**kwargs):
            if path == self.work/'code/b.dm': raise OSError('injected retirement failure')
            return original_unlink(path,*args,**kwargs)
        with patch.object(Path,'unlink',unlink), self.assertRaises(OSError): self.retire()
        ledger=json.loads((self.work/'retired-inputs.json').read_text())
        self.assertEqual(ledger['status'],'failed'); self.assertEqual(ledger['retired'],['code/a.dm'])
        self.assertIn('injected retirement failure',ledger['error'])
        self.assertFalse(ledger['unique_evidence_retired'])
        for name,data in self.contents.items():
            if name != 'code/a.dm': self.assertEqual((self.work/name).read_bytes(),data)


if __name__ == '__main__':
    unittest.main(verbosity=2)
