"""Windows owned command-job launcher; default-off and native-unverified.

CreateProcess receives its Job and inherited-handle list atomically. No job
termination or kill-on-close policy is configured. Wait keeps ownership until
root exit and observed zero active members; uncertainty never authorizes replay.
"""
import ctypes
from ctypes import wintypes
import os
import subprocess
import time
import threading

_inflight=threading.local()

def peek_inflight():
    return getattr(_inflight,'owned',None)

def release_inflight(job):
    if getattr(_inflight,'owned',None) is not job:raise JobUnavailable('inflight_identity_mismatch')
    if not job.closed:raise JobUnavailable('inflight_job_not_closed')
    del _inflight.owned

class JobUnavailable(RuntimeError):pass

class _SecurityAttributes(ctypes.Structure):
    _fields_=[('nLength',wintypes.DWORD),('lpSecurityDescriptor',ctypes.c_void_p),('bInheritHandle',wintypes.BOOL)]
class _StartupInfo(ctypes.Structure):
    _fields_=[('cb',wintypes.DWORD),('lpReserved',wintypes.LPWSTR),('lpDesktop',wintypes.LPWSTR),('lpTitle',wintypes.LPWSTR),
      ('dwX',wintypes.DWORD),('dwY',wintypes.DWORD),('dwXSize',wintypes.DWORD),('dwYSize',wintypes.DWORD),
      ('dwXCountChars',wintypes.DWORD),('dwYCountChars',wintypes.DWORD),('dwFillAttribute',wintypes.DWORD),
      ('dwFlags',wintypes.DWORD),('wShowWindow',wintypes.WORD),('cbReserved2',wintypes.WORD),
      ('lpReserved2',ctypes.c_void_p),('hStdInput',wintypes.HANDLE),('hStdOutput',wintypes.HANDLE),('hStdError',wintypes.HANDLE)]
class _StartupInfoEx(ctypes.Structure):
    _fields_=[('StartupInfo',_StartupInfo),('lpAttributeList',ctypes.c_void_p)]
class _ProcessInformation(ctypes.Structure):
    _fields_=[('hProcess',wintypes.HANDLE),('hThread',wintypes.HANDLE),('dwProcessId',wintypes.DWORD),('dwThreadId',wintypes.DWORD)]
class _JobAccounting(ctypes.Structure):
    _fields_=[('user',ctypes.c_longlong),('kernel',ctypes.c_longlong),('period_user',ctypes.c_longlong),
              ('period_kernel',ctypes.c_longlong),('faults',wintypes.DWORD),('total',wintypes.DWORD),
              ('active',wintypes.DWORD),('terminated',wintypes.DWORD)]


