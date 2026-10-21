"""Manual containment-only CI pilot. Import/plan mode never starts processes.

No BYOND, compiler, game inputs, secrets, host runtime or measurement dispatch.
Execution is restricted to an explicitly confirmed standard public hosted job.
"""
import argparse
import errno
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import uuid

IMAGE = 'docker.io/library/python@sha256:57d96f71de145a98e7ceca18ee4ade77bba4103a33a72dfaea026b23625c6bf0'
IMAGE_ID = 'sha256:3c4d812a6efe003770aafbdba65f9c1960ba8234ab23a133934205a70bdcda77'
IMAGE_SOURCE = 'https://github.com/docker-library/repo-info/blob/master/repos/python/remote/3.12-slim-bookworm.md'
IMAGE_SOURCE_BLOB = 'e4a0e633985ceac539eb2d33c23c98df0ef167a9'
MEMORY = 64*1024**2
SCRATCH = 8*1024**2
PIDS = 16
CASES = ('guard', 'output', 'pids', 'memory', 'descendant')
SCOPE = 'civ13-reserved-containment-only'


def require(value, message):
    if not value:
        raise ValueError(message)


def hosted_guard(env, head, platform=sys.platform):
    require(platform == 'linux' and re.fullmatch('[0-9a-f]{40}', head or ''), 'Linux exact-head job required')
    expected = {'GITHUB_ACTIONS':'true', 'RUNNER_ENVIRONMENT':'github-hosted', 'RUNNER_OS':'Linux',
                'RUNNER_ARCH':'X64', 'GITHUB_REPOSITORY':'Civ13/Civ13', 'GITHUB_REPOSITORY_ID':'141349998',
                'GITHUB_EVENT_NAME':'workflow_dispatch', 'CIV13_REPOSITORY_VISIBILITY':'public',
                'CIV13_CONTAINMENT_CONFIRMED':'true', 'GITHUB_SHA':head}
    require(all(env.get(key) == value for key,value in expected.items()), 'Unconfirmed/free-hosted-job identity')


def plan():
    return {'scope':SCOPE, 'image':IMAGE, 'image_id':IMAGE_ID, 'image_source':IMAGE_SOURCE,
            'image_source_blob':IMAGE_SOURCE_BLOB, 'runner':'ubuntu-24.04 standard GitHub-hosted; public repository only',
            'memory_bytes':MEMORY, 'memory_plus_swap_bytes':MEMORY, 'swap_max_bytes':0,
            'scratch_bytes':SCRATCH, 'pids_max':PIDS, 'cpu_quota':25000, 'cpu_period':100000,
            'cases':list(CASES), 'aggregate_wall_seconds':240, 'cleanup_wall_seconds':30,
            'default':'OFF; no Docker invocation without --execute and exact hosted/manual confirmation',
            'native_byond_actions':0, 'artifact_uploads':0}


def validate_counters(values):
    require(values=={'memory.max':str(MEMORY),'memory.swap.max':'0','pids.max':str(PIDS),'cpu.max':'25000 100000'}, 'Enforced cgroup read-back mismatch')


def validate_result(case,result):
    require(result['case']==case and result['passed'] is True,'Control receipt rejected')
    validate_counters(result['enforced'])
    observed=result['observations']
    if case=='guard':
        require(observed['egress_errno'] in (errno.ENETUNREACH,errno.EHOSTUNREACH,errno.EPERM)
                and observed['readonly_errno'] in (errno.EROFS,errno.EACCES) and observed['scratch_positive'] is True, 'Guard causal evidence missing')
    elif case=='output':
        require(observed['errno']==errno.ENOSPC and 0<observed['written']<=SCRATCH,'Scratch causal evidence missing')
    elif case=='pids':
        require(observed['errno']==errno.EAGAIN and 0<observed['children']<PIDS
                and observed['events_after']>observed['events_before']>=0 and observed['all_reaped'] is True, 'PID causal evidence missing')


