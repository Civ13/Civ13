"""Review-only until main accepts this exact packet. One compiler/one daemon.

No local-native mode. Host execution requires exact public GitHub-hosted manual
context. The worker runs only in the reviewed immutable 386 image, network none.
"""
import argparse
import base64
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import selectors
import shutil
import signal
import stat
import subprocess
import sys
import tarfile
import time
import uuid
import zipfile
sys.path.insert(0,str(Path(__file__).resolve().parent))
from prepare import PIN, prepare, record

IMAGE='docker.io/library/python@sha256:e859437f5f6d28ecc8452905c49f0729533f72e680feec294186e1ab3799a445'
SCOPE='civ13-train-station-proof'
HERE=Path(__file__).resolve().parent
MAX_LOG=2*1024**2
WORK_FILES=('status.json','compile.log','daemon.log','runtime.log','native-trace.log')


def require(ok,why):
    if not ok:raise RuntimeError(why)


def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path);mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod);return mod


def save(path,data):path.write_text(json.dumps(data,indent=2)+'\n',encoding='utf8')


def sockets(pid):
    owned=set()
    for fd in Path('/proc',str(pid),'fd').iterdir():
        try:
            target=os.readlink(fd)
            if target.startswith('socket:['):owned.add(target[8:-1])
        except FileNotFoundError:pass
    rows=[]
    for table in ('tcp','tcp6','udp','udp6'):
        for line in Path('/proc',str(pid),'net',table).read_text().splitlines()[1:]:
            fields=line.split()
            if fields[9] in owned:rows.append({'table':table,'local':fields[1],'remote':fields[2],'state':fields[3]})
    return rows


def native(argv,seconds,cpu,as_bytes,work,name):
    import resource
    def limits():
        resource.setrlimit(resource.RLIMIT_AS,(as_bytes,as_bytes))
        resource.setrlimit(resource.RLIMIT_CPU,(cpu,cpu))
        resource.setrlimit(resource.RLIMIT_FSIZE,(MAX_LOG,MAX_LOG))
        resource.setrlimit(resource.RLIMIT_CORE,(0,0))
    child=subprocess.Popen(argv,cwd=work,stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,
          env={'PATH':'/usr/bin:/bin','HOME':'/work','LANG':'C.UTF-8','LD_LIBRARY_PATH':'/opt/byond/bin'},
          start_new_session=True,preexec_fn=limits)
    identity={'pid':child.pid,'stat':Path('/proc',str(child.pid),'stat').read_text()}
    data=bytearray();sel=selectors.DefaultSelector();sel.register(child.stdout,selectors.EVENT_READ)
    start=time.monotonic();samples=0;peak=0;observed=[];error=None
    try:
        while sel.get_map() or child.poll() is None:
            require(time.monotonic()-start<seconds,'native phase wall limit')
            if child.poll() is None:
                try:
                    status=Path('/proc',str(child.pid),'status').read_text()
                    rss=re.search(r'^VmRSS:\s+(\d+)',status,re.M)
                    if rss:peak=max(peak,int(rss.group(1))*1024)
                    observed=sockets(child.pid);samples+=1
                    require(not observed,'unexpected native inet socket')
                    descendants=Path('/proc',str(child.pid),'task',str(child.pid),'children').read_text().strip()
                    require(not descendants,'native child process observed')
                except FileNotFoundError:
                    require(child.poll() is not None,'native census disappeared while running')
            for key,_ in sel.select(.05):
                chunk=os.read(key.fd,65536)
                if chunk:
                    data.extend(chunk);require(len(data)<=MAX_LOG,'native stdout limit')
                else:sel.unregister(key.fileobj)
        child.wait(timeout=3)
    except BaseException as exc:
        error=str(exc)
    finally:
        sel.close()
        if child.poll() is None:
            try:os.killpg(child.pid,signal.SIGKILL)
            except ProcessLookupError:pass
            child.wait(timeout=3)
        child.stdout.close()
        (work/(name+'.log')).write_bytes(data)
    result={'identity':identity,'argv':argv,'returncode':child.returncode,'exited':child.poll() is not None,
            'seconds':time.monotonic()-start,'wall_limit':seconds,'cpu_limit':cpu,'as_limit':as_bytes,
            'sampled_peak_rss':peak,'census_samples':samples,'observed_sockets':observed,'error':error,
            'sampling_limit':'50ms polling can miss shorter sockets/children; container has no external network.'}
    return result


