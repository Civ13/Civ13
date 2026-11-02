"""Bind the exact pair-order experiment without accepting unrelated tree changes."""
import re
import subprocess
import time
import pair_stage

PARENT = '8f403183ac7f8faa5b7e0e7941f14be89ff468c6'
PARENT_TREE = '782af0b64ac5f989323b7ec48e49ddfe2e4bf5ed'
ALLOWED_DELTA = frozenset({
    '.github/workflows/wildlife-cardinal-cadence.yml',
    'tests/human_subtile/cloud_npc_controller.py',
    'tests/human_subtile/cloud_npc_job.py',
    'tests/human_subtile/cloud_npc_smoke.py',
    'tests/human_subtile/pair_measure.dm',
    'tests/human_subtile/pair_stage.py',
    'tests/human_subtile/pair_receipt.py',
    'tests/human_subtile/pair_materialize.py',
    'tests/human_subtile/pair_worker.py',
    'tests/human_subtile/pair_evidence.py',
    'tests/human_subtile/pair_binding.py',
    'tests/human_subtile/test_pair_order.py',
    'tests/human_subtile/test_pair_integration.py',
    'tests/human_subtile/test_bump_integration.py',
})


def budget_timeout(maximum, deadline):
    if deadline is None:
        return maximum
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise TimeoutError('pair host-validation deadline')
    return min(maximum, remaining)


def validate_head(git, head, env=None, deadline=None):
    if type(head) is not str or re.fullmatch('[0-9a-f]{40}', head) is None:
        raise ValueError('invalid pair experiment head')
    parent = subprocess.check_output(git + ['rev-parse', head + '^'], timeout=budget_timeout(10, deadline), env=env).decode().strip()
    parent_tree = subprocess.check_output(git + ['rev-parse', head + '^^{tree}'], timeout=budget_timeout(10, deadline), env=env).decode().strip()
    if parent != PARENT or parent_tree != PARENT_TREE:
        raise ValueError('pair experiment parent mismatch')
    raw = subprocess.check_output(git + ['diff', '--no-ext-diff', '--no-renames', '--name-only', '-z',
                                         PARENT, head, '--'], timeout=budget_timeout(30, deadline), env=env)
    parts = raw.split(b'\0')
    if parts[-1] != b'' or not all(parts[:-1]):
        raise ValueError('invalid pair delta encoding')
    paths = [x.decode('utf-8') for x in parts[:-1]]
    if len(paths) != len(set(paths)) or frozenset(paths) != ALLOWED_DELTA:
        raise ValueError('pair delta differs from reviewed paths')
    tree = subprocess.check_output(git + ['rev-parse', head + '^{tree}'], timeout=budget_timeout(10, deadline), env=env).decode().strip()
    if re.fullmatch('[0-9a-f]{40}', tree) is None:
        raise ValueError('invalid pair tree')
    return tree


def read_inputs(git, env=None, deadline=None):
    tree = subprocess.check_output(git + ['rev-parse', pair_stage.BASE + '^{tree}'],
                                   timeout=budget_timeout(10, deadline), env=env).decode().strip()
    if tree != pair_stage.BASE_TREE:
        raise ValueError('base complete tree differs')
    result = {}
    for path, expected in pair_stage.BLOBS.items():
        raw = subprocess.check_output(git + ['show', pair_stage.BASE + ':' + path],
                                      timeout=budget_timeout(10, deadline), env=env)
        if pair_stage.blob(raw) != expected:
            raise ValueError('base blob mismatch: ' + path)
        result[path] = raw
    return result
