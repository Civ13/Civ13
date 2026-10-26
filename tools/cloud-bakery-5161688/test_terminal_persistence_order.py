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
  self.assertIn("'PASS_NATIVE_CIV13_FLAX_A_FRAMES', started=started)",b)
 def test_new_helper_is_bound_without_replacing_source_pins(self):
  s=Path(__file__).with_name('encode_local.py').read_text(encoding='utf-8')
  for name in ('capture.py','run_scene.py','recording.py','encode_local.py','viewport_border.py','receipt_persistence.py'):
   self.assertIn(repr(name),s)
  self.assertIn("receipt.get('persistence_complete') is True",s)
