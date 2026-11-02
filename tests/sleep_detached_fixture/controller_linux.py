"""Source-review candidate: bounded synthetic exporter writer/fresh reader.

Linux only. No provisioning, network sandbox, real game, or production authority.
A reviewed caller must provide a fresh isolated parent and exact self hash.
"""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import signal
import stat
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parent
STAGE=ROOT/'fixture-stage-v6'
STAGE_MANIFEST='1b87f3b04561be600b0475d981f754f646d0144c6cded816a06560d5e6bbcc95'
HELPERS={'scripts/byond_runtime.py':'e65075d47f884bb3f668d174b9589a4debd2d6c26535c6287b87715c973d37ba',
         'scripts/byond_toolchain.py':'f70797fe2b0db7973dd1b4f4c78a0d1cf6f7e7d3caac234ea3525aa224e50b2e',
         'tools/byond/version.json':'360299d3f744dceed24d1bbcbcb43acffb244071401776c663e6c3a01a6cd907'}
STAGED={'fixture.dme','fixture_stubs.dm','fixture_world.dm','graph_probe.dm','pinned_loader.dm','reader_probe.dm','sleep_graph_export_fixture.dm'}
MAX_FILE=256*1024**2
MAX_OUTPUT=256*1024**2  # sampled, not a filesystem quota
MAX_LOG=8*1024**2
MAX_ENTRIES=512
MAX_AS=1024**3
MIN_FREE=16*1024**3
PHASE_SECONDS=120
TOTAL_SECONDS=360
DIAGNOSTIC=re.compile(r'infinite[ _]loop|switching proc to background|runtime error|unexpected runtime|runtime failure|\bBad ref\b|\bBad loc\b|Cannot read null|Cannot execute null|\bBUG:|##\s*ERROR\s*:|uncaught exception|fatal error|segmentation|assertion failed|\bRUNTIME:|\bOOM\b|out of memory|access violation|\bCRASH(?:ED)?\b|invalid file',re.I)

def require(condition,message):
    if not condition: raise ValueError(message)

def plain(path,kind):
    path=Path(path).absolute()
    require('..' not in path.parts,'parent traversal refused')
    for node in reversed((path,*path.parents)):
        st=node.lstat()
        require(not stat.S_ISLNK(st.st_mode),'linked path refused')
    st=path.lstat()
    require(stat.S_ISDIR(st.st_mode) if kind=='dir' else stat.S_ISREG(st.st_mode),'wrong path type')
    return path

def bounded(path,limit):
    path=plain(path,'file')
    require(path.stat().st_size<=limit,'file exceeds bound')
    with path.open('rb') as f: data=f.read(limit+1)
    require(len(data)<=limit,'file exceeds bound')
    return data

def digest(data):return hashlib.sha256(data).hexdigest()

def source_binding(expected_controller):
    require(re.fullmatch(r'[0-9a-f]{64}',expected_controller or '') is not None,'controller hash required')
    require(digest(bounded(Path(__file__),2*1024**2))==expected_controller,'controller hash mismatch')
    for name,want in HELPERS.items():require(digest(bounded(ROOT/name,2*1024**2))==want,'runtime verifier source mismatch: '+name)
    raw=bounded(STAGE/'stage-manifest.json',2*1024**2)
    require(digest(raw)==STAGE_MANIFEST,'fixture manifest mismatch')
    manifest=json.loads(raw)
    require(manifest.get('status')=='source_only_unrun' and manifest.get('authority')=='synthetic_only' and manifest.get('production_enabled') is False,'stage authority mismatch')
    expected=manifest.get('staged_sha256')
    require(type(expected) is dict and set(expected)==STAGED,'stage file scope mismatch')
    require({p.name for p in plain(STAGE,'dir').iterdir()}==STAGED|{'stage-manifest.json'},'stage inventory mismatch')
    for name,want in expected.items():require(digest(bounded(STAGE/name,2*1024**2))==want,'fixture source mismatch: '+name)
    return manifest

def work_binding(work,manifest):
    for name,want in manifest['staged_sha256'].items():
        require(digest(bounded(work/name,2*1024**2))==want,'working fixture source changed: '+name)

def require_free(root):
    require(shutil.disk_usage(root).free >= MIN_FREE,'less than 16 GiB free')

