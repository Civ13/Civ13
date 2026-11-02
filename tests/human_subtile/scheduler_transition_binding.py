"""Exact parent, file inventory and input guards for the scheduler draft."""
import subprocess
import time

BASE_COMMIT='37f7c5ab43c30489f53971a25d0b5cdeffea1c44'
BASE_TREE='1e815423c56874cb13b93ac5520db876cc43f832'
# Fixture/overlay input blob identities are pinned to this source candidate.
PINNED={
    'code/game/mob/living/simple_animal/subtile_movement.dm':'01aacb93a60138836ad9603efa6dd1e478da0303',
    'code/game/mob/living/simple_animal/simple_animal.dm':'6656a7ee937f42cbef6ec02b05ac2bbbc0cd2781',
    'code/game/mob/living/simple_animal/simple_ai.dm':'104d69687aef37eefdc4b88027e2b67e8aff6128',
    'code/game/mob/living/simple_animal/friendly/cat.dm':'451fb534a6f76c747150f3e45c3b7b4e82a8dca7',
    'code/game/mob/living/simple_animal/friendly/dogs.dm':'acfa716c893f933148ee20ce41e15bc5e850f6c9',
    'tests/human_subtile/probe.dm':'58afd77c15b3b89a3c924e428068085b04f6614a',
    'civ13.dme':'1ec749aba78bbd2c944da0131540f3eca832a037',
    'tests/human_subtile/scheduler_core_draft.dm':'44100f3998cf9626b7bb4907496a2f93ea7f229e',
    'tests/human_subtile/scheduler_transition_stage.py':'9de9e7e6506c7ca53281386f5d85b98d969ac4de',
    'tests/human_subtile/scheduler_transition_contract.py':'f8e1b459de5f30bd5b19e2c7dea9e67054383aa9',
    'tests/human_subtile/scheduler_transition_worker.py':'53e455d4f2ee113dc9c431cd30179db547af72b5',
}
ALLOWED_DELTA=frozenset({
    '.github/workflows/wildlife-cardinal-cadence.yml',
    'tests/human_subtile/cloud_npc_controller.py',
    'tests/human_subtile/cloud_npc_job.py',
    'tests/human_subtile/cloud_npc_smoke.py',
    'tests/human_subtile/scheduler_core_draft.dm',
    'tests/human_subtile/scheduler_transition_binding.py',
    'tests/human_subtile/scheduler_transition_contract.py',
    'tests/human_subtile/scheduler_transition_evidence.py',
    'tests/human_subtile/scheduler_transition_stage.py',
    'tests/human_subtile/scheduler_transition_worker.py',
    'tests/human_subtile/test_scheduler_transition_contract.py',
    'tests/human_subtile/test_scheduler_transition_controller.py',
    'tests/human_subtile/test_scheduler_transition_draft.py',
    'tests/human_subtile/test_scheduler_transition_stage.py',
    'tests/human_subtile/test_species_fallback_controller.py',
})

def require(ok,label):
    if not ok:raise ValueError(label)

def validate_source(git,env,head,deadline=None):
    require(isinstance(head,str) and len(head)==40 and all(c in '0123456789abcdef' for c in head),'invalid source head')
    def limit(seconds):
        if deadline is None:return seconds
        remaining=deadline-time.monotonic();require(remaining>0,'source validation deadline')
        return min(seconds,remaining)
    def read(args,timeout=10):
        return subprocess.check_output(git+args,env=env,timeout=limit(timeout)).decode('ascii').strip()
    require(read(['rev-parse',BASE_COMMIT+'^{tree}'])==BASE_TREE,'base tree')
    result=subprocess.run(git+['merge-base','--is-ancestor',BASE_COMMIT,head],env=env,capture_output=True,timeout=limit(10))
    require(result.returncode==0,'base ancestry')
    raw=subprocess.check_output(git+['diff','--no-ext-diff','--no-renames','--name-only','-z',BASE_COMMIT,head,'--'],env=env,timeout=limit(30))
    parts=raw.split(b'\0');require(parts[-1]==b'' and all(parts[:-1]),'delta encoding')
    names=[p.decode('utf-8') for p in parts[:-1]]
    require(len(names)==len(set(names)) and frozenset(names)==ALLOWED_DELTA,'unexpected source delta')
    for path,expected in PINNED.items():
        require(read(['rev-parse',head+':'+path])==expected,'changed input: '+path)
    return True