def container_args(name, owner, head, script, case, cidfile):
    require(case in CASES, 'Unknown control')
    return ['create', '--name',name,'--cidfile',str(cidfile), '--platform','linux/amd64', '--pull','never',
            '--label','scope='+SCOPE, '--label','owner='+owner, '--label','head='+head,
            '--network','none','--read-only','--cap-drop','ALL','--security-opt','no-new-privileges',
            '--user','65534:65534','--pids-limit',str(PIDS),'--memory',str(MEMORY),'--memory-swap',str(MEMORY),
            '--cpus','0.25','--cgroupns','private','--ipc','private','--shm-size','1048576',
            '--tmpfs',f'/work:rw,noexec,nosuid,nodev,size={SCRATCH},mode=1777',
            '--mount','type=bind,src='+str(script)+',dst=/pilot.py,readonly',
            '--workdir','/work','--env','PYTHONDONTWRITEBYTECODE=1','--env','PYTHONUNBUFFERED=1',
            '--restart','no','--stop-timeout','1','--no-healthcheck',
            '--log-driver','local','--log-opt','max-size=1m','--log-opt','max-file=1',
            '--entrypoint','/usr/local/bin/python3',IMAGE,'-B','/pilot.py','--inside',case]


def owned(info, cid, name, owner, head):
    require(info['Id'] == cid and info['Name'] == '/'+name, 'Container identity changed')
    labels=info['Config']['Labels']
    require(all(labels.get(k)==v for k,v in {'scope':SCOPE,'owner':owner,'head':head}.items()), 'Container ownership changed')


def inspect_settings(info, script):
    host=info['HostConfig']
    require(info['Image']==IMAGE_ID and info['Config']['Image']==IMAGE, 'Image drift')
    require(host['Memory']==MEMORY and host['MemorySwap']==MEMORY and host['PidsLimit']==PIDS
            and host['NanoCpus']==250000000, 'Resource settings drift')
    require(host['NetworkMode']=='none' and host['ReadonlyRootfs'] is True and host['Privileged'] is False
            and host['CgroupnsMode']=='private' and host['IpcMode']=='private' and host['PidMode']=='', 'Namespace/root drift')
    require(host['CapDrop']==['ALL'] and 'no-new-privileges' in host['SecurityOpt']
            and not host.get('PortBindings') and not host.get('Devices') and not host.get('Binds'), 'Capability/port/device drift')
    require(host['Tmpfs']=={'/work':f'rw,noexec,nosuid,nodev,size={SCRATCH},mode=1777'} and host['ShmSize']==1048576, 'Scratch quota drift')
    mounts=info['Mounts']
    require(len(mounts)==1 and mounts[0]['Type']=='bind' and mounts[0]['Source']==str(script)
            and mounts[0]['Destination']=='/pilot.py' and mounts[0]['RW'] is False, 'Unexpected writable/host mount')
    require(info['Config']['User']=='65534:65534' and info['Config']['Entrypoint']==['/usr/local/bin/python3'], 'Workload user/entrypoint drift')


class Docker:
    """Bound the retained Docker CLI itself; use only the ephemeral local daemon."""
    def __init__(self, output):
        self.output=output
        self.config=output/'empty-docker-config';self.config.mkdir()
        self.started=time.monotonic();self.index=0

    def call(self, args, timeout=10, optional=False, cleanup=False):
        remaining=(270 if cleanup else 240)-(time.monotonic()-self.started)
        require(remaining>0, 'Controller aggregate deadline')
        timeout=min(timeout,remaining)
        self.index+=1
        paths=[self.output/f'cli-{self.index}-{kind}.log' for kind in ('out','err')]
        with paths[0].open('xb') as out,paths[1].open('xb') as err:
            child=subprocess.Popen(['docker','--host','unix:///var/run/docker.sock','--config',str(self.config),*args],
                                   stdout=out,stderr=err,stdin=subprocess.DEVNULL)
            try:
                deadline=time.monotonic()+timeout
                while child.poll() is None:
                    require(time.monotonic()<deadline,'Docker CLI timeout')
                    require(sum(p.stat().st_size for p in paths)<=1024**2,'Docker CLI output bound')
                    time.sleep(.05)
                require(sum(p.stat().st_size for p in paths)<=1024**2,'Docker CLI output bound')
            finally:
                if child.poll() is None:
                    child.kill();child.wait(timeout=3)
        result=(child.returncode,paths[0].read_text(errors='replace'),paths[1].read_text(errors='replace'))
        require(optional or result[0]==0,
                f'Docker command failed: {args[0]} rc={result[0]} stderr={result[2][-512:]!r}')
        return result


