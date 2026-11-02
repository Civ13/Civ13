"""Offline source binding, paired evidence and bounded runner controls."""
import copy
import hashlib
import io
import json
import os
from pathlib import Path
import tarfile
import tempfile
import time
import types
import unittest
from unittest.mock import patch

import cloud_npc_controller as controller
import cloud_npc_job as job
import ordinary_bump_binding as binding
import ordinary_bump_evidence as evidence
import ordinary_bump_materialize as materialize
import ordinary_bump_receipt as receipt
import ordinary_bump_stage as stage
import ordinary_bump_worker as worker
import runner_limits as limits
import test_ordinary_bump_receipt as model

HERE=Path(__file__).resolve().parent
HEAD='a'*40
TREE='b'*40


def require(ok,msg):
    if not ok:raise RuntimeError(msg)


def inputs():
    p=HERE/'ordinary_inputs'
    return {'old_living':(p/'living-base.dm').read_bytes(), 'new_living':(p/'living-current.dm').read_bytes(),
            'probe':(p/'probe-current.dm').read_bytes(),'dme':(p/'civ13-current.dme').read_bytes(),
            'runner':(p/'run-current.py').read_bytes()}


def make_tar(files):
    out=io.BytesIO()
    with tarfile.open(fileobj=out,mode='w') as t:
        for name,raw in files.items():
            info=tarfile.TarInfo(name);info.size=len(raw);t.addfile(info,io.BytesIO(raw))
    return out.getvalue()


def package_fixture():
    data=inputs();fixture=(HERE/'ordinary_bump_probe.dm').read_bytes()
    overlays={k:stage.reconstruct(data['old_living'] if k=='baseline' else data['new_living'],
        data['probe'],data['dme'],fixture,k=='candidate') for k in ('baseline','candidate')}
    rows={k:model.receipt('legacy' if k=='baseline' else 'candidate') for k in overlays}
    resource={'bytes':3,'sha256':'b'*64,'mode':0o600};compiled={'bytes':4,'sha256':'c'*64,'mode':0o444}
    states={k:{'before':resource,'after':resource,'changed':False,'integrity_verified':True} for k in overlays}
    artifacts={k:{'human_subtile.rsc':resource,'human_subtile.dmb':compiled} for k in overlays}
    phases=[dict(name=n,seconds=1,returncode=0,timed_out=False,oversized_log=False,deadline=limit) for n,limit in limits.PHASES]
    for i,prefix,mode in ((0,'npc-parent','legacy'),(2,'npc-smoke','candidate')):
        phases[i]['command']=['/opt/byond/bin/DreamMaker','-max_errors','0','/work/'+prefix+'/stage/human_subtile.dme']
        phases[i+1]['command']=['/opt/byond/bin/DreamDaemon','/work/'+prefix+'/runtime/human_subtile.dmb',
            '59474','-ip','127.0.0.1','-trusted','-params','tested_commit='+HEAD+';ordinary_bump_mode='+mode,'-log','runtime.log']
    bare=lambda item:{k:v for k,v in item.items() if k!='name'}
    originals={path:materialize.digest(data[k]) for path,k in (('code/game/mob/living/living.dm','new_living'),
        ('tests/human_subtile/probe.dm','probe'),('civ13.dme','dme'),('tests/human_subtile/run.py','runner'))}
    files={};results={}
    for label,prefix,mode,i in (('baseline','npc-parent','legacy',0),('candidate','npc-smoke','candidate',2)):
        raw=json.dumps(rows[label]).encode()
        manifest={'head':HEAD,'ordinary_bump_mode':mode,'game_head':stage.CANDIDATE_HEAD,'game_tree':stage.CANDIDATE_TREE,
            'baseline_living_commit':stage.BASE_HEAD,'experiment_tree':TREE,'stage_files':{p:materialize.digest(v) for p,v in overlays[label].items()},
            'original_git_files':originals,'adaptations':{}}
        files[prefix+'/cloud-manifest.json']=json.dumps(manifest).encode()
        files[prefix+'/stage/compile-stdout.log']=b'0 errors, 0 warnings\n';files[prefix+'/stage/compile-stderr.log']=b''
        for name,value in (('receipt.json',raw),('result.txt',b'PASS\n'),('port-closed.txt',b'closed\n'),
                           ('runtime.log',b''),('daemon-stdout.log',b''),('daemon-stderr.log',b'')):
            files[prefix+'/runtime/'+name]=value
        results[label]={'receipt_sha256':hashlib.sha256(raw).hexdigest(),'daemon':bare(phases[i+1])}
    summary={'head':HEAD,'tree':TREE,'game_head':stage.CANDIDATE_HEAD,'game_tree':stage.CANDIDATE_TREE,
        'baseline_head':stage.BASE_HEAD,'suite':'ordinary05','fixture_dme_only':True,'observation_complete':True,
        'visual_or_broad_parity_established':False,'scope':receipt.SCOPE,'tick':0.5,'modes':['legacy','candidate'],
        'cases':list(receipt.CASES),'comparison':{'ordinary_cases_observed':4,'visual_or_broad_parity_established':False},
        'artifacts':artifacts,'resource_states':states,'results':results,'phases':phases,
        'compiles':{'baseline':bare(phases[0]),'candidate':bare(phases[2])},'comparison_elapsed':5,'setup_seconds':1,
        'limits':{'compile_seconds':90,'daemon_seconds':60,'setup_seconds':60,'work_seconds':490,'whole_seconds':600}}
    status={'head':HEAD,'suite':'ordinary05','phase':'complete','outcome':'passed','fixture_dme_only':True,
            'resource_copies_independent':True,'runtime_resources':states}
    files['smoke-summary.json']=json.dumps(summary).encode();files['harness-status.json']=json.dumps(status).encode()
    files.update({f'abi/abi-{i}-{part}.log':b'' for i in range(6) for part in ('stdout','stderr')})
    return data,fixture,files


