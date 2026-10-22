"""V4 source-first setup over the reviewed backend; inert on import."""
import json
from pathlib import PurePosixPath

import backend as b
import run as r
import prepare


def recipes(dotnet):
    return [[dotnet,'--version'],
      [dotnet,'restore','OpenDream.slnx','--locked-mode','--disable-parallel'],
      [dotnet,'build','OpenDreamPackageTool','-c','Release','--no-restore','--disable-build-servers'],
      [dotnet,'run','--project','OpenDreamPackageTool','--no-build','-c','Release','--',
       '--server','--configuration','Release','--platform','linux-x64','--output','out-server'],
      [dotnet,'publish','DMCompiler','-c','Release','--no-restore','--disable-build-servers','-o','out-compiler']]


def check_route(a):
    r.need(a.get('enabled') is True and a.get('allocated') is True,'route OFF/unallocated')
    for key,want in [('game',r.GAME),('engine',r.ENGINE),('engine_tree',r.ENGINE_TREE),('robust',r.ROBUST),
                     ('sdk_url',prepare.SDK_URL),('sdk_sha512',prepare.SDK_SHA512)]:
        r.need(a.get(key)==want,'route identity differs: '+key)
    r.need(a.get('cvars')==r.CVARS,'profile differs')
    for key in ('owner','allocation_id','run_id','run_attempt'):
        r.need(isinstance(a.get(key),str) and a[key],'missing '+key)
    for key in ('executor_review_sha256','monitor_review','startup_sha256','profile_sha256'):
        r.need(isinstance(a.get(key),str) and r.re.fullmatch('[0-9a-f]{64}',a[key]),'missing digest '+key)
    r.need(type(a.get('expires_utc')) in (int,float) and 0<a['expires_utc']<float('inf'),'expiry required')
    env=a.get('resource_envelope',{})
    r.need(env.get('runner_class')=='standard-public-ubuntu' and
           type(env.get('runner_cpus')) is int and env['runner_cpus']>0 and
           type(env.get('sample_interval_seconds')) in (int,float) and
           0<env['sample_interval_seconds']<=.25,'resource envelope required')
    r.need(a.get('driver_files') and all(isinstance(v,str) and r.re.fullmatch('[0-9a-f]{64}',v)
           for v in a['driver_files'].values()),'driver file pins required')
    r.need(set(a['driver_files'])=={'entry.py','hosted.py','prepare.py','backend.py','run.py','startup.dm'},
           'driver closure differs')
    r.need(not any(a.get(k) for k in ('compiler_sha256','runtime_sha256','archive_sha256','installed_manifest_sha256')),
           'predictive output pins not accepted in source-first route')


