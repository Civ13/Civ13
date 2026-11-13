"""Player changelog for the in-game lobby (code/modules/player_changelog).

Pull requests carry one optional `Changelog:` line in their description
(tools/changelog/README.md). This collects those lines from recently merged
pull requests whose merge commit is part of the running revision, and writes
config/player-changelog.json for the world's What's New window.

The host (gaia_host.py start, shard_group.py handover) runs it beside
config/server-build.json, best effort: a network or GitHub failure keeps the
previous file and never stops a start. It needs no GitHub Actions and no token
(one unauthenticated API request per new revision); set CIV13_GITHUB_TOKEN to
lift the anonymous rate limit. By hand, for a server started without the host:

    py -3 scripts/gaia-host/player_changelog.py --repo D:/GitHub/Civ13
"""
from __future__ import annotations

import argparse
import calendar
import json
import os
from pathlib import Path
import re
import subprocess
import time
import unicodedata
import urllib.request

REPOSITORY = 'Civ13/Civ13'
FILE = Path('config') / 'player-changelog.json'
MAX_ENTRIES = 60
PAGES = 2  # 200 most recently updated closed PRs: a few days of merges
# Merge commits older than this many commits on the running revision are not checked;
# the window shows the newest entries only.
HISTORY_DEPTH = 600
BYOND_EPOCH = 946684800  # 2000-01-01 UTC
HEX40 = re.compile(r'^[0-9a-f]{40}$')

PLACEHOLDERS = {'required', 'optional', 'todo', 'to do', 'tbd', 'to be determined', 'fixme', 'pending',
                'placeholder', 'example', 'none', 'n/a', 'not applicable', 'no changelog', 'your changelog here',
                'changelog text here', 'player-facing text here'}
INSTRUCTION = re.compile(r'^(?:enter|insert|write|add|fill in|describe|replace)(?: the| your| a)? '
                         r'(?:changelog|player-facing|player-visible)(?:\b|$)')
UNSAFE = re.compile('[\r\n\x00-\x1f\x7f@<>\u202e\u202d]')
LINE = re.compile(r'^Changelog:[ \t]*(.*)$', re.IGNORECASE)
FENCE = re.compile(r'^\s*(`{3,}|~{3,})')


def changelog_line(body):
    """The PR description's Changelog: text, or None when it has none or it is not
    publishable. Mirrors tools/changelog/publish.mjs changelogLine, except that an
    invalid field is skipped here rather than failing (the PR check already reports it)."""
    if not isinstance(body, str) or len(body) > 65536:
        return None
    visible = re.sub(r'<!--[\s\S]*?(?:-->|$)', '', body)
    fence = None
    entries = []
    for line in re.split(r'\r*\n', visible):
        delimiter = FENCE.match(line)
        if delimiter:
            mark = delimiter.group(1)
            if not fence:
                fence = mark
            elif mark[0] == fence[0] and len(mark) >= len(fence):
                fence = None
            continue
        if fence:
            continue
        match = LINE.match(line)
        if match:
            entries.append(match.group(1).strip())
    if len(entries) != 1 or not entries[0]:
        return None
    text = entries[0]
    marker = re.sub(r'^[\s`*_\[\]{}:]+|[\s`*_\[\]{}:.!?]+$', '', unicodedata.normalize('NFKC', text).lower()).strip()
    nested = re.sub(r'[\s`*_\[\]{}:.!?]+$', '', re.split(r'\s+player changelog\s*:', marker)[0]).strip()
    if nested in PLACEHOLDERS or INSTRUCTION.search(marker):
        return None
    if len(text.encode('utf-16-le')) // 2 > 1500 or UNSAFE.search(text):
        return None
    return text


def entries_from_pulls(pulls, included):
    """Newest-first entries for merged PRs whose merge commit `included` accepts."""
    rows = []
    for pull in pulls if isinstance(pulls, list) else []:
        if not isinstance(pull, dict) or not pull.get('merged_at'):
            continue
        sha = str(pull.get('merge_commit_sha') or '')
        number = pull.get('number')
        if not HEX40.match(sha) or not isinstance(number, int) or not included(sha):
            continue
        text = changelog_line(pull.get('body'))
        if not text:
            continue
        merged = str(pull['merged_at'])
        try:
            stamp = calendar.timegm(time.strptime(merged, '%Y-%m-%dT%H:%M:%SZ'))
        except ValueError:
            continue
        rows.append({'pr': number, 'text': text, 'date': merged[:10], 'merged': stamp,
                     'merged_minute': (stamp - BYOND_EPOCH) // 60})
    rows.sort(key=lambda row: (row['merged'], row['pr']), reverse=True)
    for row in rows:
        del row['merged']
    return rows[:MAX_ENTRIES]


def http_get_json(url, token=None, timeout=10):
    headers = {'Accept': 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28',
               'User-Agent': 'civ13-host'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=timeout) as response:
        return json.loads(response.read().decode('utf-8'))


def pulls_url(repository=REPOSITORY):
    return ('https://api.github.com/repos/%s/pulls?state=closed&base=master&sort=updated'
            '&direction=desc&per_page=100' % repository)


def write(repo, revision, history, fetch, now=None, repository=REPOSITORY, force=False):
    """Write <repo>/config/player-changelog.json for `revision`. `history` is the set of
    commits reachable from it (None when unknown: every merged PR counts). Returns the
    entry count written, or None when the file was kept (same revision or a failure)."""
    path = Path(repo) / FILE
    try:
        previous = json.loads(path.read_text(encoding='utf-8'))
    except (OSError, ValueError):
        previous = None
    if not force and isinstance(previous, dict) and previous.get('revision') == revision:
        return None
    pulls = []
    try:
        for page in range(1, PAGES + 1):
            batch = fetch(pulls_url(repository) + '&page=%d' % page)
            if not isinstance(batch, list):
                return None
            pulls += batch
            if len(batch) < 100:
                break
    except Exception:  # offline or rate limited: the previous list stays
        return None
    entries = entries_from_pulls(pulls, (lambda sha: sha in history) if history is not None else (lambda sha: True))
    now = int(time.time() if now is None else now)
    record = {'schema': 1, 'revision': revision, 'repository': repository,
              'generated_minute': (now - BYOND_EPOCH) // 60, 'entries': entries}
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(record, ensure_ascii=False), encoding='utf-8')
    os.replace(temporary, path)
    return len(entries)


def history_from_output(code, out):
    if code != 0:
        return None
    commits = {line.strip() for line in out.splitlines() if HEX40.match(line.strip())}
    return commits or None


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('--repo', default='.', help='the server checkout (default: current folder)')
    parser.add_argument('--revision', default='HEAD')
    parser.add_argument('--git', default='git')
    args = parser.parse_args(argv)
    run = lambda *a: subprocess.run([args.git, *a], cwd=args.repo, capture_output=True, text=True, timeout=60)
    head = run('rev-parse', args.revision)
    revision = head.stdout.strip()
    if head.returncode != 0 or not HEX40.match(revision):
        parser.error('could not resolve %s in %s' % (args.revision, args.repo))
    listing = run('rev-list', '--max-count=%d' % HISTORY_DEPTH, revision)
    history = history_from_output(listing.returncode, listing.stdout)
    token = os.environ.get('CIV13_GITHUB_TOKEN') or None
    count = write(args.repo, revision, history, lambda url: http_get_json(url, token), force=True)
    if count is None:
        print('could not reach GitHub; config/player-changelog.json was not changed')
        return 1
    print('wrote %d changelog entries for %s to %s' % (count, revision[:12], Path(args.repo) / FILE))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
