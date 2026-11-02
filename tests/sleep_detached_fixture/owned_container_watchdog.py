"""Proposed independent watchdog for one labelled synthetic Docker container.

Unrun source candidate. Docker daemon/cgroup trust is assumed; this does not
prove absence of processes that escaped container control. No Docker operation
occurs on import. The supervisor must start it before attempting create.
"""
import argparse
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import select
import signal
import stat
import subprocess
import sys
import time

LABEL='org.civ13.sleep-fixture'
MAX_LOG=8*1024**2
BINDING_SHA='790120b605e77d24188655e962207c5b41f5553c79069cab68ad721c91b660d8'

def binding_module():
    path=Path(__file__).resolve().with_name('host_binding.py')
    require(hashlib.sha256(regular(path,2*1024**2)).hexdigest()==BINDING_SHA,'host binding source changed')
    spec=importlib.util.spec_from_file_location('sleep_job_binding',path)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    return module

def require(ok,message):
    if not ok:raise ValueError(message)

def regular(path,limit):
    p=Path(path).absolute()
    require('..' not in p.parts,'parent traversal')
    for node in reversed((p,*p.parents)):
        info=node.lstat();require(not stat.S_ISLNK(info.st_mode),'linked path')
    info=p.lstat();require(stat.S_ISREG(info.st_mode) and info.st_size<=limit,'not bounded regular file')
    with p.open('rb') as f:data=f.read(limit+1)
    require(len(data)<=limit,'oversize');return data

def unique(pairs):
    result={}
    for key,value in pairs:
        if key in result:raise ValueError('duplicate JSON key')
        result[key]=value
    return result

def exact_state(raw,token,image):
    s=json.loads(raw,object_pairs_hook=unique)
    require(type(s) is dict and set(s)=={'token','image','create_started','create_confirmed','container_id','start_started','start_confirmed'},'state shape')
    require(s['token']==token and s['image']==image and type(s['create_started']) is bool and type(s['create_confirmed']) is bool and type(s['start_started']) is bool and type(s['start_confirmed']) is bool,'state binding')
    require(not s['create_confirmed'] or (s['create_started'] and re.fullmatch(r'[0-9a-f]{64}',s['container_id'] or '') is not None),'confirmed identity')
    require(s['create_confirmed'] or s['container_id'] is None,'unconfirmed identity')
    require(not s['start_started'] or s['create_confirmed'],'start lacks confirmed create')
    require(not s['start_confirmed'] or s['start_started'],'confirmed start lacks dispatch')
    return s

def cleanup_owned(call,state,token,image):
    """One attempt per mutation. Return Docker-level evidence, never OS census."""
    result={'status':'unknown','container_id':None,'census_after':None,'create_uncertain':state['create_started'] and not state['create_confirmed'],'start_uncertain':state['start_started'] and not state['start_confirmed']}
    ids=call(['ps','--all','--quiet','--no-trunc','--filter','label='+LABEL+'='+token]).splitlines()
    require(len(ids)<=1 and all(re.fullmatch(r'[0-9a-f]{64}',x) for x in ids),'label census ambiguous')
    if state['create_confirmed'] and ids:require(ids[0]==state['container_id'],'label points to another container')
    if ids:
        require(state['create_started'],'container found before owned create')
        ident=ids[0];result['container_id']=ident
        raw=json.loads(call(['inspect',ident]),object_pairs_hook=unique);require(type(raw) is list and len(raw)==1,'inspect shape')
        info=raw[0]
        require(info.get('Id')==ident and info.get('Name')=='/civ13-sleep-'+token and info.get('Image')==image,'cleanup container identity')
        require(type(info.get('Config')) is dict and type(info['Config'].get('Labels')) is dict and info['Config']['Labels'].get(LABEL)==token,'cleanup label identity')
        status=info.get('State',{}).get('Status')
        require(status in ('created','running','exited','dead'),'unsupported Docker state')
        if status=='running':
            require(call(['kill',ident]).strip()==ident,'kill not confirmed')
            waited=call(['wait','--condition','not-running',ident]).strip()
            require(re.fullmatch(r'[0-9]+',waited) is not None,'wait not confirmed')
        require(call(['rm',ident]).strip()==ident,'remove not confirmed')
    after=call(['ps','--all','--quiet','--no-trunc','--filter','label='+LABEL+'='+token]).splitlines()
    require(not after,'owned label still present')
    result['census_after']=[]
    result['status']='cleanup_unverified_create_outcome' if result['create_uncertain'] else ('cleanup_unverified_start_outcome' if result['start_uncertain'] else 'docker_cleanup_verified')
    return result