def _kernel():
    if os.name!='nt':raise JobUnavailable('windows_required')
    k=ctypes.WinDLL('kernel32',use_last_error=True)
    k.CreateJobObjectW.argtypes=[ctypes.c_void_p,wintypes.LPCWSTR];k.CreateJobObjectW.restype=wintypes.HANDLE
    k.CreatePipe.argtypes=[ctypes.POINTER(wintypes.HANDLE),ctypes.POINTER(wintypes.HANDLE),ctypes.POINTER(_SecurityAttributes),wintypes.DWORD];k.CreatePipe.restype=wintypes.BOOL
    k.SetHandleInformation.argtypes=[wintypes.HANDLE,wintypes.DWORD,wintypes.DWORD];k.SetHandleInformation.restype=wintypes.BOOL
    k.CreateFileW.argtypes=[wintypes.LPCWSTR,wintypes.DWORD,wintypes.DWORD,ctypes.POINTER(_SecurityAttributes),wintypes.DWORD,wintypes.DWORD,wintypes.HANDLE];k.CreateFileW.restype=wintypes.HANDLE
    k.InitializeProcThreadAttributeList.argtypes=[ctypes.c_void_p,wintypes.DWORD,wintypes.DWORD,ctypes.POINTER(ctypes.c_size_t)];k.InitializeProcThreadAttributeList.restype=wintypes.BOOL
    k.UpdateProcThreadAttribute.argtypes=[ctypes.c_void_p,wintypes.DWORD,ctypes.c_size_t,ctypes.c_void_p,ctypes.c_size_t,ctypes.c_void_p,ctypes.c_void_p];k.UpdateProcThreadAttribute.restype=wintypes.BOOL
    k.DeleteProcThreadAttributeList.argtypes=[ctypes.c_void_p];k.DeleteProcThreadAttributeList.restype=None
    k.CreateProcessW.argtypes=[wintypes.LPCWSTR,wintypes.LPWSTR,ctypes.c_void_p,ctypes.c_void_p,wintypes.BOOL,wintypes.DWORD,ctypes.c_void_p,wintypes.LPCWSTR,ctypes.POINTER(_StartupInfo),ctypes.POINTER(_ProcessInformation)];k.CreateProcessW.restype=wintypes.BOOL
    k.WaitForSingleObject.argtypes=[wintypes.HANDLE,wintypes.DWORD];k.WaitForSingleObject.restype=wintypes.DWORD
    k.GetExitCodeProcess.argtypes=[wintypes.HANDLE,ctypes.POINTER(wintypes.DWORD)];k.GetExitCodeProcess.restype=wintypes.BOOL
    k.GetProcessTimes.argtypes=[wintypes.HANDLE,ctypes.POINTER(wintypes.FILETIME),ctypes.POINTER(wintypes.FILETIME),ctypes.POINTER(wintypes.FILETIME),ctypes.POINTER(wintypes.FILETIME)]
    k.GetProcessTimes.restype=wintypes.BOOL
    k.QueryInformationJobObject.argtypes=[wintypes.HANDLE,ctypes.c_int,ctypes.c_void_p,wintypes.DWORD,ctypes.POINTER(wintypes.DWORD)];k.QueryInformationJobObject.restype=wintypes.BOOL
    k.CloseHandle.argtypes=[wintypes.HANDLE];k.CloseHandle.restype=wintypes.BOOL
    return k


def environment_block(env):
    if type(env) is not dict or not env:raise JobUnavailable('environment_required')
    pairs=[];names=set()
    for key,value in env.items():
        if type(key) is not str or type(value) is not str or not key or '=' in key or '\x00' in key or '\x00' in value:
            raise JobUnavailable('environment_invalid')
        if key.casefold() in names:raise JobUnavailable('environment_duplicate')
        names.add(key.casefold());pairs.append((key,value))
    pairs.sort(key=lambda x:x[0].casefold())
    return '\x00'.join(k+'='+v for k,v in pairs)+'\x00\x00'


