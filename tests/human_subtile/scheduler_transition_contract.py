"""Strict source-draft scheduler receipt checks. Not wired to a runner."""
import math

KINDS={'follow','flee','pet'}
OWNER_FIELDS=('base_flag','transaction','pulse','follow_owner','flee_owner','pet_owner','pursuit_owner','wild_owner','pending','recovery')
FLAG_FIELDS=('follow_flag','flee_flag','pet_flag')
KINDS_BY_CASE={'follow_flee':('follow','flee'),'pet':('pet',)}
PHASES={'follow_flee':{'follow','gap','flee','quiet'},'pet':{'pet','quiet'}}
EVENTS={'sample','observation_end','end','stimulus_before','stimulus_after',
        'life_before','life_after','move_before','move_after','ready_before','ready_after',
        'command_return','native_stop_return','stop_before','stop_after','quiet_sample','quiet_end'}

def require(ok,label):
    if not ok: raise ValueError(label)

def number(v): return type(v) in (int,float) and math.isfinite(v)
def bit(v): return type(v) in (bool,int) and v in (0,1)
def position(e): return (e['x']*32+e['sx'],e['y']*32+e['sy'])
def quiet_snapshot(e): return tuple(e[k] for k in ('x','y','z','sx','sy','generation'))
def contiguous(samples,start,end):
    return bool(samples) and 0<=samples[0]-start<=0.5 and 0<=end-samples[-1]<=0.5 and all(0<=b-a<=0.5 for a,b in zip(samples,samples[1:]))

