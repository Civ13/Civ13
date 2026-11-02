"""Validate observations, never infer swap safety or gameplay parity."""
import math
import re

SCOPE = 'human-goat forceMove versus raw loc assignment; observational fixture only'
CASES = ('none', 'owner', 'relocate', 'delete', 'yield', 'throw')
MODES = ('legacy', 'pair_first')
MAX_EVENTS = 256
LABELS = frozenset({
    'start', 'first_before', 'first_after', 'second_before', 'second_after',
    'second_skipped_deleted', 'fixture_injection_before', 'action_before',
    'action_after', 'repeated_action_suppressed', 'owner_admission_return',
    'delete_requested', 'yield_before', 'yield_after', 'throw_requested',
    'caught_exception', 'terminal', 'turf_entered_before', 'turf_entered_after',
    'turf_exited_before', 'turf_exited_after', 'human_uncrossed_before',
    'human_uncrossed_after', 'human_crossed_before', 'human_crossed_after',
    'animal_uncrossed_before', 'animal_uncrossed_after', 'animal_crossed_before',
    'animal_crossed_after', 'animal_move_before', 'animal_move_after',
})
PHASES = frozenset({'before_first', 'first_leg', 'second_leg', 'after_commit', 'settling'})


def require(ok, message):
    if not ok:
        raise ValueError(message)


def flag(value, expected):
    return type(value) in (bool, int) and value == int(expected)


def unique(events, label):
    found = [event for event in events if event.get('label') == label]
    require(len(found) == 1, 'missing or duplicate ' + label)
    return found[0]


