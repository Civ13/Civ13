"""Host-side contract for a future fixture-only cardinal timing lane.

No native execution or controller wiring is performed by this module.
"""
import math
import subprocess

TICKS = (0.5, 1.0)
LAGS = (3, 4)
MODES = ('legacy', 'smooth')
MAX_EVENTS = 512
OBSERVATION_DS = 16
SOURCE_MOVEMENT_BLOB = 'c658aa260cd486f5c8a82dc796e048c321362d54'
BASE_COMMIT = '40e9f25336eb0ce1f5abcc1e6e33c3bd90529ee9'
BASE_TREE = 'b7fb57be52ceb22328b2ebe05d7ad50c194f557d'
ALLOWED_DELTA = frozenset({
    'code/game/mob/living/simple_animal/subtile_movement.dm',
    'code/game/mob/living/simple_animal/hostile/mosquitoes.dm',
    'code/game/mob/living/simple_animal/hostile/vampirebat.dm',
    'tests/human_subtile/test_random_cadence_contract.py',
    'tests/human_subtile/cardinal_contract.py',
    'tests/human_subtile/cardinal_stage.py',
    'tests/human_subtile/test_cardinal_contract.py',
})
SCOPE = 'one held cardinal mosquito movement command; no Life, random, contact or gameplay acceptance'


def require(condition, message):
    if not condition:
        raise ValueError(message)


def number(value):
    return type(value) in (int, float) and math.isfinite(value)


def validate_source(git, env, head):
    """Enforce reviewed ancestry/path scope; caller must bind the full head/tree."""
    require(isinstance(head,str) and len(head)==40 and all(x in '0123456789abcdef' for x in head), 'head')
    tree=subprocess.check_output(git+['rev-parse',BASE_COMMIT+'^{tree}'],env=env,timeout=10).decode('ascii').strip()
    require(tree==BASE_TREE,'cardinal base tree')
    ancestor=subprocess.run(git+['merge-base','--is-ancestor',BASE_COMMIT,head],env=env,
                            capture_output=True,timeout=10)
    require(ancestor.returncode==0,'cardinal base ancestry')
    raw=subprocess.check_output(git+['diff','--no-ext-diff','--no-renames','--name-only','-z',BASE_COMMIT,head,'--'],
                                env=env,timeout=30)
    paths=raw.split(b'\0')
    require(paths[-1]==b'' and all(paths[:-1]),'cardinal delta encoding')
    paths=[item.decode('utf-8') for item in paths[:-1]]
    require(len(paths)==len(set(paths)) and frozenset(paths)==ALLOWED_DELTA,'cardinal exact source paths')
    return True


def position(event):
    for k in ('x', 'y', 'z', 'sx', 'sy'):
        require(type(event.get(k)) is int, 'nonintegral coordinates')
    require(1 <= event['x'] <= 65 and 1 <= event['y'] <= 65 and event['z'] == 1 and
            0 <= event['sx'] < 32 and 0 <= event['sy'] < 32, 'coordinate bounds')
    return event['x'] * 32 + event['sx'], event['y'] * 32 + event['sy'], event['z']


