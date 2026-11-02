"""Offline source binding and evidence controls; never launch BYOND or Docker."""
import base64,hashlib,importlib.util,io,json,lzma,os,re,sys,tarfile,time,unittest,tempfile,shutil
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE/'native_group'))
import validate_receipt as oracle
from test_validate_receipt import good

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
binding=load('test_group_binding',HERE/'group_binding.py')
evidence=load('test_group_evidence',HERE/'group_evidence.py')
controller=load('test_group_controller',HERE/'cloud_npc_controller.py')
worker=load('test_group_worker',HERE/'group_worker.py')
HEAD='a'*40;TREE='b'*40

def binputs():return {n:(HERE/'native_group'/n).read_bytes() for n in binding.INPUTS}

def faux_git(extra=False,badmode=False,bad_fixture=False,badparent=False,bad_runner=False):
    def read(git,args,env=None,deadline=None,timeout=10):
        if args[0]=='rev-list':return (HEAD+' '+('f'*40 if badparent else binding.PARENT)+'\n').encode()
        if args[:2]==['rev-parse',binding.PARENT+'^{tree}']:return (binding.PARENT_TREE+'\n').encode()
        if args[0]=='diff':return b''.join(x.encode()+b'\0' for x in sorted(binding.PATHS | ({'unreviewed'} if extra else set())))
        if args[0]=='ls-tree':return b''.join((b'120000' if badmode and p.endswith('group_worker.py') else b'100644')+b' blob '+b'c'*40+b'\t'+p.encode()+b'\0' for p in sorted(binding.PATHS))
        if args[0]=='show':
            path=args[1].split(':',1)[1]
            if path.startswith(binding.PREFIX):
                name=path.removeprefix(binding.PREFIX);data=binputs()[name]
                return data+b'changed' if bad_fixture and name=='native-group-probe.dm' else data
            data=(HERE.parents[1]/path).read_bytes()
            return data+b'changed' if bad_runner and path.endswith('group_worker.py') else data
        if args[:2]==['rev-parse',HEAD+'^{tree}']:return (TREE+'\n').encode()
        raise AssertionError(args)
    return read

def phase(command,seconds):return {'command':command,'returncode':0,'timed_out':False,'oversized_log':False,'seconds':1.0,'deadline':seconds}

