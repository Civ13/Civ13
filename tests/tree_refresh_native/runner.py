"""Execute only a reviewed exact manifest on a fresh disposable hosted VM.

The CLI is inert without an exact manifest hash and unexpired task request.
No preparation/import/test invokes main or any native process.
"""
import argparse,hashlib,importlib.util,json,os,subprocess,sys,time,uuid
from datetime import datetime
from pathlib import Path
from protocol import LIMITS,admit,digest,require,validate
from supervisor import OwnedRun,facade
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'scripts'))
from native_fixture import Session,run_native

PORT=59479

def read(path, maximum):
    with Path(path).open('rb') as f:raw=f.read(maximum+1)
    require(len(raw)<=maximum,'Bounded native output read exceeded '+str(path));return raw

def inputs(prepared, manifest, compiled=False):
    stage=prepared/'stage'
    actual={p.relative_to(stage).as_posix() for p in stage.rglob('*') if p.is_file()}
    expected=set(manifest['input_files'])
    extras={'tree_refresh.dmb','tree_refresh.rsc'} if compiled else set()
    require(expected <= actual and actual <= expected|extras,'Unexpected/missing staged input or output')
    for rel,row in manifest['input_files'].items():
        p=stage/rel;require(p.resolve().is_relative_to(stage.resolve()) and not p.is_symlink(),'Source input path')
        with p.open('rb') as f: hashed=hashlib.file_digest(f,'sha256').hexdigest()
        require(p.stat().st_size==row['bytes'] and hashed==row['sha256'],'Prepared input changed: '+rel)
    return stage

