"""Offline synthetic evidence/omission controls. No native process or pixels."""
import importlib.util
import json
from pathlib import Path
import tempfile
import subprocess
import unittest
from unittest.mock import patch

def load(name,file):
    spec=importlib.util.spec_from_file_location(name,Path(__file__).with_name(file))
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module

prepare=load('gate_prepare','prepare.py')
protocol=load('root_gate','protocol.py')
support=load('gate_support','support.py')
HEAD='a'*40

class Gate(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        for module in (prepare.provenance,protocol.provenance):
            mock=patch.object(module,'revision',side_effect=lambda requested,m=module:support.snapshot(m));mock.start();self.addCleanup(mock.stop)
        self.root=Path(self.temp.name)/'stage';prepare.prepare(self.root,HEAD)
        support.fake_compile(self.root,protocol.provenance)
        self.log=self.root/'owned-runtime.log';self.log.write_text('')
        self.binding=protocol.initialize(self.root,HEAD)
        self.gate=protocol.PhaseGate(self.root,HEAD,runtime_logs=[self.log])
    def ack(self,phase,**changes):
        value={k:self.binding[k] for k in ('schema','run','manifest','head','renderer_control')}
        value.update(phase=phase,status='denied' if phase==9 else 'ready',renderer_active=int(phase>1),
            rendered=0 if phase in (1,9) else 3 if phase<5 else 2,shutter=int(phase==9),
            identity_controls={name:1 for name in protocol.IDENTITY_CHECKS})
        value.update(changes);(self.root/('phase-'+str(phase)+'.ready.json')).write_text(json.dumps(value))
    def captures(self):
        for phase in range(1,10):
            self.ack(phase);self.gate.record_pixels(phase,('synthetic map '+str(phase)).encode())
        (self.root/'complete.txt').write_text('COMPLETE\n')
    def test_positive_protocol_requires_all_independent_results(self):
        self.captures();result=self.gate.finish({name:True for name in protocol.PIXEL_CHECKS},cleanup_verified=True)
        self.assertEqual(result['status'],'passed');self.assertEqual(result['head'],HEAD)
    def test_acknowledgments_alone_cannot_pass(self):
        self.ack(9);(self.root/'complete.txt').write_text('COMPLETE')
        with self.assertRaises(protocol.Rejected):self.gate.finish({name:True for name in protocol.PIXEL_CHECKS})
    def test_identical_required_transition_rejected(self):
        for phase in (1,2):self.ack(phase);self.gate.record_pixels(phase,b'same normalized map')
        self.ack(3)
        with self.assertRaisesRegex(protocol.Rejected,'identical'):self.gate.record_pixels(3,b'same normalized map')
    def test_runtime_log_or_sticky_failure_overrides_good_ack(self):
        self.ack(2);self.log.write_text('runtime error: Root admission failed')
        with self.assertRaises(protocol.Rejected):self.gate.phase(2)
        self.log.write_text('');(self.root/'fixture.failed.json').write_text('{}')
        with self.assertRaises(protocol.Rejected):self.gate.phase(2)
    def test_admission_and_native_controls_cannot_be_omitted(self):
        for changes in [{'renderer_active':0},{'rendered':0},{'identity_controls':{}},{'shutter':1}]:
            self.ack(2,**changes)
            with self.assertRaises(protocol.Rejected):self.gate.phase(2)
    def test_stale_or_foreign_source_run_rejected(self):
        for changes in [{'run':'b'*32},{'head':'b'*40},{'manifest':'b'*64},{'schema':1}]:
            self.ack(2,**changes)
            with self.assertRaises(protocol.Rejected):self.gate.phase(2)
    def test_pending_is_not_pass_and_unknown_phase_rejected(self):
        with self.assertRaises(protocol.Pending):self.gate.phase(1)
        with self.assertRaises(protocol.Rejected):self.gate.phase(10)
    def test_phase_seven_and_eight_have_independent_immutable_records(self):
        self.ack(7);self.ack(8)
        self.assertEqual(self.gate.phase(7)['phase'],7);self.assertEqual(self.gate.phase(8)['phase'],8)
    def test_concatenated_records_reject_instead_of_waiting_until_timeout(self):
        self.ack(7);a=(self.root/'phase-7.ready.json').read_bytes()
        self.ack(8);path=self.root/'phase-8.ready.json';path.write_bytes(a+b'\n'+path.read_bytes())
        with self.assertRaisesRegex(protocol.Rejected,'Multiple acknowledgment'):self.gate.phase(8)
    def test_missing_logs_and_changed_compiled_or_source_inputs_rejected(self):
        self.ack(1);self.log.unlink()
        with self.assertRaises(protocol.Rejected):self.gate.phase(1)
        self.log.write_text('');(self.root/'fixture.rsc').write_bytes(b'changed')
        with self.assertRaises(protocol.Rejected):self.gate.input_identity()
        (self.root/'fixture.rsc').write_bytes(b'offline fake resources, never executed')
        (self.root/'fixture.dmb').write_bytes(b'changed')
        with self.assertRaises(protocol.Rejected):self.gate.input_identity()
        (self.root/'fixture.dm').write_text('changed')
        with self.assertRaises(protocol.Rejected):protocol.validate_inputs(self.root,HEAD)
    def test_late_runtime_and_missing_pixel_oracle_prevent_finish(self):
        self.captures()
        with self.assertRaises(protocol.Rejected):self.gate.finish({})
        self.log.write_text('Unhandled exception in native driver')
        with self.assertRaises(protocol.Rejected):self.gate.finish({name:True for name in protocol.PIXEL_CHECKS})
    def test_run_cannot_be_reinitialized_over_retained_evidence(self):
        with self.assertRaises(protocol.Rejected):protocol.initialize(self.root,HEAD)
    def test_negative_runtime_control_never_returns_pass_even_if_hook_omitted(self):
        self.gate.binding['failure_control']='runtime';self.captures()
        with self.assertRaises(protocol.Rejected):self.gate.finish({name:True for name in protocol.PIXEL_CHECKS})
    def test_owned_exit_receipt_is_required_not_assumed_from_job_configuration(self):
        self.captures()
        with self.assertRaisesRegex(protocol.Rejected,'retained process exits'):
            self.gate.finish({name:True for name in protocol.PIXEL_CHECKS})
    def test_wrong_well_formed_head_cannot_initialize(self):
        (self.root/'run.binding.json').unlink()
        with self.assertRaises(protocol.Rejected):protocol.initialize(self.root,'c'*40)
    def test_stale_binary_before_initialize_cannot_be_rehashed_into_pass(self):
        (self.root/'run.binding.json').unlink();(self.root/'fixture.dmb').write_bytes(b'older binary')
        with self.assertRaises(protocol.Rejected):protocol.initialize(self.root,HEAD)
    def test_missing_or_wrong_head_compile_receipt_rejected(self):
        (self.root/'run.binding.json').unlink()
        path=self.root/'compile.receipt.json';receipt=json.loads(path.read_text());receipt['head']='c'*40;path.write_text(json.dumps(receipt))
        with self.assertRaises(protocol.Rejected):protocol.initialize(self.root,HEAD)
        path.unlink()
        with self.assertRaises(protocol.Rejected):protocol.initialize(self.root,HEAD)
    def test_generated_dme_and_dmf_cannot_be_rehashed_in_manifest(self):
        for name in ('fixture.dme','fixture.dmf'):
            original=(self.root/name).read_bytes();manifest=(self.root/'source-manifest.json').read_bytes()
            (self.root/name).write_bytes(original+b'changed')
            metadata=json.loads(manifest);metadata['files'][name]=protocol.provenance.describe((self.root/name).read_bytes())
            (self.root/'source-manifest.json').write_text(json.dumps(metadata))
            with self.assertRaises(protocol.Rejected):self.gate.input_identity()
            (self.root/name).write_bytes(original);(self.root/'source-manifest.json').write_bytes(manifest)
    def test_compile_requires_fresh_outputs(self):
        with self.assertRaises(protocol.provenance.Invalid):protocol.provenance.require_fresh_outputs(self.root)
    def test_receipt_input_binding_and_owned_exit_audit_required(self):
        path=self.root/'compile.receipt.json';original=path.read_bytes();receipt=json.loads(original)
        receipt['input_binding']['files']['fixture.dm']['sha256']='c'*64;path.write_text(json.dumps(receipt))
        with self.assertRaises(protocol.provenance.Invalid):protocol.provenance.validate_compile(self.root,HEAD)
        path.write_bytes(original);receipt=json.loads(original)
        audit_path=self.root/'compile-supervisor.json';audit=json.loads(audit_path.read_text())
        audit['phases'][0]['cleanup']['all_retained_exited']=False;raw=json.dumps(audit).encode();audit_path.write_bytes(raw)
        receipt['supervisor_sha256']=protocol.digest(raw);path.write_text(json.dumps(receipt))
        with self.assertRaises(protocol.provenance.Invalid):protocol.provenance.validate_compile(self.root,HEAD)
    def test_approved_session_file_requires_explicit_opt_in_and_is_hash_bound(self):
        (self.root/'run.binding.json').unlink();identity=self.root/'authorized-identity.txt';identity.write_text('fixtureuser')
        with self.assertRaises(protocol.Rejected):protocol.initialize(self.root,HEAD)
        binding=protocol.initialize(self.root,HEAD,authorized_session=True)
        self.assertTrue(binding['authorized_session']);self.assertNotIn('fixtureuser',json.dumps(binding))
        accepted=protocol.PhaseGate(self.root,HEAD,runtime_logs=[self.log]);accepted.healthy()
        identity.write_text('anotheruser')
        with self.assertRaises(protocol.Rejected):accepted.healthy()

    def renderer_stage(self,control):
        self.root=Path(self.temp.name)/control;prepare.prepare(self.root,HEAD,renderer_control=control)
        support.fake_compile(self.root,protocol.provenance)
        self.log=self.root/'owned-runtime.log';self.log.write_text('')
        self.binding=protocol.initialize(self.root,HEAD)
        self.gate=protocol.PhaseGate(self.root,HEAD,runtime_logs=[self.log])

    def test_renderer_controls_have_distinct_binding_counts_and_cannot_pass_acceptance(self):
        for control,target in [('neighbor',3),('visibility',2)]:
            self.renderer_stage(control)
            for phase in range(1,target+1):
                self.ack(phase,rendered=0 if phase==1 else 4 if control=='visibility' else 3)
                self.gate.record_pixels(phase,('synthetic control map '+str(phase)).encode())
            with self.assertRaises(protocol.Rejected):self.gate.renderer_control_result(oracle_passed=True,cleanup_verified=True)
            with self.assertRaises(protocol.Rejected):self.gate.renderer_control_result(oracle_passed=False)
            result=self.gate.renderer_control_result(oracle_passed=False,cleanup_verified=True)
            self.assertEqual(result['status'],'control_detected');self.assertIs(result['acceptance'],False)
            self.assertEqual(result['failed_oracle'],'negative_'+control)
            self.ack(9)
            with self.assertRaisesRegex(protocol.Rejected,'never pass'):self.gate.finish({})

    def test_renderer_control_cannot_be_combined_relabelled_or_omitted_from_ack(self):
        self.renderer_stage('visibility');self.ack(2,rendered=4,renderer_control=None)
        with self.assertRaises(protocol.Rejected):self.gate.phase(2)
        self.ack(2,rendered=3)
        with self.assertRaises(protocol.Rejected):self.gate.phase(2)
        self.gate.binding['renderer_control']=None
        with self.assertRaises(protocol.Rejected):self.gate.input_identity()
        (self.root/'run.binding.json').unlink()
        with self.assertRaisesRegex(protocol.Rejected,'one control'):protocol.initialize(self.root,HEAD,failure_control='runtime')

    def failure_stage(self,control):
        self.root=Path(self.temp.name)/control;prepare.prepare(self.root,HEAD)
        support.fake_compile(self.root,protocol.provenance)
        self.log=self.root/'owned-runtime.log';self.log.write_text('runtime error: Injected fixture runtime control' if control=='runtime' else '')
        self.binding=protocol.initialize(self.root,HEAD,failure_control=control)
        self.gate=protocol.PhaseGate(self.root,HEAD,runtime_logs=[self.log]);self.ack(1)
        failure=dict(schema=2,run=self.binding['run'],status='failed',reason='native_runtime' if control=='runtime' else 'root_admission')
        (self.root/'fixture.failed.json').write_text(json.dumps(failure))

    def test_expected_failure_controls_require_actual_bound_failure_and_cleanup(self):
        for control in ('runtime','admission'):
            self.failure_stage(control)
            with self.assertRaises(protocol.Rejected):self.gate.phase(2)
            with self.assertRaises(protocol.Rejected):self.gate.failure_control_result()
            result=self.gate.failure_control_result(cleanup_verified=True)
            self.assertEqual(result['status'],'control_detected');self.assertIs(result['acceptance'],False)
            self.assertEqual(result['failure_control'],control)
            self.ack(2)
            with self.assertRaises(protocol.Rejected):self.gate.failure_control_result(cleanup_verified=True)
            (self.root/'phase-2.ready.json').unlink()
            (self.root/'fixture.failed.json').unlink()
            with self.assertRaises(protocol.Rejected):self.gate.failure_control_result(cleanup_verified=True)

    def test_wrong_failure_or_missing_runtime_diagnostic_is_not_expected_control(self):
        self.failure_stage('runtime');path=self.root/'fixture.failed.json';failure=json.loads(path.read_text())
        for change in ({'run':'foreign'},{'reason':'root_admission'},{'status':'ready'}):
            path.write_text(json.dumps({**failure,**change}))
            with self.assertRaises(protocol.Rejected):self.gate.failure_control_result(cleanup_verified=True)
        path.write_text(json.dumps(failure));self.log.write_text('')
        with self.assertRaisesRegex(protocol.Rejected,'runtime diagnostic'):self.gate.failure_control_result(cleanup_verified=True)

    def test_normal_run_cannot_be_reported_as_an_expected_control(self):
        with self.assertRaises(protocol.Rejected):self.gate.renderer_control_result(oracle_passed=False,cleanup_verified=True)
        with self.assertRaises(protocol.Rejected):self.gate.failure_control_result(cleanup_verified=True)

class CurrentRevision(unittest.TestCase):
    """Fresh local repositories, no fixed historical objects or network access."""
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)
        for name,data in support.snapshot(protocol.provenance)['sources'].items():
            path=self.root/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
        def git(*args):return subprocess.check_output(['git',*args],cwd=self.root,stderr=subprocess.PIPE).decode().strip()
        self.git=git;git('init','--quiet');git('add','--','.')
        git('-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','--quiet','-m','Current source fixture')
        self.head=git('rev-parse','HEAD')
    def test_exact_current_git_objects_and_wrong_head(self):
        state=protocol.provenance.revision(self.head,self.root)
        self.assertEqual(state['head'],self.head)
        self.assertEqual(set(state['sources']),set(protocol.provenance.SOURCES))
        with self.assertRaises(protocol.provenance.Invalid):protocol.provenance.revision('0'*40,self.root)
    def test_dirty_current_inputs_are_not_labeled_committed(self):
        with (self.root/'tests/root_tree_presentation/fixture.dm').open('a') as stream:stream.write('\n// dirty\n')
        with self.assertRaises(protocol.provenance.Invalid):protocol.provenance.revision(self.head,self.root)

if __name__=='__main__':unittest.main()
