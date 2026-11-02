"""One bounded build and two sequential headless scheduler daemons."""
import json
import os
import time

def run(shared,args,scratch,binary,archive,group,envelope,identity,abi,began,npc,runtime,legacy):
    stage_tools=shared.load_module('scheduler_transition_stage',shared.HERE/'scheduler_transition_stage.py')
    contract=shared.load_module('scheduler_transition_contract',shared.HERE/'scheduler_transition_contract.py')
    binding=shared.load_module('scheduler_transition_binding',shared.HERE/'scheduler_transition_binding.py')
    compile_limit,daemon_limit,setup_limit,work_limit=120,90,60,490
    reserve=compile_limit+2*daemon_limit+setup_limit
    shared.require(args.suite=='transition05' and args.work_deadline is not None and time.monotonic()+reserve<=args.work_deadline,'Insufficient transition shared work deadline')
    binding.validate_source(['git','-C',str(shared.ROOT)],None,args.head,args.work_deadline-reserve)
    started=time.monotonic();child_elapsed=0.0
    def check_setup():
        used=time.monotonic()-started-child_elapsed
        shared.require(0<=used<=setup_limit,'Transition setup allowance exceeded')
        return used
    shared.checkpoint('transition-staging',suite=args.suite)
    out=scratch/'npc-smoke';manifest=npc.prepare_source(shared.ROOT,out)
    shared.require(manifest['head']==args.head,'Transition source head mismatch')
    stage_tools.adapt(out,manifest,npc.current)
    (out/'cloud-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    stage,dme=out/'stage',out/manifest['dme']
    def check_inputs():
        for rel,expected in manifest['stage_files'].items():
            path=stage/rel
            shared.require(path.is_file() and path.stat().st_size==expected['bytes'] and shared.file_hash(path)==expected['sha256'],'Transition fixture input changed: '+rel)
    check_inputs();check_setup();shared.checkpoint('transition-compile')
    runtime.verify_linux(binary,archive)
    build=shared.run_owned_phase(legacy,group,[str(binary/'DreamMaker'),'-max_errors','0',str(dme)],stage,'compile',compile_limit)
    shared.require(contract.number(build.get('seconds')) and 0<=build['seconds']<=compile_limit,'Transition compile duration')
    child_elapsed+=build['seconds']
    log=''.join((stage/('compile-'+part+'.log')).read_text(errors='replace') for part in ('stdout','stderr'))
    legacy.validate_compile(log,dme.with_suffix('.dmb').name);check_inputs();check_setup()
    work,dmb,artifacts=shared.prepare_linked_runtime(out,stage,dme,'runtime')
    peer,peer_dmb,peer_artifacts=shared.prepare_linked_runtime(out,stage,dme,'runtime-wildlife')
    resource=dme.with_suffix('.rsc').name
    shared.require(artifacts==peer_artifacts and not os.path.samefile(dmb.with_suffix('.rsc'),peer_dmb.with_suffix('.rsc')),'Transition resource copies not isolated')
    shared.checkpoint('transition-runtime-staged',runtime_artifacts=artifacts,resource_copies_independent=True)
    states={};results={};receipts={};peer_states={'legacy':dict(artifacts[resource]),'mixed':dict(artifacts[resource])}
    for label,folder,local_dmb,other,other_label in (('legacy',work,dmb,peer,'mixed'),('mixed',peer,peer_dmb,work,'legacy')):
        shared.checkpoint('transition-'+label+'-daemon')
        shared.require(not any(folder.rglob('*.sav')),'Transition daemon must start without saves')
        runtime.verify_linux(binary,archive)
        params='tested_commit='+args.head+';scheduler_mode='+label
        result=shared.run_checked_runtime(legacy,group,[str(binary/'DreamDaemon'),str(local_dmb),'59474','-ip','127.0.0.1','-trusted','-params',params,'-log','runtime.log'],folder,dme,other,artifacts,peer_states[other_label],label,states,timeout=daemon_limit)
        shared.require(contract.number(result.get('seconds')) and 0<=result['seconds']<=daemon_limit,'Transition daemon duration')
        child_elapsed+=result['seconds'];peer_states[label]=dict(states[label]['after']);legacy.inspect_logs(folder)
        shared.require((folder/'port-closed.txt').read_bytes()==b'closed\n' and (folder/'result.txt').read_bytes()==b'PASS\n','Transition fixture failed: '+label)
        receipt=folder/'receipt.json';shared.require(receipt.stat().st_size<=4*1024**2,'Transition receipt bound')
        receipts[label]=json.loads(receipt.read_text(encoding='utf-8'));contract.validate_receipt(receipts[label],args.head,label)
        results[label]={'daemon':result,'receipt_sha256':shared.file_hash(receipt)}
        check_inputs();check_setup()
    comparison=contract.compare_receipts(receipts['legacy'],receipts['mixed'],args.head)
    elapsed=time.monotonic()-started;setup=elapsed-child_elapsed
    shared.require(0<=setup<=setup_limit,'Transition final setup allowance exceeded')
    summary=dict(head=args.head,suite=args.suite,fixture_dme_only=True,observation_complete=True,parity_established=False,tick=0.5,compile=build,artifacts=artifacts,resource_states=states,identity=identity,abi=abi,envelope=envelope,results=results,comparison=comparison,scope=stage_tools.SCOPE,limits={'compile_seconds':compile_limit,'daemon_seconds':daemon_limit,'setup_seconds':setup_limit,'work_seconds':work_limit,'whole_seconds':600},setup_seconds=setup,comparison_elapsed=elapsed,child_elapsed=child_elapsed,seconds=time.monotonic()-began)
    (scratch/'smoke-summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
    shared.checkpoint('complete',outcome='passed',fixture_dme_only=True,suite=args.suite)
