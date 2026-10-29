"""Replay the independently reviewed #3082 squash delta across live event inputs.

Snapshots select the reviewed delta, never the event identity or candidate source.
The live base still comes from the immutable event; whole-file equality remains
mandatory for all four modules. This does not grant native execution admission.
"""
import subprocess

from historical_fixtures import text
from source_contract import replay_reviewed_merge, require_complete_history

BEFORE = '4f2868cd58e89ed99eda715b3241ff980d2de41d'
AFTER = '76c6f244f6eca7f2f7b9037da80181c52d498afb'
PATHS = ('code/modules/persistence/functions.dm',
         'code/processes/human_corpse_decay.dm',
         'code/processes/abandoned_items.dm',
         'code/modules/1713/active_training.dm')


def project(repo, identity, current):
    try:
        ancestry = subprocess.run(['git', 'merge-base', '--is-ancestor', AFTER, identity['head']],
                                  cwd=repo, capture_output=True, text=True, timeout=15)
    except (OSError, subprocess.SubprocessError) as error:
        raise ValueError('Cannot verify integrated ancestry') from error
    if ancestry.returncode == 1:
        require_complete_history(repo, 'integrated ancestry')
        return False
    if ancestry.returncode != 0:
        raise ValueError('Cannot verify integrated ancestry: Git exited ' + str(ancestry.returncode))
    for path in PATHS:
        base = subprocess.check_output(['git', 'show', identity['base'] + ':' + path],
                                       cwd=repo, text=True, encoding='utf-8', timeout=15)
        expected = replay_reviewed_merge(base, text(BEFORE, path), text(AFTER, path))
        if current[path] != expected:
            raise ValueError('Integrated source drift from reviewed event-base projection: ' + path)
    return True