def inspect(docker, target, cleanup=False):
    return json.loads(docker.call(['inspect',target],cleanup=cleanup)[1])[0]


def proc_identity(pid):
    fields=Path(f'/proc/{pid}/stat').read_text().rsplit(')',1)[1].split()
    return {'pid':pid,'start_ticks':int(fields[19])}


def capture_descendants(docker,cid):
    rows=docker.call(['top',cid,'-eo','pid,ppid'])[1].splitlines()[1:]
    identities=[proc_identity(int(line.split()[0])) for line in rows if line.strip()]
    require(len(identities)>=2,'Missing surviving descendant control')
    leader=inspect(docker,cid)['State']['Pid']
    fields=Path(f'/proc/{leader}/cgroup').read_text().strip().splitlines()
    require(len(fields)==1 and fields[0].startswith('0::/'),'Cgroup v2 required')
    root=Path('/sys/fs/cgroup').resolve()
    group=(root/fields[0][4:]).resolve()
    require(group.is_relative_to(root) and cid in str(group),'Owned cgroup attribution')
    return {'processes':identities,'cgroup':str(group),'cgroup_inode':group.stat().st_ino}


def validate_retirement(proof):
    for row in proof.get('processes',[]):
        try:current=proc_identity(row['pid'])
        except FileNotFoundError:continue
        require(current!=row,'Retained descendant still exists')
    if proof.get('cgroup'):
        group=Path(proof['cgroup'])
        if group.exists():
            require(group.stat().st_ino==proof['cgroup_inode'] and not (group/'cgroup.procs').read_text().strip(), 'Owned cgroup not empty/changed')


def retire(docker,cid,name,owner,head,proof):
    info=inspect(docker,cid,cleanup=True);owned(info,cid,name,owner,head)
    if info['State']['Running']:
        docker.call(['kill',cid],cleanup=True)
        docker.call(['wait',cid],timeout=5,cleanup=True)
    info=inspect(docker,cid,cleanup=True);owned(info,cid,name,owner,head)
    require(not info['State']['Running'] and info['State']['Pid']==0,'Container did not stop')
    deadline=time.monotonic()+5
    while True:
        try:validate_retirement(proof);break
        except ValueError:
            require(time.monotonic()<deadline,'Owned descendants/cgroup remain')
            time.sleep(.05)
    docker.call(['rm',cid],cleanup=True)
    remaining=docker.call(['container','ls','-a','--filter','id='+cid,'--format','{{.ID}}'],cleanup=True)[1]
    require(not remaining.strip(),'Owned container removal unconfirmed')
    return {'all_exited':True,'owned_container_absent':True,'descendants_checked':len(proof.get('processes',[]))}


