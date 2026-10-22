"""Source-only Ubuntu backend. Nothing runs on import; CLI is plan-only.

PosixEffects is concrete; its source acceptance is distinct from runtime admission.
Tests inject every effect, including stdin, raw output and passive kernel reads.
"""
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import signal
import stat
import subprocess
import time

import run as r


def encoded(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':')).encode()


def relative(path):
    p = PurePosixPath(path)
    r.need(isinstance(path, str) and path and not p.is_absolute() and
           '..' not in p.parts and '\\' not in path and str(p) == path,
           'unsafe relative path')
    return path


@dataclass
class Owned:
    label: str
    process: object = None
    pid: int = None
    birth: str = None
    stdout: object = None
    stderr: object = None
    console: bool = False


class PosixEffects:
    """All native calls live here. No native calls are made by the offline tests.

    No shell, git credential helper, client, external account or public socket
    probe is used. Sources/toolchain must already exist as exact sealed inputs.
    """
    clock = staticmethod(time.monotonic)
    utc = staticmethod(time.time)
    wait = staticmethod(time.sleep)

    def capabilities(self):
        r.need(os.name == 'posix' and Path('/proc/self/stat').exists(), 'Linux /proc required')
        r.need(callable(getattr(os,'pidfd_open',None)) and
               callable(getattr(signal,'pidfd_send_signal',None)), 'Linux pidfd signaling required')

    def machine(self):
        return {'runner_memory_bytes':os.sysconf('SC_PHYS_PAGES')*os.sysconf('SC_PAGE_SIZE'),
                'runner_cpus':os.cpu_count()}

    def _safe(self, path):
        p = Path(path)
        r.need(p.is_absolute(), 'absolute owned path required')
        for parent in [p, *p.parents]:
            try:
                mode = parent.lstat().st_mode
            except FileNotFoundError:
                continue
            r.need(not stat.S_ISLNK(mode), 'symlink ancestor')
        return p

    def claim(self, path, payload):
        # No retry/unlink. Failed or uncertain reservations stay consumed.
        p = self._safe(path)
        fd = os.open(p, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd, 'wb') as out:
            out.write(payload); out.flush(); os.fsync(out.fileno())
        directory = os.open(p.parent, os.O_RDONLY | os.O_DIRECTORY)
        try: os.fsync(directory)
        finally: os.close(directory)

    def mkdir(self, path):
        self._safe(path).mkdir(mode=0o700, parents=False, exist_ok=False)

    def read(self, path):
        p = self._safe(path)
        fd = os.open(p, os.O_RDONLY | os.O_NOFOLLOW)
        with os.fdopen(fd, 'rb') as inp:
            st = os.fstat(inp.fileno())
            r.need(stat.S_ISREG(st.st_mode) and st.st_nlink == 1 and st.st_size <= 128*1024**2, 'unsafe/oversize file')
            return inp.read(128*1024**2+1)

    def write(self, path, data):
        p = self._safe(path)
        fd = os.open(p, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd, 'wb') as out:
            out.write(data); out.flush(); os.fsync(out.fileno())

    def files(self, root, deadline):
        self._safe(root)
        found = []
        pending = [Path(root)]
        total = 0
        while pending:
            r.need(self.clock() < deadline, 'filesystem traversal deadline')
            directory = pending.pop()
            with os.scandir(directory) as entries:
                for entry in entries:
                    r.need(self.clock() < deadline and len(found)+len(pending) < 10000, 'filesystem traversal bound')
                    rel = Path(entry.path).relative_to(root).as_posix()
                    r.need(len(PurePosixPath(rel).parts) <= 16, 'filesystem depth')
                    mode = entry.stat(follow_symlinks=False)
                    if stat.S_ISDIR(mode.st_mode):
                        pending.append(Path(entry.path))
                    else:
                        r.need(stat.S_ISREG(mode.st_mode) and mode.st_nlink == 1, 'nonregular/linked owned file')
                        found.append(rel)
                        total += mode.st_size
                        r.need(total <= 8*1024**3, 'filesystem bytes bound')
        return sorted(found)

    def sizes(self, root, names):
        result=[]
        for name in names:
            p=self._safe(str(Path(root)/relative(name)))
            st=p.lstat()
            r.need(stat.S_ISREG(st.st_mode) and st.st_nlink==1, 'monitor file changed type')
            result.append(st.st_size)
        return result

    def _stat(self, pid):
        raw = Path('/proc', str(pid), 'stat').read_text()
        tail = raw[raw.rindex(')')+2:].split()
        # tail begins field3: state,ppid,pgrp,session,...,starttime(field22).
        return {'pid':int(pid), 'state':tail[0], 'pgid':int(tail[2]), 'sid':int(tail[3]),
                'birth':tail[19], 'rss':int(tail[21])*os.sysconf('SC_PAGE_SIZE')}

    def launch(self, owned, argv, cwd, env, logroot, creation_guard):
        # Retain Popen object before __init__: even a partial creation failure has
        # a recorded object/pid. Owner slot itself is registered by caller first.
        owned.stdout = open(self._safe(logroot+'.stdout'), 'xb', buffering=0)
        owned.stderr = open(self._safe(logroot+'.stderr'), 'xb', buffering=0)
        try:
            creation_guard()  # after slow path/open preparation, at actual creation
            owned.process = subprocess.Popen.__new__(subprocess.Popen)
            subprocess.Popen.__init__(owned.process, argv, cwd=cwd, env=env,
                stdin=subprocess.PIPE if owned.console else subprocess.DEVNULL,
                stdout=owned.stdout, stderr=owned.stderr,
                shell=False, start_new_session=True, close_fds=True)
        finally:
            owned.pid = getattr(owned.process, 'pid', None)
            if owned.pid:
                try: owned.birth = self._stat(owned.pid)['birth']
                except FileNotFoundError: pass
        r.need(owned.pid and owned.birth, 'launch identity unavailable')
        creation_guard()  # slow constructor/identity read cannot admit later work
        if owned.console: os.set_blocking(owned.process.stdin.fileno(), False)

    def members(self, owned):
        if not owned.pid: return []
        result = []
        for name in os.listdir('/proc'):
            if not name.isdigit(): continue
            try: row = self._stat(name)
            except FileNotFoundError: continue
            if row['sid'] != owned.pid or row['state'] == 'Z': continue
            r.need(owned.birth is not None and int(row['birth']) >= int(owned.birth), 'session identity drift')
            if row['pid'] == owned.pid:
                r.need(row['birth'] == owned.birth, 'root PID reused')
            result.append(row)
        return result

    def poll(self, owned):
        return owned.process.poll()

    def sockets(self, members):
        inodes = set()
        for row in members:
            try:
                for fd in Path('/proc', str(row['pid']), 'fd').iterdir():
                    try: target = os.readlink(fd)
                    except FileNotFoundError: continue
                    if target.startswith('socket:['): inodes.add(target[8:-1])
            except FileNotFoundError: continue
        sockets = []
        for proto in ('tcp', 'tcp6', 'udp', 'udp6'):
            for line in Path('/proc/net', proto).read_text().splitlines()[1:]:
                cols = line.split()
                if cols[9] in inodes:
                    sockets.append({'proto':proto, 'local':cols[1], 'remote':cols[2], 'state':cols[3]})
        return sockets

    def stdin_write(self, owned, raw):
        r.need(owned.console and 0 < len(raw) <= 4096, 'bounded owned stdin required')
        r.need(os.write(owned.process.stdin.fileno(),raw) == len(raw), 'partial console write')

    def vacant(self, port):
        # Passive local kernel table read, never bind/connect/probe.
        for proto in ('udp', 'udp6'):
            for line in Path('/proc/net', proto).read_text().splitlines()[1:]:
                if int(line.split()[1].split(':')[1], 16) == port: return False
        return True

    def _pidfd_open(self, pid):
        return os.pidfd_open(pid,0)

    def _pidfd_signal(self, fd, sig):
        signal.pidfd_send_signal(fd,getattr(signal,sig),None,0)

    def _pidfd_close(self, fd):
        os.close(fd)

    def signal(self, owned, sig):
        if owned.process is not None:
            r.need(owned.pid is not None and owned.birth is not None, 'partial process identity unresolved')
        rows = self.members(owned)
        failures=[]
        for row in rows:
            fd=None
            try:
                # Target each member of the owned SESSION, including descendants
                # in a different process group. Never use a broad numeric PGID.
                fd=self._pidfd_open(row['pid'])
                current=self._stat(row['pid'])
                r.need(current['pid']==row['pid'] and current['birth']==row['birth'] and
                       current['sid']==row['sid']==owned.pid and
                       int(current['birth'])>=int(owned.birth), 'cleanup process identity drift')
                if current['pid']==owned.pid:
                    r.need(current['birth']==owned.birth, 'cleanup root PID reused')
                if current['state']!='Z': self._pidfd_signal(fd,sig)
            except (ProcessLookupError,FileNotFoundError):
                pass  # exited before opening/revalidation/signaling; never retarget
            except BaseException as error:
                if len(failures)<4: failures.append(str(error)[:160])
            finally:
                if fd is not None:
                    try: self._pidfd_close(fd)
                    except BaseException as error:
                        if len(failures)<4: failures.append(str(error)[:160])
        r.need(not failures,'owned process signaling failed: '+'; '.join(failures))

    def close_logs(self, owned):
        for handle in (owned.stdout, owned.stderr):
            if handle is not None: handle.close()
        if owned.console and owned.process is not None:
            handle = getattr(owned.process,'stdin',None)
            if handle is not None: handle.close()