class Docker:
    def __init__(self,path,want,logdir,binding):
        self.path=Path(path).absolute();self.want=want;self.logdir=Path(logdir);self.binding=binding;self.n=0
    def ensure_binding(self):
        require(hashlib.sha256(regular(self.path,64*1024**2)).hexdigest()==self.want,'Docker CLI changed')
        binding_module().same_daemon(self.path,self.logdir,self.binding)
    def __call__(self,args):
        self.ensure_binding()
        self.n+=1;out=self.logdir/('watch-docker-%03d.out'%self.n);err=self.logdir/('watch-docker-%03d.err'%self.n)
        env={'PATH':'/usr/bin:/bin','HOME':str(self.logdir),'LANG':'C','LC_ALL':'C'}
        def child_limits():
            import resource
            resource.setrlimit(resource.RLIMIT_FSIZE,(MAX_LOG,MAX_LOG));resource.setrlimit(resource.RLIMIT_CORE,(0,0))
        with out.open('xb') as stdout,err.open('xb') as stderr:
            p=subprocess.Popen([str(self.path),'--host','unix:///var/run/docker.sock','--config',str(self.logdir),*args],stdin=subprocess.DEVNULL,stdout=stdout,stderr=stderr,env=env,start_new_session=True,preexec_fn=child_limits)
            deadline=time.monotonic()+10
            timed_out=False
            try:
                while os.waitid(os.P_PID,p.pid,os.WEXITED|os.WNOHANG|os.WNOWAIT) is None:
                    if time.monotonic()>=deadline:
                        timed_out=True
                        break
                    time.sleep(.05)
            finally:
                signal_error=None
                try:os.killpg(p.pid,signal.SIGKILL)
                except ProcessLookupError:pass
                except OSError as exc:signal_error=str(exc)
                try:code=p.wait(timeout=10)
                except subprocess.TimeoutExpired:raise RuntimeError('Docker CLI leader unreaped')
            if signal_error:raise RuntimeError('Docker CLI group cleanup unknown: '+signal_error)
            if timed_out:raise RuntimeError('Docker CLI timeout; outcome unknown')
        data=regular(out,MAX_LOG);regular(err,MAX_LOG)
        require(code==0,'Docker CLI failed; outcome unknown')
        self.ensure_binding()
        return data.decode('utf-8','strict').strip()

def open_verified_parent(parent_pid,opener,get_parent,poll_factory,close):
    # Parentage is checked on both sides of pidfd_open so a reparented watcher
    # cannot accept a recycled numeric PID as its owner.
    require(get_parent()==parent_pid,'watch owner changed before pidfd')
    fd=opener(parent_pid,0)
    try:
        poll=poll_factory();poll.register(fd,select.POLLIN)
        require(get_parent()==parent_pid and not poll.poll(0),'watch owner changed or exited during pidfd binding')
        return fd,poll
    except Exception:
        close(fd)
        raise

def stop_deadline_owner(send,fd,poll):
    # Only a previously verified pidfd can be passed by watch().
    try:
        if poll.poll(0):return 'already_exited'
        send(fd,signal.SIGTERM)
        if poll.poll(5000):return 'term_exited'
        send(fd,signal.SIGKILL)
        return 'kill_exited' if poll.poll(5000) else 'unverified_still_running'
    except OSError as exc:
        if poll.poll(0):return 'already_exited'
        return 'unverified_signal_error: '+str(exc)

