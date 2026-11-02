"""Bounded observational receipt validator; no claim of engine/gameplay atomicity."""
import json, math, sys

CALLBACKS = frozenset(f'{name}_{phase}' for name in ('enter','exit','entered','exited','cross','crossed','uncross','uncrossed') for phase in ('before','after'))
NOTIFICATIONS = frozenset(f'{name}_{phase}' for name in ('entered','exited','crossed','uncrossed') for phase in ('before','after'))
KINDS = CALLBACKS | frozenset(('attempt_begin','attempt_return','settled','move_enter','move_exit','bump_enter','bump_exit'))
GEOMETRY = ('x','y','z','sx','sy','step_size','bound_x','bound_y','bound_width','bound_height','appearance_flags','tile_mover','density','anchored')
class ReceiptError(ValueError): pass

def require(value, message):
    if not value: raise ReceiptError(message)

def integer(value): return isinstance(value, int) and not isinstance(value, bool)
def binary(value): return value is False or value is True or (integer(value) and value in (0,1))
def position(actor): return tuple(actor[k] for k in ('x','y','z','sx','sy'))

def checked_actor(actor, life, world):
    require(isinstance(actor,dict) and actor.get('lifetime') == life,'actor lifetime mismatch')
    require(all(k in actor and integer(actor[k]) for k in GEOMETRY if k not in ('tile_mover','density','anchored')),'missing/noninteger geometry')
    require(all(binary(actor.get(k)) for k in ('tile_mover','density','anchored')),'invalid actor flags')
    require(1 <= actor['x'] <= world['maxx'] and 1 <= actor['y'] <= world['maxy'] and 1 <= actor['z'] <= world['maxz'],'actor out of map')
    require(actor['step_size'] > 0 and actor['bound_width'] == 32 and actor['bound_height'] == 32 and actor['bound_x'] == 0 and actor['bound_y'] == 0,'actor bound/step mismatch')
    require(actor['density'] == 1 and actor['anchored'] == 0 and actor['tile_mover'] == 0,'actor movement flags mismatch')
    return actor

