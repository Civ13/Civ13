"""Pure command and environment policy for the disabled Gaia updater.

No filesystem access or process creation occurs here. This policy is not a
replacement for retained workspace, executable or process-ownership checks.
"""
from dataclasses import dataclass
import re

HEX40=re.compile(r'[0-9a-f]{40}\Z')
HEX32=re.compile(r'[0-9a-f]{32}\Z')

@dataclass(frozen=True)
class CommandPolicy:
    game: str
    stage: str
    operation: str
    before: str
    target: str
    git: str
    python: str
    compiler: str
    atlas: str


def _equals(a,b):
    return type(a) is str and type(b) is str and a.casefold()==b.casefold()


def permitted(policy,arguments,cwd):
    if type(policy) is not CommandPolicy or type(arguments) not in (tuple,list) or not arguments:
        return False
    if any(type(x) is not str or not x or '\x00' in x or len(x)>4096 for x in arguments):return False
    if not all(type(x) is str for x in (policy.game,policy.stage,policy.git,policy.python,policy.compiler,policy.atlas)):
        return False
    if not HEX32.fullmatch(policy.operation) or not HEX40.fullmatch(policy.before) or not HEX40.fullmatch(policy.target):return False
    exe,args=arguments[0],tuple(arguments[1:])
    in_game=_equals(cwd,policy.game);in_stage=_equals(cwd,policy.stage)
    if _equals(exe,policy.python):
        return in_stage and args==('-S','-B','scripts/build-crafting-atlas.py','--catalog-only','--game-catalog',policy.atlas)
    if _equals(exe,policy.compiler):return in_stage and args==('-max_errors','0','civ13.dme')
    if not _equals(exe,policy.git):return False
    if args[:3]==('--no-optional-locks','-C',policy.game):
        if not in_game:return False
        args=args[3:]
    elif args[:2]==('-C',policy.game):
        if not in_game:return False
        args=args[2:]
    fixed={
      ('config','--bool','--get','core.sparseCheckout'),
      ('config','--local','--no-includes','--null','--list'),
      ('status','--porcelain=v1','--untracked-files=all'),
      ('symbolic-ref','--quiet','--short','HEAD'),
      ('rev-parse','--abbrev-ref','--symbolic-full-name','@{upstream}'),
      ('symbolic-ref','--quiet','refs/remotes/origin/HEAD'),
      ('ls-files','-v'),('remote','get-url','--all','origin'),
      ('rev-parse','--verify','HEAD^{commit}'),
      ('fetch','--no-tags','origin','refs/heads/master:refs/remotes/origin/master'),
      ('rev-parse','--verify','refs/remotes/origin/master^{commit}'),
      ('ls-remote','--symref','--exit-code','origin','HEAD','refs/heads/master'),
      ('merge-base','--is-ancestor',policy.before,policy.target),
      ('merge','--ff-only',policy.target),('rev-parse','HEAD')}
    if in_game and args in fixed:return True
    if in_game and args==('--no-optional-locks','diff','--name-only','-z',policy.before,policy.target,'--','config','SQL/admins.txt'):return True
    if in_game and args==('clone','--shared','--no-checkout','--single-branch','--branch','master',policy.game,policy.stage):return True
    if in_stage and args in {('checkout','--detach',policy.target),('rev-parse','HEAD'),
      ('--no-optional-locks','ls-files','-z'),('--no-optional-locks','diff','--name-only','-z','HEAD'),
      ('--no-optional-locks','ls-files','--others','--exclude-standard','-z'),
      ('config','--local','--no-includes','--null','--list')}:return True
    return False


def controlled_environment(*,system_root,path,home,temp,git_exec_path,empty_hooks,empty_template):
    """Construct from trusted deployment strings; never inherit ambient variables."""
    values=(system_root,path,home,temp,git_exec_path,empty_hooks,empty_template)
    if any(type(v) is not str or not v or '\x00' in v or len(v)>8192 for v in values):
        raise ValueError('trusted_environment_unavailable')
    env={'SystemRoot':system_root,'WINDIR':system_root,'PATH':path,'HOME':home,
         'USERPROFILE':home,'TEMP':temp,'TMP':temp,'GIT_EXEC_PATH':git_exec_path,
         'GIT_CONFIG_NOSYSTEM':'1','GIT_CONFIG_GLOBAL':'NUL','GIT_CONFIG_SYSTEM':'NUL',
         'GIT_TERMINAL_PROMPT':'0','GIT_OPTIONAL_LOCKS':'0','GIT_PAGER':'cat',
         'GIT_ATTR_NOSYSTEM':'1','GIT_TEMPLATE_DIR':empty_template,
         'PYTHONNOUSERSITE':'1','PYTHONDONTWRITEBYTECODE':'1'}
    controls=(('core.hooksPath',empty_hooks),('core.fsmonitor','false'),
              ('credential.helper',''),('core.attributesFile','NUL'),
              ('core.pager','cat'),('protocol.ext.allow','never'))
    env['GIT_CONFIG_COUNT']=str(len(controls))
    for i,(key,value) in enumerate(controls):
        env['GIT_CONFIG_KEY_'+str(i)]=key;env['GIT_CONFIG_VALUE_'+str(i)]=value
    return env


