"""Offline receipt oracle for the proposed fixed-direction transition fixture.

No runtime or parity claim follows from importing or passing these checks.
"""
import math
import subprocess

CASES = ('blocked', 'cancel_replace')
TICK = 0.5
MAX_EVENTS = 512
MAX_TX = 12
MAX_MOVES = 210
SCOPE = 'fixed-direction obstruction and cancellation to paid recovery; no Life or contact acceptance'
MOVEMENT_BLOB = 'c658aa260cd486f5c8a82dc796e048c321362d54'
BASE_COMMIT = '1ac243fc150e88f69254727595010fd92c1003bb'
BASE_TREE = '59b91c75e5744b9ab03e4e6ce303d558d3f2e9b0'
# This exact set is filled from the reviewed integration delta, never widened at runtime.
ALLOWED_DELTA = frozenset({
    '.github/workflows/wildlife-cardinal-cadence.yml',
    'tests/human_subtile/cloud_npc_controller.py',
    'tests/human_subtile/cloud_npc_job.py',
    'tests/human_subtile/cloud_npc_smoke.py',
    'tests/human_subtile/test_cardinal_worker.py',
    'tests/human_subtile/transition_contract.py',
    'tests/human_subtile/transition_probe.dm',
    'tests/human_subtile/transition_stage.py',
    'tests/human_subtile/transition_worker.py',
    'tests/human_subtile/transition_evidence.py',
    'tests/human_subtile/test_transition_contract.py',
    'tests/human_subtile/test_transition_integration.py',
})


def require(ok, message):
    if not ok:
        raise ValueError(message)


def number(x):
    return type(x) in (float, int) and math.isfinite(x)


def validate_source(git, env, head):
    require(isinstance(head,str) and len(head)==40 and all(x in '0123456789abcdef' for x in head), 'head')
    actual=subprocess.check_output(git+['rev-parse',BASE_COMMIT+'^{tree}'],env=env,timeout=10).decode().strip()
    require(actual==BASE_TREE, 'transition base tree')
    result=subprocess.run(git+['merge-base','--is-ancestor',BASE_COMMIT,head],env=env,capture_output=True,timeout=10)
    require(result.returncode==0, 'transition base ancestry')
    raw=subprocess.check_output(git+['diff','--no-ext-diff','--no-renames','--name-only','-z',BASE_COMMIT,head,'--'],env=env,timeout=30)
    paths=raw.split(b'\0')
    require(paths[-1]==b'' and all(paths[:-1]), 'transition delta encoding')
    names=[p.decode('utf-8') for p in paths[:-1]]
    require(len(names)==len(set(names)) and frozenset(names)==ALLOWED_DELTA, 'transition exact source paths')
    return True


def position(event):
    require(all(type(event.get(k)) is int for k in ('x', 'y', 'z', 'sx', 'sy')), 'coordinate types')
    require(event['z'] == 1 and 1 <= event['x'] <= 65 and 1 <= event['y'] <= 65 and
            0 <= event['sx'] < 32 and 0 <= event['sy'] < 32, 'coordinate bounds')
    return event['x']*32 + event['sx'], event['y']*32 + event['sy']


def one(events, name):
    found = [i for i, event in enumerate(events) if event.get('event') == name]
    require(len(found) == 1, name + ' count')
    return found[0], events[found[0]]


