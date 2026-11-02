"""Execute only a reviewed exact manifest on a fresh disposable hosted VM.

The CLI is inert without an exact manifest hash and unexpired task request.
No preparation/import/test invokes main or any native process.
"""
import argparse,hashlib,importlib.util,json,os,platform,subprocess,sys,time,uuid
from datetime import datetime
from pathlib import Path
from protocol import LIMITS,admit,digest,require,validate
from supervisor import OwnedRun,facade
from budget import EvidenceBudget
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'scripts'))
from native_fixture import Session,run_native

PORT=59479

def read(path, maximum):
    with Path(path).open('rb') as f:raw=f.read(maximum+1)
    require(len(raw)<=maximum,'Bounded native output read exceeded '+str(path));return raw

def inputs(prepared, manifest, compiled=False, generated=()):
    stage=prepared/'stage'
    actual={p.relative_to(stage).as_posix() for p in stage.rglob('*') if p.is_file()}
    expected=set(manifest['input_files'])
    extras=({'tree_refresh.dmb','tree_refresh.rsc'} if compiled else set()) | set(generated)
    require(expected <= actual and actual <= expected|extras,'Unexpected/missing staged input or output')
    for rel,row in manifest['input_files'].items():
        p=stage/rel;require(p.resolve().is_relative_to(stage.resolve()) and not p.is_symlink(),'Source input path')
        with p.open('rb') as f: hashed=hashlib.file_digest(f,'sha256').hexdigest()
        require(p.stat().st_size==row['bytes'] and hashed==row['sha256'],'Prepared input changed: '+rel)
    return stage

def retain_evidence(stage,output,budget,receipt,persist):
    """Fresh post-cleanup census, bounded copies, then actual combined check."""
    def fail(error):
        receipt.setdefault('retention_errors',[]).append(str(error));receipt['status']='failed'
    remaining=0
    if budget:
        try:
            budget.check(force=True)
            # Reserve bounded final receipt and census/failure envelopes. Copies
            # consume actual remaining shared bytes, never per-file allowances.
            remaining=max(0,budget.state_cap-budget.last_row['state_bytes']-256*1024)
        except BaseException as error:fail(error)
        protocol=('failed-event.json','receipt.json','ready.json','binding.json','events.jsonl')
        candidates=[('stage/'+name,Path(stage)/name) for name in protocol if (Path(stage)/name).is_file()]
        candidates += [(key,path) for key,path in budget.generated.items() if not key.startswith('output/') and path.name not in (*protocol,'need-second-client')]
        if len(candidates)>128:fail('Diagnostic retention file-count bound')
        receipt['diagnostics']=[]
        for key,path in candidates[:128]:
            try:
                original=path.stat().st_size
                maximum=12*1024**2 if key=='stage/events.jsonl' else 1024**2
                count=min(original,maximum,remaining)
                if original>count:
                    # Preserve a small explicit failure prefix, not an unbounded
                    # second copy of a valid but large native event stream.
                    count=min(count,1024**2);fail('Bounded evidence prefix retained: '+key)
                target=Path(output)/('native-'+path.name) if key in ['stage/'+x for x in protocol] else Path(output)/'diagnostics'/key
                require(not target.exists(),'Unexpected evidence copy target')
                if count:
                    target.parent.mkdir(parents=True,exist_ok=True)
                    with path.open('rb') as f:raw=f.read(count)
                    target.write_bytes(raw);remaining-=len(raw)
                else:raw=b''
                receipt['diagnostics'].append(dict(path=key,original_bytes=original,retained_bytes=len(raw),truncated=len(raw)!=original))
            except BaseException as error:fail(error)
        receipt['live_evidence_budget']=dict(records=budget.records,bytes=budget.stream_bytes,last=budget.last_row)
    # The final receipt itself and every actual retained copy are present when
    # the last forced scan runs. No success return may bypass that scan.
    persist()
    if budget:
        try:budget.check(force=True)
        except BaseException as error:
            fail(error);persist()

def execute(prepared, bin_path, reviewed, until, output, run_index):
    prepared=Path(prepared).resolve();output=Path(output).resolve();output.mkdir(parents=True,exist_ok=False)
    receipt=dict(host=dict(os=platform.platform(),machine=platform.machine(),cpu=platform.processor(),cpu_count=os.cpu_count()),status='failed',error=None,native_executed=False,pixels_verified=False,cleanup=None,run_index=run_index)
    runtime=None;budget=None;cleanup_error=None;started=time.monotonic()
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
        budget=EvidenceBudget(stage,output,manifest['input_files'],binary,manifest['toolchain']['files']);budget.check(force=True)
        runtime=OwnedRun(output,hashes,180);runtime.port=PORT;runtime.open()
        runtime.poll()  # Enforce watcher/free-memory/zero-child preflight before launch.
        daemon=runtime.launch([str(binaries['dd.exe']),str(dme.with_suffix('.dmb')),str(PORT),'-trusted','-invisible','-close','-ip','127.0.0.1','-nowebclient','-logself'],stage,'daemon')
        receipt.update(head=head,binding=binding,manifest_sha256=reviewed,native_executed=True)
        persist();connected=0
        while True:
            require(time.time()+30<deadline and time.monotonic()-started<360,'Authorization/aggregate deadline before cleanup reserve')
            if (stage/'ready.json').exists() and connected==0:
                ready=json.loads(read(stage/'ready.json',4096));require(ready==dict(head=head,binding=binding,port=PORT),'Bound ready world identity/port')
                runtime.launch([str(binaries['dreamseeker.exe']),'byond://127.0.0.1:'+str(PORT)],stage,'client1');connected=1
                receipt['supervision']=runtime.summary();persist()
            if (stage/'need-second-client').exists() and connected==1:
                require(read(stage/'need-second-client',16).strip()==b'2','Unexpected client request');runtime.launch([str(binaries['dreamseeker.exe']),'byond://127.0.0.1:'+str(PORT)],stage,'client2');connected=2
                receipt['supervision']=runtime.summary();persist()
            runtime.poll()  # One bounded JSONL append, no growing receipt rewrite.
            budget.check()
            if (stage/'receipt.json').exists():
                budget.check(force=True)
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
        budget.check(force=True)
        inputs(prepared,manifest,compiled=True,generated=[name.removeprefix('stage/') for name in budget.generated if name.startswith('stage/')])
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
            receipt['supervision']=runtime.summary()
        receipt['elapsed_total']=time.monotonic()-started
        retain_evidence(locals().get('stage'),output,budget,receipt,persist)
        if cleanup_error:raise cleanup_error
    return receipt

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--prepared',type=Path,required=True);p.add_argument('--bin',type=Path,required=True);p.add_argument('--reviewed-manifest',required=True);p.add_argument('--authorized-until',required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--run-index',type=int,required=True);a=p.parse_args()
    result=execute(a.prepared,a.bin,a.reviewed_manifest,a.authorized_until,a.output,a.run_index)
    sys.exit(0 if result['status']=='passed' else 1)
