"""Proposed owned Docker envelope for the synthetic sleep graph test.

Not run or approved. Requires an independently reviewed, preloaded image ID,
Docker CLI hash, and private /tmp root. No pull, daemon configuration or live
world access. Docker daemon/kernel and system Python remain trusted inputs.
"""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import secrets
import signal
import stat
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parent
CONTROLLER='4a201e057b63fcb6fc5e844d4962ac013ca52d7ab9218837a17968a41630e8d1'
WATCHDOG='323768b10f3463e7eb5f9424e2045f948bca2ec31b8c02023951ecfb55d89c35'
CONTRACT='152bb0b7398bfc47e814772f6f919bf6db01c5a63689e1001c339baf47cc0875'
BINDING='790120b605e77d24188655e962207c5b41f5553c79069cab68ad721c91b660d8'
STAGE='1b87f3b04561be600b0475d981f754f646d0144c6cded816a06560d5e6bbcc95'
MAX_LOG=8*1024**2

def require(value,message):
    if not value:raise ValueError(message)
def digest(data):return hashlib.sha256(data).hexdigest()
def read(path,limit):
    path=Path(path).absolute()
    require('..' not in path.parts,'parent traversal')
    for part in reversed((path,*path.parents)):
        require(not stat.S_ISLNK(part.lstat().st_mode),'linked path')
    info=path.lstat();require(stat.S_ISREG(info.st_mode) and info.st_size<=limit,'nonregular or oversized input')
    with path.open('rb') as f:data=f.read(limit+1)
    require(len(data)<=limit,'oversized input');return data

def load(name,path,want):
    require(digest(read(path,2*1024**2))==want,'source identity mismatch: '+name)
    spec=importlib.util.spec_from_file_location(name,path)
    mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod);return mod

def unique(pairs):
    value={}
    for key,item in pairs:
        if key in value:raise ValueError('duplicate JSON key')
        value[key]=item
    return value

def copy_new(source,target,limit,mode=0o400):
    data=read(source,limit);target.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
    with target.open('xb') as f:f.write(data)
    os.chmod(target,mode)
    require(digest(read(target,limit))==digest(data),'copied input mismatch')

def atomic_state(path,value,sequence):
    temporary=path.with_name('container-state-%d.tmp'%sequence)
    with temporary.open('x',encoding='utf-8') as f:
        json.dump(value,f,sort_keys=True);f.write('\n');f.flush();os.fsync(f.fileno())
    os.replace(temporary,path)

def wait_ready(proc,path,token,owner,deadline):
    while time.monotonic()<deadline:
        if proc.poll() is not None:raise RuntimeError('watchdog exited before ready')
        if path.exists():
            row=json.loads(read(path,4096),object_pairs_hook=unique)
            require(row=={'token':token,'owner_pid':owner,'watchdog_pid':proc.pid},'watchdog readiness mismatch')
            return
        time.sleep(.05)
    raise TimeoutError('watchdog readiness deadline')

def attach(docker,ident,env,main_dir,watcher,deadline):
    import resource
    out=main_dir/'attach.stdout.log';err=main_dir/'attach.stderr.log'
    def limits():
        resource.setrlimit(resource.RLIMIT_FSIZE,(MAX_LOG,MAX_LOG));resource.setrlimit(resource.RLIMIT_CORE,(0,0))
    with out.open('xb') as stdout,err.open('xb') as stderr:
        proc=subprocess.Popen([str(docker),'--host','unix:///var/run/docker.sock','--config',str(main_dir),'start','--attach',ident],env=env,stdin=subprocess.DEVNULL,stdout=stdout,stderr=stderr,start_new_session=True,preexec_fn=limits)
        problem=None;code=None
        try:
            while os.waitid(os.P_PID,proc.pid,os.WEXITED|os.WNOHANG|os.WNOWAIT) is None:
                if watcher.poll() is not None:problem='watchdog exited during attach';break
                if time.monotonic()>=deadline:problem='outer attach deadline';break
                time.sleep(.1)
        finally:
            try:os.killpg(proc.pid,signal.SIGKILL)
            except ProcessLookupError:pass
            except OSError as exc:problem='attach group cleanup unknown: '+str(exc)
            try:code=proc.wait(timeout=10)
            except subprocess.TimeoutExpired:problem='attach CLI leader unreaped'
        require(problem is None and code==0,'attach failed: '+str(problem or code))
    read(out,MAX_LOG);read(err,MAX_LOG)