_SAFE_LOCAL_KEYS=frozenset({'core.repositoryformatversion','core.filemode','core.bare',
 'core.logallrefupdates','core.ignorecase','core.precomposeunicode','core.symlinks',
 'remote.origin.url','remote.origin.fetch','branch.master.remote','branch.master.merge'})


def validate_local_config(raw,*,origin,allow_branch=True):
    """Parse `git config --local --no-includes --null --list` fail-closed."""
    if type(raw) is not bytes or len(raw)>65536 or not raw.endswith(b'\0'):raise ValueError('git_config_invalid')
    seen={}
    for record in raw[:-1].split(b'\0'):
        try:key,value=record.split(b'\n',1);key=key.decode('ascii').lower();value=value.decode('utf-8')
        except (ValueError,UnicodeError) as error:raise ValueError('git_config_invalid') from error
        if key not in _SAFE_LOCAL_KEYS or key in seen or '\x00' in value or len(value)>4096:
            raise ValueError('git_config_unsupported')
        seen[key]=value
    if seen.get('remote.origin.url')!=origin:raise ValueError('git_origin_mismatch')
    if not allow_branch and ('branch.master.remote' in seen or 'branch.master.merge' in seen):raise ValueError('git_branch_unexpected')
    return seen


class CommandRejected(RuntimeError):pass
class ChildOutcomeUnknown(RuntimeError):pass


class _CommandCustody:
    def __init__(self,supervisor):self.supervisor=supervisor;self.not_started=False
    def __enter__(self):
        if getattr(self.supervisor,'_fixed_command_active',False):
            raise CommandRejected('previous_command_requires_reconciliation')
        self.supervisor._fixed_command_active=True
        self.supervisor._fixed_command_job=None
        return self
    def register(self,job):self.supervisor._fixed_command_job=job
    def absent_before_spawn(self):
        self.not_started=True
        self.supervisor._fixed_command_active=False
    def done(self,job):
        if self.supervisor._fixed_command_job is not job:raise ChildOutcomeUnknown('command_identity_changed')
        self.supervisor._fixed_command_active=False
        self.supervisor._fixed_command_job=None
    def __exit__(self,typ,error,tb):
        if getattr(self.supervisor,'_fixed_command_active',False):
            self.supervisor._fixed_cycle_halted=True
            from canonical_owner import retain_command_preserving_interruption
            pending=retain_command_preserving_interruption(self.supervisor,original=error)
            if error is None and pending is not None:raise pending
        return False


