"""Independent replay admission. Reads native observations; never moves a train."""
import hashlib
import json
from pathlib import Path
from prepare import PIN, production_bytes, record

ROUTES = ('bypass', 'passenger', 'depot')
CONTROLS = ('lever_radius', 'detached_rotator', 'missing_siding_guard',
            'missing_depot_guard', 'end_of_track', 'blocked_switch_target',
            'wrong_facing_switch', 'fuel_stall')


def require(ok, why):
    if not ok:
        raise ValueError(why)


def expected_route(name):
    # Separate geometric oracle; no calls to the fixture generator or DM logic.
    path = [(x, 0) for x in range(0, 45)]
    if name == 'passenger':
        path = [(x, 0) for x in range(5)] + [(x, 1) for x in range(4, 17)] + [(x, 0) for x in range(16, 45)]
    elif name == 'depot':
        path = ([(x, 0) for x in range(23)] + [(x, -1) for x in range(22, 25)]
                + [(24, y) for y in range(-2, -9, -1)] + [(x, -8) for x in range(25, 35)]
                + [(34, y) for y in range(-7, 0)] + [(x, -1) for x in range(35, 37)]
                + [(x, 0) for x in range(36, 45)])
    return path


def source_check(root):
    root = Path(root)
    manifest = json.loads((root / 'source-manifest.json').read_text())
    require(manifest['source_commit'] == PIN, 'source pin')
    for path, r in manifest['original'].items():
        raw = (root / 'original' / path).read_bytes()
        require(record(raw) == {k: r[k] for k in ('bytes', 'sha256')}, 'original source hash: ' + path)
        blob = hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest()
        require(blob == r['git_blob'], 'Git blob: ' + path)
    require((root / 'stage/production.dm').read_bytes() == production_bytes(
        (root / 'original/code/modules/1713/trains.dm').read_bytes()), 'production extraction drift')
    for path, r in manifest['generated'].items():
        require(record((root / 'stage' / path).read_bytes()) == r, 'stage hash: ' + path)
    return manifest


def parse(log):
    require(len(log) <= 2 * 1024**2, 'native log size')
    low = log.lower()
    require(not any(t in low for t in ('runtime error:', 'bad ref', 'trace_cap_failure', 'infinite loop', 'maximum recursion')), 'native runtime diagnostic')
    rows = [json.loads(line.split('TRAIN_TRACE ', 1)[1]) for line in log.splitlines() if 'TRAIN_TRACE ' in line]
    require(0 < len(rows) <= 1024, 'native event count')
    return rows


def xy(car):
    return car['x'], car['y']


