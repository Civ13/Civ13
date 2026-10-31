"""Read-only pinned system DLL check: never install or copy a runtime."""
import argparse, json, os, re
from pathlib import Path
import acquire
from directx_setup import system_dlls

def binding():
    from activation import require_runtime
    require_runtime()
    fields={k:os.environ.get(k,'') for k in ('GITHUB_SHA','GITHUB_RUN_ID','GITHUB_RUN_ATTEMPT','GITHUB_JOB','GITHUB_REF')}
    if not (re.fullmatch('[0-9a-f]{40}',fields['GITHUB_SHA']) and re.fullmatch('[1-9][0-9]*',fields['GITHUB_RUN_ID']) and fields['GITHUB_RUN_ATTEMPT']=='1'):
        raise RuntimeError('unbound_readonly_dependency_probe')
    return fields

def probe(output):
    output=Path(output).absolute()
    acquire._plain_ancestors(output.parent)
    if output.exists() or output.is_symlink(): raise RuntimeError('fresh_dependency_receipt_required')
    context=binding()
    try:
        components=system_dlls()
        result={'schema':1,'status':'AVAILABLE_PINNED_SYSTEM_COMPONENTS','binding':context,'system_dlls':components,'installed':False,'runtime_verified':False}
    except Exception as error:
        result={'schema':1,'status':'BLOCKED_SYSTEM_COMPONENTS','binding':context,'error_class':type(error).__name__,'installed':False,'runtime_verified':False}
    raw=(json.dumps(result,sort_keys=True)+'\n').encode()
    if len(raw)>=8192: raise RuntimeError('dependency_receipt_bound')
    with output.open('xb') as stream:
        stream.write(raw);stream.flush();os.fsync(stream.fileno())
    return result

def verify(output):
    output=Path(output).absolute()
    acquire._plain_ancestors(output.parent)
    record=json.loads(acquire._read(output,8192))
    if not (record.get('schema')==1 and record.get('status')=='AVAILABLE_PINNED_SYSTEM_COMPONENTS' and
            record.get('binding')==binding() and record.get('installed') is False and
            record.get('runtime_verified') is False and record.get('system_dlls')==system_dlls()):
        raise RuntimeError('system_directx_not_exact_or_changed')
    return record

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    r=probe(a.output);print(json.dumps(r,sort_keys=True))
    raise SystemExit(0 if r['status']=='AVAILABLE_PINNED_SYSTEM_COMPONENTS' else 2)
