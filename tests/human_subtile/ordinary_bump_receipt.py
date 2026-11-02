"""Strict host oracle for paired current-source ordinary bump fixtures.

This validates receipts only; it does not launch native software or prove client visuals.
"""
import math
import re

GAME_HEAD = '5b0040a099cdacf1091bc8b4859c298f65dda63d'
SCOPE = 'ordinary human-goat help bump; current-source headless fixture'
CASES = ('human_idle', 'goat_idle_default', 'goat_idle_permitted', 'goat_active_permitted')
LABELS = {'initial','human_bump_before','human_bump_return','goat_bump_before','goat_bump_return',
          'active_before_goat','human_call_return','after_attempt','post_deferred','terminal',
          'first_leg_before','first_leg_after','second_leg_before','second_leg_after','veto'}
LEGS = ('first_leg_before','first_leg_after','second_leg_before','second_leg_after')


def require(ok, message):
    if not ok:
        raise ValueError(message)


def number(v):
    return type(v) in (int, float) and math.isfinite(v)


def normalized(values):
    require(all(type(x) is int for x in values) and 1 <= values[0] <= 18 and 1 <= values[1] <= 14 and
            0 <= values[2] < 32 and 0 <= values[3] < 32, 'invalid tile or nonnormalized offset')
    return (values[0] * 32 + values[2], values[1] * 32 + values[3])


def point(event, actor):
    keys = ('hx','hy','hsx','hsy') if actor == 'human' else ('ax','ay','asx','asy')
    return normalized([event.get(k) for k in keys])


def validate(receipt, mode, expected_head):
    require(mode in ('legacy','candidate') and type(expected_head) is str and re.fullmatch('[0-9a-f]{40}', expected_head), 'mode or source head')
    require(isinstance(receipt, dict) and receipt.get('head') == expected_head and receipt.get('scope') == SCOPE and
            receipt.get('ordinary_bump_mode') == mode and receipt.get('byond_version') == 516 and
            receipt.get('byond_build') == 1688 and receipt.get('port') == 0 and receipt.get('error') is None and
            type(receipt.get('checks')) is int and receipt['checks'] > 0 and not receipt.get('ordinary_bump_overflow'), 'receipt identity')
    rows = receipt.get('ordinary_bump_rows')
    require(isinstance(rows, list) and [r.get('case') for r in rows] == list(CASES), 'case coverage')
    for row in rows:
        name = row['case']; events = row.get('events'); pulses = row.get('human_pulses')
        require(not row.get('overflow') and type(row.get('callbacks')) is int and 1 <= row['callbacks'] <= 128 and
                isinstance(events, list) and 1 <= len(events) <= 128 and isinstance(pulses, list), 'case bounds')
        prior = -1.0
        for i, event in enumerate(events, 1):
            require(isinstance(event,dict) and event.get('case') == name and event.get('ordinal') == i and
                    event.get('label') in LABELS and number(event.get('at')) and event['at'] >= prior, 'event ordering')
            prior = event['at']; point(event,'human'); point(event,'goat')
        labels = [e['label'] for e in events]
        require(labels[0] == 'initial' and labels[-1] == 'terminal' and labels.count('terminal') == 1 and
                labels.count('post_deferred') == 1, 'missing checkpoints')
        expected_actor = 'human_bump_before' if name == 'human_idle' else 'goat_bump_before'
        require(labels.count(expected_actor) == row['callbacks'], 'callback identity/count')
        expected_pair = ('human','goat') if name == 'human_idle' else ('goat','human')
        require(all((e.get('actor'),e.get('other')) == expected_pair for e in events if e['label'] == expected_actor), 'callback actor mismatch')
        initial, terminal = events[0],events[-1]
        require(point(initial,'human') == (320,320) and point(initial,'goat') == (352,320), 'initial positions')
        require(not terminal.get('human_transaction') and not terminal.get('human_pulse') and
                not terminal.get('human_pushing') and not terminal.get('goat_pushing'), 'owner not retired')
        if name != 'goat_active_permitted' or mode == 'candidate':
            require(terminal.get('hsx') == 0 and terminal.get('hsy') == 0, 'terminal human offset not centered')
        legs = [x for x in labels if x in LEGS]; veto = labels.count('veto')
        if mode == 'candidate' and name != 'goat_idle_default':
            require(not legs and veto >= 1, 'candidate did not veto before both legs')
        if name in ('human_idle','goat_idle_permitted'):
            if mode == 'legacy':
                require(legs == list(LEGS) and veto == 0 and point(terminal,'human') == (352,320) and
                        point(terminal,'goat') == (320,320), 'legacy swap not witnessed')
            else:
                require(point(terminal,'human') == (320,320) and point(terminal,'goat') == (352,320), 'candidate idle positions')
        if name == 'goat_idle_default':
            require(not legs and not veto, 'default reverse should not acquire swap')
        if name == 'goat_active_permitted' and mode == 'candidate':
            active = [e for e in events if e['label'] == 'active_before_goat']
            collision = [e for e in events if e['label'] == 'goat_bump_before']
            post = [e for e in events if e['label'] == 'post_deferred']
            require(len(active) == 1 and active[0].get('human_owned') and active[0].get('human_transaction') and
                    active[0].get('same_admission') and point(active[0],'human')[1] > 320 and collision and
                    any(e.get('same_admission') and e.get('human_owned') for e in collision) and
                    post[0].get('same_admission') and post[0].get('human_owned'), 'partial ownership not continuous')
            require(point(post[0],'goat') == (352,320) and point(terminal,'goat') == (352,320), 'goat moved')
            require(point(terminal,'human') == (320,352) and terminal.get('human_completions') == 1 and
                    terminal.get('living_completions') == 1, 'human completion or final offset')
            require(len(pulses) == 16, 'incomplete pulse trace')
            for i, pulse in enumerate(pulses,1):
                require(type(pulse) is dict, 'invalid pulse')
                require(normalized([pulse.get(k) for k in ('x','y','sx','sy')]) == (320,320 + 2*i),
                        'unlawful displacement or skipped pulse')
    return rows


def compare(legacy, candidate, expected_head):
    before, after = validate(legacy,'legacy',expected_head), validate(candidate,'candidate',expected_head)
    b = before[1]['events'][-1]; a = after[1]['events'][-1]
    require(point(b,'human') == point(a,'human') and point(b,'goat') == point(a,'goat'), 'default reverse behavior changed')
    return {'ordinary_cases_observed': 4, 'visual_or_broad_parity_established': False}