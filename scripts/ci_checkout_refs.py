"""Prepare immutable event/source comparisons without changing HEAD."""
import argparse
import json
from pathlib import Path
import os
import re
import subprocess
import sys

SHA = re.compile(r'^[0-9a-f]{40}$')


def git(*args, check=True, cwd=None, timeout=90):
    env = os.environ.copy()
    env['GIT_TERMINAL_PROMPT'] = '0'
    result = subprocess.run(['git', *args], capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=timeout, env=env, cwd=cwd)
    if check and result.returncode:
        raise RuntimeError('Git preparation failed: ' + (result.stderr or result.stdout)[-2000:])
    return result


ZERO = '0' * 40
MAX_PUSH_COMMITS = 2048
MAX_MERGE_FRONTIER = 64


def push_event():
    try:
        value = json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text(encoding='utf-8'))
    except (KeyError, OSError, ValueError) as error:
        raise ValueError('New-branch comparison requires complete push metadata or an explicit comparison_base') from error
    if not isinstance(value, dict):
        raise ValueError('Invalid new-branch push metadata')
    return value


def push_evidence(head, payload):
    """Keep comparison evidence without resolving a moving branch name."""
    if (not isinstance(payload, dict) or payload.get('before') != ZERO
            or payload.get('after') != head or payload.get('created') is not True
            or payload.get('deleted') is not False
            or not isinstance(payload.get('ref'), str)
            or not payload['ref'].startswith('refs/heads/')
            or len(payload['ref']) <= len('refs/heads/')):
        raise ValueError('Invalid new-branch source/head metadata')
    commits = payload.get('commits')
    if not isinstance(commits, list) or len(commits) >= MAX_PUSH_COMMITS:
        raise ValueError('Missing or potentially truncated new-branch commit set')
    ids = []
    for row in commits:
        value = row.get('id') if isinstance(row, dict) else None
        if not isinstance(value, str) or not SHA.fullmatch(value) or value == ZERO:
            raise ValueError('Invalid pushed commit identity')
        ids.append(value)
    size = payload.get('size', len(ids))
    distinct = payload.get('distinct_size', None)
    tip = payload.get('head_commit')
    if (type(size) is not int or size != len(ids) or len(set(ids)) != len(ids)
            or (distinct is not None and (type(distinct) is not int or not 0 <= distinct <= size))
            or not isinstance(tip, dict) or tip.get('id') != head
            or (ids and head not in ids)):
        raise ValueError('Incomplete or inconsistent new-branch commit metadata')
    evidence = dict(before=ZERO, after=head, created=True, deleted=False,
                    ref=payload['ref'], commits=[dict(id=x) for x in sorted(ids)],
                    size=size, head_commit=dict(id=head))
    if distinct is not None:
        evidence['distinct_size'] = distinct
    return evidence


class MissingHistory(ValueError):
    pass


