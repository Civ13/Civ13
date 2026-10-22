"""Actual UbuntuBackend boundaries with ALL effects injected into memory.

No PosixEffects method is called. No OS/API/process/network/native invocation.
"""
import copy
import json
import unittest
from unittest.mock import patch

import backend as b
import run as r
import test_run as t


class CaseOutputEnvelopeTests(unittest.TestCase):
    def observation(self, phase, case_size=1, workspace_size=200*1024**2):
        fx, a, data, backend = fixture()
        backend.reserve(a)
        backend.current = 'active'
        fx.mem['/job/sdk.tar.gz'] = b'archive size injected'
        fx.mem['/job/cases/other/result.txt'] = b'other case size injected'
        fx.mem['/job/cases/active/probe.json'] = b'case size injected'
        original = fx.sizes
        def sizes(root, names):
            result = original(root, names)
            for index,name in enumerate(names):
                if name == 'sdk.tar.gz': result[index] = workspace_size
                elif name == 'cases/active/probe.json': result[index] = case_size
                elif name == 'cases/other/result.txt': result[index] = 200*1024**2
            return result
        fx.sizes = sizes
        return backend._observe(b.Owned('injected-only'), phase, backend.work_end), a

    def test_compile_and_runtime_use_active_case_and_reject_its_oversize(self):
        for phase in ('compile', 'runtime'):
            with self.subTest(phase=phase):
                sample, a = self.observation(phase)
                self.assertEqual((sample['bytes'], sample['files'], sample['depth']), (1, 1, 3))
                r.observe(sample, a)
                sample, a = self.observation(phase, case_size=128*1024**2+1)
                with self.assertRaisesRegex(r.Rejected, 'output threshold'): r.observe(sample, a)

    def test_workspace_cap_remains_enforced_outside_active_case(self):
        for phase in ('compile', 'runtime'):
            with self.subTest(phase=phase), self.assertRaisesRegex(r.Rejected, 'workspace output threshold'):
                self.observation(phase, workspace_size=8*1024**3+1)


