"""Manual hosted route using existing GNU timeout and Civ13 CI bootstrap."""
import argparse
from datetime import datetime, timedelta, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
spec = importlib.util.spec_from_file_location('budget_host_pilot', HERE / 'budget_pilot.py')
pilot = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = pilot
spec.loader.exec_module(pilot)
HOST_SECONDS = 1200
JOB_MINUTES = 30
MIN_AUTH_SECONDS = 2100
RETENTION_RESERVE = 30
PILOT_SECONDS = 915
KILL_AFTER = 5
FILES = (
    '.github/workflows/moving-save-chunks.yml',
    'tests/movement_save_chunks/budget_host.py', 'tests/movement_save_chunks/budget_pilot.py',
    'tests/movement_save_chunks/benchmark.py', 'tests/movement_save_chunks/benchmark.dm',
    'tests/movement_save_chunks/test_budget_host.py', 'tests/movement_save_chunks/test_budget_pilot.py',
    'tests/movement_save_chunks/fixtures/capture-budget-e042.txt',
    'tests/movement_save_chunks/diagnostic_cases.py', 'tests/movement_save_chunks/datum_profile.py',
    'tests/movement_save_chunks/preflight_fixture.py', 'tests/world_save/stubs.dm',
    'tests/movement_save_chunks/debug_lossy_adapter.dm', 'code/predefines.dm',
    'code/modules/multiz/world_z_budget.dm', 'code/modules/persistence/functions.dm',
    'code/modules/persistence/player_reclaim.dm', 'code/modules/persistence/saving.dm',
    'code/modules/persistence/loading.dm', 'scripts/travis_pre_byond.sh',
    'scripts/byond_toolchain.py', 'scripts/byond_runtime.py', 'tools/byond/version.json',
)
def now():
    return datetime.now(timezone.utc)

def stamp(value):
    return value.strftime('%Y-%m-%dT%H:%M:%SZ')

def digest(data):
    return hashlib.sha256(data).hexdigest()

def require(value, message):
    if not value:
        raise ValueError(message)

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, timeout=15)

def manifest(head):
    require(re.fullmatch('[0-9a-f]{40}', head or ''), 'Exact head required')
    require(git('rev-parse', 'HEAD').decode().strip() == head, 'Checkout head mismatch')
    files = {}
    for name in FILES:
        committed = git('show', head + ':' + name)
        actual = (ROOT / name).read_bytes()
        require(actual.replace(b'\r\n', b'\n') == committed.replace(b'\r\n', b'\n'), 'Source differs: ' + name)
        files[name] = digest(committed)
    return dict(schema=1, head=head, tree=git('rev-parse','HEAD^{tree}').decode().strip(),
                files=files, order=list(pilot.ORDER), limits=dict(pilot.LIMITS),
                host_seconds=HOST_SECONDS, job_minutes=JOB_MINUTES,
                pilot_controller_seconds=PILOT_SECONDS, kill_after_seconds=KILL_AFTER,
                bootstrap_compiler_max=1, pilot_compiler_max=2, daemon_max=8,
                acceptance_status='not_established')

def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':')).encode()

def context(head):
    expected = {'GITHUB_REPOSITORY':'Civ13/Civ13', 'GITHUB_EVENT_NAME':'workflow_dispatch',
                'GITHUB_SHA':head, 'GITHUB_WORKFLOW_SHA':head, 'GITHUB_RUN_ATTEMPT':'1'}
    require(all(os.environ.get(k) == v for k,v in expected.items()), 'Manual exact-head attempt-one context required')
    require(sys.platform.startswith('linux'), 'Hosted Linux required')
    selectors = json.loads(os.environ.get('PILOT_OTHER_SELECTORS', '{}'))
    require(selectors.get('capture_budget_pilot') is True and selectors.get('budget_pilot_mode') == 'execute',
            'Explicit execution selector required')
    require(all(selectors.get(k) is False for k in ('debug_combined_only','debug_lossy_only',
                'human_spatial_only','human_scale_only','lighting_interleave_only')),
            'Pilot cannot combine other native selectors')

