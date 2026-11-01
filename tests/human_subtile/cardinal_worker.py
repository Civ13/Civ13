"""Single-build, two-daemon isolated cardinal observation worker."""
import json
import os
import time


def run(shared, args, scratch, binary, archive, group, envelope, identity, abi, began, npc, runtime, legacy):
    stage_tools = shared.load_module('cardinal_stage', shared.HERE/'cardinal_stage.py')
    contract = shared.load_module('cardinal_contract', shared.HERE/'cardinal_contract.py')
    random = shared.load_module('random_contract', shared.HERE/'random_cadence_contract.py')
    tick = {'cardinal05': .5, 'cardinal10': 1.0}[args.suite]
    compile_limit, daemon_limit, setup_limit, work_limit = 90, 60, 60, 490
    shared.require(args.work_deadline is not None and
                   time.monotonic() + compile_limit + 2*daemon_limit + setup_limit <= args.work_deadline,
                   'Insufficient cardinal shared work deadline')
    started = time.monotonic()
    child_elapsed = 0.0
    contract.validate_source(['git','-C',str(shared.ROOT)],None,args.head)
    def check_setup():
        used = time.monotonic() - started - child_elapsed
        shared.require(0 <= used <= setup_limit, 'Cardinal setup allowance exceeded')
        return used
    shared.checkpoint('cardinal-staging', suite=args.suite)
    out = scratch/'npc-smoke'
    manifest = npc.prepare(out)
    shared.require(manifest['head'] == args.head, 'Cardinal source head mismatch')
    stage_tools.adapt(out, manifest, npc.current, random, contract.SCOPE)
    (out/'cloud-manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    stage, dme = out/'stage', out/manifest['dme']
    def check_inputs():
        for rel, expected in manifest['stage_files'].items():
            p = stage/rel
            shared.require(p.is_file() and p.stat().st_size == expected['bytes'] and
                           shared.file_hash(p) == expected['sha256'], 'Cardinal fixture input changed: '+rel)
    check_inputs(); check_setup()
    shared.checkpoint('cardinal-compile')
    runtime.verify_linux(binary, archive)
    build = shared.run_owned_phase(legacy, group, [str(binary/'DreamMaker'), '-max_errors', '0', str(dme)],
                                   stage, 'compile', compile_limit)
    shared.require(contract.number(build.get('seconds')) and 0 <= build['seconds'] <= compile_limit,
                   'Cardinal compile duration')
    child_elapsed += build['seconds']
    log = ''.join((stage/('compile-'+part+'.log')).read_text(errors='replace') for part in ('stdout','stderr'))
    legacy.validate_compile(log, dme.with_suffix('.dmb').name)
    check_inputs(); check_setup()
    work,dmb,artifacts = shared.prepare_linked_runtime(out,stage,dme,'runtime')
    peer,peer_dmb,peer_artifacts = shared.prepare_linked_runtime(out,stage,dme,'runtime-wildlife')
    resource = dme.with_suffix('.rsc').name
    shared.require(artifacts == peer_artifacts and not os.path.samefile(dmb.with_suffix('.rsc'), peer_dmb.with_suffix('.rsc')),
                   'Cardinal runtime resources not isolated')
    states, results, receipts = {}, {}, {}
    peer_states = {mode: dict(artifacts[resource]) for mode in contract.MODES}
    for mode, folder, local_dmb, other, other_mode in (('legacy',work,dmb,peer,'smooth'),
                                                        ('smooth',peer,peer_dmb,work,'legacy')):
        shared.checkpoint('cardinal-'+mode+'-daemon')
        shared.require(not any(folder.rglob('*.sav')), 'Cardinal runtime must start with fresh saves')
        runtime.verify_linux(binary, archive)
        params = 'tested_commit='+args.head+';cardinal_mode='+mode+';cardinal_tick='+str(tick)
        result = shared.run_checked_runtime(legacy, group,
            [str(binary/'DreamDaemon'),str(local_dmb),'59474','-ip','127.0.0.1','-trusted','-params',params,'-log','runtime.log'],
            folder,dme,other,artifacts,peer_states[other_mode],mode,states,timeout=daemon_limit)
        shared.require(contract.number(result.get('seconds')) and 0 <= result['seconds'] <= daemon_limit,
                       'Cardinal daemon duration')
        child_elapsed += result['seconds']
        peer_states[mode] = dict(states[mode]['after'])
        legacy.inspect_logs(folder)
        shared.require((folder/'port-closed.txt').read_bytes()==b'closed\n' and
                       (folder/'result.txt').read_bytes()==b'PASS\n', 'Cardinal fixture failed: '+mode)
        receipt = folder/'receipt.json'
        shared.require(receipt.stat().st_size <= 4*1024**2, 'Cardinal receipt bound')
        receipts[mode] = json.loads(receipt.read_text())
        contract.validate_receipt(receipts[mode],args.head,mode,tick)
        results[mode] = {'daemon':result, 'receipt_sha256':shared.file_hash(receipt)}
        check_inputs(); check_setup()
    comparison = contract.compare(receipts,args.head,tick)
    comparison_elapsed = time.monotonic()-started
    setup_seconds = comparison_elapsed-child_elapsed
    shared.require(0 <= setup_seconds <= setup_limit, 'Cardinal final setup allowance exceeded')
    summary = dict(head=args.head,suite=args.suite,fixture_dme_only=True,observation_complete=True,
        parity_established=False,tick=tick,compile=build,artifacts=artifacts,resource_states=states,
        identity=identity,abi=abi,envelope=envelope,results=results,comparison=comparison,scope=contract.SCOPE,
        limits={'compile_seconds':compile_limit,'daemon_seconds':daemon_limit,'setup_seconds':setup_limit,
                'work_seconds':work_limit,'whole_seconds':600},setup_seconds=setup_seconds,
        comparison_elapsed=comparison_elapsed,child_elapsed=child_elapsed,seconds=time.monotonic()-began)
    (scratch/'smoke-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    shared.checkpoint('complete',outcome='passed',fixture_dme_only=True,suite=args.suite)
