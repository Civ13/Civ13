"""Offline negative coverage of every publication identity and exact job guard."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import activation

class Activation(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
  self.root=Path(self.tmp.name)/'tools/cloud-bakery-5161688';self.root.mkdir(parents=True)
  for name in ['activation.json','run_scene.py','directx_setup.py','tree-source-contract.json','README.md']:
   (self.root/name).write_bytes((activation.HERE/name).read_bytes())
  self.workflow=self.root.parents[1]/'.github/workflows/cloud-bakery-5161688.yml';self.workflow.parent.mkdir(parents=True)
  self.workflow.write_bytes((activation.HERE.parents[1]/'.github/workflows/cloud-bakery-5161688.yml').read_bytes())
  self.a=json.loads((self.root/'activation.json').read_text(encoding='utf-8'))
 def test_real_activation(self):
  self.assertEqual(activation.check(),self.a)
 def test_each_stale_identity_rejected(self):
  cases=[(self.workflow,self.a['branch'],'ci/stale'),(self.workflow,self.a['message'],'ci: stale'),(self.workflow,'github.run_attempt == 1','github.run_attempt == 2'),(self.workflow,self.a['sole_parent'],'0'*40),(self.root/'run_scene.py','refs/heads/'+self.a['branch'],'refs/heads/ci/stale'),(self.root/'directx_setup.py','refs/heads/'+self.a['branch'],'refs/heads/ci/stale'),(self.root/'tree-source-contract.json','refs/heads/'+self.a['branch'],'refs/heads/ci/stale')]
  for path,old,new in cases:
   with self.subTest(path=path.name,identity=old):
    original=path.read_text(encoding='utf-8');self.assertIn(old,original)
    path.write_text(original.replace(old,new),encoding='utf-8')
    with self.assertRaises(ValueError):activation.check(self.root)
    path.write_text(original,encoding='utf-8')
 def test_each_readme_identity_rejected(self):
  path=self.root/'README.md';original=path.read_text(encoding='utf-8')
  for old,new in [(self.a['branch'],'ci/stale'),(self.a['message'],'ci: stale'),(self.a['sole_parent'],'0'*40),('Attempt1 only,','Attempt2 only,')]:
   with self.subTest(identity=old):
    path.write_text(original.replace(old,new),encoding='utf-8')
    with self.assertRaises(ValueError):activation.check(self.root)
    path.write_text(original,encoding='utf-8')
 def test_duplicate_workflow_message_rejected(self):
  with self.workflow.open('a',encoding='utf-8') as f:f.write("\n# github.event.head_commit.message == '"+self.a['message']+"'\n")
  with self.assertRaises(ValueError):activation.check(self.root)
 def test_missing_workflow_message_rejected(self):
  s=self.workflow.read_text(encoding='utf-8');self.workflow.write_text(s.replace('github.event.head_commit.message','omitted'),encoding='utf-8')
  with self.assertRaises(ValueError):activation.check(self.root)
 def test_manifest_fields_and_version_rejected(self):
  for key,value in [('run_attempt',2),('sole_parent','0'*40),('schema',2),('message','ci: one-shot actual-state tree handoff v999 (2026-10-25)'),('branch','wrong'),('unexpected',True)]:
   with self.subTest(key=key):
    a=dict(self.a);a[key]=value;(self.root/'activation.json').write_text(json.dumps(a),encoding='utf-8')
    with self.assertRaises(ValueError):activation.check(self.root)
 def test_seal_matches_manifest_and_each_mismatch_rejected(self):
  path=self.root/'seal.json';seal=dict(proposed_branch=self.a['branch'],proposed_message=self.a['message'],initial_sole_parent=self.a['sole_parent'],run_attempt=1)
  path.write_text(json.dumps(seal),encoding='utf-8');activation.check(self.root,path)
  for key in seal:
   bad=dict(seal);bad[key]=2 if key=='run_attempt' else 'wrong';path.write_text(json.dumps(bad),encoding='utf-8')
   with self.subTest(key=key),self.assertRaises(ValueError):activation.check(self.root,path)
 def test_explicit_utf8_under_windows_locale(self):
  orig=Path.open
  def cp1252(path,mode='r',buffering=-1,encoding=None,errors=None,newline=None):
   return orig(path,mode,buffering,encoding or (None if 'b' in mode else 'cp1252'),errors,newline)
  with patch.object(Path,'open',cp1252):activation.check(self.root)