def bind_output(output):
    expected = Path(os.environ['RUNNER_TEMP']).resolve() / 'budget-pilot-evidence'
    require(output.resolve() == expected, 'Only the fixed runner-temp evidence directory is allowed')
    require(not output.is_symlink(), 'Linked evidence root refused')

def check_scope(head, reviewed):
    row = manifest(head)
    require(re.fullmatch('[0-9a-f]{64}', reviewed or ''), 'Reviewed scope hash required')
    require(digest(canonical(row)) == reviewed, 'Reviewed source scope mismatch')
    for name,want in row['files'].items():
        require(digest((ROOT/name).read_bytes()) == want, 'Linux source bytes changed: ' + name)
    require(not git('diff','--binary','HEAD').strip(), 'Tracked source changed')
    return row

def admit(output, head, reviewed, authorized_until):
    context(head); bind_output(output)
    row = check_scope(head, reviewed)
    require(not (output/'admission.json').exists() and not (output/'admission.sha256').exists(), 'Admission is one-shot')
    until = pilot.authorization_deadline(authorized_until)
    admitted = now()
    require((until-admitted).total_seconds() >= MIN_AUTH_SECONDS, 'At least 35 minutes of fresh authorization required')
    value = dict(head=head, scope=reviewed, admitted_at=stamp(admitted),
                 authorized_until=stamp(until), overall_until=stamp(min(until-timedelta(seconds=60),
                                                                      admitted+timedelta(seconds=HOST_SECONDS))),
                 run_id=os.environ.get('GITHUB_RUN_ID'), acceptance_status='not_established')
    pilot._atomic_json(output/'admission.json', value)
    (output/'admission.sha256').write_text(digest(canonical(value)), encoding='ascii')
    return value

