"""Compile a reviewed DME with the existing bounded backend; never start a game."""
import argparse,hashlib,importlib.util,json,os,re,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'scripts'))
from native_fixture import Session,run_native
spec=importlib.util.spec_from_file_location('tree_compile_provenance',Path(__file__).with_name('provenance.py'))
provenance=importlib.util.module_from_spec(spec);spec.loader.exec_module(provenance)

def source_head(expected):
    if not re.fullmatch('[0-9a-f]{40}',expected):raise ValueError('Full source head required')
    actual=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True,timeout=15).strip()
    if actual!=expected:raise ValueError('Compiler source head does not match checkout')
    if subprocess.run(['git','diff','--quiet','HEAD'],cwd=ROOT,timeout=15).returncode:
        raise ValueError('Commit source before exact-head compilation')
    return actual

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--dme',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    p.add_argument('--byond-bin',type=Path,required=True);p.add_argument('--head',required=True)
    a=p.parse_args();source_head(a.head);a.output.mkdir(exist_ok=False,parents=True)
    dme=a.dme.resolve();exe=a.byond_bin/('dm.exe' if os.name=='nt' else 'DreamMaker')
    manifest=dme.parent/'source-manifest.json'
    fixture=manifest.is_file()
    inputs=None
    if fixture:
        if os.name!='nt' or dme.name!='fixture.dme':raise ValueError('Fixture acceptance requires the existing retained Windows compiler')
        inputs=provenance.validate_stage(dme.parent,a.head)
        provenance.require_fresh_outputs(dme.parent)
    spec=importlib.util.spec_from_file_location('reviewed_backend',ROOT/'tests/human_subtile/run-diagonal.py')
    helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
    session=Session(a.output/'supervisor',a.head,backend_factory=helper.current_backend) if os.name=='nt' else None
    command=[str(exe),'-max_errors','0',str(dme)]
    receipt={'head':a.head,'dme':str(dme),'compile_only':True,'runtime_executed':False,
       'dme_sha256':hashlib.sha256(dme.read_bytes()).hexdigest()}
    if manifest.is_file():receipt['source_manifest_sha256']=hashlib.sha256(manifest.read_bytes()).hexdigest()
    try:
        result=run_native(session,command,cwd=dme.parent,phase='compile',timeout=120,
           artifacts=[dme.with_suffix('.dmb'),dme.with_suffix('.rsc')])
    except Exception as error:
        receipt.update(passed=False,status='blocked_or_failed',reason=str(error))
        (a.output/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
        raise
    log=result.stdout+result.stderr;(a.output/'compiler.log').write_text(log)
    source_head(a.head)
    ok=result.returncode==0 and 'DM compiler version 516.1688' in log and '0 errors, 0 warnings' in log
    receipt.update(passed=ok,exit_code=result.returncode,status='passed' if ok else 'failed')
    receipt['artifacts']={str(p.name):{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
       for p in [dme.with_suffix('.dmb'),dme.with_suffix('.rsc')] if p.is_file()}
    if fixture:
        try:
            if provenance.validate_stage(dme.parent,a.head)!=inputs:raise ValueError('Compiler inputs changed during execution')
            audit=(a.output/'supervisor/containment.json').read_bytes()
            log_bytes=log.encode()
            receipt.update(schema=3,kind='root_tree_compile',input_binding=inputs,command=command,
                compiler_sha256=hashlib.sha256(exe.read_bytes()).hexdigest(),
                compiler_log_sha256=hashlib.sha256(log_bytes).hexdigest(),supervisor_sha256=hashlib.sha256(audit).hexdigest())
            (dme.parent/'compile.log').write_bytes(log_bytes)
            (dme.parent/'compile-supervisor.json').write_bytes(audit)
            (dme.parent/'compile.receipt.json').write_bytes((json.dumps(receipt,indent=2)+'\n').encode())
            if ok:provenance.validate_compile(dme.parent,a.head)
        except Exception as error:
            receipt.update(passed=False,status='failed',reason=str(error))
            (a.output/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
            (dme.parent/'compile.receipt.json').write_bytes((json.dumps(receipt,indent=2)+'\n').encode())
            raise
    (a.output/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print(log)
    return 0 if ok else 1

if __name__=='__main__':raise SystemExit(main())