class FakeEffects:
    def __init__(self):
        self.now = 0; self.wall = 1000
        self.mem = {}; self.dirs = set(); self.events = []; self.claims = set()
        self.active = {}; self.polls = {}; self.fault = None; self.starts = 0
        self.signals = []; self.kill_failure = None
        self.logroots={}; self.console_pids=set(); self.stdin=[]
        self.jsonpaths={}
    def clock(self): return self.now
    def utc(self): return self.wall
    def wait(self, seconds):
        self.now += seconds
        if self.fault == 'late': self.now += 1
    def capabilities(self):
        if self.fault == 'capability': raise r.Rejected('missing effective readback')
    def machine(self): return {'runner_memory_bytes':8*1024**3,'runner_cpus':2}
    def claim(self,path,data):
        if path in self.claims: raise r.Rejected('claim already consumed')
        self.claims.add(path); self.mem[path]=data; self.events.append(('claim',path))
    def mkdir(self,path):
        if path in self.dirs: raise r.Rejected('existing dir')
        self.dirs.add(path); self.events.append(('mkdir',path))
    def read(self,path):
        if path not in self.mem: raise r.Rejected('missing '+path)
        return self.mem[path]
    def write(self,path,data):
        if path in self.mem: raise r.Rejected('existing file')
        self.mem[path]=data
        if self.fault == 'stage-timeout' and path.endswith('/probe.dme'): self.now=2370
    def files(self,root,deadline):
        if self.fault == 'hash-timeout' and root == '/source': self.now=2370
        return sorted(p[len(root)+1:] for p in self.mem if p.startswith(root+'/'))
    def sizes(self,root,names): return [len(self.mem[root+'/'+p]) for p in names]
    def launch(self,owned,argv,cwd,env,logroot,creation_guard):
        creation_guard()
        self.starts += 1; self.events.append(('launch',tuple(argv)))
        owned.pid=self.starts; owned.birth='1'; owned.process=object()
        self.active[owned.pid]=True; self.polls[owned.pid]=0
        self.logroots[owned.pid]=logroot
        if owned.console: self.console_pids.add(owned.pid)
        if self.fault == 'partial' and self.starts == 2:
            raise r.Rejected('primary partial launch')
        self.mem[logroot+'.stdout']=b'10.0.401\n' if argv[-1]=='--version' else b''
        self.mem[logroot+'.stderr']=b''
        if 'publish' in argv:
            for p,raw in self.outputs.items(): self.mem['/job/build/'+p]=raw
        if 'probe.dme' in argv:
            self.mem[cwd+'/probe.json']=b'{"Resources":[]}'
            if self.fault == 'compile-timeout': self.now += 60
        if '--config-file' in argv:
            casepath=argv[argv.index('--config-file')+1].rsplit('/',1)[0]
            case=casepath.rsplit('/',1)[-1]
            self.jsonpaths[owned.pid]=casepath+'/probe.json'
            marker='FAIL: 2 journal assertions' if case.endswith('old-loops') else r.PASS
            self.mem[casepath+'/result.txt']=(marker+'\n').encode()
            if case.endswith('old-loops'):
                prefix='scalar account root rejected ' if case.startswith('roots') else 'scalar equipment node rejected '
                self.mem[logroot+'.stdout']=('FAIL: '+prefix+'malformed\nFAIL: '+prefix+'17\n').encode()
    def poll(self,owned):
        self.polls[owned.pid]+=1
        if self.polls[owned.pid] >= 2: self.active[owned.pid]=False; return 0
        return None
    def members(self,owned):
        return [{'pid':owned.pid,'birth':'1','rss':100,'sid':owned.pid}] if self.active.get(owned.pid) else []
    def sockets(self,members):
        if self.fault == 'listener': return [{'proto':'tcp','local':'00000000:1234','remote':'00000000:0000','state':'0A'}]
        if members and members[0]['pid'] in self.console_pids and self.fault != 'no-listeners':
            return [{'proto':'tcp','local':'0100007F:8888','remote':'00000000:0000','state':'0A'},
                    {'proto':'udp','local':'0100007F:4C6F','remote':'00000000:0000','state':'07'}]
        return []
    def stdin_write(self,owned,raw):
        self.stdin.append(raw)
        if self.fault == 'query-write': raise r.Rejected('console write failed')
        if self.fault == 'missing-readback': return
        commands=raw.decode().splitlines(); output=[]
        for command in commands:
            if command.startswith('echo '): output.append(command[5:])
            elif command.startswith('cvar '):
                key=command.split()[1]
                value=self.jsonpaths[owned.pid] if key=='opendream.json_path' else r.CVARS[key]
                if self.fault == 'config' and key=='auth.mode': value=0
                output.append(str(value))
            else: raise AssertionError('unallowlisted command')
        if self.fault == 'duplicate-frame': output+=output
        self.mem[self.logroots[owned.pid]+'.stdout']+=('\n'.join(output)+'\n').encode()
    def vacant(self,port):
        if self.fault == 'coherent-package':
            self.mem['/job/package/compiler/DMCompiler.dll']=b'replacement'
            self.mem['/job/source-built-package.json']=b'{"files":"replacement"}'
        if self.fault == 'compiled':
            for p in list(self.mem):
                if p.endswith('/probe.json'): self.mem[p]=b'{"Resources":[],"changed":true}'
        return self.fault != 'busy'
    def signal(self,owned,sig):
        self.signals.append(owned.pid)
        if owned.pid == self.kill_failure: raise r.Rejected('secondary kill failure')
        self.active[owned.pid]=False
    def close_logs(self,owned): pass


def fixture():
    fx=FakeEffects(); a=t.admission(); data=t.inputs()
    src={'OpenDream.slnx':b'inert pinned source', 'tools/civ13-provenance/robust-auth.patch':b'reviewed transform'}
    sdk={'dotnet':b'inert SDK','sdk/10.0.401/identity':b'10.0.401'}
    package={'compiler/DMCompiler.dll':b'compiler', 'server/OpenDreamServer.dll':b'OpenDream entry',
             'server/Robust.Server.dll':b'Robust loader','server/Resources/manifest.yml':b'resources',
             'server/OpenDreamServer.deps.json':b'deps','server/OpenDreamServer.runtimeconfig.json':b'runtimeconfig'}
    origins={p:('out-compiler/'+p[len('compiler/'):] if p.startswith('compiler/') else 'out-server/OpenDreamServer_linux-x64/'+p[len('server/'):]) for p in package}
    for suffix in ('.dll','.deps.json','.runtimeconfig.json'):
        origins['server/OpenDreamServer'+suffix]='bin/Content.Server/OpenDreamServer'+suffix
    fx.outputs={origins[p]:raw for p,raw in package.items()}
    for prefix,files in (('/source',src),('/sdk',sdk)):
        fx.mem.update({prefix+'/'+p:raw for p,raw in files.items()})
    bundle={'source_root':'/source','sdk_root':'/sdk','sdk_version':'10.0.401',
            'source_preparation':'offline-recursive-commit-export-with-declared-robust-patch',
            'source_identity':{'engine':r.ENGINE,'tree':r.ENGINE_TREE,'robust':r.ROBUST},
            'source_files':{p:r.sha(v) for p,v in src.items()},
            'sdk_files':{p:r.sha(v) for p,v in sdk.items()},
            'package_files':{p:r.sha(v) for p,v in package.items()},'package_origins':origins}
    dotnet='/sdk/dotnet'
    recipes=[[dotnet,'--version'],[dotnet,'restore','OpenDream.slnx','--locked-mode','--disable-parallel'],
             [dotnet,'build','OpenDreamPackageTool','-c','Release','--no-restore','--disable-build-servers'],
             [dotnet,'run','--project','OpenDreamPackageTool','--no-build','-c','Release','--','--server','--configuration','Release','--platform','linux-x64','--output','out-server'],
             [dotnet,'publish','DMCompiler','-c','Release','--no-restore','--disable-build-servers','-o','out-compiler']]
    a['profile_sha256']=r.sha(b.encoded(r.CVARS))
    a['build_contract'].update(commands_sha256=r.sha(b.encoded(recipes)),
         backend_bundle_sha256=r.sha(b.encoded(bundle)),
         effective_source_manifest_sha256=r.sha(b.encoded(bundle['source_files'])),
         robust_transform_sha256=r.sha(src['tools/civ13-provenance/robust-auth.patch']))
    a['compiler_sha256']=r.sha(package['compiler/DMCompiler.dll'])
    a['runtime_sha256']=r.sha(package['server/OpenDreamServer.dll'])
    a['installed_manifest_sha256']=r.sha(b.encoded(bundle['package_files']))
    a['archive_sha256']=r.sha(b.encoded({'profile':'independent-source-build','engine':r.ENGINE,
                                      'files':{p:raw.hex() for p,raw in package.items()}}))
    backend=b.UbuntuBackend(fx,'/job','/claims',bundle,data,b'startup')
    return fx,a,data,backend


