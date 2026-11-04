"""Synthetic readiness timing; no Windows calls or capture."""
import sys,unittest
from pathlib import Path
from types import SimpleNamespace
sys.path.insert(0,str(Path(__file__).parent/'tests'))
from test_capture import Adapter,SyntheticScreen,capture
class Readiness(unittest.TestCase):
 def run_case(self,mode):
  a=Adapter();n=SyntheticScreen(a);clock=[0.0];attempts=[];watches=[]
  def select(pid,title):
   attempts.append(clock[0])
   if mode=='multiple':raise capture.CaptureError('Multiple visible owned windows; no prompt interaction')
   if mode=='title':raise capture.CaptureError('Owned HWND lacks the exact expected scene title')
   if mode=='stale':a.dead=True
   if mode=='malformed':raise capture.OwnedWindowUnavailable(123,1,[])
   if mode=='ready' and len(attempts)==3:return 567
   raise capture.OwnedWindowUnavailable(123,0,[])
  n.select_owned=select
  def watch():
   watches.append(1)
   if mode=='watch':raise capture.CaptureError('scene budget or network failure')
  def go():return capture._wait_owned_with_backend(a,SimpleNamespace(pid=123),'title',watch,n,lambda:clock[0],lambda t:clock.__setitem__(0,clock[0]+t))
  return go,n,clock,attempts,watches
 def test_zero_then_ready_without_capture_or_activation(self):
  go,n,clock,attempts,watches=self.run_case('ready');r=go()
  self.assertEqual(r['attempts'],3);self.assertEqual(r['elapsed_seconds'],.5)
  self.assertTrue(n.cleaned);self.assertEqual(n.snapshots,0);self.assertEqual(n.counters['bitblt'],0);self.assertEqual(n.counters['activation_attempts'],0)
 def test_permanent_zero_bound_preserves_failure(self):
  go,n,clock,attempts,watches=self.run_case('zero')
  with self.assertRaises(capture.OwnedWindowUnavailable) as got:go()
  self.assertEqual(len(attempts),20);self.assertEqual(clock[0],5)
  self.assertEqual(got.exception.evidence['readiness'],dict(attempts=20,elapsed_seconds=5,limit_seconds=5));self.assertTrue(n.cleaned)
 def test_multiple_title_and_malformed_fail_immediately(self):
  for mode in ['multiple','title','malformed']:
   go,n,clock,attempts,watches=self.run_case(mode)
   with self.assertRaises(capture.CaptureError):go()
   self.assertEqual(len(attempts),1);self.assertEqual(clock[0],0);self.assertTrue(n.cleaned)
 def test_identity_change_never_waits(self):
  go,n,clock,attempts,watches=self.run_case('stale')
  with self.assertRaises(capture.CaptureError) as got:go()
  self.assertNotIsInstance(got.exception,capture.OwnedWindowUnavailable);self.assertEqual(clock[0],0);self.assertEqual(len(attempts),1)
 def test_shared_watcher_failure_immediate(self):
  go,n,clock,attempts,watches=self.run_case('watch')
  with self.assertRaisesRegex(capture.CaptureError,'budget or network'):go()
  self.assertEqual(attempts,[]);self.assertTrue(n.cleaned)
 def test_hwnd_admission_rejects_changed_or_unbound_window(self):
  for hwnd in (None,999):
   a=Adapter();n=SyntheticScreen(a)
   process=SimpleNamespace(pid=123,expected_hwnd=hwnd)
   with self.assertRaisesRegex(capture.CaptureError,'explicit admission'):
    capture._acquire_with_backend(a,process,'title',(48,48),n)
   self.assertEqual(n.counters['bitblt'],0)

if __name__=='__main__':unittest.main()
