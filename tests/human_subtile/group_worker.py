"""One compile and one daemon; synthetic native group-Bump observation only."""
import hashlib,importlib.util,json,os,shutil,stat,sys,time
from pathlib import Path

def _load(name,path):
    spec=importlib.util.spec_from_file_location(name,path);module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module);return module

def _regular(path,limit,allow_empty=False):
    info=path.lstat()
    if not stat.S_ISREG(info.st_mode) or (not allow_empty and info.st_size==0) or info.st_size>limit:
        raise ValueError('unsafe or oversized file: '+path.name)
    return info

def _record(path,limit):
    info=_regular(path,limit)
    with path.open('rb') as f:digest=hashlib.file_digest(f,'sha256').hexdigest()
    return {'bytes':info.st_size,'sha256':digest}

def run(shared,args,scratch,binary,archive,group,envelope,identity,abi,began,npc,runtime,legacy):
    if args.suite!='group05':raise ValueError('wrong group suite')
    binding=_load('group_binding_worker',shared.HERE/'group_binding.py')
    oracle=_load('group_oracle_worker',shared.HERE/'native_group'/'validate_receipt.py')
    shared.checkpoint('group-source-binding',suite='group05',fixture_dme_only=True)
    git=['git','-c','core.fsmonitor=false','-c','core.hooksPath=/dev/null','-C',str(shared.ROOT)]
    tree=binding.validate_head(git,args.head,deadline=args.work_deadline)
    if args.work_deadline is None or args.work_deadline-time.monotonic()<190:raise TimeoutError('insufficient group compile/daemon reserve')
    root=scratch/'npc-smoke';stage=root/'stage';work=root/'runtime'
    stage.mkdir(parents=True);work.mkdir()
    sources={}
    for name,expected in binding.INPUTS.items():
        source=shared.HERE/'native_group'/name
        _regular(source,4*1024**2)
        if shared.file_hash(source)!=expected:raise ValueError('checkout bytes differ: '+name)
        sources[name]={'bytes':source.stat().st_size,'sha256':expected}
        if name in ('native-group-probe.dm','native-group-probe.dme'):
            with source.open('rb') as r,(stage/name).open('xb') as w:shutil.copyfileobj(r,w,1024*1024)
            if shared.file_hash(stage/name)!=expected:raise ValueError('stage input mismatch: '+name)
    manifest={'head':args.head,'tree':tree,'parent':binding.PARENT,'source':sources,
              'scope':'standalone synthetic full-tile group Bump; no Civ13 gameplay'}
    (root/'cloud-manifest.json').write_text(json.dumps(manifest,sort_keys=True)+'\n',encoding='utf-8')
    dme=stage/'native-group-probe.dme'
    def check_inputs():
        for name in ('native-group-probe.dm','native-group-probe.dme'):
            _regular(stage/name,4*1024**2)
            if shared.file_hash(stage/name)!=binding.INPUTS[name]:raise ValueError('fixture source modified: '+name)
    runtime.verify_linux(binary,archive);shared.checkpoint('group-compile',suite='group05')
    build=shared.run_owned_phase(legacy,group,[str(binary/'DreamMaker'),'-max_errors','0',str(dme)],stage,'compile',90)
    if not isinstance(build.get('seconds'),(int,float)) or not 0<=build['seconds']<=90:raise ValueError('invalid compile duration')
    log=''.join((stage/('compile-'+part+'.log')).read_text(errors='replace') for part in ('stdout','stderr'))
    legacy.validate_compile(log,'native-group-probe.dmb');check_inputs()
    artifacts={};dmb=dme.with_suffix('.dmb');artifacts[dmb.name]=_record(dmb,1024**3)
    os.chmod(dmb,0o444);os.link(dmb,work/dmb.name)
    if not os.path.samefile(dmb,work/dmb.name):raise ValueError('DMB staging not shared read-only')
    rsc=dme.with_suffix('.rsc');runtime_rsc=work/rsc.name
    if rsc.exists():
        artifacts[rsc.name]=_record(rsc,1024**3)
        with rsc.open('rb') as r,runtime_rsc.open('xb') as w:shutil.copyfileobj(r,w,1024*1024)
        os.chmod(runtime_rsc,0o600)
        if os.path.samefile(rsc,runtime_rsc) or _record(runtime_rsc,1024**3)!=artifacts[rsc.name]:raise ValueError('resource staging mismatch')
    if any(work.rglob('*.sav')) or (work/'native-group-receipt.json').exists():raise ValueError('runtime is not fresh')
    if args.work_deadline-time.monotonic()<75:raise TimeoutError('insufficient group daemon reserve')
    runtime.verify_linux(binary,archive);shared.checkpoint('group-daemon',suite='group05',artifacts=artifacts)
    resource={'before':_record(runtime_rsc,1024**3) if runtime_rsc.exists() else None,'after':None}
    child_error=None;result=None
    try:
        result=shared.run_owned_phase(legacy,group,[str(binary/'DreamDaemon'),str(work/dmb.name),'59474','-ip','127.0.0.1','-trusted','-log','runtime.log'],work,'daemon',60)
    except BaseException as exc:
        child_error=exc
    finally:
        try:
            raw=work/'native-group-receipt.json'
            if raw.exists():
                _regular(raw,4*1024**2)
                with raw.open('rb') as r,(work/'receipt.json').open('xb') as w:shutil.copyfileobj(r,w,1024*1024)
            resource['after']=_record(runtime_rsc,1024**3) if runtime_rsc.exists() else None
            if any(work.rglob('*.sav')):raise ValueError('fixture unexpectedly wrote a save')
            if _record(dmb,1024**3)!=artifacts[dmb.name] or _record(work/dmb.name,1024**3)!=artifacts[dmb.name]:raise ValueError('DMB changed')
            if rsc.exists() != (rsc.name in artifacts):raise ValueError('compiler resource presence changed')
            if rsc.exists() and _record(rsc,1024**3)!=artifacts[rsc.name]:raise ValueError('compiler resource changed')
            check_inputs()
            shared.checkpoint('group-daemon-finished',suite='group05',resource=resource,child_error=type(child_error).__name__ if child_error else None)
        except BaseException as exc:
            shared.checkpoint('group-daemon-evidence-error',suite='group05',error_type=type(exc).__name__,error_message=str(exc)[:512])
            if child_error is None:child_error=exc
    if child_error is not None:raise child_error
    if not isinstance(result.get('seconds'),(int,float)) or not 0<=result['seconds']<=60:raise ValueError('invalid daemon duration')
    legacy.inspect_logs(work)
    receipt_file=work/'receipt.json';_regular(receipt_file,4*1024**2)
    receipt=json.loads(receipt_file.read_text(encoding='utf-8'))
    observation=oracle.validate(receipt)
    summary={'head':args.head,'tree':tree,'parent':binding.PARENT,'suite':'group05','fixture_dme_only':True,
             'scope':manifest['scope'],'parity_established':False,'observation':observation,
             'compile':build,'daemon':result,'artifacts':artifacts,'resource':resource,
             'receipt_sha256':shared.file_hash(receipt_file),'identity':identity,'abi':abi,'envelope':envelope,
             'seconds':time.monotonic()-began}
    (scratch/'smoke-summary.json').write_text(json.dumps(summary,sort_keys=True)+'\n',encoding='utf-8')
    if observation.get('status')!='observed_consistent_on_this_trace':
        shared.checkpoint('group-observation-failed',suite='group05',observation=observation)
        raise ValueError('group observation: '+str(observation.get('status')))
    shared.checkpoint('complete',outcome='passed',suite='group05',fixture_dme_only=True,observation=observation)