def row(row, mode):
    require(type(row) is dict and row.get('mode') == mode and row.get('case') in CASES,
            'case identity')
    case = row['case']
    require(flag(row.get('overflow'), False), 'event overflow')
    error = row.get('error')
    require(error is None or (case == 'throw' and error == 'pair_fixture_callback_throw'),
            'unexpected case error')
    action = row.get('action')
    require(type(action) is dict and action.get('action') == case and
            action.get('origin') in ('native_crossed', 'fixture_post_commit'), 'action identity')
    events = row.get('events')
    require(type(events) is list and 0 < len(events) <= MAX_EVENTS, 'events')
    previous = -1
    for index, event in enumerate(events, 1):
        require(type(event) is dict and type(event.get('ordinal')) is int and
                event['ordinal'] == index and event.get('case') == case and
                event.get('mode') == mode and type(event.get('human_lifetime')) is int and
                event['human_lifetime'] == 1 and type(event.get('animal_lifetime')) is int and
                event['animal_lifetime'] == 2, 'event identity')
        require(event.get('label') in LABELS and event.get('phase') in PHASES, 'event kind')
        at = event.get('at')
        require(type(at) in (int, float) and math.isfinite(at) and at >= previous, 'event time')
        previous = at
        for key in ('human_live', 'animal_live', 'human_tx', 'animal_tx', 'admission_recorded'):
            require(flag(event.get(key), False) or flag(event.get(key), True), 'event flag ' + key)
        for role in ('human', 'animal'):
            if flag(event.get(role + '_live'), True):
                keys = [role + '_' + x for x in ('x', 'y', 'z', 'sx', 'sy')]
                require(all(type(event.get(k)) is int for k in keys), role + ' snapshot')
                require(1 <= event[keys[0]] <= 18 and 1 <= event[keys[1]] <= 14 and
                        event[keys[2]] == 1 and 0 <= event[keys[3]] < 32 and
                        0 <= event[keys[4]] < 32, role + ' geometry')
    start, first, begin, terminal = (unique(events, x) for x in
                                     ('start', 'first_before', 'action_before', 'terminal'))
    require(start['ordinal'] < first['ordinal'] < begin['ordinal'] < terminal['ordinal'] and
            events[-1] is terminal and flag(start.get('human_live'), True) and
            flag(start.get('animal_live'), True) and start['human_x'] == 5 and start['human_y'] == 5 and
            start['animal_x'] == 6 and start['animal_y'] == 5 and
            all(start[k] == 0 for k in ('human_sx', 'human_sy', 'animal_sx', 'animal_sy')) and
            flag(start['human_tx'], False) and flag(start['animal_tx'], False), 'case start')
    require(begin.get('detail') == action['origin'], 'action origin does not match trace')
    if case != 'throw':
        first_after = unique(events, 'first_after')
        second_before = unique(events, 'second_before')
        second_done = [x for x in events if x.get('label') in ('second_after', 'second_skipped_deleted')]
        require(len(second_done) == 1 and first['ordinal'] < first_after['ordinal'] <
                second_before['ordinal'] < second_done[0]['ordinal'] < terminal['ordinal'],
                'incomplete leg lifecycle')
        if mode == 'legacy':
            require(begin['ordinal'] < first_after['ordinal'], 'legacy action after first leg')
    if mode == 'legacy':
        crossed = [x for x in events if x.get('label') == 'animal_crossed_before' and
                   x.get('detail') == 'human' and x['ordinal'] < begin['ordinal']]
        require(action['origin'] == 'native_crossed' and crossed and
                crossed[-1]['phase'] == 'first_leg' and begin['phase'] == 'first_leg',
                'legacy callback boundary')
    elif action['origin'] == 'fixture_post_commit':
        second = unique(events, 'second_after')
        injected = unique(events, 'fixture_injection_before')
        require(second['ordinal'] < injected['ordinal'] < begin['ordinal'] and
                begin['phase'] == 'after_commit' and not any(
                    x.get('label') == 'animal_crossed_before' and x.get('detail') == 'human' and
                    x['ordinal'] < begin['ordinal'] for x in events), 'fixture injection attribution')
    else:
        crossed = [x for x in events if x.get('label') == 'animal_crossed_before' and
                   x.get('detail') == 'human' and x['ordinal'] < begin['ordinal']]
        require(crossed and
                begin['phase'] in ('first_leg', 'second_leg') and
                not any(x.get('label') == 'fixture_injection_before' for x in events),
                'native assignment callback attribution')
    if case == 'owner':
        owner = unique(events, 'owner_admission_return')
        require(flag(action.get('returned'), True) and flag(action.get('admission_recorded'), True) and
                flag(action.get('current_at_return'), True) and flag(owner.get('animal_tx'), True) and
                flag(owner.get('admission_recorded'), True) and flag(owner.get('admission_is_current'), True) and
                flag(terminal.get('animal_live'), True) and flag(terminal.get('animal_tx'), False) and
                flag(terminal.get('admission_recorded'), True) and flag(terminal.get('admission_finished'), True) and
                begin['ordinal'] < owner['ordinal'] < terminal['ordinal'],
                'movement admission or retirement')
    elif case == 'relocate':
        after = unique(events, 'action_after')
        require(begin['ordinal'] < after['ordinal'] < terminal['ordinal'] and
                flag(action.get('returned'), True) and after.get('human_x') == 8 and
                after.get('human_y') == 8 and flag(after.get('human_live'), True), 'relocation observation')
    elif case == 'delete':
        request = unique(events, 'delete_requested')
        require(begin['ordinal'] < request['ordinal'] < terminal['ordinal'] and
                any(x['ordinal'] > request['ordinal'] and flag(x.get('animal_live'), False)
                    for x in events), 'deletion observation')
    elif case == 'yield':
        before, after = unique(events, 'yield_before'), unique(events, 'yield_after')
        require(begin['ordinal'] < before['ordinal'] < after['ordinal'] < terminal['ordinal'] and
                after['at'] > before['at'] and
                flag(action.get('returned'), True), 'yield observation')
    elif case == 'throw':
        thrown = unique(events, 'throw_requested')
        require(begin['ordinal'] < thrown['ordinal'] < terminal['ordinal'] and
                not any(x.get('label') == 'action_after' for x in events), 'throw outcome')
    else:
        require(flag(action.get('returned'), True), 'ordinary callback')
    return row


def receipt(data, head, mode):
    require(type(head) is str and re.fullmatch('[0-9a-f]{40}', head), 'head')
    require(type(data) is dict and data.get('head') == head and data.get('error') is None and
            data.get('byond_version') == 516 and data.get('byond_build') == 1688 and data.get('port') == 0 and
            data.get('scope') == SCOPE and data.get('pair_mode') == mode, 'receipt identity')
    rows = data.get('pair_rows')
    require(type(rows) is list and [x.get('case') for x in rows if type(x) is dict] == list(CASES) and
            len(rows) == len(CASES) and type(data.get('pair_checks')) is int and data['pair_checks'] > 0 and
            data.get('pair_case') == CASES[-1] and flag(data.get('pair_overflow'), False) and
            data.get('pair_partial') == rows[-1].get('events'), 'receipt completeness')
    return [row(item, mode) for item in rows]


def compare(legacy, pair_first):
    require(type(legacy) is list and type(pair_first) is list and
            len(legacy) == len(pair_first) == len(CASES), 'pair completeness')
    for index, case in enumerate(CASES):
        require(legacy[index]['case'] == pair_first[index]['case'] == case and
                legacy[index]['mode'] == 'legacy' and pair_first[index]['mode'] == 'pair_first',
                'pair case identity')
    return {'observations_complete': True, 'safety_or_gameplay_parity_established': False}
