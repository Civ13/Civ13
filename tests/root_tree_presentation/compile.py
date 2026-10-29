"""Compile a reviewed DME with the existing bounded backend; never start a game."""
import argparse,hashlib,importlib.util,json,os,re,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'scripts'))
from native_fixture import Session,run_native

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
    spec=importlib.util.spec_from_file_location('reviewed_backend',ROOT/'tests/human_subtile/run-diagonal.py')
    helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
    session=Session(a.output/'supervisor',a.head,backend_factory=helper.current_backend) if os.name=='nt' else None
    dme=a.dme.resolve();exe=a.byond_bin/('dm.exe' if os.name=='nt' else 'DreamMaker')
    receipt={'head':a.head,'dme':str(dme),'compile_only':True,'runtime_executed':False,
       'dme_sha256':hashlib.sha256(dme.read_bytes()).hexdigest()}
    manifest=dme.parent/'source-manifest.json'
    if manifest.is_file():receipt['source_manifest_sha256']=hashlib.sha256(manifest.read_bytes()).hexdigest()
    try:
        result=run_native(session,[str(exe),'-max_errors','0',str(dme)],cwd=dme.parent,phase='compile',timeout=120,
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
    (a.output/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print(log)
    return 0 if ok else 1

if __name__=='__main__':raise SystemExit(main())