class OwnedJob:
    def __init__(self,kernel,job,process,stdout,stderr,argv,*,setup_error=None):
        self.kernel,self.job,self.process=kernel,job,process
        self.stdout,self.stderr,self.args=stdout,stderr,tuple(argv)
        self.code=None;self.quiescent=False;self.closed=False;self.setup_error=setup_error;self.thread=None;self.pending_info=None
        self.process_close_attempted=False;self.job_close_attempted=False;self.uncertain_handles=False
        self.command_pipes_delegated=[False,False];self.command_pipe_close_attempted=[False,False];self.command_drain_close_state=['not_attempted','not_attempted']
    def creation_filetime(self):
        if self.closed or not self.process or self.process_close_attempted:
            raise JobUnavailable('process_handle_unavailable')
        created,exited,kernel,user=(wintypes.FILETIME() for _ in range(4))
        if not self.kernel.GetProcessTimes(self.process,ctypes.byref(created),ctypes.byref(exited),ctypes.byref(kernel),ctypes.byref(user)):
            raise JobUnavailable('process_creation_time_unavailable')
        return (created.dwHighDateTime<<32)|created.dwLowDateTime
    def wait(self,timeout=None):
        if self.closed:raise JobUnavailable('job_closed')
        if timeout is None or timeout<0:raise JobUnavailable('bounded_wait_required')
        deadline=time.monotonic()+timeout
        if self.thread or self.uncertain_handles:
            raise JobUnavailable('setup_handles_unresolved')
        if self.process_close_attempted and self.process:
            raise JobUnavailable('root_handle_close_uncertain')
        if self.process is None and self.code is None and self.pending_info is not None and self.pending_info.hProcess:
            self.process=self.pending_info.hProcess
        if self.process:
            remaining=max(0,int((deadline-time.monotonic())*1000))
            state=self.kernel.WaitForSingleObject(self.process,remaining)
            if state==258:raise subprocess.TimeoutExpired(self.args,timeout)
            if state!=0:raise JobUnavailable('root_wait_failed')
            code=wintypes.DWORD()
            if not self.kernel.GetExitCodeProcess(self.process,ctypes.byref(code)) or code.value==259:
                raise JobUnavailable('root_exit_unavailable')
            self.code=code.value
            self.process_close_attempted=True
            if not self.kernel.CloseHandle(self.process):raise JobUnavailable('root_handle_close_failed')
            self.process=None
            self.process_close_attempted=False
        while True:
            info=_JobAccounting();size=wintypes.DWORD()
            if not self.kernel.QueryInformationJobObject(self.job,1,ctypes.byref(info),ctypes.sizeof(info),ctypes.byref(size)) or size.value!=ctypes.sizeof(info):
                raise JobUnavailable('job_accounting_unavailable')
            if info.active==0:
                self.quiescent=True
                if self.code is None and self.setup_error is None:
                    raise JobUnavailable('root_exit_unavailable')
                return self.code
            if time.monotonic()>=deadline:raise subprocess.TimeoutExpired(self.args,timeout)
            time.sleep(min(0.05,max(0,deadline-time.monotonic())))
    def close_command_pipes(self):
        """Account for the exact owned command pipes after job quiescence.

        Once drain ownership is delegated only the drains close the streams;
        otherwise this owner closes each stream once. An uncertain close keeps
        custody unresolved rather than retrying a possibly reused handle.
        """
        if not self.quiescent or self.process or self.thread or self.uncertain_handles:
            raise JobUnavailable('command_pipes_before_quiescence')
        for index,stream in enumerate((self.stdout,self.stderr)):
            if self.command_pipe_close_attempted[index]:
                raise JobUnavailable('command_pipe_close_uncertain')
            if self.command_pipes_delegated[index]:
                state=self.command_drain_close_state[index]
                if state=='failed':raise JobUnavailable('command_pipe_drain_close_uncertain')
                if state!='succeeded' or not stream.closed:
                    raise JobUnavailable('command_pipe_drain_pending')
                continue
            if stream.closed:continue
            self.command_pipe_close_attempted[index]=True
            stream.close()
            if not stream.closed:raise JobUnavailable('command_pipe_close_unconfirmed')
            self.command_pipe_close_attempted[index]=False

    def close(self):
        if self.closed:return
        if not self.quiescent or self.process or self.thread or self.uncertain_handles:raise JobUnavailable('job_not_quiescent')
        if self.job_close_attempted:raise JobUnavailable('job_close_uncertain')
        self.job_close_attempted=True
        if not self.kernel.CloseHandle(self.job):raise JobUnavailable('job_close_failed')
        self.closed=True