class BackendTests(unittest.TestCase):
    def perform(self,fault=None,expiry=3400,kill_failure=None):
        fx,a,data,backend=fixture(); a['expires_utc']=expiry
        fx.fault=fault; fx.kill_failure=kill_failure
        self.fx,self.backend=fx,backend
        with patch.object(r,'INPUTS',{p:r.sha(raw) for p,raw in data.items()}):
            return r.orchestrate(a,data,b'startup',backend,fx.clock,utc=fx.utc,
                                 admission_sha256=r.sha(b.encoded(a)))

    def test_actual_backend_exact_success_in_memory(self):
        self.assertEqual(len(self.perform()),5)
        self.assertEqual(self.fx.starts,15)  # five build + five compile/runtime pairs
        receipt=json.loads(self.fx.mem['/claims/TEST-ONLY.receipt'])
        self.assertEqual(receipt['status'],'PASS')
        self.assertFalse(any(self.fx.active.values()))

    def test_expired_admission_zero_effects(self):
        with self.assertRaises(r.Rejected): self.perform(expiry=1000)
        self.assertEqual(self.fx.events,[])

    def test_missing_real_capability_zero_effects(self):
        with self.assertRaisesRegex(r.Rejected,'readback'): self.perform('capability')
        self.assertEqual(self.fx.events,[])

    def test_hash_budget_exhaustion_zero_launch(self):
        with self.assertRaisesRegex(r.Rejected,'budget'): self.perform('hash-timeout')
        self.assertEqual(self.fx.starts,0)

    def test_staging_budget_exhaustion_no_compile(self):
        with self.assertRaises(r.Rejected): self.perform('stage-timeout')
        self.assertEqual(self.fx.starts,5)

    def test_compile_budget_exhaustion_no_runtime_launch(self):
        with self.assertRaisesRegex(r.Rejected,'budget'): self.perform('compile-timeout')
        self.assertEqual(self.fx.starts,6)

    def test_partial_launch_primary_and_cleanup_failures_retained(self):
        with self.assertRaisesRegex(r.Rejected,'primary partial launch'):
            self.perform('partial',kill_failure=1)
        self.assertIn(1,self.fx.signals); self.assertIn(2,self.fx.signals)
        receipt=json.loads(self.fx.mem['/claims/TEST-ONLY.receipt'])
        self.assertIn('primary partial launch',receipt['primary'])
        self.assertTrue(receipt['secondary'])
        self.assertIn('secondary kill failure',str(receipt['cleanup_errors']))

    def test_coherent_mutable_manifest_and_artifact_replacement(self):
        with self.assertRaisesRegex(r.Rejected,'seal differs'): self.perform('coherent-package')
        self.assertEqual(self.fx.starts,6)  # runtime has NOT launched

    def test_compiled_json_replacement_no_runtime_launch(self):
        with self.assertRaisesRegex(r.Rejected,'compiled JSON'): self.perform('compiled')
        self.assertEqual(self.fx.starts,6)

    def test_effective_config_not_argv_proof(self):
        with self.assertRaisesRegex(r.Rejected,'effective startup'): self.perform('config')
        self.assertEqual(self.fx.starts,7)

    def test_readiness_failure_never_releases_fixture(self):
        for fault in ('missing-readback','duplicate-frame','query-write','no-listeners'):
            with self.subTest(fault=fault):
                with self.assertRaises(r.Rejected): self.perform(fault)
                self.assertFalse(any(p.endswith('/store-startup.go') for p in self.fx.mem))
                self.assertEqual(self.fx.starts,7)

    def test_console_batch_is_only_echo_and_single_argument_cvar(self):
        self.perform()
        for raw in self.fx.stdin:
            self.assertLessEqual(len(raw),4096)
            for line in raw.decode().splitlines():
                parts=line.split()
                self.assertEqual(len(parts),2)
                self.assertIn(parts[0],('cvar','echo'))
                if parts[0]=='cvar': self.assertIn(parts[1],set(r.CVARS)|{'opendream.json_path'})

    def test_readback_frames_exact_types_values_and_no_duplicates(self):
        fx,a,data,backend=fixture(); nonce='testnonce'
        good=[]
        for i,(k,v) in enumerate(r.CVARS.items()):
            good += ['ODREAD_'+nonce+'_'+str(i)+'_BEGIN',str(v),'ODREAD_'+nonce+'_'+str(i)+'_END']
        raw=('\n'.join(good)+'\n').encode()
        self.assertEqual(backend._readback(raw,nonce),r.CVARS)
        self.assertIsNone(backend._readback(b'',nonce))
        for bad in (raw+raw,raw.replace(b'False',b'false',1),raw.replace(b'phase=store',b'other',1),b'Unknown command cvar\n'):
            with self.assertRaises(r.Rejected): backend._readback(bad,nonce)

    def test_listener_rejected(self):
        with self.assertRaisesRegex(r.Rejected,'listener'): self.perform('listener')

    def test_late_sampling_stops_no_burst_or_extra_query(self):
        with self.assertRaisesRegex(r.Rejected,'late monitor'): self.perform('late')
        self.assertEqual(self.fx.starts,1)
        self.assertEqual(self.fx.polls[1],2)  # first sample + cleanup reap only

    def test_one_use_claim_independent_of_output_root(self):
        fx,a,data,backend=fixture(); backend.reserve(a)
        second=b.UbuntuBackend(fx,'/different-output','/claims',backend.bundle,data,b'startup')
        with self.assertRaisesRegex(r.Rejected,'consumed'): second.reserve(a)
        self.assertEqual(fx.starts,0)

    def test_utc_rollback_cannot_extend_monotonic_deadline(self):
        fx,a,data,backend=fixture(); a['expires_utc']=1100
        backend.reserve(a); fx.wall=500; fx.now=70
        with self.assertRaisesRegex(r.Rejected,'budget'): backend._check(2400)

    def test_paths_fail_closed(self):
        for p in ('../save','/production','a/../b','x\\file','./a','a//b'):
            with self.assertRaises(r.Rejected): b.relative(p)

    def test_setup_zero_summaries_are_not_warning_suppression(self):
        text=b.UbuntuBackend._build_diagnostics(['    0 Warning(s)\n    0 Error(s)\nBuild succeeded.'])
        self.assertFalse(r.DIAGNOSTIC.search(text))
        for actual in ('1 Warning(s)','warning: unimplemented','error NU123: failed'):
            self.assertTrue(r.DIAGNOSTIC.search(b.UbuntuBackend._build_diagnostics([actual])))

    def test_bundle_change_rejects_before_claim(self):
        fx,a,data,backend=fixture(); backend.bundle['sdk_files']['dotnet']='0'*64
        with self.assertRaisesRegex(r.Rejected,'bundle differs'): backend.reserve(a)
        self.assertEqual(fx.events,[])

    def test_utc_expiry_before_claim_after_capability_work(self):
        fx,a,data,backend=fixture()
        fx.capabilities=lambda:setattr(fx,'wall',a['expires_utc'])
        with self.assertRaisesRegex(r.Rejected,'expired before claim'): backend.reserve(a)
        self.assertEqual(fx.events,[])

    def test_orchestration_anchors_utc_before_validation(self):
        fx,a,data,backend=fixture(); a['expires_utc']=1100
        original=r.admission_check
        def validate(packet):
            original(packet); fx.wall=500; fx.now=70
        with patch.object(r,'INPUTS',{p:r.sha(raw) for p,raw in data.items()}), patch.object(r,'admission_check',validate):
            with self.assertRaises(r.Rejected):
                r.orchestrate(a,data,b'startup',backend,fx.clock,utc=fx.utc,admission_sha256=r.sha(b.encoded(a)))
        self.assertEqual(fx.events,[])


if __name__=='__main__': unittest.main()
