"""One manual hosted workflow coordinator; no execution without --execute.

Pulls one immutable public image and BYOND archive, then hands an exact shared
600s deadline to the reviewed controller. Host disk growth is sampled, not a
hard quota; container scratch is separately hard-limited to 1 GiB.
"""
import argparse
import base64
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import selectors
import signal
import stat
import subprocess
import sys
import tarfile
import time
import zipfile

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
spec=importlib.util.spec_from_file_location('cloud_npc_controller',HERE/'cloud_npc_controller.py')
controller=importlib.util.module_from_spec(spec);spec.loader.exec_module(controller)
BYOND_SHA='16278f318cdeb4b77c57868dd7135032fde717ea6226269d22b2a1a50968e7f9'
HOST_GROWTH=3*1024**3
MIN_FREE=2*1024**3
SCRATCH=1024**3
SELECTED=('civ13.dme','code/','icons/','sound/','UI/','interface/','config/','tests/human_subtile/')
MEMBERS=('DreamMaker','DreamDaemon','libbyond.so','libext.so')


def require(ok,message):
    if not ok: raise RuntimeError(message)


def interrupted(signum,_frame):
    raise InterruptedError('Hosted coordinator received signal '+str(signum))


def timed_out(_signum,_frame):
    raise TimeoutError('Hosted coordinator exceeded its 600-second deadline')


def disk_free(path):
    fs=os.statvfs(path)
    return fs.f_bavail*fs.f_frsize


class Storage:
    def __init__(self, root):
        self.root=root;self.before=disk_free(root);self.minimum=self.before;self.samples=0
        require(self.before >= MIN_FREE+HOST_GROWTH, 'Insufficient hosted disk headroom')
    def observe(self):
        now=disk_free(self.root);self.minimum=min(self.minimum,now);self.samples+=1
        require(now>=MIN_FREE and self.before-now<=HOST_GROWTH, 'Host disk sampled safety threshold exceeded')
    def receipt(self):
        return {'before_free_bytes':self.before,'minimum_sampled_free_bytes':self.minimum,
                'sampled_growth_bytes':max(0,self.before-self.minimum),'samples':self.samples,
                'growth_threshold_bytes':HOST_GROWTH,'minimum_free_bytes':MIN_FREE,
                'limitation':'Polling can miss/overshoot writes; this is not a hard host filesystem quota.'}


def run(argv, env, deadline, timeout, storage, maximum=1024**2, optional=False, interrupt=False):
    budget=min(timeout,deadline-time.monotonic())
    require(budget>0,'Shared deadline exhausted')
    child=subprocess.Popen(argv,stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,stderr=subprocess.PIPE,
                           env=env,start_new_session=True)
    sel=selectors.DefaultSelector();streams={child.stdout:bytearray(),child.stderr:bytearray()}
    for stream in streams: sel.register(stream,selectors.EVENT_READ)
    end=time.monotonic()+budget
    try:
        while sel.get_map():
            storage.observe()
            require(time.monotonic()<end,'Phase timeout')
            for key,_ in sel.select(min(.1,max(0,end-time.monotonic()))):
                chunk=os.read(key.fd,65536)
                if chunk:
                    streams[key.fileobj].extend(chunk)
                    require(sum(map(len,streams.values()))<=maximum,'Phase output exceeds bound')
                else: sel.unregister(key.fileobj)
        child.wait(timeout=max(0,end-time.monotonic()))
    finally:
        sel.close()
        if child.poll() is None:
            try: os.killpg(child.pid,signal.SIGINT if interrupt else signal.SIGKILL)
            except ProcessLookupError: pass
            # The owned-container watchdog may need the shared teardown reserve
            # if the interrupted controller is stalled; do not end the Actions
            # step and strand that independent cleanup process prematurely.
            wait_budget=max(1,deadline-time.monotonic()-5) if interrupt else 3
            try: child.wait(timeout=wait_budget)
            except subprocess.TimeoutExpired:
                # The controller's separate exact-owner watchdog remains responsible
                # for its container if the host child cannot close cleanly.
                try: os.killpg(child.pid,signal.SIGKILL)
                except ProcessLookupError: pass
                child.wait(timeout=3)
        child.stdout.close();child.stderr.close()
    out,err=bytes(streams[child.stdout]),bytes(streams[child.stderr])
    require(optional or child.returncode==0,'Phase failed: '+Path(argv[0]).name+' rc='+str(child.returncode))
    return child.returncode,out,err


