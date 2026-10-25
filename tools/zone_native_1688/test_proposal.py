"""Pure offline controls: does not launch any process or fabricate Git metadata."""
import hashlib,json,tempfile,unittest,zipfile
from pathlib import Path
from unittest.mock import patch
import prepare,oracle,run
B=Path(__file__).resolve().parent/'test_inputs'
class Oracles(unittest.TestCase):
 def result(self,mode):
  c={'write':(1,0,0),'read':(0,2,2),'write-sequence':(3,0,0),'read-sequence':(0,6,6),'legacy-write':(1,0,0),'legacy-read':(0,1,1)}.get(mode,(0,1,0))
  return dict(head=prepare.HEAD,version='516.1688',mode=mode,failed=0,checks=20,rejection=None,expected=None,**dict(zip(('save_calls','load_calls','load_successes'),c)))
 def negative(self,mode,reason=None):
  reason=reason or oracle.NEGATIVE[mode];r=self.result(mode);r.update(expected=reason,rejection=reason+' on code/modules/persistence/zone_topology.dm:304')
  text=f'ZONE_PHASE {mode} begin\nWorld-save preflight rejected: '+r['rejection']+f'\nZONE_PHASE {mode} end\n'
  return r,text,dict(mode=mode,expected=reason)
 def test_all_positive_modes(self):
  for mode in oracle.MODES:
   if mode not in oracle.NEGATIVE:self.assertTrue(oracle.verify_result(mode,self.result(mode),''))
 def test_all_named_negative_modes(self):
  for mode in oracle.NEGATIVE:
   r,t,p=self.negative(mode,'Missing captured membership' if mode=='incomplete' else None);self.assertTrue(oracle.verify_result(mode,r,t,p))
 def test_incomplete_savefile_prediction_both_explicit_cases(self):
  for reason in ('Missing captured membership','Captured zone membership differs'):
   r,t,p=self.negative('incomplete',reason);self.assertTrue(oracle.verify_result('incomplete',r,t,p))
 def test_wrong_predicted_reason_rejected(self):
  r,t,p=self.negative('stale-zone');p['expected']='some other rejection'
  with self.assertRaises(ValueError):oracle.verify_result('stale-zone',r,t,p)
 def test_bool_is_not_dm_integer(self):
  for key in ('failed','checks','save_calls','load_calls','load_successes'):
   r=self.result('write');r[key]=False
   with self.assertRaises(ValueError):oracle.verify_result('write',r,'')
 def test_exact_source_version_mode(self):
  for key,value in [('head','wrong'),('version','516.1681'),('mode','read')]:
   r=self.result('write');r[key]=value
   with self.assertRaises(ValueError):oracle.verify_result('write',r,'')
 def test_missing_sequence_roundtrip_rejected(self):
  r=self.result('read-sequence');r['load_successes']=5
  with self.assertRaises(ValueError):oracle.verify_result('read-sequence',r,'')
 def test_extra_outside_or_duplicate_rejection_rejected(self):
  r,t,p=self.negative('stale-zone');line='World-save preflight rejected: '+r['rejection']+'\n'
  for bad in (line+t,t+line,t.replace('ZONE_PHASE stale-zone end',line+'ZONE_PHASE stale-zone end')):
   with self.assertRaises(ValueError):oracle.verify_result('stale-zone',r,bad,p)
 def test_fatal_never_suppressed_in_negative_phase(self):
  r,t,p=self.negative('stale-zone')
  for bad in ('Runtime in /world/New','BUG: invalid datum','World-save import failed: failure','World-save bookkeeping cleanup failed: x'):
   with self.assertRaises(ValueError):oracle.verify_result('stale-zone',r,t+bad,p)
 def test_positive_cannot_have_rejection(self):
  with self.assertRaises(ValueError):oracle.verify_result('write',self.result('write'),'World-save preflight rejected: x')
 def test_closed_notifications_can_repeat_but_bind_cannot(self):
  text='World opened on network port 1234 for address 127.0.0.1.\n'+('World no longer opened to new users.\n'*2)
  self.assertTrue(oracle.verify_result('write',self.result('write'),text))
  with self.assertRaises(ValueError):oracle.verify_result('write',self.result('write'),text+text)
  with self.assertRaises(ValueError):oracle.verify_result('write',self.result('write'),text.replace('127.0.0.1','0.0.0.0'))
 def test_aux_exact_diagnostic_not_blanket_suppressed(self):
  r,t,p=self.negative('stale-zone')
  oracle.verify_aux_logs({'admin.log':'Save rejected before clearing the world: '+r['expected']},'stale-zone',r)
  with self.assertRaises(ValueError):oracle.verify_aux_logs({'admin.log':'Save rejected before clearing the world: wrong'},'stale-zone',r)
 def test_fixture_adapter_source_only(self):
  zone=(B/'zone-probe-original.dm').read_text();prefix=(B/'durable-world-probe-original.dm').read_text();before=hashlib.sha256(zone.encode()).hexdigest();generated=prepare.adapt_probe(prefix,zone)
  self.assertEqual(hashlib.sha256(zone.encode()).hexdigest(),before)
  self.assertNotIn('get_area(locate(8,8,2)).persistence_zone_id',generated);self.assertNotIn('list/spawn)',generated)
  self.assertIn('var/area/created_zone = get_area(locate(8,8,2))',generated)
  self.assertIn('ZONE_PHASE [mode] begin',generated);self.assertIn('ZONE_PHASE [mode] end',generated)
  self.assertIn('zone_load_successes_1688',generated);self.assertIn('var/success = ticker.loadmap()',generated)
  self.assertIn('/obj/map_metadata/nomads/gaia/New()\n\tmap = src',generated)
 def test_generation_inventory_and_marker(self):
  with tempfile.TemporaryDirectory() as td:
   root=Path(td);source=root/'source';source.mkdir()
   for name in run.FILES:(source/name).write_text(name)
   marker='round-v2:'+('0'*32);(source/'save_complete.txt').write_text(marker);(source/'round.json').write_text(json.dumps({'generation':marker}))
   rows=run.generation(source,root/'copy');self.assertEqual(set(rows),set(run.FILES))
   (source/'unexpected').write_text('x')
   with self.assertRaises(ValueError):run.generation(source,root/'bad')
 def test_generation_symlinks_rejected(self):
  with tempfile.TemporaryDirectory() as td:
   root=Path(td);source=root/'source';source.mkdir()
   for name in run.FILES:(source/name).write_text(name)
   (source/'map.txt').unlink();(source/'map.txt').symlink_to(source/'round.json')
   with self.assertRaises(ValueError):run.generation(source,root/'copy')
 def test_archive_and_member_binding(self):
  with tempfile.TemporaryDirectory() as td:
   root=Path(td);archive=root/'runtime.zip';binary=root/'bin';binary.mkdir()
   with zipfile.ZipFile(archive,'w') as z:
    for name in ('DreamMaker','DreamDaemon','libbyond.so','libext.so'):z.writestr('byond/bin/'+name,name.encode());(binary/name).write_text(name)
   with patch.object(run,'ARCHIVE',prepare.digest(archive.read_bytes())):
    self.assertEqual(len(run.binaries(binary,archive)),4);(binary/'DreamDaemon').write_text('changed')
    with self.assertRaises(ValueError):run.binaries(binary,archive)
 def test_owned_controller_retains_leader_and_profile_limits(self):
  text=Path(run.__file__).with_name('owned_process_1688.py').read_text()
  self.assertIn('os.WNOWAIT',text);self.assertLess(text.index('if exited:\n                    group_signal(signal.SIGKILL)'),text.index('proc.wait(timeout=3)'))
  self.assertIn('preexec_fn=lambda: limits(profile)',text);self.assertIn('on_sample(proc.pid, identity, dict(observed))',text)
 def test_preparation_rejects_wrong_head_before_copy(self):
  with patch.object(prepare,'git',return_value=b'wrong'):
   with self.assertRaises(ValueError):prepare.source_inventory(Path('/nonexistent-source-only-test'))
 def test_admin_suffix_must_end_exactly(self):
  r,t,p=self.negative('stale-zone');prefix='Save rejected before clearing the world: '+r['expected']
  for tail in ('','</span></span>'):oracle.verify_aux_logs({'admin.log':prefix+tail},'stale-zone',r)
  for tail in ('</span>','</span></span> extra','</span>hidden failure','</span></span></extra>'):
   with self.assertRaises(ValueError):oracle.verify_aux_logs({'admin.log':prefix+tail},'stale-zone',r)
 def test_admin_marked_log_requires_phase_binding(self):
  r,t,p=self.negative('stale-zone');line='Save rejected before clearing the world: '+r['expected']
  oracle.verify_aux_logs({'admin.log':'ZONE_PHASE stale-zone begin\n'+line+'\nZONE_PHASE stale-zone end'},'stale-zone',r)
  for text in (line+'\nZONE_PHASE stale-zone begin\nZONE_PHASE stale-zone end','ZONE_PHASE stale-zone begin\nZONE_PHASE stale-zone end\n'+line,'ZONE_PHASE stale-zone begin\n'+line):
   with self.assertRaises(ValueError):oracle.verify_aux_logs({'admin.log':text},'stale-zone',r)
 def test_native_flags_set_only_by_post_popen_callback(self):
  text=Path(run.__file__).read_text();owned=Path(run.__file__).with_name('owned_process_1688.py').read_text()
  self.assertEqual(text.count("summary['native_executed']=True"),1)
  begin=text.index('  def started(pid,identity):');end=text.index('  try:r=run_bounded',begin)
  self.assertIn("summary['native_executed']=True",text[begin:end])
  self.assertLess(owned.index('proc = subprocess.Popen'),owned.index('on_start(proc.pid, None)'))
  self.assertLess(owned.index('on_start(proc.pid, None)'),owned.index('identity = proc_identity(proc.pid)'))
 def test_invalid_archive_prelaunch_keeps_actual_flags_false(self):
  with tempfile.TemporaryDirectory() as td:
   out=Path(td);summary=dict(compiler_attempted=False,native_executed=False,compiler_started=False,compiler_completed=False,daemon_attempted=False,daemon_started=False,daemon_completed=False,phases=[])
   with patch.object(run,'binaries',side_effect=ValueError('archive mismatch')):
    with self.assertRaisesRegex(ValueError,'archive mismatch'):run.run_native(out,out,{},out,out/'archive',summary)
   self.assertTrue(summary['compiler_attempted']);self.assertFalse(summary['native_executed']);self.assertFalse(summary['compiler_started']);self.assertFalse(summary['compiler_completed']);self.assertFalse(summary['daemon_started'])
if __name__=='__main__':unittest.main()
