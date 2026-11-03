"""Paired controlled insect arrival observation; reports strict comparison separately."""
import math
SCOPE = 'paired mosquito towards timing; no Life, contact or client parity'
def number(x): return type(x) in (int,float) and math.isfinite(x)
def integer(x): return type(x) is int
def require(ok, reason):
    if not ok: raise ValueError(reason)
def validate(row, mode):
    require(type(row) is dict and row.get('mode')==mode and number(row.get('started')) and number(row.get('ended')) and
            0<=row['ended']-row['started']<=30 and row.get('tick_lag_ds')==0.5 and row.get('actual_clients')==0,'case identity')
    events=row.get('events');require(type(events) is list and 0<len(events)<=1024,'event bound')
    labels=('command_before','command_after','idle_before_target','target_step_before','target_step_after','arrived','stop','quiet_end')
    allowed=set(labels)|{'mosquito_intent_towards','mosquito_move_before','mosquito_move_after','travel_sample','quiet_sample'}
    phase={};moves=[];last=-1;open_move=None;actor=None;target=None
    for e in events:
        require(type(e) is dict and e.get('event') in allowed and number(e.get('at')) and last<=e['at']<=row['ended'],'event/time');last=e['at'];kind=e['event']
        require(all(integer(e.get(k)) for k in ('x','y','z','sx','sy','generation')) and 1<=e['x']<=18 and 1<=e['y']<=14 and e['z']==1 and 0<=e['sx']<32 and 0<=e['sy']<32,'actor coordinates')
        require(all(e.get(k) in (0,1,False,True) for k in ('settled','transaction','wild_owner','pending','recovery')),'flags')
        require(e.get('target_z')==1 and e.get('target_y')==6 and e.get('target_x') in (6,7) and e.get('target_sx')==0 and e.get('target_sy')==0,'target coordinates')
        p=(e['x']*32+e['sx'],e['y']*32+e['sy']);q=(e['target_x'],e['target_y'])
        if actor is None:actor=p;target=q
        if kind=='mosquito_move_before':
            require(open_move is None and p==actor,'move entry');open_move=e
            if mode=='smooth':require(e['transaction'] and e['wild_owner'] and e.get('wild_mode')=='towards','smooth authority')
            else:require(not e['transaction'] and not e['wild_owner'],'native authority')
        elif kind=='mosquito_move_after':
            require(open_move is not None,'unpaired move');b=open_move;open_move=None
            require(e['generation']==b['generation'] and e['wild_generation']==b['wild_generation'] and e['wild_revision']==b['wild_revision'],'move authority changed')
            require(p[0]-actor[0]==(2 if mode=='smooth' else 32) and p[1]==actor[1],'move displacement');moves.append((b,e));actor=p
        else:require(p==actor,'unobserved actor move')
        if kind=='target_step_after':require(target==(6,6) and q==(7,6),'target displacement');target=q
        else:require(q==target,'unobserved target move')
        if kind in labels:require(kind not in phase,'duplicate boundary');phase[kind]=e
    require(open_move is None and set(phase)==set(labels) and [e['event'] for e in events if e['event'] in labels]==list(labels),'boundary')
    command,accepted,idle,before,after,arrived,stop,end=(phase[k] for k in labels)
    require((command['x'],command['y'],command['sx'],command['sy'])==(6,6,0,0) and after['at']-row['started']==5 and before['at']==after['at'] and moves,'target stimulus')
    if mode=='smooth':
        gen,rev,due=accepted['wild_generation'],accepted['wild_revision'],accepted['wild_due']
        require(accepted.get('choice') in (1,True) and integer(gen) and integer(rev) and gen==accepted['generation'] and due==row['started']+3 and idle['wild_owner'] and idle['wild_generation']==gen and idle['wild_revision']==rev and idle['generation']==gen and idle['wild_due']==due and idle['wild_idle_end']==due+3 and due<=idle['at']<idle['wild_idle_end'] and not idle['transaction'],'smooth idle slot')
        require(len(moves)==16 and moves[0][0]['at']-after['at']<=0.5 and all(b['wild_generation']==gen and b['wild_revision']==rev and b['generation']==gen for b,_ in moves),'smooth response')
    else:
        require(not accepted['wild_owner'] and not idle['wild_owner'] and not idle['transaction'] and len(moves)==1,'native case')
    require(all(after['at']<=b['at']<=arrived['at'] for b,_ in moves) and (arrived['x'],arrived['y'],arrived['sx'],arrived['sy'])==(7,6,0,0) and not arrived['transaction'] and arrived['settled'],'sampled arrival')
    require(not stop['wild_owner'] and not stop['transaction'] and not end['wild_owner'] and not end['transaction'] and not end['pending'] and not end['recovery'] and end['at']-stop['at']>=4,'quiet stop')
    require(all((e['x'],e['y'],e['sx'],e['sy'])==(7,6,0,0) and not e['wild_owner'] and not e['transaction'] for e in events[events.index(stop):]),'late movement')
    return {'first_move_ds':moves[0][0]['at']-after['at'],'last_move_ds':moves[-1][1]['at']-after['at'],'sampled_arrival_ds':arrived['at']-after['at'],'pulses':len(moves),'quiet_ds':end['at']-stop['at']}
def validate_receipt(receipt,head):
    require(type(receipt) is dict and receipt.get('head')==head and receipt.get('error') is None and receipt.get('port')==0 and (receipt.get('byond_version'),receipt.get('byond_build'))==(516,1688) and receipt.get('scope')==SCOPE and integer(receipt.get('transition_checks')) and receipt['transition_checks']>0 and receipt.get('transition_phase')=='quiet','receipt identity')
    rows=receipt.get('transition_rows');require(type(rows) is list and len(rows)==2,'two cases')
    legacy=validate(rows[0],'legacy');smooth=validate(rows[1],'smooth');require(receipt.get('transition_partial')==rows[1]['events'],'partial trace binding')
    difference=abs(smooth['sampled_arrival_ds']-legacy['sampled_arrival_ds'])
    return {'target_response':True,'legacy':legacy,'smooth':smooth,'strict_tolerance_ds':0.5,'sampled_difference_ds':difference,'within_original_tolerance':difference<=0.5}
