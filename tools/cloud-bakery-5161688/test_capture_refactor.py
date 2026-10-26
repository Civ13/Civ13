import importlib.util,tempfile,unittest,sys,inspect
from pathlib import Path
from unittest.mock import patch
import capture
sys.path.insert(0,str(Path(__file__).parent/'tests'))
from test_capture import Adapter,SyntheticScreen
OLD=Path(__file__).parent/'capture_v48_reference_testonly.py'
spec=importlib.util.spec_from_file_location('immutable_v48_capture',OLD);old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old)
class Refactor(unittest.TestCase):
 def test_synchronous_path_pixels_facts_guard_calls_equivalent(self):
  with tempfile.TemporaryDirectory() as d:
   outputs=[]
   for i,module in enumerate((old,capture)):
    a=Adapter();n=SyntheticScreen(a);p=Path(d)/f'{i}.png'
    r=module._capture_with_backend(a,object(),p,'owned',(48,48),n)
    outputs.append((p.read_bytes(),{k:r[k] for k in ('status','identity','window','desktop','activation','checkpoints','pixel_diagnostics','viewport_border','native_counters','cleanup')},n.snapshots,n.exposed_flags,n.cleaned))
   self.assertEqual(outputs[0],outputs[1])
 def test_raw_contains_no_png_and_guard_failure_cannot_escape(self):
  a=Adapter();n=SyntheticScreen(a)
  r=capture._acquire_with_backend(a,object(),'owned',(48,48),n)
  self.assertEqual(r['status'],'OWNED_RAW_UNVALIDATED');self.assertNotIn('png_bytes',r);self.assertTrue(n.cleaned)
  n=SyntheticScreen(a);n.post_capture=lambda:setattr(a,'dead',True)
  with self.assertRaises(Exception):capture._acquire_with_backend(a,object(),'owned',(48,48),n)
 def test_pixel_checks_not_called_during_guarded_raw_acquisition(self):
  a=Adapter();n=SyntheticScreen(a)
  with patch.object(capture,'pixel_diagnostics',side_effect=AssertionError('must be deferred')):
   r=capture._acquire_with_backend(a,object(),'owned',(48,48),n)
  self.assertEqual(r['rgb'],n.result)
 def test_readback_timestamps_bracket_existing_apis_without_reordering(self):
  source=inspect.getsource(capture._WindowsScreen.capture_rgb)
  tokens=['before()', "bitblt_begin_ns=time.perf_counter_ns()", "self._call(self.gdi, 'BitBlt'", "self._call(self.gdi, 'GdiFlush')", 'after()', 'bgra = c.string_at(bits, width * height * 4)', "self.readback_timing['bgra_readback_end_ns'] = time.perf_counter_ns()", 'rgb = bytearray', 'finally:']
  offsets=[source.index(t) for t in tokens];self.assertEqual(offsets,sorted(offsets))
  self.assertEqual(source.count('time.perf_counter_ns()'),2)
 def test_optional_fake_backend_timing_preserved_without_pixels_change(self):
  a=Adapter();n=SyntheticScreen(a)
  timing=dict(clock='perf_counter_ns',bitblt_begin_ns=5000000000000,bgra_readback_end_ns=5000000000001)
  n.readback_timing=timing
  r=capture._acquire_with_backend(a,object(),'owned',(48,48),n)
  self.assertEqual(r['readback_timing'],timing);self.assertEqual(r['rgb'],n.result);self.assertTrue(n.cleaned)
if __name__=='__main__':unittest.main()
