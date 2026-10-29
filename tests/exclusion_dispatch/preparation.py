"""Validate immutable comparison identities before generating fixture sources."""
import json
from pathlib import Path
import re
import subprocess
from historical_fixtures import text as historical_text
import integrated_projection

from source_contract import (current_lighting_policy, reconstruct_list_baseline, validate_current_master,
                             project_merged_source, resolve_event_projection, replay_reviewed_merge, has_ordered_release_history, require_complete_history,
                             MERGE_BASE, MERGE_MASTER)

PATH = 'code/modules/persistence/functions.dm'
INHERITED = (
    ('code/processes/human_corpse_decay.dm', '/atom/movable/persistence_runtime_var(key)'),
    ('code/processes/abandoned_items.dm', '/obj/item/persistence_runtime_var(key)'),
    ('code/modules/1713/active_training.dm', '/mob/living/human/persistence_runtime_var(key)'),
)
FIXTURE = tuple('tests/exclusion_dispatch/' + name for name in (
    'run.py', 'run-ci.py', 'run-ci-current.py', 'source_contract.py', 'preparation.py', 'resources.py', 'probe.dm',
    'historical_fixtures.py', 'fixtures/manifest.json', 'integrated_projection.py',
    'fixtures/mall-before-squash-functions.dm.txt', 'fixtures/extraction-squash-functions.dm.txt',
    'fixtures/mall-before-squash-human_corpse_decay.dm.txt', 'fixtures/extraction-squash-human_corpse_decay.dm.txt',
    'fixtures/mall-before-squash-abandoned_items.dm.txt', 'fixtures/extraction-squash-abandoned_items.dm.txt',
    'fixtures/mall-before-squash-active_training.dm.txt', 'fixtures/extraction-squash-active_training.dm.txt',
    'fixtures/extraction-reviewed-functions.dm.txt', 'fixtures/reconciliation-base-functions.dm.txt',
    'fixtures/extraction-human-corpse-decay.dm.txt', 'fixtures/seed-human-corpse-decay.dm.txt',
    'fixtures/extraction-abandoned-items.dm.txt', 'fixtures/seed-abandoned-items.dm.txt',
    'fixtures/extraction-active-training.dm.txt', 'fixtures/seed-active-training.dm.txt'))


def git(repo, *arguments):
    return subprocess.check_output(['git', *arguments], cwd=repo, text=True,
                                   encoding='utf-8', stderr=subprocess.PIPE, timeout=15)


def has_extraction_history(repo, head):
    command = ['git', 'merge-base', '--is-ancestor', MERGE_BASE, head]
    try:
        result = subprocess.run(command, cwd=repo, text=True, encoding='utf-8',
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=15)
    except (OSError, subprocess.SubprocessError) as error:
        raise ValueError('Cannot verify extraction ancestry; Git failed or timed out') from error
    if result.returncode == 0:
        return True
    if result.returncode == 1:
        require_complete_history(repo, 'extraction ancestry')
        return False
    raise ValueError(f'Cannot verify extraction ancestry; Git exited {result.returncode}: {result.stderr.strip()}')


def identities(repo, base, head, event_path=None, event_name=None, github_actions=False):
    manual_error = ('Manual exclusion checks require exclusion_comparison_base: supply a full '
                    'immutable commit SHA distinct from the selected head in workflow inputs')
    if event_name == 'workflow_dispatch' and not base:
        raise ValueError(manual_error)
    for role, value in (('base', base), ('head', head)):
        if not value or not re.fullmatch(r'[0-9a-f]{40}', value) or set(value) == {'0'}:
            raise ValueError(f'Missing or non-immutable {role} identity; full nonzero SHA required')
        if git(repo, 'rev-parse', '--verify', value + '^{commit}').strip() != value:
            raise ValueError(f'{role} identity is not the exact commit')
    if base == head:
        raise ValueError('Base/head self-comparison is forbidden')
    actual_head = git(repo, 'rev-parse', 'HEAD').strip()
    if actual_head != head:
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
        elif event_name == 'workflow_dispatch':
            manual_base = event.get('inputs', {}).get('exclusion_comparison_base')
            if not manual_base:
                raise ValueError(manual_error)
            expected = (manual_base, actual_head)
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
    # A branch descended from extraction must retain its complete reviewed
    # custody projection even if it otherwise matches the lighting-only base.
    extraction_history = has_extraction_history(repo, head)
    projection = 'lighting-only'
    if extraction_history and integrated_projection.project(repo, identity, current):
        projection = 'reviewed-integrated-base'
    elif extraction_history:
        feature = historical_text(MERGE_BASE, PATH)
        master = historical_text(MERGE_MASTER, PATH)
        reviewed = project_merged_source(feature)
        _, projection = resolve_event_projection(repo, identity, feature, current[PATH], master, reviewed,
                                                 ordered_release=has_ordered_release_history(repo, head))
    else:
        validate_current_master(old, current[PATH])
    for path, _ in INHERITED:
        if projection == 'reviewed-integrated-base':
            # Independently replayed and compared in integrated_projection.
            continue
        pinned = committed(base, path)
        if projection == 'feature-base':
            pinned = replay_reviewed_merge(pinned, historical_text(MERGE_BASE, path), historical_text(MERGE_MASTER, path))
        if current[path] != pinned:
            raise ValueError('Inherited helper drift from event base: ' + path)
    return identity, reconstruct_list_baseline(current[PATH]), current, projection
