"""Two-phase, same-name terminal receipt persistence; stdlib only.

Call checkpoint immediately after owned cleanup, BEFORE optional diagnostics.
Call finalize after diagnostics. Never infer cleanup from absent rows. Caller must
use the returned status. Final artifact allowlist/count/byte validation still applies.
"""
import hashlib
import json
import os
import time
from pathlib import Path

CAP = 65536
FIELD_CAP = 16384
EVIDENCE = {'source-receipt.json': CAP, 'filming-take.json': CAP,
            'filming-checks.txt': CAP, 'filming-viewport.txt': 16384,
            'filming-stop.txt': CAP}
REQUIRED = tuple(name for name in EVIDENCE if name != 'filming-stop.txt')


def packed(value):
    return (json.dumps(value, ensure_ascii=True, separators=(',', ':'), allow_nan=False)+'\n').encode('ascii')


def atomic(path, data, before_replace=None):
    temporary = path.with_name(path.name + '.pending')
    if temporary.exists() or temporary.is_symlink() or path.is_symlink():
        raise ValueError('Unsafe persistence destination')
    try:
        with temporary.open('xb') as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        if before_replace is not None:
            before_replace()
        os.replace(temporary, path)
    finally:
        if temporary.exists():
            temporary.unlink()


def cleanup_snapshot(result):
    rows = result.get('cleanup')
    if type(rows) is not list or len(rows) > 3:
        raise ValueError('Malformed scene cleanup')
    seen = set()
    for row in rows:
        if type(row) is not dict or row.get('role') not in ('compiler','server','client') or row['role'] in seen or type(row.get('all_exited')) is not bool:
            raise ValueError('Malformed cleanup role/result')
        seen.add(row['role'])
    setup_result = result.get('directx_setup', {})
    if type(setup_result) is not dict:
        raise ValueError('Malformed setup result')
    setup = setup_result.get('cleanup')
    if setup is not None and (type(setup) is not dict or type(setup.get('all_exited')) is not bool):
        raise ValueError('Malformed setup cleanup')
    if len(packed(rows)) > 12000 or len(packed(setup)) > 12000:
        raise ValueError('Cleanup evidence cap')
    # JSON snapshot preserves every supplied cleanup field/value, never synthesizes
    # primitive success or omits errors/identity. Missing setup stays explicit null.
    return json.loads(packed(rows)), json.loads(packed(setup))


def checkpoint(result, output):
    """Persist fallback first. Failure status is intentional until final commit."""
    output = Path(output)
    terminal = {'status':'FAILED_PERSISTENCE_PENDING_FINALIZATION', 'persistence_complete':False,
                'native_status_before_persistence':str(result.get('status','MISSING'))[:128]}
    try:
        terminal['cleanup'], terminal['directx_cleanup'] = cleanup_snapshot(result)
    except (ValueError,TypeError,OverflowError) as error:
        terminal.update(cleanup=None, directx_cleanup=None,
                        cleanup_evidence_error=str(error)[:160])
    original_error=result.get('error')
    if type(original_error) is str:
        terminal['original_error']=original_error[:1024]
        terminal['original_error_truncated']=len(original_error)>1024
    for key in ('head','run_id','scene_revision','engine'):
        value=result.get(key)
        terminal[key]=value if type(value) is str and len(value)<=128 else None
    atomic(output/'receipt.json', packed(terminal))
    return terminal


def file_summary(data):
    return {'bytes':len(data), 'sha256':hashlib.sha256(data).hexdigest()}


