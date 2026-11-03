"""One controlled mosquito idle-slot receipt; no Life or contact parity claim."""
import math
SCOPE = 'controlled mosquito towards idle-slot; no Life, contact or client parity'
def number(x): return type(x) in (int,float) and math.isfinite(x)
def integer(x): return type(x) is int
def require(ok, reason):
    if not ok: raise ValueError(reason)
def validate(row):
    require(type(row) is dict and number(row.get('started')) and number(row.get('ended')) and
            0 <= row['ended']-row['started'] <= 20 and row.get('tick_lag_ds') == 0.5 and
            row.get('actual_clients') == 0, 'case identity')
    events=row.get('events');require(type(events) is list and 0<len(events)<=1024,'events bound')
    labels=('command_before','command_after','idle_before_target','target_step_before','target_step_after','arrived','stop','quiet_end')
    phase={};moves=[];last=-1;open_move=None
    allowed=set(labels)|{'mosquito_intent_towards','mosquito_move_before','mosquito_move_after','travel_sample','quiet_sample'}
    for e in events:
        require(type(e) is dict and e.get('event') in allowed and number(e.get('at')) and last<=e['at']<=row['ended'], 'event or time')
        last=e['at'];kind=e['event']
        require(all(integer(e.get(k)) for k in ('x','y','z','sx','sy','generation')) and
                1<=e['x']<=18 and 1<=e['y']<=14 and e['z']==1 and 0<=e['sx']<32 and 0<=e['sy']<32,'actor coordinates')
        require(all(e.get(k) in (0,1,False,True) for k in ('settled','transaction','wild_owner','pending','recovery')),'flags')
        require(e.get('target_z')==1 and e.get('target_y')==6 and e.get('target_x') in (6,7) and e.get('target_sx')==0 and e.get('target_sy')==0,'target coordinates')
        if kind in labels:
            require(kind not in phase,'duplicate boundary');phase[kind]=e
        if kind=='mosquito_move_before':
            require(open_move is None and e['transaction'] and e['wild_owner'] and e.get('wild_mode')=='towards','move entry authority')
            open_move=e
        elif kind=='mosquito_move_after':
            require(open_move is not None,'unpaired move');b=open_move;open_move=None
            require(e['generation']==b['generation'] and e['wild_generation']==b['wild_generation'] and e['wild_revision']==b['wild_revision'] and e['transaction'] and e['wild_owner'],'move authority changed')
            require((e['x']*32+e['sx'])-(b['x']*32+b['sx'])==2 and e['y']==b['y'] and e['sy']==b['sy'],'move not one eastward 2px pulse')
            moves.append((b,e))
    require(open_move is None and set(phase)==set(labels),'missing boundary or unpaired move')
    require([e['event'] for e in events if e['event'] in labels]==list(labels),'boundary order')
    command,accepted,idle,before,after,arrived,stop,end=(phase[k] for k in labels)
    require(command['target_x']==accepted['target_x']==idle['target_x']==before['target_x']==6 and after['target_x']==arrived['target_x']==stop['target_x']==end['target_x']==7,'target movement')
    require(accepted.get('choice') in (1,True) and accepted['wild_owner'] and accepted['wild_mode']=='towards' and
            number(accepted.get('wild_due')) and accepted['wild_due']==row['started']+3,'command admission')
    gen,rev,due=accepted['wild_generation'],accepted['wild_revision'],accepted['wild_due']
    require(integer(gen) and integer(rev) and gen==accepted['generation'] and
            idle['wild_owner'] and idle['wild_generation']==gen and idle['wild_revision']==rev and idle['generation']==gen and
            idle['wild_due']==due and idle['wild_idle_end']==due+3 and due<=idle['at']<idle['wild_idle_end'] and
            (idle['x'],idle['y'],idle['sx'],idle['sy'])==(6,6,0,0) and not idle['transaction'],'idle slot')
    require(before['at']==after['at'] and after['at']<idle['wild_idle_end'] and moves,'target response')
    require(all(after['at']<=b['at']<=arrived['at'] and b['wild_generation']==gen and b['wild_revision']==rev and b['generation']==gen for b,_ in moves),'move timing or owner')
    require(moves[0][0]['at']-after['at']<=0.5 and (moves[0][0]['x'],moves[0][0]['sx'])==(6,0) and
            (moves[-1][1]['x'],moves[-1][1]['sx'])==(7,0) and len(moves)==16,'first pulse or arrival path')
    require(all((a['x'],a['y'],a['sx'],a['sy'])==(b['x'],b['y'],b['sx'],b['sy']) for (_,a),(b,_) in zip(moves,moves[1:])), 'unattributed travel')
    require((arrived['x'],arrived['y'],arrived['sx'],arrived['sy'])==(7,6,0,0) and arrived['wild_owner'] and not arrived['transaction'] and arrived['wild_generation']==gen and arrived['wild_revision']==rev,'arrival')
    require(not stop['wild_owner'] and not stop['transaction'] and not end['wild_owner'] and not end['transaction'] and not end['pending'] and not end['recovery'] and end['at']-stop['at']>=4,'quiet stop')
    require(all((e['x'],e['y'],e['sx'],e['sy'])==(7,6,0,0) and not e['wild_owner'] and not e['transaction'] for e in events[events.index(stop):]),'late movement')
    return {'target_response':True,'first_pulse_delay_ds':moves[0][0]['at']-after['at'],'pulses':len(moves),'quiet_ds':end['at']-stop['at']}
def validate_receipt(receipt,head):
    require(type(receipt) is dict and receipt.get('head')==head and receipt.get('error') is None and receipt.get('port')==0 and
            (receipt.get('byond_version'),receipt.get('byond_build'))==(516,1688) and receipt.get('scope')==SCOPE and
            integer(receipt.get('transition_checks')) and receipt['transition_checks']>0 and receipt.get('transition_phase')=='quiet','receipt identity')
    rows=receipt.get('transition_rows');require(type(rows) is list and len(rows)==1,'one case')
    observed=validate(rows[0]);require(receipt.get('transition_partial')==rows[0]['events'],'partial trace binding');return observed
