"""Source-only host oracle for the proposed enabled-owner scheduler observation.

Not wired into any runner. This checks one feline flee-to-follow transition; it
does not establish contact/client parity or ordinary species acceptance.
"""
import math

EVENTS = {'life_before','life_after','move_before','move_after','old_completion_hook',
          'old_timer_before','old_timer_after','stop_before','stop_after',
          'replacement_requested','follow_owner_observed','sample',
          'final_stop_before','final_stop_after','quiet_sample','quiet_end'}
FLAGS = ('base_enabled','offset_owned','transaction','transaction_old','pulse','flee_old',
         'follow_new','follow_any','recovery','pending','pursuit','wild','pet','old_cancelled','old_owner_retired','old_finished','old_arrived')
COUNTS = ('generation','old_hooks','old_timer_count','follow_moves')


def need(condition, message):
    if not condition:
        raise ValueError(message)


def finite(x):
    return type(x) in (int, float) and math.isfinite(x)


number = finite


def position(e):
    return (e['x'] * 32 + e['sx'], e['y'] * 32 + e['sy'])


def snapshot(e):
    return tuple(e[k] for k in ('x','y','z','sx','sy','generation','offset_owned'))


def validate(row):
    need(type(row) is dict and row.get('tick_lag_ds') == 0.5 and row.get('actual_clients') == 0,
         'mode and client gate')
    need(row.get('life_interval_ds') == 10 and row.get('start_delay_ds') == 6 and
         type(row.get('process_ticks')) is int and row['process_ticks'] > 0, 'real mob scheduler')
    start, end, events = row.get('started'), row.get('ended'), row.get('events')
    need(finite(start) and finite(end) and 4 <= end-start <= 114.5 and
         type(events) is list and 0 < len(events) <= 4096, 'bounded observation')
    for e in events:
        need(type(e) is dict and e.get('event') in EVENTS and e.get('phase') in ('flee','replacement','quiet'),
             'event vocabulary')
        need(finite(e.get('at')) and start <= e['at'] <= end, 'event time')
        need(all(type(e.get(k)) in (bool,int) and e[k] in (0,1) for k in FLAGS), 'owner fields')
        need(all(type(e.get(k)) is int and e[k] >= 0 for k in COUNTS), 'generation/counters')
        need(all(type(e.get(k)) is int for k in ('x','y','z','sx','sy')) and
             1 <= e['x'] <= 18 and 1 <= e['y'] <= 14 and e['z'] == 1 and
             0 <= e['sx'] < 32 and 0 <= e['sy'] < 32, 'canonical geometry')
        need(e['base_enabled'] == 1, 'base must stay enabled')
        need(not any(e[k] for k in ('pursuit','wild','pet')), 'competing producer')
        need(not (e['sx'] or e['sy']) or e['offset_owned'] == 1 or
             (e['event']=='move_after' and e['transaction'] and e['pulse']),
             'partial offset lacks owner')
    need(all(a['at'] <= b['at'] for a,b in zip(events,events[1:])), 'monotonic time')
    def unique(name):
        found = [(i,e) for i,e in enumerate(events) if e['event'] == name]
        need(len(found) == 1, 'missing or duplicate ' + name)
        return found[0]
    sb, before = unique('stop_before')
    sa, after = unique('stop_after')
    rq, request = unique('replacement_requested')
    own, owner = unique('follow_owner_observed')
    tb, timer_before = unique('old_timer_before')
    ta, timer_after = unique('old_timer_after')
    fs, final_before = unique('final_stop_before')
    fa, final_after = unique('final_stop_after')
    qe, quiet_end = unique('quiet_end')
    need(sb < sa < rq < own < tb < ta < fs < fa < qe == len(events)-1, 'lifecycle order')
    need(before['flee_old'] and before['transaction_old'] and before['transaction_owner'] == 'old_flee'
         and not before['old_finished'] and (before['sx'] or before['sy']) and before['offset_owned'],
         'active partial flee admission')
    need(position(after) == position(before) and after['offset_owned'] and not after['flee_old'] and
         after['generation'] > before['generation'] and after['old_cancelled'], 'stop must retain partial physical state')
    need(any(e['event']=='life_before' for e in events[:sb]) and
         any(e['event']=='life_after' for e in events[:sb]) and
         any(e['event']=='life_before' for e in events[rq:own]), 'scheduler Life observations')
    hooks = [e for e in events[sa:] if e['event']=='old_completion_hook']
    need(len(hooks)==1 and hooks[0]['old_hooks']==1, 'old completion must occur once')
    need(all(not e['old_arrived'] for e in events[sa:]), 'cancelled transaction reported arrival')
    need(owner['follow_new'] and owner['follow_any'] and owner['generation'] > before['generation'] and
         owner['old_finished'] and owner['old_hooks']==1, 'replacement ownership')
    need(timer_before['old_owner_retired'] and timer_before['follow_new'] and timer_after['follow_new'] and
         timer_before['generation']==timer_after['generation'] and
         snapshot(timer_before)==snapshot(timer_after) and timer_after['result']==0 and
         timer_before['old_timer_count']==0 and timer_after['old_timer_count']==1,
         'old ticket affected replacement')
    deadline=before.get('ticket_deadline')
    need(finite(deadline) and deadline > before['at'] and
         all(e.get('ticket_deadline')==deadline for e in events[sb:qe+1]) and
         0 <= timer_before['at']-deadline <= 0.5 and timer_before['at']==timer_after['at'],
         'old ticket deadline')
    pending_calls = {}; seen_calls = set()
    recovery_move = False
    follow_move = False
    for i,e in enumerate(events):
        name=e['event']
        if name=='move_before':
            ident=e.get('call_id')
            need(type(ident) is int and ident > 0 and ident not in seen_calls, 'move entry identity')
            need(e['transaction'] and e['pulse'] and type(e.get('transaction_generation')) is int,
                 'unauthenticated move entry')
            if i > sa:
                need(not e['transaction_old'] and e['transaction_owner'] in
                     ('recovery','new_follow','follow_before_capture'), 'stale old movement')
            need(i < fs, 'movement after final stop')
            pending_calls[ident]=e; seen_calls.add(ident)
        elif name=='move_after':
            ident=e.get('call_id')
            need(type(ident) is int and ident in pending_calls, 'missing move entry')
            pre=pending_calls.pop(ident)
            if (e['sx'] or e['sy']) and not e['offset_owned']:
                need(not pre['offset_owned'] and pre['sx']==0 and pre['sy']==0 and
                     pre['transaction'] and pre['pulse'], 'unowned partial outside initial pulse')
            need(type(e.get('result')) in (bool,int) and e['result'] in (0,1) and
                 e['generation']==pre['generation'] and e['transaction_generation']==pre['transaction_generation'] and
                 e['transaction_owner']==pre['transaction_owner'] and e['transaction_old']==pre['transaction_old'],
                 'move frame ownership changed')
            dx=abs(position(e)[0]-position(pre)[0]);dy=abs(position(e)[1]-position(pre)[1])
            need(dx <= 2 and dy <= 2 and dx+dy > 0, 'paid pulse displacement')
            if i > sa and pre['transaction_owner']=='recovery':
                need(pre['old_finished'] and pre['recovery'], 'recovery precedes retirement')
                recovery_move=True
            if i > own and pre['transaction_owner']=='new_follow':
                need(pre['follow_new'] and pre['transaction_generation']==pre['generation'],
                     'replacement transaction ownership')
                follow_move=True
    need(not pending_calls and recovery_move and follow_move, 'missing recovery or replacement travel')
    # Recovery must have reached an aligned endpoint before follow may start.
    first_follow = next((e for e in events[sa:] if e['event']=='move_before' and
                         e['transaction_owner'] in ('new_follow','follow_before_capture')), None)
    need(first_follow is not None and first_follow['sx']==0 and first_follow['sy']==0,
         'follow started before alignment')
    need(not any(final_after[k] for k in ('transaction','pulse','follow_any','flee_old','recovery','pending')),
         'final owner not retired')
    quiet=events[fa:qe+1]
    need(4 <= quiet_end['at']-final_after['at'] <= 4.5 and
         all(snapshot(e)==snapshot(final_after) for e in quiet) and
         all(not any(e[k] for k in ('transaction','pulse','follow_any','flee_old','recovery','pending')) for e in quiet) and
         all(e['event']!='move_before' for e in quiet), 'final quiet')
    samples=[e['at'] for e in quiet if e['event']=='quiet_sample']
    need(samples and 0 <= samples[0]-final_after['at'] <= 0.5 and
         0 <= quiet_end['at']-samples[-1] <= 0.5 and
         all(0 <= b-a <= 0.5 for a,b in zip(samples,samples[1:])), 'quiet sampling')
    return {'old_completion_hooks':1,'old_timer_calls':1,'recovery_move':True,
            'follow_move':True,'events':len(events)}

SCOPE='headless mob scheduler; enabled flee to follow handoff; no client/contact parity'


def validate_receipt(receipt, head):
    need(type(receipt) is dict and receipt.get('head') == head and receipt.get('error') is None and
         receipt.get('port') == 0 and (receipt.get('byond_version'), receipt.get('byond_build')) == (516,1688)
         and receipt.get('scope') == SCOPE and type(receipt.get('transition_checks')) is int and
         receipt['transition_checks'] > 0 and receipt.get('transition_phase') == 'quiet', 'receipt identity')
    rows=receipt.get('transition_rows')
    need(type(rows) is list and len(rows)==1, 'exactly one enabled handoff')
    observed=validate(rows[0])
    need(receipt.get('transition_partial') == rows[0]['events'], 'partial trace binding')
    return observed
