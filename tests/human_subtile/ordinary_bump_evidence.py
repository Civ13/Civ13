"""Host-side bounded evidence validator for current-game ordinary bumps."""
import hashlib
import importlib.util
import io
import json
from pathlib import Path,PurePosixPath
import re
import subprocess
import sys
import tarfile

HERE=Path(__file__).resolve().parent


def require(value,message):
    if not value:raise ValueError(message)


def modules():
    names=('ordinary_bump_stage','ordinary_bump_binding','ordinary_bump_receipt','ordinary_bump_materialize','runner_limits')
    result={}
    for name in names:
        require(name not in sys.modules,'Unexpected preloaded ordinary bump module: '+name)
        spec=importlib.util.spec_from_file_location(name,HERE/(name+'.py'))
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        sys.modules[name]=module;result[name]=module
    return result


def metadata(raw):return {'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}


def valid_artifact(value,mode):
    return (isinstance(value,dict) and type(value.get('bytes')) is int and 0<value['bytes']<=1024**3 and
            re.fullmatch('[0-9a-f]{64}',value.get('sha256') or '') is not None and value.get('mode')==mode)


def validate(data,head,suite,git,env,loaded=None,compile_validator=None,deadline=None):
    m=loaded if loaded is not None else modules()
    binding,stage,oracle,materialize,limits=(m[x] for x in ('ordinary_bump_binding','ordinary_bump_stage',
        'ordinary_bump_receipt','ordinary_bump_materialize','runner_limits'))
    require(suite=='ordinary05','ordinary suite')
    tree=binding.validate_head(git,head,env,deadline);inputs=binding.read_inputs(git,env,deadline)
    fixture=subprocess.check_output(git+['show',head+':tests/human_subtile/ordinary_bump_probe.dm'],
                                    env=env,timeout=binding.budget_timeout(10,deadline))
    expected={label:stage.reconstruct(inputs['old_living'] if label=='baseline' else inputs['new_living'],
        inputs['probe'],inputs['dme'],fixture,label=='candidate') for label in ('baseline','candidate')}
    allowed={'harness-status.json','smoke-summary.json'}
    allowed.update(f'{prefix}/{name}' for prefix in ('npc-parent','npc-smoke')
                   for name in ('cloud-manifest.json','stage/compile-stdout.log','stage/compile-stderr.log'))
    allowed.update(f'{prefix}/runtime/{name}' for prefix in ('npc-parent','npc-smoke')
                   for name in ('receipt.json','result.txt','port-closed.txt','runtime.log','daemon-stdout.log','daemon-stderr.log'))
    allowed.update(f'abi/abi-{i}-{part}.log' for i in range(6) for part in ('stdout','stderr'))
    require(len(allowed)==32,'archive policy')
    with tarfile.open(fileobj=io.BytesIO(data),mode='r:') as archive:
        entries=archive.getmembers();names=[x.name for x in entries]
        require(len(names)==len(set(names))==len(allowed) and set(names)==allowed and
            sum(x.size for x in entries)<=16*1024**2 and all(x.isfile() and x.size<=4*1024**2 and
            not PurePosixPath(x.name).is_absolute() and '..' not in PurePosixPath(x.name).parts for x in entries),
            'incomplete or unsafe ordinary bump archive')
        def get(name):return archive.extractfile(name).read()
        status=json.loads(get('harness-status.json'));summary=json.loads(get('smoke-summary.json'))
        require(status.get('head')==head and status.get('suite')==suite and status.get('phase')=='complete' and
            status.get('outcome')=='passed' and status.get('fixture_dme_only') is True and
            status.get('resource_copies_independent') is True and summary.get('head')==head and summary.get('tree')==tree and
            summary.get('game_head')==stage.CANDIDATE_HEAD and summary.get('game_tree')==stage.CANDIDATE_TREE and
            summary.get('baseline_head')==stage.BASE_HEAD and summary.get('suite')==suite and
            summary.get('fixture_dme_only') is True and summary.get('observation_complete') is True and
            summary.get('visual_or_broad_parity_established') is False and summary.get('scope')==oracle.SCOPE and
            summary.get('tick')==0.5 and summary.get('modes')==['legacy','candidate'] and
            summary.get('cases')==list(oracle.CASES) and
            summary.get('comparison')=={'ordinary_cases_observed':4,'visual_or_broad_parity_established':False} and
            summary.get('limits')=={'compile_seconds':90,'daemon_seconds':60,'setup_seconds':60,
                                    'work_seconds':490,'whole_seconds':600},'summary identity')
        states=summary.get('resource_states');artifacts=summary.get('artifacts')
        require(isinstance(states,dict) and set(states)=={'baseline','candidate'} and status.get('runtime_resources')==states and
            isinstance(artifacts,dict) and set(artifacts)=={'baseline','candidate'},'resource identities')
        limits.validate_accounting(summary.get('phases'),summary.get('comparison_elapsed'),summary.get('setup_seconds'))
        phases=summary['phases']
        for i,prefix in ((0,'npc-parent'),(2,'npc-smoke')):
            mode='legacy' if i==0 else 'candidate'
            require(phases[i].get('command')==['/opt/byond/bin/DreamMaker','-max_errors','0','/work/'+prefix+'/stage/human_subtile.dme'] and
                    phases[i+1].get('command')==['/opt/byond/bin/DreamDaemon','/work/'+prefix+'/runtime/human_subtile.dmb',
                    '59474','-ip','127.0.0.1','-trusted','-params','tested_commit='+head+';ordinary_bump_mode='+mode,'-log','runtime.log'],
                    'unexpected process command')
        if compile_validator is None:
            compile_validator=materialize.runner_module(inputs['runner'],HERE/'run.py').validate_compile
        receipts={};manifests={}
        for label,prefix in (('baseline','npc-parent'),('candidate','npc-smoke')):
            binding.budget_timeout(1,deadline);offset=0 if label=='baseline' else 2;mode='legacy' if label=='baseline' else 'candidate'
            compile_phase={k:v for k,v in phases[offset].items() if k!='name'}
            daemon_phase={k:v for k,v in phases[offset+1].items() if k!='name'}
            require(summary.get('compiles',{}).get(label)==compile_phase and
                    summary.get('results',{}).get(label,{}).get('daemon')==daemon_phase,'phase identity')
            manifest=json.loads(get(prefix+'/cloud-manifest.json'));manifests[label]=manifest
            require(manifest.get('head')==head and manifest.get('ordinary_bump_mode')==mode and
                manifest.get('game_head')==stage.CANDIDATE_HEAD and manifest.get('game_tree')==stage.CANDIDATE_TREE and
                manifest.get('baseline_living_commit')==stage.BASE_HEAD and manifest.get('experiment_tree')==tree,
                'manifest identity')
            for path,raw in expected[label].items():
                require(manifest.get('stage_files',{}).get(path)==metadata(raw),'fixture reconstruction: '+path)
            for path,key in (('code/game/mob/living/living.dm','new_living'),('tests/human_subtile/probe.dm','probe'),
                             ('civ13.dme','dme'),('tests/human_subtile/run.py','runner')):
                require(manifest.get('original_git_files',{}).get(path)==metadata(inputs[key]),'game archive input: '+path)
            require(isinstance(artifacts[label],dict) and set(artifacts[label])=={'human_subtile.dmb','human_subtile.rsc'} and
                    valid_artifact(artifacts[label]['human_subtile.dmb'],0o444),'compiled binary')
            initial=artifacts[label]['human_subtile.rsc'];state=states[label]
            require(valid_artifact(initial,0o600) and isinstance(state,dict) and valid_artifact(state.get('before'),0o600) and
                valid_artifact(state.get('after'),0o600) and state['before']==initial and type(state.get('changed')) is bool and
                state['changed']==(state['before']!=state['after']) and state.get('integrity_verified') is True and
                'daemon_error' not in state and 'integrity_error' not in state,'resource state')
            require(get(prefix+'/runtime/port-closed.txt')==b'closed\n' and get(prefix+'/runtime/result.txt')==b'PASS\n','runtime markers')
            log=(get(prefix+'/stage/compile-stdout.log')+get(prefix+'/stage/compile-stderr.log')).decode(errors='replace')
            compile_validator(log,'human_subtile.dmb')
            raw=get(prefix+'/runtime/receipt.json')
            require(summary.get('results',{}).get(label,{}).get('receipt_sha256')==hashlib.sha256(raw).hexdigest(),'receipt hash')
            receipts[label]=json.loads(raw);oracle.validate(receipts[label],mode,head)
        a,b=manifests['baseline'],manifests['candidate']
        require(a.get('original_git_files')==b.get('original_git_files') and a.get('adaptations')==b.get('adaptations'),
                'stages did not share exact game source')
        sa,sb=a.get('stage_files'),b.get('stage_files')
        require(isinstance(sa,dict) and isinstance(sb,dict) and set(sa)==set(sb) and
                {p for p in sa if sa[p]!=sb[p]}=={'code/game/mob/living/living.dm'},'unexpected stage differences')
        require(oracle.compare(receipts['baseline'],receipts['candidate'],head)==summary['comparison'],'comparison mismatch')
        binding.budget_timeout(1,deadline)
    return True