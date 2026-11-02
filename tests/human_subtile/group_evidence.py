"""Host validation for standalone group-Bump evidence; no gameplay parity claim."""
import hashlib,importlib.util,io,json,math,re,tarfile
from pathlib import Path,PurePosixPath
HERE=Path(__file__).resolve().parent

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

def require(value,message):
    if not value:raise ValueError(message)

def artifact(value):
    return (isinstance(value,dict) and set(value)=={'bytes','sha256'} and type(value['bytes']) is int and
            0<value['bytes']<=1024**3 and re.fullmatch('[0-9a-f]{64}',value['sha256'] or '') is not None)

def phase(row,command,limit):
    return (isinstance(row,dict) and row.get('command')==command and type(row.get('returncode')) is int and row['returncode']==0 and
            row.get('timed_out') is False and row.get('oversized_log') is False and
            type(row.get('seconds')) in (int,float) and math.isfinite(row['seconds']) and 0<=row['seconds']<=limit and
            row.get('deadline')==limit)

def validate(data,head,suite,git,env,deadline=None):
    require(suite=='group05','wrong suite')
    binding=load('group_binding_host',HERE/'group_binding.py');tree=binding.validate_head(git,head,env,deadline)
    oracle=load('group_oracle_host',HERE/'native_group'/'validate_receipt.py')
    legacy=load('group_legacy_host',HERE/'run.py')
    allowed={'harness-status.json','smoke-summary.json','npc-smoke/cloud-manifest.json',
             'npc-smoke/stage/compile-stdout.log','npc-smoke/stage/compile-stderr.log',
             'npc-smoke/runtime/receipt.json','npc-smoke/runtime/runtime.log',
             'npc-smoke/runtime/daemon-stdout.log','npc-smoke/runtime/daemon-stderr.log'}
    allowed.update(f'abi/abi-{i}-{part}.log' for i in range(6) for part in ('stdout','stderr'))
    require(len(allowed)==21,'evidence policy')
    with tarfile.open(fileobj=io.BytesIO(data),mode='r:') as tar:
        entries=tar.getmembers();names=[e.name for e in entries]
        require(len(names)==len(set(names))==len(allowed) and set(names)==allowed and
                sum(e.size for e in entries)<=16*1024**2 and all(e.isfile() and e.size<=4*1024**2 and
                not PurePosixPath(e.name).is_absolute() and '..' not in PurePosixPath(e.name).parts for e in entries),
                'incomplete or unsafe group evidence')
        def get(name):return tar.extractfile(name).read()
        status=json.loads(get('harness-status.json'));summary=json.loads(get('smoke-summary.json'))
        manifest=json.loads(get('npc-smoke/cloud-manifest.json'))
        require(status.get('head')==head and status.get('suite')==suite and status.get('phase')=='complete' and
                status.get('outcome')=='passed' and status.get('fixture_dme_only') is True and
                summary.get('head')==head and summary.get('tree')==tree and summary.get('parent')==binding.PARENT and
                summary.get('suite')==suite and summary.get('fixture_dme_only') is True and
                summary.get('parity_established') is False and summary.get('scope')=='standalone synthetic full-tile group Bump; no Civ13 gameplay',
                'group status or scope')
        require(manifest.get('head')==head and manifest.get('tree')==tree and manifest.get('parent')==binding.PARENT and
                manifest.get('scope')==summary['scope'] and set(manifest.get('source',{}))==set(binding.INPUTS),
                'source manifest')
        for name,digest in binding.INPUTS.items():
            raw=binding.read(git,['show',head+':'+binding.PREFIX+name],env,deadline)
            require(manifest['source'][name]=={'bytes':len(raw),'sha256':digest} and hashlib.sha256(raw).hexdigest()==digest,
                    'source input mismatch: '+name)
        compile_command=['/opt/byond/bin/DreamMaker','-max_errors','0','/work/npc-smoke/stage/native-group-probe.dme']
        daemon_command=['/opt/byond/bin/DreamDaemon','/work/npc-smoke/runtime/native-group-probe.dmb','59474','-ip','127.0.0.1','-trusted','-log','runtime.log']
        require(phase(summary.get('compile'),compile_command,90) and phase(summary.get('daemon'),daemon_command,60),'phase bounds/commands')
        logs=(get('npc-smoke/stage/compile-stdout.log')+get('npc-smoke/stage/compile-stderr.log')).decode('utf-8',errors='replace')
        legacy.validate_compile(logs,'native-group-probe.dmb')
        for name in ('runtime.log','daemon-stdout.log','daemon-stderr.log'):
            require(not legacy.DIAGNOSTICS.search(get('npc-smoke/runtime/'+name).decode('utf-8',errors='replace')),'native diagnostic: '+name)
        artifacts=summary.get('artifacts');resource=summary.get('resource')
        require(isinstance(artifacts,dict) and set(artifacts) in ({'native-group-probe.dmb'},{'native-group-probe.dmb','native-group-probe.rsc'}) and
                all(artifact(x) for x in artifacts.values()),'compiled artifacts')
        require(isinstance(resource,dict) and set(resource)=={'before','after'},'resource record')
        initial=artifacts.get('native-group-probe.rsc')
        require(resource['before']==initial and (resource['after'] is None or artifact(resource['after'])),'resource identity')
        if initial is not None:require(resource['after'] is not None,'runtime resource missing')
        raw=get('npc-smoke/runtime/receipt.json')
        require(hashlib.sha256(raw).hexdigest()==summary.get('receipt_sha256'),'receipt hash')
        observation=oracle.validate(json.loads(raw))
        require(observation==summary.get('observation')==status.get('observation') and
                observation.get('status')=='observed_consistent_on_this_trace','observation failed or inconclusive')
    return True