def worker():
    require(sys.platform=='linux' and Path('/source/prepared/stage/proof.dme').is_file(),'isolated worker mounts required')
    root=Path('/source/prepared');work=Path('/work/proof')
    import contract
    source=contract.source_check(root);shutil.copytree(root/'stage',work)
    receipt={'source_commit':PIN,'outcome':'failed','native_executed':False,'source_manifest':record((root/'source-manifest.json').read_bytes()),
             'run_provenance':json.loads((root/'run-provenance.json').read_text())}
    runtime=load('train_runtime_identity',root/'original/scripts/byond_runtime.py')
    try:
        identity=runtime.verify_linux('/opt/byond/bin','/inputs/byond.zip');receipt['runtime_identity']=identity
        receipt['compiler']=native(['/opt/byond/bin/DreamMaker','-max_errors','0','proof.dme'],60,30,512*1024**2,work,'compile')
        phase=receipt['compiler'];log=(work/'compile.log').read_text(errors='replace')
        require(not phase['error'] and phase['returncode']==0,'compiler failed')
        require(re.findall(r'^DM compiler version .*$',log,re.M)==['DM compiler version 516.1688'],'compiler version banner')
        require(len(re.findall(r'^proof.dmb - 0 errors, 0 warnings(?: \([^\n]*\))?$',log,re.M))==1 and not re.search(r'\b(?:[1-9]\d*) (?:errors|warnings)\b',log),'clean compiler summary')
        receipt['compiled']={n:record((work/n).read_bytes()) for n in ('proof.dmb','proof.rsc')}
        require(runtime.verify_linux('/opt/byond/bin','/inputs/byond.zip')==identity,'toolchain changed before daemon')
        receipt['native_executed']=True
        receipt['daemon']=native(['/opt/byond/bin/DreamDaemon','proof.dmb','-invisible','-trusted','-close','-ip','127.0.0.1','-nowebclient','-log','runtime.log'],150,15,256*1024**2,work,'daemon')
        phase=receipt['daemon'];require(not phase['error'] and phase['returncode']==0,'daemon failed')
        logs=[(work/n).read_text(errors='replace') for n in ('daemon.log','runtime.log') if (work/n).exists()]
        # Runtime diagnostics in either output invalidate the result. Avoid a
        # duplicate trace if the engine mirrors world.log to both destinations.
        for log in logs:
            require(not any(x in log.lower() for x in ('runtime error:','bad ref','maximum recursion','trace_cap_failure')),'daemon diagnostic')
        trace=next((log for log in reversed(logs) if 'TRAIN_TRACE ' in log),'')
        (work/'native-trace.log').write_text(trace,encoding='utf8')
        receipt['oracle']=contract.validate(contract.parse(trace));receipt['outcome']='passed'
    except BaseException as exc:
        receipt['error']=type(exc).__name__+': '+str(exc)[:1000]
    finally:
        save(work/'status.json',receipt)
        out=io.BytesIO()
        with tarfile.open(fileobj=out,mode='w:xz',preset=6) as archive:
            for name in WORK_FILES:
                path=work/name
                if path.exists():
                    raw=path.read_bytes();require(len(raw)<=MAX_LOG,'evidence file bound')
                    row=tarfile.TarInfo(name);row.size=len(raw);row.mode=0o600;archive.addfile(row,io.BytesIO(raw))
        data=out.getvalue();require(len(data)<=512*1024,'compressed evidence cap')
        print('TRAIN_CLOUD_PACKAGE '+json.dumps({**record(data),'xz_base64':base64.b64encode(data).decode()}),flush=True)
    require(receipt['outcome']=='passed','native proof failed; package retained')


