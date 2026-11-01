"""Draft host-side checks for candidate bump observations, not a native runner.

Event ids are assigned per case and per admission. Raw BYOND references may be
reused and are diagnostic only. This module intentionally does not accept a
fixture until the real recorder and exact staged source have been reviewed.
"""
import math
import re

CASES = ('human_active', 'animal_active', 'human_idle', 'animal_idle')
MAX_EVENTS = 512
SCOPE = 'human-goat ordinary bump; headless authority adapter; no wildlife activation'


def require(condition, message):
    if not condition:
        raise ValueError(message)


def flag(value, expected):
    return type(value) in (int, bool) and value == int(expected)


def human_position(event):
    fields = ('human_x', 'human_y', 'human_z', 'human_sx', 'human_sy')
    require(all(type(event.get(k)) is int for k in fields), 'human position')
    return (event['human_x'] * 32 + event['human_sx'],
            event['human_y'] * 32 + event['human_sy'], event['human_z'])


def observed_position(event, role):
    keys = tuple(role + '_' + part for part in ('x', 'y', 'z', 'sx', 'sy'))
    require(all(type(event.get(key)) is int for key in keys), role + ' position fields')
    x, y, z, sx, sy = (event[key] for key in keys)
    require(1 <= x <= 18 and 1 <= y <= 14 and z == 1 and 0 <= sx < 32 and 0 <= sy < 32,
            role + ' position bounds')
    return (x * 32 + sx, y * 32 + sy, z)


def valid_displacement(role, case, start, end):
    dx, dy = end[0] - start[0], end[1] - start[1]
    if start[2] != end[2]:
        return False
    if role == 'human':
        return (0 <= dx <= 2 and dy == 0) if case == 'human_active' else (dx == 0 and 0 <= dy <= 2)
    return case == 'animal_active' and -2 <= dx <= 0 and dy == 0


