"""Prepare immutable event/source comparisons without changing HEAD."""
import argparse
import json
from pathlib import Path
import os
import re
import subprocess
import sys

SHA = re.compile(r'^[0-9a-f]{40}$')


def git(*args, check=True, cwd=None):
    env = os.environ.copy()
    env['GIT_TERMINAL_PROMPT'] = '0'
    result = subprocess.run(['git', *args], capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=90, env=env, cwd=cwd)
    if check and result.returncode:
        raise RuntimeError('Git preparation failed: ' + (result.stderr or result.stdout)[-2000:])
    return result


ZERO = '0' * 40
MAX_PUSH_COMMITS = 2048


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
            if len(boundaries) != 1:
                raise ValueError('Ambiguous new-branch parent boundary; supply comparison_base')
            value = next(iter(boundaries))
        else:
            links = parents(head)
            if not links:
                raise ValueError('New-branch root has no real comparison parent; supply comparison_base')
            value = links[0]
        parents(value)  # Require the exact boundary commit object, not merely its hash.
        return value

    try:
        base = derive()
    except MissingHistory:
        if not fetch:
            raise
        # At most one fetch, by immutable SHA, bounded by git() and the job step.
        git('fetch', '--no-tags', '--depth=' + str(max(2, len(pushed) + 1)),
            'origin', head, cwd=cwd)
        base = derive()
    if base == head or base == ZERO:
        raise ValueError('Invalid self/zero source comparison')
    if git('rev-parse', '--verify', 'HEAD^{commit}', cwd=cwd).stdout.strip() != head:
        raise RuntimeError('Source comparison changed checked-out head')
    return dict(schema_version=1, kind='new-branch-push-range' if pushed else 'new-branch-tip-parent',
                base=base, head=head, evidence=evidence)


def prepare(head, base, event, payload=None):
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
    args = parser.parse_args()
    try:
        prepare(args.head, args.base, args.event)
    except (ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        print('CI checkout preparation failed: ' + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