def reconcile_trigger(trigger,fd,poll,send,load_state,cleanup):
    require(trigger in ('requested','owner_lost','deadline'),'unknown watchdog trigger')
    result={'trigger':trigger,'status':'unknown','owner_deadline_signal':'not_requested'}
    if trigger=='deadline':
        result['owner_deadline_signal']=stop_deadline_owner(send,fd,poll)
        # Owner must be stopped before state read or any Docker census/mutation.
        if result['owner_deadline_signal'] not in ('already_exited','term_exited','kill_exited'):
            result['error']='owner was not confirmed stopped before cleanup'
            return result
    try:
        result.update(cleanup(load_state()))
    except Exception as exc:
        result['error']=str(exc)[:1024]
    return result

def watch(parent_pid,deadline,token,image,docker,docker_sha,evidence):
    require(sys.platform.startswith('linux') and os.geteuid()!=0 and hasattr(os,'pidfd_open') and hasattr(signal,'pidfd_send_signal') and hasattr(os,'waitid') and hasattr(os,'WNOWAIT'),'unprivileged Linux pidfd/waitid/signalling required')
    require(re.fullmatch(r'[0-9a-f]{32}',token or '') is not None and re.fullmatch(r'sha256:[0-9a-f]{64}',image or '') is not None,'watch identity')
    require(re.fullmatch(r'[0-9a-f]{64}',docker_sha or '') is not None and type(parent_pid) is int and parent_pid>1,'watch owner')
    require(math.isfinite(deadline) and time.monotonic()<deadline<=time.monotonic()+480 and os.getppid()==parent_pid,'watch deadline or parent')
    evidence=Path(evidence).absolute()
    require(evidence.parent.parent==Path('/tmp'),'evidence must be under a private /tmp child')
    for node in (evidence.parent,evidence):
        st=node.lstat()
        require(stat.S_ISDIR(st.st_mode) and not stat.S_ISLNK(st.st_mode) and st.st_uid==os.geteuid() and stat.S_IMODE(st.st_mode)&0o077==0,'private evidence directory required')
    binding=json.loads(regular(evidence/'daemon-binding.json',4096),object_pairs_hook=unique)
    require(type(binding) is dict and set(binding)=={'socket','daemon'},'daemon binding shape')
    fd,poll=open_verified_parent(parent_pid,os.pidfd_open,os.getppid,select.poll,os.close)
    try:
        ready_tmp=evidence/'watchdog-ready.tmp'
        with ready_tmp.open('x',encoding='utf-8') as ready:
            json.dump({'token':token,'owner_pid':parent_pid,'watchdog_pid':os.getpid()},ready);ready.write('\n');ready.flush()
        require(os.getppid()==parent_pid and not poll.poll(0),'watch owner changed before readiness')
        os.replace(ready_tmp,evidence/'watchdog-ready.json')
        while True:
            if (evidence/'cleanup-request.json').is_file():trigger='requested';break
            if poll.poll(0):trigger='owner_lost';break
            if time.monotonic()>=deadline:trigger='deadline';break
            time.sleep(.2)
        result=reconcile_trigger(trigger,fd,poll,signal.pidfd_send_signal,
            lambda:exact_state(regular(evidence/'container-state.json',4096),token,image),
            lambda state:cleanup_owned(Docker(docker,docker_sha,evidence,binding),state,token,image))
        with (evidence/'watchdog-result.json').open('x',encoding='utf-8') as out:json.dump(result,out,sort_keys=True,indent=2);out.write('\n')
        return result
    finally:os.close(fd)

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--run-watchdog',action='store_true',required=True)
    p.add_argument('--owner-pid',type=int,required=True);p.add_argument('--deadline-monotonic',type=float,required=True)
    p.add_argument('--token',required=True);p.add_argument('--image-id',required=True);p.add_argument('--docker',required=True);p.add_argument('--docker-sha256',required=True);p.add_argument('--evidence',required=True)
    a=p.parse_args();result=watch(a.owner_pid,a.deadline_monotonic,a.token,a.image_id,a.docker,a.docker_sha256,a.evidence)
    print(json.dumps(result,sort_keys=True));sys.exit(0 if result['status']=='docker_cleanup_verified' else 1)