def execute(prepared, bin_path, reviewed, until, output, run_index):
    prepared=Path(prepared).resolve();output=Path(output).resolve();output.mkdir(parents=True,exist_ok=False)
    receipt=dict(status='failed',error=None,native_executed=False,pixels_verified=False,cleanup=None,run_index=run_index)
    runtime=None;cleanup_error=None;started=time.monotonic()
    def persist(): (output/'execution-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    try:
        raw=read(prepared/'tree-native-manifest.json',12*1024**2);manifest=json.loads(raw);head=manifest['head']
        deadline=admit(head,raw,reviewed,until,os.environ)
        require(run_index in (1,2,3),'At most three reviewed independent runs; no automatic retry')
        require(subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()==head,'Execution source head changed')
        require(not subprocess.check_output(['git','status','--porcelain'],cwd=ROOT).strip(),'Execution source dirty')
        stage=inputs(prepared,manifest)
        # Drop redundant archival indices before measured native supervision.
        for key in ('original_git_files','stage_files'):manifest.pop(key,None)
        hashes=manifest['toolchain']['binary_hashes'];binary=Path(bin_path).resolve()
        for rel,row in manifest['toolchain']['files'].items():
            p=binary/rel;require(p.resolve().is_relative_to(binary) and p.stat().st_size==row['bytes'] and digest(p.read_bytes())==row['sha256'],'Pinned toolchain input changed')
        binaries={p.name.lower():p for p in binary.iterdir() if p.is_file()}
        # No credential or existing user session is read; VM host restrictions are
        # checked above before even constructing the native facade.
        session=Session(output/'compiler-supervision',head,backend_factory=facade)
        dme=prepared/manifest['dme'];result=run_native(session,[str(binaries['dm.exe']),'-max_errors','0',str(dme)],cwd=stage,phase='compile',timeout=120,artifacts=[dme.with_suffix('.dmb'),dme.with_suffix('.rsc')])
        (output/'compiler.log').write_text(result.stdout+result.stderr)
        require(result.returncode==0 and 'DM compiler version 516.1688' in result.stdout+result.stderr and '0 errors, 0 warnings' in result.stdout+result.stderr,'Pinned native compile failed/warned')
        require(time.monotonic()-started<150 and time.time()+210<deadline,'Compiler/aggregate remaining budget')
        inputs(prepared,manifest,compiled=True)
        receipt['compiled_artifacts']={}
        for p in (dme.with_suffix('.dmb'),dme.with_suffix('.rsc')):
            require(p.is_file(),'Missing compiled native artifact')
            with p.open('rb') as f:hashed=hashlib.file_digest(f,'sha256').hexdigest()
            receipt['compiled_artifacts'][p.name]=dict(bytes=p.stat().st_size,sha256=hashed)
        binding=uuid.uuid4().hex
        for name in ('receipt.json','ready.json','events.jsonl','binding.json','need-second-client'):
            require(not (stage/name).exists(),'Stale native protocol output')
        (stage/'binding.json').write_text(json.dumps(dict(head=head,binding=binding)))
        runtime=OwnedRun(output,hashes,180);runtime.port=PORT;runtime.open()
        daemon=runtime.launch([str(binaries['dd.exe']),str(dme.with_suffix('.dmb')),str(PORT),'-trusted','-invisible','-ip','127.0.0.1','-nowebclient','-logself'],stage,'daemon')
        receipt.update(head=head,binding=binding,manifest_sha256=reviewed,native_executed=True)
        persist();connected=0
        while True:
            require(time.time()+30<deadline and time.monotonic()-started<360,'Authorization/aggregate deadline before cleanup reserve')
            if (stage/'ready.json').exists() and connected==0:
                ready=json.loads(read(stage/'ready.json',4096));require(ready==dict(head=head,binding=binding,port=PORT),'Bound ready world identity/port')
                runtime.launch([str(binaries['dreamseeker.exe']),'byond://127.0.0.1:'+str(PORT)],stage,'client1');connected=1
            if (stage/'need-second-client').exists() and connected==1:
                require(read(stage/'need-second-client',16).strip()==b'2','Unexpected client request');runtime.launch([str(binaries['dreamseeker.exe']),'byond://127.0.0.1:'+str(PORT)],stage,'client2');connected=2
            observations=runtime.poll();receipt['supervision']=dict(samples=runtime.samples,known_children=[dict(name=n,identity=runtime.a.identity(p)) for n,p in runtime.children]);persist()
            logs=[p for p in output.rglob('*.log') if p.is_file()]
            require(sum(p.stat().st_size for p in logs)+sum((stage/n).stat().st_size for n in ('events.jsonl','receipt.json') if (stage/n).exists())<=LIMITS['evidence_bytes'],'Generated log/state cap16MiB')
            if (stage/'receipt.json').exists():
                native=json.loads(read(stage/'receipt.json',65536));receipt['native_receipt']=native
                if not runtime.a.exited(daemon):
                    time.sleep(.1);continue
                receipt['daemon_exit']=runtime.a.finish(daemon)
                require(receipt['daemon_exit']['exit_code']==0,'Native daemon nonzero exit')
                require((stage/'events.jsonl').is_file(),'Native stopped before first event: '+str(native.get('error')))
                rows=[json.loads(line) for line in read(stage/'events.jsonl',12*1024**2).splitlines() if line]
                receipt['native_receipt']=native;receipt['analysis']=validate(native,rows,head,binding);receipt['status']='passed' if receipt['analysis']['cost_accepted'] else 'measurement_incomplete';break
            require(not runtime.a.exited(daemon),'Daemon exited without final failure/success receipt')
            time.sleep(.1)
        spec=importlib.util.spec_from_file_location('tree_fixture_diagnostics',ROOT/'tests/human_subtile/run.py')
        diagnostics=importlib.util.module_from_spec(spec);spec.loader.exec_module(diagnostics)
        diagnostics.inspect_logs(stage)
        for path in output.glob('*.log'):
            require(path.stat().st_size<=4*1024**2,'Native output log cap')
            require(not diagnostics.DIAGNOSTICS.search(path.read_text(errors='replace')),'Native diagnostic in '+path.name)
        for name,row in receipt['compiled_artifacts'].items():
            with (stage/name).open('rb') as f:require(hashlib.file_digest(f,'sha256').hexdigest()==row['sha256'],'Compiled artifact changed during runtime')
        receipt['elapsed_before_cleanup']=time.monotonic()-started
    except BaseException as error:
        receipt.update(status='failed',error=str(error));raise
    finally:
        if runtime:
            try:receipt['cleanup']=runtime.cleanup()
            except BaseException as error:cleanup_error=error;receipt.update(status='failed',cleanup_error=str(error))
            receipt['supervision_samples']=runtime.samples
        for name in ('events.jsonl','failed-event.json','receipt.json','ready.json','binding.json'):
            if 'stage' in locals() and (stage/name).is_file():
                try:(output/('native-'+name)).write_bytes(read(stage/name,LIMITS['evidence_bytes']))
                except BaseException as retention:receipt.setdefault('retention_errors',[]).append(str(retention));receipt['status']='failed'
        if 'stage' in locals():
            try:
                logs=list(stage.rglob('*.log'))+list((stage/'data/logs/runtime').rglob('*.txt'))
                require(len(logs)<=128 and sum(p.stat().st_size for p in logs)<=LIMITS['evidence_bytes'],'Native diagnostic retention cap')
                for p in logs:
                    target=output/'diagnostics'/p.relative_to(stage);target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(read(p,4*1024**2))
            except BaseException as retention:receipt.setdefault('retention_errors',[]).append(str(retention));receipt['status']='failed'
        receipt['elapsed_total']=time.monotonic()-started;persist()
        if cleanup_error:raise cleanup_error
    return receipt

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--prepared',type=Path,required=True);p.add_argument('--bin',type=Path,required=True);p.add_argument('--reviewed-manifest',required=True);p.add_argument('--authorized-until',required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--run-index',type=int,required=True);a=p.parse_args()
    result=execute(a.prepared,a.bin,a.reviewed_manifest,a.authorized_until,a.output,a.run_index)
    sys.exit(0 if result['status']=='passed' else 1)
