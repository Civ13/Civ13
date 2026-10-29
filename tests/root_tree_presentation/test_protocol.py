"""Offline synthetic evidence/omission controls. No native process or pixels."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

def load(name,file):
    spec=importlib.util.spec_from_file_location(name,Path(__file__).with_name(file))
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module

prepare=load('gate_prepare','prepare.py')
protocol=load('root_gate','protocol.py')
HEAD='a'*40

class Gate(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)/'stage';prepare.prepare(self.root)
        (self.root/'fixture.dmb').write_bytes(b'offline fake compiled content, never executed')
        (self.root/'fixture.rsc').write_bytes(b'offline fake resources, never executed')
        self.log=self.root/'owned-runtime.log';self.log.write_text('')
        self.binding=protocol.initialize(self.root,HEAD)
        self.gate=protocol.PhaseGate(self.root,HEAD,runtime_logs=[self.log])
    def ack(self,phase,**changes):
        value={k:self.binding[k] for k in ('schema','run','manifest','head')}
        value.update(phase=phase,status='denied' if phase==9 else 'ready',renderer_active=int(phase>1),
            rendered=0 if phase in (1,9) else 3 if phase<5 else 2,shutter=int(phase==9),
            identity_controls={name:1 for name in protocol.IDENTITY_CHECKS})
        value.update(changes);(self.root/'phase.ready.json').write_text(json.dumps(value))
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
    def test_missing_logs_and_changed_compiled_or_source_inputs_rejected(self):
        self.ack(1);self.log.unlink()
        with self.assertRaises(protocol.Rejected):self.gate.phase(1)
        self.log.write_text('');(self.root/'fixture.rsc').write_bytes(b'changed')
        with self.assertRaises(protocol.Rejected):self.gate.input_identity()
        (self.root/'fixture.rsc').write_bytes(b'offline fake resources, never executed')
        (self.root/'fixture.dmb').write_bytes(b'changed')
        with self.assertRaises(protocol.Rejected):self.gate.input_identity()
        (self.root/'fixture.dm').write_text('changed')
        with self.assertRaises(protocol.Rejected):protocol.validate_inputs(self.root)
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

if __name__=='__main__':unittest.main()
