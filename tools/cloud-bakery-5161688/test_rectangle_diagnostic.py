"""Bounded owned-window metadata; no native APIs or image capture executed."""
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import Mock
import capture
sys.path.insert(0, str(Path(__file__).parent/'tests'))
from test_capture import Adapter, SyntheticScreen, capture
from types import SimpleNamespace
import tempfile

class RectangleDiagnostic(unittest.TestCase):
    def test_schema_numeric_bounded_no_content(self):
        e=capture.OwnedRectangleMismatch(567,123,124,(0,0,464,441),(0,0,480,480))
        self.assertEqual(str(e),'Owned client must match the exact map-only dimensions')
        self.assertEqual(set(e.evidence), {'schema','hwnd','pid','thread_id','actual_client_rect','expected_client_rect','capture_thread_dpi_context','process_identity_revalidated'})
        self.assertLess(len(json.dumps(e.evidence)),512)

    def test_malformed_metadata_is_not_retained(self):
        for rect in (None,[],[0,0,2**32,1],[False,0,1,1],['private',0,1,1]):
            self.assertIsNone(capture.OwnedRectangleMismatch(567,123,124,rect,(0,0,480,480)).evidence)
        for pid in (False,0,-1,2**32):
            self.assertIsNone(capture.OwnedRectangleMismatch(567,pid,124,(0,0,1,1),(0,0,480,480)).evidence)

    def run_failure(self, stale=False, cleanup_error=False):
        a=Adapter();n=SyntheticScreen(a);n.cleanup_error=cleanup_error
        def mismatch(*args,**kwargs):
            if stale: a.dead=True
            raise capture.OwnedRectangleMismatch(567,123,124,(0,0,464,441),(0,0,48,48))
        n.window_snapshot=mismatch
        with tempfile.TemporaryDirectory() as t:
            p=Path(t)/'frame.png'
            with self.assertRaises(capture.CaptureError) as caught:
                capture._capture_with_backend(a,SimpleNamespace(pid=123),p,capture.DEFAULT_TITLE,(48,48),n)
            self.assertFalse(p.exists());self.assertTrue(n.cleaned)
            self.assertEqual(n.counters,dict(bitblt=0,activation_attempts=0))
            return caught.exception

    def test_same_rejection_cleanup_without_activation_or_pixels(self):
        e=self.run_failure();self.assertIsInstance(e,capture.OwnedRectangleMismatch)
        self.assertTrue(e.evidence['process_identity_revalidated'])
        self.assertEqual(e.evidence['creation_filetime'],Adapter().binding['creation_filetime'])

    def test_stale_identity_suppresses_metadata(self):
        self.assertNotIsInstance(self.run_failure(stale=True),capture.OwnedRectangleMismatch)

    def test_cleanup_failure_not_hidden(self):
        self.assertEqual(str(self.run_failure(cleanup_error=True)),'Synthetic cleanup failure')

    def test_native_rectangle_branch_rechecks_same_owner_before_rejection(self):
        n=object.__new__(capture._WindowsScreen);n.user=object();n._owned_title=Mock();n._object_name=Mock(return_value='Default');n._owner=Mock(return_value=(123,124))
        calls=[]
        def api(lib,name,*args,**kw):
            calls.append(name)
            if name=='IsIconic':return 0
            if name=='GetAncestor':return 567
            if name=='GetClientRect':
                r=capture.c.cast(args[1],capture.c.POINTER(capture._RECT)).contents
                r.left=0;r.top=0;r.right=464;r.bottom=441
            return 1
        n._call=api
        n.owned_child_geometry=Mock(return_value=[])
        with self.assertRaises(capture.OwnedRectangleMismatch) as caught:
            n.window_snapshot(567,123,capture.DEFAULT_TITLE,(480,480),require_exposed=False)
        self.assertEqual(caught.exception.evidence['actual_client_rect'],[0,0,464,441])
        self.assertEqual(n._owner.call_count,2)
        self.assertNotIn('GetDC',calls);self.assertNotIn('ClientToScreen',calls)
        n.owned_child_geometry=Mock(side_effect=capture.CaptureError('synthetic diagnostic denial'))
        with self.assertRaises(capture.OwnedRectangleMismatch) as unavailable:
            n.window_snapshot(567,123,capture.DEFAULT_TITLE,(480,480),require_exposed=False)
        self.assertEqual(unavailable.exception.evidence['child_geometry_status'],'unavailable')
        self.assertNotIn('direct_children',unavailable.exception.evidence)
        n._owner=Mock(side_effect=[(123,124),(999,124)])
        with self.assertRaises(capture.CaptureError) as caught:
            n.window_snapshot(567,123,capture.DEFAULT_TITLE,(480,480),require_exposed=False)
        self.assertNotIsInstance(caught.exception,capture.OwnedRectangleMismatch)

    def test_controller_only_retains_revalidated_exception(self):
        s=(Path(__file__).parent/'run_scene.py').read_text()
        self.assertIn("error.evidence.get('process_identity_revalidated') is True",s)
        self.assertIn("result['owned_rectangle_mismatch'] = error.evidence",s)

if __name__=='__main__':unittest.main()