def github_binding(expected_head,expected_tree,env):
    """Pure first-attempt identity check; no network or admission side effects."""
    required={'GITHUB_ACTIONS':'true','RUNNER_ENVIRONMENT':'github-hosted','RUNNER_OS':'Linux','RUNNER_ARCH':'X64',
              'GITHUB_REPOSITORY':'Civ13/Civ13','GITHUB_REPOSITORY_ID':'141349998','GITHUB_EVENT_NAME':'workflow_dispatch',
              'GITHUB_SHA':expected_head,'CIV13_REPOSITORY_VISIBILITY':'public'}
    require(all(env.get(k)==v for k,v in required.items()),'wrong hosted manual context')
    require(all(re.fullmatch('[0-9a-f]{40}',x or '') for x in (expected_head,expected_tree)),'exact reviewed head/tree required')
    require(re.fullmatch('[1-9][0-9]*',env.get('GITHUB_RUN_ID','')),'actual GitHub run ID required')
    require(env.get('GITHUB_RUN_ATTEMPT')=='1','only the admitted first attempt is allowed; workflow reruns are refused')
    ref=env.get('GITHUB_REF','')
    require(ref.startswith('refs/heads/') and len(ref)>len('refs/heads/'),'experiment branch ref required')
    workflow_ref='Civ13/Civ13/.github/workflows/train-collision.yml@'+ref
    require(env.get('GITHUB_WORKFLOW_REF')==workflow_ref and env.get('GITHUB_WORKFLOW_SHA')==expected_head,
            'workflow ref/SHA differs from reviewed candidate')
    return {'schema':1,'repository':'Civ13/Civ13','repository_id':'141349998',
            'event':'workflow_dispatch','run_id':env['GITHUB_RUN_ID'],'run_attempt':1,
            'ref':ref,'workflow_ref':workflow_ref,'workflow_sha':expected_head,
            'candidate_head':expected_head,'candidate_tree':expected_tree,'source_commit':PIN}


def hosted(expected_head,expected_tree):
    require(sys.platform=='linux','Linux hosted execution required')
    return github_binding(expected_head,expected_tree,os.environ)


def renderer_capabilities(command,out):
    """Read-only commands only; fail before image acquisition or native work."""
    receipt={'status':'running','commands':[],'no_dependency_installation':True}
    save(out/'renderer-capabilities.json',receipt)
    try:
        ffmpeg=shutil.which('ffmpeg',path='/usr/bin:/bin')
        ffprobe=shutil.which('ffprobe',path='/usr/bin:/bin')
        receipt.update(ffmpeg=ffmpeg,ffprobe=ffprobe,
                       missing=[n for n,p in (('ffmpeg',ffmpeg),('ffprobe',ffprobe)) if not p])
        require(ffmpeg and ffprobe,'preinstalled ffmpeg/ffprobe required; missing: '+','.join(receipt['missing'])+'; no dependency installation')
        checks=[('ffmpeg_version',[ffmpeg,'-version'],r'^ffmpeg version '),
                ('ffprobe_version',[ffprobe,'-version'],r'^ffprobe version '),
                ('libx264',[ffmpeg,'-hide_banner','-h','encoder=libx264'],r'^Encoder libx264 \[')]
        for label,argv,pattern in checks:
            row={'name':label,'argv':argv,'wall_limit':5,'output_limit':65536}
            receipt['commands'].append(row)
            result=command(argv,timeout=5,maximum=65536,optional=True)
            output=result.stdout+result.stderr
            row.update(returncode=result.returncode,output=output.decode('utf8',errors='replace'),output_identity=record(output))
            require(result.returncode==0 and re.search(pattern,row['output'],re.M),label+' capability unavailable')
        receipt.update(status='passed',ffmpeg=ffmpeg,ffprobe=ffprobe)
    except BaseException as exc:
        receipt.update(status='failed',error=type(exc).__name__+': '+str(exc)[:1000])
        raise
    finally:save(out/'renderer-capabilities.json',receipt)
    return receipt


def group_members(pgid):
    members=[]
    for proc in Path('/proc').iterdir():
        if not proc.name.isdecimal():continue
        try:
            tail=(proc/'stat').read_text().rsplit(')',1)[1].split()
            if int(tail[2])==pgid:
                members.append({'pid':int(proc.name),'pgrp':int(tail[2]),'session':int(tail[3]),
                                'start_ticks':int(tail[19]),'state':tail[0]})
        except FileNotFoundError:pass
    return members


def bind_group(pgid):
    members=group_members(pgid)
    leader=next((m for m in members if m['pid']==pgid),None)
    require(leader and leader['pgrp']==leader['session']==pgid,'fresh renderer session identity unavailable')
    return leader


