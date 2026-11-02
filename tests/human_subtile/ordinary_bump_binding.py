"""Exact experiment and merged game-source bindings for ordinary bump tests."""
import re
import subprocess
import time
import ordinary_bump_stage as stage

PARENT='5b230715135c380dcd3a690fb52e19a8d61552af'
PARENT_TREE='d36bf64f724a56c89bca08c0ed081b35414a957d'
RUNNER_BLOB='723044afb31a5de9c91cedc3169963acb90a90b3'
PATHS=frozenset({
    '.github/workflows/wildlife-cardinal-cadence.yml',
    'tests/human_subtile/cloud_npc_controller.py','tests/human_subtile/cloud_npc_job.py',
    'tests/human_subtile/cloud_npc_smoke.py','tests/human_subtile/test_bump_integration.py',
    'tests/human_subtile/ordinary_bump_probe.dm','tests/human_subtile/ordinary_bump_stage.py',
    'tests/human_subtile/ordinary_bump_receipt.py','tests/human_subtile/ordinary_bump_materialize.py',
    'tests/human_subtile/ordinary_bump_binding.py','tests/human_subtile/ordinary_bump_worker.py',
    'tests/human_subtile/ordinary_bump_evidence.py','tests/human_subtile/test_ordinary_bump_stage.py',
    'tests/human_subtile/test_ordinary_bump_receipt.py','tests/human_subtile/test_ordinary_bump_materialize.py',
    'tests/human_subtile/test_ordinary_bump_integration.py',
    'tests/human_subtile/ordinary_inputs/living-base.dm',
    'tests/human_subtile/ordinary_inputs/living-current.dm',
    'tests/human_subtile/ordinary_inputs/probe-current.dm',
    'tests/human_subtile/ordinary_inputs/civ13-current.dme',
    'tests/human_subtile/ordinary_inputs/run-current.py',
})
INPUTS={
    ('old_living',stage.BASE_HEAD,'code/game/mob/living/living.dm'):stage.BASE_LIVING,
    ('new_living',stage.CANDIDATE_HEAD,'code/game/mob/living/living.dm'):stage.CANDIDATE_LIVING,
    ('probe',stage.CANDIDATE_HEAD,'tests/human_subtile/probe.dm'):stage.PROBE,
    ('dme',stage.CANDIDATE_HEAD,'civ13.dme'):stage.DME,
    ('runner',stage.CANDIDATE_HEAD,'tests/human_subtile/run.py'):RUNNER_BLOB,
}


def budget_timeout(maximum,deadline):
    if deadline is None:return maximum
    remaining=deadline-time.monotonic()
    if remaining<=0:raise TimeoutError('ordinary bump validation deadline')
    return min(maximum,remaining)


def read(git,args,env=None,deadline=None,timeout=10):
    return subprocess.check_output(git+args,env=env,timeout=budget_timeout(timeout,deadline))


def validate_head(git,head,env=None,deadline=None):
    if type(head) is not str or re.fullmatch('[0-9a-f]{40}',head) is None:
        raise ValueError('invalid test commit')
    parent=read(git,['rev-parse',head+'^'],env,deadline).decode().strip()
    tree=read(git,['rev-parse',head+'^^{tree}'],env,deadline).decode().strip()
    if parent!=PARENT or tree!=PARENT_TREE:raise ValueError('experiment parent mismatch')
    raw=read(git,['diff','--no-ext-diff','--no-renames','--name-only','-z',PARENT,head,'--'],env,deadline,30)
    parts=raw.split(b'\0')
    if parts[-1]!=b'' or not all(parts[:-1]):raise ValueError('bad path encoding')
    paths=[p.decode('utf-8') for p in parts[:-1]]
    if len(paths)!=len(set(paths)) or frozenset(paths)!=PATHS:raise ValueError('experiment path scope')
    result=read(git,['rev-parse',head+'^{tree}'],env,deadline).decode().strip()
    if re.fullmatch('[0-9a-f]{40}',result) is None:raise ValueError('bad test tree')
    return result


def read_inputs(git,env=None,deadline=None):
    game_tree=read(git,['rev-parse',stage.CANDIDATE_HEAD+'^{tree}'],env,deadline).decode().strip()
    game_parent=read(git,['rev-parse',stage.CANDIDATE_HEAD+'^'],env,deadline).decode().strip()
    if game_tree!=stage.CANDIDATE_TREE or game_parent!=stage.BASE_HEAD:
        raise ValueError('merged game tree or parent mismatch')
    result={}
    for (name,commit,path),expected in INPUTS.items():
        raw=read(git,['show',commit+':'+path],env,deadline)
        if stage.blob(raw)!=expected:raise ValueError('game source blob mismatch: '+name)
        result[name]=raw
    return result