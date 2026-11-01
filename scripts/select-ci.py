"""Fail-closed compilation selection and bounded reviewed offline impact selection."""
import argparse
import os
import json
import re
from pathlib import PurePosixPath
import subprocess

DOC_WORKFLOWS = {'.github/workflows/api-docs.yml', '.github/workflows/api-pages.yml'}
CI_BASES = {'master', 'help-markdown-byond-html'}
ORDINARY_PR_ACTIONS = {'opened', 'synchronize', 'reopened'}
# Reviewed source preparation, not native entry points. These exact files retain
# ci_baseline's character_return_preparation suite; never exempt the directory.
SOURCE_PREPARATION_ONLY_TESTS = frozenset({
    'tests/world_save/character_return/fixture.dm',
    'tests/world_save/character_return/prepare.py',
    'tests/world_save/character_return/test_prepare.py',
})

# These exact tests run in their respective offline baseline suites.
PLAYER_HELP_OFFLINE_TESTS = frozenset({'tests/player_help/test_help_links.py',
                                      'tests/player_help/test_wiki_guides.py'})

# These existing Atlas tests are reviewed exceptions to added-test selection.
# Exact paths keep unrelated edits from requesting costly native fixtures.
ATLAS_TEST_INPUTS = {
    'tests/test_crafting_atlas.py': 'tests/test_crafting_atlas.py',
    'tests/crafting_atlas/probe.dm': 'tests/crafting_atlas',
    'tests/crafting_atlas/resource-search.test.mjs': 'tests/crafting_atlas',
}


def starts_build(message):
    """The first line is literal data, with no case folding or whitespace trim."""
    return isinstance(message, str) and message.split('\n', 1)[0].startswith('build:')


def load_event(path):
    try:
        with open(path, encoding='utf-8') as event_file:
            event = json.load(event_file)
        return event if isinstance(event, dict) else {}
    except (OSError, ValueError, TypeError):
        return {}


def edited_change_kind(payload):
    """Recognize title/body edits and base retargets; ambiguous data is invalid."""
    pr = payload.get('pull_request')
    if not isinstance(pr, dict) or not isinstance(pr.get('title'), str) or not pr['title']:
        return 'invalid'
    if 'body' not in pr or not (pr['body'] is None or isinstance(pr['body'], str)):
        return 'invalid'
    for field in ('head', 'base'):
        row = pr.get(field)
        if not isinstance(row, dict) or not isinstance(row.get('sha'), str) or not re.fullmatch(r'[0-9a-f]{40}', row['sha']):
            return 'invalid'
    changes = payload.get('changes')
    if not isinstance(changes, dict) or not changes or not set(changes) <= {'title', 'body', 'base'}:
        return 'invalid'
    for field in ('title', 'body'):
        if field in changes:
            row = changes[field]
            if not isinstance(row, dict) or set(row) != {'from'}:
                return 'invalid'
            if not isinstance(row['from'], str) and not (field == 'body' and row['from'] is None):
                return 'invalid'
            if row['from'] == pr[field] or field == 'title' and not row['from']:
                return 'invalid'
    if 'base' in changes:
        base = changes['base']
        if not isinstance(base, dict) or not set(base) <= {'ref', 'sha'} or 'ref' not in base:
            return 'invalid'
        ref = base['ref']
        if not isinstance(ref, dict) or set(ref) != {'from'} or not isinstance(ref['from'], str) or not ref['from']:
            return 'invalid'
        if 'sha' in base:
            old_sha = base['sha']
            if not isinstance(old_sha, dict) or set(old_sha) != {'from'} or not isinstance(old_sha['from'], str):
                return 'invalid'
        return 'retarget'
    return 'text'


def build_policy(event, payload):
    """Return ordinary eligibility and a compile-only request.

    Expanded subscriptions must not expand introduced-test/native eligibility.
    Missing or capped push metadata conservatively requests only compilation.
    """
    if event == 'workflow_dispatch':
        return True, False
    if event == 'push':
        if payload.get('deleted') is True:
            return False, False
        ordinary = payload.get('ref') == 'refs/heads/master'
        commits = payload.get('commits')
        if not isinstance(commits, list) or not commits or len(commits) >= 2048:
            return ordinary, True
        if any(not isinstance(commit, dict) or not isinstance(commit.get('message'), str)
               for commit in commits):
            return ordinary, True
        # Some event producers also report a size; refuse to treat a partial
        # list as proof that no pushed commit requested a build.
        size = payload.get('size', len(commits))
        if not isinstance(size, int) or size > len(commits):
            return ordinary, True
        return ordinary, any(starts_build(commit['message']) for commit in commits)
    if event == 'pull_request':
        pr = payload.get('pull_request')
        if not isinstance(pr, dict) or not isinstance(pr.get('title'), str):
            return False, True
        base = pr.get('base', {})
        ordinary = (isinstance(base, dict)
                    and base.get('ref') in CI_BASES
                    and payload.get('action') in ORDINARY_PR_ACTIONS)
        return ordinary, starts_build(pr['title'])
    return False, False