def validate_rows(rows,mode):
    require(mode in ('legacy','mixed') and type(rows) is list and len(rows)==2,'row envelope')
    require({r.get('scenario') for r in rows if type(r) is dict}==set(KINDS_BY_CASE),'case inventory')
    output={}
    for row in rows:
        case=row['scenario'];duration=100 if case=='follow_flee' else 12
        require(row.get('mode')==mode and row.get('actual_clients')==0 and row.get('tick_lag_ds')==0.5,'mode/clock/client')
        require(row.get('life_interval_ds')==10 and row.get('start_delay_ds')==6,'scheduler cadence')
        require(type(row.get('process_ticks')) is int and row['process_ticks']>0,'scheduler did not fire')
        start,end=row.get('started'),row.get('ended')
        require(number(start) and number(end) and duration+4<=end-start<=duration+14.5,'case duration')
        events=row.get('events');require(type(events) is list and 0<len(events)<=4096,'event bound')
        open_calls={};seen_ids=set();active_id=0;active_kind=None;last_id=0;ready={};moves={k:0 for k in KINDS_BY_CASE[case]}
        samples=[];quiet_samples=[];end_marker=[];observation_end=[];quiet_end=[];stimuli=[];stops=[];gap_activity=[];prior=start;life_pairs=0
        gap_snapshot=None;quiet_baseline=None;gap_open=False;quiet_open=False
        for i,e in enumerate(events):
            require(type(e) is dict and e.get('event') in EVENTS,'event kind')
            name=e['event'];t=e.get('at');phase=e.get('phase');cid=e.get('command_id');ckind=e.get('command_kind')
            require(number(t) and start<=t<=end and t>=prior,'event time');prior=t
            require(phase in PHASES[case],'phase')
            require(all(bit(e.get(k)) and not e[k] for k in OWNER_FIELDS),'live ownership')
            require(all(bit(e.get(k)) and bool(e[k])==(mode=='mixed') for k in FLAG_FIELDS),'producer flags')
            require(all(type(e.get(k)) is int for k in ('x','y','z','sx','sy','generation','command_id')) and
                    1<=e['x']<=18 and 1<=e['y']<=14 and e['z']==1 and
                    0<=e['sx']<32 and 0<=e['sy']<32 and e['generation']>=0 and cid>=0,'geometry or identity')
            if gap_open:
                require(quiet_snapshot(e)==gap_snapshot,'gap position or generation changed')
                if name=='stimulus_after':gap_open=False
            if quiet_open:
                require(quiet_snapshot(e)==quiet_baseline,'quiet position or generation changed')
            if name=='sample': samples.append(t)
            if name=='quiet_sample': quiet_samples.append(t)
            if name=='observation_end': observation_end.append(t)
            if name=='quiet_end': quiet_end.append(t)
            if name=='end':end_marker.append((i,t))
            if name in ('stimulus_before','stimulus_after'): stimuli.append((name,t,phase))
            if phase in ('gap','quiet') and name in ('move_before','move_after','command_return'):gap_activity.append((phase,name,t))
            if name=='command_return':
                kind=e.get('kind')
                require(kind in KINDS and kind==phase and cid==last_id+1 and ckind==kind,'command identity')
                require(kind in ready and 0<=t-ready[kind]<=0.5,'command without ready')
                require(not any(v[0]=='move' for v in open_calls.values()),'dispatch overlaps move')
                last_id=cid;active_id=cid;active_kind=kind
            elif name=='native_stop_return':
                require(e.get('kind') in ('scan','timer') and cid==0 and ckind is None,'native stop marker')
                require(not any(v[0]=='move' for v in open_calls.values()),'native stop overlaps move')
                active_id=0;active_kind=None
            elif name=='stop_after':
                require(cid==0 and ckind is None,'explicit stop marker')
                active_id=0;active_kind=None;stops.append((phase,t))
                if phase=='gap':
                    require(gap_snapshot is None,'duplicate gap stop');gap_snapshot=quiet_snapshot(e);gap_open=True
                if phase=='quiet':
                    require(quiet_baseline is None,'duplicate quiet stop');quiet_baseline=quiet_snapshot(e);quiet_open=True
            else: require(cid==active_id and ckind==active_kind,'stale command epoch')
            if name.endswith('_before') and name.split('_')[0] in ('life','move','ready','stop'):
                typ=name[:-7];ident=e.get('call_id')
                require(type(ident) is int and ident>0 and ident not in seen_ids,'call identity')
                if typ=='stop': require(not any(v[0]=='move' for v in open_calls.values()),'stop overlaps move')
                seen_ids.add(ident);open_calls[ident]=(typ,e,active_id,active_kind)
            if name.endswith('_after') and name.split('_')[0] in ('life','move','ready','stop'):
                typ=name[:-6];ident=e.get('call_id')
                require(type(ident) is int and ident in open_calls,'missing call entry')
                before_type,before,entry_id,entry_kind=open_calls.pop(ident)
                require(typ==before_type and before['phase']==phase,'mismatched call')
                if typ=='life' and t<=start+duration:life_pairs+=1
                if typ=='ready':
                    kind=e.get('kind');require(kind in KINDS and kind==before.get('kind') and bit(e.get('accepted')),'ready result')
                    if e['accepted'] and phase==kind and t<=start+duration:ready[kind]=t
                if typ=='move' and position(before)!=position(e):
                    require(bit(e.get('accepted')),'move return')
                    if phase in moves and entry_id>0 and entry_id==active_id and entry_kind==phase and t<=start+duration:moves[phase]+=1
        require(not open_calls and life_pairs>0 and not gap_open,'unclosed callbacks, gap or no Life')
        require(len(observation_end)==1 and abs(observation_end[0]-(start+duration))<=0.5,'observation end')
        require(len(end_marker)==1 and end_marker[0][0]==len(events)-1,'terminal event')
        require(contiguous(samples,start,observation_end[0]),'sample gap')
        quiet_stops=[t for phase,t in stops if phase=='quiet']
        require(len(quiet_stops)==1 and len(quiet_end)==1 and 4<=quiet_end[0]-quiet_stops[0]<=4.5 and
                contiguous(quiet_samples,quiet_stops[0],quiet_end[0]) and quiet_end[0]<=end,'final quiet')
        require(not any(phase=='quiet' for phase,_,_ in gap_activity),'movement during final quiet')
        if case=='follow_flee':
            require(len(stimuli)==2 and [x[0] for x in stimuli]==['stimulus_before','stimulus_after'] and
                    stimuli[0][2]=='follow' and stimuli[1][2]=='flee' and
                    abs(stimuli[0][1]-(start+30))<=0.5 and abs(stimuli[1][1]-(start+40))<=0.5,'transition stimulus')
            gap_stops=[t for phase,t in stops if phase=='gap']
            gap_samples=[e['at'] for e in events if e['event']=='sample' and e['phase']=='gap']
            require(len(gap_stops)==1 and 10<=stimuli[1][1]-gap_stops[0]<=10.5 and
                    contiguous(gap_samples,gap_stops[0],stimuli[1][1]),'gap quiet')
            require(not any(phase=='gap' for phase,_,_ in gap_activity),'movement during gap')
        else:require(not stimuli and not any(phase=='gap' for phase,_ in stops),'unexpected stimulus')
        require(all(moves[k]>0 for k in KINDS_BY_CASE[case]),'missing dispatched physical movement')
        output[case]={'moves':moves,'life_pairs':life_pairs,'events':len(events),'commands':last_id}
    return output

def compare_pair(legacy,mixed):
    # Both use native movement because base is off; no random path/contact parity claim.
    return {'legacy':validate_rows(legacy,'legacy'),'mixed':validate_rows(mixed,'mixed')}


def validate_receipt(receipt,head,mode):
    require(type(receipt) is dict and receipt.get('head')==head and receipt.get('error') is None
            and receipt.get('port')==0 and (receipt.get('byond_version'),receipt.get('byond_build'))==(516,1688)
            and receipt.get('scope')=='headless mob scheduler; native fallback only; no smooth/client parity'
            and type(receipt.get('transition_checks')) is int and receipt['transition_checks']>0
            and receipt.get('transition_phase')=='quiet','fixture receipt identity')
    rows=receipt.get('transition_rows');observed=validate_rows(rows,mode)
    require(receipt.get('transition_partial')==rows[-1]['events'],'partial trace binding')
    return observed

def compare_receipts(legacy,mixed,head):
    return {'legacy':validate_receipt(legacy,head,'legacy'),'mixed':validate_receipt(mixed,head,'mixed')}