class BindingControls(unittest.TestCase):
    def test_exact_parent_and_path_scope(self):
        paths=sorted(binding.PATHS)
        def execute(cmd,**kwargs):
            if cmd[-2:]==['rev-parse',HEAD+'^']:return (binding.PARENT+'\n').encode()
            if cmd[-2:]==['rev-parse',HEAD+'^^{tree}']:return (binding.PARENT_TREE+'\n').encode()
            if cmd[-2:]==['rev-parse',HEAD+'^{tree}']:return (TREE+'\n').encode()
            if 'diff' in cmd:return ('\0'.join(paths)+'\0').encode()
            raise AssertionError(cmd)
        with patch.object(binding.subprocess,'check_output',side_effect=execute):
            self.assertEqual(binding.validate_head(['git'],HEAD),TREE)
            paths.pop()
            with self.assertRaises(ValueError):binding.validate_head(['git'],HEAD)
            paths.append('unreviewed/file')
            with self.assertRaises(ValueError):binding.validate_head(['git'],HEAD)
        with self.assertRaises(ValueError):binding.validate_head(['git'],'invalid')

    def test_game_inputs_reject_tree_parent_and_blob_mutation(self):
        data=inputs()
        def execute(cmd,**kwargs):
            if cmd[-1]==stage.CANDIDATE_HEAD+'^{tree}':return (stage.CANDIDATE_TREE+'\n').encode()
            if cmd[-1]==stage.CANDIDATE_HEAD+'^':return (stage.BASE_HEAD+'\n').encode()
            if cmd[-2]=='show':
                for (key,commit,path),_ in binding.INPUTS.items():
                    if cmd[-1]==commit+':'+path:return data[key]
            raise AssertionError(cmd)
        with patch.object(binding.subprocess,'check_output',side_effect=execute):
            self.assertEqual(binding.read_inputs(['git']),data)
            data['probe']+=b'X'
            with self.assertRaises(ValueError):binding.read_inputs(['git'])