class SourceBuildBackend(b.UbuntuBackend):
    """One build, then immutable measured package. No re-build in setup()."""
    def __init__(self,fx,root,claims,driver,python,startup):
        super().__init__(fx,root,claims,{'sdk_root':root+'/sdk'}, {},startup)
        self.driver=driver; self.python=python; self.bootstrap_done=False
        self.install_claimed=False; self.installed=False; self.preparing=True
        self.receipts=[]

    def _driver(self,deadline):
        for name,digest in self.route['driver_files'].items():
            b.relative(name); self._check(deadline)
            r.need(r.sha(self.fx.read(self.driver+'/'+name))==digest,'driver changed')
            self._check(deadline)

    def _base(self,deadline):
        self._check(deadline); self._driver(deadline)
        if self.preparing: return dict(self.anchors)
        return super()._base(deadline)

    def _receipt(self,label,data,deadline):
        self._check(deadline)
        row={'label':label,'previous_sha256':self.receipts[-1] if self.receipts else self.token,'data':data}
        raw=b.encoded(row)
        self._check(deadline); self.fx.claim(self._path('receipts/'+label+'.json'),raw)
        self._check(deadline)
        r.need(self.fx.read(self._path('receipts/'+label+'.json'))==raw,'receipt readback differs')
        self.receipts.append(r.sha(raw)); return self.receipts[-1]

    def begin(self,route,digest,entered,entered_utc):
        check_route(route); r.need(r.sha(b.encoded(route))==digest,'route digest differs')
        r.need(not self.seen,'single use'); self.seen=True
        self.route=json.loads(json.dumps(route)); self.a=self.route
        remaining=min(2190,route['expires_utc']-entered_utc)
        r.need(remaining>30,'expired before claim')
        self.end=entered+remaining; self.work_end=self.end-30
        self.anchors={'engine':r.ENGINE,'engine_tree':r.ENGINE_TREE,'robust':r.ROBUST,
                      'profile_sha256':r.sha(b.encoded(r.CVARS)),
                      'sdk_sha512':prepare.SDK_SHA512,'route_sha256':digest}
        r.need(self.anchors['profile_sha256']==route['profile_sha256'],'profile digest differs')
        r.need(r.sha(self.startup)==route['startup_sha256'],'startup differs')
        self._check(self.work_end); self.fx.capabilities(); self._check(self.work_end)
        self.machine=self.fx.machine(); self._check(self.work_end)
        r.need(self.machine['runner_cpus']>=route['resource_envelope']['runner_cpus'],'CPU capacity differs')
        # Explicit user override: available-memory admission is not a rejection.
        r.need(self.root.startswith('/') and self.root!='/' and self.claim_dir.startswith('/'),'absolute owned roots')
        self._driver(self.work_end)
        self.token=digest
        self._check(self.work_end)
        self.fx.claim(self.claim_dir+'/'+b.relative(route['allocation_id'])+'.claim',
                      b.encoded({'route':digest,'run_id':route['run_id'],'run_attempt':route['run_attempt'],'root':self.root}))
        self._check(self.work_end)

    def bootstrap(self,deadline,guard):
        self._check(deadline)
        self.fx.mkdir(self.root); self.dirs=set()
        for name in ('home','logs','build','package','cases','receipts'):
            self._check(deadline); self.fx.mkdir(self._path(name)); self.dirs.add(name)
        self._receipt('00-allocation',{'route':self.route,'machine':self.machine,'end':self.end},deadline)
        def boundary(kind,seals):
            self._check(deadline)
            r.need(seals==self.anchors,'bootstrap seals drift')
        argv=[self.python,'-B',self.driver+'/prepare.py','--root',self.root,
              '--deadline',str(deadline),'--expires',str(self.route['expires_utc'])]
        self._command(argv,self.root,'setup',None,deadline,guard,boundary,lambda:self._base(deadline))
        self._check(deadline)
        prep=json.loads(self.fx.read(self._path('preparation.json')))
        for key,want in [('engine',r.ENGINE),('tree',r.ENGINE_TREE),('robust',r.ROBUST),('game',r.GAME),
                         ('sdk_url',prepare.SDK_URL),('sdk_sha512',prepare.SDK_SHA512)]:
            r.need(prep.get(key)==want,'preparation identity differs')
        r.need(prep.get('git_proof') and prep['git_proof'][0]=={'path':'','head':r.ENGINE,'tree':r.ENGINE_TREE},
               'root Git proof differs')
        r.need(prep.get('commands'),'missing setup command receipts')
        for row in prep['commands']:
            self._check(deadline)
            r.need(r.sha(self.fx.read(self._path('receipts/'+b.relative(row['path']))))==row['sha256'],
                   'setup command receipt drift')
            self._check(deadline)
        self.inputs={p:bytes.fromhex(raw) for p,raw in prep['inputs'].items()}; r.verify_inputs(self.inputs)
        self.bundle={'source_root':self._path('source'),'sdk_root':self._path('sdk'),'sdk_version':'10.0.401',
                     'source_preparation':'offline-recursive-commit-export-with-declared-robust-patch',
                     'source_identity':{'engine':r.ENGINE,'tree':r.ENGINE_TREE,'robust':r.ROBUST},
                     'source_files':prep['source_files'],'sdk_files':prep['sdk_files']}
        r.need(self.bundle['source_files'].get('tools/civ13-provenance/robust-auth.patch')==prep['robust_transform_sha256'],
               'transform seal differs')
        self.preparing=False
        self._base(deadline)
        self._receipt('01-source-sdk',prep,deadline)
        for p in sorted(self.bundle['source_files']):
            self._check(deadline); raw=self.fx.read(self.bundle['source_root']+'/'+b.relative(p)); self._check(deadline)
            r.need(r.sha(raw)==self.bundle['source_files'][p],'source copy drift')
            self._write('build/'+p,raw,deadline); self.copied_sources.append(p)
        commands=recipes(self.bundle['sdk_root']+'/dotnet')
        for index,argv in enumerate(commands):
            report=self._command(argv,self._path('build'),'setup',None,deadline,guard,boundary,lambda:self._base(deadline))
            if index==0: r.need(''.join(report['streams']).strip()=='10.0.401','actual SDK differs')
        self._check(deadline)
        # One successful build's complete output closure, with actual origins.
        outputs={}; origins={}; measured={}
        for prefix,origin in [('compiler/','out-compiler/'),('server/','out-server/OpenDreamServer_linux-x64/')]:
            root=self._path('build/'+origin.rstrip('/'))
            names=self.fx.files(root,deadline); self._check(deadline)
            sizes=self.fx.sizes(root,names); self._check(deadline)
            r.need(len(names)==len(sizes),'package measurement count differs')
            for p,size in zip(names,sizes):
                target=prefix+b.relative(p)
                r.need(target not in origins,'duplicate package member')
                origins[target]=origin+p; measured[target]=size
        measurement=measure_outputs(measured)
        # Reject the complete serialized size before reading/hex-allocating output
        # bytes, and before any fixture compiler or server launch.
        for target,origin in origins.items():
            self._check(deadline); raw=self.fx.read(self._path('build/'+origin)); self._check(deadline)
            r.need(len(raw)==measured[target],'package changed after measurement')
            outputs[target]=raw
        # Every standard-library source in the pinned compiler source is required.
        for name in self.bundle['source_files']:
            if name.startswith('DMCompiler/DMStandard/'):
                target='compiler/'+name[len('DMCompiler/'):]
                r.need(target in outputs,'compiler standard closure missing')
                r.need(r.sha(outputs[target])==self.bundle['source_files'][name],'compiler standard source drift')
        pins=seal_outputs(outputs)
        # Retain dependency resolution receipts, not a claim that --locked-mode
        # invents lockfiles. Missing assets or a failed locked restore rejects.
        dependencies={}; resolutions={}
        for p in self.fx.files(self._path('build'),deadline):
            if p.endswith(('project.assets.json','packages.lock.json','nuget.config')):
                self._check(deadline); raw=self.fx.read(self._path('build/'+p)); self._check(deadline)
                dependencies[p]=r.sha(raw)
                if p.endswith('project.assets.json'): resolutions[p]=dependency_resolution(raw)
        r.need(resolutions,'missing dependency resolution receipt')
        required_projects={'DMCompiler.csproj','OpenDreamServer.csproj','Robust.Server.csproj','OpenDreamPackageTool.csproj'}
        r.need(required_projects.issubset({row['project'] for row in resolutions.values()}),'incomplete dependency project receipts')
        self.bundle.update(package_files={p:r.sha(raw) for p,raw in outputs.items()},package_origins=origins)
        self._receipt('02-build',{'commands':commands,'origins':origins,'dependency_files':dependencies,
                                'resolved_dependency_graphs':resolutions,
                                'output_measurement':measurement,
                                'restore_provenance':{'top_level_locked_mode_invoked':True,
                                  'nested_packager_implicit_restore':True,
                                  'complete_locked_dependency_closure_proven':False,
                                  'scope':'first-resolution package sealed once; transitive reproducibility not established',
                                  'later_build_or_restore':False},
                                'source_sdk_receipt':self.receipts[-1]},deadline)
        for p,raw in outputs.items(): self._write('package/'+p,raw,deadline)
        archive=b.encoded({'profile':'independent-source-build','engine':r.ENGINE,
                           'files':{p:raw.hex() for p,raw in sorted(outputs.items())}})
        self._write('source-built-package.json',archive,deadline)
        r.need(r.sha(archive)==pins['archive_sha256'],'container seal mismatch')
        admitted=dict(self.route,setup_mode='sealed-first-build',**pins)
        admitted['resource_envelope']=dict(self.route['resource_envelope'],runner_memory_bytes=1)
        admitted['build_contract']={'sdk':'10.0.401','configuration':'Release','platform':'linux-x64',
             'commands_sha256':r.sha(b.encoded(commands)),
             'effective_source_manifest_sha256':r.sha(b.encoded(self.bundle['source_files'])),
             'robust_transform_sha256':prep['robust_transform_sha256'],
             'backend_bundle_sha256':r.sha(b.encoded(self.bundle))}
        self.a=admitted; self.anchors=r.anchors_for(admitted,self.inputs); self.installed=True
        self._base(deadline)
        self.package_bytes=dict(outputs)
        self._receipt('03-package-seal',{'admission':admitted,'package_files':self.bundle['package_files']},deadline)
        self.bootstrap_done=True
        return admitted

    def reserve(self,a):
        r.need(self.bootstrap_done and not self.install_claimed and a==self.a,'unsealed/reused install')
        self._check(self.work_end); self.install_claimed=True
        return self.token

    def setup(self,a,token,deadline,guard,boundary):
        self._owned(token); self._check(deadline)
        # No build or process launch here: existing sealed first-build bytes only.
        self._base(deadline)
        r.need(seal_outputs(self.package_bytes)=={k:a[k] for k in OUTPUT_KEYS},'retained output seals differ')
        boundary('copy',dict(self.anchors)); self._check(deadline)
        guard({'owned':True,'clients':0,'outbound':0,'unexpected_listener':False,
               'bytes':0,'files':0,'depth':0,'rss':0,'monitor_epoch':'sealed-install'})
        boundary('final',self._base(deadline))
        return dict(a,exited=True,descendants_empty=True,prepared_install=True)