def validate_candidate_after_impact(row, collision, human_done):
    """Attribute every post-impact position change to a bounded real Move frame."""
    events = row['events']
    case = row['case']
    tx, epoch = collision['human_admission'], collision['human_admission_epoch']
    move_kinds = {'human_move_before': ('human', True), 'human_move_after': ('human', False),
                  'animal_move_before': ('animal', True), 'animal_move_after': ('animal', False)}
    frames = []
    for event in events[:collision['ordinal']-1]:
        entry = move_kinds.get(event.get('kind'))
        if not entry:
            continue
        role, opening = entry
        require(event.get('actor_lifetime') == (1 if role == 'human' else 2), 'pre-impact move actor')
        if opening:
            frames.append((role, observed_position(event, role), observed_position(event, 'animal' if role == 'human' else 'human')))
        else:
            require(frames and frames[-1][0] == role, 'unpaired pre-impact move')
            frames.pop()
    expected_role = 'human' if case == 'human_active' else 'animal'
    require(len(frames) == 1 and frames[-1][0] == expected_role, 'collision move identity')
    position = {role: observed_position(collision, role) for role in ('human', 'animal')}
    other_role = 'animal' if expected_role == 'human' else 'human'
    require(valid_displacement(expected_role, case, frames[-1][1], position[expected_role]) and
            frames[-1][2] == position[other_role], 'collision displacement')
    animal_generation = collision.get('animal_generation')
    require(type(animal_generation) is int, 'animal generation')
    if case == 'animal_active':
        stopped_before = [e for e in events if e.get('kind') == 'animal_stop_before']
        stopped_after = [e for e in events if e.get('kind') == 'animal_stop_after']
        require(len(stopped_before) == len(stopped_after) == 1 and
                collision['ordinal'] < stopped_before[0]['ordinal'] < stopped_after[0]['ordinal'] and
                stopped_before[0].get('actor_lifetime') == stopped_after[0].get('actor_lifetime') == 2,
                'explicit animal stop')
        stop_before, stop_after = stopped_before[0], stopped_after[0]
        require(flag(stop_before.get('animal_wild_owner'), True) and
                stop_before.get('animal_owner_generation') == animal_generation and
                stop_before.get('animal_generation') == animal_generation and
                flag(stop_after.get('animal_wild_owner'), False) and
                stop_after.get('animal_generation') == animal_generation + 1, 'animal stop generation')
        animal_tx, animal_tx_generation = collision['animal_admission'], collision['animal_tx_generation']
    else:
        require(not any(e.get('kind') in ('animal_stop_before', 'animal_stop_after') for e in events),
                'unexpected animal stop')
    for event in events[collision['ordinal']-1:]:
        current = {role: observed_position(event, role) for role in ('human', 'animal')}
        for key in ('human_active', 'human_offset_owned', 'animal_active', 'animal_offset_owned',
                    'animal_wild_owner', 'animal_pending'):
            require(flag(event.get(key), True) or flag(event.get(key), False), 'invalid owner flag: ' + key)
        require(flag(event.get('human_offset_owned'), True), 'human offset ownership changed')
        if event['ordinal'] <= human_done['ordinal'] or flag(event.get('human_active'), True):
            require(flag(event.get('human_active'), True) and type(event.get('human_admission')) is int and
                    event['human_admission'] == tx and type(event.get('human_admission_epoch')) is int and
                    event['human_admission_epoch'] == epoch, 'human admission changed')
        else:
            require(flag(event.get('human_active'), False) and event.get('human_admission') is None and
                    event.get('human_admission_epoch') is None, 'invalid human release')
        if case == 'human_active':
            require(type(event.get('animal_generation')) is int and event['animal_generation'] == animal_generation and
                    flag(event.get('animal_active'), False) and flag(event.get('animal_wild_owner'), False) and
                    flag(event.get('animal_pending'), False), 'stationary goat ownership changed')
        else:
            required_gen = animal_generation if event['ordinal'] <= stop_before['ordinal'] else animal_generation + 1
            if event['ordinal'] < stop_after['ordinal']:
                required_gen = animal_generation
            require(type(event.get('animal_generation')) is int and event['animal_generation'] == required_gen and
                    flag(event.get('animal_pending'), False),
                    'animal generation changed outside explicit stop')
            if event['ordinal'] < stop_after['ordinal']:
                require(flag(event.get('animal_wild_owner'), True) and type(event.get('animal_owner_generation')) is int and
                        event['animal_owner_generation'] == animal_generation, 'animal owner changed before stop')
            else:
                require(flag(event.get('animal_wild_owner'), False) and
                        event.get('animal_owner_generation') is None, 'animal owner persisted after stop')
            if flag(event.get('animal_active'), True):
                require(type(event.get('animal_admission')) is int and event['animal_admission'] == animal_tx and
                        type(event.get('animal_tx_generation')) is int and
                        event['animal_tx_generation'] == animal_tx_generation, 'animal admission changed')
            elif event.get('animal_admission') is not None:
                require(event.get('kind') in ('animal_living_before', 'animal_living_after', 'animal_tx_finished') and
                        type(event.get('animal_admission')) is int and event['animal_admission'] == animal_tx,
                        'unexpected released animal admission')
            if event.get('animal_admission') == animal_tx:
                require(type(event.get('animal_tx_generation')) is int and
                        event['animal_tx_generation'] == animal_tx_generation, 'animal transaction generation changed')
        entry = move_kinds.get(event.get('kind'))
        if entry:
            require(event.get('actor_lifetime') == (1 if entry[0] == 'human' else 2), 'post-impact move actor')
        if entry and entry[1]:
            role = entry[0]
            require(current == position, 'unobserved movement before Move')
            if role == 'human':
                require(event.get('human_admission') == tx and event.get('human_admission_epoch') == epoch,
                        'new human movement admission')
            else:
                require(case == 'animal_active' and event.get('animal_admission') == animal_tx and
                        event.get('animal_tx_generation') == animal_tx_generation, 'new animal movement admission')
            frames.append((role, current[role], current['animal' if role == 'human' else 'human']))
        else:
            changed = [role for role in ('human', 'animal') if current[role] != position[role]]
            if changed:
                require(len(changed) == 1 and frames and frames[-1][0] == changed[0] and
                        valid_displacement(changed[0], case, frames[-1][1], current[changed[0]]),
                        'unattributed, excessive or reversed displacement')
            if entry:
                require(frames and frames[-1][0] == entry[0] and
                        valid_displacement(entry[0], case, frames[-1][1], current[entry[0]]), 'unpaired move exit')
                frames.pop()
        position = current
    require(not frames and sum(e.get('kind') == 'terminal' for e in events) == 1 and
            events[-1].get('kind') == 'terminal' and events[-1].get('actor_lifetime') == 1 and
            flag(events[-1].get('human_active'), False) and flag(events[-1].get('animal_active'), False) and
            flag(events[-1].get('animal_wild_owner'), False) and flag(events[-1].get('animal_pending'), False),
            'terminal movement state')
    if events[-1]['animal_sx'] or events[-1]['animal_sy']:
        require(flag(events[-1].get('animal_offset_owned'), True), 'terminal animal offset ownership')
    result = row.get('legacy_result')
    require(type(result) is dict and all(result.get(role + '_' + part) == events[-1].get(role + '_' + part)
            for role in ('human', 'animal') for part in ('x', 'y', 'sx', 'sy')), 'terminal position mismatch')


