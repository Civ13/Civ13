"""Held short-burst recording implementation; no native activation in this package.

Every sample retains synchronous native safety checks. A four-frame bounded
worker hashes and spools raw bytes; full-pixel validation and PNG encoding occur
after acquisition (<=25 seconds) and a bounded <=0.5s drain/handshake.
"""
import hashlib,json,math,time
from fractions import Fraction
from pathlib import Path
from capture import acquire_owned,_finalize_acquisition,PixelHeuristicFailure
from receipt_persistence import atomic
from bounded_spool import BoundedSpool

NATIVE_RELEASED=False
SIZE=(480,480)
MAX_COUNT=500
MAX_RAW_BYTES=345600000
MAX_FRAME_TOTAL=160*1024**2
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
                  clock=time.monotonic,sleep=time.sleep, sample_clock=time.perf_counter_ns,
                  clock_info=time.get_clock_info,on_first_sample=None,spool_factory=BoundedSpool):
    """Private test seam. Parent owns process cleanup and terminal receipt proof.

    read_configuration must be narrowly wired to the same admitted client's bounded
    numeric receipt; callbacks are not a substitute for native ownership checks.
    scene_started is the original overall work origin, never reset for this burst.
    """
    output=Path(output);manifest=output/'cadence-recording.json'
    require(output.is_dir() and not output.is_symlink() and not manifest.exists() and not manifest.is_symlink() and not any(output.glob('cadence-*.png')),'Fresh bounded output required')
    result=dict(schema=4,status='FAILED_DIAGNOSTIC_ONLY',deferred_validation=True,rejected=True,width=480,height=480,frames=[],cadence_samples=[],raw_spool_bytes=0)
    previous_sample_ns=None
    def ns():
        nonlocal previous_sample_ns
        value=sample_clock()
        require(type(value) is int and 0<=value<2**63, 'Invalid high-resolution clock reading')
        require(previous_sample_ns is None or value>=previous_sample_ns, 'High-resolution clock moved backward')
        previous_sample_ns=value
        return value
    def info(name):
        c=clock_info(name)
        require(type(c.implementation) is str and 0<len(c.implementation)<=128 and type(c.resolution) in (int,float) and math.isfinite(c.resolution) and 0<c.resolution<=1 and c.monotonic is True and c.adjustable is False, 'Invalid clock metadata')
        return dict(implementation=c.implementation,resolution_seconds=c.resolution,monotonic=c.monotonic,adjustable=c.adjustable)
    batch=[];owned_raw=[];total_raw=0;total_png=0;last=None;inflight=None;validation_index=None;spooler=None
    private=output/'environment'
    require(not private.is_symlink() and not getattr(private,'is_junction',lambda:False)(),'Linked private spool parent')
    private.mkdir(exist_ok=True)
    spool=private/'cadence-raw'
    require(not spool.exists() and not spool.is_symlink(),'Fresh private spool required')
    spool.mkdir()
    def check_work():
        watch()
        require(0<=clock()-scene_started<120,'Original work deadline exceeded')
        if spooler is not None:spooler.check()
    try:
        require(callable(on_first_sample), 'One fixed first-sample callback required')
        spooler=spool_factory()
        result.update(timing_clock='perf_counter_ns',safety_clock='monotonic',
            clock_metadata=dict(perf_counter=info('perf_counter'),monotonic=info('monotonic')),
            safety_scene_started_seconds=scene_started,first_sample_callback_count=0,
            readback_scope='BitBlt start through BGRA memory read; includes flush and post-copy ownership checks; not presentation time')
        check_work();config=configuration(admission_configuration);fps=config['effective_fps'];count=MAX_COUNT;interval=1/fps
        require(fps == 20 and config["world_fps"] == 20, "Exactly native-configured 20 FPS required")
        require(type(admitted_owner) is dict and set(admitted_owner)=={'pid','creation_filetime','hwnd'} and all(type(v) is int and v>0 for v in admitted_owner.values()),'Malformed admitted owner')
        result.update(fps_config=config,owner=dict(admitted_owner),frame_count=count,
                      rejection_timing='Native safety immediate per sample; raw spool bounded to four frames; all-frame content validation deferred <=twenty-five-second acquisition plus <=0.5s drain/handshake; no acceptance before scene/cleanup/terminal proof',
                      configured_cadence_only=True,rendered_presentation_rate_measured=False)
        result['cadence_samples'].append(dict(phase='admission',config=config,owner=dict(admitted_owner)))
        start_config=configuration(read_configuration());require(start_config==config,'Cadence changed before burst')
        result['cadence_samples'].append(dict(phase='burst_start',config=start_config,owner=dict(admitted_owner)))
        result['safety_origin_before_seconds']=clock()
        origin=ns()
        result['perf_counter_origin_ns']=origin
        result['safety_origin_after_seconds']=clock()
        rate=Fraction(str(fps));numerator,denominator=rate.numerator,rate.denominator
        for index in range(count):
            due_ns=(index*1000000000*denominator+numerator-1)//numerator
            due=origin+due_ns
            now=ns()
            while now<due:
                check_work();sleep(min(.002,(due-now)/1000000000));now=ns()
            check_work();begin=ns();last=dict(index=index,due_ns=due_ns,begin_ns=begin-origin,
                due_seconds=due_ns/1000000000,begin_seconds=(begin-origin)/1000000000)
            require((begin-due)*numerator<1000000000*denominator,'Acquisition start missed native interval; no catch-up')
            c=acquire(adapter,process,title,SIZE)
            inflight=c
            end=ns();last.update(end_ns=end-origin,end_seconds=(end-origin)/1000000000);check_work()
            require(end>=begin and (end-due)*numerator<1000000000*denominator,'Acquisition missed native interval; no duplicate frames')
            require(c.get('status')=='OWNED_RAW_UNVALIDATED' and c.get('checkpoints')==CHECKPOINTS and c.get('cleanup')==CLEANUP,'Missing native guard/cleanup proof')
            require((c.get('width'),c.get('height'))==SIZE and c['window']['client_rect']==[0,0,480,480] and owner_of(c)==admitted_owner,'Frame owner/geometry mismatch')
            timing=c.get('readback_timing')
            require(type(timing) is dict and set(timing)=={'clock','bitblt_begin_ns','bgra_readback_end_ns'} and timing['clock']=='perf_counter_ns','Missing native readback clock evidence')
            rb,re=timing['bitblt_begin_ns'],timing['bgra_readback_end_ns']
            require(type(rb) is int and type(re) is int and begin<=rb<=re<=end,'Native readback interval outside acquisition')
            last.update(readback_begin_ns=rb-origin,readback_end_ns=re-origin)
            require(type(c.get('rgb')) is bytes and len(c['rgb'])==691200,'Exact raw RGB required')
            total_raw+=len(c['rgb']);require(total_raw<=MAX_RAW_BYTES,'Raw batch byte cap')
            raw_path=spool/f'{index:03d}.rgb'
            raw=c.pop('rgb')
            owned_raw.append(raw_path)
            spooler.submit(index,raw_path,raw)
            del raw
            check_work()
            require((ns()-due)*numerator<1000000000*denominator,'Raw enqueue missed native interval')
            batch.append((c,dict(last),raw_path,index))
            inflight=None
            if index==0:
                check_work();result['first_sample_callback_begin_ns']=ns()-origin
                if count>1:
                    require(result['first_sample_callback_begin_ns']<(1000000000*denominator+numerator-1)//numerator,'First-sample callback began after next due')
                result['first_sample_callback_count']+=1
                on_first_sample()
                result['first_sample_callback_end_ns']=ns()-origin
                check_work()
                # Callback time consumes the next sample's original due window.
                if count>1:
                    next_due=(1000000000*denominator+numerator-1)//numerator
                    require((result['first_sample_callback_end_ns']-next_due)*numerator<1000000000*denominator,'First-sample callback exhausted next acquisition interval')
        result['acquisition_end_ns']=ns()-origin
        result['acquisition_end_seconds']=result['acquisition_end_ns']/1000000000
        require(result['acquisition_end_ns']<=25000000000,'Twenty-five-second acquisition bound')
        hashes=spooler.finish(count,check_work,timeout=.5)
        result['spool_stats']=spooler.stats()
        handshake_started=clock()
        end_config=configuration(read_configuration());require(end_config==config,'Cadence changed during burst')
        require(clock()-handshake_started<=.5,'End configuration handshake deadline')
        result['cadence_samples'].append(dict(phase='burst_end',config=end_config,owner=dict(admitted_owner)))
        result['raw_spool_bytes']=total_raw
        result['validation_begin_ns']=ns()-origin
        result['validation_begin_seconds']=result['validation_begin_ns']/1000000000
        require(result['validation_begin_ns']<=25500000000,'Deferred content rejection bound')
        for index,(c,timing,raw_path,spool_index) in enumerate(batch):
            validation_index=index
            check_work();name=f'cadence-{index:03d}.png';path=output/name
            require(spool_index==index,'Raw spool index mismatch')
            require(raw_path.is_file() and not raw_path.is_symlink() and raw_path.stat().st_size==691200,'Raw spool size/type changed')
            raw=raw_path.read_bytes()
            require(hashlib.sha256(raw).hexdigest()==hashes[index],'Raw spool changed')
            c['rgb']=raw
            del raw
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
            c.pop('rgb')
            raw_path.unlink()  # Only this frame's verified private spool file.
        require(len(result['frames'])==count,'Incomplete validated batch')
        check_work();result.update(status='VALIDATED_PENDING_SCENE_CLEANUP',rejected=False,total_frame_bytes=total_png)
        return result
    except BaseException as error:
        result.update(status='FAILED_DIAGNOSTIC_ONLY',rejected=True,error=(type(error).__name__+': '+str(error))[:512],last_attempt_timing=last)
        result['raw_bytes_acquired']=total_raw
        if spooler is not None:result['spool_stats']=spooler.stats()
        if validation_index is not None:
            result['failed_validation_index']=validation_index
            result['validation_failure_elapsed_ns']=ns()-origin
            result['validation_failure_elapsed_seconds']=result['validation_failure_elapsed_ns']/1000000000
        if isinstance(error,PixelHeuristicFailure):result['failed_pixel_facts']=error.facts
        raise
    finally:
        if type(inflight) is dict:inflight.pop('rgb',None)
        for row in batch:row[0].pop('rgb',None)
        batch.clear()
        spool_errors=[]
        joined = spooler is None or spooler.cancel_and_join(timeout=2)
        if not joined:
            spool_errors.append('worker_not_joined')
        else:
            created = [] if spooler is None else spooler.created_paths()
            for raw_path in created:
                try:
                    require(raw_path in owned_raw,'Unexpected raw cleanup target')
                    if raw_path.exists():
                        require(raw_path.is_file() and not raw_path.is_symlink(),'Linked raw cleanup target')
                        raw_path.unlink()
                except (OSError,RuntimeError) as error:spool_errors.append(type(error).__name__)
            try:spool.rmdir()
            except OSError as error:spool_errors.append(type(error).__name__)
        result['raw_spool_released']=not spool_errors
        if spool_errors:
            result.update(status='FAILED_DIAGNOSTIC_ONLY',rejected=True,cleanup_error='Private raw spool cleanup failed',spool_cleanup_errors=spool_errors)
        # Existing parent cleanup checkpoint/atomic terminal receipt still follows.
        # This recording manifest alone never permits acceptance, even if stale.
        raw=(json.dumps(result,separators=(',',':'),allow_nan=False)+'\n').encode('utf-8')
        require(len(raw)<=786432,'Cadence manifest cap')
        atomic(manifest,raw)
        if spool_errors:raise RuntimeError('Private raw spool cleanup failed; evidence retained')
        if result['status']=='VALIDATED_PENDING_SCENE_CLEANUP':
            try:
                check_work()
            except BaseException as error:
                result.update(status='FAILED_DIAGNOSTIC_ONLY',rejected=True,error=('Post-manifest work deadline/watch: '+str(error))[:512])
                # Failed invalidation can leave stale bytes; final scene/cleanup/
                # successful controller exit and exact terminal marker remain mandatory.
                atomic(manifest,(json.dumps(result,separators=(',',':'),allow_nan=False)+'\n').encode())
                raise

