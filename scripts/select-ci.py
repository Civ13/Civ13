"""Fail-closed selection for expensive game checks; unknown paths compile; regressions require opt-in or new tests."""
import argparse
import os
import json
from pathlib import PurePosixPath
import subprocess

DOC_WORKFLOWS = {'.github/workflows/api-docs.yml', '.github/workflows/api-pages.yml'}

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
            stderr=subprocess.PIPE).decode('utf-8').split('\0')
    except (subprocess.CalledProcessError, UnicodeError):
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
            stderr=subprocess.PIPE).decode('utf-8').split('\0')
    except (subprocess.CalledProcessError, UnicodeError):
        return []
    suites = set()
    for path in paths:
        parts = PurePosixPath(path).parts
        suffix = PurePosixPath(path).suffix.lower()
        if len(parts) >= 2 and parts[0] == 'tests' and suffix in {'.py', '.ps1', '.dm', '.sh'}:
            suites.add('/'.join(parts[:2]))
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
    args = parser.parse_args()
    game, reason = select(args.base, args.head)
    new_tests = introduced_tests(args.base, args.head, args.event)
    extensive = game and needs_extensive(args.event, args.extensive == 'true')
    with open(args.output, 'a', encoding='utf-8') as output:
        output.write('new_tests=' + json.dumps(new_tests, separators=(',', ':')) + '\n')
        output.write(f'game={str(game).lower()}\nextensive={str(extensive).lower()}\n')
    print(f'game={str(game).lower()}, extensive={str(extensive).lower()}, introduced suites={new_tests}: {reason}')
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a', encoding='utf-8') as output:
            output.write(f'Game compilation selected: **{game}**. Extensive regressions opted in: **{extensive}**. {reason}. New test suites selected: `{new_tests}`.\n')

if __name__ == '__main__':
    main()