def new_branch_comparison(head, payload, *, fetch=False, cwd=None):
    """Derive a real parent snapshot without changing the event diff or HEAD.

    Read raw parent headers so a shallow boundary cannot masquerade as a root.
    If needed, one bounded exact-head fetch obtains the complete pushed chain
    and its boundary. The existing event comparison remains unavailable.
    """
    if not isinstance(head, str) or not SHA.fullmatch(head) or head == ZERO:
        raise ValueError('Expected a nonzero source-comparison head')
    if git('rev-parse', '--verify', 'HEAD^{commit}', cwd=cwd).stdout.strip() != head:
        raise ValueError('Source-comparison head differs from checkout')
    evidence = push_evidence(head, payload)
    pushed = {row['id'] for row in evidence['commits']}

    def derive():
        cache = {}
        def parents(value):
            if value not in cache:
                kind = git('cat-file', '-t', value, check=False, cwd=cwd)
                if kind.returncode:
                    raise MissingHistory('New-branch comparison history unavailable; supply comparison_base')
                if kind.stdout.strip() != 'commit':
                    raise ValueError('New-branch comparison object is not a commit')
                raw = git('cat-file', 'commit', value, cwd=cwd).stdout
                rows = [x[7:] for x in raw.split('\n\n', 1)[0].splitlines() if x.startswith('parent ')]
                if any(not SHA.fullmatch(x) or x == ZERO for x in rows):
                    raise ValueError('Invalid commit parent identity')
                cache[value] = rows
            return cache[value]
        if pushed:
            pending, reached = [head], set()
            while pending:
                value = pending.pop()
                if value in reached:
                    continue
                reached.add(value)
                pending.extend(x for x in parents(value) if x in pushed)
            if reached != pushed:
                raise ValueError('Pushed commit set is disconnected from event head')
        if pushed:
            if any(not parents(value) for value in reached):
                raise ValueError('New-branch root has no real comparison parent; supply comparison_base')
            boundaries = {parent for value in reached for parent in parents(value) if parent not in pushed}
            frontier = sorted(boundaries)
            if len(frontier) == 1:
                value = frontier[0]
            else:
                if not frontier or len(frontier) > MAX_MERGE_FRONTIER:
                    raise ValueError('New-branch merge frontier exceeds bound; supply comparison_base')
                for boundary in frontier:
                    parents(boundary)
                common = git('merge-base', '--all', '--octopus', *frontier, check=False, cwd=cwd)
                if common.returncode:
                    raise MissingHistory('Merged new-branch ancestry unavailable; supply comparison_base')
                candidates = common.stdout.splitlines()
                if len(candidates) != 1:
                    raise ValueError('Ambiguous new-branch common ancestor; supply comparison_base')
                value = candidates[0]
                if not SHA.fullmatch(value) or value == ZERO or value in pushed:
                    raise ValueError('Invalid merged new-branch comparison ancestor')
                # A proven ancestor of every external parent covers the full
                # pushed subgraph plus any already-existing merge history.
                for boundary in frontier:
                    ancestry = git('merge-base', '--is-ancestor', value, boundary, check=False, cwd=cwd)
                    if ancestry.returncode:
                        raise MissingHistory('Unproved new-branch frontier ancestry; supply comparison_base')
        else:
            frontier = []
            links = parents(head)
            if not links:
                raise ValueError('New-branch root has no real comparison parent; supply comparison_base')
            value = links[0]
        parents(value)  # Require the exact comparison commit object, not merely its hash.
        return value, frontier if len(frontier) > 1 else []

    try:
        base, frontier = derive()
    except MissingHistory:
        if not fetch:
            raise
        # At most one fetch, by immutable SHA, bounded by git() and the job step.
        git('fetch', '--no-tags', '--depth=' + str(max(2, len(pushed) + 1)),
            'origin', head, cwd=cwd)
        base, frontier = derive()
    if base == head or base == ZERO:
        raise ValueError('Invalid self/zero source comparison')
    if git('rev-parse', '--verify', 'HEAD^{commit}', cwd=cwd).stdout.strip() != head:
        raise RuntimeError('Source comparison changed checked-out head')
    proof = dict(schema_version=1, kind='new-branch-push-range' if pushed else 'new-branch-tip-parent',
                 base=base, head=head, evidence=evidence)
    if frontier:
        proof.update(kind='new-branch-merge-frontier', frontier=frontier)
    return proof



MAX_ATLAS_COMMITS = 2048