def await_watchdog(watcher,watch_dir,timeout):
    deadline=time.monotonic()+timeout
    while time.monotonic()<deadline:
        if os.waitid(os.P_PID,watcher.pid,os.WEXITED|os.WNOHANG|os.WNOWAIT) is not None:
            try:os.killpg(watcher.pid,signal.SIGKILL)
            except ProcessLookupError:pass
            code=watcher.wait(timeout=10)
            row=json.loads(read(watch_dir/'watchdog-result.json',65536),object_pairs_hook=unique)
            require(code==0 and row.get('status')=='docker_cleanup_verified' and row.get('trigger')=='requested','watchdog cleanup not verified')
            return row
        time.sleep(.1)
    # Do not blindly issue a second mutation: the watchdog may be inside one.
    raise TimeoutError('watchdog cleanup outcome unknown')

def verify_inner(controller,run):
    accepted=json.loads(read(run/'accepted.json',2*1024**2),object_pairs_hook=unique)
    require(type(accepted) is dict and accepted.get('status')=='passed_synthetic' and accepted.get('controller_sha256')==CONTROLLER and accepted.get('stage_manifest_sha256')==STAGE and accepted.get('native_game_or_authority_proved') is False,'inner acceptance mismatch')
    work=run/'fixture';writer=controller.receipt(work/'writer-result.json','writer');controller.receipt(work/'reader-result.json','reader')
    payload=controller.validate_payload(work)
    require(payload==accepted.get('payload') and digest(read(work/'writer-result.json',65536))==accepted.get('writer_receipt_sha256'),'outer payload or writer receipt mismatch')
    builds=accepted.get('compiled_sha256')
    require(type(builds) is dict and set(builds)=={'.dmb','.rsc'} and all(digest(read(work/('fixture'+ext),controller.MAX_FILE))==builds[ext] for ext in builds),'outer compiled artifact mismatch')
    require(writer['mode']=='writer','writer identity')
    return {'payload':payload,'compiled_sha256':builds,'writer_receipt_sha256':accepted['writer_receipt_sha256']}

def verify_job_binding(receipt,image,docker_sha,python_sha,env,boot):
    require(type(receipt) is dict and type(receipt.get('schema')) is int and receipt['schema']==1 and receipt.get('status')=='prepared' and receipt.get('phase')=='before_native' and receipt.get('mode')=='execute' and receipt.get('native_executed') is False,'prepared binding schema or phase')
    require(receipt.get('image_id')==image and receipt.get('docker_sha256')==docker_sha and receipt.get('python_sha256')==python_sha and receipt.get('endpoint')=='unix:///var/run/docker.sock','prepared binding mismatch')
    require(all(isinstance(env.get(k),str) and env.get(k) for k in ('GITHUB_RUN_ID','GITHUB_RUN_ATTEMPT','GITHUB_JOB','GITHUB_SHA')),'job identity unavailable')
    require(receipt.get('run_id')==env['GITHUB_RUN_ID'] and receipt.get('run_attempt')==env['GITHUB_RUN_ATTEMPT'] and receipt.get('job')==env['GITHUB_JOB'] and receipt.get('head')==env['GITHUB_SHA'] and receipt.get('boot_id')==boot,'binding is from another job or host')
    return {'socket':receipt['socket'],'daemon':receipt['daemon']}

