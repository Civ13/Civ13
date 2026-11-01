"""Host-side full archive/source/receipt validation for transition05."""
import hashlib
import importlib.util
import io
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import tarfile

HERE=Path(__file__).resolve().parent


def module(name):
    spec=importlib.util.spec_from_file_location(name,HERE/(name+'.py'))
    value=importlib.util.module_from_spec(spec);spec.loader.exec_module(value)
    return value


def require(ok,message):
    if not ok: raise ValueError(message)


def one(text,old,new):
    require(text.count(old)==1,'transition reconstruction preimage')
    return text.replace(old,new,1)


def validate(data,head,suite,git,git_env):
    c,stage,random=(module(name) for name in ('transition_contract','transition_stage','random_cadence_contract'))
    require(suite=='transition05','suite');c.validate_source(git,git_env,head)
    def source(path): return subprocess.check_output(git+['show',head+':'+path],env=git_env,timeout=10)
    def record(raw): return {'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
    with tarfile.open(fileobj=io.BytesIO(data),mode='r:') as archive:
        entries=archive.getmembers();names=[e.name for e in entries]
        allowed={'harness-status.json','smoke-summary.json','npc-smoke/cloud-manifest.json',
                 'npc-smoke/stage/compile-stdout.log','npc-smoke/stage/compile-stderr.log'}
        allowed.update('npc-smoke/runtime/'+name for name in ('receipt.json','result.txt','port-closed.txt',
                                                               'runtime.log','daemon-stdout.log','daemon-stderr.log'))
        allowed.update(f'abi/abi-{i}-{part}.log' for i in range(6) for part in ('stdout','stderr'))
        require(len(allowed)==23 and set(names)==allowed and len(names)==len(set(names)) and
                sum(e.size for e in entries)<=16*1024**2 and all(e.isfile() and e.size<=4*1024**2 and
                not PurePosixPath(e.name).is_absolute() and '..' not in PurePosixPath(e.name).parts for e in entries),
                'incomplete or unsafe transition package')
        def read(name): return archive.extractfile(name).read()
        status=json.loads(read('harness-status.json'));summary=json.loads(read('smoke-summary.json'))
        require(status.get('head')==head and status.get('suite')==suite and status.get('phase')=='complete' and
                status.get('outcome')=='passed' and status.get('fixture_dme_only') is True and
                summary.get('head')==head and summary.get('suite')==suite and summary.get('tick')==c.TICK and
                summary.get('fixture_dme_only') is True and summary.get('observation_complete') is True and
                summary.get('parity_established') is False and summary.get('scope')==c.SCOPE and
                summary.get('limits')=={'compile_seconds':90,'daemon_seconds':60,'setup_seconds':60,
                                        'work_seconds':490,'whole_seconds':600},'summary identity')
        manifest=json.loads(read('npc-smoke/cloud-manifest.json'))
        require(manifest.get('head')==head and manifest.get('transition_scope')==c.SCOPE and
                manifest.get('transition_movement_blob')==stage.MOVEMENT_BLOB,'staged identity')
        expected={}
        for path,blob in {stage.MOVEMENT:stage.MOVEMENT_BLOB,**stage.SPECIES}.items():
            raw=source(path);require(stage.git_blob(raw)==blob,'production blob mismatch: '+path)
            expected[path]=random.movement_fixture_bytes(raw,'candidate') if path==stage.MOVEMENT else raw
        for path in (stage.CORE,stage.FIXTURE): expected[path]=source(path)
        raw=source(stage.RANDOM).decode('utf-8')
        old='list("mode" = mode, "lag" = lag, "speed_argument" = 0)'
        new='list("mode" = mode, "lag" = lag, "speed_argument" = 0, "direction" = direction)'
        identity_old='"pending" = P ? "\\ref[P]" : null,\n\t\t"active_tx"'
        identity_new=('"pending" = P ? "\\ref[P]" : null,\n'
                      '\t\t"recovery" = A.npc_subtile_recovery ? "\\ref[A.npc_subtile_recovery]" : null,\n'
                      '\t\t"tx_intent" = T && T.intent_owner ? "\\ref[T.intent_owner]" : null,\n\t\t"active_tx"')
        require(raw.count(old)==2 and raw.count(identity_old)==1,'transition observation preimage')
        expected[stage.RANDOM]=raw.replace(old,new).replace(identity_old,identity_new).encode('utf-8')
        probe=source(stage.PROBE).decode('utf-8')
        probe=one(probe,'\t\t\thuman_subtile_fixture_headless()','\t\t\tnpc_subtile_fixture()')
        probe=one(probe,'"checks" = human_subtile_fixture_checks,',
                  '"checks" = human_subtile_fixture_checks, "npc_checks" = npc_subtile_checks, "npc_rows" = npc_subtile_rows,')
        probe=one(probe,'\tmaxx = 18\n\tmaxy = 14','\tmaxx = 65\n\tmaxy = 65')
        probe=one(probe,'\t\t\tnpc_subtile_fixture()','\t\t\tfixture_transition_main()')
        probe=one(probe,'"scope" = "actual human/codec; headless authority adapter"',
                  '"scope" = "'+c.SCOPE+'", "movement_blob" = "'+stage.MOVEMENT_BLOB+'", '
                  '"setup" = fixture_transition_setup, "transition_rows" = fixture_transition_rows, '
                  '"transition_case" = fixture_transition_case, "transition_checks" = fixture_scheduler_checks, '
                  '"transition_partial" = fixture_random_events, "overflow" = fixture_random_overflow')
        expected[stage.PROBE]=probe.encode('utf-8')
        dme=source('civ13.dme').decode('utf-8')
        dme=re.sub(r'^#include ".*\.dmm"\s*$','',dme,flags=re.M)
        dme+='\n#include "tests\\human_subtile\\mining.dm"\n#include "tests\\human_subtile\\probe.dm"\n'
        dme+='\n#include "tests\\human_subtile\\npc.dm"\n'
        for path in (stage.CORE,stage.RANDOM,stage.FIXTURE): dme+='\n#include "'+path.replace('/','\\')+'"'
        expected['human_subtile.dme']=(dme+'\n').encode('utf-8')
        for path,raw in expected.items():
            require(manifest.get('stage_files',{}).get(path)==record(raw),'adapted source mismatch: '+path)
        phase=summary.get('compile',{})
        require(phase.get('returncode')==0 and phase.get('timed_out') is False and
                phase.get('oversized_log') is False and phase.get('deadline')==90,'compile phase')
        npc=module('run-npc')
        npc.current.legacy.validate_compile((read('npc-smoke/stage/compile-stdout.log')+
                                             read('npc-smoke/stage/compile-stderr.log')).decode(errors='replace'),
                                            'human_subtile.dmb')
        states=summary.get('resource_states');artifacts=summary.get('artifacts')
        require(isinstance(states,dict) and set(states)=={'transition'} and status.get('runtime_resources')==states and
                isinstance(artifacts,dict) and isinstance(artifacts.get('human_subtile.rsc'),dict),'resource states')
        state=states['transition'];before=state.get('before',{});after=state.get('after',{})
        require(before==artifacts['human_subtile.rsc'] and state.get('integrity_verified') is True and
                'daemon_error' not in state and 'integrity_error' not in state and type(state.get('changed')) is bool and
                state['changed']==(before!=after),'resource integrity')
        for value in (before,after):
            require(type(value.get('bytes')) is int and 0<value['bytes']<=1024**3 and value.get('mode')==0o600 and
                    re.fullmatch('[0-9a-f]{64}',value.get('sha256') or ''),'resource identity')
        phase=summary.get('result',{}).get('daemon',{})
        require(phase.get('returncode')==0 and phase.get('timed_out') is False and
                phase.get('oversized_log') is False and phase.get('deadline')==60,'daemon phase')
        prefix='npc-smoke/runtime/'
        require(read(prefix+'result.txt')==b'PASS\n' and read(prefix+'port-closed.txt')==b'closed\n','daemon result')
        raw=read(prefix+'receipt.json')
        require(summary['result'].get('receipt_sha256')==hashlib.sha256(raw).hexdigest(),'receipt hash')
        require(c.validate_receipt(json.loads(raw),head)==summary.get('observation'),'observation mismatch')
        timings=[summary['compile'].get('seconds'),phase.get('seconds')]
        require(all(c.number(v) and 0<=v<=limit for v,limit in zip(timings,(90,60))) and
                c.number(summary.get('child_elapsed')) and abs(sum(timings)-summary['child_elapsed'])<0.000001 and
                c.number(summary.get('comparison_elapsed')) and c.number(summary.get('setup_seconds')) and
                abs(summary['comparison_elapsed']-summary['child_elapsed']-summary['setup_seconds'])<0.000001 and
                0<=summary['setup_seconds']<=60,'elapsed budget')