def inventory(root,deadline):
    stack=[(root,0)]; entries=0; total=0
    while stack:
        directory,depth=stack.pop()
        require(depth<=6 and time.monotonic()<deadline,'inventory depth or time')
        with os.scandir(directory) as it:
            for ent in it:
                entries+=1
                require(entries<=MAX_ENTRIES and time.monotonic()<deadline,'inventory entries or time')
                require(not ent.is_symlink(),'output symlink refused')
                if ent.is_dir(follow_symlinks=False):stack.append((Path(ent.path),depth+1))
                else:
                    require(ent.is_file(follow_symlinks=False),'nonregular output')
                    size=ent.stat(follow_symlinks=False).st_size
                    require(size<=MAX_FILE and (not ent.name.endswith('.log') or size<=MAX_LOG),'output file bound')
                    total+=size;require(total<=MAX_OUTPUT,'sampled output total bound')

def limits():
    import resource
    resource.setrlimit(resource.RLIMIT_AS,(MAX_AS,MAX_AS))
    resource.setrlimit(resource.RLIMIT_FSIZE,(MAX_FILE,MAX_FILE))
    resource.setrlimit(resource.RLIMIT_CORE,(0,0))

def owned(command,cwd,role,output,deadline,env,extra_log=None):
    require(sys.platform.startswith('linux') and hasattr(os,'waitid') and hasattr(os,'WNOWAIT'),'Linux owned-process API required')
    out=output/(role+'.stdout.log');err=output/(role+'.stderr.log')
    rec={'role':role,'pid':None,'exit':None,'timeout':False,'error':None,'cleanup':None}
    proc=None
    try:
        require(time.monotonic()<deadline,'sequence deadline before launch')
        with out.open('xb') as stdout,err.open('xb') as stderr:
            proc=subprocess.Popen(command,cwd=cwd,env=env,stdin=subprocess.DEVNULL,stdout=stdout,stderr=stderr,start_new_session=True,preexec_fn=limits)
            rec['pid']=proc.pid
            phase_deadline=min(deadline,time.monotonic()+PHASE_SECONDS)
            while True:
                if time.monotonic()>=phase_deadline:
                    rec['timeout']=True;raise TimeoutError('phase deadline')
                if os.waitid(os.P_PID,proc.pid,os.WEXITED|os.WNOHANG|os.WNOWAIT) is not None:break
                for log in (out,err):require(log.stat().st_size<=MAX_LOG,'sampled log bound')
                if extra_log and extra_log.exists():require(not extra_log.is_symlink() and extra_log.stat().st_size<=MAX_LOG,'native log bound')
                inventory(output,phase_deadline)
                time.sleep(.05)
    except Exception as exc:rec['error']=str(exc)[:1024]
    finally:
        if proc:
            try:os.killpg(proc.pid,signal.SIGKILL);rec['cleanup']='group_signal_sent'
            except ProcessLookupError:rec['cleanup']='group_absent'
            except OSError as exc:rec['cleanup']='group_signal_error: '+str(exc)
            try:rec['exit']=proc.wait(timeout=10)
            except subprocess.TimeoutExpired:rec['cleanup']='owned_leader_not_reaped'
        (output/(role+'.process.json')).write_text(json.dumps(rec,indent=2)+'\n',encoding='utf-8')
    require(not rec['error'] and rec['exit']==0 and rec['cleanup'] in ('group_signal_sent','group_absent'),'process failure: '+json.dumps(rec))
    for log in (out,err):require(not DIAGNOSTIC.search(bounded(log,MAX_LOG).decode('utf-8','replace')),'native diagnostic in '+log.name)
    if extra_log:require(not DIAGNOSTIC.search(bounded(extra_log,MAX_LOG).decode('utf-8','replace')),'native log diagnostic')
    return rec

def unique(pairs):
    result={}
    for key,value in pairs:
        if key in result:raise ValueError('duplicate JSON key')
        result[key]=value
    return result

def receipt(path,mode):
    row=json.loads(bounded(path,65536),object_pairs_hook=unique)
    require(type(row) is dict and set(row)=={'schema','mode','result','runtime','port','synthetic_authority'},'receipt schema')
    zero=lambda x:x is False or (type(x) is int and x==0)
    one=lambda x:x is True or (type(x) is int and x==1)
    require(type(row['schema']) is int and row['schema']==1 and row['mode']==mode and row['result']=='PASS' and zero(row['runtime']) and type(row['port']) is int and row['port']==0 and one(row['synthetic_authority']),'receipt failed')
    return row

