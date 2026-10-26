"""Held short-burst recording implementation; no native activation in this package.

Every sample retains synchronous native safety checks. Only full-pixel validation,
PNG encoding and file writes are delayed until acquisition ends (<=1 second) plus a bounded <=0.5s end-config handshake.
"""
import hashlib,json,math,time
from pathlib import Path
from capture import acquire_owned,_finalize_acquisition,PixelHeuristicFailure
from receipt_persistence import atomic

NATIVE_RELEASED=True
SIZE=(480,480)
MAX_COUNT=20
MAX_RAW_BYTES=13824000
MAX_FRAME_TOTAL=15*1024**2
MAX_FRAME_BYTES=1024**2
CHECKPOINTS=['immediately_before_bitblt','immediately_after_bitblt']
CLEANUP='owned GDI/input handles released; thread DPI restored'

def require(ok,reason):
    if not ok:raise RuntimeError(reason)

def configuration(value):
    keys={'world_fps','world_tick_lag','client_fps','client_tick_lag','same_admitted_client'}
    require(type(value) is dict and set(value)==keys,'Malformed cadence configuration')
    require(value['same_admitted_client'] is True,'Cadence client not admitted')
    for key in keys-{'same_admitted_client'}:
        v=value[key];require(type(v) in (int,float) and math.isfinite(v) and v>=0,'Invalid cadence number')
    w,c=value['world_fps'],value['client_fps']
    require(1<=w<=120 and (c==0 or 1<=c<=120),'Unsupported configured rate; no fallback')
    require(abs(w*value['world_tick_lag']-10)<1e-5,'World tick relation')
    require((c==0 and value['client_tick_lag']==0) or abs(c*value['client_tick_lag']-10)<1e-5,'Client tick relation')
    return dict(value,effective_fps=c or w)

def owner_of(c):
    return dict(pid=c['identity']['pid'],creation_filetime=c['identity']['creation_filetime'],hwnd=c['window']['hwnd'])

def record_burst(*args,**kwargs):
    require(NATIVE_RELEASED,'SOURCE-ONLY HOLD: native burst not admitted')
    return _record_burst(*args,**kwargs)

