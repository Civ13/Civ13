"""Fixed scene handshake around retained 160-frame native recording; no GUI input."""
import hashlib, json, math, time
from pathlib import Path
from deferred_recording import record_burst, configuration
from cadence_schema import validate_manifest
from activation import SOURCE

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

def ref(value):return type(value) is str and 0<len(value)<64
def clock(value):return type(value) in (int,float) and math.isfinite(value) and value>=0
def common(before,after,end,keys):
    need(before['phase']=='before' and after['phase']=='after','phase')
    for key in keys:need(ref(before[key]) and before[key]==after[key],'identity')
    need(all(clock(t) for t in [before['time'],after['time'],end]),'clock')
    need(before['time']<after['time']<=end and after['time']-before['time']<=80,'capture window')
def harvest(before,after,end):
    common(before,after,end,('actor','tool'))
    need(before['staged_mature']==after['staged_mature']==1 and before['growth_observed']==after['growth_observed']==0,'honest staged origin')
    targets=before['targets'];need(type(targets) is list and len(targets)==3 and all(ref(t) for t in targets) and len(set(targets))==3 and targets==after['targets'],'targets')
    rows=after['rows'];need(type(rows) is list and len(rows)==3 and [r['plant'] for r in rows]==targets,'harvested target set')
    outputs=[];previous=before['time']
    for r in rows:
        need(r['removed']==1 and r['seed_units']==2,'crop removed and seeds retained')
        need(clock(r['time']) and previous<r['time']<=after['time'],'harvest timing');previous=r['time']
        need(type(r['outputs']) is list and 1<=len(r['outputs'])<=3 and all(ref(x) for x in r['outputs']),'native yield')
        outputs+=r['outputs']
    need(len(outputs)==len(set(outputs)) and not set(outputs)&set(targets),'new grain identities')
    need(after['picked_ref'] in outputs and after['actor_holds_output']==1,'same harvest pickup')
def mill(before,after,end):
    common(before,after,end,('actor','mill','input'))
    need(before['input_staged']==1,'staged input')
    need(all(before[k]==1 for k in ['strength_coeff','stamina_coeff','dexterity_coeff']),'baseline stats')
    need(before['stamina_cost_constant']==before['mood_cost_constant']==0,'native zero work charges')
    need(after['input_consumed']==1 and after['mill_idle']==1,'material consumed and normal completion')
    need(ref(after['produced_ref']) and after['produced_ref']==after['picked_ref'] and after['produced_ref']!=before['input'],'new flour identity')
    need(after['actor_holds_output']==1 and after['flour_units']==10,'ten units picked up')
    need(clock(after['work_elapsed']) and 70<=after['work_elapsed']<80 and clock(after['work_started']) and after['work_started']-before['time']==5 and after['work_elapsed']==after['time']-after['work_started'],'normal seven-second work')

continuity = mill

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
    manifest=read(output/'cadence-recording.json',262144)
    validate_manifest(manifest,output,expected_count=160)
    need(result['owner']==owner and manifest['owner']==owner,'Recorded process/window binding changed')
    take=read(source/'intro-take.json')
    need(take['source']==SOURCE and take['engine']=='516.1688' and take['world_fps']==20,'Take source/build mismatch')
    continuity(read(source/'intro-state-before.json'),read(source/'intro-state-after.json'),end_tick)
    need(len({r['sha256'] for r in manifest['frames']})>1,'No visible change recorded')
    return dict(status='GUARDED_NATIVE_FRAMES_PENDING_PLAYBACK',frames=160,target_fps=20,
                measured_acquisition_seconds=manifest['acquisition_end_seconds'],owner=owner,
                manifest_sha256=hashlib.sha256((output/'cadence-recording.json').read_bytes()).hexdigest(),
                accepted_for_marketing=False)