def eligibility(event, payload, build_prefix):
    """Separate compiler work, unchanged native admission and check identity.

    A compile-only event cannot replace a full ordinary scope's native verdict.
    Missing scope metadata is not evidence for an informational classification.
    """
    ordinary, forced = build_policy(event, payload) if build_prefix else (True, False)
    action = payload.get('action')
    base_ref = None
    metadata_valid, supported_edit, gating, skip_duplicate = True, False, False, False
    scope_reason = 'Event outside full ordinary CI scope'
    if event == 'pull_request':
        pr = payload.get('pull_request')
        base = pr.get('base') if isinstance(pr, dict) else None
        base_ref = base.get('ref') if isinstance(base, dict) else None
        metadata_valid = (isinstance(pr, dict) and isinstance(pr.get('title'), str) and bool(pr['title'])
                          and isinstance(base, dict) and isinstance(base.get('ref'), str) and bool(base['ref'])
                          and isinstance(action, str) and bool(action))
        kind = edited_change_kind(payload) if action == 'edited' and build_prefix else None
        if kind == 'invalid':
            metadata_valid = False
        supported = metadata_valid and base['ref'] in CI_BASES
        if kind == 'retarget':
            # Existing native gates explicitly exclude edited events. Do not claim
            # a full retarget check until those gates can admit and verify it.
            metadata_valid = False
        supported_edit = supported and action == 'edited' and kind != 'retarget'
        gating = supported and action in ORDINARY_PR_ACTIONS
        skip_duplicate = bool(build_prefix and metadata_valid and kind == 'text' and not forced)
        scope_reason = ('Full ordinary PR admission' if gating else
                        'Edited PR omits introduced/native admission' if supported_edit else
                        'PR outside full ordinary base/action scope')
    elif event == 'push':
        metadata_valid = isinstance(payload.get('ref'), str) and bool(payload.get('ref'))
        gating = (metadata_valid and payload['ref'] == 'refs/heads/master'
                  and payload.get('deleted') is not True)
        scope_reason = 'Full ordinary master-push scope' if gating else 'Non-master/deleted push omits full PR coverage'
    elif event == 'workflow_dispatch':
        scope_reason = 'Manual opt-ins do not replace ordinary PR coverage'
    if not build_prefix:
        # Other reusable callers keep their pre-existing selection behavior.
        metadata_valid = True
    elif not metadata_valid:
        scope_reason = 'Missing event scope metadata; selection must fail closed'
    compile_eligible = (ordinary or supported_edit or forced) and not skip_duplicate
    compile_reason = ('Manual CI requires compilation and the native toolchain' if build_prefix and event == 'workflow_dispatch' else
                      'Validated title/body edit reuses existing required checks' if skip_duplicate else
                      'Explicit build: request or incomplete metadata requires compilation' if forced else
                      'Supported edited PR: evaluate exact base/head diff' if supported_edit else
                      'Ordinary/legacy event: evaluate exact base/head diff' if ordinary else
                      'Outside automatic compilation scope')
    native_reason = ('Legacy reusable caller retains its existing admission' if not build_prefix else
                     'Existing ordinary PR introduced-suite admission' if ordinary and event == 'pull_request' else
                     'Existing master-push policy; introduced PR suites remain off' if ordinary and event == 'push' else
                     'Manual extensive admission still requires its explicit input' if ordinary else
                     'No introduced/native or extensive admission for this event')
    return dict(action=action if isinstance(action, str) else None, skip_duplicate=skip_duplicate,
                base_ref=base_ref if isinstance(base_ref, str) else None,
                ref=payload.get('ref') if isinstance(payload.get('ref'), str) else None,
                metadata_valid=metadata_valid,
                compile=dict(eligible=compile_eligible, reason=compile_reason),
                native=dict(eligible=ordinary, reason=native_reason),
                gating=dict(eligible=bool(gating), reason=scope_reason), forced=forced)


def selections(base, head, event, opted_in, build_prefix=False, payload=None):
    policy = eligibility(event, payload or {}, build_prefix)
    if policy['skip_duplicate']:
        return False, False, [], 'Validated title/body edit; reuse existing required checks'
    game, reason = select(base, head) if policy['compile']['eligible'] else (False, 'Outside ordinary CI subscription')
    if build_prefix and event == 'workflow_dispatch':
        # Manual inputs can request native fixtures independently of the diff.
        # The build job also installs their BYOND toolchain.
        game, reason = True, 'Manual CI run; compile game and prepare native toolchain'
    elif policy['forced']:
        game, reason = True, 'build: request or incomplete event metadata; compile game'
    new_tests = (sorted(set(introduced_tests(base, head, event)) |
                        set(changed_atlas_tests(base, head, event)))
                 if policy['native']['eligible'] else [])
    extensive = policy['native']['eligible'] and game and needs_extensive(event, opted_in)
    return game, extensive, new_tests, reason

