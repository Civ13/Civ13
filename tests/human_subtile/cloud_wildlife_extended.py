"""Offline staging/receipt contracts for a future separately reviewed native lane.

No main entry point, processes, networking, or runtime admission. The future
lane must reuse the reviewed bounded worker and exact-Git staging mechanisms.
"""
import hashlib
import json
import math
from pathlib import Path

SCOPE = 'large border and native geometry observations with manually scheduled wildlife; no large-body movement acceptance'
GEOMETRY_SCOPE = 'standalone native geometry observations only; no Civ13 or wildlife acceptance'


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


def adapt_extended(out, manifest, current):
    """Adapt npc.prepare output. Existing vendor/nine-check suites are not run."""
    stage = Path(out) / 'stage'
    relative = 'tests/human_subtile/probe.dm'
    for name in ('large_border_observe.dm', 'large_native_observe.dm', 'wildlife_runtime_observe.dm'):
        require((stage / 'tests/human_subtile' / name).is_file(), 'Missing exact-source fixture: ' + name)
    current.adapt(out, manifest, relative, '\t\t\tnpc_subtile_fixture()',
        '\t\t\tif (world.params["wildlife_extended"])\n\t\t\t\tlarge_border_fixture()\n\t\t\t\tlarge_native_fixture()\n\t\t\t\twildlife_runtime_fixture()\n\t\t\telse\n\t\t\t\tnpc_subtile_fixture()')
    current.adapt(out, manifest, relative, '"npc_checks" = npc_subtile_checks,',
        '"large_border_checks" = large_border_checks, "large_border_rows" = large_border_rows, '
        '"large_native_checks" = large_native_checks, "large_native_rows" = large_native_rows, '
        '"wildlife_runtime_checks" = wildlife_runtime_checks, "wildlife_runtime_rows" = wildlife_runtime_rows, '
        '"npc_checks" = npc_subtile_checks,')
    current.adapt(out, manifest, relative, '"scope" = "actual human/codec; headless authority adapter"',
        '"scope" = "' + SCOPE + '"')
    dme = Path(out) / manifest['dme']
    with dme.open('a', encoding='utf-8', newline='\n') as stream:
        stream.write('\n#include "tests\\human_subtile\\large_border_observe.dm"\n'
                     '#include "tests\\human_subtile\\large_native_observe.dm"\n'
                     '#include "tests\\human_subtile\\wildlife_runtime_observe.dm"\n')
    for rel in (relative, 'human_subtile.dme'):
        path = stage / rel
        data = path.read_bytes()
        manifest['stage_files'][rel] = {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
    manifest['extended_scope'] = SCOPE
    (Path(out) / 'extended-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')


def common(row, head, scope):
    require(isinstance(row, dict) and row.get('head') == head and row.get('error') is None and
            row.get('port') == 0 and (row.get('byond_version'), row.get('byond_build')) == (516, 1688) and
            row.get('scope') == scope, 'Wrong source, engine, port, scope or failed fixture')


def validate_extended(row, head):
    common(row, head, SCOPE)
    require(row.get('npc_checks') == 0 and row.get('large_border_checks') == 20 and
            row.get('wildlife_runtime_checks') == 58, 'Missing, mixed or incomplete extended checks')
    borders = row.get('large_border_rows')
    require(isinstance(borders, list) and len(borders) == 4, 'Missing border observations')
    keys = set()
    for item in borders:
        require(isinstance(item, dict) and item.get('classification') == 'expected_gap_characterization' and item.get('variant') in (0, 64) and
                item.get('baseline') and item.get('remote_result') and item.get('remote_calls') == 0 and
                not item.get('anchor_result') and item.get('anchor_calls') == 1 and
                isinstance(item.get('occupied'), list) and len(item['occupied']) > 1, 'Invalid border control')
        name = item.get('animal') or ''
        kind = 'mammoth' if '/mammoth/' in name else 'trex' if '/trex/' in name else ''
        require(bool(kind), 'Unknown large animal')
        keys.add((kind, item['variant']))
    require(keys == {(kind, variant) for kind in ('mammoth','trex') for variant in (0,64)}, 'Duplicate/missing border case')
    validate_native_observations(row)
    observations = row.get('wildlife_runtime_rows')
    require(isinstance(observations, list) and len(observations) == 6, 'Missing wildlife observations')
    cases = {item.get('case'): item for item in observations if isinstance(item, dict)}
    require(set(cases) == {'mosquito_life','bat_life','valid_recovery','invalidated_recovery',
                           'pursuit_ai_ticks','attack_handoff'}, 'Duplicate/missing wildlife case')
    for label in ('mosquito_life','bat_life'):
        item = cases[label]
        require(item.get('life_calls') == 14 and item.get('contact_ticks') == 14 and
                isinstance(item.get('settled_windows'), (int, float)) and item['settled_windows'] >= 2,
                'Insufficient sustained contact opportunity: ' + label)
    for label, dispatches in (('valid_recovery',1),('invalidated_recovery',0)):
        item = cases[label]
        require(item.get('flee_dispatches') == dispatches and 0 <= item.get('max_dx', 999) <= 2 and
                0 <= item.get('max_dy', 999) <= 2, 'Invalid recovery observation: ' + label)
    invalidated = cases['invalidated_recovery']
    position = invalidated.get('position')
    require(invalidated.get('terminal_observed') == 1 and invalidated.get('pending') == 0 and
            invalidated.get('recovering') == 0 and isinstance(position, dict) and
            position.get('sx') == 0 and position.get('sy') == 0,
            'Invalidated recovery did not settle before deadline')
    require(cases['pursuit_ai_ticks'].get('side_requests') == 1 and
            cases['pursuit_ai_ticks'].get('stuck_ticks') == 0 and cases['pursuit_ai_ticks'].get('owner_stable') and
            cases['attack_handoff'].get('attacks') == 1, 'Invalid pursuit or attack handoff')


def validate_native_observations(row):
    records = row.get('large_native_rows')
    require(type(row.get('large_native_checks')) is int and row['large_native_checks'] > 0 and
            isinstance(records, list) and len(records) == 80, 'Incomplete native large-body observations')
    groups = {}
    for item in records:
        require(isinstance(item, dict) and item.get('case') in ('clear','remote','anchor','clear_enter','anchor_enter') and
                item.get('variant') in (0,64) and item.get('direction') in (4,8) and
                item.get('orthogonal') in (0,1), 'Invalid native observation identity')
        name = item.get('animal') or ''
        kind = 'mammoth' if '/mammoth/' in name else 'trex' if '/trex/' in name else ''
        require(bool(kind), 'Unknown native large-body type')
        key = (kind,item['variant'],item['direction'],item['orthogonal'])
        cases = groups.setdefault(key,{})
        require(item['case'] not in cases, 'Duplicate native control')
        cases[item['case']] = item
        before, after, later, auth, trace = (item.get(k) for k in ('before','after','after_async','auth','trace'))
        require(all(isinstance(x, dict) for x in (before,after,later,auth)) and isinstance(trace,list) and
                len(trace) <= 256 and auth.get('consumed') == 1 and not auth.get('restoring') and
                auth.get('direction') == item['direction'] and before.get('bound_x') == item['variant'] and
                before.get('bound_width') == 96 and before.get('bound_height') == 96 and
                auth.get('bound_x') == before['bound_x'] and auth.get('bound_y') == before.get('bound_y') and
                auth.get('width') == 96 and auth.get('height') == 96 and isinstance(auth.get('before'),dict) and
                all(auth['before'].get(k) == before.get(k) for k in ('x','y','z','sx','sy')),
                'Invalid native pulse authentication or snapshot')
        require(all(type(before.get(k)) in (int,float) and math.isfinite(before[k]) and
                    type(after.get(k)) in (int,float) and math.isfinite(after[k]) for k in ('x','y','z','sx','sy')) and
                before['z'] == after['z'] and isinstance(before.get('locs'),list) and isinstance(after.get('locs'),list) and
                isinstance(later.get('locs'),list) and all(type(later.get(k)) in (int,float) and math.isfinite(later[k])
                    for k in ('x','y','z','sx','sy')),
                'Invalid native position or occupancy')
        dx=(after['x']-before['x'])*32+after['sx']-before['sx']
        dy=(after['y']-before['y'])*32+after['sy']-before['sy']
        expected=2 if item['direction']==4 else -2
        require(all(type(auth.get(k)) in (int,float) and math.isfinite(auth[k]) for k in ('destination_x','destination_y','sx','sy')) and
                (auth['destination_x']-before['x'])*32+auth['sx']-before['sx'] == expected and
                (auth['destination_y']-before['y'])*32+auth['sy']-before['sy'] == 0, 'Invalid requested pulse')
        require(dy == 0 and 0 <= dx * (1 if expected > 0 else -1) <= 2 and (item['case'] not in ('clear','clear_enter') or dx == expected),
                'Unexpected native displacement')
        events=[event.get('event') for event in trace if isinstance(event,dict)]
        require('Move:before' in events and 'Move:after' in events and
                events.index('Move:before') < events.index('Move:after'), 'Missing ordered Move trace')
    require(len(groups) == 16 and all(set(cases)=={'clear','remote','anchor','clear_enter','anchor_enter'} for cases in groups.values()),
            'Missing native experiment combinations')
    for cases in groups.values():
        clear, remote, anchor = cases['clear'], cases['remote'], cases['anchor']
        edge=(clear.get('edge_x'),clear.get('edge_y'))
        before={(cell.get('x'),cell.get('y')) for cell in clear['before']['locs'] if isinstance(cell,dict)}
        after={(cell.get('x'),cell.get('y')) for cell in clear['after']['locs'] if isinstance(cell,dict)}
        require(edge in before and edge not in after and edge != (clear['before']['x'],clear['before']['y']),
                'Remote blocker was not selected from the measured exiting edge')
        for control in (remote,anchor):
            require((control.get('edge_x'),control.get('edge_y')) == edge and
                    all(control['before'].get(k) == clear['before'].get(k) for k in
                        ('x','y','z','sx','sy','dir','bound_x','bound_y','bound_width','bound_height')),
                    'Native control setup drift')
            require({(c.get('x'),c.get('y')) for c in control['before']['locs'] if isinstance(c,dict)} == before,
                    'Native control occupancy drift')
        clear_enter, anchor_enter = cases['clear_enter'], cases['anchor_enter']
        entering_before={(c.get('x'),c.get('y')) for c in clear_enter['before']['locs'] if isinstance(c,dict)}
        entering_after={(c.get('x'),c.get('y')) for c in clear_enter['after']['locs'] if isinstance(c,dict)}
        require(entering_after - entering_before and
                any(isinstance(e,dict) and e.get('event') == 'Enter' for e in clear_enter['trace']),
                'Clear entering phase did not observe a native entered edge')
        require(all(anchor_enter['before'].get(k) == clear_enter['before'].get(k) for k in
                    ('x','y','z','sx','sy','dir','bound_x','bound_y','bound_width','bound_height')) and
                {(c.get('x'),c.get('y')) for c in anchor_enter['before']['locs'] if isinstance(c,dict)} == entering_before,
                'Entering positive control setup drift')
        require(any(isinstance(event,dict) and event.get('event') == 'CheckExit' for event in anchor_enter['trace']),
                'Entering anchor positive control did not exercise CheckExit')


def validate_geometry(row, head):
    common(row, head, GEOMETRY_SCOPE)
    rows = row.get('observations')
    require(isinstance(rows, list) and len(rows) == 115 and rows[0].get('case') == 'same_anchor_bound_change',
            'Missing geometry observations')
    def finite(value):
        return type(value) in (int,float) and math.isfinite(value)
    def snapshot(snap):
        require(isinstance(snap, dict) and all(finite(snap.get(k)) for k in
                ('x','y','z','sx','sy','bound_x','bound_y','bound_width','bound_height','pixel_x','pixel_y','dir')) and
                snap['bound_width'] == 96 and snap['bound_height'] == 96 and
                all(k in snap and (snap[k] is None or finite(snap[k])) for k in ('pixel_w','pixel_z')) and
                isinstance(snap.get('locs'), list) and
                0 < len(snap['locs']) <= 32, 'Incomplete geometry snapshot')
        cells = set()
        for cell in snap['locs']:
            require(isinstance(cell, dict) and cell.get('x') in range(1,15) and cell.get('y') in range(1,15) and
                    cell.get('z') == 1 and cell.get('in_contents') in (0,1), 'Invalid occupied turf')
            cells.add((cell['x'],cell['y'],cell['z']))
        require(len(cells) == len(snap['locs']), 'Duplicate occupied turf')
    for label in ('zero','sixtyfour'):
        snapshot(rows[0].get(label))
    zero, sixtyfour = rows[0]['zero'], rows[0]['sixtyfour']
    require(zero['bound_x'] == 0 and sixtyfour['bound_x'] == 64 and
            all(zero[k] == sixtyfour[k] for k in ('x','y','z','sx','sy')),
            'Bound experiment did not preserve the initial anchor')
    controls = set()
    for item in rows[1:3]:
        require(isinstance(item, dict) and item.get('case') == 'east_2px_clear' and
                item.get('variant') in (0,64) and item.get('direction') == 4 and
                finite(item.get('native_return')) and finite(item.get('bumps')) and item['bumps'] >= 0,
                'Missing clear movement control')
        snapshot(item.get('before')); snapshot(item.get('after'))
        baseline = zero if item['variant'] == 0 else sixtyfour
        require(item['before']['bound_x'] == item['variant'] and
                all(item['before'][k] == baseline[k] for k in ('x','y','z','sx','sy')),
                'Clear control did not start from the measured setup')
        controls.add(item['variant'])
    require(controls == {0,64}, 'Duplicate/missing clear control')
    keys = set()
    for item in rows[3:]:
        require(isinstance(item, dict) and item.get('case') == 'east_2px_blocker' and
                item.get('variant') in (0,64) and item.get('blocker_x') in range(4,12) and
                item.get('blocker_y') in range(5,12) and isinstance(item.get('before'), dict) and
                isinstance(item.get('after'), dict) and isinstance(item['before'].get('locs'), list) and
                isinstance(item['after'].get('locs'), list) and item.get('direction') == 4 and finite(item.get('native_return')),
                'Invalid collision observation')
        require(item.get('already_occupied') in (0,1) and finite(item.get('before_distance')) and
                finite(item.get('after_distance')) and finite(item.get('bumps')) and item['bumps'] >= 0,
                'Missing collision diagnostics')
        snapshot(item['before']); snapshot(item['after'])
        baseline = zero if item['variant'] == 0 else sixtyfour
        require(item['before']['bound_x'] == item['variant'] and
                all(item['before'][k] == baseline[k] for k in ('x','y','z','sx','sy')),
                'Collision case did not start from the measured setup')
        keys.add((item['variant'],item['blocker_x'],item['blocker_y']))
    require(len(keys) == 112, 'Duplicate/missing fixed-cell collision case')