def validate_row(row, candidate):
    require(type(row) is dict and row.get('case') in CASES, 'case')
    case = row['case']
    active = case.endswith('_active')
    require(flag(row.get('headless_authority'), True) and row.get('actual_tick') == 0.5,
            'setup')
    require(type(row.get('human_lifetime')) is int and row['human_lifetime'] == 1 and
            type(row.get('animal_lifetime')) is int and row['animal_lifetime'] == 2,
            'case-scoped actor lifetimes')
    events = row.get('events')
    require(type(events) is list and 0 < len(events) <= MAX_EVENTS, 'event bound')
    previous = -1.0
    for index, event in enumerate(events, 1):
        require(type(event) is dict and type(event.get('ordinal')) is int and event['ordinal'] == index, 'event ordinal')
        at = event.get('time')
        require(type(at) in (int, float) and math.isfinite(at) and at >= previous, 'time')
        require(type(event.get('actor_lifetime')) is int and event['actor_lifetime'] in (1, 2), 'event actor lifetime')
        previous = at
    collisions = [e for e in events if e.get('kind') == 'collision']
    deferred = [e for e in events if e.get('kind') == 'deferred']
    require(len(collisions) == 1 and len(deferred) == 1 and
            collisions[0]['ordinal'] < deferred[0]['ordinal'], 'collision lifecycle')
    collision = collisions[0]
    expected_mover = 1 if case.startswith('human_') else 2
    require(collision['actor_lifetime'] == expected_mover and type(collision.get('collision_id')) is int and
            type(deferred[0].get('collision_id')) is int and deferred[0]['collision_id'] == collision['collision_id'] == 1,
            'collision identity')
    require(flag(row.get('overflow'), False) and flag(row.get('quiesced'), True), 'terminal')
    if active:
        tx = collision.get('human_admission')
        require(type(tx) is int and tx > 0 and type(collision.get('human_admission_epoch')) is int and
                collision['human_admission_epoch'] == 1 and
                flag(collision.get('human_active'), True) and flag(collision.get('human_offset_owned'), True) and
                type(collision.get('human_sx')) is int and type(collision.get('human_sy')) is int and
                (collision['human_sx'] != 0 or collision['human_sy'] != 0), 'active collision precondition')
        terminals = [e for e in events if e.get('kind') == 'human_completed' and
                     e.get('human_admission') == tx and e.get('human_admission_epoch') == 1]
        require(len(terminals) == 1 and terminals[0]['actor_lifetime'] == 1 and
                terminals[0]['ordinal'] > collision['ordinal'], 'transaction completion')
        living = [e for e in events if e.get('kind') == 'human_living_completed' and
                  e.get('human_admission') == tx and e.get('human_admission_epoch') == 1]
        require(len(living) == 1 and living[0]['actor_lifetime'] == 1 and
                collision['ordinal'] < living[0]['ordinal'] < terminals[0]['ordinal'], 'living completion')
        stack, progress = [], False
        for event in events[:collision['ordinal']-1]:
            if event.get('kind') not in ('human_move_before', 'human_move_after'):
                continue
            require(type(event.get('human_admission')) is int and event['human_admission'] == tx and
                    type(event.get('human_admission_epoch')) is int and event['human_admission_epoch'] == 1,
                    'human move admission identity')
            if event['kind'] == 'human_move_before':
                stack.append(human_position(event))
            else:
                require(stack, 'unpaired human move exit')
                initial = stack.pop()
                final = human_position(event)
                require(initial[2] == final[2] and abs(initial[0] - final[0]) <= 2 and
                        abs(initial[1] - final[1]) <= 2, 'human pulse displacement')
                progress |= initial != final
        # The human's Move calls Bump only in the human-mover scenario.
        require(progress and len(stack) == (1 if case == 'human_active' else 0),
                'human real progress and in-flight collision')
        if case == 'human_active':
            require(any(e.get('kind') == 'swap_branch' and e.get('collision_id') == 1 for e in events),
                    'ordinary swap branch not reached')
            if not candidate:
                require(sum(e.get('kind') == 'legacy_swap_leg_before' and e.get('collision_id') == 1
                            for e in events) == 2, 'baseline swap legs not reached')
        if case == 'animal_active':
            require(flag(collision.get('animal_active'), True) and
                    type(collision.get('animal_admission')) is int and collision['animal_admission'] > 0 and
                    type(collision.get('animal_generation')) is int and
                    type(collision.get('animal_tx_generation')) is int and
                    type(collision.get('animal_owner_generation')) is int and
                    collision.get('animal_tx_generation') == collision['animal_generation'] and
                    collision.get('animal_owner_generation') == collision['animal_generation'],
                    'animal owner identity at collision')
            def same_animal(e):
                return (type(e.get('animal_admission')) is int and e['animal_admission'] == collision['animal_admission'] and
                        type(e.get('animal_tx_generation')) is int and e['animal_tx_generation'] == collision['animal_tx_generation'])
            animal_before = [e for e in events if e.get('kind') == 'animal_living_before' and same_animal(e)]
            animal_after = [e for e in events if e.get('kind') == 'animal_living_after' and same_animal(e)]
            animal_done = [e for e in events if e.get('kind') == 'animal_tx_finished' and same_animal(e)]
            require(len(animal_before) == len(animal_after) == len(animal_done) == 1 and
                    animal_before[0]['actor_lifetime'] == animal_after[0]['actor_lifetime'] == animal_done[0]['actor_lifetime'] == 2 and
                    collision['ordinal'] < animal_before[0]['ordinal'] < animal_after[0]['ordinal'] < animal_done[0]['ordinal'] and
                    flag(animal_done[0].get('animal_tx_finished'), True), 'animal completion')
            require(not any(e.get('kind') == 'animal_move_before' and same_animal(e)
                            for e in events[animal_done[0]['ordinal']:]), 'late animal movement')
            require(not any(e.get('kind') in ('swap_branch', 'legacy_push_before') and e.get('collision_id') == 1
                            for e in events), 'unexpected animal active branch')
        for event in events[terminals[0]['ordinal']:]:
            require(not (event.get('kind') in ('human_pulse', 'human_move_before') and
                         event.get('human_admission') == tx and event.get('human_admission_epoch') == 1),
                    'late old pulse')
            if candidate:
                require(event.get('kind') not in ('human_pulse', 'human_move_before'),
                        'unrequested later human movement')
        if candidate:
            require(flag(deferred[0].get('latched_guard'), True), 'latched guard')
            require(not any(e.get('kind') in ('legacy_swap_leg_before', 'legacy_push_before') and
                            e.get('collision_id') == 1 for e in events), 'protected displacement')
            validate_candidate_after_impact(row, collision, terminals[0])
    else:
        require(flag(collision.get('human_active'), False) and collision.get('human_sx') == 0 and
                collision.get('human_sy') == 0, 'idle precondition')
        branch = [e for e in events if e.get('kind') == 'swap_branch' and e.get('collision_id') == 1]
        legs = [e for e in events if e.get('kind') == 'legacy_swap_leg_before' and e.get('collision_id') == 1]
        require((len(branch) == 1 and len(legs) == 2) if case == 'human_idle' else
                (not branch and not legs), 'idle directional branch')
    return True


