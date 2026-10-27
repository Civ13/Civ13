"""Fail-closed compilation selection and bounded reviewed offline impact selection."""
import argparse
import os
import json
from pathlib import PurePosixPath
import subprocess

DOC_WORKFLOWS = {'.github/workflows/api-docs.yml', '.github/workflows/api-pages.yml'}
CI_BASES = {'master', 'help-markdown-byond-html'}
ORDINARY_PR_ACTIONS = {'opened', 'synchronize', 'reopened'}


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
    metadata_valid, supported_edit, gating = True, False, False
    scope_reason = 'Event outside full ordinary CI scope'
    if event == 'pull_request':
        pr = payload.get('pull_request')
        base = pr.get('base') if isinstance(pr, dict) else None
        base_ref = base.get('ref') if isinstance(base, dict) else None
        metadata_valid = (isinstance(pr, dict) and isinstance(pr.get('title'), str)
                          and isinstance(base, dict) and isinstance(base.get('ref'), str) and bool(base['ref'])
                          and isinstance(action, str) and bool(action))
        supported = metadata_valid and base['ref'] in CI_BASES
        supported_edit = supported and action == 'edited'
        gating = supported and action in ORDINARY_PR_ACTIONS
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
    compile_eligible = ordinary or supported_edit or forced
    compile_reason = ('Explicit build: request or incomplete metadata requires compilation' if forced else
                      'Supported edited PR: evaluate exact base/head diff' if supported_edit else
                      'Ordinary/legacy event: evaluate exact base/head diff' if ordinary else
                      'Outside automatic compilation scope')
    native_reason = ('Legacy reusable caller retains its existing admission' if not build_prefix else
                     'Existing ordinary PR introduced-suite admission' if ordinary and event == 'pull_request' else
                     'Existing master-push policy; introduced PR suites remain off' if ordinary and event == 'push' else
                     'Manual extensive admission still requires its explicit input' if ordinary else
                     'No introduced/native or extensive admission for this event')
    return dict(action=action if isinstance(action, str) else None,
                base_ref=base_ref if isinstance(base_ref, str) else None,
                ref=payload.get('ref') if isinstance(payload.get('ref'), str) else None,
                metadata_valid=metadata_valid,
                compile=dict(eligible=compile_eligible, reason=compile_reason),
                native=dict(eligible=ordinary, reason=native_reason),
                gating=dict(eligible=bool(gating), reason=scope_reason), forced=forced)


def selections(base, head, event, opted_in, build_prefix=False, payload=None):
    policy = eligibility(event, payload or {}, build_prefix)
    game, reason = select(base, head) if policy['compile']['eligible'] else (False, 'Outside ordinary CI subscription')
    if policy['forced']:
        game, reason = True, 'build: request or incomplete event metadata; compile game'
    new_tests = introduced_tests(base, head, event) if policy['native']['eligible'] else []
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', default='')
    parser.add_argument('--head', default='')
    parser.add_argument('--output', required=True)
    parser.add_argument('--event', default='')
    parser.add_argument('--extensive', choices=('true', 'false'), default='false')
    parser.add_argument('--build-prefix', choices=('true', 'false'), default='false')
    parser.add_argument('--receipt', help='Exact-source machine-readable selection receipt')
    args = parser.parse_args()
    payload = load_event(os.environ.get('GITHUB_EVENT_PATH'))
    policy = eligibility(args.event, payload, args.build_prefix == 'true')
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
    print(f'game={str(game).lower()}, extensive={str(extensive).lower()}, introduced suites={new_tests}: {reason}')
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a', encoding='utf-8') as output:
            output.write(f'Game compilation selected: **{game}**. Extensive regressions opted in: **{extensive}**. {reason}. New test suites selected: `{new_tests}`.\n')
            output.write(f'Gating context eligible: **{policy["gating"]["eligible"]}**. {policy["gating"]["reason"]}.\n')

if __name__ == '__main__':
    main()
