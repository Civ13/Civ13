"""Synthetic-only contracts; no subprocess, socket, native compiler or daemon."""
import hashlib,json,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
from prepare import HEAD,TREE,ADAPTER,VARIANTS,CANDIDATE_INVENTORY_SHA256,canonical,digest,validate_inventory_bytes
from plan import PHASES,PROFILES,TOTAL_WALL_SECONDS,RESTART_FILES,copy_restart,activation_gate
from receipts import LifecycleModel
from grant import consume_grant

class Contracts(unittest.TestCase):
 def test_exact_plan_and_unchanged_nonwall_limits(self):
  self.assertEqual(HEAD,'ae99e2b07c3ba9a2dd191ba07b6dba27a4bfda3e')
  self.assertEqual(TREE,'3fedd061d42235af0d7699d9eb39135d41c25fd5')
  self.assertEqual(VARIANTS,('baseline',))
  self.assertEqual(PHASES,(('baseline-compile','compiler','baseline',None),('baseline-writer','daemon','baseline','writer'),('baseline-reader','daemon','baseline','reader')))
  self.assertEqual(TOTAL_WALL_SECONDS,600)
  self.assertEqual(PROFILES['daemon'],dict(wall_seconds=180,cpu_seconds=30,address_space_bytes=1024**3,file_bytes=16*1024**2,file_descriptors=128,stdout_bytes=4*1024**2))
  self.assertEqual(PROFILES['compiler'],dict(wall_seconds=180,cpu_seconds=150,address_space_bytes=2*1024**3,file_bytes=512*1024**2,file_descriptors=256,stdout_bytes=4*1024**2))
 def test_actual_full_inventory_bytes(self):
  raw=Path(__file__).with_name('source-manifest.json').read_bytes()
  rows=validate_inventory_bytes(raw);self.assertEqual(len(rows),5089)
  with self.assertRaises(ValueError):validate_inventory_bytes(raw+b' ')
 def test_default_is_inactive(self):
  with self.assertRaises(RuntimeError):activation_gate(False)
 def test_process_controller_unchanged(self):
  self.assertEqual(digest(Path(__file__).with_name('owned_process_1688.py').read_bytes()),'b247b308ff088b832417466218b1b96f11be2f1a622e710749e92c77b451b1ea')
 def test_restart_requires_all_fixed_files_and_cleanup(self):
  with tempfile.TemporaryDirectory() as tmp:
   root=Path(tmp);w=root/'writer';w.mkdir();files={}
   for n in RESTART_FILES:
    p=w/n;p.parent.mkdir(parents=True,exist_ok=True);b=('invented '+n).encode();p.write_bytes(b);files[n]={'bytes':len(b),'sha256':digest(b)}
   receipt=dict(candidate_manifest_sha256='a'*64,phase='baseline-writer',started=True,process_completed=True,cleanup_verified=True,validated=True,restart_files=files)
   copy_restart(w,root/'reader',receipt,'a'*64)
   for n in RESTART_FILES:self.assertEqual((w/n).read_bytes(),(root/'reader'/n).read_bytes())
   for key in ['validated','cleanup_verified','process_completed']:
    with self.assertRaises(ValueError):copy_restart(w,root/('bad-'+key),dict(receipt,**{key:False}),'a'*64)
   (w/'map_saves/1.sav').write_bytes(b'changed')
   with self.assertRaises(ValueError):copy_restart(w,root/'changed',receipt,'a'*64)
 def test_inconclusive_is_not_pass_or_next_phase(self):
  m=LifecycleModel('a'*64);m.attempt('baseline-compile',0)
  with self.assertRaises(ValueError):m.inconclusive('not started',1)
  m.active.update(started=True,process_completed=True,cleanup_verified=True)
  m.inconclusive('stochastic allzero',2)
  self.assertEqual(m.state['status'],'inconclusive');self.assertFalse(m.state['phases'][-1]['validated'])
  with self.assertRaises(ValueError):m.attempt('baseline-writer',3)
 def test_one_shot_exact_grant(self):
  with tempfile.TemporaryDirectory() as tmp:
   p=Path(tmp)/'grant.json';controller={'synthetic':'only'}
   grant=dict(schema=1,adapter=ADAPTER,head=HEAD,tree=TREE,candidate_manifest_sha256='a'*64,controller_sha256=digest(canonical(controller)),archive_sha256='16278f318cdeb4b77c57868dd7135032fde717ea6226269d22b2a1a50968e7f9',phases=3,compiler_phases=1,daemon_phases=2,aggregate_wall_seconds=600,grant_id='offline-invented')
   p.write_bytes(canonical(grant));self.assertTrue(consume_grant(p,controller,'a'*64)['consumed'])
   with self.assertRaises(FileExistsError):consume_grant(p,controller,'a'*64)
   grant['aggregate_wall_seconds']=1200;(Path(tmp)/'wrong.json').write_bytes(canonical(grant))
   with self.assertRaises(ValueError):consume_grant(Path(tmp)/'wrong.json',controller,'a'*64)
if __name__=='__main__':unittest.main()

class FixtureSourceContracts(unittest.TestCase):
 def test_receipt_dimensions_match_actual_fixture(self):
  import ast,re
  import prepare
  tree=ast.parse(Path(prepare.__file__).read_text())
  values=[ast.literal_eval(value) for node in ast.walk(tree) if isinstance(node,ast.Dict)
          for key,value in zip(node.keys,node.values) if isinstance(key,ast.Constant) and key.value=='dimensions']
  self.assertEqual(values,[[10,8,1]])
  fixture=Path(__file__).with_name('probe.dm').read_text()
  actual=[]
  for axis in ('x','y','z'):
   matches=re.findall(r'^\tmax'+axis+r' = (\d+)$',fixture,re.M)
   self.assertEqual(len(matches),1)
   actual.append(int(matches[0]))
  self.assertEqual(values[0],actual)
 def test_no_accelerated_or_direct_crop_callbacks(self):
  import re
  root=Path(__file__).parent
  source='\n'.join((root/n).read_text() for n in ('probe.dm','food-save.dm','wrapper.dm'))
  for pattern in (r'\.stageGrowth\s*\(',r'\.growth\s*\(',r'\.food_decay\s*\(',r'\.stage\s*=(?!=)',r'\.vstatic\s*=(?!=)',r'world\.(?:fps|tick_lag)\s*=(?!=)',r'\b(?:seed|rand_seed)\s*\('):
   self.assertIsNone(re.search(pattern,source),pattern)
  self.assertIn('map_storage.Save_World()',source);self.assertIn('map_storage.Load_World()',source)
  self.assertIn('sleep(1)',source);self.assertIn('winter_origin_tick < 1350',source)
 def test_generated_overlay_excludes_only_global_startup(self):
  import os
  from prepare import generated_files,INPUTS
  path=os.environ.get('WINTER_TEST_SOURCE')
  if not path:self.skipTest('Actual source export/checkout path not supplied')
  root=Path(path);inputs={n:(root/n).read_bytes() for n in INPUTS}
  output=generated_files(inputs,CANDIDATE_INVENTORY_SHA256,'baseline')
  self.assertEqual(set(output),{'winter1688-world.dm','winter1688-globals.dm','winter1688-probe.dm','winter1688.dme'})
  dme=output['winter1688.dme'].decode()
  self.assertIn('code\\game\\objects\\farming.dm',dme)
  self.assertIn('code\\modules\\persistence\\loading.dm',dme)
  self.assertNotIn('winter1688-control.dm',dme)
