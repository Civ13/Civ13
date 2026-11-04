"""Summarize every GitHub Actions check on a PR head into one comment.

Run by .github/workflows/agent-ci-digest.yml after the main CI workflow
completes. It waits on the runner (not in an agent session) until every
Actions check run for the head SHA has finished, classifies each failure as
infrastructure, known pre-existing or needs-fix, reruns infrastructure-only
failures once, and posts a single comment per head with a Markdown table,
log excerpts and a machine-readable JSON block. See docs/agent-ci-digest.md.

Standard library only. Uses the workflow's GITHUB_TOKEN; never checks out or
runs pull request code.

    python3 scripts/ci_digest.py --sha <head> [--pr N] [--wait-minutes 150]
    python3 scripts/ci_digest.py --sha <head> --dry-run   # print, post nothing
"""
import argparse
import hashlib
import json
import os
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


def verdict(failures, pending):
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
    'pending': 'Some checks did not finish before the digest stopped waiting.',
}


def render(sha, summary, failures, pending, reruns, run_url):
    state = verdict(failures, pending)
    counts = summary
    head = (f"### CI digest for `{sha[:10]}`: **{state}**\n\n"
            f"{counts['success']} passed, {len(failures)} failed, {counts['skipped']} skipped"
            f"{', %d still running' % len(pending) if pending else ''}. {ADVICE[state]}\n")
    parts = [head]
    if reruns:
        parts.append('Infrastructure failures were rerun once automatically: '
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
    return (f'{MARKER} sha={sha} sig={signature} -->\n{body}\n'
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


def post(gh, pr, sha, body, signature):
    comments, page = [], 1
    while True:
        batch = gh.get(f'issues/{pr}/comments?per_page=100&page={page}')
        comments += batch
        if len(batch) < 100:
            break
        page += 1
    mine = [c for c in comments if (c.get('body') or '').startswith(f'{MARKER} sha={sha} ')]
    if mine:
        if f'sig={signature} ' in mine[-1]['body']:
            return 'unchanged'
        gh.request('PATCH', f"issues/comments/{mine[-1]['id']}", {'body': body})
        return 'updated'
    gh.request('POST', f'issues/{pr}/comments', {'body': body})
    return 'posted'


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--sha', required=True)
    parser.add_argument('--pr', type=int)
    parser.add_argument('--wait-minutes', type=float, default=150)
    parser.add_argument('--poll-seconds', type=float, default=45)
    parser.add_argument('--settle-seconds', type=float, default=60,
                        help='Wait this long after everything finishes in case a follow-up workflow queues')
    parser.add_argument('--no-rerun', action='store_true', help='Do not rerun infrastructure-only failures')
    parser.add_argument('--dry-run', action='store_true', help='Print the digest; post and rerun nothing')
    args = parser.parse_args(argv)
    if not re.fullmatch(r'[0-9a-f]{40}', args.sha):
        parser.error('--sha must be a full 40-character commit SHA')
    gh = GitHub(os.environ['GITHUB_REPOSITORY'], os.environ['GITHUB_TOKEN'])
    self_run = os.environ.get('GITHUB_RUN_ID', '')
    run_url = (f"{os.environ.get('GITHUB_SERVER_URL', 'https://github.com')}/{gh.repo}/actions/runs/{self_run}"
               if self_run else '')
    deadline = time.monotonic() + args.wait_minutes * 60
    reruns, settled = [], False
    while True:
        if args.pr and not args.dry_run and pr_head(gh, args.pr) != args.sha:
            print(f'PR #{args.pr} moved past {args.sha}; a newer digest will report.')
            return 0
        checks = actions_checks(gh, args.sha, self_run)
        busy = [c['name'] for c in checks if c['status'] != 'completed']
        if busy and time.monotonic() < deadline:
            settled = False
            print(f'{len(busy)} checks running: {", ".join(busy[:6])}', flush=True)
            time.sleep(args.poll_seconds)
            continue
        if not busy and not settled and time.monotonic() < deadline:
            settled = True
            time.sleep(args.settle_seconds)
            continue
        summary, failures, pending = collect(gh, args.sha, checks)
        state = verdict(failures, pending)
        first = [f for f in failures if f['attempt'] == 1]
        if (state == 'infra-only' and first and len(first) == len(failures) and not reruns
                and not args.no_rerun and not args.dry_run and time.monotonic() < deadline):
            for run_id in sorted({f['run_id'] for f in failures}):
                gh.request('POST', f'actions/runs/{run_id}/rerun-failed-jobs', {})
                reruns.append(run_id)
            print('Reran infrastructure failures in runs', reruns, flush=True)
            settled = False
            time.sleep(args.poll_seconds)
            continue
        break
    body, state, signature = render(args.sha, summary, failures, pending, reruns, run_url)
    summary_path = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary_path:
        with open(summary_path, 'a', encoding='utf-8') as handle:
            handle.write(body)
    print(body)
    print(f'AGENT-CI-DIGEST verdict={state} sha={args.sha} sig={signature}')
    if args.pr and not args.dry_run:
        print('Comment', post(gh, args.pr, args.sha, body, signature))
    return 0


if __name__ == '__main__':
    sys.exit(main())