def require_original_writer_receipt(path, original):
    require(bounded(path,65536)==original,'writer receipt bytes changed')

def record_compiler_diagnostic(output, controller_sha, original_error):
    """Record identities before propagating a compile failure; raw logs remain unchanged."""
    record={'schema':1,'phase':'compile','controller_sha256':controller_sha,'status':'unavailable',
            'error':str(original_error)[:1024]}
    try:
        logs={}
        for stream in ('stdout','stderr'):
            raw=bounded(output/('compile.'+stream+'.log'),MAX_LOG)
            logs[stream]={'bytes':len(raw),'sha256':digest(raw)}
        process_raw=bounded(output/'compile.process.json',65536)
        process=json.loads(process_raw,object_pairs_hook=unique)
        require(type(process) is dict and set(process)=={'role','pid','exit','timeout','error','cleanup'} and process['role']=='compile','invalid compiler process receipt')
        record.update(status='retained',logs=logs,process_sha256=digest(process_raw),process=process)
    except Exception as exc:
        record['retention_error']=str(exc)[:1024]
    (output/'compile-diagnostic.json').write_text(json.dumps(record,sort_keys=True,indent=2)+'\n',encoding='utf-8')
    return record

def validate_payload(work):
    body=bounded(work/'sleep-payload.txt',1048576)
    require(bool(body),'empty payload refused')
    body.decode('ascii')  # fixture values are ASCII; no Unicode equivalence assumed
    raw=bounded(work/'sleep-manifest.json',65536)
    m=json.loads(raw,object_pairs_hook=unique)
    keys={'schema','state','round_id','account','nonce','root_ref','entries','lists','edges','payload_length','payload_md5'}
    require(type(m) is dict and set(m)==keys and type(m['schema']) is int and m['schema']==1 and m['state']=='unverified','payload manifest schema')
    require(m['round_id']=='Round-A' and m['account']=='fixtureaccount' and m['nonce']=='a'*32,'synthetic identity')
    require(type(m['root_ref']) is int and m['root_ref']==1 and type(m['entries']) is int and 1<=m['entries']<=512 and type(m['lists']) is int and 1<=m['lists']<=256 and type(m['edges']) is int and 1<=m['edges']<=4096,'synthetic graph bounds')
    require(type(m['payload_length']) is int and m['payload_length']==len(body) and type(m['payload_md5']) is str and m['payload_md5']==hashlib.md5(body,usedforsecurity=False).hexdigest(),'payload mismatch')
    return {'payload_sha256':digest(body),'manifest_sha256':digest(raw),'manifest':m}

