"""Only memory effects, fake kernel seams and in-memory archives are exercised."""
import copy
import io
import json
import tarfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import backend as b
import entry
import hosted as h
import prepare
import run as r
import test_backend as tb
import test_run as tr
import v3_launch_control as old_launch


def fixture():
    base,a,data,old_backend=tb.fixture(); startup=old_backend.startup
    class Effects(tb.FakeEffects):
        def launch(self,owned,argv,cwd,env,logs,creation_guard):
            super().launch(owned,argv,cwd,env,logs,creation_guard)
            if '/driver/prepare.py' in argv:
                for prefix,files in [('source',source),('sdk',sdk)]:
                    self.mem.update({'/job/'+prefix+'/'+p:raw for p,raw in files.items()})
                prep={'engine':r.ENGINE,'tree':r.ENGINE_TREE,'robust':r.ROBUST,'game':r.GAME,
                  'sdk_url':prepare.SDK_URL,'sdk_sha512':prepare.SDK_SHA512,
                  'git_proof':[{'path':'','head':r.ENGINE,'tree':r.ENGINE_TREE}],
                  'source_files':{p:r.sha(v) for p,v in source.items()},
                  'sdk_files':{p:r.sha(v) for p,v in sdk.items()},
                  'robust_transform_sha256':r.sha(source['tools/civ13-provenance/robust-auth.patch']),
                  'commands':[{'path':'command-0.json','sha256':r.sha(b'inert command receipt')}],
                  'inputs':{p:raw.hex() for p,raw in data.items()}}
                self.mem['/job/receipts/command-0.json']=b'inert command receipt'
                if self.fault=='wrong-preparation': prep['engine']='0'*40
                self.mem['/job/preparation.json']=b.encoded(prep)
            if self.fault=='seal-expiry' and 'publish' in argv: self.wall=4000
    fx=Effects(); fx.outputs=base.outputs.copy()
    fx.outputs['obj/project.assets.json']=b'{"synthetic":true}'
    source={p[len('/source/'):]:raw for p,raw in base.mem.items() if p.startswith('/source/')}
    sdk={p[len('/sdk/'):]:raw for p,raw in base.mem.items() if p.startswith('/sdk/')}
    names=['entry.py','hosted.py','prepare.py','backend.py','run.py','startup.dm']
    driver={p:b'inert driver '+p.encode() for p in names}
    fx.mem.update({'/driver/'+p:raw for p,raw in driver.items()})
    route={k:copy.deepcopy(a[k]) for k in ('game','engine','engine_tree','robust','owner','allocation_id',
           'expires_utc','cvars','resource_envelope','executor_review_sha256','monitor_review','startup_sha256','profile_sha256')}
    route.update(enabled=True,allocated=True,run_id='123',run_attempt='1',
                 sdk_url=prepare.SDK_URL,sdk_sha512=prepare.SDK_SHA512,
                 driver_files={p:r.sha(raw) for p,raw in driver.items()})
    route['startup_sha256']=r.sha(startup)
    route['profile_sha256']=r.sha(b.encoded(r.CVARS))
    backend=h.SourceBuildBackend(fx,'/job','/claims','/driver','/python',startup)
    return fx,route,data,backend


