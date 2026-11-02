"""Exact immutable source binding for one enabled-owner handoff observation."""
import subprocess
import time

BASE_COMMIT = '4c648b04e4c7aa27d799523517cd1feaa9188fd3'
BASE_TREE = '35c9a70ae17d44f1d041061ba9c0e95d661ad1f0'
PINNED = {'civ13.dme': '1ec749aba78bbd2c944da0131540f3eca832a037',
 'code/game/mob/living/simple_animal/friendly/cat.dm': '451fb534a6f76c747150f3e45c3b7b4e82a8dca7',
 'code/game/mob/living/simple_animal/simple_ai.dm': '104d69687aef37eefdc4b88027e2b67e8aff6128',
 'code/game/mob/living/simple_animal/simple_animal.dm': '6656a7ee937f42cbef6ec02b05ac2bbbc0cd2781',
 'code/game/mob/living/simple_animal/subtile_movement.dm': '01aacb93a60138836ad9603efa6dd1e478da0303',
 'tests/human_subtile/probe.dm': '58afd77c15b3b89a3c924e428068085b04f6614a',
 'tests/human_subtile/scheduler_core_draft.dm': '44100f3998cf9626b7bb4907496a2f93ea7f229e',
 'tests/human_subtile/scheduler_enabled_handoff_contract.py': '297f4c12a9878e56240d5bd64dca0b3675faa0fa',
 'tests/human_subtile/scheduler_enabled_handoff_draft.dm': '00006a529b730137b64879ed59b2bfc7dcccddf7',
 'tests/human_subtile/scheduler_enabled_handoff_evidence.py': '1fa914a4eda2fc8005527fa31827ee43fad617bf',
 'tests/human_subtile/scheduler_enabled_handoff_stage.py': '9b7f7486542a53c36c7840e7a8f2bee760279ade',
 'tests/human_subtile/scheduler_enabled_handoff_worker.py': '1c9d5e9dccdd0e7f3d2615847a11f84c1887ded8',
 'tests/human_subtile/scheduler_transition_stage.py': '9de9e7e6506c7ca53281386f5d85b98d969ac4de',
 'tests/human_subtile/test_scheduler_enabled_handoff.py': 'fd6c9e00e3b03e4a42cd8c80cf20b7106b2e412d',
 'tests/human_subtile/test_scheduler_enabled_handoff_controller.py': 'cfde1f2833bca988724157fdd73a25fa85e9fbea',
 'tests/human_subtile/test_scheduler_enabled_handoff_stage.py': '1bde0b2f1db7ddc5e44dab92797fbb17982cb8d4',
 'tests/human_subtile/test_scheduler_transition_stage.py': '251cf60051f6497d45c43bcd6002fef4f4071a2e'}
SOURCE_PINS = {'.github/workflows/wildlife-cardinal-cadence.yml': '39989589aa587f5d57ba51c6ba710d31fdf8b69e',
 'tests/human_subtile/cloud_npc_controller.py': '36c95578c5a2357ea1ec9787431f4bc1cdc03980',
 'tests/human_subtile/cloud_npc_job.py': 'badf1cbd5323f0e4a40ff92eb500ab9a10f27c5e',
 'tests/human_subtile/cloud_npc_smoke.py': '63b742dce9a60ba0f301c6144d8373b4eef0e4fd',
 'tests/human_subtile/scheduler_enabled_handoff_contract.py': '297f4c12a9878e56240d5bd64dca0b3675faa0fa',
 'tests/human_subtile/scheduler_enabled_handoff_draft.dm': '00006a529b730137b64879ed59b2bfc7dcccddf7',
 'tests/human_subtile/scheduler_enabled_handoff_evidence.py': '1fa914a4eda2fc8005527fa31827ee43fad617bf',
 'tests/human_subtile/scheduler_enabled_handoff_stage.py': '9b7f7486542a53c36c7840e7a8f2bee760279ade',
 'tests/human_subtile/scheduler_enabled_handoff_worker.py': '1c9d5e9dccdd0e7f3d2615847a11f84c1887ded8',
 'tests/human_subtile/test_scheduler_enabled_handoff.py': 'fd6c9e00e3b03e4a42cd8c80cf20b7106b2e412d',
 'tests/human_subtile/test_scheduler_enabled_handoff_controller.py': 'cfde1f2833bca988724157fdd73a25fa85e9fbea',
 'tests/human_subtile/test_scheduler_enabled_handoff_stage.py': '1bde0b2f1db7ddc5e44dab92797fbb17982cb8d4'}
ALLOWED_DELTA = frozenset(['.github/workflows/wildlife-cardinal-cadence.yml',
 'tests/human_subtile/cloud_npc_controller.py',
 'tests/human_subtile/cloud_npc_job.py',
 'tests/human_subtile/cloud_npc_smoke.py',
 'tests/human_subtile/scheduler_enabled_handoff_contract.py',
 'tests/human_subtile/scheduler_enabled_handoff_draft.dm',
 'tests/human_subtile/scheduler_enabled_handoff_evidence.py',
 'tests/human_subtile/scheduler_enabled_handoff_stage.py',
 'tests/human_subtile/scheduler_enabled_handoff_worker.py',
 'tests/human_subtile/test_scheduler_enabled_handoff.py',
 'tests/human_subtile/test_scheduler_enabled_handoff_stage.py',
 'tests/human_subtile/test_scheduler_enabled_handoff_controller.py',
 'tests/human_subtile/scheduler_enabled_handoff_binding.py'])


def require(ok,label):
    if not ok:
        raise ValueError(label)


def validate_source(git,env,head,deadline=None):
    require(isinstance(head,str) and len(head)==40 and all(c in '0123456789abcdef' for c in head),'invalid source head')
    def limit(seconds):
        if deadline is None:
            return seconds
        remaining=deadline-time.monotonic()
        require(remaining>0,'source validation deadline')
        return min(seconds,remaining)
    def read(args,timeout=10):
        return subprocess.check_output(git+args,env=env,timeout=limit(timeout)).decode('ascii').strip()
    require(read(['rev-parse',BASE_COMMIT+'^{tree}'])==BASE_TREE,'base tree')
    result=subprocess.run(git+['merge-base','--is-ancestor',BASE_COMMIT,head],env=env,capture_output=True,timeout=limit(10))
    require(result.returncode==0,'base ancestry')
    raw=subprocess.check_output(git+['diff','--no-ext-diff','--no-renames','--name-only','-z',
                                    BASE_COMMIT,head,'--'],env=env,timeout=limit(30))
    parts=raw.split(b'\0')
    require(parts[-1]==b'' and all(parts[:-1]),'delta encoding')
    names=[p.decode('utf-8') for p in parts[:-1]]
    require(len(names)==len(set(names)) and frozenset(names)==ALLOWED_DELTA,'unexpected source delta')
    for path,expected in {**PINNED,**SOURCE_PINS}.items():
        require(read(['rev-parse',head+':'+path])==expected,'changed input: '+path)
    return True
