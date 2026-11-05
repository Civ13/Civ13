"""Run the ordinary CI set locally and attest the pass so hosted CI can skip it.

Modes:
  run       select like CI, run the offline baseline, compile (and dreamchecker
            when a binary is available), write a receipt, then optionally push
            and attest. Works on Windows (py -3, Git Bash) and Linux.
  attest    publish an existing receipt: a commit comment holding the receipt
            and a `local-ci/attested` commit status pointing at it.
  verify    hosted gate. Reads the status, comment, selection and allowlist and
            decides whether heavy jobs may be skipped. Always exits 0: any doubt
            means hosted CI runs (fail-open to hosted, never a red check).
  aggregate hosted required-aggregate path for an attested or waived head.

Trust: statuses are accepted only from GitHub user ids in
tools/ci/local_attesters.json as read from the base commit, never the PR head.
See docs/local-ci-attestation.md.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import platform
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
REPO = 'Civ13/Civ13'
API = 'https://api.github.com'
CONTEXT = 'local-ci/attested'
MARKER = '<!-- local-ci-receipt v1 -->'
ATTESTERS = 'tools/ci/local_attesters.json'
DESCRIPTION = re.compile(r'local-ci v1 sha256=([0-9a-f]{64})')
RECEIPT_BLOCK = re.compile(r'```json\n(.*?)\n```', re.S)
# Changes here can alter what the gate or the selector does, so they always run hosted.
CONTROL_PATHS = ('.github/', 'scripts/select-ci.py', 'scripts/ci_baseline.py',
                 'scripts/ci_checkout_refs.py', 'scripts/local_ci.py',
                 'scripts/byond_toolchain.py', 'tools/byond/', 'tools/ci/')
GAME_SUFFIXES = {'.dm', '.dme', '.dmm', '.dmi', '.rsc'}
WAIVER_PREFIX = 'skip-ci:'
SHA = re.compile(r'[0-9a-f]{40}')


def canonical(value):
    return json.dumps(value, sort_keys=True, indent=2)


def sha256_text(text):
    return hashlib.sha256(text.encode('utf-8')).hexdigest()


def selection_core(plan):
    """The part of a selection that decides which hosted jobs and suites run."""
    suites = plan['baseline']['suites']
    return dict(compile=bool(plan['compile']['selected']), extensive=bool(plan['extensive']),
                new_tests=sorted(plan['new_tests']),
                suites=sorted(name for name, row in suites.items() if row['selected']))


def core_digest(plan):
    return sha256_text(canonical(selection_core(plan)))


def control_paths(paths):
    return sorted(p for p in paths if any(p == c or (c.endswith('/') and p.startswith(c)) for c in CONTROL_PATHS))


def game_paths(paths):
    return sorted(p for p in paths if PurePosixPath(p).suffix.lower() in GAME_SUFFIXES)


def load_attesters(path):
    data = json.loads(Path(path).read_text(encoding='utf-8'))
    if data.get('schema') != 1 or not isinstance(data.get('attesters'), list):
        raise ValueError('Invalid attester list')
    ids = set()
    for row in data['attesters']:
        if type(row.get('id')) is not int or row['id'] <= 0 or not isinstance(row.get('login'), str):
            raise ValueError('Invalid attester entry')
        ids.add(row['id'])
    return ids


def hosted_scope(plan):
    """Reasons the selection itself rules out a skip; empty means skippable."""
    reasons = []
    if plan.get('event') != 'pull_request':
        reasons.append('Only pull_request runs can be skipped')
    if not plan.get('eligibility', {}).get('gating', {}).get('eligible'):
        reasons.append('Selection is not a full ordinary PR scope')
    if plan.get('comparison', {}).get('status') != 'available':
        reasons.append('No exact base/head comparison')
    if plan.get('extensive') or plan.get('new_tests'):
        reasons.append('Native or introduced suites selected; they only run hosted')
    touched = control_paths(plan.get('comparison', {}).get('paths', []))
    if touched:
        reasons.append('CI-control paths changed: ' + ', '.join(touched[:5]))
    return reasons


def check_attestation(*, head, tree, plan, statuses, get_comment, attesters, version):
    """Return (receipt, []) for a valid attestation, else (None, reasons)."""
    mine = [s for s in statuses if s.get('context') == CONTEXT]
    if not mine:
        return None, ['No local-ci/attested status']
    status = mine[0]  # The API lists newest first; only the latest counts.
    creator = (status.get('creator') or {}).get('id')
    if status.get('state') != 'success':
        return None, ['Latest local-ci/attested status is not success']
    if creator not in attesters:
        return None, ['Status creator is not a trusted attester']
    match = DESCRIPTION.fullmatch(status.get('description') or '')
    if not match:
        return None, ['Status description has no receipt digest']
    url = status.get('target_url') or ''
    link = re.fullmatch(re.escape(f'https://github.com/{REPO}/commit/{head}') + r'#commitcomment-(\d+)', url)
    if not link:
        return None, ['Status does not link a commit comment on this head']
    comment = get_comment(int(link.group(1)))
    if not comment or (comment.get('user') or {}).get('id') != creator:
        return None, ['Receipt comment missing or written by someone else']
    if comment.get('commit_id') != head:
        return None, ['Receipt comment is on another commit']
    body = comment.get('body') or ''
    block = RECEIPT_BLOCK.search(body)
    if not body.startswith(MARKER) or not block:
        return None, ['Receipt comment has no receipt block']
    text = block.group(1).replace('\r\n', '\n')
    if sha256_text(text) != match.group(1):
        return None, ['Receipt differs from the digest in the status']
    receipt = json.loads(text)
    reasons = []
    expect = dict(schema=1, kind='local-ci', status='passed', head=head, tree=tree)
    for key, value in expect.items():
        if receipt.get(key) != value:
            reasons.append('Receipt ' + key + ' mismatch')
    if receipt.get('byond') != version:
        reasons.append('Receipt BYOND version differs from the pin')
    if receipt.get('selection_core_sha256') != core_digest(plan):
        reasons.append('Local selection differs from hosted selection')
    if receipt.get('selection_core_sha256') != sha256_text(canonical(receipt.get('selection_core'))):
        reasons.append('Receipt selection core is inconsistent')
    if (receipt.get('baseline') or {}).get('status') != 'passed':
        reasons.append('Local baseline did not pass')
    compile_row = receipt.get('compile') or {}
    wanted = 'passed' if plan['compile']['selected'] else 'skipped'
    if compile_row.get('status') != wanted:
        reasons.append('Local compile status is not ' + wanted)
    return (None, reasons) if reasons else (receipt, [])


def check_waiver(*, head, plan, labels, label_events, attesters):
    name = WAIVER_PREFIX + head
    if name not in labels:
        return ['No skip-ci label for this head']
    events = [e for e in label_events if e.get('event') in ('labeled', 'unlabeled')
              and (e.get('label') or {}).get('name') == name]
    if not events or events[-1].get('event') != 'labeled':
        return ['skip-ci label event not found']
    if (events[-1].get('actor') or {}).get('id') not in attesters:
        return ['skip-ci label was added by someone not on the attester list']
    touched = game_paths(plan.get('comparison', {}).get('paths', []))
    if touched:
        return ['Game files changed; a waiver cannot skip compilation: ' + ', '.join(touched[:5])]
    return []


def decide(*, head, tree, plan, statuses, get_comment, attesters, version, labels, label_events):
    verdict = dict(head=head, skip=False, skip_dreamchecker=False, mode='hosted', reasons=[])
    scope = hosted_scope(plan)
    if scope:
        verdict['reasons'] = scope
        return verdict
    receipt, reasons = check_attestation(head=head, tree=tree, plan=plan, statuses=statuses,
                                         get_comment=get_comment, attesters=attesters, version=version)
    if receipt:
        dreamchecker = (receipt.get('dreamchecker') or {}).get('status')
        verdict.update(skip=True, mode='attested', attester=receipt.get('attester'),
                       skip_dreamchecker=dreamchecker in ('passed', 'ratchet_failed'))
        return verdict
    waiver = check_waiver(head=head, plan=plan, labels=labels, label_events=label_events, attesters=attesters)
    if not waiver:
        verdict.update(skip=True, skip_dreamchecker=True, mode='waived')
        return verdict
    verdict['reasons'] = reasons + waiver
    return verdict


# ---- GitHub API ---------------------------------------------------------

def token():
    for name in ('GITHUB_TOKEN', 'GH_TOKEN'):
        if os.environ.get(name):
            return os.environ[name]
    gh = shutil.which('gh')
    if gh:
        result = subprocess.run([gh, 'auth', 'token'], capture_output=True, text=True, timeout=30)
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    raise RuntimeError('No GitHub token: set GITHUB_TOKEN or run `gh auth login`')


def api(method, path, body=None, auth=None):
    request = urllib.request.Request(API + path, method=method,
                                     data=json.dumps(body).encode() if body is not None else None)
    request.add_header('Accept', 'application/vnd.github+json')
    request.add_header('X-GitHub-Api-Version', '2022-11-28')
    request.add_header('User-Agent', 'civ13-local-ci')
    if auth:
        request.add_header('Authorization', 'Bearer ' + auth)
    if body is not None:
        request.add_header('Content-Type', 'application/json')
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.loads(response.read().decode('utf-8') or 'null')


def paged(path, auth, limit=10):
    rows = []
    for page in range(1, limit + 1):
        batch = api('GET', f'{path}{"&" if "?" in path else "?"}per_page=100&page={page}', auth=auth)
        rows.extend(batch)
        if len(batch) < 100:
            break
    return rows


# ---- local run ------------------------------------------------------------

def git(*args, cwd=ROOT):
    return subprocess.check_output(['git', *args], cwd=cwd, stderr=subprocess.PIPE, timeout=120).decode().strip()


def say(message):
    print('[local-ci] ' + message, flush=True)


def find_compiler(explicit=None):
    candidates = [explicit] if explicit else []
    if os.name == 'nt':
        candidates += [shutil.which('dm'), r'C:\Program Files (x86)\BYOND\bin\dm.exe',
                       r'C:\Program Files\BYOND\bin\dm.exe']
    else:
        candidates += [shutil.which('DreamMaker')]
        candidates += sorted(str(p) for p in Path('/opt').glob('civ13-byond-*/byond/bin/DreamMaker'))
        candidates += sorted(str(p) for p in Path.home().glob('byond-*/byond/bin/DreamMaker'))
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return candidate
    raise RuntimeError('BYOND compiler not found; pass --compiler (Linux: bash scripts/cloud_byond_setup.sh)')


def find_dreamchecker(explicit=None):
    names = ['dreamchecker.exe', 'dreamchecker'] if os.name == 'nt' else ['dreamchecker']
    candidates = [explicit] if explicit else []
    candidates += [str(ROOT / '.ci/lint' / n) for n in names] + [shutil.which(n) for n in names]
    return next((c for c in candidates if c and Path(c).is_file()), None)


def open_pr(branch):
    try:
        rows = api('GET', f'/repos/{REPO}/pulls?state=open&head={REPO.split("/")[0]}:{branch}')
    except (urllib.error.URLError, OSError):
        return None
    return rows[0] if rows else None


def require_clean():
    dirty = git('status', '--porcelain', '--untracked-files=normal')
    if dirty:
        raise RuntimeError('Working tree is not clean; commit or stash first:\n' + dirty)


def run_logged(command, log, env=None):
    started = time.monotonic()
    with open(log, 'wb') as handle:
        result = subprocess.run(command, cwd=ROOT, stdout=handle, stderr=subprocess.STDOUT, env=env)
    return result.returncode, round(time.monotonic() - started, 1)


def local_run(args):
    out = Path(args.output).resolve()
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    require_clean()
    head, tree = git('rev-parse', 'HEAD'), git('rev-parse', 'HEAD^{tree}')
    branch = args.branch or git('rev-parse', '--abbrev-ref', 'HEAD')
    if branch == 'HEAD':
        raise RuntimeError('Detached HEAD; pass --branch')
    if branch == 'master':
        raise RuntimeError('Run this on a PR branch, not master')
    pr = open_pr(branch)
    base_ref = (pr or {}).get('base', {}).get('ref') or 'master'
    say(f'fetching origin/{base_ref}')
    git('fetch', '--quiet', args.remote, base_ref)
    base = args.base or git('rev-parse', 'FETCH_HEAD')
    title = (pr or {}).get('title') or git('log', '-1', '--format=%s')
    say(f'head {head[:12]} base {base[:12]} ({"PR #" + str(pr["number"]) if pr else "no open PR yet"})')

    event = dict(action='synchronize', number=(pr or {}).get('number', 0),
                 pull_request=dict(title=title, labels=[], base=dict(ref=base_ref, sha=base), head=dict(sha=head, ref=branch)))
    event_path = out / 'event.json'
    event_path.write_text(json.dumps(event), encoding='utf-8')
    env = {k: v for k, v in os.environ.items() if not k.startswith('GITHUB_')}
    env.update(GITHUB_EVENT_PATH=str(event_path), GITHUB_EVENT_NAME='pull_request', PYTHONDONTWRITEBYTECODE='1')
    python = sys.executable

    selection = out / 'selection.json'
    code, _ = run_logged([python, '-B', 'scripts/select-ci.py', '--base', base, '--head', head,
                          '--output', str(out / 'selection.out'), '--event', 'pull_request',
                          '--extensive', 'false', '--build-prefix', 'true', '--receipt', str(selection)],
                         out / 'selection.log', env)
    if code != 0:
        raise RuntimeError('Selection failed; see ' + str(out / 'selection.log'))
    plan = json.loads(selection.read_text(encoding='utf-8'))
    scope = hosted_scope(plan)
    core = selection_core(plan)
    say(f'selection: compile={core["compile"]} suites={len(core["suites"])} new_tests={core["new_tests"]}')
    if scope and not args.force_run:
        for reason in scope:
            say('hosted CI is required: ' + reason)
        say('nothing to attest; push normally and let GitHub run CI')
        return 3

    say(f'running {len(core["suites"])} offline suites')
    code, seconds = run_logged([python, '-B', 'scripts/ci_baseline.py', 'run', '--selection', str(selection),
                                '--head', head, '--base', base, '--output', str(out / 'baseline')],
                               out / 'baseline.log', env)
    baseline_receipt = json.loads((out / 'baseline/baseline.json').read_text(encoding='utf-8'))
    failed = sorted(n for n, r in baseline_receipt['suites'].items() if r['status'] == 'failed')
    baseline = dict(status='passed' if code == 0 and baseline_receipt['status'] == 'passed' else 'failed',
                    seconds=seconds, suites_run=sum(1 for r in baseline_receipt['suites'].values() if r['selected']),
                    failed=failed)
    say(f'baseline {baseline["status"]} in {seconds}s' + (f' (failed: {", ".join(failed)})' if failed else ''))

    code, _ = run_logged([python, '-B', 'scripts/check_forbidden_patterns.py'], out / 'forbidden_patterns.log', env)
    forbidden = dict(status='passed' if code == 0 else 'ratchet_failed', advisory=True)

    sys.path.insert(0, str(ROOT / 'scripts'))
    import byond_toolchain
    version = byond_toolchain.load()['version']
    compile_row = dict(status='skipped', reason='Selection did not admit compilation')
    if core['compile']:
        compiler = find_compiler(args.compiler)
        command = [compiler, 'civ13.dme'] if os.name == 'nt' else [compiler, '-max_errors', '0', 'civ13.dme']
        say(f'compiling with {compiler}')
        code, seconds = run_logged(command, out / 'compiler.log')
        text = (out / 'compiler.log').read_text(encoding='utf-8', errors='replace')
        try:
            byond_toolchain.compiler_log(text, version)
            status = 'passed' if code == 0 else 'failed'
        except ValueError as error:
            status, compile_row['error'] = 'failed', str(error)
        compile_row.update(status=status, exit_code=code, seconds=seconds, compiler=Path(compiler).name,
                           result=next(iter(re.findall(r'- \d+ errors?, \d+ warnings?', text)[-1:]), None))
        say(f'compile {status} in {seconds}s ({compile_row["result"]})')

    dreamchecker = dict(status='not_run', advisory=True)
    binary = None if args.no_dreamchecker else find_dreamchecker(args.dreamchecker)
    if binary:
        say(f'running dreamchecker {binary}')
        code, _ = run_logged([python, '-B', 'scripts/dreamchecker_lint.py', 'run', '--binary', binary,
                              '--output', str(out / 'lint')], out / 'dreamchecker-run.log', env)
        if code == 0:
            code, _ = run_logged([python, '-B', 'scripts/dreamchecker_lint.py', 'check', '--receipt',
                                  str(out / 'lint/dreamchecker.json'), '--head', head], out / 'dreamchecker.log', env)
            dreamchecker['status'] = 'passed' if code == 0 else 'ratchet_failed'
        else:
            dreamchecker['status'] = 'error'
        say('dreamchecker ' + dreamchecker['status'] + ' (advisory)')

    if git('rev-parse', 'HEAD') != head or git('status', '--porcelain', '--untracked-files=normal'):
        raise RuntimeError('The checkout changed while checks ran; nothing attested')
    passed = baseline['status'] == 'passed' and compile_row['status'] in ('passed', 'skipped') and not scope
    receipt = dict(schema=1, kind='local-ci', status='passed' if passed else 'failed', head=head, tree=tree,
                   base=base, branch=branch, byond=version, selection_core=core,
                   selection_core_sha256=sha256_text(canonical(core)), baseline=baseline,
                   compile=compile_row, forbidden_patterns=forbidden, dreamchecker=dreamchecker,
                   platform=f'{platform.system()} {platform.release()}', python=platform.python_version(),
                   finished=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()))
    (out / 'receipt.json').write_text(canonical(receipt) + '\n', encoding='utf-8')
    if not passed:
        say('FAILED; nothing attested. Logs: ' + str(out))
        return 1
    say('all checks passed; receipt ' + str(out / 'receipt.json'))
    if args.no_attest:
        return 0
    if args.push:
        say(f'pushing {head[:12]} to {args.remote}/{branch}')
        subprocess.run(['git', 'push', args.remote, f'{head}:refs/heads/{branch}'], cwd=ROOT, check=True)
    else:
        remote = git('ls-remote', args.remote, 'refs/heads/' + branch).split('\t')[0]
        if remote != head:
            raise RuntimeError(f'{args.remote}/{branch} is not at {head[:12]}; use --push')
    return publish(receipt, args.remote_wait)


def publish(receipt, wait_seconds=0):
    auth = token()
    me = api('GET', '/user', auth=auth)
    receipt = dict(receipt, attester=me['login'])
    text = canonical(receipt)
    body = f'{MARKER}\nLocal CI pass for `{receipt["head"]}` by @{me["login"]} on {receipt["platform"]}.\n\n```json\n{text}\n```\n'
    head = receipt['head']
    for attempt in range(max(1, wait_seconds // 2)):
        try:
            comment = api('POST', f'/repos/{REPO}/commits/{head}/comments', dict(body=body), auth=auth)
            break
        except urllib.error.HTTPError as error:
            if error.code != 422 or attempt + 1 >= max(1, wait_seconds // 2):
                raise
            time.sleep(2)  # GitHub may not know a just-pushed commit yet.
    api('POST', f'/repos/{REPO}/statuses/{head}', dict(
        state='success', context=CONTEXT, target_url=comment['html_url'],
        description=f'local-ci v1 sha256={sha256_text(text)}'), auth=auth)
    say(f'attested {head[:12]}: {comment["html_url"]}')
    say('if CI for this commit had already started its heavy jobs, re-run it from the Actions tab')
    return 0


def attest(args):
    receipt = json.loads(Path(args.receipt).read_text(encoding='utf-8'))
    if receipt.get('status') != 'passed' or receipt.get('kind') != 'local-ci':
        raise RuntimeError('Receipt did not pass')
    receipt.pop('attester', None)
    return publish(receipt, args.remote_wait)


# ---- hosted gate ------------------------------------------------------------

def write_outputs(path, verdict):
    lines = [f'skip={str(verdict["skip"]).lower()}', f'skip_dreamchecker={str(verdict["skip_dreamchecker"]).lower()}',
             f'mode={verdict["mode"]}']
    if path:
        with open(path, 'a', encoding='utf-8') as handle:
            handle.write('\n'.join(lines) + '\n')
    print('\n'.join(lines))


def verify(args):
    verdict = dict(head=args.head, skip=False, skip_dreamchecker=False, mode='hosted', reasons=[])
    try:
        if not SHA.fullmatch(args.head or ''):
            raise ValueError('Invalid head')
        checkout = Path(args.checkout)
        tree = git('rev-parse', args.head + '^{tree}', cwd=checkout)
        plan = json.loads(Path(args.selection).read_text(encoding='utf-8'))
        if plan.get('head') != args.head:
            raise ValueError('Selection head differs')
        attesters = load_attesters(args.attesters)
        version = json.loads((checkout / 'tools/byond/version.json').read_text(encoding='utf-8'))['version']
        payload = json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text(encoding='utf-8'))
        pr = payload.get('pull_request') or {}
        labels = [label.get('name') for label in pr.get('labels', [])]
        auth = os.environ.get('GITHUB_TOKEN')
        statuses = api('GET', f'/repos/{REPO}/commits/{args.head}/statuses?per_page=100', auth=auth)

        def get_comment(number):
            try:
                return api('GET', f'/repos/{REPO}/comments/{number}', auth=auth)
            except urllib.error.HTTPError:
                return None
        label_events = []
        if any(name == WAIVER_PREFIX + args.head for name in labels) and payload.get('number'):
            label_events = paged(f'/repos/{REPO}/issues/{payload["number"]}/events', auth)
        verdict = decide(head=args.head, tree=tree, plan=plan, statuses=statuses, get_comment=get_comment,
                         attesters=attesters, version=version, labels=labels, label_events=label_events)
    except Exception as error:  # Any doubt runs hosted CI.
        verdict['reasons'] = ['Gate error: ' + str(error)[:300]]
    Path(args.verdict).parent.mkdir(parents=True, exist_ok=True)
    Path(args.verdict).write_text(canonical(verdict) + '\n', encoding='utf-8')
    write_outputs(args.output, verdict)
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a', encoding='utf-8') as handle:
            handle.write(f'Local CI gate: **{verdict["mode"]}**' + (
                '; heavy jobs skipped.\n' if verdict['skip'] else '; hosted jobs run.\n'))
            for reason in verdict['reasons']:
                handle.write(f'- {reason}\n')
    return 0


def aggregate(args):
    jobs = json.loads(os.environ['CI_NEEDS'])
    gate = jobs.get('local-attestation', {})
    errors = []
    if jobs.get('changes', {}).get('result') != 'success':
        errors.append('Selection did not succeed')
    if gate.get('result') != 'success' or gate.get('outputs', {}).get('skip') != 'true':
        errors.append('Gate did not record a skip')
    mode = gate.get('outputs', {}).get('mode')
    if mode not in ('attested', 'waived'):
        errors.append('Unknown skip mode')
    for name in ('baseline', 'evidence-checker', 'build', 'extraction-instances'):
        if jobs.get(name, {}).get('result') not in ('skipped', 'success'):
            errors.append(f'{name} did not finish cleanly: {jobs.get(name, {}).get("result")}')
    receipt = dict(schema_version=1, kind='aggregate', status='failed' if errors else 'passed',
                   head=args.head, coverage=mode, jobs=jobs, errors=errors)
    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    Path(args.output).write_text(canonical(receipt) + '\n', encoding='utf-8')
    print(canonical(receipt))
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a', encoding='utf-8') as handle:
            handle.write('Heavy jobs were skipped: ' + (
                'a trusted local pass is attested for this exact head.\n' if mode == 'attested'
                else 'a maintainer waived CI for this exact head (not verified).\n'))
    return 1 if errors else 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='mode', required=True)
    run = sub.add_parser('run', help='run CI locally and attest the pass')
    run.add_argument('--push', action='store_true', help='push HEAD to the branch after checks pass, then attest')
    run.add_argument('--no-attest', action='store_true', help='run checks and write the receipt only')
    run.add_argument('--base', help='comparison base SHA (default: tip of the PR base branch)')
    run.add_argument('--branch', help='branch name (default: current branch)')
    run.add_argument('--remote', default='origin')
    run.add_argument('--compiler', help='path to dm.exe or DreamMaker')
    run.add_argument('--dreamchecker', help='path to a verified dreamchecker binary')
    run.add_argument('--no-dreamchecker', action='store_true')
    run.add_argument('--force-run', action='store_true', help='run checks even when hosted CI is required (never attests)')
    run.add_argument('--output', default=str(ROOT / '.ci/local'))
    run.add_argument('--remote-wait', type=int, default=20, help='seconds to retry while GitHub learns a new push')
    publish_parser = sub.add_parser('attest', help='publish an existing passed receipt')
    publish_parser.add_argument('--receipt', default=str(ROOT / '.ci/local/receipt.json'))
    publish_parser.add_argument('--remote-wait', type=int, default=20)
    gate = sub.add_parser('verify', help='hosted gate (always exits 0)')
    gate.add_argument('--head', required=True)
    gate.add_argument('--checkout', default='.')
    gate.add_argument('--selection', required=True)
    gate.add_argument('--attesters', required=True, help='allowlist read from the base commit')
    gate.add_argument('--verdict', required=True)
    gate.add_argument('--output', default=os.environ.get('GITHUB_OUTPUT'))
    agg = sub.add_parser('aggregate', help='hosted required aggregate for a skipped head')
    agg.add_argument('--head', required=True)
    agg.add_argument('--output', required=True)
    args = parser.parse_args(argv)
    try:
        return {'run': local_run, 'attest': attest, 'verify': verify, 'aggregate': aggregate}[args.mode](args)
    except (RuntimeError, subprocess.CalledProcessError, urllib.error.URLError) as error:
        say('error: ' + str(error))
        return 2


if __name__ == '__main__':
    sys.exit(main())
