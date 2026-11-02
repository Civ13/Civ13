"""Unrun synthetic custody coordinator. No network or live server access."""
import ctypes
from ctypes import wintypes
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
import time
from unittest import mock

SNAPSHOT=Path(__file__).resolve().parent
sys.path.insert(0,str(SNAPSHOT/'source'))
import trusted_update_commands as commands
import windows_owned_job as jobs
import windows_handle_evidence as handles
from windows_scope_evidence import current_process_sid,inspect_handle,evaluate_integrity,IntegrityPolicy

ROOT=Path(os.environ['RUNNER_TEMP']).resolve()/'civ13-custody'
with (ROOT/'runtime.json').open('rb') as runtime_file:runtime_bytes=runtime_file.read(16385)
if len(runtime_bytes)>16384 or hashlib.sha256(runtime_bytes).hexdigest()!=os.environ['CUSTODY_RUNTIME_SHA256']:
    raise RuntimeError('runtime_manifest_mismatch')
runtime=json.loads(runtime_bytes)
PYTHON=Path(runtime['python'])
PYTHON_SHA=runtime['python_sha256']

class InjectedRegistration(KeyboardInterrupt):pass
class InjectedClock(RuntimeError):pass


def require(condition,reason):
    if not condition:raise RuntimeError(reason)


def digest(path):
    with Path(path).open('rb') as f:
        h=hashlib.sha256()
        total=0
        for block in iter(lambda:f.read(65536),b''):
            total+=len(block);require(total<=67108864,'hash_limit');h.update(block)
        return h.hexdigest()


def check_chain(chain,policy):
    chain.recheck()
    for h in chain.handles:
        require(evaluate_integrity(inspect_handle(h),policy).permitted,'acl_or_owner_refused')


class Workspace:
    def __init__(self,scratch,python):
        from types import SimpleNamespace
        self.supervisor=SimpleNamespace(_fixed_command_active=False,_fixed_command_job=None,_fixed_cycle_halted=False)
        self.scratch=scratch;self.python=python;self.actor=current_process_sid()
        # Synthetic fixture policy only. No principal or ACL is modified.
        trusted=frozenset({self.actor,'S-1-5-18','S-1-5-32-544'})
        self.policy=IntegrityPolicy(trusted,trusted)
        self.chains=[];self.active=False
    def __enter__(self):
        try:
            for path in (self.scratch,self.python):
                chain=handles.RetainedPathEvidence(str(path),allow_tool_hardlinks=(path==self.python))
                chain.__enter__();self.chains.append(chain)
            self.active=True;self.require();return self
        except BaseException:
            self.__exit__(*sys.exc_info());raise
    def require(self):
        require(self.active and current_process_sid()==self.actor,'identity_changed')
        for chain in self.chains:check_chain(chain,self.policy)
    require_live=require
    def require_no_nested_git_shadow(self,stage):
        self.require();require(not (Path(stage)/'git.exe').exists(),'unexpected_git_shadow')
    def verify_executable(self,path):
        require(Path(path)==self.python and digest(path)==PYTHON_SHA,'python_pin_changed')
        self.require()
    def __exit__(self,typ,error,tb):
        self.active=False
        while self.chains:self.chains.pop().__exit__(typ,error,tb)
        return False


def wait_ready(case):
    deadline=time.monotonic()+5
    while time.monotonic()<deadline:
        try:
            with (case/'child-ready.marker').open('rb') as f:
                require(f.read(9)==b'ready-v1','ready_marker_invalid');return
        except FileNotFoundError:time.sleep(0.02)
    raise RuntimeError('ready_marker_timeout')