class BoundedCommandRunner:
    """Retain an owned child to exit; never auto-kill or replay on uncertainty.

    Workspace must be an already retained, concrete verifier with require() and
    verify_executable(path) methods. This runner is not enabled by the channel.
    """
    def __init__(self,policy,environment,workspace,halt,*,popen=None,clock=None,sleep=None):
        import subprocess,time
        if type(policy) is not CommandPolicy or type(environment) is not dict or not callable(halt):
            raise CommandRejected('trusted_runner_configuration_invalid')
        self.policy=policy;self.environment=dict(environment);self.workspace=workspace;self.halt=halt
        self.owned_job=(popen is None)
        if self.owned_job:
            from windows_owned_job import spawn
            popen=spawn
        self.popen=popen;self.clock=clock or time.monotonic;self.sleep=sleep or time.sleep
        self.max_output=4*1024*1024
    def run(self,arguments,*,cwd,timeout=180,capture_output=True,text=False):
        import subprocess,threading
        if capture_output is not True or type(text) is not bool or type(timeout) not in (int,float) or not 0<timeout<=1800:
            raise CommandRejected('unsupported_invocation')
        if not permitted(self.policy,arguments,cwd):raise CommandRejected('command_not_allowlisted')
        # Probe local config without includes before every other Git command.
        args=tuple(arguments[1:])
        probe_tail=('config','--local','--no-includes','--null','--list')
        if _equals(arguments[0],self.policy.git) and not (len(args)>=len(probe_tail) and args[-len(probe_tail):]==probe_tail):
            repo=self.policy.stage if _equals(cwd,self.policy.stage) else self.policy.game
            probe=[self.policy.git,'-C',repo,*probe_tail] if _equals(repo,self.policy.game) else [self.policy.git,*probe_tail]
            checked=self.run(probe,cwd=repo,timeout=30,capture_output=True,text=False)
            if checked.returncode!=0:raise CommandRejected('local_config_probe_failed')
            expected='https://github.com/Civ13/Civ13.git' if _equals(repo,self.policy.game) else self.policy.game
            validate_local_config(checked.stdout,origin=expected)
        self.workspace.require();self.workspace.verify_executable(arguments[0]);self.workspace.require()
        if _equals(arguments[0],self.policy.python):
            self.workspace.require_no_nested_git_shadow(self.policy.stage)
        from contextlib import nullcontext
        custody_context=_CommandCustody(self.workspace.supervisor) if self.owned_job else nullcontext(None)
        with custody_context as custody:
            try:
                proc=self.popen(list(arguments),cwd=cwd,env=dict(self.environment),stdin=subprocess.DEVNULL,
                    stdout=subprocess.PIPE,stderr=subprocess.PIPE,shell=False,close_fds=True,
                    creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
            except BaseException as error:
                self.halt()
                if self.owned_job:
                    from windows_owned_job import peek_inflight
                    proc=peek_inflight()
                else:
                    proc=None
                if proc is None:
                    if custody is not None:custody.absent_before_spawn()
                    error.add_note('Child creation outcome is unknown; do not retry automatically.')
                    raise
                if proc.setup_error is None:proc.setup_error=error
            if custody is not None:custody.register(proc)
            buffers=[bytearray(),bytearray()];errors=[];threads=[];failed=getattr(proc,'setup_error',None)
            if failed is not None:self.halt()
            def drain(stream,index):
                try:
                    while True:
                        block=stream.read(65536)
                        if not block:break
                        room=max(0,self.max_output-len(buffers[index]))
                        buffers[index].extend(block[:room])
                        if len(block)>room and 'output_limit' not in errors:errors.append('output_limit')
                except BaseException:
                    errors.append('pipe_read_failed')
                finally:
                    try:
                        if self.owned_job:proc.command_drain_close_state[index]='attempting'
                        stream.close()
                        if self.owned_job:
                            if not stream.closed:raise ChildOutcomeUnknown('pipe_close_unconfirmed')
                            proc.command_drain_close_state[index]='succeeded'
                    except BaseException:
                        if self.owned_job:proc.command_drain_close_state[index]='failed'
                        errors.append('pipe_close_failed')
            try:
                for i,stream in enumerate((proc.stdout,proc.stderr)):
                    t=threading.Thread(target=drain,args=(stream,i),daemon=True)
                    # Mark ownership before start: interruption during start has
                    # an uncertain outcome, so never close that stream here.
                    if self.owned_job:proc.command_pipes_delegated[i]=True
                    t.start();threads.append(t)
            except BaseException as error:
                failed=error;self.halt()
                if not self.owned_job:
                    for stream in (proc.stdout,proc.stderr):
                        try:stream.close()
                        except BaseException:pass
            deadline=self.clock()+timeout
            while True:
                try:
                    code=proc.wait(timeout=0.5)
                    if self.clock()>deadline and failed is None:
                        failed=ChildOutcomeUnknown('child_timeout_retained_until_exit');self.halt()
                    break
                except subprocess.TimeoutExpired:
                    try:
                        if self.clock()>deadline and failed is None:
                            failed=ChildOutcomeUnknown('child_timeout_retained_until_exit');self.halt()
                        self.workspace.require_live()
                    except BaseException as error:
                        if failed is None:failed=error;self.halt()
                except BaseException as error:
                    if failed is None:failed=error;self.halt()
                    try:self.sleep(0.25)
                    except BaseException as pacing_error:
                        if failed is None:failed=pacing_error;self.halt()
                        try:
                            from canonical_owner import _fallback_pause
                            _fallback_pause()
                        except BaseException as fallback_error:
                            if failed is None:failed=fallback_error;self.halt()
            for t in threads:
                try:t.join(timeout=2)
                except BaseException as error:
                    if failed is None:failed=error;self.halt()
                if t.is_alive():errors.append('pipe_drain_incomplete')
            try:
                if self.owned_job:proc.close_command_pipes()
                close_job=getattr(proc,'close',None)
                if close_job is not None:close_job()
                if self.owned_job:
                    from windows_owned_job import release_inflight
                    release_inflight(proc)
                    custody.done(proc)
            except BaseException as error:
                if failed is None:failed=error;self.halt()
            try:
                self.workspace.require()
                self.workspace.verify_executable(arguments[0])
                self.workspace.require()
            except BaseException as error:
                if failed is None:failed=error;self.halt()
            if (type(code) is not int or not 0<=code<=0xffffffff) and failed is None:
                failed=ChildOutcomeUnknown('child_exit_unavailable');self.halt()
            if errors and failed is None:
                failed=ChildOutcomeUnknown('child_output_unavailable');self.halt()
            if failed is not None:
                failed.add_note('Owned child was retained until observed exit; no replay was attempted.')
                raise failed
            out,err=bytes(buffers[0]),bytes(buffers[1])
            if text:out,err=out.decode('utf-8','replace'),err.decode('utf-8','replace')
            return subprocess.CompletedProcess(list(arguments),code,out,err)