def spawn(argv,*,cwd,env,stdin,stdout,stderr,shell,close_fds,creationflags):
    """Start one fixed command in a new job, with only explicit std handles."""
    import msvcrt
    if (type(argv) is not list or not argv or shell is not False or close_fds is not True or
        stdin!=subprocess.DEVNULL or stdout!=subprocess.PIPE or stderr!=subprocess.PIPE or
        creationflags!=getattr(subprocess,'CREATE_NO_WINDOW',0) or type(cwd) is not str):
        raise JobUnavailable('spawn_arguments_invalid')
    if any(type(a) is not str or '\x00' in a for a in argv):raise JobUnavailable('spawn_arguments_invalid')
    environment=ctypes.create_unicode_buffer(environment_block(env));command=ctypes.create_unicode_buffer(subprocess.list2cmdline(argv))
    k=_kernel();invalid=ctypes.c_void_p(-1).value
    if peek_inflight() is not None:raise JobUnavailable('previous_job_unresolved')
    owned=[];streams=[];attributes=None;initialized=False;armed=False;proc=None;pi=None;thread_attempted=False
    def close_raw(h):
        if h and h in owned:
            owned.remove(h)  # Never retry a close whose outcome is uncertain.
            previously_uncertain=proc.uncertain_handles if proc is not None and armed else False
            if proc is not None and armed:proc.uncertain_handles=True
            if not k.CloseHandle(h):raise JobUnavailable('setup_handle_close_failed')
            if proc is not None and armed:proc.uncertain_handles=previously_uncertain
    try:
        job=k.CreateJobObjectW(None,None)
        if not job:raise JobUnavailable('job_create_failed')
        owned.append(job)
        sa=_SecurityAttributes(ctypes.sizeof(_SecurityAttributes),None,True)
        read_handles=[];write_handles=[]
        for _ in range(2):
            read=wintypes.HANDLE();write=wintypes.HANDLE()
            if not k.CreatePipe(ctypes.byref(read),ctypes.byref(write),ctypes.byref(sa),0):raise JobUnavailable('pipe_create_failed')
            owned.extend((read.value,write.value));read_handles.append(read.value);write_handles.append(write.value)
            if not k.SetHandleInformation(read,1,0):raise JobUnavailable('pipe_inheritance_failed')
        null=k.CreateFileW('NUL',0x80000000,3,ctypes.byref(sa),3,0,None)
        if not null or null==invalid:raise JobUnavailable('stdin_open_failed')
        owned.append(null)
        for h in read_handles:
            fd=msvcrt.open_osfhandle(h,os.O_RDONLY|os.O_BINARY)
            owned.remove(h)
            try:streams.append(os.fdopen(fd,'rb',buffering=0))
            except BaseException:
                os.close(fd)
                raise
        size=ctypes.c_size_t()
        if k.InitializeProcThreadAttributeList(None,2,0,ctypes.byref(size)) or ctypes.get_last_error()!=122 or not 1<=size.value<=65536:
            raise JobUnavailable('attribute_size_failed')
        storage=ctypes.create_string_buffer(size.value);attributes=ctypes.cast(storage,ctypes.c_void_p)
        if not k.InitializeProcThreadAttributeList(attributes,2,0,ctypes.byref(size)):raise JobUnavailable('attribute_init_failed')
        initialized=True
        inherited=(wintypes.HANDLE*3)(null,*write_handles);jobs=(wintypes.HANDLE*1)(job)
        if not k.UpdateProcThreadAttribute(attributes,0,0x20002,inherited,ctypes.sizeof(inherited),None,None):raise JobUnavailable('handle_list_failed')
        if not k.UpdateProcThreadAttribute(attributes,0,0x2000d,jobs,ctypes.sizeof(jobs),None,None):raise JobUnavailable('job_list_failed')
        start=_StartupInfoEx();start.StartupInfo.cb=ctypes.sizeof(start);start.StartupInfo.dwFlags=0x100
        start.StartupInfo.hStdInput=null;start.StartupInfo.hStdOutput=write_handles[0];start.StartupInfo.hStdError=write_handles[1];start.lpAttributeList=attributes
        pi=_ProcessInformation()
        proc=OwnedJob(k,job,None,streams[0],streams[1],argv)
        flags=0x80000|0x400|0x08000000
        # Arm retained ownership before entering the creation call. Even an
        # interruption immediately on return must preserve the job and pipes.
        proc.pending_info=pi
        _inflight.owned=proc
        armed=True
        try:
            if not k.CreateProcessW(argv[0],command,None,None,True,flags,environment,cwd,ctypes.byref(start.StartupInfo),ctypes.byref(pi)):
                raise JobUnavailable('process_create_failed_or_uncertain')
            proc.process=pi.hProcess
        except BaseException as error:
            proc.process=pi.hProcess or None
            proc.setup_error=error
        # pi owns the primary thread handle if creation got far enough to fill
        # it. A failed close is retained and prevents a quiescence assertion.
        if pi.hThread:
            thread_attempted=True
            proc.thread=pi.hThread
            if not k.CloseHandle(pi.hThread):
                proc.setup_error=JobUnavailable('primary_thread_handle_close_failed')
            else:
                proc.thread=None
                pi.hThread=None
        for h in (*write_handles,null):
            try:close_raw(h)
            except BaseException as error:proc.setup_error=error
        return proc
    except BaseException as error:
        if armed and proc is not None:
            if pi is not None and pi.hProcess and not proc.process:proc.process=pi.hProcess
            if pi is not None and pi.hThread and not proc.thread:
                # Never retry an uncertain CloseHandle. Require reconciliation.
                proc.thread=pi.hThread
            proc.setup_error=error
            return proc
        raise
    finally:
        if initialized:k.DeleteProcThreadAttributeList(attributes)
        if not armed:
            if proc is not None and peek_inflight() is proc:del _inflight.owned
            for stream in streams:
                try:stream.close()
                except BaseException:pass
        while owned:
            h=owned.pop()
            if armed and proc is not None and h==proc.job:
                continue  # Never discard the live job on post-create failure.
            previously_uncertain=proc.uncertain_handles if armed and proc is not None else False
            if armed and proc is not None:proc.uncertain_handles=True
            if not k.CloseHandle(h):
                if armed and proc is not None:proc.setup_error=JobUnavailable('setup_handle_close_failed')
            elif armed and proc is not None:
                proc.uncertain_handles=previously_uncertain


