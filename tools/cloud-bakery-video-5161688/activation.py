"""One fresh hosted source publication; inert until a separately reviewed release."""
from datetime import datetime, timedelta, timezone
import hashlib, json, os, re, subprocess
from pathlib import Path

HERE=Path(__file__).resolve().parent
SOURCE='58404f5bd16e3fed80f1d9844c5db3edd144942c'
PARENT='ff67d89241336d55f456967ec596d5cd10358df6'
BRANCH='ci/cloud-city-route-official-toolchain-5161688-20261030-r4'
MESSAGE='ci: bounded no-capture city route preflight r4'
DEADLINE='2026-10-31T20:00:00Z'

def validate_release_states(activation,scene,recording):
    if any(type(v) is not bool for v in (activation,scene,recording)) or activation != scene or recording is not False:
        raise RuntimeError('Release states disagree')
    return activation

def validate(a, env, now, parent, message, *, native_os):
    def need(ok,why):
        if not ok: raise RuntimeError(why)
    need(a.get('released') is True,'HELD: bakery execution not admitted')
    need(a.get('schema')==1 and a.get('source')==SOURCE and a.get('branch')==BRANCH and
         a.get('message')==MESSAGE and a.get('job')=='bakery' and a.get('attempt')==1,
         'Wrong immutable activation contract')
    need(native_os=='nt' and env.get('GITHUB_ACTIONS')=='true' and
         env.get('RUNNER_ENVIRONMENT')=='github-hosted','Hosted Windows only')
    need(env.get('GITHUB_REPOSITORY')=='Civ13/Civ13' and env.get('GITHUB_EVENT_NAME')=='push' and
         env.get('GITHUB_REF')=='refs/heads/'+BRANCH and env.get('GITHUB_JOB')=='bakery' and
         env.get('GITHUB_RUN_ATTEMPT')=='1','Wrong run/branch/job/attempt')
    need(parent==PARENT and message==MESSAGE and env.get('EVENT_BEFORE') in (PARENT,'0'*40),
         'Initial publication and sole parent required')
    head,run=env.get('GITHUB_SHA',''),env.get('GITHUB_RUN_ID','')
    need(re.fullmatch('[0-9a-f]{40}',head) and re.fullmatch('[1-9][0-9]*',run),'Provider-assigned identity missing')
    need(a.get('deadline_utc')==DEADLINE and now+timedelta(minutes=5)<datetime.fromisoformat(DEADLINE.replace('Z','+00:00')),
         'Expired deadline or insufficient reserve')
    need(re.fullmatch('[0-9a-f]{64}',a.get('scene_sha256','')),'Scene seal required')
    return dict(controller=head,run_id=run,job='bakery',run_attempt=1,source=SOURCE,
                sole_parent=parent,deadline_utc=DEADLINE,scene_sha256=a['scene_sha256'])

def require_runtime():
    a=json.loads((HERE/'activation.json').read_text())
    if a.get('released') is not True: raise RuntimeError('HELD: bakery execution not admitted')
    root=os.environ.get('GITHUB_WORKSPACE','')
    row=subprocess.check_output(['git','-C',root,'rev-list','--parents','-n','1','HEAD'],text=True,timeout=10).split()
    if len(row)!=2 or row[0]!=os.environ.get('GITHUB_SHA'): raise RuntimeError('Exact single-parent controller required')
    message=subprocess.check_output(['git','-C',root,'log','-1','--format=%B'],text=True,timeout=10).strip()
    d=(HERE/'derived-source.json').read_bytes()
    if hashlib.sha256(d).hexdigest()!=a['scene_sha256'] or json.loads(d)['native_released'] is not True:
        raise RuntimeError('Scene identity/release mismatch')
    from deferred_recording import NATIVE_RELEASED
    validate_release_states(a['released'],json.loads(d)['native_released'],NATIVE_RELEASED)
    if NATIVE_RELEASED: raise RuntimeError('Preflight forbids recording')
    return validate(a,os.environ,datetime.now(timezone.utc),row[1],message,native_os=os.name)

if __name__=='__main__': print(json.dumps(require_runtime(),sort_keys=True))