def peek_exited(pid):
    # WNOWAIT retains even an exited leader as our unreaped child. Its PID and
    # session identity cannot be reused before the group cleanup below.
    return os.waitid(os.P_PID,pid,os.WEXITED|os.WNOHANG|os.WNOWAIT) is not None


def cleanup_group(binding,scan=group_members,send=None,now=time.monotonic,pause=time.sleep,seconds=3):
    """Check/kill the owned group even after leader exit, before reaping it."""
    if send is None:send=os.killpg
    pgid=binding['pid'];before=scan(pgid)
    leader=next((m for m in before if m['pid']==pgid),None)
    require(leader and all(leader[k]==binding[k] for k in ('pid','pgrp','session','start_ticks')),
            'unreaped renderer group owner identity changed')
    require(all(m['session']==pgid and m['start_ticks']>=binding['start_ticks'] for m in before),'renderer group session drift')
    live=lambda rows:[m for m in rows if m['state'] not in ('Z','X')]
    survivors=live(before)
    result={'leader':binding,'members_before':before,'leader_exited_before_cleanup':leader['state'] in ('Z','X'),
            'survivors_after_leader_exit':leader['state'] in ('Z','X') and bool(survivors),'kill_sent':False}
    if survivors:
        try:send(pgid,9) # Linux SIGKILL; no native effects in mocked controls.
        except ProcessLookupError:pass
        result['kill_sent']=True
    deadline=now()+seconds
    while True:
        after=scan(pgid)
        require(all(m['session']==pgid and m['start_ticks']>=binding['start_ticks'] for m in after),'renderer group changed during cleanup')
        if not live(after):
            result.update(members_after=after,no_running_members=True)
            return result
        require(now()<deadline,'renderer group still has running members after cleanup deadline')
        pause(.05)


def watchdog(cid,name,owner,head,config,until,out):
    """Independent exact-owner teardown after host interruption or hard failure."""
    env={'PATH':'/usr/bin:/bin','HOME':str(config),'LANG':'C.UTF-8'}
    base=['docker','--host','unix:///var/run/docker.sock','--config',str(config)]
    result={'id':cid,'removed':False,'absent':False}
    def call(args):return subprocess.run(base+args,env=env,stdin=subprocess.DEVNULL,capture_output=True,timeout=5)
    try:
        while True:
            probe=call(['inspect',cid])
            require(len(probe.stdout)<65536,'watchdog inspect bound')
            if probe.returncode:
                missing=call(['container','ls','-a','--filter','id='+cid,'--format','{{.ID}}'])
                require(missing.returncode==0 and not missing.stdout.strip(),'watchdog absence uncertain')
                result['absent']=True;break
            info=json.loads(probe.stdout)[0]
            require(info['Id']==cid and info['Name']=='/'+name and info['Config']['Labels']=={'scope':SCOPE,'owner':owner,'head':head},'watchdog owner mismatch')
            if time.monotonic()>=until:
                result['deadline_reached']=True
                if info['State']['Running']:
                    require(call(['kill',cid]).returncode==0 and call(['wait',cid]).returncode==0,'watchdog termination failed')
                final=call(['inspect',cid]);require(final.returncode==0,'watchdog exit inspect')
                stopped=json.loads(final.stdout)[0]
                require(stopped['Id']==cid and not stopped['State']['Running'] and stopped['State']['Pid']==0,'watchdog exit uncertain')
                result['state']=stopped['State']
                logs=call(['logs',cid]);require(len(logs.stdout)+len(logs.stderr)<=MAX_LOG,'watchdog log bound')
                (out/'watchdog-container.log').write_bytes(logs.stdout+logs.stderr)
                require(call(['rm',cid]).returncode==0,'watchdog remove failed')
                missing=call(['container','ls','-a','--filter','id='+cid,'--format','{{.ID}}'])
                require(missing.returncode==0 and not missing.stdout.strip(),'watchdog final absence uncertain')
                result.update(removed=True,absent=True);break
            time.sleep(.5)
    except BaseException as exc:result['error']=str(exc)[:1000]
    finally:save(out/'watchdog.json',result)
    require(result['absent'],'watchdog incomplete')


