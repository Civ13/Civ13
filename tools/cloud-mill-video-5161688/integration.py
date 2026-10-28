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

def number(v):return type(v) in (int,float) and math.isfinite(v)
def continuity(before,after,end):
 need(before['phase']=='before' and after['phase']=='after','phase')
 for k in ('actor','mill','input'):need(type(before[k]) is str and 0<len(before[k])<64 and before[k]==after[k],'identity')
 need(all(number(x) and x>=0 for x in [before['time'],after['time'],end,after['work_started'],after['work_elapsed']]),'clock')
 need(before['time']<after['time']<=end and after['time']-before['time']<80,'existing capture window')
 need(after['work_started']-before['time']>=5,'input visibility wait not shortened')
 need(after['work_elapsed']==after['time']-after['work_started'],'work clock consistency')
 keys=('strength_coeff','stamina_coeff','dexterity_coeff')
 coeff=[before[k] for k in keys]
 need(all(number(v) and v>0 for v in coeff),'effective coefficients')
 need(all(before[k]==100 for k in ('raw_strength','raw_stamina','raw_dexterity')),'unmodified raw stats')
 need(number(before['mood_modifier']) and all(abs(v-before['mood_modifier'])<.0001 for v in coeff),'normal effective mood coefficients')
 increment=6*coeff[0]+6*coeff[1]+3*coeff[2]
 steps=math.ceil(100/increment)
 need(before['work_steps']==after['work_steps']==steps and 1<=steps<=7,'source-derived step count')
 need(abs(before['work_increment']-increment)<.001 and abs(after['work_increment']-increment)<.001,'unchanged production formula')
 need(before['requested_wait_ds']==10 and after['work_elapsed']>=steps*10,'no shortened production waits')
 need(before['input_staged']==1 and before['stamina_cost_constant']==before['mood_cost_constant']==0,'honest staged input and native zero costs')
 need(before['mill_staged']==after['mill_staged']==1 and before['original_mill_location_claim']==after['original_mill_location_claim']==0,'honest stock prop staging')
 rows=after['observed_progress'];need(type(rows) is list and len(rows)==steps,'zero plus every pre-completion increment observed')
 previous=None
 for i,row in enumerate(rows):
  need(number(row['time']) and row['time']>=after['work_started']+i*10 and row['time']<after['time'],'no early progress')
  need(previous is None or row['time']>previous,'ordered progress');previous=row['time']
  need(number(row['progress']) and abs(row['progress']-i*increment)<.001,'real native progress sequence')
  need(all(number(row[k]) and abs(row[k]-before[k])<.0001 for k in keys),'coefficient changed during work')
  need(all(row[k]==100 for k in ('raw_strength','raw_stamina','raw_dexterity')),'raw stats changed during work')
  need(row['mood_modifier']==before['mood_modifier'],'mood modifier changed during work')
 need(after['input_consumed']==1 and after['mill_idle']==1,'normal completion and consumed material')
 need(type(after['produced_ref']) is str and 0<len(after['produced_ref'])<64 and after['produced_ref']==after['picked_ref'] and after['produced_ref']!=before['input'],'same new flour')
 need(after['actor_holds_output']==1 and after['flour_units']==10,'ten flour units picked up')
 need(after['final_increment_evidence']=='native finish_work output and cleared work; not directly sampled','honest final increment witness')

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