class OwnedGame:
    """Long-lived job adapter for the existing retained supervisor owner."""
    def __init__(self,job):
        self.job=job;self.threads=[];self.drain_errors=[];self.done=False
    @property
    def pid(self):
        info=self.job.pending_info
        if info is None or not info.dwProcessId:raise JobUnavailable('game_process_identity_unavailable')
        return info.dwProcessId
    def creation_filetime(self):
        return self.job.creation_filetime()
    def start_drains(self):
        def drain(stream):
            try:
                while stream.read(65536):pass
            except BaseException:self.drain_errors.append('game_pipe_read_failed')
            finally:
                try:stream.close()
                except BaseException:self.drain_errors.append('game_pipe_close_failed')
        try:
            for stream in (self.job.stdout,self.job.stderr):
                thread=threading.Thread(target=drain,args=(stream,),daemon=True)
                thread.start();self.threads.append(thread)
        except BaseException as error:
            self.job.setup_error=error
            for stream in (self.job.stdout,self.job.stderr):
                try:stream.close()
                except BaseException:pass
            raise
    def wait(self,timeout=None):
        if self.done:return self.job.code
        code=self.job.wait(timeout=timeout)
        if code is None or self.job.setup_error is not None:
            raise JobUnavailable('game_start_or_exit_unknown')
        for thread in self.threads:
            thread.join(timeout=0)
            if thread.is_alive():raise JobUnavailable('game_pipe_drain_pending')
        if self.drain_errors:raise JobUnavailable('game_pipe_drain_failed')
        self.job.close();release_inflight(self.job);self.done=True
        return code
    def poll(self):
        try:return self.wait(timeout=0)
        except subprocess.TimeoutExpired:return None


def start_game(supervisor,argv,*,cwd,env,flags):
    """Install the retained child before handling any uncertain start result."""
    try:
        job=spawn(argv,cwd=str(cwd),env=env,stdin=subprocess.DEVNULL,
                  stdout=subprocess.PIPE,stderr=subprocess.PIPE,shell=False,
                  close_fds=True,creationflags=flags)
    except BaseException as error:
        job=peek_inflight()
        if job is not None:
            child=OwnedGame(job);supervisor.child=child
            try:child.start_drains()
            except BaseException as drain_error:error.add_note('Owned game drain setup failed: '+type(drain_error).__name__)
        supervisor._fixed_cycle_halted=True
        raise
    child=OwnedGame(job);supervisor.child=child
    try:child.start_drains()
    except BaseException:
        supervisor._fixed_cycle_halted=True
        raise
    if job.setup_error is not None:
        supervisor._fixed_cycle_halted=True
        raise JobUnavailable('owned_game_start_unknown') from job.setup_error
    return child
