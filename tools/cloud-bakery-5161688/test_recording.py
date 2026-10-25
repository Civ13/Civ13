import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import recording as R

class FakeClock:
    value = 0.0
    def now(self): return self.value
    def sleep(self, seconds): self.value += seconds

class RecordingTests(unittest.TestCase):
    def run_fake(self, mode=None):
        temp = tempfile.TemporaryDirectory(); self.addCleanup(temp.cleanup)
        root = Path(temp.name); clock = FakeClock(); calls=[]; watches=[]; starts=[]
        def capture(a,p,path,title,size):
            i=len(calls);calls.append(i)
            if mode=='failure' and i==2: raise RuntimeError('owned guard failed')
            if mode=='slow' and i==2: clock.value += .3
            data=b'frame' + str(i if mode!='flat' else 0).encode();path.write_bytes(data)
            return dict(status='captured',viewport_border=dict(schema=1,width=480,height=480,border_pixels=32,pixels_per_strip=15360,reject_at_black_pixels=14592,top_black_pixels=0,bottom_black_pixels=0,left_black_pixels=0,right_black_pixels=0,accepted=True),identity=dict(pid=1,creation_filetime=2),
                window=dict(hwnd=4 if mode=='identity' and i==2 else 3,client_rect=[0,0,480,480]),
                width=480,height=480,png_bytes=len(data),png_sha256=hashlib.sha256(data).hexdigest(),
                checkpoints=['immediately_before_bitblt','immediately_after_bitblt'])
        def go(): return R.record_frames(None,None,root,'title',lambda:watches.append(1),
            lambda:starts.append(len(calls)),capture,clock.now,clock.sleep)
        return root,go,calls,watches,starts

    def test_exact_80_genuine_frames_20_seconds(self):
        root,go,calls,watches,starts=self.run_fake();result=go()
        self.assertEqual(len(calls),80);self.assertEqual(starts,[1]);self.assertGreaterEqual(len(watches),160)
        self.assertEqual(result['playback_seconds'],20)
        manifest=json.loads((root/'recording.json').read_text())
        self.assertEqual(manifest['frames'][-1]['begin_seconds'],19.75)
        self.assertEqual(len(list(root.glob('recording-*.png'))),80)
        self.assertLess((root/'recording.json').stat().st_size,32768)

    def test_guard_failure_stops_and_marks_partial_diagnostic(self):
        root,go,calls,*_=self.run_fake('failure')
        with self.assertRaisesRegex(RuntimeError,'owned guard'):go()
        self.assertEqual(len(calls),3)
        self.assertEqual(json.loads((root/'recording.json').read_text())['status'],'FAILED_DIAGNOSTIC_ONLY')

    def test_slow_capture_does_not_duplicate_or_catch_up(self):
        root,go,calls,*_=self.run_fake('slow')
        with self.assertRaisesRegex(RuntimeError,'too slow'):go()
        self.assertEqual(len(calls),3)

    def test_owned_identity_change_rejected(self):
        _,go,calls,*_=self.run_fake('identity')
        with self.assertRaisesRegex(RuntimeError,'identity'):go()
        self.assertEqual(len(calls),3)

    def test_unchanged_frames_not_accepted(self):
        _,go,*_=self.run_fake('flat')
        with self.assertRaisesRegex(RuntimeError,'no observed change'):go()

    def test_no_overwrite(self):
        root,go,calls,*_=self.run_fake();(root/'recording-000.png').write_bytes(b'existing')
        with self.assertRaisesRegex(RuntimeError,'Fresh'):go()
        self.assertEqual(calls,[])

    def test_payload_cap_removes_crossing_frame_and_stops(self):
        root,go,calls,*_=self.run_fake()
        with patch.object(R,'MAX_FRAME_TOTAL',10):
            with self.assertRaisesRegex(RuntimeError,'byte cap'):go()
        self.assertEqual(len(calls),2)
        self.assertFalse((root/'recording-001.png').exists())
        self.assertEqual(len(list(root.glob('recording-*.png'))),1)

    def test_existing_watch_failure_aborts_without_capture(self):
        temp=tempfile.TemporaryDirectory();self.addCleanup(temp.cleanup);root=Path(temp.name)
        def watch():raise RuntimeError('shared safety budget')
        def capture(*args):self.fail('must not capture after watch failure')
        with self.assertRaisesRegex(RuntimeError,'shared safety budget'):
            R.record_frames(None,None,root,'title',watch,lambda:None,capture)
        self.assertEqual(json.loads((root/'recording.json').read_text())['frames'],[])

    def test_fixed_artifact_caps_and_no_encoder_on_runner(self):
        root=Path(__file__).parent
        workflow=(root.parents[1]/'.github/workflows/cloud-bakery-5161688.yml').read_text()
        for token in ('0..79','$files.Count -gt 100','$total -gt 16777216','$file.Length -gt 1048576'):
            self.assertIn(token,workflow)
        self.assertNotIn('ffmpeg',workflow.lower())
        controller=(root/'run_scene.py').read_text()
        self.assertIn("require((source/'filming-take.json').is_file()",controller)
        self.assertLess(controller.index('record_frames(client'),controller.index("result['status'] = 'PASS_NATIVE_CIV13_TANNING_FRAMES'"))

if __name__=='__main__':unittest.main()
