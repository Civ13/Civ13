"""Offline YAML/shell-policy and synthetic retention controls. No native execution."""
import json,re,subprocess,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
import yaml
import collect_evidence as collect
B=Path(__file__).resolve().parents[2]
WORKFLOW=B/'.github/workflows/zone-native-1688-once.yml'
class Workflow(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.text=WORKFLOW.read_text();cls.doc=yaml.load(cls.text,Loader=yaml.BaseLoader);cls.job=cls.doc['jobs']['fixture'];cls.steps=cls.job['steps']
 def test_initial_branch_first_attempt_and_parent(self):
  self.assertEqual(self.doc['on'],{'push':{'branches':['codex/zone-native-1688-20261025-attempt1']}})
  for gate in ("github.event.created == true","github.run_attempt == 1","github.repository == 'Civ13/Civ13'","refs/heads/codex/zone-native-1688-20261025-attempt1"):self.assertIn(gate,self.job['if'])
  self.assertIn('rev-parse HEAD^)" = 281fb2e8b236fc814dbf1d88f41c318fc66099fb',self.text)
  self.assertIn('rev-list --parents -n 1 HEAD | wc -w)" -eq 2',self.text)
  self.assertEqual(self.doc['permissions'],{'contents':'read'})
 def test_pinned_actions_python_host_timeouts(self):
  for s in self.steps:
   if 'uses' in s:self.assertRegex(s['uses'],r'^[A-Za-z0-9_/-]+@[0-9a-f]{40}$')
  self.assertEqual(self.job['runs-on'],'ubuntu-22.04');self.assertEqual(self.job['timeout-minutes'],'35')
  self.assertEqual(next(s for s in self.steps if s.get('uses','').startswith('actions/setup-python'))['with']['python-version'],'3.12')
 def test_separate_exact_source_checkout(self):
  checkouts=[s for s in self.steps if s.get('uses','').startswith('actions/checkout')]
  self.assertEqual(len(checkouts),2)
  self.assertEqual(checkouts[1]['with']['ref'],'8144be445fa0492a515b6bb47b9692e0edc1830b')
  self.assertEqual(checkouts[1]['with']['path'],'source')
  for s in checkouts:self.assertEqual(s['with']['persist-credentials'],'false')
  self.assertIn('508e7e0677a8cdc45ab6eed100bcbb0d1fb283f3',self.text)
 def test_acquisition_exact_pinned_source_without_fallback(self):
  step=next(s for s in self.steps if s.get('name','').startswith('Acquire'))
  self.assertIn('--source repository-release',step['run']);self.assertIn('sha256sum --check',step['run'])
  self.assertIn('58e60ef0263cba1f1af04c0a135d1a14f486d799',self.text);self.assertIn('738fecfaf195bfbe31ed68fa4f0e4d05b9912248',self.text)
  self.assertNotRegex(step['run'],r'curl|wget|--insecure|verify=False|https?_proxy|\|\|')
 def test_runtime_only_explicit_pinned_controller(self):
  step=next(s for s in self.steps if s.get('name','').startswith('Execute'))
  self.assertEqual(step['timeout-minutes'],'21');self.assertIn('/runner/tools/zone_native_1688/run.py',step['run']);self.assertIn('--reviewed-native',step['run']);self.assertNotIn('qemu',step['run'].lower())
 def test_upload_only_staged_evidence(self):
  step=next(s for s in self.steps if s.get('uses','').startswith('actions/upload-artifact'))
  self.assertEqual(step['if'],'always()');self.assertEqual(step['with']['path'],'${{ runner.temp }}/zone-1688-retained/');self.assertEqual(step['with']['retention-days'],'7')
  self.assertNotRegex(step['with']['path'],r'\*|source|toolchain|\.dmb|\.rsc')
 def test_shell_syntax_only(self):
  for s in self.steps:
   if 'run' in s:
    result=subprocess.run(['bash','-n'],input=s['run'],text=True,capture_output=True)
    self.assertEqual(result.returncode,0,result.stderr)
 def roots(self,base):
  roots=[base/x for x in ('evidence','acquisition','tooling')]
  for p in roots:p.mkdir()
  return roots
 def test_retention_excludes_binaries_real_source_and_saves(self):
  with tempfile.TemporaryDirectory() as td:
   b=Path(td);e,a,t=self.roots(b);(e/'result.json').write_text('{}');(e/'source').mkdir();(e/'source/compile.log').write_text('compiler');(e/'source/zone-1688.dmb').write_bytes(b'binary');(e/'source/civ13.dme').write_text('real source');(e/'runs/write/map_saves').mkdir(parents=True);(e/'runs/write/map_saves/1.sav').write_text('save')
   r=collect.collect(e,a,t,b/'retained');paths={x['path'] for x in r['files']}
   self.assertEqual(paths,{'receipts/result.json','compile/compile.log'});self.assertFalse(r['rejected'])
 def test_retention_symlink_and_oversize_fail_closed(self):
  with tempfile.TemporaryDirectory() as td:
   b=Path(td);e,a,t=self.roots(b);secret=b/'outside';secret.write_text('outside');(e/'result.json').symlink_to(secret);(e/'preparation.json').write_text('x'*20)
   with patch.object(collect,'MAX_FILE',10):r=collect.collect(e,a,t,b/'retained')
   self.assertEqual(len(r['rejected']),2);self.assertFalse(r['files']);self.assertNotIn('outside',(b/'retained/retention.json').read_text())
 def test_retention_bound_does_not_upload_whole_mode(self):
  with tempfile.TemporaryDirectory() as td:
   b=Path(td);e,a,t=self.roots(b);m=e/'runs/read';m.mkdir(parents=True);(m/'daemon.log').write_text('abc');(m/'unapproved.json').write_text('no');(m/'extra.log').write_text('log')
   r=collect.collect(e,a,t,b/'retained');self.assertEqual({x['path'] for x in r['files']},{'runs/read/daemon.log','runs/read/extra.log'})
if __name__=='__main__':unittest.main()
