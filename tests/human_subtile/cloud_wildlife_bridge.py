"""Staging and independent receipt checks for the disabled exit-bridge fixture."""
import hashlib
import json
import math
from pathlib import Path

SCOPE = 'disabled large-body cardinal exit bridge fixture; no facing, save or wildlife acceptance'

def require(value, message):
    if not value:
        raise RuntimeError(message)

def adapt_bridge(out, manifest, current):
    stage = Path(out) / 'stage'
    relative = 'tests/human_subtile/probe.dm'
    for name in ('large_native_observe.dm', 'large_bridge_fixture.dm'):
        require((stage / 'tests/human_subtile' / name).is_file(), 'Missing bridge fixture: ' + name)
    current.adapt(out, manifest, relative, '\t\t\tnpc_subtile_fixture()', '\t\t\tlarge_bridge_fixture()')
    current.adapt(out, manifest, relative, '"npc_checks" = npc_subtile_checks,',
                  '"large_bridge_checks" = large_bridge_checks, "large_bridge_rows" = large_bridge_rows, '
                  '"large_bridge_controls" = large_bridge_controls, "large_bridge_exception_sentinel" = large_bridge_exception_sentinel, '
                  '"npc_checks" = npc_subtile_checks,')
    current.adapt(out, manifest, relative, '"scope" = "actual human/codec; headless authority adapter"',
                  '"scope" = "' + SCOPE + '"')
    with (Path(out) / manifest['dme']).open('a', encoding='utf-8', newline='\n') as stream:
        stream.write('\n#include "tests\\human_subtile\\large_native_observe.dm"\n'
                     '#include "tests\\human_subtile\\large_bridge_fixture.dm"\n')
    for rel in (relative, 'human_subtile.dme'):
        data = (stage / rel).read_bytes()
        manifest['stage_files'][rel] = {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
    manifest['bridge_scope'] = SCOPE
    (Path(out) / 'bridge-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')

def finite(value):
    return type(value) in (int, float) and math.isfinite(value)

def point(value):
    require(isinstance(value, dict) and all(finite(value.get(k)) for k in ('x','y','z','sx','sy')), 'Invalid position')
    return tuple(value[k] for k in ('x','y','z','sx','sy'))

def events(record):
    trace = record.get('trace')
    require(isinstance(trace, list) and len(trace) <= 256 and all(isinstance(x, dict) for x in trace), 'Invalid trace')
    return [x.get('event') for x in trace]

def validate_bridge(row, head):
    require(isinstance(row, dict) and row.get('head') == head and row.get('error') is None and
            row.get('port') == 0 and (row.get('byond_version'), row.get('byond_build')) == (516, 1688) and
            row.get('scope') == SCOPE and row.get('npc_checks') == 0 and
            row.get('large_bridge_checks') == 4121, 'Invalid bridge receipt identity or count')
    sentinel=row.get('large_bridge_exception_sentinel')
    require(isinstance(sentinel,dict) and sentinel.get('caught') == 1 and sentinel.get('name') == 'fixture_bridge_exception',
            'Direct exception sentinel failed')
    rows = row.get('large_bridge_rows')
    require(isinstance(rows, list) and len(rows) == 64, 'Incomplete bridge matrix')
    identities = set()
    groups = {}
    for item in rows:
        require(isinstance(item, dict), 'Invalid bridge record')
        name = item.get('animal') or ''
        kind = 'mammoth' if '/mammoth/' in name else 'trex' if '/trex/' in name else ''
        direction, variant, orthogonal, allow = (item.get(k) for k in ('direction','variant','orthogonal','allow'))
        require(kind and direction in (1,2,4,8) and variant in (0,64) and orthogonal in (0,1) and allow in (0,1), 'Invalid bridge case')
        key = (kind, variant, direction, orthogonal, allow)
        require(key not in identities, 'Duplicate bridge case'); identities.add(key)
        groups.setdefault(key[:-1], {})[allow] = item
        before, after, later = (item.get(k) for k in ('before','after','after_async'))
        b, a, l = point(before), point(after), point(later)
        require(a == l and before.get('dir') == direction and before.get('bound_x') == variant and
                before.get('bound_y') == 0 and before.get('bound_width') == 96 and before.get('bound_height') == 96,
                'Geometry or asynchronous displacement mismatch')
        dx = (a[0]-b[0])*32+a[3]-b[3]; dy = (a[1]-b[1])*32+a[4]-b[4]
        expected = {1:(0,2),2:(0,-2),4:(2,0),8:(-2,0)}[direction] if allow else (0,0)
        require((dx,dy) == expected and a[2] == b[2] and item.get('frame_cleared') == 1 and type(item.get('checks')) is int and item['checks'] > 0 and
                item.get('exit_direction') == direction, 'Wrong bridge outcome or direction')
        auth = item.get('auth'); require(isinstance(auth,dict) and auth.get('consumed') == 1 and not auth.get('restoring') and
                auth.get('direction') == direction and point(auth.get('before')) == b and auth.get('bound_x') == variant and
                auth.get('bound_y') == 0 and auth.get('width') == 96 and auth.get('height') == 96 and
                all(finite(auth.get(k)) for k in ('destination_x','destination_y','sx','sy')), 'Wrong pulse authentication')
        requested = {1:(0,2),2:(0,-2),4:(2,0),8:(-2,0)}[direction]
        require(((auth['destination_x']-b[0])*32+auth['sx']-b[3],
                 (auth['destination_y']-b[1])*32+auth['sy']-b[4]) == requested,
                'Requested movement does not match cardinal pulse')
        require((b[4] if direction in (4,8) else b[3]) == (2 if orthogonal else 0), 'Orthogonal setup mismatch')
        if direction == 8:
            require(b[3] == 2 and auth.get('destination_x') == b[0] and auth.get('sx') == 0,
                    'Missing same-anchor west control')
        trace = events(item)
        collision = [e for e in trace if e in ('Uncross','CheckExit:bridge')]
        require(collision == ['Uncross','CheckExit:bridge'] * item['checks'] and
                'Move:before' in trace and 'Move:after' in trace and
                trace.index('Move:before') < trace.index('Uncross') < trace.index('Move:after') and
                max(i for i, e in enumerate(trace) if e == 'CheckExit:bridge') < trace.index('Move:after'),
                'Missing ordered native collision callbacks')
        edge = (item.get('edge_x'),item.get('edge_y'))
        require(all(finite(v) for v in edge) and isinstance(before.get('locs'),list) and
                edge in {(c.get('x'),c.get('y')) for c in before['locs'] if isinstance(c,dict)} and edge != b[:2],
                'Blocker not on remote occupied edge')
    expected_keys={(kind,v,d,o,a) for kind in ('mammoth','trex') for v in (0,64) for d in (1,2,4,8) for o in (0,1) for a in (0,1)}
    require(identities == expected_keys, 'Bridge matrix missing cases')
    for cases in groups.values():
        allowed, denied = cases[1], cases[0]
        require(point(allowed['before']) == point(denied['before']) and
                {(c.get('x'),c.get('y'),c.get('z')) for c in allowed['before']['locs']} ==
                {(c.get('x'),c.get('y'),c.get('z')) for c in denied['before']['locs']} and
                (allowed['edge_x'],allowed['edge_y']) == (denied['edge_x'],denied['edge_y']), 'Control setup mismatch')
        edge=(allowed['edge_x'],allowed['edge_y'])
        require(isinstance(allowed['after'].get('locs'),list) and
                edge not in {(c.get('x'),c.get('y')) for c in allowed['after']['locs'] if isinstance(c,dict)},
                'Allowed move did not actually exit the measured remote edge')
    controls = row.get('large_bridge_controls')
    require(isinstance(controls,list) and len(controls) == 34 and all(isinstance(c,dict) for c in controls), 'Missing bridge controls')
    by_case={c.get('case'):c for c in controls}
    require(all(c.get('frame_cleared') == 1 for c in controls), 'Missing frame cleanup evidence')
    callbacks = {'callback_invalidate','callback_cancel','callback_finish','callback_delete','callback_blocker_delete','callback_incapacitate','callback_reassign','callback_control','callback_disable'}
    real={f'real_/obj/structure/{kind}/bridge_fixture_{direction}_{allow}' for kind in ('window','railing','table') for direction in (4,8) for allow in (0,1)}
    require(set(by_case) == {'missing','stale','wrong_actor','unarmed','wrong_destination','replay','ordinary_32','object_uncross_reject','parent_uncross_reject','callback_nested','callback_throw','callback_actor_delete','policy_mutation'} | callbacks | real, 'Duplicate or missing controls')
    for name in ('missing','stale','wrong_actor','unarmed','wrong_destination','replay'):
        case=by_case[name]
        require(case.get('result') == 0 and point(case.get('before')) == point(case.get('after')) and
                'CheckExit:bridge' not in events(case), 'Invalid capability rejection: '+name)
    ordinary=by_case['ordinary_32']; old=point(ordinary.get('before')); new=point(ordinary.get('after'))
    require(ordinary['before'].get('bound_width') == 32 and ordinary['before'].get('bound_height') == 32 and
            (new[0]-old[0])*32+new[3]-old[3] == 2 and new[1:3] == old[1:3], 'Ordinary 32 control failed')
    for name, count, event in [(name,1,'CheckExit:bridge') for name in callbacks] + [('object_uncross_reject',0,'Uncross:fixture_reject'),('parent_uncross_reject',0,'Uncross:parent_reject')]:
        case=by_case[name]
        require(point(case.get('before')) == point(case.get('after')) and case.get('checks') == count and event in events(case),
                'Callback rejection control failed: '+name)
    nested=by_case['callback_nested']; before=point(nested.get('before')); after=point(nested.get('after'))
    require(nested.get('nested_result') == 0 and nested.get('checks') == 1 and
            (after[0]-before[0])*32+after[3]-before[3] == -2 and 'CheckExit:bridge' in events(nested),
            'Nested pulse was not rejected or outer pulse did not complete')
    thrown=by_case['callback_throw']
    throw_auth=thrown.get('auth',{})
    require(thrown.get('caught') == 1 and thrown.get('caught_name') == 'fixture_bridge_exception' and
            thrown.get('throw_attempted') == 1 and thrown.get('helper_returned') == 0 and
            thrown.get('boundary_caught') == 1 and thrown.get('boundary_name') == 'fixture_bridge_exception' and
            thrown.get('checks') == 1 and throw_auth.get('consumed') == 1 and
            throw_auth.get('actor_pulse_present') == 1 and throw_auth.get('actor_transaction_present') == 1 and
            throw_auth.get('actor_frame_present') == 0 and point(thrown.get('before')) == point(thrown.get('after')) and
            'fixture_throw_attempt' in events(thrown) and 'Uncross:throw_catch' in events(thrown),
            'Exception cleanup control failed')
    deleted=by_case['callback_actor_delete']
    require(deleted.get('actor_deleted') == 1 and deleted.get('pulse_consumed') == 1 and deleted.get('checks') == 1 and
            deleted.get('error') is None and 'CheckExit:bridge' in events(deleted), 'Actor-deletion control failed')
    point(deleted.get('before'))
    policy=by_case['policy_mutation']; trace=events(policy)
    require(point(policy.get('before')) == point(policy.get('after')) and policy.get('subject_allow') == 0 and
            type(policy.get('mutator_checks')) is int and policy['mutator_checks'] > 0 and
            type(policy.get('subject_checks')) is int and policy['subject_checks'] > 0 and
            'policy_mutated' in trace and 'CheckExit:policy_subject' in trace and
            trace.index('policy_mutated') < trace.index('CheckExit:policy_subject'), 'Changed blocker policy was not checked')
    for name in real:
        case=by_case[name]; before=point(case.get('before')); after=point(case.get('after'))
        kind=next(kind for kind in ('window','railing','table') if '/'+kind+'/' in name)
        trace=events(case); count=case.get('checks')
        direction=case.get('direction')
        require(type(count) is int and count > 0 and direction in (4,8) and case.get('exit_direction') == direction and
                case.get('variant') == (64 if direction == 4 else 0) and case.get('allow') in (0,1) and
                (after[0]-before[0])*32+after[3]-before[3] == ((2 if direction == 4 else -2) if case['allow'] else 0) and
                [e for e in trace if e in ('Uncross:'+kind,'CheckExit:'+kind)] == ['Uncross:'+kind,'CheckExit:'+kind]*count,
                'Real border directional control failed: '+name)
