"""One fixture compile and one fresh headless transition daemon."""
import json
import os
import time


def run(shared,args,scratch,binary,archive,group,envelope,identity,abi,began,npc,runtime,legacy):
    stage_tools=shared.load_module('transition_stage',shared.HERE/'transition_stage.py')
    contract=shared.load_module('transition_contract',shared.HERE/'transition_contract.py')
    random=shared.load_module('random_contract',shared.HERE/'random_cadence_contract.py')
    compile_limit,daemon_limit,setup_limit,work_limit=90,60,60,490
    shared.require(args.suite=='transition05' and args.work_deadline is not None and
                   time.monotonic()+compile_limit+daemon_limit+setup_limit <= args.work_deadline,
                   'Insufficient transition shared work deadline')
    contract.validate_source(['git','-C',str(shared.ROOT)],None,args.head)
    started=time.monotonic(); child_elapsed=0.0
    def check_setup():
        used=time.monotonic()-started-child_elapsed
        shared.require(0 <= used <= setup_limit,'Transition setup allowance exceeded')
        return used
    shared.checkpoint('transition-staging',suite=args.suite)
    out=scratch/'npc-smoke'; manifest=npc.prepare(out)
    shared.require(manifest['head']==args.head,'Transition source head mismatch')
    stage_tools.adapt(out,manifest,npc.current,random,contract.SCOPE)
    (out/'cloud-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    stage,dme=out/'stage',out/manifest['dme']
    def check_inputs():
        for rel,expected in manifest['stage_files'].items():
            path=stage/rel
            shared.require(path.is_file() and path.stat().st_size==expected['bytes'] and
                           shared.file_hash(path)==expected['sha256'],'Transition fixture input changed: '+rel)
    check_inputs();check_setup();shared.checkpoint('transition-compile')
    runtime.verify_linux(binary,archive)
    build=shared.run_owned_phase(legacy,group,[str(binary/'DreamMaker'),'-max_errors','0',str(dme)],stage,'compile',compile_limit)
    shared.require(contract.number(build.get('seconds')) and 0<=build['seconds']<=compile_limit,'Transition compile duration')
    child_elapsed+=build['seconds']
    log=''.join((stage/('compile-'+part+'.log')).read_text(errors='replace') for part in ('stdout','stderr'))
    legacy.validate_compile(log,dme.with_suffix('.dmb').name)
    check_inputs();check_setup()
    work,dmb,artifacts=shared.prepare_linked_runtime(out,stage,dme,'runtime')
    peer,peer_dmb,peer_artifacts=shared.prepare_linked_runtime(out,stage,dme,'runtime-wildlife')
    resource=dme.with_suffix('.rsc').name
    shared.require(artifacts==peer_artifacts and not os.path.samefile(dmb.with_suffix('.rsc'),peer_dmb.with_suffix('.rsc')),
                   'Transition resource copies not isolated')
    shared.require(not any(work.rglob('*.sav')),'Transition runtime must start with fresh saves')
    runtime.verify_linux(binary,archive); states={}
    params='tested_commit='+args.head+';transition_tick=0.5'
    result=shared.run_checked_runtime(legacy,group,
        [str(binary/'DreamDaemon'),str(dmb),'59474','-ip','127.0.0.1','-trusted','-params',params,'-log','runtime.log'],
        work,dme,peer,artifacts,dict(artifacts[resource]),'transition',states,timeout=daemon_limit)
    shared.require(contract.number(result.get('seconds')) and 0<=result['seconds']<=daemon_limit,'Transition daemon duration')
    child_elapsed+=result['seconds'];legacy.inspect_logs(work)
    shared.require((work/'port-closed.txt').read_bytes()==b'closed\n' and
                   (work/'result.txt').read_bytes()==b'PASS\n','Transition fixture failed')
    receipt=work/'receipt.json'
    shared.require(receipt.stat().st_size<=4*1024**2,'Transition receipt bound')
    observed=contract.validate_receipt(json.loads(receipt.read_text()),args.head)
    check_inputs();check_setup()
    elapsed=time.monotonic()-started;setup=elapsed-child_elapsed
    shared.require(0<=setup<=setup_limit,'Transition final setup allowance exceeded')
    summary=dict(head=args.head,suite=args.suite,fixture_dme_only=True,observation_complete=True,
        parity_established=False,tick=contract.TICK,compile=build,artifacts=artifacts,resource_states=states,
        identity=identity,abi=abi,envelope=envelope,result={'daemon':result,'receipt_sha256':shared.file_hash(receipt)},
        observation=observed,scope=contract.SCOPE,
        limits={'compile_seconds':compile_limit,'daemon_seconds':daemon_limit,'setup_seconds':setup_limit,
                'work_seconds':work_limit,'whole_seconds':600},setup_seconds=setup,
        comparison_elapsed=elapsed,child_elapsed=child_elapsed,seconds=time.monotonic()-began)
    (scratch/'smoke-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    shared.checkpoint('complete',outcome='passed',fixture_dme_only=True,suite=args.suite)
