"""Fresh pair binding, held until reviewed source and action-time admission."""
from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
import re
import subprocess

HERE = Path(__file__).resolve().parent
SOURCE = 'ff67d89241336d55f456967ec596d5cd10358df6'
BRANCH = 'ci/cloud-lighting-v2-pair-5161688-20261027-r1'
MESSAGE = 'ci: held lighting V2 off-on native pair r1 (2026-10-27)'


def validate(a, env, now, *, native_os, parent, message):
    def need(ok, why):
        if not ok:
            raise RuntimeError(why)
    need(a.get('released') is True, 'HELD: fresh root admission missing')
    need(a.get('schema') == 2 and a.get('sole_parent') == SOURCE and
         a.get('branch') == BRANCH and a.get('message') == MESSAGE and
         a.get('run_attempt') == 1 and a.get('jobs') == {'lighting_off': 0, 'lighting_on': 1},
         'Unreviewed activation identity')
    need(native_os == 'nt' and env.get('GITHUB_ACTIONS') == 'true' and
         env.get('RUNNER_ENVIRONMENT') == 'github-hosted', 'Hosted Windows only')
    need(env.get('GITHUB_REPOSITORY') == 'Civ13/Civ13' and env.get('GITHUB_RUN_ATTEMPT') == '1' and
         env.get('GITHUB_REF') == 'refs/heads/' + BRANCH and env.get('GITHUB_EVENT_NAME') == 'push',
         'Wrong branch/repository/event/attempt')
    head, run, job = (env.get(k, '') for k in ('GITHUB_SHA','GITHUB_RUN_ID','GITHUB_JOB'))
    need(re.fullmatch('[0-9a-f]{40}', head) and re.fullmatch('[1-9][0-9]*', run) and
         job in a['jobs'] and env.get('LIGHTING_MODE') == str(a['jobs'][job]), 'Wrong head/run/job/mode')
    need(parent == SOURCE and message == MESSAGE and
         env.get('EVENT_BEFORE') in (SOURCE, '0'*40), 'Wrong ancestry/publication')
    # A specific run ID may only be bound after GitHub assigns it. Do not invent it.
    need(a.get('run_id') is None or a['run_id'] == run, 'Wrong fresh run ID')
    end = datetime.fromisoformat(a['deadline_utc'].replace('Z', '+00:00'))
    need(end == datetime(2026,10,27,12,0,0,tzinfo=timezone.utc) and
         now + timedelta(minutes=5) < end, 'Expired deadline or insufficient reserve')
    return dict(controller=head, sole_parent=parent, branch=BRANCH, run_id=run,
                run_attempt=1, job=job, mode=a['jobs'][job], deadline_utc=a['deadline_utc'])


def require_runtime():
    a = json.loads((HERE/'activation.json').read_text(encoding='utf-8'))
    if a.get('released') is not True:
        raise RuntimeError('HELD: fresh root admission missing')
    root = os.environ.get('GITHUB_WORKSPACE', '')
    row = subprocess.check_output(['git','-C',root,'rev-list','--parents','-n','1','HEAD'],
                                  timeout=10, text=True).strip().split()
    if len(row) != 2 or row[0] != os.environ.get('GITHUB_SHA'):
        raise RuntimeError('Expected exact controller with one parent')
    message = subprocess.check_output(['git','-C',root,'log','-1','--format=%B'],
                                      timeout=10, text=True).strip()
    return validate(a, os.environ, datetime.now(timezone.utc), native_os=os.name,
                    parent=row[1], message=message)


if __name__ == '__main__':
    print(json.dumps(require_runtime(), sort_keys=True))
