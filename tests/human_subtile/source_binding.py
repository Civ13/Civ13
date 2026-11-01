"""Read exact historic transition inputs, not files from a dirty worktree.

This does not yet bind a published fixture tree, runner, or resulting archive.
"""
import subprocess
import re
import time
from build_guard import blob

BASE = '7436e0d95c069ebf13ce620763c3e619417ede38'
TREE = '68a32a6f3b772b2daac56b64f7c995240b746774'
BLOBS = {
    'civ13.dme': '3dd48f947b1b681844fd71c9eb84586998b71caa',
    'code/game/mob/living/living.dm': '296c8a2e370cf4aef77c68a6c7b3ee86b9c15e22',
    'code/game/mob/living/carbon/human/subtile_movement.dm': '3a3566e5c766ef4ce7d97971c6021cf8b5b7b534',
    'code/game/mob/living/simple_animal/friendly/farm_animals.dm': '42da8b3fb0223ab9a4d9542fdd566d4a4ff08042',
    'code/game/mob/living/simple_animal/subtile_movement.dm': 'c658aa260cd486f5c8a82dc796e048c321362d54',
    'code/game/mob/living/simple_animal/hostile/tactical_ai.dm': 'e83f103f7f014b8e47a3a852eb78c8e5e2c98f1f',
    'tests/human_subtile/probe.dm': '58afd77c15b3b89a3c924e428068085b04f6614a',
    'tests/human_subtile/npc.dm': '000b3713c9a156e4a35029fea4efa5af3af1778b',
    'tests/human_subtile/run-npc.py': '8a73c8ab42e2b33782c674a3ca4c37958731b768',
}
ALLOWED_DELTA = frozenset({
    '.github/workflows/wildlife-cardinal-cadence.yml',
    'tests/human_subtile/cloud_npc_controller.py', 'tests/human_subtile/cloud_npc_job.py',
    'tests/human_subtile/cloud_npc_smoke.py', 'tests/human_subtile/bump_guard_preimage.dm',
    'tests/human_subtile/bump_fixture_observer.dm', 'tests/human_subtile/bump_fixture_probe.dm',
    'tests/human_subtile/build_guard.py', 'tests/human_subtile/source_binding.py',
    'tests/human_subtile/stage_observer.py', 'tests/human_subtile/stage_bundle.py',
    'tests/human_subtile/materialize_pair.py', 'tests/human_subtile/receipt.py',
    'tests/human_subtile/runner_limits.py', 'tests/human_subtile/bump_worker.py',
    'tests/human_subtile/test_cardinal_worker.py',
    'tests/human_subtile/bump_evidence.py', 'tests/human_subtile/test_bump_integration.py',
    'tests/human_subtile/test_guard.py', 'tests/human_subtile/test_source_binding.py',
    'tests/human_subtile/test_stage.py', 'tests/human_subtile/test_stage_bundle.py',
    'tests/human_subtile/test_materialize_pair.py', 'tests/human_subtile/test_receipt.py',
    'tests/human_subtile/test_runner_limits.py',
})


def budget_timeout(maximum, deadline):
    if deadline is None:
        return maximum
    left = deadline - time.monotonic()
    if left <= 0:
        raise TimeoutError('bump host-validation deadline')
    return min(maximum, left)


def validate_head(git, head, env=None, deadline=None):
    if type(head) is not str or re.fullmatch('[0-9a-f]{40}', head) is None:
        raise ValueError('invalid experiment head')
    ancestor = subprocess.run(git + ['merge-base', '--is-ancestor', BASE, head],
                              capture_output=True, timeout=budget_timeout(10, deadline), env=env)
    if ancestor.returncode:
        raise ValueError('experiment does not descend from baseline')
    raw = subprocess.check_output(git + ['diff', '--no-ext-diff', '--no-renames',
                                         '--name-only', '-z', BASE, head, '--'], timeout=budget_timeout(30, deadline), env=env)
    parts = raw.split(b'\0')
    if parts[-1] != b'' or not all(parts[:-1]):
        raise ValueError('invalid experiment delta encoding')
    paths = [x.decode('utf-8') for x in parts[:-1]]
    if len(paths) != len(set(paths)) or frozenset(paths) != ALLOWED_DELTA:
        raise ValueError('experiment delta differs from reviewed path set')
    tree = subprocess.check_output(git + ['rev-parse', head + '^{tree}'], timeout=budget_timeout(10, deadline), env=env).decode().strip()
    if re.fullmatch('[0-9a-f]{40}', tree) is None:
        raise ValueError('invalid experiment tree')
    return tree


def read_inputs(git, expected_head, execute=subprocess.check_output, env=None, deadline=None):
    if expected_head != BASE:
        raise ValueError('baseline head differs from reviewed transition')
    if execute(git + ['rev-parse', BASE + '^{tree}'], timeout=budget_timeout(10, deadline), env=env).decode().strip() != TREE:
        raise ValueError('baseline complete tree differs')
    result = {}
    for path, expected in BLOBS.items():
        raw = execute(git + ['show', BASE + ':' + path], timeout=budget_timeout(10, deadline), env=env)
        if blob(raw) != expected:
            raise ValueError('source blob differs: ' + path)
        result[path] = raw
    return result