def selected_estimate(raw):
    total=count=0
    for row in raw.split(b'\0'):
        if not row: continue
        meta,path=row.split(b'\t',1);name=path.decode('utf-8')
        if any(name==wanted or name.startswith(wanted) for wanted in SELECTED):
            parts=meta.split();require(parts[0] in (b'100644',b'100755') and parts[1]==b'blob' and parts[3]!=b'-','Unsupported Git entry')
            total+=int(parts[3]);count+=1
    require(count>0,'No selected source')
    # Source tar + extracted files, with a deliberately conservative metadata margin.
    estimate=2*total+16384*count
    require(estimate<SCRATCH,'Selected source alone cannot fit 1 GiB scratch')
    return {'files':count,'blob_bytes':total,'archive_and_stage_estimate_bytes':estimate,
            'scratch_limit_bytes':SCRATCH,
            'limitation':'Does not include compiled artifacts, logs, saves or short-lived peaks.'}


def extract_toolchain(archive, target):
    require(archive.stat().st_size==4887281 and hashlib.sha256(archive.read_bytes()).hexdigest()==BYOND_SHA,
            'BYOND archive differs from pinned bytes')
    target.mkdir(parents=True)
    with zipfile.ZipFile(archive) as package:
        for name in MEMBERS:
            matches=[x for x in package.infolist() if x.filename=='byond/bin/'+name]
            require(len(matches)==1,'Missing/duplicate BYOND member')
            row=matches[0];mode=row.external_attr>>16
            require(row.create_system==3 and stat.S_ISREG(mode) and not row.flag_bits&1 and
                    0<row.file_size<=32*1024**2,'Unsafe BYOND member')
            with package.open(row) as stream: data=stream.read(row.file_size+1)
            require(len(data)==row.file_size,'Wrong BYOND member size')
            path=target/name
            with path.open('xb') as stream: stream.write(data)
            path.chmod(0o755 if name in ('DreamMaker','DreamDaemon') else 0o644)


def save(path,row):
    raw=(json.dumps(row,indent=2,sort_keys=True)+'\n').encode()
    require(len(raw)<=65536,'Coordinator receipt bound')
    temp=path.with_suffix('.tmp');temp.write_bytes(raw);os.replace(temp,path)