OUTPUT_KEYS=('archive_sha256','compiler_sha256','runtime_sha256','installed_manifest_sha256')


PUBLIC_FEEDS={'https://api.nuget.org/v3/index.json',
    'https://pkgs.dev.azure.com/dnceng/public/_packaging/dotnet-eng/nuget/v3/index.json'}


def dependency_resolution(raw):
    # Actual NuGet-generated identity claims, not a pre-existing lock baseline.
    import base64
    try:
        doc=json.loads(raw); restore=doc['project']['restore']
        project=restore['projectPath'].replace('\\','/').rsplit('/',1)[-1]
        sources=sorted(restore['sources'])
        r.need(sources and set(sources)<=PUBLIC_FEEDS,'unsupported dependency feed')
        libraries=doc['libraries']; targets=doc['targets']; packages={}
        r.need(isinstance(libraries,dict) and isinstance(targets,dict) and targets,'invalid dependency graph')
        for identity,row in libraries.items():
            r.need(row.get('type') in ('package','project'),'unsupported dependency library')
            if row['type']=='package':
                digest=row['sha512']; decoded=base64.b64decode(digest,validate=True)
                r.need(len(decoded)==64 and isinstance(row['path'],str),'invalid dependency content identity')
                packages[identity]={'sha512':digest,'path':row['path']}
        for target,rows in targets.items():
            r.need(isinstance(rows,dict),'invalid dependency target')
            for identity,row in rows.items():
                r.need(identity in libraries,'unresolved dependency target')
                if row.get('type')=='package': r.need(identity in packages,'missing dependency content identity')
        return {'project':project,'sources':sources,'packages':packages,
                'targets_sha256':r.sha(b.encoded(targets)),'assets_sha256':r.sha(raw)}
    except (KeyError,TypeError,ValueError,AttributeError) as error:
        raise r.Rejected('invalid dependency resolution receipt') from error


