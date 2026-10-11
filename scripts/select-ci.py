"""Fail-closed selection for expensive game checks; unknown paths run all suites."""
import argparse
import os
from pathlib import PurePosixPath
import subprocess

DOC_WORKFLOWS = {'.github/workflows/api-docs.yml', '.github/workflows/api-pages.yml'}

def needs_game(paths):
    # Full-game probes compile the DME and its shared includes. Do not maintain
    # a partial subsystem dependency graph: every non-doc change runs them all.
    return any(PurePosixPath(path).suffix.lower() in {'.dm', '.dme', '.dmm', '.dmi', '.rsc'} or not (
        path.startswith('docs/') or
        (len(PurePosixPath(path).parts) == 1 and path.endswith('.md')) or
        path == 'scripts/build-api-docs.py' or path in DOC_WORKFLOWS
    ) for path in paths)

def select(base, head):
    if not base or not head or set(base) == {'0'}:
        return True, 'No reliable comparison; run all game checks'
    try:
        paths = subprocess.check_output(
            ['git', 'diff', '--name-only', '--no-renames', '-z', base, head],
            stderr=subprocess.PIPE).decode('utf-8').split('\0')
    except (subprocess.CalledProcessError, UnicodeError):
        return True, 'Comparison unavailable; run all game checks'
    paths = [path for path in paths if path]
    game = needs_game(paths)
    return game, 'Game/shared/unknown changes' if game else 'Only documentation generation or prose changed'

def needs_extensive(event, opted_in):
    return event == 'workflow_dispatch' and opted_in

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', default='')
    parser.add_argument('--head', default='')
    parser.add_argument('--output', required=True)
    parser.add_argument('--event', default='')
    parser.add_argument('--extensive', choices=('true', 'false'), default='false')
    args = parser.parse_args()
    game, reason = select(args.base, args.head)
    extensive = game and needs_extensive(args.event, args.extensive == 'true')
    with open(args.output, 'a', encoding='utf-8') as output:
        output.write(f'game={str(game).lower()}\nextensive={str(extensive).lower()}\n')
    print(f'game={str(game).lower()}, extensive={str(extensive).lower()}: {reason}')
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a', encoding='utf-8') as output:
            output.write(f'Game compilation selected: **{game}**. Extensive regressions opted in: **{extensive}**. {reason}.\n')

if __name__ == '__main__':
    main()