def validate_case(row, mode, tick, lag):
    require(mode in MODES and tick in TICKS and type(lag) is int and lag in LAGS, 'case selector')
    require(isinstance(row, dict) and row.get('enabled') == (mode == 'smooth') and
            row.get('lag_ticks') == lag and row.get('tick_lag_ds') == tick and
            row.get('converted_ds') == lag and row.get('observation_ds') == OBSERVATION_DS and
            number(row.get('step_size')) and row['step_size'] > 0 and row.get('life_count') == 0,
            'case setup')
    start, end = row.get('started'), row.get('ended')
    require(number(start) and number(end) and OBSERVATION_DS <= end-start <= OBSERVATION_DS+11,
            'case duration')
    events = row.get('events')
    require(isinstance(events, list) and 0 < len(events) <= MAX_EVENTS and row.get('event_count') == len(events),
            'event count')
    require(all(isinstance(e, dict) for e in events), 'event structure')
    require(events[0].get('event') == 'phase_start' and events[0].get('at') == start and
            events[-1].get('event') == 'phase_end' and events[-1].get('at') == end and
            sum(e.get('event') == 'phase_start' for e in events) == 1 and
            sum(e.get('event') == 'phase_end' for e in events) == 1, 'boundaries')
    for e in (events[0], events[-1]):
        require(not e.get('transaction') and not e.get('pulse') and e.get('owner') is None and
                e.get('pending') is None, 'boundary ownership')
    physical = position(events[0])
    stack, active, final, released = [], {}, set(), {}
    first_moves, admissions, final_pulses, finished = [], [], [], []
    command = None
    command_time = None
    commands = 0
    observation_end = None
    allowed = {'phase_start', 'phase_end', 'observation_end', 'command_before', 'command_after', 'move_enter', 'move_exit',
               'tx_admitted', 'final_pulse', 'tx_actor_released', 'tx_finished'}
    previous = start
    for e in events:
        label, at = e.get('event'), e.get('at')
        require(label in allowed and number(at) and previous <= at <= end and
                e.get('life_depth') == 0 and e.get('enabled') == row['enabled'] and
                e.get('step_size') == row['step_size'] and
                number(e.get('tick_usage')) and 0 <= e['tick_usage'] < 100, 'event timing/state')
        previous = at
        now = position(e)
        if label == 'move_enter':
            require(observation_end is None, 'move began after stop')
            require(len(stack) < 16 and (stack or now == physical), 'move entry')
            require(mode == 'legacy' or e.get('active_tx') in active, 'unowned move')
            stack.append((now, at, e.get('active_tx')))
        elif label == 'move_exit':
            require(stack, 'move return without entry')
            before, move_at, tx = stack.pop()
            require(mode == 'legacy' or tx == e.get('active_tx'), 'move owner changed')
            dx, dy = now[0] - before[0], now[1] - before[1]
            require(now[2] == before[2] and 0 <= dx <= (32 if mode == 'legacy' else 2) and dy == 0,
                    'wrong direction or displacement')
            if not stack:
                physical = now
                if dx:
                    first_moves.append((move_at, dx))
        elif not stack:
            require(now == physical, 'unobserved displacement')
        if label == 'command_before':
            require(command is None and commands == 0 and isinstance(e.get('detail'), dict) and
                    e['detail'] == {'mode': 'direction', 'lag': lag, 'speed_argument': 0, 'direction': 4},
                    'command issue')
            command = e
            command_time = at
        elif label == 'command_after':
            require(command is not None, 'command return')
            if mode == 'smooth':
                require(e.get('detail') in (1, True) and e.get('owner'), 'smooth command rejected')
            commands += 1
            command = None
        elif label == 'tx_admitted':
            require(observation_end is None, 'admission after stop')
            tx = e.get('tx')
            require(mode == 'smooth' and not active and isinstance(tx, str) and tx and
                    e.get('active_tx') == tx and e.get('transaction') and e.get('tx_dir') == 4 and
                    e.get('remaining_x') == 32 and e.get('remaining_y') == 0, 'transaction admission')
            active[tx] = (at, now)
            admissions.append(at)
        elif label == 'observation_end':
            require(observation_end is None and start+OBSERVATION_DS <= at <= start+OBSERVATION_DS+tick,
                    'observation boundary')
            observation_end = at
        elif label == 'final_pulse':
            tx = e.get('tx')
            require(tx in active and tx not in final and e.get('remaining_x') == 0 and
                    e.get('remaining_y') == 0 and now == (active[tx][1][0] + 32, active[tx][1][1], active[tx][1][2]),
                    'invalid final pulse')
            final.add(tx)
            final_pulses.append({'at':at,'tx':tx})
        elif label == 'tx_actor_released':
            tx = e.get('tx')
            require(tx in active and tx not in released and not e.get('transaction') and
                    e.get('active_tx') is None and e.get('tx_finished') == 0 and
                    e.get('tx_actor_present') == 1 and e.get('arrived') in (0, 1), 'actor release')
            require(not e['arrived'] or tx in final, 'arrival without final pulse')
            released[tx] = e['arrived']
        elif label == 'tx_finished':
            tx = e.get('tx')
            require(tx in released and e.get('arrived') == released[tx] and e.get('tx_finished') == 1 and not e.get('transaction') and
                    e.get('active_tx') is None and all(e.get(k) == 0 for k in
                    ('tx_actor_present', 'tx_target_present', 'tx_combat_present', 'tx_following_present', 'tx_intent_present')),
                    'terminal cleanup')
            finished.append({'at': at, 'admitted':active[tx][0], 'arrived': e.get('arrived'), 'tx': tx})
            active.pop(tx)
            released.pop(tx)
            final.discard(tx)
    require(not stack and not active and not released and command is None and commands == 1 and
            observation_end is not None, 'incomplete phase')
    enters=sum(e.get('event')=='move_enter' for e in events)
    exits=sum(e.get('event')=='move_exit' for e in events)
    transactions=sum(e.get('event')=='tx_admitted' for e in events)
    require(3 <= enters == exits <= 210 and enters == row.get('move_enter_count') and
            exits == row.get('move_exit_count') and transactions == row.get('tx_count') and
            transactions <= 12 and (mode == 'smooth' or transactions == 0), 'observation counts')
    starts = [at for at, dx in first_moves if mode == 'legacy'] if mode == 'legacy' else admissions
    require(sum(at < observation_end for at in starts) >= 3 and
            sum(at < observation_end for at, dx in first_moves) >= 3, 'insufficient observed movement')
    if mode == 'smooth':
        require(sum(item['arrived'] == 1 and item['at'] <= observation_end for item in finished) >= 2,
                'insufficient completed cycles')
    return {'command_at':command_time,'starts': starts, 'first_start_delay':starts[0]-command_time,
            'start_intervals': [b-a for a,b in zip(starts, starts[1:])],
            'first_physical_move': first_moves[0][0], 'first_physical_delay':first_moves[0][0]-command_time,
            'final_pulses':final_pulses, 'finished': finished}