def needs_game(paths):
    # Compilation depends on shared includes. Unknown paths compile, but do
    # not implicitly authorize running existing regression suites.
    return any(PurePosixPath(path).suffix.lower() in {'.dm', '.dme', '.dmm', '.dmi', '.rsc'} or not (
        path.startswith('docs/') or
        (len(PurePosixPath(path).parts) == 1 and path.endswith('.md')) or
        path == 'scripts/build-api-docs.py' or path in DOC_WORKFLOWS
    ) for path in paths)

def select(base, head):
    if not base or not head or set(base) == {'0'}:
        return True, 'No reliable comparison; compile game'
    try:
        paths = subprocess.check_output(
            ['git', 'diff', '--name-only', '--no-renames', '-z', base, head],
            stderr=subprocess.PIPE, timeout=15).decode('utf-8').split('\0')
    except (subprocess.SubprocessError, UnicodeError):
        return True, 'Comparison unavailable; compile game'
    paths = [path for path in paths if path]
    game = needs_game(paths)
    return game, 'Game/shared/unknown changes' if game else 'Only documentation generation or prose changed'

def needs_extensive(event, opted_in):
    return event == 'workflow_dispatch' and opted_in

def changed_atlas_tests(base, head, event):
    """Select only explicitly reviewed Atlas test edits on ordinary PRs."""
    if event != 'pull_request':
        return []
    if not base or not head or set(base) == {'0'}:
        raise RuntimeError('Atlas test selection requires a valid base and head comparison')
    try:
        paths = subprocess.check_output(
            ['git', 'diff', '--name-only', '--no-renames', '--diff-filter=AM', '-z',
             base, head, '--', *ATLAS_TEST_INPUTS],
            stderr=subprocess.PIPE, timeout=15).decode('utf-8').split('\0')
    except (subprocess.SubprocessError, OSError, UnicodeError) as exc:
        raise RuntimeError('Atlas test selection could not compare base and head; check Git and the refs') from exc
    return sorted({ATLAS_TEST_INPUTS[path] for path in paths if path in ATLAS_TEST_INPUTS})


def select_mcp(base, head, event):
    """Select the offline MCP workflow without expanding native suite admission."""
    if event == 'workflow_dispatch' or (event == 'push' and (not base or set(base) == {'0'})):
        return True
    if not base or not head or set(base) == {'0'}:
        raise RuntimeError('MCP selection requires a valid base and head comparison')
    try:
        paths = subprocess.check_output(
            ['git', 'diff', '--name-only', '--no-renames', '-z', base, head],
            stderr=subprocess.PIPE, timeout=15).decode('utf-8').split('\0')
    except (subprocess.SubprocessError, OSError, UnicodeError) as exc:
        raise RuntimeError('MCP selection could not compare base and head') from exc
    return any(path.startswith('tools/mcp/') or path in {
        '.github/workflows/mcp.yml', 'scripts/select-ci.py', 'tests/test_ci_selection.py',
        'scripts/ci_checkout_refs.py', 'tests/test_ci_checkout_refs.py',
        'scripts/nomads-lifecycle/agent_debug.py',
        'scripts/nomads-lifecycle/variable_observability.py',
        'scripts/nomads-lifecycle/read_blackout.py',
        'tests/nomads_lifecycle/test_agent_debug.py',
        'tests/nomads_lifecycle/test_variable_observability.py',
        # Fixed production readers and phase-contract inputs; no general DM glob.
        'code/modules/persistence/functions.dm', 'code/modules/persistence/saving.dm',
        'code/modules/persistence/restart_transaction.dm',
        'code/modules/persistence/nomads_lifecycle.dm',
        'code/modules/persistence/variable_observability.dm',
        'code/modules/persistence/zone_topology.dm'
    } for path in paths)