def execute(output,isolated_root,byond,archive,expected_controller):
    require(sys.platform.startswith('linux') and os.geteuid()!=0,'unprivileged Linux only')
    manifest=source_binding(expected_controller)
    isolated_root=plain(isolated_root,'dir');output=Path(output).absolute()
    root_stat=isolated_root.stat()
    require(isolated_root.parent==Path('/tmp') and root_stat.st_uid==os.geteuid() and stat.S_IMODE(root_stat.st_mode)&0o077==0,'private owned /tmp child required')
    require(output.parent==isolated_root and not output.exists() and not output.is_symlink(),'fresh direct-child output required')
    require_free(isolated_root)
    require(time.monotonic()>0,'clock unavailable')
    output.mkdir(mode=0o700)
    work=output/'fixture';work.mkdir(mode=0o700)
    records=[];deadline=time.monotonic()+TOTAL_SECONDS;active_role=None
    try:
        for name in sorted(STAGED):
            with (work/name).open('xb') as f:f.write(bounded(STAGE/name,2*1024**2))
        source_binding(expected_controller)
        work_binding(work,manifest)
        spec=importlib.util.spec_from_file_location('sleep_pinned_runtime',ROOT/'scripts/byond_runtime.py')
        verifier=importlib.util.module_from_spec(spec);spec.loader.exec_module(verifier)
        identity=verifier.verify_linux(byond,archive)
        require(identity.get('version')=='516.1688' and set(identity.get('members',{}))=={'DreamMaker','DreamDaemon','libbyond.so','libext.so'},'runtime identity')
        (output/'runtime-identity.json').write_text(json.dumps(identity,indent=2)+'\n',encoding='utf-8')
        env={'PATH':'/usr/bin:/bin','HOME':str(work),'TMPDIR':str(work),'LANG':'C','LC_ALL':'C','LD_LIBRARY_PATH':str(byond)}
        for role in ('compile','writer','reader'):
            active_role=role
            source_binding(expected_controller)
            work_binding(work,manifest)
            require_free(isolated_root)
            if role != 'compile': require({ext:digest(bounded(work/('fixture'+ext),MAX_FILE)) for ext in ('.dmb','.rsc')}==build_hashes,'compiled fixture changed before '+role)
            require(verifier.verify_linux(byond,archive)==identity,'runtime changed before '+role)
            if role=='compile':
                cmd=[str(byond/'DreamMaker'),'-max_errors','0','fixture.dme'];native=None
            else:
                native=work/(role+'.native.log')
                cmd=[str(byond/'DreamDaemon'),str(work/'fixture.dmb'),'0','-ip','127.0.0.1','-trusted','-params','mode='+role,'-log',native.name]
            records.append(owned(cmd,work,role,output,deadline,env,native))
            source_binding(expected_controller)
            work_binding(work,manifest)
            require_free(isolated_root)
            if role != 'compile': require({ext:digest(bounded(work/('fixture'+ext),MAX_FILE)) for ext in ('.dmb','.rsc')}==build_hashes,'compiled fixture changed after '+role)
            require(verifier.verify_linux(byond,archive)==identity,"runtime changed after "+role)
            inventory(output,deadline)
            if role=='compile':
                log=''.join(bounded(output/('compile.'+kind+'.log'),MAX_LOG).decode('utf-8','replace') for kind in ('stdout','stderr'))
                lines=log.splitlines();banners=[x for x in lines if re.search(r'DM compiler version',x,re.I)]
                results=[x for x in lines if re.search(r'\berrors?\b|\bwarnings?\b',x,re.I)]
                require(banners==['DM compiler version 516.1688'] and len(results)==1 and re.fullmatch(r'fixture\.dmb - 0 errors, 0 warnings(?: \(\d{1,2}/\d{1,2}/\d{2,4} \d{1,2}:\d{2}(?::\d{2})? (?:am|pm)\))?',results[0]) is not None,'compiler identity or diagnostics')
                build_hashes={ext:digest(bounded(work/('fixture'+ext),MAX_FILE)) for ext in ('.dmb','.rsc')}
            elif role=='writer':
                writer_receipt_raw=bounded(work/'writer-result.json',65536)
                writer_receipt=receipt(work/'writer-result.json','writer')
                require_original_writer_receipt(work/'writer-result.json',writer_receipt_raw)
                writer=validate_payload(work)
            else:
                receipt(work/'reader-result.json','reader')
                require_original_writer_receipt(work/'writer-result.json',writer_receipt_raw)
                require(receipt(work/'writer-result.json','writer')==writer_receipt and validate_payload(work)==writer,'reader changed writer receipt, payload or manifest')
        require([r['role'] for r in records]==['compile','writer','reader'] and all(type(r['pid']) is int and r['pid']>0 for r in records) and time.monotonic()<deadline,'process sequence or deadline')
        result={'status':'passed_synthetic','controller_sha256':expected_controller,'stage_manifest_sha256':STAGE_MANIFEST,'runtime':identity,'payload':writer,'writer_receipt_sha256':digest(writer_receipt_raw),'compiled_sha256':build_hashes,'records':records,'native_game_or_authority_proved':False}
        (output/'accepted.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
        return result
    except Exception as exc:
        if active_role=='compile':
            try:record_compiler_diagnostic(output,expected_controller,exc)
            except Exception:pass  # diagnostic failure never replaces the original failure
        (output/'failure.json').write_text(json.dumps({'error':str(exc)[:1024],'records':records},indent=2)+'\n',encoding='utf-8')
        raise

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--run-native',action='store_true',required=True)
    p.add_argument('--output',type=Path,required=True);p.add_argument('--isolated-root',type=Path,required=True)
    p.add_argument('--byond-bin',type=Path,required=True);p.add_argument('--byond-archive',type=Path,required=True)
    p.add_argument('--controller-sha256',required=True)
    a=p.parse_args()
    print(json.dumps(execute(a.output,a.isolated_root,a.byond_bin.absolute(),a.byond_archive.absolute(),a.controller_sha256)))