def run(sandbox,byond,archive,image,docker,docker_sha,runner_sha,python_sha,binding_path):
    require(sys.platform.startswith('linux') and os.geteuid()!=0 and hasattr(os,'pidfd_open') and hasattr(signal,'pidfd_send_signal') and hasattr(os,'waitid') and hasattr(os,'WNOWAIT'),'unprivileged Linux pidfd/waitid/signalling required')
    for value in (runner_sha,docker_sha,python_sha):require(re.fullmatch(r'[0-9a-f]{64}',value or '') is not None,'reviewed executable hashes required')
    require(digest(read(__file__,2*1024**2))==runner_sha,'outer runner hash mismatch')
    require(re.fullmatch(r'sha256:[0-9a-f]{64}',image or '') is not None,'exact reviewed image ID required')
    python=Path(sys.executable).resolve();require(digest(read(python,64*1024**2))==python_sha,'host Python mismatch')
    require(digest(read(docker,64*1024**2))==docker_sha and os.access(docker,os.X_OK),'Docker CLI mismatch')
    controller=load('sleep_inner_controller',ROOT/'controller_linux.py',CONTROLLER)
    contract=load('sleep_container_contract',ROOT/'outer_container_contract.py',CONTRACT)
    watchdog=load('sleep_container_watchdog',ROOT/'owned_container_watchdog.py',WATCHDOG)
    host_binding=load('sleep_job_binding',ROOT/'host_binding.py',BINDING)
    receipt=json.loads(read(binding_path,65536),object_pairs_hook=unique)
    binding=verify_job_binding(receipt,image,docker_sha,python_sha,os.environ,host_binding.boot_identity())
    manifest=controller.source_binding(CONTROLLER)
    sandbox=controller.plain(sandbox,'dir');info=sandbox.stat()
    require(sandbox.parent==Path('/tmp') and info.st_uid==os.geteuid() and stat.S_IMODE(info.st_mode)&0o077==0 and not any(sandbox.iterdir()),'fresh private /tmp root required')
    controller.require_free(sandbox)
    source=sandbox/'source';runtime=sandbox/'runtime';tmp=sandbox/'tmp';main=sandbox/'main';watch=sandbox/'watch'
    for path in (source,runtime,tmp,main,watch):path.mkdir(mode=0o700)
    fixture_root=tmp/'sleep-fixture';fixture_root.mkdir(mode=0o700)
    source_files=['controller_linux.py','scripts/byond_runtime.py','scripts/byond_toolchain.py','tools/byond/version.json','fixture-stage-v6/stage-manifest.json']
    source_files += ['fixture-stage-v6/'+name for name in sorted(controller.STAGED)]
    for name in source_files:copy_new(ROOT/name,source/name,2*1024**2)
    # Bind the copied verifier and its version file as well as the original.
    require(digest(read(source/'controller_linux.py',2*1024**2))==CONTROLLER and digest(read(source/'fixture-stage-v6/stage-manifest.json',2*1024**2))==STAGE,'copied source binding')
    for name,want in manifest['staged_sha256'].items():require(digest(read(source/'fixture-stage-v6'/name,2*1024**2))==want,'copied stage file changed')
    for name,want in controller.HELPERS.items():require(digest(read(source/name,2*1024**2))==want,'copied runtime verifier changed')
    spec=importlib.util.spec_from_file_location('sleep_outer_runtime',ROOT/'scripts/byond_runtime.py');verifier=importlib.util.module_from_spec(spec);spec.loader.exec_module(verifier)
    identity=verifier.verify_linux(byond,archive)
    for name in ('DreamMaker','DreamDaemon','libbyond.so','libext.so'):
        copy_new(Path(byond)/name,runtime/'bin'/name,32*1024**2,0o500 if name in ('DreamMaker','DreamDaemon') else 0o400)
    copy_new(archive,runtime/'archive.zip',64*1024**2)
    require(verifier.verify_linux(runtime/'bin',runtime/'archive.zip')==identity,'copied runtime mismatch')
    controller.require_free(sandbox)
    docker=Path(docker).absolute();host_binding.same_daemon(docker,main,binding)
    dc=watchdog.Docker(docker,docker_sha,main,binding)
    image_data=json.loads(dc(['image','inspect',image]),object_pairs_hook=unique)
    require(type(image_data) is list and len(image_data)==1,'image inspect shape');contract.validate_image(image_data[0],image)
    token=secrets.token_hex(16)
    state={'token':token,'image':image,'create_started':False,'create_confirmed':False,'container_id':None,'start_started':False,'start_confirmed':False}
    with (watch/'daemon-binding.json').open('x',encoding='utf-8') as f:json.dump(binding,f,sort_keys=True)
    atomic_state(watch/'container-state.json',state,0)
    deadline=time.monotonic()+420
    env={'PATH':'/usr/bin:/bin','HOME':str(main),'LANG':'C','LC_ALL':'C'}
    wout=main/'watchdog.stdout.log';werr=main/'watchdog.stderr.log'
    watcher=None;outer_error=None;inner=None;cleanup=None;container_id=None;exit_state=None
    require(digest(read(ROOT/'owned_container_watchdog.py',2*1024**2))==WATCHDOG,'watchdog source changed')
    try:
        with wout.open('xb') as stdout,werr.open('xb') as stderr:
            watcher=subprocess.Popen([str(python),'-I',str(ROOT/'owned_container_watchdog.py'),'--run-watchdog','--owner-pid',str(os.getpid()),'--deadline-monotonic',str(deadline),'--token',token,'--image-id',image,'--docker',str(docker),'--docker-sha256',docker_sha,'--evidence',str(watch)],stdin=subprocess.DEVNULL,stdout=stdout,stderr=stderr,env=env,start_new_session=True)
        wait_ready(watcher,watch/'watchdog-ready.json',token,os.getpid(),min(deadline,time.monotonic()+10))
        require(watcher.poll() is None,'watchdog unavailable before create')
        controller.require_free(sandbox)
        state['create_started']=True;atomic_state(watch/'container-state.json',state,1)
        container_id=dc(contract.command(image,token,os.geteuid(),os.getegid(),source,runtime,tmp)['argv'])
        require(re.fullmatch(r'[0-9a-f]{64}',container_id or '') is not None,'container create output unknown')
        state['create_confirmed']=True;state['container_id']=container_id;atomic_state(watch/'container-state.json',state,2)
        details=json.loads(dc(['inspect',container_id]),object_pairs_hook=unique)
        require(type(details) is list and len(details)==1,'container inspect shape')
        spec=contract.command(image,token,os.geteuid(),os.getegid(),source,runtime,tmp)
        contract.validate_inspect(details[0],spec,container_id)
        require(watcher.poll() is None and time.monotonic()<deadline,'watchdog or deadline before start')
        require(digest(read(docker,64*1024**2))==docker_sha,'Docker CLI changed before attach')
        dc.ensure_binding()
        state['start_started']=True;atomic_state(watch/'container-state.json',state,3)
        attach(docker,container_id,env,main,watcher,deadline)
        dc.ensure_binding()
        state['start_confirmed']=True;atomic_state(watch/'container-state.json',state,4)
        require(digest(read(docker,64*1024**2))==docker_sha,'Docker CLI changed after attach')
        details=json.loads(dc(['inspect',container_id]),object_pairs_hook=unique)
        require(type(details) is list and len(details)==1,'post-run inspect shape')
        contract.validate_inspect(details[0],spec,container_id,expected_state='exited')
        exit_state=details[0]['State'].copy()
        inner=verify_inner(controller,fixture_root/'run')
    except Exception as exc:
        outer_error=str(exc)[:1024]
    finally:
        if watcher:
            try:
                with (watch/'cleanup-request.json').open('x',encoding='utf-8') as f:json.dump({'token':token},f)
                cleanup=await_watchdog(watcher,watch,90)
            except Exception as exc:
                outer_error=(outer_error+'; ' if outer_error else '')+'cleanup unverified: '+str(exc)[:1024]
    result={'status':'passed_synthetic' if not outer_error and inner and cleanup else 'held',
            'error':outer_error,'image_id':image,'container_id':container_id,'token':token,
            'inner':inner,'cleanup':cleanup,'docker_exit_state':exit_state,'docker_cleanup_scope':'Docker metadata and owned label only; no proof of escaped descendants'}
    with (main/'outer-result.json').open('x',encoding='utf-8') as f:json.dump(result,f,sort_keys=True,indent=2);f.write('\n')
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--run-native',action='store_true',required=True)
    p.add_argument('--sandbox',type=Path,required=True);p.add_argument('--byond-bin',type=Path,required=True);p.add_argument('--byond-archive',type=Path,required=True)
    p.add_argument('--image-id',required=True);p.add_argument('--docker',type=Path,required=True);p.add_argument('--docker-sha256',required=True);p.add_argument('--runner-sha256',required=True);p.add_argument('--python-sha256',required=True)
    p.add_argument('--binding',type=Path,required=True)
    a=p.parse_args();r=run(a.sandbox,a.byond_bin,a.byond_archive,a.image_id,a.docker,a.docker_sha256,a.runner_sha256,a.python_sha256,a.binding)
    print(json.dumps(r,sort_keys=True));sys.exit(0 if r['status']=='passed_synthetic' else 1)