def validate(row):
    require(isinstance(row, dict) and row.get('case') in CASES and row.get('tick') == TICK and
            row.get('lag') == 4 and row.get('life_count') == 0 and row.get('overflow') in (0, False), 'case setup')
    start, end = row.get('start'), row.get('end')
    # Initial admission wait <=8ds, one old 4ds cycle, retirement <=10ds,
    # recovery/replacement <=32ds and final cleanup <=10ds, plus tick slack.
    require(number(start) and number(end) and start <= end <= start + 65, 'time bound')
    events = row.get('events')
    require(isinstance(events, list) and 0 < len(events) <= MAX_EVENTS and row.get('event_count') == len(events), 'event bound')
    allowed = {'transition_start','transition_end','transition_blocked_end','transition_before','transition_after',
               'transition_old_completion','transition_old_terminal','transition_recovery','transition_replacement',
               'transition_wait_end','command_before','command_after','move_enter','move_exit','tx_admitted',
               'final_pulse','tx_actor_released','tx_finished'}
    require(all(isinstance(e, dict) for e in events), 'event structure')
    require(events[0].get('event') == 'transition_start' and events[-1].get('event') == 'transition_end', 'phase boundary')
    for event in (events[0], events[-1]):
        require(not event.get('transaction') and not event.get('pulse') and not event.get('owner') and
                not event.get('pending') and not event.get('recovery'), 'boundary ownership')
    initial = physical = position(events[0])
    start_detail=events[0].get('detail')
    require(initial == (12*32, 32*32) and isinstance(start_detail,dict) and
            all(start_detail.get(k)==v for k,v in {'bound_x':0,'bound_y':0,'bound_width':32,'bound_height':32}.items()),
            'initial position and bounds')
    stack, active, released, final = [], {}, {}, set()
    previous = start
    enters = exits = admissions = 0
    moves, terminals, admission_times = [], [], []
    for i, event in enumerate(events):
        label, at = event.get('event'), event.get('at')
        require(label in allowed and number(at) and previous <= at <= end and
                event.get('enabled') in (1, True) and event.get('life_depth') == 0 and event.get('step_size') == 32 and
                number(event.get('tick_usage')) and 0 <= event['tick_usage'] < 100, 'event state')
        previous = at
        now = position(event)
        tx = event.get('tx')
        if label == 'move_enter':
            require(len(stack) < 16 and (stack or now == physical) and event.get('active_tx') in active, 'move entry')
            stack.append((now, event.get('active_tx'), i))
            enters += 1
        elif label == 'move_exit':
            require(stack, 'unpaired move')
            before, owner, enter_index = stack.pop()
            require(owner == event.get('active_tx'), 'move ownership')
            dx, dy = now[0]-before[0], now[1]-before[1]
            require(abs(dx) <= 2 and abs(dy) <= 2 and not (dx and dy), 'non-pulse displacement')
            if not stack:
                physical = now
                moves.append((enter_index, i, owner, dx, dy))
            exits += 1
        elif not stack:
            require(now == physical, 'unobserved displacement')
        if label == 'tx_admitted':
            require(isinstance(tx, str) and tx and not active and event.get('active_tx') == tx and event.get('transaction') and
                    isinstance(event.get('tx_intent'),str) and event['tx_intent'], 'admission')
            active[tx] = (i,event['tx_intent'])
            admissions += 1
            admission_times.append(at)
        elif label == 'final_pulse':
            require(tx in active and tx not in final and event.get('remaining_x') == event.get('remaining_y') == 0, 'final pulse')
            final.add(tx)
        elif label == 'tx_actor_released':
            require(tx in active and tx not in released and not event.get('transaction') and
                    event.get('active_tx') is None and event.get('tx_finished') == 0 and
                    event.get('tx_actor_present') == 1 and event.get('arrived') in (0, 1), 'actor release')
            require(not event['arrived'] or tx in final, 'arrival without final pulse')
            released[tx] = event['arrived']
        elif label == 'tx_finished':
            require(tx in released and event.get('arrived') == released[tx] and event.get('tx_finished') == 1 and
                    not event.get('transaction') and event.get('active_tx') is None and all(event.get(k) == 0 for k in
                    ('tx_actor_present', 'tx_target_present', 'tx_combat_present', 'tx_following_present', 'tx_intent_present')),
                    'terminal cleanup')
            terminals.append((i, tx, event['arrived'], active[tx][1]))
            active.pop(tx); released.pop(tx); final.discard(tx)
    require(not stack and not active and not released and enters == exits == row.get('move_enter_count') ==
            row.get('move_exit_count') and admissions == row.get('tx_count') and
            1 <= enters <= MAX_MOVES and 1 <= admissions <= MAX_TX, 'incomplete accounting')
    commands = [e for e in events if e.get('event') == 'command_before']
    returns = [e for e in events if e.get('event') == 'command_after']
    command_indices = [i for i,e in enumerate(events) if e.get('event') == 'command_before']
    return_indices = [i for i,e in enumerate(events) if e.get('event') == 'command_after']
    require(len(commands) == len(returns) and all(e.get('detail') in (1, True) for e in returns), 'command results')
    expected_east = {'mode':'direction','lag':4,'speed_argument':0,'direction':4}
    first_admission=next(i for i,e in enumerate(events) if e.get('event')=='tx_admitted')
    require(commands and commands[0].get('detail') == expected_east and
            0 < command_indices[0] < return_indices[0] < first_admission, 'initial command')
    if row['case'] == 'blocked':
        index, blocked = one(events, 'transition_blocked_end')
        require(len(commands) == 1 and events[0].get('detail', {}).get('wall_dense') == 1 and
                blocked.get('detail', {}).get('wall_dense') == 1 and 2 <= admissions <= 3 and
                position(blocked) == initial and all(dx == dy == 0 for _, _, _, dx, dy in moves) and
                all(not arrived for _, _, arrived, _ in terminals) and admission_times[0] >= start+4 and
                all(b-a >= 4 for a,b in zip(admission_times, admission_times[1:])), 'blocked behavior')
        require(index < len(events)-1, 'blocked cleanup')
        return {'case':'blocked','attempts':admissions,'displacement':0}
    before_i, before = one(events, 'transition_before')
    after_i, after = one(events, 'transition_after')
    done_i, done = one(events, 'transition_old_terminal')
    recovery_i, recovery = one(events, 'transition_recovery')
    replacement_i, replacement = one(events, 'transition_replacement')
    wait_i, wait = one(events, 'transition_wait_end')
    old = before.get('tx')
    require(before_i < after_i < done_i < recovery_i < replacement_i < wait_i and
            isinstance(old, str) and old and before.get('transaction') and
            before.get('detail', {}).get('offset_owned') == 1 and (before['sx'] or before['sy']) and
            before.get('active_tx') == old and old in (after.get('tx'),) and old == done.get('tx') == wait.get('tx') and
            before.get('tx_finished') == 0 and before['at'] < before.get('detail', {}).get('old_end', 0) and
            any(e.get('event') == 'tx_admitted' and e.get('tx') == old and e.get('tx_intent') == before.get('owner')
                for e in events[:before_i]), 'preterminal ownership')
    require(position(before) == position(after) == position(done) and not after.get('owner') and
            type(before.get('generation')) is int and after.get('generation') == before['generation'] + 1 and
            not done.get('transaction') and
            not done.get('pulse') and not done.get('owner') and done.get('tx_finished') == 1 and
            done.get('arrived') == 0 and done.get('detail', {}).get('completions') == 1,
            'cancel completion or preserved offset')
    completion_i, _ = one(events, 'transition_old_completion')
    require(after_i < completion_i < done_i and sum(tx == old for _, tx, _, _ in terminals) == 1 and
            not any(a > after_i and owner == old for a, _, owner, _, _ in moves), 'stale old transaction')
    recovery_ref=recovery.get('recovery')
    require(isinstance(recovery_ref,str) and recovery_ref and replacement.get('recovery') == recovery_ref and
            recovery.get('detail', {}).get('recovery') == 1 and replacement.get('detail', {}).get('recovery') == 1 and
            replacement.get('detail', {}).get('pending') == 1 and len(commands) == 2 and
            recovery_i < command_indices[1] < return_indices[1] < replacement_i and
            commands[1].get('detail') == {'mode':'direction','lag':4,'speed_argument':0,'direction':1} and
            position(wait)[1] > initial[1], 'replacement/recovery')
    north = [a for a, _, owner, dx, dy in moves if a > replacement_i and dy > 0 and owner != old]
    require(north, 'replacement physical progress')
    north_tx=next(owner for a,_,owner,dx,dy in moves if a==north[0] and dy>0)
    require(any(e.get('event')=='tx_admitted' and e.get('tx')==north_tx and e.get('owner') and
                e.get('tx_intent')==e.get('owner') for e in events[replacement_i:north[0]]),
            'replacement owner mismatch')
    require(any(replacement_i < i < north[0] and tx != old and arrived == 1 and intent == recovery_ref and
                events[i]['sx'] == 0 and events[i]['sy'] == 0 for i, tx, arrived, intent in terminals),
            'paid recovery did not finish aligned before replacement')
    return {'case':'cancel_replace','old_tx':old,'old_completions':1,'north_progress':position(wait)[1]-initial[1]}