def finalize(result, source, output, terminal, pass_status,
             reserved_file_count=5, reserved_bytes=5*1048576, *,
             started=None, clock=time.monotonic):
    """Finalize using existing filenames; no spill files or new artifact allowance.

    Reservation defaults cover acquisition/dependency and DirectX receipt+2 logs,
    each under the existing1MiB/file bound. Caller can supply exact remaining
    reservation if those files already reside in output. No cap may be raised.
    """
    source,output=Path(source),Path(output)
    def elapsed():
        if started is None:
            return None  # Offline helper tests only; native caller supplies origin.
        value=clock()-started
        if not 0 <= value < float('inf'):
            raise ValueError('Invalid elapsed clock')
        return value
    try:
        if type(reserved_file_count) is not int or not 0<=reserved_file_count<=100 or type(reserved_bytes) is not int or not 0<=reserved_bytes<=16*1024**2:
            raise ValueError('Invalid artifact reservation')
        if terminal.get('cleanup_evidence_error'):
            raise ValueError('Invalid cleanup evidence; cannot finalize')
        scene_cleanup,setup_cleanup=cleanup_snapshot(result)
        if scene_cleanup != terminal['cleanup'] or setup_cleanup != terminal['directx_cleanup']:
            raise ValueError('Cleanup changed after checkpoint')
        evidence={}
        evidence_errors=[]
        for name,cap in EVIDENCE.items():
            # Preserve every other valid named file even if one is unavailable.
            # At most five fixed names, each bounded error text; no broad scan.
            try:
                path=source/name
                if path.is_symlink():
                    raise ValueError('Symlink evidence rejected')
                if not path.exists():
                    if result.get('status')==pass_status and name in REQUIRED:
                        raise ValueError('Missing required evidence')
                    continue
                if not path.is_file() or path.stat().st_size>cap:
                    raise ValueError('Evidence cap/type')
                data=path.read_bytes()
                if len(data)>cap:
                    raise ValueError('Evidence grew beyond cap')
                data.decode('utf-8',errors='strict')
                atomic(output/name,data)  # Exact bytes; preserve original newlines.
                if (output/name).read_bytes()!=data:
                    raise ValueError('Evidence copy verification failed')
                evidence[name]=file_summary(data)
            except Exception as error:
                evidence_errors.append({'file':name,'error':(type(error).__name__+': '+str(error))[:160]})
        if evidence_errors:
            raise ValueError('One or more named evidence copies failed')
        if result.get('status')==pass_status:
            if {r['role'] for r in scene_cleanup}!={'compiler','server','client'} or not all(r['all_exited'] is True for r in scene_cleanup) or not setup_cleanup or setup_cleanup['all_exited'] is not True:
                raise ValueError('PASS lacks complete successful owned cleanup')
            for name,key in [('source-receipt.json','source'),('filming-take.json','take')]:
                if json.loads((output/name).read_bytes()) != result.get(key):
                    raise ValueError('Required evidence binding mismatch: '+name)
            checks=(output/'filming-checks.txt').read_text(encoding='utf-8').strip()
            if checks != result.get('native_checks'):
                raise ValueError('Checks evidence binding mismatch')
            if evidence['filming-viewport.txt']['sha256'] != result.get('viewport_evidence',{}).get('sha256'):
                raise ValueError('Viewport evidence binding mismatch')
        final={}
        for key,value in result.items():
            if type(key) is not str or len(key)>128:
                raise ValueError('Invalid receipt field name')
            if key=='native_checks':
                if 'filming-checks.txt' not in evidence:
                    raise ValueError('Checks text has no exact retained file')
                final[key]={'retained_file':'filming-checks.txt',**evidence['filming-checks.txt']}
                continue
            if key=='failed_capture_readiness' and type(value) is dict and 'native_checks' in value:
                value=dict(value)
                if value['native_checks'] is not None:
                    if 'filming-checks.txt' not in evidence:
                        raise ValueError('Failure checks lack exact file')
                    value['native_checks']={'retained_file':'filming-checks.txt',**evidence['filming-checks.txt']}
            encoded=packed(value)
            if len(encoded)>FIELD_CAP:
                raise ValueError('Receipt field cap: '+key)
            final[key]=value
        final['retained_evidence']=evidence
        final['persistence_complete']=True
        raw=packed(final)
        if len(raw)>CAP:
            raise ValueError('Compact receipt cap exceeded')
        files=[]
        for path in output.iterdir():
            if path.name=='environment' and path.is_dir() and not path.is_symlink():
                continue  # Exact owned runtime directory excluded by workflow.
            files.append(path)
        if any(not p.is_file() or p.is_symlink() or p.stat().st_size>1048576 for p in files):
            raise ValueError('Output artifact type/file cap')
        size=sum(p.stat().st_size for p in files if p.name!='receipt.json')+len(raw)
        if len(files)+reserved_file_count>100 or size+reserved_bytes>16*1024**2:
            raise ValueError('Artifact count/byte cap')
        observed=elapsed()
        if observed is not None:
            final['elapsed_seconds']=observed
            final['persistence_timing_scope']='sample immediately before final receipt I/O; post-I/O sample emitted to terminal log; I/O is not interruptible'
            if observed >= 180:
                raise TimeoutError('Total budget exceeded before final receipt commit')
            raw=packed(final)
            if len(raw)>CAP:
                raise ValueError('Timed compact receipt cap exceeded')
            actual_size=sum(p.stat().st_size for p in files if p.name!='receipt.json')+len(raw)
            if actual_size+reserved_bytes>16*1024**2:
                raise ValueError('Timed artifact byte cap')
        def admit_replace():
            nonlocal observed
            current=elapsed()
            observed=current
            if current is not None and current >= 180:
                raise TimeoutError('Total budget exceeded during receipt flush before replacement')
        atomic(output/'receipt.json',raw,before_replace=admit_replace)
        observed=elapsed()
        if observed is not None:
            if observed >= 180:
                raise TimeoutError('Total budget exceeded during final receipt persistence')
            print(json.dumps({'marker':'receipt_persistence_terminal_v1','receipt_sha256':hashlib.sha256(raw).hexdigest(),'persistence_post_write_elapsed_seconds':observed,'total_limit_seconds':180,'status':final['status']},separators=(',',':')))
        return final
    except Exception as error:
        failed=dict(terminal)
        failed['status']='FAILED_TOTAL_BUDGET' if isinstance(error,TimeoutError) else 'FAILED_PERSISTENCE'
        if 'observed' in locals() and observed is not None:
            failed['elapsed_seconds']=observed
        if 'evidence_errors' in locals() and evidence_errors:
            failed['evidence_errors']=evidence_errors
        if 'evidence' in locals():
            failed['retained_evidence']=evidence
        failed['persistence_error']=(type(error).__name__+': '+str(error))[:512]
        # If invalidation fails after a completed PASS write, that file may be stale.
        # Acceptance additionally requires the matching success marker and zero exit.
        try:
            atomic(output/'receipt.json',packed(failed))
        except OSError:
            pass
        if started is not None:
            print(json.dumps({'persistence_terminal_elapsed_seconds':elapsed(),'status':failed['status'],'total_limit_seconds':180},separators=(',',':')))
        return failed