def introduced_tests(base, head, event):
    """Only added executable tests on a PR qualify, never edits or prose.

    Rename detection stays enabled so moving an existing test is not treated
    as introducing integration coverage. Missing comparisons select no suites.
    """
    if event != 'pull_request' or not base or not head or set(base) == {'0'}:
        return []
    try:
        paths = subprocess.check_output(
            ['git', 'diff', '--name-only', '--diff-filter=A', '-M', '-z', base, head],
            stderr=subprocess.PIPE, timeout=15).decode('utf-8').split('\0')
    except (subprocess.SubprocessError, UnicodeError):
        return []
    suites = set()
    for path in paths:
        if path in SOURCE_PREPARATION_ONLY_TESTS or path in PLAYER_HELP_OFFLINE_TESTS:
            continue
        parts = PurePosixPath(path).parts
        suffix = PurePosixPath(path).suffix.lower()
        if len(parts) >= 2 and parts[0] == 'tests' and suffix in {'.py', '.ps1', '.dm', '.sh'}:
            suites.add('/'.join(parts[:2]))
        elif path in {'scripts/opendream/bounded_build/test_guard.py',
                      'scripts/opendream/bounded_build/test_windows.py'}:
            suites.add('scripts/opendream/bounded_build')
        elif path.startswith('tools/') and (path.endswith('.test.mjs') or path.endswith('.test.js')):
            suites.add('/'.join(parts[:2]))
    return sorted(suites)


def validate_manual_base(base, head, cwd=None):
    """Manual runs need explicit immutable, locally available distinct commits."""
    if not re.fullmatch(r'[0-9a-f]{40}', base or '') or not re.fullmatch(r'[0-9a-f]{40}', head or ''):
        raise ValueError('Manual CI requires comparison_base and head as full lowercase 40-character commit IDs')
    if base == head:
        raise ValueError('Manual comparison_base must differ from the head commit')
    try:
        for value in (base, head):
            resolved = subprocess.check_output(['git', 'rev-parse', '--verify', value + '^{commit}'],
                                               cwd=cwd, stderr=subprocess.PIPE, timeout=15).decode('utf-8').strip()
            if resolved != value:
                raise ValueError('Manual comparison commit identity mismatch')
    except (subprocess.SubprocessError, UnicodeError) as exc:
        raise ValueError('Manual comparison_base or head is unavailable in the local checkout') from exc


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', default='')
    parser.add_argument('--head', default='')
    parser.add_argument('--output', required=True)
    parser.add_argument('--event', default='')
    parser.add_argument('--extensive', choices=('true', 'false'), default='false')
    parser.add_argument('--build-prefix', choices=('true', 'false'), default='false')
    parser.add_argument('--receipt', help='Exact-source machine-readable selection receipt')
    parser.add_argument('--mcp-only', action='store_true', help='Select the independent offline MCP workflow')
    args = parser.parse_args()
    if args.mcp_only:
        try:
            selected = select_mcp(args.base, args.head, args.event)
        except RuntimeError as error:
            parser.error(str(error))
        with open(args.output, 'a', encoding='utf-8') as output:
            output.write(f'mcp={str(selected).lower()}\n')
        return
    if args.event == 'workflow_dispatch' and args.build_prefix == 'true':
        try:
            validate_manual_base(args.base, args.head)
        except ValueError as error:
            parser.error(str(error))
    payload = load_event(os.environ.get('GITHUB_EVENT_PATH'))
    policy = eligibility(args.event, payload, args.build_prefix == 'true')
    if args.build_prefix == 'true' and args.event == 'pull_request' and payload.get('action') == 'edited':
        pr = payload.get('pull_request')
        if (not isinstance(pr, dict) or not isinstance(pr.get('head'), dict)
                or not isinstance(pr.get('base'), dict) or pr['head'].get('sha') != args.head
                or pr['base'].get('sha') != args.base):
            policy['metadata_valid'] = False
            policy['skip_duplicate'] = False
    game, extensive, new_tests, reason = selections(
        args.base, args.head, args.event, args.extensive == 'true',
        args.build_prefix == 'true', payload)
    if args.receipt:
        from ci_baseline import selection_receipt, write_json
        receipt = selection_receipt(args.base, args.head, game, extensive,
                                    new_tests, reason, args.event, policy)
        if not policy['metadata_valid']:
            receipt['status'] = 'failed'
        write_json(args.receipt, receipt)
    if not policy['metadata_valid']:
        parser.error('Missing event scope metadata; refusing to publish informational success')
    with open(args.output, 'a', encoding='utf-8') as output:
        output.write('new_tests=' + json.dumps(new_tests, separators=(',', ':')) + '\n')
        output.write(f'game={str(game).lower()}\nextensive={str(extensive).lower()}\n')
        output.write(f'gating={int(policy["gating"]["eligible"])}\n')
        output.write(f'skip_duplicate={str(policy["skip_duplicate"]).lower()}\n')
    print(f'game={str(game).lower()}, extensive={str(extensive).lower()}, introduced suites={new_tests}: {reason}')
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a', encoding='utf-8') as output:
            output.write(f'Game compilation selected: **{game}**. Extensive regressions opted in: **{extensive}**. {reason}. New test suites selected: `{new_tests}`.\n')
            output.write(f'Gating context eligible: **{policy["gating"]["eligible"]}**. {policy["gating"]["reason"]}.\n')

if __name__ == '__main__':
    main()