def _record_burst(adapter,process,output,title,watch,read_configuration,admission_configuration,
                  admitted_owner,scene_started,acquire=acquire_owned,validate=_finalize_acquisition,
                  clock=time.monotonic,sleep=time.sleep):
    """Private test seam. Parent owns process cleanup and terminal receipt proof.

    read_configuration must be narrowly wired to the same admitted client's bounded
    numeric receipt; callbacks are not a substitute for native ownership checks.
    scene_started is the original overall work origin, never reset for this burst.
    """
    output=Path(output);manifest=output/'cadence-recording.json'
    require(output.is_dir() and not output.is_symlink() and not manifest.exists() and not manifest.is_symlink() and not any(output.glob('cadence-*.png')),'Fresh bounded output required')
    result=dict(schema=2,status='FAILED_DIAGNOSTIC_ONLY',deferred_validation=True,rejected=True,width=480,height=480,frames=[],cadence_samples=[],raw_buffer_bytes=0)
    batch=[];total_raw=0;total_png=0;last=None;inflight=None;validation_index=None
    def check_work():
        watch()
        require(0<=clock()-scene_started<165,'Original work deadline exceeded')
    try:
        check_work();config=configuration(admission_configuration);fps=config['effective_fps'];count=min(MAX_COUNT,max(1,math.floor(fps)));interval=1/fps
        require(type(admitted_owner) is dict and set(admitted_owner)=={'pid','creation_filetime','hwnd'} and all(type(v) is int and v>0 for v in admitted_owner.values()),'Malformed admitted owner')
        result.update(fps_config=config,owner=dict(admitted_owner),frame_count=count,
                      rejection_timing='Native safety immediate per sample; all-frame content validation deferred <=one-second acquisition plus <=0.5s configuration handshake; no acceptance before scene/cleanup/terminal proof',
                      configured_cadence_only=True,rendered_presentation_rate_measured=False)
        result['cadence_samples'].append(dict(phase='admission',config=config,owner=dict(admitted_owner)))
        start_config=configuration(read_configuration());require(start_config==config,'Cadence changed before burst')
        result['cadence_samples'].append(dict(phase='burst_start',config=start_config,owner=dict(admitted_owner)))
        origin=clock()
        for index in range(count):
            due=origin+index/fps
            while clock()<due:
                check_work();sleep(min(.002,max(0,due-clock())))
            check_work();begin=clock();last=dict(index=index,due_seconds=due-origin,begin_seconds=begin-origin)
            require(begin-due<interval,'Acquisition start missed native interval; no catch-up')
            c=acquire(adapter,process,title,SIZE)
            inflight=c
            end=clock();last['end_seconds']=end-origin;check_work()
            require(end>=begin and end-due<interval,'Acquisition missed native interval; no duplicate frames')
            require(c.get('status')=='OWNED_RAW_UNVALIDATED' and c.get('checkpoints')==CHECKPOINTS and c.get('cleanup')==CLEANUP,'Missing native guard/cleanup proof')
            require((c.get('width'),c.get('height'))==SIZE and c['window']['client_rect']==[0,0,480,480] and owner_of(c)==admitted_owner,'Frame owner/geometry mismatch')
            require(type(c.get('rgb')) is bytes and len(c['rgb'])==691200,'Exact raw RGB required')
            total_raw+=len(c['rgb']);require(total_raw<=MAX_RAW_BYTES,'Raw batch byte cap')
            batch.append((c,dict(last)))
            inflight=None
        result['acquisition_end_seconds']=clock()-origin
        require(result['acquisition_end_seconds']<=1,'One-second acquisition bound')
        handshake_started=clock()
        end_config=configuration(read_configuration());require(end_config==config,'Cadence changed during burst')
        require(clock()-handshake_started<=.5,'End configuration handshake deadline')
        result['cadence_samples'].append(dict(phase='burst_end',config=end_config,owner=dict(admitted_owner)))
        result['raw_buffer_bytes']=total_raw
        result['validation_begin_seconds']=clock()-origin
        require(result['validation_begin_seconds']<=1.5,'Deferred content rejection bound')
        for index,(c,timing) in enumerate(batch):
            validation_index=index
            check_work();name=f'cadence-{index:03d}.png';path=output/name
            v=validate(c,path)
            check_work()
            require(v.get('status')=='captured' and owner_of(v)==admitted_owner and v.get('checkpoints')==CHECKPOINTS and v.get('cleanup')==CLEANUP,'Validation/native proof mismatch')
            require(v.get('viewport_border',{}).get('accepted') is True,'Every frame requires border validation')
            require(path.is_file() and not path.is_symlink(),'Missing real frame')
            size=path.stat().st_size;require(0<size<=MAX_FRAME_BYTES,'PNG per-frame cap')
            total_png+=size;require(total_png<=MAX_FRAME_TOTAL,'PNG batch byte cap')
            digest=hashlib.sha256(path.read_bytes()).hexdigest();require(digest==v['png_sha256'] and size==v['png_bytes'],'Frame persistence mismatch')
            result['frames'].append(dict(**timing,name=name,sha256=digest,bytes=size,width=480,height=480,**admitted_owner,
                checkpoints=list(CHECKPOINTS),native_cleanup=CLEANUP,pixel_diagnostics=v['pixel_diagnostics'],viewport_border=v['viewport_border']))
            c.pop('rgb')  # Release each buffer after exact validation/persistence.
        require(len(result['frames'])==count,'Incomplete validated batch')
        check_work();result.update(status='VALIDATED_PENDING_SCENE_CLEANUP',rejected=False,total_frame_bytes=total_png)
        return result
    except BaseException as error:
        result.update(status='FAILED_DIAGNOSTIC_ONLY',rejected=True,error=(type(error).__name__+': '+str(error))[:512],last_attempt_timing=last)
        if validation_index is not None:
            result['failed_validation_index']=validation_index
            result['validation_failure_elapsed_seconds']=clock()-origin
        if isinstance(error,PixelHeuristicFailure):result['failed_pixel_facts']=error.facts
        raise
    finally:
        if type(inflight) is dict:inflight.pop('rgb',None)
        for c,_ in batch:c.pop('rgb',None)
        batch.clear()
        result['raw_buffers_released']=True
        # Existing parent cleanup checkpoint/atomic terminal receipt still follows.
        # This recording manifest alone never permits acceptance, even if stale.
        raw=(json.dumps(result,separators=(',',':'),allow_nan=False)+'\n').encode('utf-8')
        require(len(raw)<=32768,'Cadence manifest cap')
        atomic(manifest,raw)
        if result['status']=='VALIDATED_PENDING_SCENE_CLEANUP':
            try:
                check_work()
            except BaseException as error:
                result.update(status='FAILED_DIAGNOSTIC_ONLY',rejected=True,error=('Post-manifest work deadline/watch: '+str(error))[:512])
                # Failed invalidation can leave stale bytes; final scene/cleanup/
                # successful controller exit and exact terminal marker remain mandatory.
                atomic(manifest,(json.dumps(result,separators=(',',':'),allow_nan=False)+'\n').encode())
                raise