class HostedTests(unittest.TestCase):
    def execute(self,fx,route,data,backend):
        with patch.object(r,'INPUTS',{p:r.sha(raw) for p,raw in data.items()}):
            return h.execute(route,r.sha(b.encoded(route)),backend,fx.clock,fx.utc)

    def test_one_build_then_all_five_cases_with_measured_seal(self):
        fx,a,data,backend=fixture()
        self.assertEqual(len(self.execute(fx,a,data,backend)),5)
        launches=[e[1] for e in fx.events if e[0]=='launch']
        self.assertEqual(sum('publish' in argv for argv in launches),1)
        self.assertEqual(sum('/driver/prepare.py' in argv for argv in launches),1)
        self.assertTrue(backend.bootstrap_done)
        self.assertTrue(backend.install_claimed)
        self.assertEqual(len(backend.receipts),4)
        self.assertIn('/claims/TEST-ONLY.bootstrap-receipt.json',fx.mem)

    def test_wrong_source_preparation_never_builds(self):
        fx,a,data,backend=fixture(); fx.fault='wrong-preparation'
        with self.assertRaisesRegex(r.Rejected,'preparation identity'): self.execute(fx,a,data,backend)
        self.assertFalse(any('publish' in e[1] for e in fx.events if e[0]=='launch'))
        self.assertIn('/claims/TEST-ONLY.bootstrap-receipt.json',fx.mem)

    def test_expiry_after_build_prevents_seal_and_runtime(self):
        fx,a,data,backend=fixture(); fx.fault='seal-expiry'
        with self.assertRaisesRegex(r.Rejected,'expiry'): self.execute(fx,a,data,backend)
        self.assertFalse(backend.bootstrap_done)
        self.assertNotIn('/job/receipts/03-package-seal.json',fx.mem)
        self.assertFalse(any('--config-file' in e[1] for e in fx.events if e[0]=='launch'))

    def test_package_replacement_after_first_seal_rejected_before_install(self):
        fx,a,data,backend=fixture()
        original=backend.reserve
        def mutate(admitted):
            fx.mem['/job/package/compiler/DMCompiler.dll']=b'replacement'
            return original(admitted)
        backend.reserve=mutate
        with self.assertRaisesRegex(r.Rejected,'seal differs'): self.execute(fx,a,data,backend)
        self.assertEqual(sum('publish' in e[1] for e in fx.events if e[0]=='launch'),1)

    def test_retained_measurement_replacement_rejected(self):
        fx,a,data,backend=fixture(); original=backend.bootstrap
        def mutate(deadline,guard):
            admitted=original(deadline,guard)
            backend.package_bytes['compiler/DMCompiler.dll']=b'changed'
            return admitted
        backend.bootstrap=mutate
        with self.assertRaisesRegex(r.Rejected,'package admission drift'): self.execute(fx,a,data,backend)

    def test_first_build_failure_has_no_seal_and_retains_primary(self):
        fx,a,data,backend=fixture(); fx.fault='partial'
        with self.assertRaisesRegex(r.Rejected,'primary partial launch'): self.execute(fx,a,data,backend)
        row=json.loads(fx.mem['/claims/TEST-ONLY.bootstrap-receipt.json'])
        self.assertIn('primary partial launch',row['primary'])
        self.assertFalse(backend.bootstrap_done)

    def test_no_predictive_hash_admission(self):
        fx,a,data,backend=fixture(); a['compiler_sha256']='1'*64
        with self.assertRaisesRegex(r.Rejected,'predictive'): self.execute(fx,a,data,backend)
        self.assertEqual(fx.starts,0)

    def test_unreliable_memory_admission_does_not_reject(self):
        fx,a,data,backend=fixture()
        fx.machine=lambda:{'runner_memory_bytes':0,'runner_cpus':4}
        self.assertEqual(len(self.execute(fx,a,data,backend)),5)

    def test_write_parent_preparation_expiry_blocks_actual_write(self):
        fx,a,data,backend=fixture()
        backend.a=a; backend.work_end=20; backend.dirs=set()
        backend._parents=lambda p:setattr(fx,'now',20)
        with self.assertRaisesRegex(r.Rejected,'budget'): backend._write('late/file',b'x',20)
        self.assertNotIn('/job/late/file',fx.mem)

    def test_entry_off_never_constructs_native_adapter(self):
        args=['--route-packet','/inert','--expected-route-sha256','0'*64,
              '--root','/job','--claim-dir','/claims']
        with patch.object(Path,'stat',return_value=SimpleNamespace(st_size=17)), patch.object(Path,'read_bytes',return_value=b'{"enabled":false}'):
            self.assertEqual(entry.main(args,effects_factory=lambda:self.fail('native adapter')),0)

    def test_entry_platform_rerun_is_rejected_before_native_adapter(self):
        fx,a,data,backend=fixture(); a.update(run_id='bind-current-run',run_attempt='1')
        env={'POLICY':b.encoded(a).decode(),'GITHUB_ACTIONS':'true','GITHUB_REPOSITORY':'Civ13/Civ13',
             'GITHUB_RUN_ID':'789','GITHUB_RUN_ATTEMPT':'2','RUNNER_OS':'Linux','RUNNER_ARCH':'X64'}
        args=['--route-json-env','POLICY','--expected-route-sha256',r.sha(b.encoded(a)),
              '--root','/job','--claim-dir','/claims']
        with self.assertRaisesRegex(r.Rejected,'rerun'):
            entry.main(args,effects_factory=lambda:self.fail('native adapter'),environ=env)

    def test_entry_binds_unknown_at_dispatch_run_id_to_frozen_policy(self):
        fx,a,data,backend=fixture(); a.update(run_id='bind-current-run',run_attempt='1')
        parent=r.sha(b.encoded(a)); calls=[]
        env={'POLICY':b.encoded(a).decode(),'GITHUB_ACTIONS':'true','GITHUB_REPOSITORY':'Civ13/Civ13',
             'GITHUB_RUN_ID':'789','GITHUB_RUN_ATTEMPT':'1','RUNNER_OS':'Linux','RUNNER_ARCH':'X64'}
        args=['--route-json-env','POLICY','--expected-route-sha256',parent,'--root','/job','--claim-dir','/claims']
        with patch.object(entry.time,'monotonic',side_effect=fx.clock),patch.object(entry.time,'time',side_effect=fx.utc), \
             patch.object(h,'SourceBuildBackend',return_value=backend),patch.object(h,'execute',side_effect=lambda *args,**kw:calls.append(args)):
            self.assertEqual(entry.main(args,effects_factory=lambda:fx,environ=env),0)
        self.assertEqual(calls[0][0]['run_id'],'789')
        self.assertEqual(calls[0][0]['parent_route_sha256'],parent)
        self.assertEqual(calls[0][1],r.sha(b.encoded(calls[0][0])))


