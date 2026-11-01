"""Offline transition staging, worker, selector and host-evidence contracts."""
import copy
import contextlib
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import tarfile
import tempfile
import time
import types
import unittest
from unittest.mock import patch

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
def load(name):
    spec=importlib.util.spec_from_file_location(name,HERE/(name+'.py'))
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result
stage=load('transition_stage');contract=load('transition_contract');random=load('random_cadence_contract')
evidence=load('transition_evidence');worker=load('transition_worker');controller=load('cloud_npc_controller')
smoke=load('cloud_npc_smoke')
rows=load('test_transition_contract')
HEAD='a'*40

class Adaptor:
    @staticmethod
    def adapt(out,manifest,rel,old,new):
        path=out/'stage'/rel;text=path.read_text(encoding='utf-8')
        if text.count(old)!=1: raise ValueError('preimage: '+rel)
        path.write_text(text.replace(old,new,1),encoding='utf-8',newline='\n')


def data():
    source={p:(ROOT/p).read_bytes() for p in (stage.MOVEMENT,*stage.SPECIES,stage.PROBE,stage.RANDOM,stage.CORE,stage.FIXTURE)}
    source['civ13.dme']=b'#include "code/world.dm"\n#include "maps/unused.dmm"\n'
    with tempfile.TemporaryDirectory() as tmp:
        out=Path(tmp);dest=out/'stage';dest.mkdir()
        for rel,raw in source.items():
            path=dest/rel;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(raw)
        probe=dest/stage.PROBE;text=probe.read_text(encoding='utf-8')
        text=text.replace('\t\t\thuman_subtile_fixture_headless()','\t\t\tnpc_subtile_fixture()',1)
        text=text.replace('"checks" = human_subtile_fixture_checks,',
             '"checks" = human_subtile_fixture_checks, "npc_checks" = npc_subtile_checks, "npc_rows" = npc_subtile_rows,',1)
        probe.write_text(text,encoding='utf-8',newline='\n')
        dme=re.sub(r'^#include ".*\.dmm"\s*$','',source['civ13.dme'].decode(),flags=re.M)
        dme+='\n#include "tests\\human_subtile\\mining.dm"\n#include "tests\\human_subtile\\probe.dm"\n'
        dme+='\n#include "tests\\human_subtile\\npc.dm"\n'
        (dest/'human_subtile.dme').write_text(dme,encoding='utf-8',newline='\n')
        manifest={'head':HEAD,'dme':'stage/human_subtile.dme','stage_files':{
            p:{'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()} for p,raw in source.items()}}
        stage.adapt(out,manifest,Adaptor,random,contract.SCOPE)
        observer=(dest/stage.RANDOM).read_text(encoding='utf-8').split('/proc/fixture_random_observe(',1)[1].split('/mob/living/',1)[0]
        assert '"recovery" = A.npc_subtile_recovery ?' in observer and '"tx_intent" = T && T.intent_owner ?' in observer
        for forbidden in ('sleep(', 'prob(', 'rand(', 'Move(', 'step(', 'walk(', 'spawn(', 'qdel('):
            assert forbidden not in observer
        with unittest.TestCase().assertRaises(ValueError): stage.adapt(out,manifest,Adaptor,random,contract.SCOPE)
    cases=[rows.row('blocked'),rows.row('cancel_replace')]
    for case in cases:
        case['start']+=1;case['end']+=1
        for event in case['events']:
            event['at']+=1
            if isinstance(event.get('detail'),dict) and 'old_end' in event['detail']:
                event['detail']['old_end']+=1
    receipt={'head':HEAD,'error':None,'port':0,'byond_version':516,'byond_build':1688,'scope':contract.SCOPE,
             'movement_blob':contract.MOVEMENT_BLOB,'overflow':0,'setup':{'requested_tick':.5,'actual_tick':.5,
             'startup_time':0,'ready_time':.5,'startup_usage':10000,'ready_usage':1},'transition_rows':cases,
             'transition_case':'cancel_replace','transition_checks':1,'transition_partial':cases[-1]['events']}
    raw=json.dumps(receipt).encode();resource={'bytes':3,'sha256':'b'*64,'mode':0o600}
    states={'transition':{'before':resource,'after':resource,'changed':False,'integrity_verified':True}}
    phase=lambda limit:{'returncode':0,'timed_out':False,'oversized_log':False,'deadline':limit,'seconds':1}
    summary={'head':HEAD,'suite':'transition05','tick':.5,'fixture_dme_only':True,'observation_complete':True,
             'parity_established':False,'scope':contract.SCOPE,'compile':phase(90),'resource_states':states,
             'artifacts':{'human_subtile.rsc':resource},'result':{'daemon':phase(60),'receipt_sha256':hashlib.sha256(raw).hexdigest()},
             'observation':contract.validate_receipt(receipt,HEAD),
             'limits':{'compile_seconds':90,'daemon_seconds':60,'setup_seconds':60,'work_seconds':490,'whole_seconds':600},
             'child_elapsed':2,'comparison_elapsed':3,'setup_seconds':1}
    status={'head':HEAD,'suite':'transition05','phase':'complete','outcome':'passed','fixture_dme_only':True,'runtime_resources':states}
    files={'harness-status.json':json.dumps(status).encode(),'smoke-summary.json':json.dumps(summary).encode(),
           'npc-smoke/cloud-manifest.json':json.dumps(manifest).encode(),
           'npc-smoke/stage/compile-stdout.log':b'0 errors, 0 warnings\n','npc-smoke/stage/compile-stderr.log':b''}
    for name,value in (('receipt.json',raw),('result.txt',b'PASS\n'),('port-closed.txt',b'closed\n'),
                       ('runtime.log',b''),('daemon-stdout.log',b''),('daemon-stderr.log',b'')):
        files['npc-smoke/runtime/'+name]=value
    files.update({f'abi/abi-{i}-{part}.log':b'' for i in range(6) for part in ('stdout','stderr')})
    return source,files


def package(files):
    result=io.BytesIO()
    with tarfile.open(fileobj=result,mode='w') as tar:
        for name,data in files.items():
            item=tarfile.TarInfo(name);item.size=len(data);tar.addfile(item,io.BytesIO(data))
    return result.getvalue()


class IntegrationTests(unittest.TestCase):
    def test_actual_transport_and_container_command_are_narrow(self):
        _,files=data()
        self.assertTrue(set(files)<=set(smoke.EVIDENCE_PATHS))
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            for name,raw in files.items():
                path=root/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(raw)
            captured=io.StringIO()
            with patch.object(smoke,'RUN_STATE',{'suite':'transition05'}),contextlib.redirect_stdout(captured):
                smoke.emit_package(root,'passed',{'samples':1})
            output=captured.getvalue().encode();marker=json.loads(output.splitlines()[-1].split(b' ',1)[1])
            self.assertTrue(marker['package']['complete'])
            raw=controller.package_from_logs(output,marker,'transition05')
            with tarfile.open(fileobj=io.BytesIO(raw)) as archive:self.assertEqual(set(archive.getnames()),set(files))
        args=controller.create_args('owned','b'*32,HEAD,Path('/source'),Path('/byond'),Path('/byond.zip'),
                                    '1001:1001','transition05',123.0)
        self.assertIn('--network',args);self.assertEqual(args[args.index('--network')+1],'none')
        self.assertIn('--read-only',args);self.assertIn('--pids-limit',args)
        self.assertEqual(args[args.index('--pids-limit')+1],'64')
        self.assertEqual(args[args.index('--memory')+1],'3g')
        self.assertEqual(args[args.index('--cpus')+1],'2')
        self.assertIn('transition05',args);self.assertIn('--work-deadline',args)
        with self.assertRaises(RuntimeError):
            controller.create_args('owned','b'*32,HEAD,Path('/source'),Path('/byond'),Path('/byond.zip'),
                                   '1001:1001','transition05',None)
        image='sha256:'+'d'*64
        mounts=((Path('/reviewed'),'/source'),(Path('/bin-by'),'/opt/byond/bin'),(Path('/by.zip'),'/inputs/byond.zip'))
        cmd=['-I','-B','/source/tests/human_subtile/cloud_npc_smoke.py','--head',HEAD,
             '--byond-bin','/opt/byond/bin','--byond-archive','/inputs/byond.zip',
             '--scratch-root','/work','--reviewed-cloud-envelope','--suite','transition05','--work-deadline','123.0']
        row={'Image':image,'Config':{'Image':controller.IMAGE,'User':'1001:1001',
             'Entrypoint':['/usr/local/bin/python3.12'],'Cmd':cmd,'Env':['LANG=C.UTF-8']},
             'HostConfig':{'Memory':3*1024**3,'MemorySwap':3*1024**3,'PidsLimit':64,'NanoCpus':2000000000,
             'NetworkMode':'none','ReadonlyRootfs':True,'Privileged':False,'CgroupnsMode':'private',
             'IpcMode':'private','PidMode':'','CapDrop':['ALL'],'SecurityOpt':['no-new-privileges'],
             'PortBindings':None,'Devices':None,'Binds':None,
             'Tmpfs':{'/work':'rw,noexec,nosuid,nodev,size=1073741824,mode=1777'},'ShmSize':1048576,
             'LogConfig':{'Type':'local','Config':{'max-size':'1m','max-file':'1','compress':'false'}}},
             'Mounts':[{'Source':str(src),'Destination':dest,'RW':False,'Type':'bind'} for src,dest in mounts]}
        controller.inspect_settings(row,image,mounts,'1001:1001',HEAD,'transition05',123.0)
        row['HostConfig']['NetworkMode']='host'
        with self.assertRaises(RuntimeError):
            controller.inspect_settings(row,image,mounts,'1001:1001',HEAD,'transition05',123.0)

    def test_full_host_receipt_and_negative_archives(self):
        sources,files=data();self.assertEqual(len(files),23)
        fake_npc=types.SimpleNamespace(current=types.SimpleNamespace(legacy=types.SimpleNamespace(validate_compile=lambda *_:None)))
        mods={'transition_contract':contract,'transition_stage':stage,'random_cadence_contract':random,'run-npc':fake_npc}
        with patch.object(evidence,'module',side_effect=lambda name:mods[name]), \
             patch.object(evidence.subprocess,'check_output',side_effect=lambda cmd,**_:sources[cmd[-1].split(':',1)[1]]), \
             patch.object(contract,'validate_source',return_value=True) as binding:
            evidence.validate(package(files),HEAD,'transition05',['git'],{});binding.assert_called_once()
            for mutate in (lambda x:x.pop('npc-smoke/runtime/receipt.json'),
                           lambda x:x.update({'npc-smoke/runtime/extra':b'x'}),
                           lambda x:x.update({'npc-smoke/runtime/receipt.json':b'{}'}),
                           lambda x:x.update({'npc-smoke/cloud-manifest.json':b'{}'})):
                bad=copy.deepcopy(files);mutate(bad)
                with self.assertRaises((ValueError,KeyError)):evidence.validate(package(bad),HEAD,'transition05',['git'],{})
        raw=package(files);meta={'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
        self.assertEqual(controller.validate_package(raw,meta,'transition05'),raw)
        extra=dict(files);extra['npc-smoke/runtime-wildlife/receipt.json']=b'x';raw=package(extra)
        with self.assertRaises(RuntimeError):controller.validate_package(raw,{'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()},'transition05')
        for name in ('../escape','npc-smoke/runtime/unknown'):
            extra=dict(files);extra[name]=b'x';raw=package(extra)
            with self.assertRaises(RuntimeError):controller.validate_package(raw,{'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()},'transition05')
        buf=io.BytesIO()
        with tarfile.open(fileobj=buf,mode='w') as tar:
            for name,value in files.items():
                entry=tarfile.TarInfo(name);entry.size=len(value);tar.addfile(entry,io.BytesIO(value))
            entry=tarfile.TarInfo('npc-smoke/runtime/receipt.json');entry.type=tarfile.SYMTYPE;entry.linkname='other';tar.addfile(entry)
        raw=buf.getvalue()
        with self.assertRaises(RuntimeError):controller.validate_package(raw,{'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()},'transition05')

    def test_worker_runs_one_compile_and_one_daemon_with_deadline(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);calls=[]
            def require(ok,msg):
                if not ok: raise RuntimeError(msg)
            def prepare(out):
                (out/'stage').mkdir(parents=True);(out/'stage/human_subtile.dme').write_text('fixture')
                return {'head':HEAD,'dme':'stage/human_subtile.dme','stage_files':{}}
            def compile_phase(_legacy,_group,cmd,path,name,limit):
                calls.append(('compile',limit));(path/'compile-stdout.log').write_text('ok');(path/'compile-stderr.log').write_text('')
                return {'seconds':0}
            def linked(out,stage_dir,dme,name):
                folder=out/name;folder.mkdir();return folder,folder/'human_subtile.dmb',{'human_subtile.rsc':{'mode':384}}
            def daemon(_legacy,_group,cmd,folder,dme,peer,artifacts,peer_expected,label,states,timeout):
                calls.append(('daemon',label,timeout,cmd[cmd.index('-params')+1]));states[label]={'after':{'mode':384}}
                (folder/'port-closed.txt').write_bytes(b'closed\n');(folder/'result.txt').write_bytes(b'PASS\n')
                (folder/'receipt.json').write_text('{}');return {'seconds':0}
            fake_contract=types.SimpleNamespace(SCOPE='scope',TICK=.5,number=contract.number,
                validate_source=lambda git,env,head:calls.append(('source',)),validate_receipt=lambda receipt,head:['ok'])
            fake_stage=types.SimpleNamespace(adapt=lambda *args:calls.append(('adapt',)))
            shared=types.SimpleNamespace(HERE=HERE,ROOT=root,load_module=lambda name,_:{'transition_stage':fake_stage,
                'transition_contract':fake_contract,'random_contract':object()}[name],require=require,checkpoint=lambda *a,**k:None,
                run_owned_phase=compile_phase,prepare_linked_runtime=linked,run_checked_runtime=daemon,file_hash=lambda p:'b'*64)
            npc=types.SimpleNamespace(prepare=prepare,current=object());runtime=types.SimpleNamespace(verify_linux=lambda *_:None)
            legacy=types.SimpleNamespace(validate_compile=lambda *_:None,inspect_logs=lambda *_:None)
            args=types.SimpleNamespace(suite='transition05',head=HEAD,work_deadline=time.monotonic()+400)
            with patch.object(worker.os.path,'samefile',return_value=False):
                worker.run(shared,args,root,root,root,None,{}, {}, {},time.monotonic(),npc,runtime,legacy)
            self.assertEqual([x[:2] for x in calls],[('source',),('adapt',),('compile',90),('daemon','transition')])
            self.assertIn('transition_tick=0.5',calls[-1][3]);self.assertEqual(calls[-1][2],60)
            self.assertFalse(json.loads((root/'smoke-summary.json').read_text())['parity_established'])
            args.work_deadline=time.monotonic()+1
            with self.assertRaisesRegex(RuntimeError,'Insufficient transition'):
                worker.run(shared,args,root,root,root,None,{}, {}, {},time.monotonic(),npc,runtime,legacy)
            args.suite='cardinal05';args.work_deadline=time.monotonic()+400
            with self.assertRaisesRegex(RuntimeError,'Insufficient transition'):
                worker.run(shared,args,root,root,root,None,{}, {}, {},time.monotonic(),npc,runtime,legacy)


if __name__=='__main__':unittest.main()