def validate_pair(baseline, candidate):
    require(type(baseline) is list and type(candidate) is list and
            all(type(r) is dict for r in baseline + candidate) and
            [r.get('case') for r in baseline] == list(CASES) and
            [r.get('case') for r in candidate] == list(CASES), 'four ordered cases')
    for old, new in zip(baseline, candidate):
        validate_row(old, False)
        validate_row(new, True)
        if old['case'].endswith('_idle'):
            require(old.get('legacy_result') == new.get('legacy_result') and
                    type(old.get('legacy_result')) is dict, 'idle behavior mismatch')
            kinds = ('swap_branch', 'canpass_before', 'canpass_after', 'legacy_swap_leg_before', 'legacy_swap_leg_after',
                     'bumped_before', 'bumped_after', 'turf_enter_before', 'turf_enter_after',
                     'turf_exit_before', 'turf_exit_after',
                     'parent_bump_before', 'parent_bump_after', 'legacy_push_before', 'legacy_push_after')
            projection = lambda row: [(e['kind'], e['actor_lifetime'], e.get('detail'),
                                       tuple(e.get(k) for k in ('human_x', 'human_y', 'human_sx', 'human_sy',
                                                                'animal_x', 'animal_y', 'animal_sx', 'animal_sy')))
                                      for e in row['events'] if e['kind'] in kinds]
            require(projection(old) == projection(new), 'idle callback mismatch')
    return True


