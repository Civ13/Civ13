"""Fixed scene handshake around held 240-frame native recording; no GUI input."""
import hashlib, json, math, time
from pathlib import Path
from deferred_recording import record_burst, configuration
from cadence_schema import validate_manifest
from activation import SOURCE
from continuity import validate as continuity

def need(ok,why):
    if not ok: raise ValueError(why)

def read(path,cap=65536):
    need(path.is_file() and not path.is_symlink() and path.stat().st_size<cap,'Missing/linked/oversized witness')
    return json.loads(path.read_text())

def config_at(source,phase):
    row=read(source/('intro-cadence-'+phase+'.json'))
    need(row.pop('phase')==phase,'Wrong cadence phase')
    tick=row.pop('world_time_ds')
    need(type(tick) in (int,float) and math.isfinite(tick) and tick>=0,'Invalid native clock')
    need(type(row.get('same_admitted_client')) is int and row['same_admitted_client']==1,
         'Native observer identity missing')
    row['same_admitted_client']=True
    configuration(row)
    return row,tick


def record_scene(adapter,process,source,output,title,watch,scene_started,owner):
    source,output=Path(source),Path(output)
    admission,_=config_at(source,'admission');calls=0;end_tick=None
    def read_configuration():
        nonlocal calls,end_tick
        calls+=1
        need(calls<=2,'Only start/end configuration reads allowed')
        if calls==1: return config_at(source,'start')[0]
        with (source/'intro-end-request.txt').open('xb') as stream: stream.write(b'end\n')
        deadline=time.monotonic()+.5
        while not (source/'intro-cadence-end.json').exists():
            watch();need(time.monotonic()<deadline,'Native end configuration deadline');time.sleep(.01)
        row,end_tick=config_at(source,'end');return row
    def first():
        with (source/'intro-first-sample.txt').open('xb') as stream: stream.write(b'first_owned_sample\n')
    result=record_burst(adapter,process,output,title,watch,read_configuration,admission,owner,
                        scene_started,on_first_sample=first)
    # Read durable bytes rather than treating an in-memory success as persistence.
    manifest=read(output/'cadence-recording.json',393216)
    validate_manifest(manifest,output,expected_count=240)
    need(result['owner']==owner and manifest['owner']==owner,'Recorded process/window binding changed')
    take=read(source/'intro-take.json')
    need(take['source']==SOURCE and take['engine']=='516.1688' and take['world_fps']==20,'Take source/build mismatch')
    continuity(read(source/'intro-state-before.json'),read(source/'intro-state-after.json'),end_tick)
    need(len({r['sha256'] for r in manifest['frames']})>1,'No visible change recorded')
    return dict(status='GUARDED_NATIVE_FRAMES_PENDING_PLAYBACK',frames=240,target_fps=20,
                measured_acquisition_seconds=manifest['acquisition_end_seconds'],owner=owner,
                manifest_sha256=hashlib.sha256((output/'cadence-recording.json').read_bytes()).hexdigest(),
                accepted_for_marketing=False)
