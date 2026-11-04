"""Summarize every GitHub Actions check on a PR head into one comment.

Run by .github/workflows/agent-ci-digest.yml each time a PR workflow
completes. A pass that sees checks still running exits at once (no runner is
held waiting); the pass that sees every Actions check on the head finished
classifies each failure as infrastructure, known pre-existing or needs-fix,
reruns infrastructure-only first attempts once, and posts a comment for the
head with a Markdown table, log excerpts and a machine-readable JSON block.
Any API failure (rate limit, outage) exits 0 without a digest; agents then
read CI directly. See docs/agent-ci-digest.md.

Standard library only. Uses the workflow's GITHUB_TOKEN; never checks out or
runs pull request code.

    python3 scripts/ci_digest.py --sha <head> [--pr N] [--report-pending]
    python3 scripts/ci_digest.py --sha <head> --dry-run   # print, post nothing
    python3 scripts/ci_digest.py sync-workflows [--write]  # trigger list
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import time
import urllib.error
import urllib.request

MARKER = '<!-- agent-ci-digest'
API = os.environ.get('GITHUB_API_URL', 'https://api.github.com')
SELF_JOB = 'digest'
TIMESTAMP = re.compile(r'^﻿?\d{4}-\d\d-\d\dT[\d:.]+Z ?')

# Failures outside the code under test. Matched against the failed step's log
# window. Each entry is (pattern, reason).
INFRA = tuple((re.compile(p, re.I), reason) for p, reason in (
    (r'runner has received a shutdown signal', 'runner shut down'),
    (r'lost communication with the server', 'runner lost contact'),
    (r'The operation was canceled', 'operation cancelled'),
    (r'Could not resolve host', 'DNS failure'),
    (r"unable to access 'https://", 'git network failure'),
    (r'RPC failed|early EOF|fetch-pack: unexpected disconnect', 'git transfer failure'),
    (r'Connection (?:reset by peer|timed out)|Operation timed out|ETIMEDOUT|ECONNRESET', 'network timeout'),
    (r'(?:HTTP Error|status code|returned error:?)\s*5\d\d|\b50[234] (?:Bad Gateway|Service Unavailable|Gateway Time-?out)',
     'server error 5xx'),
    (r'Unable to (?:download|find) artifact|Artifact not found|No artifacts? found', 'missing artifact'),
    (r'API rate limit exceeded|secondary rate limit', 'GitHub rate limit'),
    (r'No space left on device', 'runner disk full'),
))
# Failed step names that never run project code.
INFRA_STEPS = re.compile(r'^(?:Set up job|Initialize containers|Complete job|Post .*|'
                         r'.*\b(?:checkout|check out|download-artifact|upload-artifact|cache)\b.*)$', re.I)
# Failures documented as pre-existing on master (see the civ13-pr-preflight skill).
KNOWN = tuple((re.compile(p, re.I), reason) for p, reason in (
    (r'capture budget', 'moving-save benchmark capture budget (fails on master too)'),
))
# Evidence that project code or a test actually failed.
REAL = re.compile(r'\bFAILED\b|AssertionError|Traceback \(most recent call last\)|^\S.*\.dm:\d+:error:|'
                  r'\b[1-9]\d* errors?, \d+ warnings?|runtime error:|^FAIL:|^ERROR: test|'
                  r'(?i:failed at its named assertion|assertion failed)|^FAIL\b', re.M)


ANSI = re.compile(r'\x1b\[[0-9;]*m')


def clean(log):
    return [ANSI.sub('', TIMESTAMP.sub('', line.rstrip('\r'))) for line in log.splitlines()]


def failure_window(lines, limit=40, errors_kept=8):
    """Output leading up to the first ##[error], plus the error lines.

    Drops each step's echoed script (##[group]Run ... ##[endgroup]) and runner
    bookkeeping so the excerpt is the failing command's own output.
    """
    errors = [i for i, line in enumerate(lines) if line.startswith('##[error]')]
    end = errors[0] if errors else len(lines)
    body, in_header = [], False
    for line in lines[max(0, end - 600):end]:
        if line.startswith('##[group]Run '):
            in_header = True
            continue
        if line.startswith('##[endgroup]'):
            in_header = False
            continue
        if in_header or not line.strip() or line.startswith(('##[group]', '[command]', '##[debug]')):
            continue
        body.append(line)
    return body[-limit:] + [lines[i] for i in errors[:errors_kept]]


def classify(conclusion, step, lines):
    """Return (class, reason). Classes: infra, known, timeout, real, unknown."""
    # Only the first failing command: later errors (e.g. an evidence upload
    # that found nothing) are consequences, not causes.
    window = '\n'.join(failure_window(lines, limit=200, errors_kept=1))
    for pattern, reason in KNOWN:
        if pattern.search(window):
            return 'known', reason
    if conclusion == 'timed_out':
        return 'timeout', 'job hit its time limit'
    if conclusion == 'cancelled' and not REAL.search(window):
        return 'infra', 'job cancelled'
    if step and INFRA_STEPS.match(step):
        return 'infra', f'failed in step "{step}"'
    if REAL.search(window):
        return 'real', f'test or compile failure in step "{step or "?"}"'
    for pattern, reason in INFRA:
        if pattern.search(window):
            return 'infra', reason
    return 'unknown', f'failed in step "{step or "?"}"; read the excerpt'


def verdict(failures, pending, reruns=()):
    if reruns:
        return 'rerunning'
    if pending:
        return 'pending'
    classes = {f['class'] for f in failures}
    if not classes:
        return 'green'
    if classes <= {'infra'}:
        return 'infra-only'
    if classes <= {'infra', 'known'}:
        return 'known-only'
    return 'needs-fix'


ADVICE = {
    'green': 'All GitHub Actions checks passed on this head.',
    'infra-only': 'Every failure is infrastructure. Under the local-build policy, document the exact-head '
                  'local compile and preflight, then the PR may be admin-merged with authorization.',
    'known-only': 'Only known pre-existing failures (plus any infrastructure). Note them in the PR with this '
                  'run link; do not change gameplay code for them.',
    'needs-fix': 'At least one failure looks like a real test, compile or unknown failure. Read the excerpt, '
                 'reproduce locally and fix it.',
    'pending': 'Some checks were still running.',
    'rerunning': 'Every failure was infrastructure on its first attempt, so the failed jobs were rerun once. '
                 'A final digest follows when the reruns finish; if none appears, check the reruns by hand.',
}


def render(sha, summary, failures, pending, reruns, run_url):
    state = verdict(failures, pending, reruns)
    counts = summary
    head = (f"### CI digest for `{sha[:10]}`: **{state}**\n\n"
            f"{counts['success']} passed, {len(failures)} failed, {counts['skipped']} skipped"
            f"{', %d still running' % len(pending) if pending else ''}. {ADVICE[state]}\n")
    parts = [head]
    if reruns:
        parts.append('Rerun requested for: '
                     + ', '.join(f'[run {r}](https://github.com/{os.environ.get("GITHUB_REPOSITORY", "")}/actions/runs/{r})'
                                 for r in reruns) + '.\n')
    if failures:
        parts.append('| Workflow | Job | Failed step | Class | Reason |\n|---|---|---|---|---|')
        for f in failures:
            parts.append(f"| {f['workflow']} | [{f['job']}]({f['url']}) | {f['step'] or '-'} | {f['class']} | {f['reason']} |")
        parts.append('')
        budget = 40000
        for f in failures:
            text = '\n'.join(f['excerpt'])[-4000:].replace('```', "'''")
            if len(text) > budget:
                break
            budget -= len(text)
            parts.append(f"<details><summary>{f['workflow']} / {f['job']}</summary>\n\n```\n{text}\n```\n</details>\n")
    if pending:
        parts.append('Still running: ' + ', '.join(pending) + '\n')
    if run_url:
        parts.append(f'<sub>Digest run: {run_url}</sub>\n')
    data = {'sha': sha, 'verdict': state, 'counts': counts, 'pending': pending, 'reruns': reruns,
            'failed': [{k: f[k] for k in ('workflow', 'job', 'run_id', 'job_id', 'attempt', 'step', 'class',
                                          'reason', 'url')} for f in failures]}
    signature = hashlib.sha256(json.dumps(data, sort_keys=True).encode()).hexdigest()[:16]
    body = '\n'.join(parts)
    return (f'{MARKER} sha={sha} sig={signature} verdict={state} -->\n{body}\n'
            f'<!-- agent-ci-digest-json {json.dumps(data, separators=(",", ":"))} -->\n'), state, signature


class GitHub:
    def __init__(self, repo, token):
        self.repo, self.token = repo, token

    def request(self, method, path, payload=None, raw=False):
        url = path if path.startswith('http') else f'{API}/repos/{self.repo}/{path}'
        data = json.dumps(payload).encode() if payload is not None else None
        req = urllib.request.Request(url, data=data, method=method, headers={
            'Authorization': f'Bearer {self.token}', 'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28', 'User-Agent': 'civ13-ci-digest'})
        for attempt in range(4):
            try:
                with urllib.request.urlopen(req, timeout=60) as response:
                    body = response.read()
                    return body.decode('utf-8', 'replace') if raw else (json.loads(body) if body else {})
            except urllib.error.HTTPError as error:
                if error.code < 500 or attempt == 3:
                    raise
            except urllib.error.URLError:
                if attempt == 3:
                    raise
            time.sleep(5 * (attempt + 1))

    def get(self, path):
        return self.request('GET', path)

    def check_runs(self, sha):
        runs, page = [], 1
        while True:
            batch = self.get(f'commits/{sha}/check-runs?filter=latest&per_page=100&page={page}')['check_runs']
            runs += batch
            if len(batch) < 100:
                return runs
            page += 1

    def job_log(self, job_id):
        # The API answers with a redirect to signed blob storage; follow it
        # without forwarding the token.
        class Stop(urllib.request.HTTPRedirectHandler):
            def redirect_request(self, *args, **kwargs):
                return None
        req = urllib.request.Request(f'{API}/repos/{self.repo}/actions/jobs/{job_id}/logs', headers={
            'Authorization': f'Bearer {self.token}', 'Accept': 'application/vnd.github+json',
            'User-Agent': 'civ13-ci-digest'})
        try:
            try:
                with urllib.request.build_opener(Stop).open(req, timeout=60) as response:
                    return response.read().decode('utf-8', 'replace')
            except urllib.error.HTTPError as error:
                if error.code not in (301, 302, 303, 307, 308):
                    raise
                location = error.headers['Location']
            with urllib.request.urlopen(urllib.request.Request(location, headers={'User-Agent': 'civ13-ci-digest'}),
                                        timeout=120) as response:
                return response.read().decode('utf-8', 'replace')
        except (urllib.error.URLError, OSError) as error:
            return f'##[error]digest could not read the job log: {error}'


def actions_checks(gh, sha, self_run):
    checks = []
    for run in gh.check_runs(sha):
        if (run.get('app') or {}).get('slug') != 'github-actions':
            continue
        match = re.search(r'/actions/runs/(\d+)/job/(\d+)', run.get('details_url') or '')
        if not match or match.group(1) == str(self_run):
            continue
        checks.append(dict(run, run_id=int(match.group(1)), job_id=int(match.group(2))))
    return checks


def collect(gh, sha, checks):
    summary = {'success': 0, 'skipped': 0, 'failed': 0}
    failures, pending = [], []
    run_names = {}
    for check in checks:
        if check['status'] != 'completed':
            pending.append(check['name'])
            continue
        conclusion = check['conclusion']
        if conclusion in ('success', 'neutral'):
            summary['success'] += 1
            continue
        if conclusion == 'skipped':
            summary['skipped'] += 1
            continue
        summary['failed'] += 1
        job = gh.get(f"actions/jobs/{check['job_id']}")
        if check['run_id'] not in run_names:
            run_names[check['run_id']] = gh.get(f"actions/runs/{check['run_id']}").get('name', '?')
        step = next((s['name'] for s in job.get('steps', []) if s.get('conclusion') in ('failure', 'timed_out', 'cancelled')), '')
        lines = clean(gh.job_log(check['job_id']))[-3000:]
        kind, reason = classify(conclusion, step, lines)
        failures.append({'workflow': run_names[check['run_id']], 'job': check['name'], 'run_id': check['run_id'],
                         'job_id': check['job_id'], 'attempt': job.get('run_attempt', 1), 'step': step,
                         'class': kind, 'reason': reason, 'url': check.get('html_url', ''),
                         'excerpt': failure_window(lines)})
    return summary, failures, pending


def pr_head(gh, pr):
    return gh.get(f'pulls/{pr}')['head']['sha']


def post(gh, pr, sha, body, signature, state):
    """One comment per head and verdict: a new verdict posts (and wakes
    subscribed agents); the same verdict with new details edits in place."""
    comments, page = [], 1
    while True:
        batch = gh.get(f'issues/{pr}/comments?per_page=100&page={page}')
        comments += batch
        if len(batch) < 100:
            break
        page += 1
    mine = [c for c in comments if (c.get('body') or '').startswith(f'{MARKER} sha={sha} ')]
    if mine:
        first_line = mine[-1]['body'].split('\n', 1)[0]
        if f'sig={signature} ' in first_line:
            return 'unchanged'
        if f' verdict={state} ' in first_line:
            gh.request('PATCH', f"issues/comments/{mine[-1]['id']}", {'body': body})
            return 'updated'
    gh.request('POST', f'issues/{pr}/comments', {'body': body})
    return 'posted'


def digest_once(gh, args, run_url):
    """One pass. Returns the verdict, or None when checks are still running."""
    if args.pr and not args.dry_run and pr_head(gh, args.pr) != args.sha:
        print(f'PR #{args.pr} moved past {args.sha}; a newer digest will report.')
        return None
    checks = actions_checks(gh, args.sha, os.environ.get('GITHUB_RUN_ID', ''))
    busy = [c['name'] for c in checks if c['status'] != 'completed']
    if busy and not args.report_pending:
        # Do not hold a runner slot waiting: the free plan has a small
        # concurrent-job limit. The next listed workflow to finish reports.
        print(f'{len(busy)} checks still running ({", ".join(busy[:6])}); a later completion will report.')
        return None
    summary, failures, pending = collect(gh, args.sha, checks)
    reruns = []
    first = [f for f in failures if f['attempt'] == 1]
    if (verdict(failures, pending) == 'infra-only' and len(first) == len(failures)
            and not args.no_rerun and not args.dry_run):
        for run_id in sorted({f['run_id'] for f in failures}):
            try:
                gh.request('POST', f'actions/runs/{run_id}/rerun-failed-jobs', {})
                reruns.append(run_id)
            except urllib.error.HTTPError as error:
                print(f'Rerun of run {run_id} refused: HTTP {error.code}')
    body, state, signature = render(args.sha, summary, failures, pending, reruns, run_url)
    summary_path = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary_path:
        with open(summary_path, 'a', encoding='utf-8') as handle:
            handle.write(body)
    print(body)
    print(f'AGENT-CI-DIGEST verdict={state} sha={args.sha} sig={signature}')
    if args.pr and not args.dry_run:
        print('Comment', post(gh, args.pr, args.sha, body, signature, state))
    return state


ROOT = Path(__file__).resolve().parents[1]
DIGEST_WORKFLOW = '.github/workflows/agent-ci-digest.yml'
LIST = re.compile(r'(  workflow_run:\n    workflows:\n)((?:      - .+\n)+)')


def pull_request_workflows(root=ROOT):
    """Names of every workflow with a pull_request trigger."""
    names = set()
    for path in sorted((root / '.github/workflows').glob('*.yml')):
        source = path.read_text(encoding='utf-8')
        if re.search(r'^  pull_request:?\s*$', source.split('\njobs:')[0], re.M):
            names.add(re.search(r'^name:\s*(.+?)\s*$', source, re.M).group(1).strip('\'"'))
    return names


def listed_workflows(text):
    return set(re.findall(r'^      - (.+)$', LIST.search(text).group(2), re.M))


def sync_workflows(root=ROOT, write=False):
    """Return (stale, text). With write, rewrite the digest's trigger list to
    every pull_request workflow so a new workflow is watched automatically."""
    path = root / DIGEST_WORKFLOW
    text = path.read_text(encoding='utf-8')
    expected = pull_request_workflows(root)
    stale = listed_workflows(text) != expected
    if stale and write:
        block = ''.join(f'      - {name}\n' for name in sorted(expected, key=str.lower))
        text = LIST.sub(lambda m: m.group(1) + block, text, count=1)
        path.write_text(text, encoding='utf-8')
    return stale, text


def sync_main(argv):
    parser = argparse.ArgumentParser(prog='ci_digest.py sync-workflows')
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args(argv)
    stale, _ = sync_workflows(write=args.write)
    state = 'regenerated' if stale and args.write else 'STALE (rerun with --write)' if stale else 'current'
    print(f'{DIGEST_WORKFLOW} trigger list: {state}')
    return 1 if stale and not args.write else 0


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if argv[:1] == ['sync-workflows']:
        return sync_main(argv[1:])
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--sha', required=True)
    parser.add_argument('--pr', type=int)
    parser.add_argument('--report-pending', action='store_true',
                        help='Report even while checks are running (manual runs)')
    parser.add_argument('--no-rerun', action='store_true', help='Do not rerun infrastructure-only failures')
    parser.add_argument('--dry-run', action='store_true', help='Print the digest; post and rerun nothing')
    args = parser.parse_args(argv)
    if not re.fullmatch(r'[0-9a-f]{40}', args.sha):
        parser.error('--sha must be a full 40-character commit SHA')
    gh = GitHub(os.environ['GITHUB_REPOSITORY'], os.environ['GITHUB_TOKEN'])
    self_run = os.environ.get('GITHUB_RUN_ID', '')
    run_url = (f"{os.environ.get('GITHUB_SERVER_URL', 'https://github.com')}/{gh.repo}/actions/runs/{self_run}"
               if self_run else '')
    try:
        digest_once(gh, args, run_url)
    except (urllib.error.URLError, OSError, KeyError, ValueError) as error:
        # Rate limits, outages and API changes must not turn a PR red. Agents
        # fall back to reading CI directly when no digest appears.
        print(f'AGENT-CI-DIGEST verdict=unavailable sha={args.sha} reason={error}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