def emit_evidence(setup, control):
    """Retain small synthetic evidence in workflow logs; no billable artifact."""
    allowed=((setup/'coordinator.json','coordinator.json'),
             (control/'controller.json','controller.json'),
             (control/'watchdog.json','watchdog.json'),
             (control/'container-tail.log','container-tail.log'),
             (control/'watchdog-tail.log','watchdog-tail.log'),
             (control/'harness-evidence.tar','harness-evidence.tar'))
    buffer=io.BytesIO()
    with tarfile.open(fileobj=buffer,mode='w:gz') as archive:
        for path,name in allowed:
            if not path.exists(): continue
            info=path.lstat()
            require(stat.S_ISREG(info.st_mode) and info.st_size<=16*1024**2, 'Unsafe host evidence')
            data=path.read_bytes();require(len(data)==info.st_size,'Host evidence changed')
            entry=tarfile.TarInfo(name);entry.size=len(data);entry.mode=0o600;entry.mtime=0
            archive.addfile(entry,io.BytesIO(data))
    raw=buffer.getvalue();require(len(raw)<=1024**2,'Compressed log evidence exceeds 1 MiB')
    encoded=base64.b64encode(raw).decode('ascii')
    parts=[encoded[i:i+4096] for i in range(0,len(encoded),4096)]
    print('CLOUD_EVIDENCE_META '+json.dumps({'sha256':hashlib.sha256(raw).hexdigest(),
          'bytes':len(raw),'parts':len(parts)}),flush=True)
    for index,part in enumerate(parts,1):
        print('CLOUD_EVIDENCE_PART '+str(index)+'/'+str(len(parts))+' '+part,flush=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute',action='store_true');parser.add_argument('--head',required=True)
    parser.add_argument('--output',required=True,type=Path);parser.add_argument('--controller-output',required=True,type=Path)
    args=parser.parse_args();require(args.execute,'Explicit --execute required')
    controller.hosted(os.environ,args.head)
    signal.signal(signal.SIGTERM,interrupted);signal.signal(signal.SIGINT,interrupted)
    signal.signal(signal.SIGALRM,timed_out);signal.alarm(600)
    start=time.monotonic();deadline=start+600
    temp=Path(os.environ['RUNNER_TEMP']).resolve();out=args.output.resolve();control=args.controller_output.resolve()
    require(out.parent==temp and control.parent==temp and out!=control and not out.exists() and not control.exists(),
            'Fresh separate RUNNER_TEMP output directories required')
    out.mkdir();(out/'docker-config').mkdir()
    record={'head':args.head,'complete':False,'phase':'preflight',
            'host_storage_is_hard_quota':False,'native_executed':False}
    save(out/'coordinator.json',record)
    clean_env={'PATH':'/usr/bin:/bin','HOME':str(out),'LANG':'C.UTF-8','GIT_CONFIG_NOSYSTEM':'1',
               'GIT_CONFIG_GLOBAL':'/dev/null','GIT_TERMINAL_PROMPT':'0','GIT_OPTIONAL_LOCKS':'0'}
    docker=['docker','--host','unix:///var/run/docker.sock','--config',str(out/'docker-config')]
    storage=None
    try:
        # Docker root is observed, never reconfigured. GitHub runner is ephemeral.
        probe=subprocess.run(docker+['info','--format','{{.DockerRootDir}}'],env=clean_env,
                             capture_output=True,timeout=10,check=True)
        diskroot=Path(probe.stdout.decode().strip()).resolve()
        require(diskroot.is_absolute() and diskroot.is_dir(),'Unusable Docker data root')
        require(os.stat(diskroot).st_dev==os.stat(temp).st_dev,'Docker and runner temp need same monitored filesystem')
        storage=Storage(diskroot);storage.observe()
        git=['git','-c','core.fsmonitor=false','-c','core.hooksPath=/dev/null','-C',str(ROOT)]
        _,head,_=run(git+['rev-parse','HEAD'],clean_env,deadline,10,storage)
        _,dirty,_=run(git+['status','--porcelain=v1','--untracked-files=all'],clean_env,deadline,30,storage)
        require(head.decode().strip()==args.head and not dirty,'Source differs from clean exact head')
        _,tree,_=run(git+['ls-tree','-r','-l','-z',args.head],clean_env,deadline,30,storage,maximum=16*1024**2)
        record['scratch_estimate']=selected_estimate(tree);record['phase']='image-acquisition';save(out/'coordinator.json',record)
        rc,existing,err=run(docker+['image','inspect',controller.IMAGE],clean_env,deadline,10,storage,optional=True)
        if rc:
            require(b'No such image' in err or b'No such object' in err,'Docker image state uncertain')
            record['image_pull_state']='started-outcome-uncertain';save(out/'coordinator.json',record)
            run(docker+['pull','--platform','linux/386',controller.IMAGE],clean_env,deadline,120,storage,maximum=4*1024**2)
            record['image_pulled']=True
            record['image_pull_state']='completed'
        else: record['image_pulled']=False
        _,raw,_=run(docker+['image','inspect',controller.IMAGE],clean_env,deadline,10,storage)
        image=json.loads(raw)[0]
        allowed={controller.IMAGE,'python@'+controller.IMAGE.split('@',1)[1],
                 'library/python@'+controller.IMAGE.split('@',1)[1]}
        require(image['Os']=='linux' and image['Architecture']=='386' and any(x in allowed for x in image.get('RepoDigests',[])) and
                isinstance(image.get('Size'),int) and 0<image['Size']<=2*1024**3,
                'Pinned image identity or size mismatch')
        record['image']={'id':image['Id'],'size_bytes':image['Size'],'digest':controller.IMAGE}
        record['phase']='byond-acquisition';save(out/'coordinator.json',record)
        archive=out/'pinned.zip'
        record['byond_download_state']='started-outcome-uncertain';save(out/'coordinator.json',record)
        run([sys.executable,'-I','-B',str(ROOT/'scripts/byond_toolchain.py'),'download','--platform','linux',
             '--source','repository-release','--output',str(archive)],clean_env,deadline,65,storage)
        record['byond_download_state']='completed'
        binary=out/'toolchain'/'byond'/'bin';extract_toolchain(archive,binary)
        spec=importlib.util.spec_from_file_location('cloud_runtime_identity',ROOT/'scripts/byond_runtime.py')
        runtime=importlib.util.module_from_spec(spec);spec.loader.exec_module(runtime)
        record['byond_identity']=runtime.verify_linux(binary,archive)
        record['phase']='controller';save(out/'coordinator.json',record)
        # Preserve a 10-second coordinator receipt lease after controller/watchdog.
        command=[sys.executable,'-I','-B',str(HERE/'cloud_npc_controller.py'),'--execute','--head',args.head,
                 '--source',str(ROOT),'--byond-bin',str(binary),'--byond-archive',str(archive),
                 '--output',str(control),'--deadline',str(deadline-10)]
        child_env={k:v for k,v in os.environ.items() if k in ('GITHUB_ACTIONS','RUNNER_ENVIRONMENT','RUNNER_OS','RUNNER_ARCH',
          'GITHUB_REPOSITORY','GITHUB_REPOSITORY_ID','GITHUB_EVENT_NAME','CIV13_REPOSITORY_VISIBILITY','GITHUB_SHA','RUNNER_TEMP')}
        child_env.update(PATH='/usr/bin:/bin',LANG='C.UTF-8')
        record['native_executed']='controller-started-not-proof-of-launch'
        run(command,child_env,deadline-5,max(1,deadline-time.monotonic()-5),storage,interrupt=True)
        receipt=json.loads((control/'controller.json').read_text())
        require(receipt.get('head')==args.head and receipt.get('complete') is True and receipt.get('fixture_dme_only') is True,
                'Controller did not produce exact-head fixture acceptance')
        record['complete']=True;record['phase']='complete'
    except BaseException as exc:
        record['error']=type(exc).__name__+': '+str(exc)[:512]
    finally:
        if storage: record['host_storage']=storage.receipt()
        record['seconds']=time.monotonic()-start
        save(out/'coordinator.json',record)
        try:
            emit_evidence(out,control)
        except BaseException as exc:
            record['complete']=False
            record['evidence_error']=type(exc).__name__+': '+str(exc)[:512]
            save(out/'coordinator.json',record)
            print('CLOUD_EVIDENCE_FAILED '+json.dumps(record,sort_keys=True),flush=True)
    require(record['complete'],'Cloud smoke incomplete; retain coordinator/controller evidence')
    signal.alarm(0)


if __name__=='__main__':
    try: main()
    except BaseException as exc:
        print('COORDINATOR_FAILURE '+json.dumps({'type':type(exc).__name__,'message':str(exc)[:512]}),file=sys.stderr,flush=True)
        raise