class CreationTests(unittest.TestCase):
    def exercise(self,slow=False,post=False,old=False):
        events=[]; now=[0]
        class Effects(b.PosixEffects):
            def _safe(self,path): return path
            def _stat(self,pid): return {'birth':'10'}
        class FakePopen:
            def __init__(self,*args,**kwargs):
                events.append('create'); self.pid=100
                if post: now[0]=20
        def opened(*args,**kwargs):
            events.append('open')
            if slow and len(events)==2: now[0]=20
            return io.BytesIO()
        def guard(): r.need(now[0]<10,'creation expired')
        owned=b.Owned('actual-policy')
        with patch.object(b.subprocess,'Popen',FakePopen),patch('builtins.open',opened):
            try:
                if old: old_launch.launch_control(Effects(),owned,['inert'],'/inert',{},'/logs')
                else: Effects().launch(owned,['inert'],'/inert',{},'/logs',guard)
            except r.Rejected:
                if post: self.assertIn('create',events)
                else: self.assertNotIn('create',events)
                return events,owned
        if post: self.fail('missing fresh post-creation guard')
        return events,owned

    def test_actual_launch_slow_internal_open_never_creates_process(self):
        events,owner=self.exercise(slow=True)
        self.assertEqual(events,['open','open']); self.assertIsNone(owner.pid)

    def test_actual_launch_valid_creation_retains_identity(self):
        events,owner=self.exercise()
        self.assertEqual(events,['open','open','create']); self.assertEqual(owner.pid,100)
        self.assertEqual(owner.birth,'10')


    def test_frozen_v3_control_fails_same_no_late_creation_oracle(self):
        def no_late_creation(events): r.need('create' not in events,'late process created')
        old_events,_=self.exercise(slow=True,old=True)
        with self.assertRaisesRegex(r.Rejected,'late process created'): no_late_creation(old_events)
        events,_=self.exercise(slow=True)
        no_late_creation(events)

    def test_actual_launch_slow_return_keeps_identity_and_rejects(self):
        events,owner=self.exercise(post=True)
        self.assertIn('create',events); self.assertEqual(owner.pid,100)
        self.assertEqual(owner.birth,'10')


class ArchiveTests(unittest.TestCase):
    def test_setup_child_command_checks_after_internal_object_preparation(self):
        now=[0]; events=[]
        class FakePopen:
            def __new__(cls):
                now[0]=20; return object.__new__(cls)
            def __init__(self,*args,**kwargs): events.append('create')
        def fresh(): prepare.need(now[0]<10,'expired before setup creation')
        with patch.object(prepare.subprocess,'Popen',FakePopen):
            with self.assertRaisesRegex(ValueError,'expired before setup creation'):
                prepare.guarded_command(['inert'],'/inert',fresh,10)
        self.assertEqual(events,[])

    class Destination:
        def __init__(self,events,name=''): self.events=events; self.name=name
        def __truediv__(self,name): return type(self)(self.events,self.name+'/'+str(name))
        @property
        def parent(self): return type(self)(self.events,self.name.rsplit('/',1)[0])
        def mkdir(self,**kwargs): self.events.append(('mkdir',self.name))
        def open(self,mode): self.events.append(('open',self.name)); return io.BytesIO()
        def chmod(self,mode): self.events.append(('chmod',self.name,mode))

    def archive(self,name='dotnet',kind=tarfile.REGTYPE):
        raw=io.BytesIO()
        with tarfile.open(fileobj=raw,mode='w') as out:
            member=tarfile.TarInfo(name); member.type=kind
            member.size=1 if kind==tarfile.REGTYPE else 0; member.mode=0o777
            out.addfile(member,io.BytesIO(b'x') if member.size else None)
        raw.seek(0); return tarfile.open(fileobj=raw,mode='r|')

    def test_actual_extractor_rejects_traversal_and_links_without_file_open(self):
        for name,kind in [('../escape',tarfile.REGTYPE),('link',tarfile.SYMTYPE),('hard',tarfile.LNKTYPE)]:
            events=[]
            with self.subTest(name=name), self.archive(name,kind) as tar:
                with self.assertRaises(ValueError): prepare.extract(tar,self.Destination(events),lambda:None)
            self.assertFalse(any(row[0]=='open' for row in events))

    def test_actual_extractor_rechecks_after_slow_parent_before_file_creation(self):
        events=[]
        def fresh():
            if any(row[0]=='mkdir' for row in events): raise ValueError('expired after parent')
        with self.archive() as tar:
            with self.assertRaisesRegex(ValueError,'expired after parent'):
                prepare.extract(tar,self.Destination(events),fresh)
        self.assertFalse(any(row[0]=='open' for row in events))

    def test_actual_extractor_restricts_modes_and_writes_only_regular_file(self):
        events=[]
        with self.archive() as tar: prepare.extract(tar,self.Destination(events),lambda:None)
        self.assertIn(('open','/dotnet'),events)
        self.assertIn(('chmod','/dotnet',0o700),events)



if __name__=='__main__': unittest.main()