def run_case(scratch,name,mode,fixture_bytes):
    case=scratch/name;case.mkdir();(case/'scripts').mkdir()
    fixture=case/'scripts'/'build-crafting-atlas.py'
    with fixture.open('xb') as out:out.write(fixture_bytes);out.flush();os.fsync(out.fileno())
    require(digest(fixture)==hashlib.sha256(fixture_bytes).hexdigest(),'fixture_copy_mismatch')
    sentinel=InjectedRegistration('registration') if mode=='registration' else InjectedClock('clock')
    recorded={'case':name,'mode':mode,'held_before_unwind':False,'held_during_unwind':False,
              'released':False,'job_closed':False,'job_quiescent':False,'root_exit':None,
              'pipe_closed_before_fixture_cleanup':None,'pipe_closed_after_fixture_cleanup':None,
              'drain_threads_joined':False,'same_error':False,'active_after':None,
              'inflight_after':None,'spawn_attempts':0,'failure':None}
    seen=[];started=[];original_thread=threading.Thread
    def tracked_thread(*a,**kw):
        thread=original_thread(*a,**kw);started.append(thread);return thread
    with Workspace(scratch,PYTHON) as workspace:
        owner=workspace.supervisor
        policy=commands.CommandPolicy(str(scratch),str(case),'a'*32,'b'*40,'c'*40,
            str(ROOT/'unused-git.exe'),str(PYTHON),str(ROOT/'unused-compiler.exe'),str(case/'unused-catalog.json'))
        env={'SystemRoot':r'C:\Windows','WINDIR':r'C:\Windows',
             'PATH':str(PYTHON.parent),'TEMP':str(case),'TMP':str(case),
             'PYTHONNOUSERSITE':'1','PYTHONDONTWRITEBYTECODE':'1'}
        runner=commands.BoundedCommandRunner(policy,env,workspace,lambda:setattr(owner,'_fixed_cycle_halted',True))
        original_register=commands._CommandCustody.register
        def gate(job):
            wait_ready(case)
            require(jobs.peek_inflight() is job and owner._fixed_command_active,'job_binding_missing')
            try:job.wait(timeout=0)
            except subprocess.TimeoutExpired:recorded['held_before_unwind']=True
            else:raise RuntimeError('child_exited_before_fault')
            old=job.wait
            def wait_with_barrier(timeout=None):
                require(sys.exc_info()[1] is sentinel,'fault_not_active_at_retention')
                require(owner._fixed_command_active and jobs.peek_inflight() is job,'retention_binding_changed')
                try:old(timeout=0)
                except subprocess.TimeoutExpired:recorded['held_during_unwind']=True
                else:raise RuntimeError('child_exited_before_release')
                with (case/'release.marker').open('xb') as f:
                    f.write(b'release1');f.flush();os.fsync(f.fileno())
                recorded['released']=True
                job.wait=old
                return old(timeout=timeout)
            job.wait=wait_with_barrier;seen.append(job)
        def register(custody,job):
            recorded['spawn_attempts']+=1
            if mode=='registration':gate(job);raise sentinel
            return original_register(custody,job)
        def clock():
            require(mode=='clock','unexpected_clock')
            job=owner._fixed_command_job
            require(job is not None,'registered_job_missing')
            gate(job);raise sentinel
        if mode=='clock':runner.clock=clock
        args=[str(PYTHON),'-S','-B','scripts/build-crafting-atlas.py',
              '--catalog-only','--game-catalog',str(case/'unused-catalog.json')]
        try:
            with mock.patch.object(commands._CommandCustody,'register',register), \
                 mock.patch.object(threading,'Thread',side_effect=tracked_thread):
                runner.run(args,cwd=str(case),timeout=10)
        except BaseException as error:
            recorded['same_error']=error is sentinel
        if len(seen)==1:
            job=seen[0]
            recorded['root_exit']=job.code
            recorded['job_closed']=job.closed;recorded['job_quiescent']=job.quiescent
            for thread in started:thread.join(timeout=1)
            recorded['drain_threads_joined']=all(not t.is_alive() for t in started)
            recorded['pipe_closed_before_fixture_cleanup']=[job.stdout.closed,job.stderr.closed]
            # Only after quiescence, close exactly these owned synthetic pipe reads.
            if job.closed and job.quiescent:
                for stream in (job.stdout,job.stderr):
                    if not stream.closed:stream.close()
            recorded['pipe_closed_after_fixture_cleanup']=[job.stdout.closed,job.stderr.closed]
        recorded['active_after']=owner._fixed_command_active
        recorded['inflight_after']=jobs.peek_inflight() is not None
        checks=(recorded['same_error'] and recorded['held_before_unwind'] and
                recorded['held_during_unwind'] and recorded['released'] and
                recorded['job_closed'] and recorded['job_quiescent'] and recorded['root_exit']==0 and
                recorded['drain_threads_joined'] and recorded['pipe_closed_before_fixture_cleanup']==[True,True] and
                recorded['pipe_closed_after_fixture_cleanup']==[True,True] and
                recorded['active_after'] is False and recorded['inflight_after'] is False and
                recorded['spawn_attempts']==1)
        if not checks:recorded['failure']='acceptance_evidence_incomplete'
    return recorded


def main():
    require(len(sys.argv)==2,'scratch_argument_required')
    scratch=Path(sys.argv[1])
    require(scratch.is_absolute() and scratch.parent==ROOT/'runs' and scratch.name.startswith('run-'),'scratch_path_invalid')
    require(Path(sys.executable)==PYTHON and digest(PYTHON)==PYTHON_SHA,'python_pin_mismatch')
    with (SNAPSHOT/'manifest.json').open('rb') as f:manifest_bytes=f.read(16385)
    require(len(manifest_bytes)<=16384,'manifest_too_large')
    def unique(pairs):
        result={}
        for key,value in pairs:
            require(key not in result,'manifest_duplicate');result[key]=value
        return result
    manifest=json.loads(manifest_bytes,object_pairs_hook=unique)
    require(type(manifest) is dict and set(manifest)=={'schema','files'} and manifest['schema']==1,'manifest_invalid')
    require(type(manifest['files']) is dict and 1<=len(manifest['files'])<=16,'manifest_count')
    for relative,expected in manifest['files'].items():
        require(type(relative) is str and not relative.startswith(('/','\\')) and '..' not in Path(relative).parts,'manifest_path_invalid')
        require((SNAPSHOT/relative).stat().st_size<=1048576 and digest(SNAPSHOT/relative)==expected,'snapshot_pin_mismatch')
    with (SNAPSHOT/'stage'/'scripts'/'build-crafting-atlas.py').open('rb') as f:fixture=f.read(1048577)
    require(len(fixture)<=1048576,'fixture_too_large')
    results=[]
    try:
        results.append(run_case(scratch,'case-register','registration',fixture))
        results.append(run_case(scratch,'case-clock','clock',fixture))
    except BaseException as error:
        results.append({'failure':'coordinator_exception','type':type(error).__name__})
    encoded=json.dumps({'schema':1,'cases':results},sort_keys=True,separators=(',',':')).encode()
    require(len(encoded)<=16384,'result_too_large')
    with (scratch/'coordinator-result.json').open('xb') as f:
        f.write(encoded);f.flush();os.fsync(f.fileno())
    return 0 if len(results)==2 and all(x.get('failure') is None for x in results) else 1

if __name__=='__main__':raise SystemExit(main())