def run_phase(output, head, reviewed, phase):
    require(phase in ('bootstrap','pilot'), 'Unknown host phase')
    context(head); bind_output(output); check_scope(head, reviewed)
    admission = json.loads((output/'admission.json').read_text())
    require(digest(canonical(admission)) == (output/'admission.sha256').read_text(), 'Admission changed')
    require(admission['authorized_until'] == stamp(pilot.authorization_deadline(os.environ.get('AUTHORIZED_UNTIL',''))), 'Approved deadline input changed')
    require(admission['head']==head and admission['scope']==reviewed and
            admission['run_id']==os.environ.get('GITHUB_RUN_ID'), 'Admission identity mismatch')
    overall = pilot.authorization_deadline(admission['overall_until'])
    until = pilot.authorization_deadline(admission['authorized_until'])
    require(overall <= until-timedelta(seconds=60), 'Admission exceeds authorization')
    require(overall <= pilot.authorization_deadline(admission['admitted_at'])+timedelta(seconds=HOST_SECONDS), 'Overall deadline expanded')
    remaining = (overall-now()).total_seconds()
    require(not (output/('outer-'+phase+'.json')).exists() and not (output/('outer-'+phase+'.log')).exists(), 'Host phase is one-shot')
    row = dict(phase=phase, head=head, scope=reviewed, overall_until=stamp(overall),
               status='inconclusive', controller_invocation_attempted=False,
               cleanup='not_established', acceptance_status='not_established')
    error = None
    try:
        if phase == 'bootstrap':
            require(remaining > RETENTION_RESERVE, 'No overall time remains')
            seconds = min(900, int(remaining)-RETENTION_RESERVE)
            command = ['bash', 'scripts/travis_pre_byond.sh']
        else:
            prior = json.loads((output/'outer-bootstrap.json').read_text())
            require(prior.get('status') == 'bootstrap_completed' and prior.get('returncode') == 0
                    and prior.get('head') == head and prior.get('scope') == reviewed
                    and prior.get('overall_until') == stamp(overall), 'Successful exact-scope bootstrap required')
            require(remaining >= PILOT_SECONDS+RETENTION_RESERVE, 'Insufficient time for the fixed pilot budget')
            seconds = PILOT_SECONDS
            command = [sys.executable, '-B', 'tests/movement_save_chunks/budget_pilot.py',
                       '--output', str(output/'cases'), '--run-native',
                       '--byond-bin', str(ROOT/'BYOND/byond/bin'),
                       '--byond-archive', str(ROOT/'BYOND/pinned.zip'),
                       '--authorized-until', stamp(overall-timedelta(seconds=10))]
        argv = ['timeout', '-k', str(KILL_AFTER), str(seconds), *command]
        row.update(command=argv, timeout_seconds=seconds, kill_after_seconds=KILL_AFTER,
                   controller_invocation_attempted=True)
        env = os.environ.copy()
        env.update(BYOND_MAJOR='516', BYOND_MINOR='1688', BYOND_ARCHIVE_SOURCE='repository-release',
                   LD_LIBRARY_PATH=str(ROOT/'BYOND/byond/bin') + ':' + env.get('LD_LIBRARY_PATH',''),
                   PYTHONDONTWRITEBYTECODE='1')
        with (output/('outer-'+phase+'.log')).open('xb') as log:
            result = subprocess.run(argv, cwd=ROOT, env=env, stdin=subprocess.DEVNULL,
                                    stdout=log, stderr=subprocess.STDOUT, timeout=seconds+KILL_AFTER+5)
        row['returncode'] = result.returncode
        row['status'] = 'phase_failed' if result.returncode else 'bootstrap_completed'
        if phase == 'pilot':
            receipt = json.loads((output/'cases/receipt.json').read_text())
            verdict = receipt.get('diagnostic_verdict')
            row['pilot_verdict'] = verdict
            # not_run can be stale after persistent I/O failure, even after launches.
            rows = receipt.get('results', [])
            complete = (receipt.get('execution') == 'diagnostic_only'
                        and receipt.get('acceptance_status') == 'not_established'
                        and receipt.get('fixed_order') == list(pilot.ORDER)
                        and len(rows) == 8 and not receipt.get('stop')
                        and [r.get('pilot_index') for r in rows] == list(range(8))
                        and [r.get('case') for r in rows] == pilot.plan())
            if complete and verdict == 'completed_no_breach_observed' and result.returncode == 0 and all(r.get('passed') is True for r in rows):
                row['status'] = 'diagnostic_completed_no_breach_observed'
            elif complete and verdict == 'completed_with_breaches' and result.returncode == 1 and any(r.get('passed') is False for r in rows):
                row['status'] = 'diagnostic_completed_with_failures'
            else:
                row['status'] = 'unfinalized_or_inconclusive'
    except BaseException as exc:
        error = exc
        row['error'] = pilot._error_record(exc)
        raise
    finally:
        row['qualifications'] = (
            'Existing timeout supervises the controller; inner monitor handles owned direct children. '
            'Native children start new sessions and descendant cleanup is not established by controller timeout. '
            'Trusted ephemeral runner/job termination is a backstop, not measured containment or hard I/O bounds. '
            'Artifact retention is best effort; missing/unfinalized evidence is inconclusive.')
        try:
            pilot._atomic_json(output/('outer-'+phase+'.json'), row)
        except BaseException as publish:
            if error is not None:
                error.add_note('Outer receipt write also failed: ' + str(publish))
            else:
                raise
    return row

def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode',choices=('prepare','admit','bootstrap','pilot'))
    parser.add_argument('--head',required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--reviewed-scope')
    parser.add_argument('--authorized-until')
    args=parser.parse_args(argv)
    if args.mode == 'prepare':
        args.output.mkdir(parents=True,exist_ok=False)
        row=manifest(args.head)
        pilot._atomic_json(args.output/'host-manifest.json',row)
        (args.output/'host-manifest.sha256').write_text(digest(canonical(row)),encoding='ascii')
        print(digest(canonical(row)))
        return 0
    if args.mode == 'admit':
        admit(args.output,args.head,args.reviewed_scope,args.authorized_until)
        return 0
    row=run_phase(args.output,args.head,args.reviewed_scope,args.mode)
    return 0 if row['status'] in ('bootstrap_completed','diagnostic_completed_no_breach_observed') else 1

if __name__ == '__main__':
    raise SystemExit(main())