def validate_receipt(receipt, head, mode, tick):
    require(isinstance(head, str) and len(head) == 40 and all(x in '0123456789abcdef' for x in head), 'head')
    require(isinstance(receipt, dict) and receipt.get('head') == head and receipt.get('error') is None and
            receipt.get('port') == 0 and (receipt.get('byond_version'), receipt.get('byond_build')) == (516, 1688) and
            receipt.get('scope') == SCOPE and receipt.get('mode') == mode and receipt.get('tick') == tick and
            receipt.get('overflow') in (0, False) and receipt.get('movement_blob') == SOURCE_MOVEMENT_BLOB,
            'receipt identity')
    setup = receipt.get('setup')
    require(isinstance(setup, dict) and setup.get('requested_tick') == tick and setup.get('actual_tick') == tick and
            all(number(setup.get(k)) for k in ('startup_time', 'ready_time', 'startup_usage', 'ready_usage')) and
            0 <= setup['startup_time'] < setup['ready_time'] and 0 <= setup['ready_usage'] < 100,
            'readiness')
    rows = receipt.get('rows')
    require(isinstance(rows, list) and len(rows) == len(LAGS), 'case set')
    cases = {}
    for row in rows:
        require(isinstance(row, dict) and type(row.get('lag_ticks')) is int and row['lag_ticks'] in LAGS and
                row['lag_ticks'] not in cases, 'duplicate or unexpected lag')
        require(number(row.get('started')) and row['started'] >= setup['ready_time'], 'case precedes readiness')
        cases[row['lag_ticks']] = validate_case(row, mode, tick, row['lag_ticks'])
    return cases


def compare(receipts, head, tick):
    require(isinstance(receipts, dict) and set(receipts) == set(MODES), 'mode set')
    results = {mode: validate_receipt(receipts[mode], head, mode, tick) for mode in MODES}
    return {'tick': tick, 'source_movement_blob': SOURCE_MOVEMENT_BLOB, 'parity_established': False,
            'cases': {str(lag): {mode: results[mode][lag] for mode in MODES} for lag in LAGS}}