def validate(rows):
    require([r['seq'] for r in rows] == list(range(1, len(rows)+1)), 'sequence gap/duplicate')
    require(all(r['source'] == PIN and type(r['tick']) is int for r in rows), 'event source/time')
    require(all(a['tick'] <= b['tick'] for a, b in zip(rows, rows[1:])), 'time regression')
    require(rows[-1]['event'] == 'complete' and rows[-1]['failures'] == 0 and rows[-1]['port'] == 0, 'terminal result')
    require(all(r['ok'] == 1 for r in rows if r['event'] == 'check'), 'native assertion failure')
    require(any(r['event']=='check' and r['case']=='startup' and r['label']=='native port closed' and r['ok']==1 for r in rows),'missing native port assertion')
    groups = {}
    order = []
    for row in rows:
        if row['event'] == 'begin':
            require(row['case'] not in groups, 'duplicate case')
            groups[row['case']] = []
            order.append(row['case'])
        if row['case'] in groups:
            groups[row['case']].append(row)
    require(tuple(order) == ROUTES + CONTROLS, 'missing/extra/reordered scenario')
    for name, events in groups.items():
        require(len([r for r in events if r['event'] == 'layout']) == 1, 'layout count: '+name)
        require(len([r for r in events if r['event'] == 'end' and r['failures'] == 0]) == 1, 'case completion: '+name)
        require(any(r['event']=='check' for r in events),'missing native case assertions: '+name)
    for name in ROUTES:
        events = groups[name]
        frames = [r for r in events if r['event'] == 'frame']
        initial = next(r for r in frames if r['kind'] == 'initial')
        pulses = [r for r in frames if r['kind'] == 'pulse' and r['moved'] == 1]
        require([xy(initial['cars'][0])] + [xy(r['cars'][0]) for r in pulses] == expected_route(name), 'actual route differs: '+name)
        previous = initial['cars']
        require([xy(c) for c in previous] == [(-i, 0) for i in range(8)], 'initial consist')
        require({r['label'] for r in events if r['event']=='check' and r['label'].startswith('native hitch ')} == {'native hitch '+str(i) for i in range(2,9)},'native hitch evidence')
        for pulse in pulses:
            cars = pulse['cars']
            require(len(cars) == 8 and [c['id'] for c in cars] == list(range(1, 9)), 'lost vehicle')
            require(all(c['next'] == (c['id']+1 if c['id'] < 8 else 0) for c in cars), 'coupling changed')
            require(all(c['health'] == 1000 for c in cars), 'route collision')
            require([xy(c) for c in cars[1:]] == [xy(c) for c in previous[:-1]], 'follower did not occupy predecessor old tile')
            old,new=xy(previous[0]),xy(cars[0])
            lateral={((4,0),(4,1)),((16,1),(16,0)),((22,0),(22,-1)),((36,-1),(36,0))}
            heading=4 if (old,new) in lateral else 4 if new[0]>old[0] else 1 if new[1]>old[1] else 2
            require(all(c['dir']==heading for c in cars),'native train heading')
            previous = cars
        before_clear = next(r for r in pulses if xy(r['cars'][0]) == (43, 0))
        after_clear = next(r for r in pulses if xy(r['cars'][0]) == (44, 0))
        require(xy(before_clear['cars'][-1]) == (36, 0) and xy(after_clear['cars'][-1]) == (37, 0), 'whole consist clearance')
        stopped = [r for r in frames if r['kind'] == 'stopped']
        require(stopped and all(r['auto'] == 0 and r['on'] == 0 for r in stopped), 'powered stop state')
        targets = [(r['x'], r['y']) for r in events if r['event'] == 'target_stop']
        require(all(r['on']==0 and r['auto']==0 and r['method']=='locomotive.attack_hand' for r in events if r['event']=='target_stop'),'native operator stop path')
        want = [(44, 0)]
        if name == 'passenger': want.insert(0, (13, 1))
        if name == 'depot': want.insert(0, (32, -8))
        require(targets == want, 'target stop sequence')
        if name != 'bypass':
            service = next(r for r in frames if r['kind'] == 'service_dwell')
            require(xy(service['cars'][0]) == want[0] and service['auto'] == 0, 'service stop')
            require([xy(c) for c in service['cars']] == ([(x,1) for x in range(13,5,-1)] if name=='passenger'
                    else [(x,-8) for x in range(32,24,-1)]),'eight vehicle service berth alignment')
        turns = [r for r in next(r for r in events if r['event'] == 'layout')['rails'] if r['type'] == '/obj/structure/rails/turn']
        require(sorted((r['x'], r['y'], r['dir'], r['turn']) for r in turns) == sorted(
            [(24,-1,1,8),(24,-8,2,4),(34,-8,4,1),(34,-1,8,2)]), 'crafted left-turn orientations')
    # Independently check control outcomes, beyond accepting their PASS labels.
    def frames(name): return [r for r in groups[name] if r['event'] == 'frame']
    radius = frames('lever_radius')
    require(len(radius) == 2, 'lever control frame count')
    require(radius[0]['tick']<radius[1]['tick'],'native lever control observations must advance time')
    state = lambda r, x, y: next(s['state'] for s in r['switches'] if (s['x'],s['y']) == (x,y))
    require(state(radius[0],4,0) == state(radius[0],6,4) == 'split' and state(radius[0],7,2) == 'forward', 'lever native radius')
    require(all(s['state'] == 'forward' for s in radius[1]['switches']), 'lever native reset')
    rot = frames('detached_rotator')
    require([r['kind'] for r in rot] == ['initial','rotate_right','rotate_left','rotate_hand'], 'rotator invocation sequence')
    require(all(a['tick']<b['tick'] for a,b in zip(rot,rot[1:])),'native rotator control observations must advance time')
    require([r['cars'][0]['dir'] for r in rot] == [2,4,2,4] and all(r['cars'][1]['dir'] == 4 for r in rot), 'rotator native directions')
    require(all(xy(r['cars'][0]) == (24,-4) and xy(r['cars'][1]) == (25,-4) and all(c['next'] == 0 for c in r['cars']) for r in rot), 'rotator moved/connected vehicle')
    for name, pos in [('missing_siding_guard',(16,1)),('missing_depot_guard',(36,-1)),('end_of_track',(47,0)),('blocked_switch_target',(4,0)),('fuel_stall',(0,0))]:
        rows_ = frames(name)
        final = rows_[-1]
        pulse = next(r for r in rows_ if r['kind'] == 'pulse')
        require(xy(final['cars'][0]) == pos and final['auto'] == 0 and pulse['moved'] == 0, 'boundary motion: '+name)
        require(final['cars'][0]['health'] == (995 if name == 'blocked_switch_target' else 1000), 'boundary health: '+name)
    wrong = frames('wrong_facing_switch')[-1]
    require(xy(wrong['cars'][0]) == (5,0) and wrong['cars'][0]['dir'] == 4, 'wrong facing switch')
    return {'accepted': True, 'source_commit': PIN, 'events': len(rows), 'routes': list(ROUTES), 'controls': list(CONTROLS),
            'scope': 'Native extracted procedures, not full game/client/crafting UI acceptance'}


if __name__ == '__main__':
    import argparse
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--prepared', required=True, type=Path)
    p.add_argument('--log', required=True, type=Path)
    p.add_argument('--output', required=True, type=Path)
    a = p.parse_args()
    source_check(a.prepared)
    raw = a.log.read_bytes()
    result = validate(parse(raw.decode('utf8', errors='replace')))
    result['native_log'] = record(raw)
    a.output.write_text(json.dumps(result, indent=2)+'\n', encoding='utf8')
    print(json.dumps(result, indent=2))