def sample_archive():
    inputs=binputs();source={n:{'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()} for n,data in inputs.items()}
    manifest={'head':HEAD,'tree':TREE,'parent':binding.PARENT,'scope':'standalone synthetic full-tile group Bump; no Civ13 gameplay','source':source}
    raw=json.dumps(good(),sort_keys=True).encode();obs=oracle.validate(json.loads(raw))
    status={'head':HEAD,'suite':'group05','phase':'complete','outcome':'passed','fixture_dme_only':True,'observation':obs}
    summary={'head':HEAD,'tree':TREE,'parent':binding.PARENT,'suite':'group05','fixture_dme_only':True,'scope':manifest['scope'],'parity_established':False,'observation':obs,
       'compile':phase(['/opt/byond/bin/DreamMaker','-max_errors','0','/work/npc-smoke/stage/native-group-probe.dme'],90),
       'daemon':phase(['/opt/byond/bin/DreamDaemon','/work/npc-smoke/runtime/native-group-probe.dmb','59474','-ip','127.0.0.1','-trusted','-log','runtime.log'],60),
       'artifacts':{'native-group-probe.dmb':{'bytes':1,'sha256':'c'*64}},'resource':{'before':None,'after':None},'receipt_sha256':hashlib.sha256(raw).hexdigest()}
    files={'harness-status.json':json.dumps(status).encode(),'smoke-summary.json':json.dumps(summary).encode(),'npc-smoke/cloud-manifest.json':json.dumps(manifest).encode(),
       'npc-smoke/stage/compile-stdout.log':b'DM OK','npc-smoke/stage/compile-stderr.log':b'',
       'npc-smoke/runtime/receipt.json':raw,'npc-smoke/runtime/runtime.log':b'ok','npc-smoke/runtime/daemon-stdout.log':b'ok','npc-smoke/runtime/daemon-stderr.log':b''}
    files.update({f'abi/abi-{i}-{s}.log':b'ok' for i in range(6) for s in ('stdout','stderr')})
    return files

def tar_bytes(files):
    b=io.BytesIO()
    with tarfile.open(fileobj=b,mode='w') as t:
        for name,data in files.items():
            x=tarfile.TarInfo(name);x.size=len(data);t.addfile(x,io.BytesIO(data))
    return b.getvalue()

def host_validate(data):
    legacy=SimpleNamespace(validate_compile=lambda log,name: None if log=='DM OK' and name=='native-group-probe.dmb' else (_ for _ in ()).throw(ValueError('compile')),DIAGNOSTICS=re.compile('runtime error',re.I))
    def modules(name,path):
        if name=='group_binding_host':return binding
        if name=='group_oracle_host':return oracle
        if name=='group_legacy_host':return legacy
        raise AssertionError(name)
    with patch.object(evidence,'load',side_effect=modules),patch.object(binding,'read',side_effect=faux_git()):
        return evidence.validate(data,HEAD,'group05',[],{},deadline=None)

class BindingTests(unittest.TestCase):
 def test_exact_parent_paths_and_five_fixture_hashes(self):
    with patch.object(binding,'read',side_effect=faux_git()):self.assertEqual(binding.validate_head([],HEAD),TREE)
 def test_unrelated_path_rejected(self):
    with patch.object(binding,'read',side_effect=faux_git(extra=True)),self.assertRaises(ValueError):binding.validate_head([],HEAD)
 def test_symlink_mode_rejected(self):
    with patch.object(binding,'read',side_effect=faux_git(badmode=True)),self.assertRaises(ValueError):binding.validate_head([],HEAD)
 def test_fixture_byte_change_rejected(self):
    with patch.object(binding,'read',side_effect=faux_git(bad_fixture=True)),self.assertRaises(ValueError):binding.validate_head([],HEAD)
 def test_runner_byte_change_rejected(self):
    with patch.object(binding,'read',side_effect=faux_git(bad_runner=True)),self.assertRaises(ValueError):binding.validate_head([],HEAD)
 def test_wrong_parent_rejected(self):
    with patch.object(binding,'read',side_effect=faux_git(badparent=True)),self.assertRaises(ValueError):binding.validate_head([],HEAD)
 def test_expired_deadline_stops_git(self):
    with self.assertRaises(TimeoutError):binding.read([],[],deadline=time.monotonic()-1)

class ArchiveTests(unittest.TestCase):
 def test_complete_exact_archive(self):self.assertTrue(host_validate(tar_bytes(sample_archive())))
 def test_missing_member_fails(self):
    files=sample_archive();del files['npc-smoke/runtime/receipt.json']
    with self.assertRaises(ValueError):host_validate(tar_bytes(files))
 def test_unexpected_member_fails(self):
    files=sample_archive();files['npc-smoke/runtime/unexpected.sav']=b'private'
    with self.assertRaises(ValueError):host_validate(tar_bytes(files))
 def test_wrong_receipt_hash_fails(self):
    files=sample_archive();files['npc-smoke/runtime/receipt.json']+=b' '
    with self.assertRaises(ValueError):host_validate(tar_bytes(files))
 def test_boolean_exit_code_cannot_impersonate_success(self):
    files=sample_archive();v=json.loads(files['smoke-summary.json']);v['daemon']['returncode']=False;files['smoke-summary.json']=json.dumps(v).encode()
    with self.assertRaises(ValueError):host_validate(tar_bytes(files))
 def test_wrong_phase_timeout_fails(self):
    files=sample_archive();v=json.loads(files['smoke-summary.json']);v['daemon']['deadline']=61;files['smoke-summary.json']=json.dumps(v).encode()
    with self.assertRaises(ValueError):host_validate(tar_bytes(files))
 def test_unsupported_observation_cannot_pass(self):
    files=sample_archive();v=json.loads(files['smoke-summary.json']);v['observation']['status']='unsupported_no_exchange';files['smoke-summary.json']=json.dumps(v).encode()
    with self.assertRaises(ValueError):host_validate(tar_bytes(files))
 def test_controller_accepts_only_group_named_members(self):
    raw=tar_bytes(sample_archive());expected={'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
    self.assertEqual(controller.validate_package(raw,expected,'group05'),raw)
    files=sample_archive();files['npc-parent/runtime/receipt.json']=b'x';raw=tar_bytes(files);expected={'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
    with self.assertRaises(RuntimeError):controller.validate_package(raw,expected,'group05')
 def test_bounded_xz_log_transport_roundtrip_and_truncation(self):
    raw=tar_bytes(sample_archive());packed=lzma.compress(raw,format=lzma.FORMAT_XZ,preset=6);b64=base64.b64encode(packed)
    parts=[b64[i:i+8192] for i in range(0,len(b64),8192)]
    lines=[b'HARNESS_EVIDENCE_PART '+str(i).encode()+b'/'+str(len(parts)).encode()+b' '+part for i,part in enumerate(parts,1)]
    marker={'package':{'parts':len(parts),'compressed_bytes':len(packed),'complete':True,'compression':'xz','bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}}
    self.assertEqual(controller.package_from_logs(b'\n'.join(lines),marker,'group05'),raw)
    with self.assertRaises(RuntimeError):controller.package_from_logs(b'\n'.join(lines[:-1]),marker,'group05')
 def test_unsafe_link_fails(self):
    files=sample_archive();b=io.BytesIO()
    with tarfile.open(fileobj=b,mode='w') as t:
        for name,data in files.items():
            x=tarfile.TarInfo(name)
            if name=='npc-smoke/runtime/receipt.json':x.type=tarfile.SYMTYPE;x.linkname='/etc/passwd';t.addfile(x)
            else:x.size=len(data);t.addfile(x,io.BytesIO(data))
    with self.assertRaises(ValueError):host_validate(b.getvalue())
class WorkerTests(unittest.TestCase):
 def run_worker(self,kind):
    workspace=HERE.parents[2].resolve()
    with tempfile.TemporaryDirectory(prefix='group-test-',dir=workspace) as name:
        root=Path(name).resolve();self.assertEqual(root.parent,workspace)
        checkpoints=[]
        fake_binding=SimpleNamespace(INPUTS=binding.INPUTS,PARENT=binding.PARENT,validate_head=lambda *a,**k:TREE)
        def loading(name,path):
            return fake_binding if name=='group_binding_worker' else oracle
        def checkpoint(name,**kw):checkpoints.append((name,kw))
        def hashfile(path):return hashlib.sha256(path.read_bytes()).hexdigest()
        def run_phase(legacy,group,command,cwd,label,limit):
            if label=='compile':
                (cwd/'native-group-probe.dmb').write_bytes(b'dmb');(cwd/'compile-stdout.log').write_text('DM OK');(cwd/'compile-stderr.log').write_text('')
                if kind=='resource_mutation':(cwd/'native-group-probe.rsc').write_bytes(b'original')
            else:
                (cwd/'daemon-stdout.log').write_text('ok');(cwd/'daemon-stderr.log').write_text('');(cwd/'runtime.log').write_text('ok')
                fixture=good()
                if kind=='unsupported':
                    row=fixture['cases'][2];row['events']=[e for e in row['events'] if e['kind'] not in ('entered_before','entered_after')]
                    for i,e in enumerate(row['events'],1):e['ordinal']=i
                (cwd/'native-group-receipt.json').write_text(json.dumps(fixture))
                if kind=='resource_mutation':(cwd/'native-group-probe.rsc').write_bytes(b'cached')
                if kind=='source_mutation':(cwd.parent/'stage'/'native-group-probe.dm').write_text('changed')
                if kind=='daemon_failure':raise RuntimeError('injected daemon failure')
            return {'command':[str(x) for x in command],'returncode':0,'timed_out':False,'oversized_log':False,'seconds':1.0,'deadline':limit}
        shared=SimpleNamespace(HERE=HERE,ROOT=HERE.parents[1],checkpoint=checkpoint,file_hash=hashfile,run_owned_phase=run_phase)
        runtime=SimpleNamespace(verify_linux=lambda *x:None)
        legacy=SimpleNamespace(validate_compile=lambda *x:None,inspect_logs=lambda *x:None)
        args=SimpleNamespace(suite='group05',head=HEAD,work_deadline=time.monotonic()+500)
        with patch.object(worker,'_load',side_effect=loading):
            if kind in ('daemon_failure','source_mutation','unsupported'):
                with self.assertRaises((RuntimeError,ValueError)):worker.run(shared,args,root,Path('/opt/byond/bin'),Path('/opt/byond.zip'),root,{}, {},{},time.monotonic(),None,runtime,legacy)
                self.assertTrue((root/'npc-smoke/runtime/receipt.json').is_file())
                if kind=='unsupported':
                    summary=json.loads((root/'smoke-summary.json').read_text());self.assertEqual(summary['observation']['status'],'inconclusive_no_postcommit_notification')
                else:self.assertFalse((root/'smoke-summary.json').exists())
            else:
                worker.run(shared,args,root,Path('/opt/byond/bin'),Path('/opt/byond.zip'),root,{}, {},{},time.monotonic(),None,runtime,legacy)
                summary=json.loads((root/'smoke-summary.json').read_text());self.assertEqual(summary['observation']['status'],'observed_consistent_on_this_trace')
                if kind=='resource_mutation':
                    self.assertNotEqual(summary['resource']['before'],summary['resource']['after'])
                    self.assertEqual((root/'npc-smoke/stage/native-group-probe.rsc').read_bytes(),b'original')
                self.assertEqual(checkpoints[-1][0],'complete')
 def test_worker_one_compile_one_daemon_no_resource(self):self.run_worker('success')
 def test_daemon_failure_preserves_raw_receipt(self):self.run_worker('daemon_failure')
 def test_unsupported_observation_preserves_summary_and_receipt(self):self.run_worker('unsupported')
 def test_runtime_resource_mutation_preserves_compiler_copy(self):self.run_worker('resource_mutation')
 def test_source_mutation_cannot_pass_and_receipt_survives(self):self.run_worker('source_mutation')

if __name__=='__main__':unittest.main(verbosity=2)
