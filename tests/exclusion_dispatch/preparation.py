"""Validate immutable comparison identities before generating fixture sources."""
import json
from pathlib import Path
import re
import subprocess

from source_contract import current_lighting_policy, reconstruct_list_baseline, validate_current_master

PATH = 'code/modules/persistence/functions.dm'
INHERITED = (
    ('code/processes/human_corpse_decay.dm', '/atom/movable/persistence_runtime_var(key)'),
    ('code/processes/abandoned_items.dm', '/obj/item/persistence_runtime_var(key)'),
    ('code/modules/1713/active_training.dm', '/mob/living/human/persistence_runtime_var(key)'),
)
FIXTURE = tuple('tests/exclusion_dispatch/' + name for name in (
    'run.py', 'run-ci.py', 'source_contract.py', 'preparation.py', 'resources.py', 'probe.dm'))


def git(repo, *arguments):
    return subprocess.check_output(['git', *arguments], cwd=repo, text=True,
                                   encoding='utf-8', stderr=subprocess.PIPE, timeout=15)


def identities(repo, base, head, event_path=None, event_name=None, github_actions=False):
    for role, value in (('base', base), ('head', head)):
        if not value or not re.fullmatch(r'[0-9a-f]{40}', value) or set(value) == {'0'}:
            raise ValueError(f'Missing or non-immutable {role} identity; full nonzero SHA required')
        if git(repo, 'rev-parse', '--verify', value + '^{commit}').strip() != value:
            raise ValueError(f'{role} identity is not the exact commit')
    if base == head:
        raise ValueError('Base/head self-comparison is forbidden')
    if git(repo, 'rev-parse', 'HEAD').strip() != head:
        raise ValueError('Requested head differs from checked-out HEAD')
    # A PR event base need not be an ancestor of an unrefreshed feature branch.
    if not git(repo, 'merge-base', base, head).strip():
        raise ValueError('Base/head have no common history')
    if github_actions and not event_path:
        raise ValueError('GitHub event metadata is required in Actions')
    if event_path:
        event = json.loads(Path(event_path).read_text(encoding='utf-8'))
        if event_name == 'pull_request':
            expected = (event['pull_request']['base']['sha'], event['pull_request']['head']['sha'])
        elif event_name == 'push':
            expected = (event['before'], event['after'])
        else:
            raise ValueError('No immutable base/head pair for this event')
        if (base, head) != expected:
            raise ValueError('Requested identities differ from immutable event base/head')
    return dict(base=base, head=head, identity_source='event' if event_path else 'explicit offline identities')


def prepare(repo, base, head, **event):
    identity = identities(repo, base, head, **event)
    # Read independent commit objects, then verify the actual fixture inputs.
    # Never construct the comparison from candidate bytes or a moving ref.
    def committed(revision, path):
        return git(repo, 'show', revision + ':' + path)

    current = {}
    for path in (PATH, *(file for file, _ in INHERITED), *FIXTURE):
        text = (repo / path).read_text(encoding='utf-8')
        if text != committed(head, path):
            raise ValueError('Working input differs from checked-out head: ' + path)
        current[path] = text
    old = committed(base, PATH)
    validate_current_master(old, current[PATH])
    for path, _ in INHERITED:
        if current[path] != committed(base, path):
            raise ValueError('Inherited helper drift from event base: ' + path)
    return identity, reconstruct_list_baseline(current_lighting_policy(old)), current
