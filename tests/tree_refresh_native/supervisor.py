"""Private hosted-VM Windows Job. Does not alter the frozen one-process backend.

Only current-pin dm/dd and the exact reviewed extracted DreamSeeker bytes enter.
All children are detached/suspended, assigned and retained before resume. The
sampled socket oracle permits only this fixture's IPv4 loopback port. This is
not a continuous network-denial claim and never runs on the user's desktop.
"""
import ast, ctypes, importlib.util, inspect, os, sys, time
from pathlib import Path
from protocol import LIMITS, digest, require
ROOT=Path(__file__).resolve().parents[2]

def facade():
    spec=importlib.util.spec_from_file_location('tree_existing_native',ROOT/'tests/human_subtile/run-diagonal.py')
    m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m.current_backend()

def socket_ok(row, port, daemon):
    if row.get('protocol')!='tcp' or row.get('address')!='127.0.0.1': return False
    if daemon and row.get('state')=='listen': return row['port']==port and row.get('remote_port')==0
    if row.get('remote_address')!='127.0.0.1': return False
    return row.get('port')==port if daemon else row.get('remote_port')==port

def derive_launch(source):
    import textwrap
    source=textwrap.dedent(source)
    anchor='from guard_config import digest, BINARIES'
    require(source.count(anchor)==1,'Launcher binary-boundary anchor drift')
    return source.replace(anchor,'BINARIES = self.tree_native_binary_hashes\n    from hashlib import sha256\n    digest = lambda p: sha256(Path(p).read_bytes()).hexdigest()',1)

class OwnedRun:
    def __init__(self, output, binary_hashes, wall=180, now=time.monotonic):
        self.b=facade();self.a=self.b.a;self.w=self.b.windows;self.o=self.b.owned
        self.output=Path(output);self.hashes=binary_hashes;self.wall=wall;self.now=now
        self.started=now();self.children=[];self.samples=[];self.port=None;self.finished=False
    def open(self):
        self.b.open(self.wall)
        limits=self.w.JobLimits();limits.basic.flags=0x230C;limits.basic.active=LIMITS['processes']
        limits.basic.job_time=int(self.wall*10_000_000);limits.process_memory=LIMITS['rss_bytes'];limits.job_memory=LIMITS['rss_bytes']
        self.a.check(self.a.k.SetInformationJobObject(self.a.job,9,ctypes.byref(limits),ctypes.sizeof(limits)))
    def launch(self, argv, cwd, name):
        require(len(self.children)<3 and self.now()-self.started<self.wall,'Owned launch/deadline limit')
        require(Path(argv[0]).name.lower() in self.hashes and digest(Path(argv[0]).read_bytes())==self.hashes[Path(argv[0]).name.lower()],'Reviewed executable identity changed')
        # Reuse exact retained/suspended launch implementation, changing only its
        # immutable binary allowlist boundary. Never mutate guard_config globals.
        source=derive_launch(inspect.getsource(type(self.a).launch))
        env=dict(vars(sys.modules[type(self.a).__module__]));exec(compile(source,'<source-bound native launch>','exec'),env)
        self.a.tree_native_binary_hashes=self.hashes
        child=env['launch'](self.a,list(map(str,argv)),Path(cwd),self.output,name)
        self.children.append((name,child));return child
    def poll(self):
        require(self.now()-self.started<self.wall,'Native wall deadline180seconds')
        acc=self.a.accounting();membership=self.o.query_members(self.a);known={p.pid for _,p in self.children}
        unexpected=set(membership['pids'])-known
        for pid in unexpected:self.b.captured.append(self.o.capture_unexpected(self.a,pid))
        require(not unexpected and acc.total==len(self.children) and acc.terminated==0,'Unretained/unexpected cumulative process or Job violation')
        watcher,free=self.b.resources();require(watcher<=LIMITS['watcher_bytes'] and free>=6*1024**3,'Watcher reserve/free-memory floor')
        resources=[];total_rss=0
        for name,p in self.children:
            exited=self.a.exited(p)
            if exited:
                resources.append(dict(name=name,pid=p.pid,exited=True));continue
            memory=self.w.Memory();memory.cb=ctypes.sizeof(memory);self.a.check(self.a.ps.GetProcessMemoryInfo(p.process,ctypes.byref(memory),memory.cb))
            total_rss+=memory.ws;sockets=self.a.sockets(p)
            require(self.port is not None or not sockets,'Socket before bound ready port witness')
            require(all(socket_ok(x,self.port,name=='daemon') for x in sockets),'Socket outside exact fixture loopback endpoints')
            require(self.a.memory(p.process)<=LIMITS['rss_bytes'],'Private memory ceiling')
            resources.append(dict(name=name,pid=p.pid,exited=False,rss=memory.ws,private=self.a.memory(p.process),cpu=self.a.times(p)[1],sockets=sockets))
        require(total_rss<=LIMITS['rss_bytes'],'Aggregate owned RSS ceiling1920MiB')
        self.samples.append(dict(elapsed=self.now()-self.started,total=acc.total,active=acc.active,rss=total_rss,resources=resources))
        require(len(self.samples)<=1900,'Supervisor sample bound')
        return resources
    def cleanup(self):
        result=self.b.cleanup(30);self.finished=True
        require(result['all_retained_exited'] and not result['errors'],'Retained owned exits not confirmed')
        require(result['total_assigned']==len(result['exits'])==len(self.children),'Cumulative exit accounting mismatch')
        return result
