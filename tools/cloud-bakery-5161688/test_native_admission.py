"""Offline V49 activation/scope checks; never executes native entrypoints."""
import ast,json,hashlib,unittest
from pathlib import Path
from activation import check
R=Path(__file__).parent
class NativeAdmission(unittest.TestCase):
 def test_manifest_and_three_native_flags_exact(self):
  a=check();self.assertEqual(a['branch'],'ci/cloud-native-cadence-5161688-v50-20261026');self.assertEqual(a['run_attempt'],1)
  for name,flag in [('run_scene.py','CADENCE_NATIVE_RELEASED'),('deferred_recording.py','NATIVE_RELEASED')]:
   values=[n.value.value for n in ast.parse((R/name).read_text(encoding='utf-8')).body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id==flag for t in n.targets)]
   self.assertEqual(values,[True])
  self.assertEqual((R/'changed-source/filming/scene.dm').read_text(encoding='utf-8').count('#define FILMING_NATIVE_RELEASED TRUE'),1)
 def test_workflow_retains_caps_and_has_no_export(self):
  w=(R.parents[1]/'.github/workflows/cloud-bakery-5161688.yml').read_text(encoding='utf-8')
  self.assertLess(w.index('verify_diagnostic.py'),w.index('Offline acquisition'))
  self.assertIn('0..19',w);self.assertIn('cadence-recording.json',w);self.assertNotIn('0..79',w)
  for bound in ('-gt 100','-gt 16777216','-gt 1048576'):self.assertIn(bound,w)
  for forbidden in ('local_encode.py','ffmpeg','encode_local.py --','landscape'):self.assertNotIn(forbidden,w)
 def test_original_reference_and_production_revision_retained(self):
  self.assertEqual(hashlib.sha256((R/'capture_v48_reference_testonly.py').read_bytes()).hexdigest(),'fb4ae1b15eecb3c7bd0ce556c1a13725f054f6ad82ac62582ef38b3adb2caa51')
  scene=(R/'run_scene.py').read_text(encoding='utf-8')
  for token in ("wait_file('filming-take.json')","'PASS_NATIVE_CADENCE_DIAGNOSTIC'",'terminal = checkpoint(result, output)'):self.assertIn(token,scene)
  self.assertIn('9683866a89d2bdc12f8dc7d25444e350583c5483',(R/'tree-source-contract.json').read_text(encoding='utf-8'))
if __name__=='__main__':unittest.main()
