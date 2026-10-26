from pathlib import Path
import unittest
S=Path(__file__).with_name('run_scene.py').read_text(encoding='utf-8')
class PersistenceOrder(unittest.TestCase):
 def test_cleanup_precedes_checkpoint_optional_diagnostics_follow(self):
  b=S[S.index('    finally:'):]
  self.assertLess(b.index("result['cleanup'].append"),b.index('terminal = checkpoint(result, output)'))
  self.assertLess(b.index('terminal = checkpoint(result, output)'),b.index('from owned_crash import collect'))
  self.assertIn("result['status'] = 'FAILED_POST_CLEANUP_DIAGNOSTICS'",b)
  self.assertIn('finally:\n            result = finalize(',b)
  self.assertNotIn('json.dumps(result, indent=2)',b)
  self.assertIn("'PASS_NATIVE_CADENCE_DIAGNOSTIC', started=started)",b)
 def test_new_helper_is_bound_without_replacing_source_pins(self):
  s=Path(__file__).with_name('encode_local.py').read_text(encoding='utf-8')
  for name in ('capture.py','run_scene.py','recording.py','encode_local.py','viewport_border.py','receipt_persistence.py'):
   self.assertIn(repr(name),s)
  self.assertIn("receipt.get('persistence_complete') is True",s)
  # The new encoder planner remains local-only, outside this native controller.
  # Runtime source closure hashes every actual Python tool, including the new path.
  self.assertIn("'execution_source_sha256': {p.name: digest(p) for p in Path(__file__).parent.glob('*.py')}",S)
  for name in ('deferred_recording.py','cadence_schema.py','run_scene.py','capture.py','receipt_persistence.py'):
   self.assertTrue(Path(__file__).with_name(name).is_file(),name)
  self.assertIn("result['cadence_manifest_sha256'] = digest(output/'cadence-recording.json')",S)
  self.assertIn('PASS_NATIVE_CIV13_FLAX_A_FRAMES',s)
  self.assertNotIn('PASS_NATIVE_CADENCE_DIAGNOSTIC',s)
