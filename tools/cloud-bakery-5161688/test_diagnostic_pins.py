import json,shutil,tempfile,unittest
from pathlib import Path
from verify_diagnostic import verify
R=Path(__file__).parent
class Pins(unittest.TestCase):
 def setUp(self):
  tmp=tempfile.TemporaryDirectory();self.addCleanup(tmp.cleanup);self.base=Path(tmp.name)/'proposal'
  shutil.copytree(R.parents[1],self.base,ignore=shutil.ignore_patterns('__pycache__','*.pyc'))
  self.root=self.base/'tools/cloud-bakery-5161688'
 def test_exact_closure(self):self.assertEqual(verify(self.root)['status'],'EXACT_DIAGNOSTIC_CLOSURE_VERIFIED')
 def test_changed_source_fails(self):
  with (self.root/'run_scene.py').open('a',encoding='utf-8') as f:f.write('\n# changed\n')
  with self.assertRaisesRegex(ValueError,'pin mismatch'):verify(self.root)
 def test_added_unreviewed_tool_fails(self):
  (self.root/'unreviewed.py').write_text('pass\n',encoding='utf-8')
  with self.assertRaisesRegex(ValueError,'membership'):verify(self.root)
if __name__=='__main__':unittest.main()