def execute(head,output):
    hosted_guard(os.environ,head)
    repo=Path(__file__).resolve().parents[2]
    actual=subprocess.check_output(['git','-C',str(repo),'rev-parse','HEAD'],text=True).strip()
    require(actual==head and not subprocess.check_output(['git','-C',str(repo),'status','--porcelain'],text=True).strip(),'Checkout drift')
    temp=Path(os.environ['RUNNER_TEMP']).resolve()
    require(not output.exists() and not output.is_symlink() and output.parent.resolve()==temp,'Fresh RUNNER_TEMP output required')
    output.mkdir()
    docker=Docker(output)
    report={**plan(),'head':head,'complete':False,'runs':[],'wrapper_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
    def save():
        value=json.dumps(report,indent=2)
        require(len(value)<=128*1024,'Pilot receipt bound')
        (output/'pilot.json').write_text(value+'\n')
    try:
        docker.call(['pull','--platform','linux/amd64',IMAGE],timeout=60)
        image=json.loads(docker.call(['image','inspect',IMAGE])[1])[0]
        require(image['Id']==IMAGE_ID and image['Os']=='linux' and image['Architecture']=='amd64'
                and any(x.endswith('@'+IMAGE.split('@')[1]) for x in image.get('RepoDigests',[])), 'Official image read-back failed')
        report['image_verified']=True
        for case in CASES:
            owner=uuid.uuid4().hex;name='civ13-containment-'+owner
            row={'case':case,'owner':owner,'name':name,'complete':False};report['runs'].append(row);save()
            cid=None;proof={}
            try:
                cidfile=output/(owner+'.cid')
                # Resolve a possibly completed create only by this fresh name and
                # exact ownership labels; never enumerate/adopt another container.
                try:
                    created=docker.call(container_args(name,owner,head,Path(__file__).resolve(),case,cidfile))[1].strip()
                    require(re.fullmatch('[0-9a-f]{64}',created),'Invalid created ID')
                    cid=created
                except BaseException as create_error:
                    row['create_error']=str(create_error)
                    try:
                        code,out,err=docker.call(['inspect',name],optional=True,cleanup=True)
                        row['create_reconciliation']={'returncode':code}
                        if code==0:
                            candidate=json.loads(out)[0]
                            candidate_id=candidate['Id']
                            require(re.fullmatch('[0-9a-f]{64}',candidate_id),'Uncertain create identity')
                            owned(candidate,candidate_id,name,owner,head);cid=candidate_id
                        else:
                            row['create_reconciliation']['error']=err[-512:]
                    except BaseException as reconciliation_error:
                        row['create_reconciliation']={'error':str(reconciliation_error)}
                    raise
                row['cid']=cid;save()
                info=inspect(docker,cid);owned(info,cid,name,owner,head)
                inspect_settings(info,Path(__file__).resolve());row['settings_verified']=True
                docker.call(['start',cid])
                if case=='descendant':
                    deadline=time.monotonic()+5
                    while True:
                        logs=docker.call(['logs','--tail','8',cid])[1]
                        if 'DESCENDANT_READY' in logs:break
                        require(time.monotonic()<deadline,'Descendant ready deadline');time.sleep(.05)
                    proof=capture_descendants(docker,cid);row['retirement_proof']=proof
                else:
                    exit_code=int(docker.call(['wait',cid],timeout=15)[1].strip())
                    terminal=inspect(docker,cid);owned(terminal,cid,name,owner,head)
                    logs=docker.call(['logs','--tail','8',cid])[1]
                    row.update(exit_code=exit_code,oom_killed=terminal['State']['OOMKilled'],stdout=logs)
                    if case=='memory':
                        require(exit_code==137 and terminal['State']['OOMKilled'] is True,'Missing hard-memory OOM control')
                        preflight=json.loads(logs.strip())
                        require(preflight['case']=='memory','Missing memory preflight')
                        validate_counters(preflight['preflight'])
                    else:
                        require(exit_code==0 and terminal['State']['OOMKilled'] is False,'Unexpected control exit')
                        result=json.loads(logs.strip());validate_result(case,result)
                        row['observations']=result
            finally:
                if cid is not None:
                    try:
                        row['cleanup']=retire(docker,cid,name,owner,head,proof)
                    except BaseException as error:
                        row['cleanup']={'all_exited':False,'error':str(error)}
                        save();raise
                else:
                    row['cleanup']={'all_exited':False,'error':'No owned ID confirmed; retain exact name for reconciliation'}
                save()
            require(row['cleanup']['all_exited'],'Cleanup incomplete')
            row['complete']=True;save()
        report['complete']=True
    except BaseException as error:
        report['error']=str(error);raise
    finally:save()
    return report


def read_inside():
    require(sys.platform=='linux' and Path('/.dockerenv').is_file() and os.getuid()==65534,'Constrained container user required')
    root=Path('/sys/fs/cgroup')
    values={name:(root/name).read_text().strip() for name in ('memory.max','memory.swap.max','pids.max','cpu.max')}
    validate_counters(values)
    size=os.statvfs('/work');require(size.f_blocks*size.f_frsize==SCRATCH,'Enforced scratch size mismatch')
    return values


def inside(case):
    import signal
    import socket
    require(case in CASES,'Unknown inside control')
    counters=read_inside()
    observations={}
    if case=='guard':
        require([name for _,name in socket.if_nameindex()]==['lo'],'Unexpected network interface')
        try:
            with socket.create_connection(('198.51.100.1',9),timeout=.5):raise ValueError('Egress succeeded')
        except OSError as error:
            require(error.errno in (errno.ENETUNREACH,errno.EHOSTUNREACH,errno.EPERM),'Egress failure not attributable to isolation')
            observations['egress_errno']=error.errno
        try:
            with open('/pilot.py','rb+'):pass
        except OSError as error:
            require(error.errno in (errno.EROFS,errno.EACCES),'Unexpected input write failure')
            observations['readonly_errno']=error.errno
        else:raise ValueError('Read-only input was writable')
        Path('/work/positive').write_bytes(b'positive');Path('/work/positive').unlink()
        observations['scratch_positive']=True
    elif case=='output':
        written=0
        try:
            with open('/work/limit','wb',buffering=0) as target:
                while written<=2*SCRATCH:written+=target.write(b'x'*65536)
        except OSError as error:
            require(error.errno==errno.ENOSPC and 0<written<=SCRATCH,'Missing scratch ENOSPC control')
            observations.update(errno=error.errno,written=written)
        else:raise ValueError('Scratch bound not enforced')
    elif case=='pids':
        children=[]
        before=Path('/sys/fs/cgroup/pids.events').read_text()
        try:
            try:
                for _ in range(2*PIDS):
                    pid=os.fork()
                    if pid==0:
                        signal.pause();os._exit(0)
                    children.append(pid)
            except OSError as error:
                require(error.errno==errno.EAGAIN and 0<len(children)<PIDS,'Missing PID-limit control')
                after=Path('/sys/fs/cgroup/pids.events').read_text()
                require(int(after.split()[1])>int(before.split()[1]),'PID rejection not attributed to cgroup')
                observations.update(errno=error.errno,children=len(children),events_before=int(before.split()[1]),events_after=int(after.split()[1]))
            else:raise ValueError('PID bound not enforced')
        finally:
            for pid in children:os.kill(pid,signal.SIGKILL)
            for pid in children:os.waitpid(pid,0)
        observations['all_reaped']=True
    elif case=='memory':
        print(json.dumps({'case':case,'preflight':counters}),flush=True)
        values=[]
        for _ in range(32):
            chunk=bytearray(4*1024**2)
            for index in range(0,len(chunk),4096):chunk[index]=1
            values.append(chunk)
        raise ValueError('Hard memory control did not kill the container')
    elif case=='descendant':
        pid=os.fork()
        signal.signal(signal.SIGTERM,signal.SIG_IGN)
        if pid==0:
            time.sleep(300);os._exit(0)
        print('DESCENDANT_READY',flush=True);time.sleep(300)
        raise ValueError('External owned-descendant cleanup did not occur')
    result={'case':case,'passed':True,'enforced':counters,'observations':observations}
    validate_result(case,result)
    print(json.dumps(result),flush=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute',action='store_true')
    parser.add_argument('--expected-head')
    parser.add_argument('--output',type=Path)
    parser.add_argument('--inside',choices=CASES)
    args=parser.parse_args()
    if args.inside:
        require(not args.execute,'Exclusive inside mode');inside(args.inside)
    elif args.execute:
        require(args.output is not None,'Output required');execute(args.expected_head,args.output)
    else:print(json.dumps(plan(),indent=2))


if __name__=='__main__':main()