def atlas_pr_comparison(base, head, *, fetch=False, cwd=None):
    """Prove one merge base without trusting a shallow graph's apparent roots.

    Only Atlas PR admission uses this origin. Event base/head remain unchanged.
    Excluding the candidate and its proven ancestors bounds the graph we need;
    any shallow boundary above that exclusion makes the proof incomplete.
    """
    if any(not isinstance(value, str) or not SHA.fullmatch(value) or value == ZERO for value in (base, head)):
        raise ValueError('Atlas PR comparison requires exact nonzero base and head SHAs')
    def run(*args, check=True, timeout=15):
        result = git('--no-replace-objects', *args, check=check, cwd=cwd, timeout=timeout)
        if len(result.stdout.encode('utf-8')) > 1024*1024:
            raise ValueError('Atlas ancestry output bound exceeded')
        return result
    def metadata(name):
        path = Path(run('rev-parse', '--git-path', name).stdout.strip())
        if not path.is_absolute():
            path = Path(cwd or os.getcwd())/path
        if not path.exists():
            return ''
        if path.stat().st_size > 1024*1024:
            raise ValueError('Atlas ancestry metadata bound exceeded')
        return path.read_text(encoding='ascii')
    def check_head():
        if run('rev-parse', '--verify', 'HEAD^{commit}').stdout.strip() != head:
            raise ValueError('Atlas event head differs from checked-out head')
    check_head()
    if metadata('info/grafts').strip():
        raise ValueError('Atlas ancestry does not accept grafted history')
    def derive():
        for value in (base, head):
            result = run('rev-parse', '--verify', value+'^{commit}', check=False)
            if result.returncode or result.stdout.strip() != value:
                raise MissingHistory('Atlas event commit unavailable')
        shallow_text = metadata('shallow')
        shallow = set(shallow_text.splitlines())
        if any(not SHA.fullmatch(value) for value in shallow):
            raise ValueError('Invalid Atlas shallow-boundary metadata')
        result = run('merge-base', '--all', base, head, check=False)
        if result.returncode:
            if shallow or result.returncode != 1:
                raise MissingHistory('Atlas common ancestry unavailable or incomplete')
            raise ValueError('Atlas PR histories are unrelated')
        candidates = result.stdout.splitlines()
        if len(candidates) != 1 or not SHA.fullmatch(candidates[0]):
            raise ValueError('Atlas PR comparison requires a unique merge base')
        ancestor = candidates[0]
        for value in (base, head):
            if run('merge-base', '--is-ancestor', ancestor, value, check=False).returncode:
                raise MissingHistory('Atlas common ancestor not proved')
        result = run('rev-list', '--boundary', '--max-count='+str(MAX_ATLAS_COMMITS+1),
                     base, head, '--not', ancestor, check=False)
        if result.returncode:
            raise MissingHistory('Atlas comparison history is incomplete')
        rows = result.stdout.splitlines()
        if any(not SHA.fullmatch(row.removeprefix('-')) for row in rows):
            raise ValueError('Invalid Atlas ancestry identity')
        visited = {row for row in rows if not row.startswith('-')}
        if len(visited) > MAX_ATLAS_COMMITS:
            raise ValueError('Atlas ancestry exceeds the bounded comparison range')
        if visited & shallow:
            raise MissingHistory('Atlas comparison crosses an incomplete shallow boundary')
        check_head()
        return dict(kind='atlas-pr-merge-base', event_base=base, head=head, ancestor=ancestor,
                    range_commits=len(visited), max_range_commits=MAX_ATLAS_COMMITS)
    try:
        return derive()
    except MissingHistory:
        if not fetch:
            raise
    # One exact-SHA bounded fetch, no moving branch names or first-parent guess.
    run('fetch', '--no-tags', '--depth='+str(MAX_ATLAS_COMMITS+1), 'origin', base, head, timeout=90)
    return derive()


def prepare(head, base, event, payload=None, *, atlas_ancestry=False):
    if not SHA.fullmatch(head) or head == '0' * 40:
        raise ValueError('Expected a nonzero full head SHA')
    if git('rev-parse', '--verify', 'HEAD^{commit}').stdout.strip() != head:
        raise ValueError('Checked-out head differs from event head')
    if not base or base == '0' * 40:
        if event == 'pull_request':
            raise ValueError('Pull request requires an immutable base SHA')
        if event == 'push' and base == ZERO:
            return new_branch_comparison(head, payload if payload is not None else push_event(), fetch=True)
        return
    if atlas_ancestry and event == 'pull_request':
        return atlas_pr_comparison(base, head, fetch=True)
    if not SHA.fullmatch(base):
        raise ValueError('Expected a full comparison SHA')
    if git('cat-file', '-e', base + '^{commit}', check=False).returncode:
        git('fetch', '--no-tags', '--depth=1', 'origin', base)
    if git('cat-file', '-e', base + '^{commit}', check=False).returncode:
        raise RuntimeError('Comparison commit unavailable after fetch')
    if git('rev-parse', '--verify', 'HEAD^{commit}').stdout.strip() != head:
        raise RuntimeError('Git preparation changed the checked-out head')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--head', required=True)
    parser.add_argument('--base', default='')
    parser.add_argument('--event', required=True)
    parser.add_argument('--atlas-ancestry', action='store_true', help='Bounded Atlas-only ordinary PR ancestry preparation')
    args = parser.parse_args()
    try:
        prepare(args.head, args.base, args.event, atlas_ancestry=args.atlas_ancestry)
    except (ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        print('CI checkout preparation failed: ' + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
