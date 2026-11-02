"""Offline scheduler staging, budget, archive and host-evidence controls."""
import copy
import base64
import lzma
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import re
import subprocess
import tarfile
import tempfile
from types import SimpleNamespace
import time
import unittest
from unittest.mock import patch

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];HEAD='a'*40
def load(name,file):
 spec=importlib.util.spec_from_file_location(name,HERE/file);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
binding=load('transition_binding_test','scheduler_transition_binding.py')
evidence=load('transition_evidence_test','scheduler_transition_evidence.py')
controller=load('transition_controller_test','cloud_npc_controller.py')
fixture=load('transition_sample_test','test_scheduler_transition_contract.py')
stage=load('transition_stage_test','scheduler_transition_stage.py')
contract=load('transition_contract_test','scheduler_transition_contract.py')
worker=load('transition_worker_test','scheduler_transition_worker.py')
def rec(raw):return {'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
def archive(files):
 out=io.BytesIO()
 with tarfile.open(fileobj=out,mode='w') as tar:
  for name,raw in files:
   item=tarfile.TarInfo(name);item.size=len(raw);tar.addfile(item,io.BytesIO(raw))
 return out.getvalue()
def receipt(mode):
 rows=fixture.rows(mode)
 return {'head':HEAD,'error':None,'port':0,'byond_version':516,'byond_build':1688,'scope':stage.SCOPE,
         'transition_checks':1,'transition_phase':'quiet','transition_rows':rows,'transition_partial':copy.deepcopy(rows[-1]['events'])}
def synthetic():
 sources={name:(ROOT/name).read_bytes() for name in binding.PINNED}
 overlays=stage.instrument({p:sources[p].decode() for p in (stage.ANIMAL,stage.AI,stage.CAT)})
 expected={name:raw for name,raw in sources.items() if name not in ('civ13.dme',stage.PROBE,stage.ANIMAL,stage.AI,stage.CAT)}
 expected.update({p:text.encode() for p,text in overlays.items()})
 expected[stage.PROBE]=stage.adapt_probe(sources[stage.PROBE].decode()).encode()
 dme=re.sub(r'^#include ".*\.dmm"\s*$','',sources['civ13.dme'].decode(),flags=re.M)
 dme+='\n#include "tests\\human_subtile\\mining.dm"\n#include "tests\\human_subtile\\probe.dm"\n'
 dme+='\n#include "tests\\human_subtile\\scheduler_core_draft.dm"\n';expected['human_subtile.dme']=dme.encode()
 manifest={'head':HEAD,'transition_scope':stage.SCOPE,'native_executed':False,'stage_files':{p:rec(raw) for p,raw in expected.items()},
           'original_git_files':{p:rec(raw) for p,raw in sources.items()}}
 resource={'bytes':12,'mode':0o600,'sha256':'a'*64};states={k:{'before':resource,'after':resource,'changed':False,'integrity_verified':True} for k in ('legacy','mixed')}
 receipts={k:receipt(k) for k in ('legacy','mixed')};raws={k:json.dumps(v).encode() for k,v in receipts.items()}
 phase=lambda sec,lim:{'returncode':0,'timed_out':False,'oversized_log':False,'deadline':lim,'seconds':sec}
 status={'head':HEAD,'suite':'transition05','phase':'complete','outcome':'passed','fixture_dme_only':True,
         'resource_copies_independent':True,'runtime_resources':states}
 summary={'head':HEAD,'suite':'transition05','tick':0.5,'fixture_dme_only':True,'observation_complete':True,
          'parity_established':False,'scope':stage.SCOPE,'limits':{'compile_seconds':120,'daemon_seconds':90,'setup_seconds':60,'work_seconds':490,'whole_seconds':600},
          'compile':phase(3,120),'artifacts':{'human_subtile.rsc':resource},'resource_states':states,
          'results':{k:{'daemon':phase(4,90),'receipt_sha256':hashlib.sha256(raws[k]).hexdigest()} for k in raws},
          'comparison':contract.compare_receipts(receipts['legacy'],receipts['mixed'],HEAD),
          'child_elapsed':11,'setup_seconds':1,'comparison_elapsed':12}
 files={'harness-status.json':json.dumps(status).encode(),'smoke-summary.json':json.dumps(summary).encode(),
        'npc-smoke/cloud-manifest.json':json.dumps(manifest).encode(),'npc-smoke/stage/compile-stdout.log':b'ok','npc-smoke/stage/compile-stderr.log':b''}
 for label,folder in (('legacy','runtime'),('mixed','runtime-wildlife')):
  prefix='npc-smoke/'+folder+'/'
  files.update({prefix+'receipt.json':raws[label],prefix+'result.txt':b'PASS\n',prefix+'port-closed.txt':b'closed\n',
                prefix+'runtime.log':b'',prefix+'daemon-stdout.log':b'',prefix+'daemon-stderr.log':b''})
 files.update({f'abi/abi-{i}-{part}.log':b'' for i in range(6) for part in ('stdout','stderr')})
 return sources,files
def validate(files,sources):
 class Legacy:
  @staticmethod
  def validate_compile(log,expected):
   if log!='ok' or expected!='human_subtile.dmb':raise ValueError('compile log')
 class NPC:
  class current:legacy=Legacy()
 modules={'scheduler_transition_binding':binding,'scheduler_transition_stage':stage,'scheduler_transition_contract':contract,'run-npc':NPC}
 def git(args,**kwargs):return sources[args[-1].split(':',1)[1]]
 with patch.object(evidence,'module',side_effect=modules.__getitem__),patch.object(binding,'validate_source',return_value=True),patch.object(evidence.subprocess,'check_output',side_effect=git):
  return evidence.validate(archive(list(files.items())),HEAD,'transition05',['git'],None,time.monotonic()+10)

class HostContracts(unittest.TestCase):
 def test_synthetic_complete_package(self):
  sources,files=synthetic();self.assertEqual(len(files),29);self.assertIsNone(validate(files,sources))
  raw=archive(list(files.items()));self.assertEqual(controller.validate_package(raw,rec(raw),'transition05'),raw)
 def test_missing_extra_traversal_and_duplicate_fail_closed(self):
  sources,files=synthetic()
  for mutation in ('missing','extra','traversal'):
   altered=dict(files)
   if mutation=='missing':altered.pop('npc-smoke/runtime-wildlife/receipt.json')
   elif mutation=='extra':altered['unexpected']=b'x'
   else:altered['../escape']=b'x'
   with self.subTest(mutation=mutation),self.assertRaises(ValueError):validate(altered,sources)
  raw=archive(list(files.items())+[('harness-status.json',b'{}')])
  with self.assertRaises(RuntimeError):controller.validate_package(raw,rec(raw),'transition05')
 def test_compressed_evidence_round_trip_and_bad_transport(self):
  _,files=synthetic();raw=archive(list(files.items()));compressed=lzma.compress(raw,format=lzma.FORMAT_XZ,preset=6)
  self.assertLessEqual(len(compressed),controller.MAX_LOG_PACKAGE)
  def parts(data):
   encoded=base64.b64encode(data);chunks=[encoded[i:i+8192] for i in range(0,len(encoded),8192)]
   log=b'\n'.join(b'HARNESS_EVIDENCE_PART '+str(i+1).encode()+b'/'+str(len(chunks)).encode()+b' '+part for i,part in enumerate(chunks))
   marker={'package':{'parts':len(chunks),'compressed_bytes':len(data),'complete':True,'compression':'xz',
                      'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}}
   return log,marker
  log,marker=parts(compressed);self.assertEqual(controller.package_from_logs(log,marker,'transition05'),raw)
  for bad in (compressed[:-1],compressed+b'junk'):
   log,marker=parts(bad)
   with self.subTest(trailing=bad.endswith(b'junk')),self.assertRaises((RuntimeError,lzma.LZMAError)):controller.package_from_logs(log,marker,'transition05')
 def test_changed_input_receipt_and_budget_fail(self):
  sources,files=synthetic();bad=dict(sources);bad[stage.CAT]+=b'changed'
  with self.assertRaises(ValueError):validate(files,bad)
  for mutation in ('receipt','setup','resource'):
   altered=dict(files);summary=json.loads(altered['smoke-summary.json'])
   if mutation=='receipt':altered['npc-smoke/runtime/receipt.json']=b'{}'
   elif mutation=='setup':summary['setup_seconds']=61;altered['smoke-summary.json']=json.dumps(summary).encode()
   else:summary['resource_states']['mixed']['integrity_verified']=False;altered['smoke-summary.json']=json.dumps(summary).encode()
   with self.subTest(mutation=mutation),self.assertRaises(ValueError):validate(altered,sources)
 def test_pinned_source_bytes_match_git_blob_identities(self):
  for path,expected in binding.PINNED.items():
   raw=(ROOT/path).read_bytes().replace(b'\r\n',b'\n')
   actual=hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
   with self.subTest(path=path):self.assertEqual(actual,expected)
 def test_source_binding_rejects_wrong_paths_and_pins(self):
  def perform(paths,bad=False):
   def output(args,**kwargs):
    if 'diff' in args:return ('\0'.join(sorted(paths))+'\0').encode()
    val=args[-1]
    if val.endswith('^{tree}'):return binding.BASE_TREE.encode()
    path=val.split(':',1)[1];return ('bad' if bad else binding.PINNED[path]).encode()
   with patch.object(binding.subprocess,'check_output',side_effect=output),patch.object(binding.subprocess,'run',return_value=subprocess.CompletedProcess([],0)):
    return binding.validate_source(['git'],None,HEAD,time.monotonic()+3)
  self.assertTrue(perform(binding.ALLOWED_DELTA))
  for paths,bad in ((set(binding.ALLOWED_DELTA)-{next(iter(binding.ALLOWED_DELTA))},False),(set(binding.ALLOWED_DELTA)|{'other'},False),(binding.ALLOWED_DELTA,True)):
   with self.subTest(bad=bad),self.assertRaises(ValueError):perform(paths,bad)
 def test_container_bounds_and_selector(self):
  args=controller.create_args('name','owner',HEAD,Path('/source'),Path('/bin'),Path('/zip'),'1001:1001','transition05',123.0)
  for flag,value in (('--network','none'),('--pids-limit','64'),('--memory','3g'),('--memory-swap','3g'),('--cpus','2'),('--work-deadline','123.0')):
   self.assertEqual(args[args.index(flag)+1],value)
  for path in ('cloud_npc_controller.py','cloud_npc_job.py','cloud_npc_smoke.py'):
   self.assertIn("choices=('species05','transition05')",(HERE/path).read_text())
  workflow=(ROOT/'.github/workflows/wildlife-cardinal-cadence.yml').read_text()
  self.assertIn('suite: [transition05]',workflow);self.assertIn('test "$(git rev-parse HEAD^{tree})" = "$EXPECTED_TREE"',workflow)

class WorkerContracts(unittest.TestCase):
 def run_worker(self,fail):
  checkpoints=[];launches=[]
  class FakeShared:
   HERE=HERE;ROOT=ROOT
   @staticmethod
   def require(value,reason):
    if not value:raise RuntimeError(reason)
   @staticmethod
   def load_module(name,path):return {'scheduler_transition_stage':fake_stage,'scheduler_transition_contract':contract,'scheduler_transition_binding':fake_binding}[name]
   @staticmethod
   def checkpoint(phase,**kw):checkpoints.append(phase)
   @staticmethod
   def file_hash(path):return hashlib.sha256(path.read_bytes()).hexdigest()
   @staticmethod
   def run_owned_phase(legacy,group,command,cwd,name,deadline):
    launches.append(('compile',deadline));(cwd/'compile-stdout.log').write_text('ok');(cwd/'compile-stderr.log').write_text('')
    return {'returncode':0,'timed_out':False,'oversized_log':False,'deadline':deadline,'seconds':0}
   @staticmethod
   def prepare_linked_runtime(out,source,dme,name):
    work=out/name;work.mkdir();dmb=work/'human_subtile.dmb';dmb.write_bytes(b'compiled');dmb.with_suffix('.rsc').write_bytes(b'resource')
    return work,dmb,{'human_subtile.rsc':{'bytes':8,'sha256':'a'*64,'mode':0o600}}
   @staticmethod
   def run_checked_runtime(legacy,group,command,work,dme,peer,artifacts,expected,label,states,timeout):
    launches.append((label,timeout))
    if fail==label:
     (work/'result.txt').write_bytes(b'FAIL\n');raise RuntimeError('synthetic daemon failure')
    item=artifacts['human_subtile.rsc'];states[label]={'before':item,'after':item,'changed':False,'integrity_verified':True}
    (work/'port-closed.txt').write_bytes(b'closed\n');(work/'result.txt').write_bytes(b'PASS\n');(work/'receipt.json').write_text(json.dumps(receipt(label)))
    return {'returncode':0,'timed_out':False,'oversized_log':False,'deadline':timeout,'seconds':0}
  class FakeNPC:
   current=object()
   @staticmethod
   def prepare_source(root,out):
    (out/'stage').mkdir(parents=True);(out/'stage/human_subtile.dme').write_text('source');return {'head':HEAD,'dme':'stage/human_subtile.dme','stage_files':{}}
  class FakeStage:
   SCOPE=stage.SCOPE
   @staticmethod
   def adapt(out,manifest,current):manifest['stage_files']['human_subtile.dme']=rec((out/'stage/human_subtile.dme').read_bytes())
  fake_stage=FakeStage();fake_binding=SimpleNamespace(validate_source=lambda *args:True)
  fake_runtime=SimpleNamespace(verify_linux=lambda *args:None);fake_legacy=SimpleNamespace(validate_compile=lambda *args:None,inspect_logs=lambda *args:None)
  args=SimpleNamespace(suite='transition05',head=HEAD,work_deadline=time.monotonic()+1000)
  with tempfile.TemporaryDirectory() as tmp:
   scratch=Path(tmp)
   if fail:
    with self.assertRaisesRegex(RuntimeError,'synthetic daemon failure'):worker.run(FakeShared,args,scratch,Path(tmp),Path(tmp),'group',{}, {}, {},time.monotonic(),FakeNPC,fake_runtime,fake_legacy)
    self.assertFalse((scratch/'smoke-summary.json').exists());self.assertNotIn('complete',checkpoints)
    if fail=='mixed':self.assertTrue((scratch/'npc-smoke/runtime/receipt.json').is_file())
   else:
    worker.run(FakeShared,args,scratch,Path(tmp),Path(tmp),'group',{}, {}, {},time.monotonic(),FakeNPC,fake_runtime,fake_legacy)
    summary=json.loads((scratch/'smoke-summary.json').read_text());self.assertFalse(summary['parity_established']);self.assertEqual(checkpoints[-1],'complete')
  return launches
 def test_one_compile_two_sequential_bounded_daemons(self):self.assertEqual(self.run_worker(None),[('compile',120),('legacy',90),('mixed',90)])
 def test_first_failure_stops_before_second_daemon(self):self.assertEqual(self.run_worker('legacy'),[('compile',120),('legacy',90)])
 def test_second_failure_preserves_first_receipt(self):self.assertEqual(self.run_worker('mixed'),[('compile',120),('legacy',90),('mixed',90)])
 def test_short_deadline_refused_before_any_launch(self):
  class Shared:
   HERE=HERE;ROOT=ROOT
   @staticmethod
   def require(value,reason):
    if not value:raise RuntimeError(reason)
   @staticmethod
   def load_module(name,path):return {'scheduler_transition_stage':stage,'scheduler_transition_contract':contract,'scheduler_transition_binding':binding}[name]
  with self.assertRaisesRegex(RuntimeError,'deadline'):worker.run(Shared,SimpleNamespace(suite='transition05',head=HEAD,work_deadline=time.monotonic()+1),Path('.'),Path('.'),Path('.'),None,{}, {}, {},time.monotonic(),None,None,None)

if __name__=='__main__':unittest.main()
