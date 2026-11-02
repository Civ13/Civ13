"""Current-game ordinary bump pair within the existing bounded controller."""
import json
import os
import sys
import time


def modules(shared):
    names=('ordinary_bump_stage','ordinary_bump_binding','ordinary_bump_receipt',
           'ordinary_bump_materialize','runner_limits')
    result={}
    for name in names:
        shared.require(name not in sys.modules,'Unexpected preloaded ordinary bump module: '+name)
        module=shared.load_module(name,shared.HERE/(name+'.py'))
        sys.modules[name]=module;result[name]=module
    return result


def run(shared,args,scratch,binary,archive,group,envelope,identity,abi,began,npc,runtime,legacy):
    m=modules(shared); limits=m['runner_limits']; binding=m['ordinary_bump_binding']
    stage=m['ordinary_bump_stage']; materialize=m['ordinary_bump_materialize']; oracle=m['ordinary_bump_receipt']
    shared.require(args.suite=='ordinary05','Unexpected ordinary bump suite')
    limits.admission('bump05',time.monotonic(),args.work_deadline)
    git=['git','-c','core.fsmonitor=false','-c','core.hooksPath=/dev/null','-C',str(shared.ROOT)]
    tree=binding.validate_head(git,args.head,deadline=args.work_deadline)
    inputs=binding.read_inputs(git,deadline=args.work_deadline)
    limits.admission('bump05',time.monotonic(),args.work_deadline)
    fixture=(shared.HERE/'ordinary_bump_probe.dm').read_bytes()
    human=materialize.runner_module(inputs['runner'],shared.HERE/'run.py')
    started=time.monotonic();child_elapsed=0.0;phases=[]

    def check_setup():
        used=time.monotonic()-started-child_elapsed
        shared.require(0<=used<=limits.SETUP_SECONDS,'Ordinary bump setup allowance exceeded')
        return used

    shared.checkpoint('ordinary-bump-staging',suite=args.suite,fixture_dme_only=True)
    out=scratch/'npc-smoke'
    manifest=human.prepare(shared.ROOT,out,'human',fixture_source_head=stage.CANDIDATE_HEAD)
    parent,parent_manifest=materialize.prepare_pair(out,manifest,inputs['old_living'],inputs['new_living'],
        inputs['probe'],inputs['dme'],fixture,args.head)
    variants=(('baseline','legacy',parent,parent_manifest),('candidate','candidate',out,manifest))
    for label,mode,folder,data in variants:
        data['experiment_tree']=tree
        (folder/'cloud-manifest.json').write_text(json.dumps(data,indent=2)+'\n')

    def check_inputs():
        for label,mode,folder,data in variants:
            for rel,expected in data['stage_files'].items():
                path=folder/'stage'/rel
                shared.require(path.is_file() and not path.is_symlink() and path.stat().st_size==expected['bytes'] and
                               shared.file_hash(path)==expected['sha256'],'Ordinary bump fixture input changed: '+label+'/'+rel)

    builds={};artifacts_by_variant={};states={};receipts={};results={}
    for label,mode,folder,data in variants:
        check_inputs();limits.remaining(len(phases),check_setup(),time.monotonic(),args.work_deadline)
        stage_path,dme=folder/'stage',folder/data['dme']
        shared.checkpoint('ordinary-bump-'+label+'-compile')
        runtime.verify_linux(binary,archive)
        build=shared.run_owned_phase(human,group,[str(binary/'DreamMaker'),'-max_errors','0',str(dme)],
                                     stage_path,'compile',limits.COMPILE_SECONDS)
        shared.require(limits.finite(build.get('seconds')) and 0<=build['seconds']<=limits.COMPILE_SECONDS,'Compile duration')
        child_elapsed+=build['seconds'];phases.append(dict(build,name=label+'_compile'))
        log=''.join((stage_path/('compile-'+part+'.log')).read_text(errors='replace') for part in ('stdout','stderr'))
        human.validate_compile(log,dme.with_suffix('.dmb').name);builds[label]=build
        check_inputs();check_setup()
        work,dmb,artifacts=shared.prepare_linked_runtime(folder,stage_path,dme,'runtime')
        peer,peer_dmb,peer_artifacts=shared.prepare_linked_runtime(folder,stage_path,dme,'runtime-wildlife')
        resource=dme.with_suffix('.rsc').name
        shared.require(artifacts==peer_artifacts and not os.path.samefile(dmb.with_suffix('.rsc'),peer_dmb.with_suffix('.rsc')),
                       'Runtime resource copies are not independent')
        artifacts_by_variant[label]=artifacts
        shared.checkpoint('ordinary-bump-'+label+'-runtime-staged',resource_copies_independent=True)
        limits.remaining(len(phases),check_setup(),time.monotonic(),args.work_deadline)
        shared.require(not any(work.rglob('*.sav')),'Fresh runtime unexpectedly contains saves')
        runtime.verify_linux(binary,archive)
        params='tested_commit='+args.head+';ordinary_bump_mode='+mode
        result=shared.run_checked_runtime(human,group,
            [str(binary/'DreamDaemon'),str(dmb),'59474','-ip','127.0.0.1','-trusted','-params',params,'-log','runtime.log'],
            work,dme,peer,artifacts,dict(artifacts[resource]),label,states,timeout=limits.DAEMON_SECONDS)
        shared.require(limits.finite(result.get('seconds')) and 0<=result['seconds']<=limits.DAEMON_SECONDS,'Daemon duration')
        child_elapsed+=result['seconds'];phases.append(dict(result,name=label+'_daemon'))
        human.inspect_logs(work)
        shared.require((work/'port-closed.txt').read_bytes()==b'closed\n' and (work/'result.txt').read_bytes()==b'PASS\n',
                       'Ordinary bump fixture failed: '+label)
        path=work/'receipt.json';shared.require(path.stat().st_size<=4*1024**2,'Receipt byte bound')
        receipts[label]=json.loads(path.read_text());oracle.validate(receipts[label],mode,args.head)
        results[label]={'daemon':result,'receipt_sha256':shared.file_hash(path)}
        check_inputs();check_setup()
    comparison=oracle.compare(receipts['baseline'],receipts['candidate'],args.head)
    elapsed=time.monotonic()-started;setup=elapsed-child_elapsed
    limits.validate_accounting(phases,elapsed,setup)
    summary=dict(head=args.head,tree=tree,game_head=stage.CANDIDATE_HEAD,game_tree=stage.CANDIDATE_TREE,
        baseline_head=stage.BASE_HEAD,suite=args.suite,fixture_dme_only=True,observation_complete=True,
        visual_or_broad_parity_established=False,scope=oracle.SCOPE,tick=0.5,modes=['legacy','candidate'],
        cases=list(oracle.CASES),comparison=comparison,compiles=builds,artifacts=artifacts_by_variant,
        resource_states=states,results=results,phases=phases,identity=identity,abi=abi,envelope=envelope,
        limits={'compile_seconds':limits.COMPILE_SECONDS,'daemon_seconds':limits.DAEMON_SECONDS,
                'setup_seconds':limits.SETUP_SECONDS,'work_seconds':limits.WORK_SECONDS,'whole_seconds':limits.OUTER_SECONDS},
        setup_seconds=setup,comparison_elapsed=elapsed,child_elapsed=child_elapsed,seconds=time.monotonic()-began)
    (scratch/'smoke-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    shared.checkpoint('complete',outcome='passed',fixture_dme_only=True,suite=args.suite)