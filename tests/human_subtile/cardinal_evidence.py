"""Host revalidation of complete bounded cardinal evidence; no parity claim."""
import hashlib
import importlib.util
import io
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import tarfile

HERE = Path(__file__).resolve().parent


def module(name):
    spec = importlib.util.spec_from_file_location(name, HERE/(name+'.py'))
    value = importlib.util.module_from_spec(spec); spec.loader.exec_module(value)
    return value


def require(ok, message):
    if not ok: raise ValueError(message)


def one(text, old, new):
    require(text.count(old) == 1, 'source reconstruction preimage')
    return text.replace(old,new,1)


def validate(data, head, suite, git, git_env):
    c, stage, random = (module(name) for name in ('cardinal_contract','cardinal_stage','random_cadence_contract'))
    require(suite in ('cardinal05','cardinal10'), 'suite')
    c.validate_source(git,git_env,head)
    tick = .5 if suite == 'cardinal05' else 1.0
    def source(path):
        return subprocess.check_output(git+['show',head+':'+path],env=git_env,timeout=10)
    def record(raw):
        return {'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
    with tarfile.open(fileobj=io.BytesIO(data),mode='r:') as archive:
        entries=archive.getmembers(); names=[x.name for x in entries]
        allowed={'harness-status.json','smoke-summary.json','npc-smoke/cloud-manifest.json',
                 'npc-smoke/stage/compile-stdout.log','npc-smoke/stage/compile-stderr.log'}
        allowed.update(f'npc-smoke/{folder}/{name}' for folder in ('runtime','runtime-wildlife') for name in
                       ('receipt.json','result.txt','port-closed.txt','runtime.log','daemon-stdout.log','daemon-stderr.log'))
        allowed.update(f'abi/abi-{i}-{part}.log' for i in range(6) for part in ('stdout','stderr'))
        require(len(allowed)==29 and set(names)==allowed and len(names)==len(set(names)) and
                sum(x.size for x in entries)<=16*1024**2 and all(x.isfile() and x.size<=4*1024**2 and
                not PurePosixPath(x.name).is_absolute() and '..' not in PurePosixPath(x.name).parts for x in entries),
                'incomplete or unsafe cardinal package')
        def read(name): return archive.extractfile(name).read()
        status=json.loads(read('harness-status.json')); summary=json.loads(read('smoke-summary.json'))
        require(status.get('head')==head and status.get('suite')==suite and status.get('phase')=='complete' and
                status.get('outcome')=='passed' and status.get('fixture_dme_only') is True and
                summary.get('head')==head and summary.get('suite')==suite and summary.get('tick')==tick and
                summary.get('fixture_dme_only') is True and summary.get('observation_complete') is True and
                summary.get('parity_established') is False and summary.get('scope')==c.SCOPE and
                summary.get('limits')=={'compile_seconds':90,'daemon_seconds':60,'setup_seconds':60,
                                        'work_seconds':490,'whole_seconds':600}, 'summary identity')
        manifest=json.loads(read('npc-smoke/cloud-manifest.json'))
        require(manifest.get('head')==head and manifest.get('cardinal_scope')==c.SCOPE and
                manifest.get('cardinal_movement_blob')==stage.EXPECTED_MOVEMENT_BLOB, 'staged identity')
        expected={}
        for path, blob in {stage.MOVEMENT:stage.EXPECTED_MOVEMENT_BLOB,**stage.EXPECTED_SPECIES_BLOBS}.items():
            raw=source(path); require(stage.git_blob(raw)==blob,'production blob mismatch: '+path)
            expected[path]=random.movement_fixture_bytes(raw,'candidate') if path==stage.MOVEMENT else raw
        for path in (stage.CORE,stage.CARDINAL_FIXTURE): expected[path]=source(path)
        raw=source(stage.RANDOM_FIXTURE).decode('utf-8')
        old='list("mode" = mode, "lag" = lag, "speed_argument" = 0)'
        new='list("mode" = mode, "lag" = lag, "speed_argument" = 0, "direction" = direction)'
        require(raw.count(old)==2,'fixture command preimage')
        expected[stage.RANDOM_FIXTURE]=raw.replace(old,new).encode('utf-8')
        probe=source(stage.PROBE).decode('utf-8')
        probe=one(probe,'\t\t\thuman_subtile_fixture_headless()','\t\t\tnpc_subtile_fixture()')
        probe=one(probe,'"checks" = human_subtile_fixture_checks,',
                  '"checks" = human_subtile_fixture_checks, "npc_checks" = npc_subtile_checks, "npc_rows" = npc_subtile_rows,')
        probe=one(probe,'\tmaxx = 18\n\tmaxy = 14','\tmaxx = 65\n\tmaxy = 65')
        probe=one(probe,'\t\t\tnpc_subtile_fixture()','\t\t\tfixture_interval_cardinal_main()')
        probe=one(probe,'"scope" = "actual human/codec; headless authority adapter"',
          '"scope" = "'+c.SCOPE+'", "mode" = fixture_cardinal_mode, "tick" = fixture_cardinal_tick, '
          '"movement_blob" = "'+stage.EXPECTED_MOVEMENT_BLOB+'", "setup" = fixture_cardinal_setup, '
          '"rows" = fixture_cardinal_rows, "overflow" = fixture_random_overflow')
        expected[stage.PROBE]=probe.encode('utf-8')
        dme=source('civ13.dme').decode('utf-8')
        dme=re.sub(r'^#include ".*\.dmm"\s*$', '', dme, flags=re.M)
        dme+='\n#include "tests\\human_subtile\\mining.dm"\n#include "tests\\human_subtile\\probe.dm"\n'
        dme+='\n#include "tests\\human_subtile\\npc.dm"\n'
        for path in (stage.CORE,stage.RANDOM_FIXTURE,stage.CARDINAL_FIXTURE):
            dme+='\n#include "'+path.replace('/','\\')+'"'
        dme+='\n'
        expected['human_subtile.dme']=dme.encode('utf-8')
        for path, raw in expected.items():
            require(manifest.get('stage_files',{}).get(path)==record(raw),'adapted source mismatch: '+path)
        phase=summary.get('compile',{})
        require(phase.get('returncode')==0 and phase.get('timed_out') is False and
                phase.get('oversized_log') is False and phase.get('deadline')==90,'compile phase')
        npc=module('run-npc')
        npc.current.legacy.validate_compile((read('npc-smoke/stage/compile-stdout.log')+
                                              read('npc-smoke/stage/compile-stderr.log')).decode(errors='replace'),
                                             'human_subtile.dmb')
        states=summary.get('resource_states'); artifacts=summary.get('artifacts')
        require(isinstance(states,dict) and set(states)==set(c.MODES) and status.get('runtime_resources')==states and
                isinstance(artifacts,dict) and isinstance(artifacts.get('human_subtile.rsc'),dict),'resource states')
        receipts={}
        for mode, folder in (('legacy','runtime'),('smooth','runtime-wildlife')):
            state=states[mode]; before=state.get('before',{}); after=state.get('after',{})
            require(before==artifacts['human_subtile.rsc'] and state.get('integrity_verified') is True and
                    'daemon_error' not in state and 'integrity_error' not in state and type(state.get('changed')) is bool and
                    state['changed']==(before!=after),'resource integrity')
            for value in (before,after):
                require(type(value.get('bytes')) is int and 0<value['bytes']<=1024**3 and value.get('mode')==0o600 and
                        re.fullmatch('[0-9a-f]{64}',value.get('sha256') or ''),'resource identity')
            result=summary.get('results',{}).get(mode,{}); phase=result.get('daemon',{})
            require(phase.get('returncode')==0 and phase.get('timed_out') is False and
                    phase.get('oversized_log') is False and phase.get('deadline')==60,'daemon phase')
            prefix='npc-smoke/'+folder+'/'
            require(read(prefix+'result.txt')==b'PASS\n' and read(prefix+'port-closed.txt')==b'closed\n', 'daemon result')
            raw=read(prefix+'receipt.json'); require(result.get('receipt_sha256')==hashlib.sha256(raw).hexdigest(),'receipt hash')
            receipts[mode]=json.loads(raw)
        timings=[summary['compile'].get('seconds')]+[summary['results'][m]['daemon'].get('seconds') for m in c.MODES]
        require(all(c.number(v) and 0<=v<=limit for v,limit in zip(timings,(90,60,60))) and
                c.number(summary.get('child_elapsed')) and abs(sum(timings)-summary['child_elapsed'])<0.000001 and
                c.number(summary.get('comparison_elapsed')) and c.number(summary.get('setup_seconds')) and
                abs(summary['comparison_elapsed']-summary['child_elapsed']-summary['setup_seconds'])<0.000001 and
                0<=summary['setup_seconds']<=60,'elapsed budget')
        require(c.compare(receipts,head,tick)==summary.get('comparison'),'comparison mismatch')