def validate_pair(rows):
    require(isinstance(rows,list) and len(rows)==2 and {r.get('case') for r in rows if isinstance(r,dict)} == set(CASES), 'case set')
    return [validate(row) for row in rows]


def validate_receipt(receipt, head):
    require(isinstance(receipt,dict) and receipt.get('head')==head and receipt.get('error') is None and
            receipt.get('port')==0 and (receipt.get('byond_version'),receipt.get('byond_build'))==(516,1688) and
            receipt.get('scope')==SCOPE and receipt.get('movement_blob')==MOVEMENT_BLOB and
            receipt.get('overflow') in (0,False), 'receipt identity')
    setup=receipt.get('setup')
    require(isinstance(setup,dict) and setup.get('requested_tick')==setup.get('actual_tick')==TICK and
            all(number(setup.get(k)) for k in ('startup_time','ready_time','startup_usage','ready_usage')) and
            0 <= setup['startup_time'] < setup['ready_time'] and 0 <= setup['ready_usage'] < 100, 'readiness')
    rows=receipt.get('transition_rows')
    require(isinstance(rows,list) and all(isinstance(r,dict) and number(r.get('start')) and
            r['start'] >= setup['ready_time'] for r in rows), 'transition case readiness')
    require(type(receipt.get('transition_checks')) is int and receipt['transition_checks'] > 0 and
            receipt.get('transition_case') == 'cancel_replace' and len(rows)==2 and rows[-1].get('case')=='cancel_replace' and
            isinstance(receipt.get('transition_partial'),list) and
            receipt['transition_partial']==rows[-1].get('events'), 'transition evidence continuity')
    return validate_pair(rows)
