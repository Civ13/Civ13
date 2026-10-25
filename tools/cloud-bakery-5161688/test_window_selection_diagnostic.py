import json,tempfile,sys
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock
import unittest
sys.path.insert(0,str(Path(__file__).parent/'tests'))
from test_capture import Adapter,SyntheticScreen,capture
class WindowDiagnostic(unittest.TestCase):
 def test_bounded_owned_only_schema(self):
  rows=[dict(hwnd=i+1,pid=123,thread_id=124,visible=False) for i in range(4)]
  e=capture.OwnedWindowUnavailable(123,20,rows)
  self.assertEqual(len(e.evidence['owned_rows']),4);self.assertTrue(e.evidence['rows_truncated'])
  self.assertLess(len(json.dumps(e.evidence)),1024)
  self.assertEqual(capture.OwnedWindowUnavailable(123,0,[]).evidence['owned_top_level_count'],0)
 def test_malformed_metadata_omitted(self):
  for pid,count,rows in [(False,0,[]),(123,513,[]),(123,1,[]),(123,1,[dict(hwnd=1,pid=123,thread_id=124,visible=True)]),(123,1,[dict(hwnd=1,pid=123,thread_id=124,visible=False,title='private')])]:
   self.assertIsNone(capture.OwnedWindowUnavailable(pid,count,rows).evidence)
 def screen(self,owners):
  n=object.__new__(capture._WindowsScreen);n.user=object();n.callback_type=lambda f:f;n._owned_title=Mock();n._require=lambda x,m:None if x else (_ for _ in ()).throw(capture.CaptureError(m));calls=[]
  n._owner=lambda hwnd:owners[hwnd][:2]
  def api(lib,name,*args):
   calls.append(name)
   if name=='EnumWindows':
    for hwnd in owners:
     if not args[0](hwnd,0):return 0
    return 1
   if name=='IsWindowVisible':return owners[args[0]][2]
   raise AssertionError(name)
  n._call=api;return n,calls
 def test_existing_queries_only_and_no_unowned_visibility(self):
  n,calls=self.screen({1:(999,8,True),2:(123,124,False)})
  with self.assertRaises(capture.OwnedWindowUnavailable) as got:n.select_owned(123,'title')
  self.assertEqual(got.exception.evidence['owned_rows'],[dict(hwnd=2,pid=123,thread_id=124,visible=False)])
  self.assertEqual(calls,['EnumWindows','IsWindowVisible']);n._owned_title.assert_not_called()
 def test_one_visible_and_multiple_rejection_unchanged(self):
  n,calls=self.screen({1:(123,124,False),2:(123,124,True)})
  self.assertEqual(n.select_owned(123,'title'),2);n._owned_title.assert_called_once_with(2,123,'title')
  n,calls=self.screen({1:(123,124,True),2:(123,124,True),3:(123,124,False)})
  with self.assertRaisesRegex(capture.CaptureError,'Multiple visible'):n.select_owned(123,'title')
  self.assertEqual(calls,['EnumWindows','IsWindowVisible','IsWindowVisible'])
 def failure(self,stale=False,cleanup_error=False):
  a=Adapter();n=SyntheticScreen(a);n.cleanup_error=cleanup_error
  def fail(*args):
   if stale:a.dead=True
   raise capture.OwnedWindowUnavailable(123,0,[])
  n.select_owned=fail
  with tempfile.TemporaryDirectory() as t:
   path=Path(t)/'frame.png'
   with self.assertRaises(capture.CaptureError) as caught:capture._capture_with_backend(a,SimpleNamespace(pid=123),path,'title',(48,48),n)
   self.assertFalse(path.exists());self.assertTrue(n.cleaned);self.assertEqual(n.snapshots,0);self.assertEqual(n.counters['bitblt'],0);self.assertEqual(n.counters['activation_attempts'],0)
   return caught.exception
 def test_same_failure_after_identity_recheck_and_cleanup(self):
  e=self.failure();self.assertIsInstance(e,capture.OwnedWindowUnavailable);self.assertTrue(e.evidence['process_identity_revalidated']);self.assertEqual(e.evidence['creation_filetime'],123456)
 def test_stale_identity_or_cleanup_error_drops_diagnostic(self):
  self.assertNotIsInstance(self.failure(stale=True),capture.OwnedWindowUnavailable)
  self.assertEqual(str(self.failure(cleanup_error=True)),'Synthetic cleanup failure')
 def test_no_poll_retry_or_extra_window_api(self):
  s=Path(capture.__file__).read_text();body=s.split('    def select_owned(')[1].split('    def activate_owned')[0]
  self.assertNotIn('sleep(',body);self.assertNotIn('GetWindowText',body);self.assertNotIn('GetClass',body)
  c=(Path(__file__).parent/'run_scene.py').read_text();self.assertIn("result['owned_window_unavailable'] = error.evidence",c)
  self.assertIn('first_frame_ready_at = time.monotonic() + 2',c)
if __name__=='__main__':unittest.main()
