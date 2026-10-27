"""Synthetic failed-frame proof: no actual screenshots/native execution."""
from pathlib import Path
import hashlib
import sys
import tempfile
import unittest
from types import SimpleNamespace
sys.path.insert(0,str(Path(__file__).parent/'tests'))
from test_capture import Adapter,SyntheticScreen,capture

class FailedFrameTests(unittest.TestCase):
    def fixture(self):
        a=Adapter();n=SyntheticScreen(a)
        n.rectangle=[30,40,510,520];n.result=bytes(480*480*3)
        return a,n

    def run_capture(self,a,n,path):
        return capture._capture_with_backend(a,SimpleNamespace(pid=123),path,capture.DEFAULT_TITLE,(480,480),n)

    def test_black_diagnostic_only_after_complete_guards_cleanup(self):
        a,n=self.fixture()
        with tempfile.TemporaryDirectory() as t:
            p=Path(t)/'bakery-before.png'
            with self.assertRaises(capture.PixelHeuristicFailure) as caught:self.run_capture(a,n,p)
            e=caught.exception;d=e.diagnostic
            self.assertFalse(p.exists());self.assertTrue(n.cleaned)
            self.assertEqual(n.counters['bitblt'],1)
            self.assertEqual(d['checkpoints'],['immediately_before_bitblt','immediately_after_bitblt'])
            self.assertFalse(d['accepted']);self.assertEqual(d['status'],'FAILED_HEURISTIC_DIAGNOSTIC_ONLY')
            f=Path(t)/d['filename'];self.assertTrue(f.name.endswith('.failed-diagnostic.png'))
            self.assertEqual(hashlib.sha256(f.read_bytes()).hexdigest(),d['png_sha256'])
            self.assertLess(f.stat().st_size,1048576)
            self.assertTrue(e.facts['entirely_black']);self.assertTrue(e.facts['flat_rgb'])
            self.assertEqual(e.facts['nonzero_pixel_count'],0)
            self.assertEqual(e.facts['channel_min'],e.facts['channel_max'])

    def test_nonblack_flat_not_mislabeled_black(self):
        with self.assertRaises(capture.PixelHeuristicFailure) as caught:
            capture.pixel_diagnostics(b'\xff\xff\xff'*(480*480),480,480)
        f=caught.exception.facts;self.assertFalse(f['entirely_black']);self.assertTrue(f['flat_rgb'])
        self.assertEqual(f['nonzero_pixel_count'],480*480);self.assertEqual(f['channel_min'],255)

    def test_unsafe_or_cleanup_failure_writes_nothing(self):
        for mutation in ('foreground_error','cleanup_error','dead_after'):
            a,n=self.fixture()
            if mutation=='dead_after':n.post_capture=lambda:setattr(a,'dead',True)
            else:setattr(n,mutation,True)
            with self.subTest(mutation=mutation),tempfile.TemporaryDirectory() as t:
                with self.assertRaises(capture.CaptureError):self.run_capture(a,n,Path(t)/'bakery-before.png')
                self.assertEqual(list(Path(t).iterdir()),[])

    def test_no_overwrite_of_existing_diagnostic(self):
        a,n=self.fixture()
        with tempfile.TemporaryDirectory() as t:
            p=Path(t)/'bakery-before.failed-diagnostic.png';p.write_bytes(b'prior')
            with self.assertRaises(FileExistsError):self.run_capture(a,n,Path(t)/'bakery-before.png')
            self.assertEqual(p.read_bytes(),b'prior')

    def test_other_destination_never_exports_failed_pixels(self):
        a,n=self.fixture()
        with tempfile.TemporaryDirectory() as t:
            with self.assertRaises(capture.PixelHeuristicFailure) as caught:self.run_capture(a,n,Path(t)/'other.png')
            self.assertIsNone(caught.exception.diagnostic);self.assertEqual(list(Path(t).iterdir()),[])

    def test_receipt_and_upload_remain_failure_bounded(self):
        root=Path(__file__).parent;s=(root/'run_scene.py').read_text()
        self.assertIn("result['failed_frame_diagnostic'] = error.diagnostic",s)
        self.assertIn('render_readiness_proven=False',s)
        self.assertIn("'status': 'FAILED'",s)
        w=(root.parent.parent/'.github/workflows/cloud-lighting-5161688.yml').read_text()
        self.assertIn("'bakery-before.failed-diagnostic.png'",w)
        self.assertIn('$files.Count -gt 100',w);self.assertIn('$file.Length -gt 1048576',w)

if __name__=='__main__':unittest.main()