class EvidenceControls(unittest.TestCase):
    def test_complete_package_and_rejected_extras(self):
        data,fixture,files=package_fixture()
        fake=types.SimpleNamespace(validate_head=lambda *a,**k:TREE,read_inputs=lambda *a,**k:data,budget_timeout=lambda *a,**k:1)
        loaded={'ordinary_bump_binding':fake,'ordinary_bump_stage':stage,'ordinary_bump_receipt':receipt,
                'ordinary_bump_materialize':materialize,'runner_limits':limits}
        compile_ok=lambda log,name:require(log=='0 errors, 0 warnings\n' and name=='human_subtile.dmb','compile')
        with patch.object(evidence.subprocess,'check_output',return_value=fixture):
            raw=make_tar(files);self.assertEqual(len(files),32)
            self.assertTrue(evidence.validate(raw,HEAD,'ordinary05',['git'],{},loaded,compile_ok))
            self.assertEqual(controller.validate_package(raw,{'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()},'ordinary05'),raw)
            for mutation in ('missing','extra','receipt','mode','source','staged','resource'):
                bad=copy.deepcopy(files)
                if mutation=='missing':del bad['npc-parent/runtime/receipt.json']
                elif mutation=='extra':bad['npc-parent/runtime/extra']=b'x'
                elif mutation=='receipt':bad['npc-parent/runtime/receipt.json']=b'{}'
                elif mutation=='mode':
                    v=json.loads(bad['smoke-summary.json']);v['phases'][1]['command'][-3]+=';unexpected=1';bad['smoke-summary.json']=json.dumps(v).encode()
                elif mutation=='source':
                    v=json.loads(bad['npc-parent/cloud-manifest.json']);v['original_git_files']['civ13.dme']['sha256']='0'*64;bad['npc-parent/cloud-manifest.json']=json.dumps(v).encode()
                elif mutation=='staged':
                    v=json.loads(bad['npc-smoke/cloud-manifest.json']);v['stage_files']['human_subtile.dme']['sha256']='0'*64;bad['npc-smoke/cloud-manifest.json']=json.dumps(v).encode()
                else:
                    v=json.loads(bad['smoke-summary.json']);v['artifacts']['baseline']['human_subtile.dmb']['mode']=0o600;bad['smoke-summary.json']=json.dumps(v).encode()
                with self.subTest(mutation=mutation),self.assertRaises((ValueError,KeyError,RuntimeError)):
                    evidence.validate(make_tar(bad),HEAD,'ordinary05',['git'],{},loaded,compile_ok)
            bad=make_tar(dict(files,**{'npc-parent/runtime/extra':b'x'}))
            with self.assertRaises(RuntimeError):controller.validate_package(bad,{'bytes':len(bad),'sha256':hashlib.sha256(bad).hexdigest()},'ordinary05')

    def test_scratch_estimate_targets_the_merged_game_tree(self):
        source=(HERE/'cloud_npc_job.py').read_text(encoding='utf-8')
        self.assertIn("if args.suite == 'ordinary05':",source)
        self.assertIn("estimate_head='5b0040a099cdacf1091bc8b4859c298f65dda63d'",source)
        self.assertIn("game_tree.decode().strip()=='6559a4507c5e874051966b55c758c2908541e711'",source)
        self.assertIn("['ls-tree','-r','-l','-z',estimate_head]",source)
        self.assertIn("record['scratch_source_head']=estimate_head",source)
    def test_container_and_scratch_limits_remain_bounded(self):
        args=controller.create_args('owned','b'*32,HEAD,Path('/source'),Path('/byond'),Path('/byond.zip'),'1001:1001','ordinary05',123.0)
        for flag,value in (('--network','none'),('--memory','3g'),('--cpus','2'),('--pids-limit','64')):
            self.assertEqual(args[args.index(flag)+1],value)
        self.assertIn('--read-only',args);self.assertIn('size=1073741824',args[args.index('--tmpfs')+1]);self.assertNotIn('--privileged',args)
        estimate=job.selected_estimate(b'100644 blob abc 100\tcode/example.dm\0','ordinary05')
        self.assertEqual(estimate['archive_and_stage_estimate_bytes'],200+32768)
        self.assertEqual(estimate['scratch_limit_bytes'],1024**3)


class WorkerControls(unittest.TestCase):
    def test_two_bounded_compiles_and_daemons(self):
        with tempfile.TemporaryDirectory(prefix='ordinary-worker-',dir=HERE) as temp:
            root=Path(temp).resolve();calls=[]
            def prepare(_root,out,_suite,fixture_source_head=None):
                self.assertEqual(fixture_source_head,stage.CANDIDATE_HEAD)
                st=out/'stage';st.mkdir(parents=True);(st/'human_subtile.dme').write_bytes(b'fixture')
                return {'head':stage.CANDIDATE_HEAD,'dme':'stage/human_subtile.dme','stage_files':{}}
            human=types.SimpleNamespace(prepare=prepare,validate_compile=lambda *_:None,inspect_logs=lambda *_:None)
            def pair(out,manifest,*args):
                parent=root/'npc-parent';(parent/'stage').mkdir(parents=True);(parent/'stage/human_subtile.dme').write_bytes(b'fixture')
                return parent,{'head':HEAD,'dme':'stage/human_subtile.dme','stage_files':{}}
            def compile_phase(_runner,_group,command,folder,name,timeout):
                calls.append(('compile',timeout));(folder/'compile-stdout.log').write_text('0 errors, 0 warnings\n');(folder/'compile-stderr.log').write_text('')
                return dict(command=command,seconds=0,returncode=0,timed_out=False,oversized_log=False,deadline=timeout)
            def linked(folder,stage_path,dme,name):
                work=folder/name;work.mkdir();dmb=work/'human_subtile.dmb';dmb.write_bytes(b'dmb');dmb.with_suffix('.rsc').write_bytes(b'rsc')
                return work,dmb,{'human_subtile.rsc':{'bytes':3,'sha256':'b'*64,'mode':0o600},'human_subtile.dmb':{'bytes':3,'sha256':'c'*64,'mode':0o444}}
            def daemon(_runner,_group,command,work,dme,peer,artifacts,resource,label,states,timeout):
                mode='legacy' if label=='baseline' else 'candidate'
                self.assertEqual(command[command.index('-params')+1],'tested_commit='+HEAD+';ordinary_bump_mode='+mode)
                calls.append(('daemon',mode,timeout));(work/'port-closed.txt').write_bytes(b'closed\n');(work/'result.txt').write_bytes(b'PASS\n')
                (work/'receipt.json').write_text(json.dumps(model.receipt(mode)));states[label]={'before':resource,'after':resource,'changed':False,'integrity_verified':True}
                return dict(command=command,seconds=0,returncode=0,timed_out=False,oversized_log=False,deadline=timeout)
            fake_binding=types.SimpleNamespace(validate_head=lambda *a,**k:TREE,read_inputs=lambda *a,**k:inputs())
            fake_mat=types.SimpleNamespace(prepare_pair=pair,runner_module=lambda *_:human)
            mods={'runner_limits':limits,'ordinary_bump_binding':fake_binding,'ordinary_bump_stage':stage,
                  'ordinary_bump_materialize':fake_mat,'ordinary_bump_receipt':receipt}
            shared=types.SimpleNamespace(HERE=HERE,ROOT=root,require=require,checkpoint=lambda *a,**k:None,
                run_owned_phase=compile_phase,prepare_linked_runtime=linked,run_checked_runtime=daemon,
                file_hash=lambda path:hashlib.sha256(path.read_bytes()).hexdigest())
            runtime=types.SimpleNamespace(verify_linux=lambda *_:None)
            args=types.SimpleNamespace(suite='ordinary05',head=HEAD,work_deadline=time.monotonic()+400)
            with patch.object(worker,'modules',return_value=mods),patch.object(worker.os.path,'samefile',return_value=False):
                worker.run(shared,args,root,root,root,None,{}, {}, {},time.monotonic(),None,runtime,None)
            self.assertEqual(calls,[('compile',90),('daemon','legacy',60),('compile',90),('daemon','candidate',60)])
            self.assertFalse(json.loads((root/'smoke-summary.json').read_text())['visual_or_broad_parity_established'])

    def test_short_deadline_refuses_before_staging(self):
        fake={'runner_limits':limits,'ordinary_bump_binding':None,'ordinary_bump_materialize':None,
              'ordinary_bump_receipt':None,'ordinary_bump_stage':None}
        shared=types.SimpleNamespace(require=require);args=types.SimpleNamespace(suite='ordinary05',work_deadline=time.monotonic()+100)
        with patch.object(worker,'modules',return_value=fake),self.assertRaises(ValueError):
            worker.run(shared,args,None,None,None,None,{}, {}, {},time.monotonic(),None,None,None)


if __name__=='__main__':unittest.main()