def host(expected_head,expected_tree,out):
    run_provenance=hosted(expected_head,expected_tree)
    require(out.parent.resolve()==Path(os.environ['RUNNER_TEMP']).resolve() and not out.exists(),'fresh runner-temp output required')
    out.mkdir();config=out/'docker-config';config.mkdir()
    env={'PATH':'/usr/bin:/bin','HOME':str(out),'LANG':'C.UTF-8','GIT_CONFIG_NOSYSTEM':'1','GIT_CONFIG_GLOBAL':'/dev/null','GIT_TERMINAL_PROMPT':'0'}
    end=time.monotonic()+600
    def interrupted(signum,_frame):raise InterruptedError('host received signal '+str(signum))
    signal.signal(signal.SIGTERM,interrupted);signal.signal(signal.SIGINT,interrupted)
    def command(argv,timeout=15,maximum=MAX_LOG,optional=False,retain_group=False):
        limit=min(end,time.monotonic()+timeout)
        child=subprocess.Popen(argv,stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=env,start_new_session=True)
        binding=bind_group(child.pid) if retain_group else None
        cleanup=None
        selector=selectors.DefaultSelector();streams={child.stdout:bytearray(),child.stderr:bytearray()}
        for stream in streams:selector.register(stream,selectors.EVENT_READ)
        try:
            while selector.get_map() or (not peek_exited(child.pid) if binding else child.poll() is None):
                require(time.monotonic()<limit,'host phase timeout')
                require(shutil.disk_usage(out).free>=2*1024**3,'sampled host disk floor')
                for key,_ in selector.select(.1):
                    chunk=os.read(key.fd,65536)
                    if chunk:
                        streams[key.fileobj].extend(chunk)
                        require(sum(map(len,streams.values()))<=maximum,'host CLI output bound')
                    else:selector.unregister(key.fileobj)
            if not binding:child.wait(timeout=3)
        finally:
            selector.close()
            if binding:
                try:
                    cleanup=cleanup_group(binding)
                    # Reap the retained leader only after all group members have
                    # stopped. A zombie descendant is exited, not running.
                    child.wait(timeout=3)
                    require(not any(m['state'] not in ('Z','X') for m in group_members(child.pid)),
                            'renderer group regained a running member')
                    save(out/'renderer-group-receipt.json',cleanup)
                except BaseException as exc:
                    save(out/'renderer-group-receipt.json',{'leader':binding,'cleanup':cleanup,'error':str(exc)[:1000],
                                                          'no_running_members':False})
                    raise
            elif child.poll() is None:
                try:os.killpg(child.pid,signal.SIGKILL)
                except ProcessLookupError:pass
                child.wait(timeout=3)
            child.stdout.close();child.stderr.close()
        result=subprocess.CompletedProcess(argv,child.returncode,bytes(streams[child.stdout]),bytes(streams[child.stderr]))
        require(not cleanup or not cleanup['survivors_after_leader_exit'],'renderer left a running child after leader exit; group cleaned but evidence rejected')
        require(optional or result.returncode==0,'host command failed: '+Path(argv[0]).name+' '+result.stderr.decode(errors='replace')[:256])
        return result
    docker=['docker','--host','unix:///var/run/docker.sock','--config',str(config)]
    repo=HERE.parents[1] # Installed as tests/train_station_cloud/cloud.py
    git=['git','-C',str(repo),'-c','core.hooksPath=/dev/null','-c','core.fsmonitor=false']
    require(command(git+['rev-parse','HEAD']).stdout.decode().strip()==expected_head and
            command(git+['rev-parse','HEAD^{tree}']).stdout.decode().strip()==expected_tree and
            not command(git+['status','--porcelain=v1','--untracked-files=all']).stdout,'dirty/unreviewed checkout')
    command(git+['merge-base','--is-ancestor',PIN,expected_head])
    changed=command(git+['diff','--name-only',PIN,expected_head]).stdout.decode().splitlines()
    require(changed and all(n.startswith('tests/train_station_cloud/') or n=='.github/workflows/train-collision.yml' for n in changed),'out-of-scope source delta')
    prepared=out/'prepared';prepare(repo,prepared)
    workflow_path='.github/workflows/train-collision.yml'
    workflow_bytes=command(git+['show',expected_head+':'+workflow_path],maximum=65536).stdout
    run_provenance['workflow_file']={'path':workflow_path,
        'git_blob':command(git+['rev-parse',expected_head+':'+workflow_path]).stdout.decode().strip(),**record(workflow_bytes)}
    run_provenance['source_manifest']=record((prepared/'source-manifest.json').read_bytes())
    run_provenance['fixture_files']={n:record((HERE/n).read_bytes()) for n in
        ('cloud.py','prepare.py','contract.py','replay.py','adapters.dm','fixture.dm')}
    save(prepared/'run-provenance.json',run_provenance)
    require(shutil.disk_usage(out).free>=5*1024**3,'host free disk floor')
    receipt={'head':expected_head,'tree':expected_tree,'source_commit':PIN,'complete':False,'native_executed':False,
             'run_provenance':run_provenance}
    cid=None;watcher=None;watchdog_until=None;owner=uuid.uuid4().hex;name='civ13-train-'+owner
    def inspect():return json.loads(command(docker+['inspect',cid],maximum=65536).stdout)[0]
    def own(info):require(info['Id']==cid and info['Name']=='/'+name and info['Config']['Labels']=={'scope':SCOPE,'owner':owner,'head':expected_head},'owned container identity')
    try:
        receipt['renderer_capabilities']=renderer_capabilities(command,out)
        command(docker+['pull','--platform','linux/386',IMAGE],timeout=120)
        image=json.loads(command(docker+['image','inspect',IMAGE],maximum=65536).stdout)[0]
        require(image['Os']=='linux' and image['Architecture']=='386' and image['Size']<=2*1024**3,'image ABI/size')
        receipt['image']={k:image[k] for k in ('Id','RepoDigests','Architecture','Os','Size')}
        archive=out/'byond.zip'
        command([sys.executable,'-I','-B',str(prepared/'original/scripts/byond_toolchain.py'),'download','--platform','linux','--source','repository-release','--output',str(archive)],timeout=65)
        pin=json.loads((prepared/'original/tools/byond/version.json').read_text())['linux']
        raw=archive.read_bytes();require(record(raw)=={'bytes':pin['bytes'],'sha256':pin['sha256']},'BYOND archive')
        binary=out/'byond';binary.mkdir()
        with zipfile.ZipFile(io.BytesIO(raw)) as z:
            for item in ('DreamMaker','DreamDaemon','libbyond.so','libext.so'):
                members=[r for r in z.infolist() if r.filename=='byond/bin/'+item]
                require(len(members)==1 and stat.S_ISREG(members[0].external_attr>>16) and 0<members[0].file_size<=32*1024**2,'BYOND member')
                path=binary/item;path.write_bytes(z.read(members[0]));path.chmod(0o755 if item in ('DreamMaker','DreamDaemon') else 0o644)
        mounts=[(str(HERE),'/source/code'),(str(prepared),'/source/prepared'),(str(binary),'/opt/byond/bin'),(str(archive),'/inputs/byond.zip')]
        argv=['create','--platform','linux/386','--name',name,'--label','scope='+SCOPE,'--label','owner='+owner,'--label','head='+expected_head,
              '--network','none','--read-only','--cap-drop','ALL','--security-opt','no-new-privileges','--pids-limit','32',
              '--memory','768m','--memory-swap','768m','--cpus','1','--user',str(os.getuid())+':'+str(os.getgid()),
              '--tmpfs','/work:rw,noexec,nosuid,nodev,size=134217728,mode=1777','--shm-size','1m',
              '--log-driver','local','--log-opt','max-size=2m','--log-opt','max-file=1','--log-opt','compress=false',
              '--env','HOME=/work','--env','LD_LIBRARY_PATH=/opt/byond/bin','--env','LANG=C.UTF-8',
              '--entrypoint','/usr/local/bin/python3.12']
        for src,dest in mounts:argv+=['--mount','type=bind,src='+src+',dst='+dest+',readonly']
        argv += [IMAGE,'-I','-B','/source/code/cloud.py','worker']
        result=command(docker+argv,maximum=65536);cid=result.stdout.decode().strip();require(re.fullmatch('[0-9a-f]{64}',cid),'container ID')
        info=inspect();own(info);hostconf=info['HostConfig']
        require(info['Image']==image['Id'] and hostconf['NetworkMode']=='none' and hostconf['ReadonlyRootfs'] and not hostconf['Privileged'] and
                hostconf['Memory']==hostconf['MemorySwap']==768*1024**2 and hostconf['PidsLimit']==32 and hostconf['NanoCpus']==1000000000 and
                hostconf['CapDrop']==['ALL'] and 'no-new-privileges' in hostconf['SecurityOpt'] and not hostconf['PortBindings'] and not hostconf['Devices'], 'container envelope drift')
        require(hostconf['Tmpfs']=={'/work':'rw,noexec,nosuid,nodev,size=134217728,mode=1777'} and
                hostconf['ShmSize']==1048576 and not hostconf.get('Binds') and hostconf['IpcMode']=='private' and
                hostconf['PidMode']=='' and hostconf['CgroupnsMode']=='private' and
                hostconf['LogConfig']=={'Type':'local','Config':{'max-size':'2m','max-file':'1','compress':'false'}} and
                info['Config']['User']==str(os.getuid())+':'+str(os.getgid()) and
                info['Config']['Entrypoint']==['/usr/local/bin/python3.12'] and
                info['Config']['Cmd']==['-I','-B','/source/code/cloud.py','worker'],'container command/storage/namespace drift')
        require(not any(re.search('GITHUB|GH_TOKEN|SECRET|CREDENTIAL|PASSWORD|API_KEY',v.split('=',1)[0],re.I) for v in info['Config']['Env']),'credential environment in worker')
        require({(m['Source'],m['Destination'],m['RW'],m['Type']) for m in info['Mounts']}=={(s,d,False,'bind') for s,d in mounts},'container mounts')
        receipt['container_create_inspect']=info
        deadline=min(end-160,time.monotonic()+225)
        watchdog_until=deadline+10
        watchlog=(out/'watchdog.log').open('wb')
        try:
            watcher=subprocess.Popen([sys.executable,'-I','-B',str(HERE/'cloud.py'),'watchdog',
                 '--cid',cid,'--name',name,'--owner',owner,'--head',expected_head,'--config',str(config),
                 '--until',str(watchdog_until),'--output',str(out)],stdin=subprocess.DEVNULL,stdout=watchlog,
                 stderr=subprocess.STDOUT,env=env,start_new_session=True)
        finally:watchlog.close()
        command(docker+['start',cid]);receipt['native_executed']='worker-started-not-proof-of-native-launch'
        while True:
            require(time.monotonic()<deadline,'container watchdog deadline')
            info=inspect();own(info)
            if not info['State']['Running']:break
            time.sleep(.5)
        receipt['container_state']=info['State']
        require(info['State']['Pid']==0 and not info['State']['OOMKilled'],'container exit/OOM')
        logs=command(docker+['logs',cid],maximum=MAX_LOG).stdout
        (out/'container.log').write_bytes(logs)
        packets=[line.split(b'TRAIN_CLOUD_PACKAGE ',1)[1] for line in logs.splitlines() if line.startswith(b'TRAIN_CLOUD_PACKAGE ')]
        require(len(packets)==1,'exactly one worker evidence package')
        packet=json.loads(packets[0]);data=base64.b64decode(packet['xz_base64'],validate=True)
        require(record(data)=={k:packet[k] for k in ('bytes','sha256')} and len(data)<=512*1024,'worker package hash')
        (out/'native-evidence.tar.xz').write_bytes(data)
        native_out=out/'native';native_out.mkdir()
        with tarfile.open(fileobj=io.BytesIO(data),mode='r:xz') as tar:
            rows=tar.getmembers();names=[r.name for r in rows]
            require(len(names)==len(set(names)) and set(names)<=set(WORK_FILES) and all(r.isfile() and r.size<=MAX_LOG for r in rows) and sum(r.size for r in rows)<=4*1024**2,'worker package members')
            for row in rows:(native_out/row.name).write_bytes(tar.extractfile(row).read())
        worker_status=json.loads((native_out/'status.json').read_text());receipt['worker']=worker_status
        require(info['State']['ExitCode']==0 and worker_status['outcome']=='passed','native worker failed; retain package')
        require(worker_status['source_commit']==PIN and worker_status['native_executed'] is True and
                worker_status['source_manifest']==record((prepared/'source-manifest.json').read_bytes()) and
                worker_status['run_provenance']==run_provenance,'worker source/run identity')
        for phase,wall,cpu,address in (('compiler',60,30,512*1024**2),('daemon',150,15,256*1024**2)):
            row=worker_status[phase]
            require(row['returncode']==0 and row['exited'] is True and row['error'] is None and not row['observed_sockets'] and
                    row['wall_limit']==wall and row['cpu_limit']==cpu and row['as_limit']==address and row['census_samples']>0,'independent native phase receipt: '+phase)
        import contract
        receipt['independent_oracle']=contract.validate(contract.parse((native_out/'native-trace.log').read_text()))
        # Destroy and verify absence BEFORE encoding the replay.
        command(docker+['rm',cid]);require(not command(docker+['container','ls','-a','--filter','id='+cid,'--format','{{.ID}}']).stdout.strip(),'container absence uncertain')
        receipt['cleanup']={'removed':True,'id':cid};cid=None
        watcher.wait(timeout=10);require(watcher.returncode==0 and json.loads((out/'watchdog.json').read_text())['absent'],'independent watchdog absence')
        receipt['watchdog']=json.loads((out/'watchdog.json').read_text())
        command([sys.executable,'-B',str(HERE/'replay.py'),'--prepared',str(prepared),'--run-provenance',str(prepared/'run-provenance.json'),
                 '--log',str(native_out/'native-trace.log'),'--output',str(out/'civ13-station-native-replay.mp4')],timeout=140,retain_group=True)
        receipt['complete']=True
    except BaseException as exc:
        receipt['error']=type(exc).__name__+': '+str(exc)[:1000]
    finally:
        if cid:
            try:
                info=inspect();own(info)
                if info['State']['Running']:command(docker+['kill',cid]);command(docker+['wait',cid])
                # Preserve available logs on every failed phase, before removal.
                logs=command(docker+['logs',cid],optional=True).stdout
                (out/'container-failure.log').write_bytes(logs)
                info=inspect();own(info);require(not info['State']['Running'] and info['State']['Pid']==0,'owned exit uncertain')
                command(docker+['rm',cid]);require(not command(docker+['container','ls','-a','--filter','id='+cid,'--format','{{.ID}}']).stdout.strip(),'owned absence uncertain')
                receipt['cleanup']={'removed':True,'id':cid,'state':info['State']}
            except BaseException as exc:
                receipt['cleanup']={'removed':False,'id':cid,'error':str(exc)[:1000]};receipt['complete']=False
        if watcher:
            try:
                if cid and not receipt.get('cleanup',{}).get('removed'):
                    # Finish the independent exact-owner cleanup before emitting
                    # the final receipt; no success or pending-cleanup handoff.
                    budget=min(end-5,watchdog_until+15)-time.monotonic()
                    require(budget>0,'no teardown budget for watchdog completion')
                    watcher.wait(timeout=budget)
                    receipt['watchdog']=json.loads((out/'watchdog.json').read_text())
                    require(watcher.returncode==0 and receipt['watchdog']['absent'],'watchdog cleanup incomplete')
                    require(not command(docker+['container','ls','-a','--filter','id='+cid,'--format','{{.ID}}']).stdout.strip(),
                            'owned absence uncertain after watchdog')
                    receipt['initial_cleanup_failure']=receipt.get('cleanup')
                    receipt['cleanup']={'removed':True,'id':cid,'by':'watchdog','absence_verified':True}
                else:
                    watcher.wait(timeout=10)
                    receipt['watchdog']=json.loads((out/'watchdog.json').read_text())
                    require(watcher.returncode==0 and receipt['watchdog']['absent'],'watchdog failed')
            except BaseException as exc:
                receipt['watchdog_error']=str(exc)[:1000];receipt['complete']=False
        receipt['elapsed_seconds']=600-max(0,end-time.monotonic());save(out/'host-receipt.json',receipt)
    require(receipt['complete'],'cloud proof incomplete; retain all failure evidence')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('mode',choices=('host','worker','watchdog'))
    p.add_argument('--head');p.add_argument('--tree');p.add_argument('--output',type=Path)
    p.add_argument('--cid');p.add_argument('--name');p.add_argument('--owner');p.add_argument('--config',type=Path);p.add_argument('--until',type=float);a=p.parse_args()
    if a.mode=='worker':worker()
    elif a.mode=='watchdog':watchdog(a.cid,a.name,a.owner,a.head,a.config,a.until,a.output)
    else:host(a.head,a.tree,a.output.resolve())
