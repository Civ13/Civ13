"""Exact immutable source binding for one enabled-owner handoff observation."""
import subprocess
import time

BASE_COMMIT = '6643c6e42e53cbc3d357c8c45072e0727c914288'
BASE_TREE = '31eab4b7f47d6cab9a21c425d76958cea32a9ab8'
PINNED = {'civ13.dme': '1ec749aba78bbd2c944da0131540f3eca832a037',
 'code/game/mob/living/simple_animal/friendly/cat.dm': '451fb534a6f76c747150f3e45c3b7b4e82a8dca7',
 'code/game/mob/living/simple_animal/hostile/hostile.dm': '8772533242bd02ab3a6f8ab005d1d7dbf93d2c9c',
 'code/game/mob/living/simple_animal/hostile/panther.dm': '960bdab38b573c29a5e02a01a2b5edd47acc4df6',
 'code/game/mob/living/simple_animal/hostile/tactical_ai.dm': '6c9ea2683a6fa4166b57470cf85fa7e337ae3403',
 'code/game/mob/living/simple_animal/simple_ai.dm': '104d69687aef37eefdc4b88027e2b67e8aff6128',
 'code/game/mob/living/simple_animal/simple_animal.dm': '6656a7ee937f42cbef6ec02b05ac2bbbc0cd2781',
 'code/game/mob/living/simple_animal/subtile_movement.dm': '01aacb93a60138836ad9603efa6dd1e478da0303',
 'code/processes/__processScheduler.dm': 'c30e02e4db07bbaac79ffe03deba7aaed6179734',
 'code/processes/_process.dm': '385102f68a880545c66f8063bf97f693e7f8045a',
 'code/processes/mob.dm': '8a2f55edaf0233d1561f16936e2fddfb288156e4',
 'code/processes/scheduler.dm': '1f27def620632fe33e8df47cf49dfead65acb352',
 'tests/human_subtile/probe.dm': '58afd77c15b3b89a3c924e428068085b04f6614a',
 'tests/human_subtile/scheduler_core_draft.dm': '44100f3998cf9626b7bb4907496a2f93ea7f229e',
 'tests/human_subtile/scheduler_transition_stage.py': '9de9e7e6506c7ca53281386f5d85b98d969ac4de',
 'tests/human_subtile/test_scheduler_transition_stage.py': '251cf60051f6497d45c43bcd6002fef4f4071a2e'}
SOURCE_PINS = {'.github/workflows/wildlife-cardinal-cadence.yml': '2d3d62c694a3c135e424da54a02edbe72a6505aa',
 'tests/human_subtile/cloud_npc_controller.py': 'cd99156a092bdb63a91771525c80300ce12362f0',
 'tests/human_subtile/cloud_npc_job.py': 'df0356762855401578407be52a02b40a74030bf0',
 'tests/human_subtile/cloud_npc_smoke.py': '0488777cac3edd8f8ce9f6bce6be19b46dd8b63d',
 'tests/human_subtile/scheduler_hostile_contract.py': 'a3cc1f74372631af08c858e5ba88c027c62dc727',
 'tests/human_subtile/scheduler_hostile_draft.dm': 'c9f342a4644efafdc0691ef136c3fed091382171',
 'tests/human_subtile/scheduler_hostile_evidence.py': '89c79e68412b2c04a00c9e7b46faa530a8af2a5c',
 'tests/human_subtile/scheduler_hostile_stage.py': 'd8a867d22133033895a59711fbdbbd84399fe9c8',
 'tests/human_subtile/scheduler_hostile_worker.py': 'c404fb848ae19500c5a6f5dea92df8b560310cba',
 'tests/human_subtile/test_scheduler_hostile_contract.py': '8e49fb108920c20de6803b3436bf17ed659a55d3',
 'tests/human_subtile/test_scheduler_hostile_controller.py': '6367edb20188ebe40b770581c531646a993b92ce',
 'tests/human_subtile/test_scheduler_hostile_stage.py': 'ab3ddd6f008b1a2c59952ec22c4d03f2bc1f169d'}
ALLOWED_DELTA = frozenset(['tests/human_subtile/scheduler_hostile_binding.py',
 'tests/human_subtile/scheduler_hostile_contract.py',
 'tests/human_subtile/scheduler_hostile_draft.dm',
 'tests/human_subtile/scheduler_hostile_stage.py',
 'tests/human_subtile/test_scheduler_hostile_contract.py'])


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
