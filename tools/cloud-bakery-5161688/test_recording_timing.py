import json
from pathlib import Path
import unittest
import tempfile
import recording
import test_recording

class RecordingTimingTests(unittest.TestCase):
    def test_slow_rejected_frame_records_exact_schedule(self):
        helper=test_recording.RecordingTests();self.addCleanup(helper.doCleanups)
        root,go,calls,*_=helper.run_fake('slow')
        with self.assertRaisesRegex(RuntimeError,'too slow'):go()
        m=json.loads((root/'recording.json').read_text());t=m['last_attempt_timing']
        self.assertEqual(m['status'],'FAILED_DIAGNOSTIC_ONLY')
        self.assertEqual(t['index'],2);self.assertEqual(t['due_seconds'],.5)
        self.assertEqual(t['begin_seconds'],.5);self.assertEqual(t['end_seconds'],.8)
        self.assertEqual(t['capture_call_seconds'],.3);self.assertEqual(t['end_lateness_seconds'],.3)
        self.assertEqual(len(calls),3)

    def test_only_one_bounded_last_attempt(self):
        helper=test_recording.RecordingTests();self.addCleanup(helper.doCleanups)
        root,go,*_=helper.run_fake();go();m=json.loads((root/'recording.json').read_text())
        self.assertEqual(m['last_attempt_timing']['index'],79)
        self.assertLess((root/'recording.json').stat().st_size,32768)

    def test_native_operations_and_threshold_unchanged(self):
        root=Path(__file__).parent;s=(root/'capture.py').read_text();r=(root/'recording.py').read_text()
        for key in ('native_guards_and_readback','pixel_diagnostics','png_encoding','png_write_fsync'):
            self.assertIn(key,s);self.assertIn(key,r)
        self.assertIn('MAX_LATE = 0.20',r)
        self.assertIn('COUNT, FPS, SIZE = 80, 4, (480, 480)',r)
        self.assertIn('end - due > MAX_LATE',r)
        self.assertIn('math.isfinite(stage[k])',r)

    def stage_case(self, stages):
        with tempfile.TemporaryDirectory() as temp:
            clock=test_recording.FakeClock();clock.value=0
            def capture(*args):
                clock.value=.3
                return {'stage_seconds':stages}
            with self.assertRaisesRegex(RuntimeError,'too slow'):
                recording.record_frames(None,None,Path(temp),'title',lambda:None,lambda:None,
                    capture,clock.now,clock.sleep)
            return json.loads((Path(temp)/'recording.json').read_text())['last_attempt_timing']

    def test_valid_stage_timings_survive_rejection(self):
        stages=dict(native_guards_and_readback=.08,pixel_diagnostics=.2,png_encoding=.01,png_write_fsync=.01)
        self.assertEqual(self.stage_case(stages)['capture_stage_seconds'],stages)

    def test_malformed_or_unbounded_stage_data_omitted(self):
        for stages in ({'private':'text'},None,dict(native_guards_and_readback=float('nan'),pixel_diagnostics=0,png_encoding=0,png_write_fsync=0)):
            self.assertNotIn('capture_stage_seconds',self.stage_case(stages))

if __name__=='__main__':unittest.main()