class UbuntuBackend:
    """Concrete policy above injectable, low-level POSIX effects.

    All paths and per-file expected hashes are retained independently of the
    on-disk package/source manifests. Replacing a manifest with its files cannot
    authorize a replacement. No low-level method supplies a ready-made verdict.
    """
    def __init__(self, effects, root, claim_dir, bundle, inputs, startup):
        self.fx, self.root, self.claim_dir = effects, root, claim_dir
        self.bundle = json.loads(json.dumps(bundle))
        self.inputs, self.startup = dict(inputs), bytes(startup)
        self.groups, self.stages, self.compiled = [], {}, {}
        self.seen = False
        self.token = None
        self.current = None
        self.last_observation = None
        self.copied_sources = []
        self.observations = []
        self.resultbytes = {}

    def _path(self, suffix): return self.root+'/'+relative(suffix)

    def _check(self, deadline):
        r.need(self.fx.clock() < deadline and self.fx.clock() < self.work_end and self.fx.utc() < self.a['expires_utc'], 'backend budget/expiry')

    def _manifest(self, root, pins, deadline):
        r.need(isinstance(pins, dict) and bool(pins), 'missing independent file pins')
        actual = self.fx.files(root, deadline)
        r.need(actual == sorted(pins), 'file closure drift')
        result = {}
        for path, digest in pins.items():
            relative(path); self._check(deadline)
            result[path] = r.sha(self.fx.read(root+'/'+path))
            r.need(result[path] == digest, 'independent file seal differs: '+path)
        return result

    def _parents(self, path):
        # Only newly created, owned directories; root is never recursively erased.
        bits = PurePosixPath(relative(path)).parts[:-1]
        for i in range(1, len(bits)+1):
            p = '/'.join(bits[:i])
            if p not in self.dirs:
                self.fx.mkdir(self._path(p)); self.dirs.add(p)

    def _write(self, path, data, deadline):
        self._check(deadline)
        self._parents(path)
        self._check(deadline)
        self.fx.write(self._path(path), data)
        self._check(deadline)
        r.need(self.fx.read(self._path(path)) == data, 'write readback differs')

    def reserve(self, a):
        r.need(not self.seen, 'backend single use')
        self.seen = True
        self.entered = self.fx.clock()
        remaining = min(2400, a['expires_utc']-self.fx.utc())
        r.need(remaining > 30, 'expired before claim')
        self.end = self.entered+remaining; self.work_end = self.end-30
        self.fx.capabilities()
        machine = self.fx.machine()
        for k in ('runner_cpus',):
            r.need(machine[k] >= a['resource_envelope'][k], 'runner capacity differs')
        r.need(self.root.startswith('/') and self.claim_dir.startswith('/') and self.root != '/', 'owned absolute roots')
        r.need(r.sha(encoded(self.bundle)) == a['build_contract']['backend_bundle_sha256'], 'bundle differs')
        r.need(self.bundle['sdk_version'] == '10.0.401', 'SDK identity differs')
        r.need(self.bundle['source_identity'] == {'engine':r.ENGINE, 'tree':r.ENGINE_TREE, 'robust':r.ROBUST}, 'source identity differs')
        r.need(r.sha(encoded(self.bundle['source_files'])) == a['build_contract']['effective_source_manifest_sha256'], 'effective source manifest differs')
        r.need(self.bundle['source_files'].get('tools/civ13-provenance/robust-auth.patch') == a['build_contract']['robust_transform_sha256'], 'Robust transform differs')
        r.need(r.sha(encoded(r.CVARS)) == a['profile_sha256'], 'profile seal differs')
        self.a = json.loads(json.dumps(a))
        self.anchors = r.anchors_for(self.a, self.inputs)
        self.token = r.sha(encoded(a))
        r.need(self.fx.clock() < self.work_end and self.fx.utc() < a['expires_utc'], 'expired before claim')
        # Shared claim_dir must preexist as a private job/allocator-owned dir.
        # O_EXCL single-use key is independent of output root.
        self.fx.claim(self.claim_dir+'/'+relative(a['allocation_id'])+'.claim', encoded({'admission':self.token,'root':self.root}))
        self.dirs = set()
        # mkdir is postponed to setup so failed partial creation reaches cleanup.
        return self.token

    def _owned(self, token): r.need(token == self.token and token is not None, 'ownership token differs')

    def _base(self, deadline):
        self._check(deadline)
        b = self.bundle
        self._manifest(b['source_root'], b['source_files'], deadline)
        self._manifest(b['sdk_root'], b['sdk_files'], deadline)
        for p in getattr(self, 'copied_sources', []):
            self._check(deadline)
            r.need(r.sha(self.fx.read(self._path('build/'+p))) == b['source_files'][p], 'effective build source differs')
        if self.installed:
            self._manifest(self._path('package'), b['package_files'], deadline)
            r.need(r.sha(self.fx.read(self._path('source-built-package.json'))) == self.a['archive_sha256'], 'source-built archive differs')
        return dict(self.anchors)

    @staticmethod
    def _build_diagnostics(streams):
        # Admit only the standard zero-count summary lines. Keep the raw streams
        # in evidence and reject every real warning/error/unimplemented message.
        return '\n'.join(line for stream in streams for line in stream.splitlines()
                         if line.strip() not in ('0 Warning(s)', '0 Error(s)'))

    def _seals(self, case, deadline, outputs=True):
        result = self._base(deadline)
        files = self.stages[case]
        for p, raw in files.items():
            self._check(deadline)
            r.need(self.fx.read(self._path('cases/'+case+'/'+p)) == raw, 'staged source/config changed')
        result.update({'stage:'+p:r.sha(raw) for p,raw in files.items()})
        if case in self.resultbytes or (self.current == case and getattr(self,'runtime_config',False)):
            r.need(self.fx.read(self._path('cases/'+case+'/server.toml')) == b'', 'effective config file changed')
        if case in self.resultbytes:
            r.need(self.fx.read(self._path('cases/'+case+'/result.txt')) == self.resultbytes[case], 'result changed after exit')
            r.need(self.fx.read(self._path('cases/'+case+'/store-startup.go')) == b'EXTRACTION_STORE_GO_V2\n', 'readiness token changed')
        if outputs and case in self.compiled:
            for p, raw in self.compiled[case].items():
                self._check(deadline)
                r.need(self.fx.read(self._path('cases/'+case+'/'+p)) == raw, 'compiled JSON/resources changed')
            result.update({'artifact:'+p:r.sha(raw) for p,raw in self.compiled[case].items()})
        return result

    def _observe(self, owned, phase, deadline):
        self._check(deadline)
        members = self.fx.members(owned)
        r.need(len(members)<=256, 'owned process count bound')
        names = self.fx.files(self.root, deadline)
        sizes = self.fx.sizes(self.root,names)
        sockets = self.fx.sockets(members)
        r.need(len(sockets)<=128, 'owned socket count bound')
        unexpected = False; clients = 0; outbound = 0
        for s in sockets:
            # Only IPv4 127.0.0.1 UDP19567 and Topic TCP LISTEN ephemeral.
            local, port = s['local'].split(':')
            allowed = (phase == 'runtime' and local == '0100007F' and
                ((s['proto'] == 'udp' and int(port,16) == 19567) or
                 (s['proto'] == 'tcp' and s['state'] == '0A' and int(port,16) != 0)))
            unexpected |= (not allowed if phase != 'setup' else s['proto'].startswith('tcp') and s['state'] == '0A')
            clients += int(phase == 'runtime' and s['proto'].startswith('tcp') and s['state'] != '0A')
            outbound += int(int(s['remote'].replace(':',''),16) != 0)
        tcp = [s for s in sockets if s['proto']=='tcp' and s['state']=='0A']
        udp = [s for s in sockets if s['proto']=='udp']
        if phase == 'runtime': unexpected |= len(tcp)>1 or len(udp)>1
        runtime = phase == 'runtime'
        # Runtime bytes are only its case, not source-build workspace contents.
        if runtime:
            prefix = 'cases/'+self.current+'/'
            selected = [(p,n) for p,n in zip(names,sizes) if p.startswith(prefix)]
        else: selected = list(zip(names,sizes))
        sample = {'owned':all(int(m['birth']) >= int(owned.birth) for m in members),
                  'clients':clients, 'outbound':outbound, 'unexpected_listener':unexpected,
                  'bytes':sum(n for p,n in selected), 'files':len(selected),
                  'depth':max((len(PurePosixPath(p).parts) for p,n in selected), default=0),
                  'rss':sum(m['rss'] for m in members), 'sockets':sockets,
                  'listeners_ready':len(tcp)==1 and len(udp)==1,'monitor_epoch':owned.label}
        return sample

    def _queries(self, nonce, expected):
        commands=[]
        for index,name in enumerate(expected):
            commands.extend(['echo ODREAD_'+nonce+'_'+str(index)+'_BEGIN',
                             'cvar '+name, 'echo ODREAD_'+nonce+'_'+str(index)+'_END'])
        return ('\n'.join(commands)+'\n').encode('ascii')

    def _readback(self, stdout, nonce, expected=None):
        expected = r.CVARS if expected is None else expected
        r.need(len(stdout) <= 1024**2, 'console output bound')
        text=stdout.decode('utf-8',errors='strict')
        r.need('Unknown command' not in text and not r.DIAGNOSTIC.search(text), 'console diagnostic')
        lines=text.splitlines()
        values={}
        for index,(key,wanted) in enumerate(expected.items()):
            prefix='ODREAD_'+nonce+'_'+str(index)
            begins=[i for i,line in enumerate(lines) if line==prefix+'_BEGIN']
            ends=[i for i,line in enumerate(lines) if line==prefix+'_END']
            r.need(len(begins)<=1 and len(ends)<=1, 'ambiguous readback frame')
            if not ends: continue
            r.need(len(begins)==1 and ends[0]==begins[0]+2, 'malformed readback frame')
            value=lines[begins[0]+1]
            r.need(value==str(wanted), 'effective startup configuration differs: '+key)
            values[key]=wanted
        return values if len(values)==len(expected) else None

    def _command(self, argv, cwd, phase, case, deadline, guard, boundary, seals):
        self._check(deadline)
        boundary('launch', seals())
        self._check(deadline)
        owner = Owned(str(len(self.groups)))
        owner.console = phase == 'runtime'
        self.groups.append(owner)  # registered BEFORE partial creation
        logs = self._path('logs/'+owner.label)
        self._parents('logs/'+owner.label+'.stdout')
        env = {'PATH':self.bundle['sdk_root']+':/usr/bin:/bin', 'HOME':self._path('home'),
               'DOTNET_ROOT':self.bundle['sdk_root'], 'DOTNET_CLI_TELEMETRY_OPTOUT':'1',
               'DOTNET_SKIP_FIRST_TIME_EXPERIENCE':'1', 'DOTNET_CLI_DO_NOT_USE_MSBUILD_SERVER':'1',
               'MSBUILDDISABLENODEREUSE':'1', 'LANG':'C.UTF-8',
               'DOTNET_CLI_HOME':self._path('home'),
               'NUGET_PACKAGES':self._path('home/nuget'),
               'DOTNET_MULTILEVEL_LOOKUP':'0','GIT_CONFIG_NOSYSTEM':'1',
               'GIT_TERMINAL_PROMPT':'0','GIT_ASKPASS':'/bin/false'}
        self.fx.launch(owner, argv, cwd, env, logs, lambda: self._check(deadline))
        self._check(deadline)  # retain ownership on slow creation return
        started=self.fx.clock()
        nonce=r.sha((self.token+':'+str(case)).encode())[:24]
        verified=False
        heartbeat=started
        wanted=dict(r.CVARS, **{'opendream.json_path':self._path('cases/'+case+'/probe.json')}) if owner.console else {}
        if owner.console:
            self._check(deadline)
            self.fx.stdin_write(owner,self._queries(nonce,wanted))
        observations = 0
        interval = self.a['resource_envelope']['sample_interval_seconds']
        next_sample = self.fx.clock() if self.last_observation is None else max(self.fx.clock(),self.last_observation+interval)
        while True:
            self._check(deadline)
            now = self.fx.clock()
            r.need(now <= next_sample+interval*0.5, 'late monitor cadence')
            if now < next_sample:
                self.fx.wait(min(next_sample-now, deadline-now)); continue
            sample=self._observe(owner, phase, deadline)
            r.need(self.fx.clock() <= next_sample+interval*0.5, 'late monitor cadence')
            if owner.console:
                # Exactly one initial read-only query batch. Heartbeats are echo
                # only, keep redirected ReadLineAsync's 2s timeout from expiring.
                actual=self._readback(self.fx.read(logs+'.stdout'),nonce,wanted)
                r.need(self.fx.clock() <= next_sample+interval*0.5, 'late readback cadence')
                if not verified:
                    r.need(self.fx.clock() < min(deadline,started+8), 'startup readback deadline')
                    sample['startup_pending']=actual is None or not sample['listeners_ready']
                    sample['effective_cvars']=None if sample['startup_pending'] else {k:actual[k] for k in r.CVARS}
                else:
                    r.need(actual==wanted, 'effective snapshot lost')
                    sample['effective_cvars']={k:actual[k] for k in r.CVARS}
                if self.fx.clock()-heartbeat >= 1:
                    self._check(deadline)
                    self.fx.stdin_write(owner,('echo ODHEART_'+nonce+'\n').encode('ascii'))
                    heartbeat=self.fx.clock()
            guard(sample); observations += 1
            r.need(len(self.observations)<10000, 'observation retention bound')
            self.observations.append(dict(sample,at=self.fx.clock(),phase=phase,owner=owner.label))
            if owner.console and not verified and not sample.get('startup_pending'):
                self._check(deadline)
                self._write('cases/'+case+'/store-startup.go',b'EXTRACTION_STORE_GO_V2\n',deadline)
                verified=True
            self.last_observation = self.fx.clock()
            code = self.fx.poll(owner)
            if code is not None:
                r.need(not self.fx.members(owner), 'owned descendants survive exit')
                r.need(not owner.console or verified, 'startup readback incomplete at exit')
                break
            next_sample += interval  # never catch up with a burst
        self.fx.close_logs(owner)
        streams = [self.fx.read(logs+s).decode('utf-8', errors='strict') for s in ('.stdout','.stderr')]
        r.need(sum(len(s.encode()) for s in streams) <= 1024**2, 'retained logs too large')
        r.need(code == 0, 'process exit failure')
        diagnostic_text = self._build_diagnostics(streams) if phase == 'setup' else '\n'.join(streams)
        r.need(not r.DIAGNOSTIC.search(diagnostic_text), 'process diagnostic')
        self._check(deadline)
        boundary('final', seals())
        return {'exited':True,'descendants_empty':True,'exit':code,
                'observations':observations,'streams':streams,'startup_verified':verified}

    def setup(self, a, token, deadline, guard, boundary):
        self._owned(token); self.installed = False
        self._check(deadline)
        self.fx.mkdir(self.root)
        for directory in ('home','logs','build','package','cases'):
            self.fx.mkdir(self._path(directory)); self.dirs.add(directory)
        # Offline-prepared source closure includes recursive submodules and the
        # reviewed Robust transform. Frozen source pins, not Git metadata alone.
        b = self.bundle
        r.need(b.get('source_preparation') == 'offline-recursive-commit-export-with-declared-robust-patch', 'source preparation unresolved')
        self._base(deadline)
        self.copied_sources = []
        for p in sorted(b['source_files']):
            self._check(deadline); boundary('copy', self._base(deadline))
            self._write('build/'+p, self.fx.read(b['source_root']+'/'+p), deadline)
            self.copied_sources.append(p)
        dotnet = b['sdk_root']+'/dotnet'
        recipes = [
            [dotnet,'--version'],
            [dotnet,'restore','OpenDream.slnx','--locked-mode','--disable-parallel'],
            [dotnet,'build','OpenDreamPackageTool','-c','Release','--no-restore','--disable-build-servers'],
            [dotnet,'run','--project','OpenDreamPackageTool','--no-build','-c','Release','--',
             '--server','--configuration','Release','--platform','linux-x64','--output','out-server'],
            [dotnet,'publish','DMCompiler','-c','Release','--no-restore','--disable-build-servers','-o','out-compiler']]
        r.need(r.sha(encoded(recipes)) == a['build_contract']['commands_sha256'], 'build recipe differs')
        for index, argv in enumerate(recipes):
            report = self._command(argv,self._path('build'),'setup',None,deadline,guard,boundary,lambda:self._base(deadline))
            if index == 0: r.need(''.join(report['streams']).strip() == '10.0.401', 'actual SDK differs')
        wrapper = {'server/OpenDreamServer'+suffix:'bin/Content.Server/OpenDreamServer'+suffix
                   for suffix in ('.dll','.deps.json','.runtimeconfig.json')}
        r.need(all(b['package_origins'].get(p)==origin for p,origin in wrapper.items()), 'OpenDream wrapper origins unresolved')
        expected_origins={p:('out-compiler/'+p[len('compiler/'):] if p.startswith('compiler/') else
                            'out-server/OpenDreamServer_linux-x64/'+p[len('server/'):])
                          for p in b['package_files'] if p not in wrapper}
        expected_origins.update(wrapper)
        r.need(b['package_origins']==expected_origins, 'package origins differ')
        for prefix,output in (('compiler/','out-compiler'),('server/','out-server/OpenDreamServer_linux-x64')):
            expected=sorted(p[len(prefix):] for p in b['package_files'] if p.startswith(prefix) and p not in wrapper)
            r.need(self.fx.files(self._path('build/'+output),deadline)==expected, 'incomplete packager/publish closure')
        # Predictive pins must be admitted separately; never derive accepted
        # expected package hashes from whatever this build happened to produce.
        for p,digest in b['package_files'].items():
            source = b['package_origins'][p]
            relative(source); self._check(deadline)
            raw = self.fx.read(self._path('build/'+source))
            r.need(r.sha(raw) == digest, 'built package differs')
            boundary('copy', self._base(deadline)); self._write('package/'+p,raw,deadline)
        manifest = encoded(b['package_files'])
        # Honest deterministic source-built package container, not a downloaded
        # release tarball. Per-file bytes/pins are retained separately.
        archive = encoded({'profile':'independent-source-build', 'engine':r.ENGINE,
                           'files':{p:self.fx.read(self._path('package/'+p)).hex() for p in b['package_files']}})
        self._write('source-built-package.json',archive,deadline)
        r.need(r.sha(manifest) == a['installed_manifest_sha256'], 'installed manifest differs')
        r.need(b['package_files']['compiler/DMCompiler.dll'] == a['compiler_sha256'] and
               b['package_files']['server/OpenDreamServer.dll'] == a['runtime_sha256'], 'package entry seals differ')
        self.installed = True
        boundary('final', self._base(deadline))
        return dict(a, exited=True, descendants_empty=True)

    def vacant(self, token, port):
        self._owned(token); return self.fx.vacant(port)

    def step(self, phase, case, files, token, deadline, guard, boundary):
        self._owned(token); self.current = case
        self.runtime_config = phase == 'runtime'
        self.last_observation = None
        if phase == 'compile':
            self.fx.mkdir(self._path('cases/'+case)); self.dirs.add('cases/'+case)
            self.stages[case] = dict(files)
            for p,raw in files.items():
                self._check(deadline); boundary('copy', self._base(deadline))
                self._write('cases/'+case+'/'+p,raw,deadline)
        cwd = self._path('cases/'+case)
        dotnet = self.bundle['sdk_root']+'/dotnet'
        if phase == 'compile':
            argv = [dotnet,self._path('package/compiler/DMCompiler.dll'),'--version=516.1681','probe.dme']
        else:
            # Fixed argv only. It remains insufficient as effective-CVar proof.
            existing=self.fx.files(cwd,deadline)
            r.need('result.txt' not in existing and 'store-startup.go' not in existing, 'preexisting result/readiness token')
            self._write('cases/'+case+'/server.toml',b'',deadline)
            self.fx.mkdir(cwd+'/data')
            argv = [dotnet,self._path('package/server/OpenDreamServer.dll'),'--config-file',cwd+'/server.toml','--data-dir',cwd+'/data']
            for k,v in dict(r.CVARS, **{'opendream.json_path':cwd+'/probe.json'}).items():
                argv.extend(['--cvar',k+'='+str(v).lower()])
            r.need(self.fx.vacant(19567), 'loopback port occupied at launch')
        process_cwd = self._path('package/server') if phase == 'runtime' else cwd
        report = self._command(argv,process_cwd,phase,case,deadline,guard,boundary,
                               lambda:self._seals(case,deadline))
        if phase == 'runtime':
            report['result'] = self.fx.read(cwd+'/result.txt')
            self.resultbytes[case]=report['result']
        return report

    def artifacts(self, token, case):
        self._owned(token)
        cwd = self._path('cases/'+case)
        raw = self.fx.read(cwd+'/probe.json')
        document = json.loads(raw)
        r.need(isinstance(document,dict), 'compiled JSON type')
        resources = document.get('Resources', [])
        r.need(isinstance(resources,list) and len(resources) <= 10000 and
               all(isinstance(p,str) for p in resources), 'compiled resource closure')
        names = ['probe.json']+resources
        interface = document.get('Interface')
        if interface is not None: names.append(interface)
        r.need(len(names) == len(set(names)), 'duplicate compiled resource')
        result = {relative(p):self.fx.read(cwd+'/'+relative(p)) for p in names}
        self.compiled[case] = dict(result)
        return result

    def seals(self, token, case):
        self._owned(token); return self._seals(case,self.work_end)

    def final_seals(self, token):
        self._owned(token)
        for case in r.CASES: self._seals(case,self.work_end)
        return self._base(self.work_end)

    def cleanup(self, token, deadline):
        self._owned(token)
        failures = []
        # Attempt every group even if an earlier signal/observation fails.
        for group in self.groups:
            try:
                self.fx.signal(group,'SIGKILL')
            except BaseException as error: failures.append(str(error)[:160])
        while self.fx.clock() < deadline:
            alive = False
            for group in self.groups:
                try:
                    if group.process is not None and group.pid:
                        self.fx.poll(group)
                    alive |= bool(self.fx.members(group))
                except BaseException as error:
                    failures.append(str(error)[:160]); alive = True
            if not alive: break
            self.fx.wait(min(0.1,deadline-self.fx.clock()))
        for group in self.groups:
            try:
                r.need(not self.fx.members(group),'surviving owned session')
                self.fx.close_logs(group)
            except BaseException as error: failures.append(str(error)[:160])
        self.cleanup_errors = failures[:4]
        return not failures and self.fx.clock() <= deadline

    def retain(self, token, record):
        self._owned(token)
        receipt = dict(record, admission_sha256=token, profile='independent-source-build',
                       cleanup_errors=getattr(self,'cleanup_errors',[]),
                       observations=self.observations,
                       groups=[{'label':g.label,'pid':g.pid,'birth':g.birth} for g in self.groups])
        # Separate allocator-owned directory survives failed output mkdir/cleanup.
        self.fx.claim(self.claim_dir+'/'+self.a['allocation_id']+'.receipt',encoded(receipt))