def validate(receipt):
    require(isinstance(receipt,dict) and receipt.get('schema') == 1 and receipt.get('kind') == 'native_group_bump_observation','schema')
    require(receipt.get('failure') is None,'fixture failure')
    require(receipt.get('version') == 516 and receipt.get('build') == 1688,'engine pin')
    require(integer(receipt.get('movement_mode')) and receipt['movement_mode'] == receipt.get('legacy_mode'),'movement mode')
    require(receipt.get('tick_lag') == 0.5 and receipt.get('icon_size') == 32,'world tick/geometry')
    require((receipt.get('maxx'),receipt.get('maxy'),receipt.get('maxz')) == (8,6,1),'world extent')
    rows=receipt.get('cases');require(isinstance(rows,list) and [r.get('case') for r in rows] == ['reach','no_group','group','pixel'],'case sequence')
    require(receipt.get('partial_case') == 'pixel' and isinstance(receipt.get('partial_events'),list) and receipt['partial_events'] == rows[-1].get('events'),'terminal capture')
    checked={}
    for number,row in enumerate(rows,1):
        case=row['case'];require(row.get('lifetime') == number,'case lifetime')
        require(row.get('overflow') == 0 and row.get('final_bump_depth') == 0,'overflow or unbalanced Bump')
        require(binary(row.get('a_in_b_group')) and binary(row.get('b_in_a_group')),'group encoding')
        require(row['a_in_b_group'] == (case in ('group','pixel')) and row['b_in_a_group'] == 0,'directed group setup')
        a=checked_actor(row.get('start_a'),f'{number}:a',receipt);b=checked_actor(row.get('start_b'),f'{number}:b',receipt)
        end_a=checked_actor(row.get('end_a'),f'{number}:a',receipt);end_b=checked_actor(row.get('end_b'),f'{number}:b',receipt)
        require(position(a) == (2,3,1,0,0),'start a')
        require(position(b) == (6 if case=='reach' else 3,3,1,0,0),'start b')
        require(a['step_size'] == (2 if case=='pixel' else 32) and b['step_size']==32,'step setup')
        require(binary(row.get('move_return')),'move result encoding')
        events=row.get('events');require(isinstance(events,list) and 0 < len(events) <= 256,'event count')
        last_time=None;depth=0;stack=[]
        for ordinal,e in enumerate(events,1):
            fields={'ordinal','time','case','kind','receiver','receiver_turf','subject','bump_depth','result','a','b','a_in_b_group','b_in_a_group'}
            require(isinstance(e,dict) and set(e)==fields and e.get('ordinal') == ordinal and e.get('case') == case,'event identity/fields')
            kind=e.get('kind');receiver=e.get('receiver');subject=e.get('subject')
            require(kind in KINDS and receiver in ('a','b','turf') and subject in ('a','b'),'event kind/provenance')
            turf=e.get('receiver_turf')
            if receiver=='turf':
                require(isinstance(turf,dict) and set(turf)=={'x','y','z'} and all(integer(turf[k]) for k in turf),'turf identity')
                require(1<=turf['x']<=receipt['maxx'] and 1<=turf['y']<=receipt['maxy'] and 1<=turf['z']<=receipt['maxz'],'turf outside map')
                receiver_id=('turf',turf['x'],turf['y'],turf['z'])
            else:
                require(turf is None,'unexpected turf identity');receiver_id=(receiver,)
            if kind in CALLBACKS:
                name,phase=kind.rsplit('_',1)
                require((receiver=='turf') == (name in ('enter','exit','entered','exited')),'callback receiver type')
                frame=(name,receiver_id,subject)
                if phase=='before':stack.append(frame)
                else:require(bool(stack) and stack.pop()==frame,'callback return pairing')
            elif kind in ('move_enter','bump_enter'):
                name=kind[:-6];require(receiver in ('a','b') and ((subject==receiver) if name=='move' else (subject!=receiver)),'movement receiver/subject')
                stack.append((name,receiver_id,subject))
            elif kind in ('move_exit','bump_exit'):
                name=kind[:-5];require(bool(stack) and stack.pop()==(name,receiver_id,subject),'movement return pairing')
            else:
                require(not stack and receiver=='a' and subject=='b','boundary inside callback or wrong actors')
            require(integer(e.get('bump_depth')) and 0 <= e['bump_depth'] <= 4,'Bump depth')
            if e['kind']=='bump_enter':
                depth+=1;require(e['bump_depth']==depth,'Bump entry depth')
            elif e['kind']=='bump_exit':
                require(depth>0 and e['bump_depth']==depth,'Bump exit depth');depth-=1
            else:require(e['bump_depth']==depth,'event Bump depth')
            require(isinstance(e.get('time'),(int,float)) and not isinstance(e.get('time'),bool) and math.isfinite(e['time']),'event time')
            require(last_time is None or e['time'] >= last_time,'event time order');last_time=e['time']
            require(binary(e.get('a_in_b_group')) and e['a_in_b_group']==row['a_in_b_group'] and binary(e.get('b_in_a_group')) and e['b_in_a_group']==0,'event group changed')
            ea=checked_actor(e.get('a'),f'{number}:a',receipt);eb=checked_actor(e.get('b'),f'{number}:b',receipt)
            fixed=('step_size','bound_x','bound_y','bound_width','bound_height','appearance_flags','tile_mover','density','anchored')
            require(all(ea[k]==a[k] and eb[k]==b[k] for k in fixed),'actor geometry or flags changed during trace')
        require(depth==0 and not stack,'unclosed movement/callback')
        require(events[0]['kind']=='attempt_begin' and events[-1]['kind']=='settled' and sum(e['kind']=='attempt_begin' for e in events)==1 and sum(e['kind']=='settled' for e in events)==1,'case boundaries')
        require(position(events[0]['a'])==position(a) and position(events[0]['b'])==position(b),'initial trace mismatch')
        require(position(events[-1]['a'])==position(end_a) and position(events[-1]['b'])==position(end_b),'terminal trace mismatch')
        require(any(e['kind']=='move_enter' and e['receiver']=='a' for e in events),'missing real Move')
        require(any(e['kind']=='move_exit' and e['receiver']=='a' for e in events),'missing Move completion')
        returns=[e for e in events if e['kind']=='attempt_return']
        require(len(returns)==1 and returns[0]['result']==row['move_return'],'attempt return')
        require(events[-1]['time'] > returns[0]['time'],'missing observation tick')
        checked[case]=(row,events)
    reach,reach_events=checked['reach']
    require(position(reach['end_a'])==(3,3,1,0,0) and position(reach['end_b'])==(6,3,1,0,0),'reach control movement')
    require(all(any(e['kind']==k and e['receiver']=='turf' and e['subject']=='a' for e in reach_events) for k in ('entered_before','exited_before')),'observer reachability control')
    nogroup,ng=checked['no_group']
    require(position(nogroup['end_a'])==(2,3,1,0,0) and position(nogroup['end_b'])==(3,3,1,0,0),'no-group control displacement')
    require(any(e['kind']=='bump_enter' and e['receiver']=='a' and e['subject']=='b' for e in ng),'no-group Bump missing')
    require(all(position(e['a'])==(2,3,1,0,0) and position(e['b'])==(3,3,1,0,0) for e in ng),'no-group transient displacement')
    pixel,pe=checked['pixel']
    for e in pe:
        if e['a']['x']==3 and e['b']['x']==2:
            return {'status':'observed_pixel_exchange','event_ordinal':e['ordinal'],'kind':e['kind']}
    group,ge=checked['group']
    before=(position(group['start_a']),position(group['start_b']));after=((3,3,1,0,0),(2,3,1,0,0))
    for e in ge:
        if (position(e['a']),position(e['b'])) not in (before,after):
            return {'status':'observed_intermediate_state','event_ordinal':e['ordinal'],'kind':e['kind']}
    group_bumps=[e for e in ge if e['kind']=='bump_enter' and e['receiver']=='a' and e['subject']=='b']
    if not group_bumps:return {'status':'unsupported_no_group_bump','event_count':len(ge)}
    if (position(group['end_a']),position(group['end_b']))!=after:return {'status':'unsupported_no_exchange','event_count':len(ge)}
    witness=[e for e in ge if e['kind'] in NOTIFICATIONS and e['bump_depth'] > 0 and (position(e['a']),position(e['b'])) == after]
    if not witness:return {'status':'inconclusive_no_postcommit_notification','event_count':len(ge)}
    return {'status':'observed_consistent_on_this_trace','witness_ordinals':[e['ordinal'] for e in witness]}

def main():
    try:
        with open(sys.argv[1],encoding='utf-8') as f:receipt=json.load(f)
        report=validate(receipt); print(json.dumps(report,sort_keys=True))
        return 0 if report['status']=='observed_consistent_on_this_trace' else 2
    except (OSError,ValueError,KeyError,IndexError,TypeError) as e:
        print(json.dumps({'status':'invalid_receipt','error':str(e)},sort_keys=True));return 1
if __name__=='__main__':raise SystemExit(main())