PACKAGE_CAP=128*1024**2
REQUIRED_OUTPUTS=('compiler/DMCompiler.dll','compiler/DMCompiler.deps.json',
    'compiler/DMCompiler.runtimeconfig.json','compiler/DMStandard/_Standard.dm',
    'server/Robust.Server.dll','server/Robust.Server.deps.json','server/Robust.Server.runtimeconfig.json',
    'server/Resources/manifest.yml','server/Resources/Assemblies/OpenDreamServer.dll')


def measure_outputs(sizes):
    r.need(isinstance(sizes,dict) and sizes,'empty package')
    for p,size in sizes.items():
        b.relative(p)
        r.need(p.startswith(('compiler/','server/')) and type(size) is int and 0<=size<=PACKAGE_CAP,
               'bad package size')
    for name in REQUIRED_OUTPUTS:
        r.need(sizes.get(name,0)>0,'required package member missing')
    overhead=len(b.encoded({'profile':'independent-source-build','engine':r.ENGINE,
                           'files':{p:'' for p in sorted(sizes)}}))
    raw_bytes=sum(sizes.values()); serialized_bytes=overhead+2*raw_bytes
    r.need(serialized_bytes<=PACKAGE_CAP,'package container too large')
    return {'raw_bytes':raw_bytes,'json_overhead_bytes':overhead,
            'serialized_bytes':serialized_bytes,'cap_bytes':PACKAGE_CAP,'files':len(sizes)}