def validate_receipt(data, head, candidate):
    require(type(head) is str and re.fullmatch('[0-9a-f]{40}', head), 'source head')
    require(type(data) is dict and data.get('head') == head and data.get('error') is None and
            data.get('byond_version') == 516 and data.get('byond_build') == 1688 and
            data.get('port') == 0 and data.get('scope') == SCOPE and
            data.get('bump_variant') == ('candidate' if candidate else 'baseline'), 'receipt identity')
    setup = data.get('bump_setup')
    require(type(setup) is dict and setup.get('tick') == 0.5 and
            type(setup.get('startup_time')) in (int, float) and
            type(setup.get('ready_time')) in (int, float) and
            math.isfinite(setup['startup_time']) and math.isfinite(setup['ready_time']) and
            setup['ready_time'] > setup['startup_time'] and
            type(setup.get('ready_usage')) in (int, float) and math.isfinite(setup['ready_usage']) and
            0 <= setup['ready_usage'] < 100, 'initialization boundary')
    rows = data.get('bump_rows')
    require(type(rows) is list and all(type(row) is dict for row in rows) and
            [row.get('case') for row in rows] == list(CASES) and
            type(data.get('bump_checks')) is int and data['bump_checks'] > 0 and
            flag(data.get('bump_overflow'), False) and data.get('bump_case') == CASES[-1] and
            data.get('bump_partial') == rows[-1].get('events'), 'receipt completeness')
    for row in rows:
        validate_row(row, candidate)
    return rows