def seal_outputs(outputs):
    r.need(isinstance(outputs,dict) and outputs,'empty package')
    r.need(all(isinstance(raw,bytes) for raw in outputs.values()),'bad package bytes')
    measured=measure_outputs({p:len(raw) for p,raw in outputs.items()})
    pins={p:r.sha(raw) for p,raw in outputs.items()}
    archive=b.encoded({'profile':'independent-source-build','engine':r.ENGINE,
                       'files':{p:raw.hex() for p,raw in sorted(outputs.items())}})
    r.need(len(archive)==measured['serialized_bytes'],'package measurement differs')
    return {'archive_sha256':r.sha(archive),'compiler_sha256':pins['compiler/DMCompiler.dll'],
            'runtime_sha256':pins['server/Robust.Server.dll'],
            'installed_manifest_sha256':r.sha(b.encoded(pins))}


def execute(route,digest,backend,clock,utc,*,entered=None,entered_utc=None):
    entered=clock() if entered is None else entered
    entered_utc=utc() if entered_utc is None else entered_utc
    backend.begin(route,digest,entered,entered_utc)
    primary=None; secondary=[]; result=None
    try:
        deadline=min(backend.work_end,entered+1500)
        last=None; epoch=None
        def guard(sample):
            nonlocal last,epoch
            backend._check(deadline); now=clock()
            if epoch!=sample.get('monitor_epoch'): last=None; epoch=sample.get('monitor_epoch')
            if last is not None:
                interval=route['resource_envelope']['sample_interval_seconds']
                r.need(interval*.5<=now-last<=interval*1.5,'bootstrap monitor cadence')
            r.observe(sample,route,build=True); last=now
        admitted=backend.bootstrap(deadline,guard)
        backend._check(deadline)
        # Fresh independent bytes-to-pins check before the existing five-case
        # orchestrator. Its own budget cannot extend backend's original deadline.
        r.need(seal_outputs(backend.package_bytes)=={k:admitted[k] for k in OUTPUT_KEYS},'package admission drift')
        r.admission_check(admitted)
        result=r.orchestrate(admitted,backend.inputs,backend.startup,backend,clock,utc=utc,
                             admission_sha256=r.sha(b.encoded(admitted)))
    except BaseException as error:
        primary=error
    finally:
        # Also covers bootstrap failure and pre-reserve orchestration rejection.
        clean_end=min(backend.end,clock()+30)
        try:
            clean=backend.cleanup(backend.token,clean_end)
            r.need(clean and clock()<=clean_end,'bootstrap/final cleanup failed')
        except BaseException as error: secondary.append(str(error)[:512])
        try:
            r.need(clock() < backend.end and utc() < route['expires_utc'], 'final receipt budget/expiry')
            backend.fx.claim(backend.claim_dir+'/'+b.relative(route['allocation_id'])+'.bootstrap-receipt.json',
                b.encoded({'route':digest,'status':'FAIL' if primary or secondary else 'PENDING_FINAL_CHECK',
                'primary':str(primary)[:1024] if primary else None,'secondary':secondary[:4],
                'receipts':backend.receipts}))
            # Immutable bytes cannot retrospectively assert a post-write verdict.
            # Return success only after the actual slow write still fits both clocks.
            r.need(clock() < backend.end and utc() < route['expires_utc'], 'final receipt budget/expiry')
        except BaseException as error: secondary.append('retention: '+str(error)[:400])
    if primary:
        if secondary: raise r.Rejected(str(primary)[:1024]+'; cleanup/receipt: '+'; '.join(secondary[:4])) from primary
        raise primary
    r.need(not secondary,'; '.join(secondary[:4]))
    return result
