#!/usr/bin/env python3
"""A pretend hosting setup for drawing the launcher's hosting tabs (Civ13.exe --render-tabs).

    python host_fixture.py make <new-folder> [--single]

writes a launcher data folder with a host.json whose control scripts, region group and
bot are copies of this file. Run as one of those copies it only prints a canned status
or check-update line, so the launcher can be drawn in every state (running, asleep,
stopped, working, out of date, failed) without a game server, a compiler or a network.
Nothing here starts, stops or changes anything: every other action is refused.
"""
import json
import shutil
import sys
from pathlib import Path

OLD = '4f1c2d7' + '0' * 33
NEW = '9be03aa' + '1' * 33

REGIONS = [
    ('gaia', 'Gaia', 1714, 1814, {
        'state': 'awake', 'listening': True, 'busy': False, 'world': {'ready': 1, 'clients': 7},
        'operation': {'action': 'start', 'phase': 'done', 'error': None},
        'stage': {'phase': 'ready', 'pending': True}, 'transfer_agent': True,
        'region_view': {'epoch': {'ordinal': 3}}}, 3),
    ('railyard', 'Rail Yard', 1715, 1815, {
        'state': 'asleep', 'listening': True, 'busy': False,
        'operation': {'action': 'update', 'phase': 'compiled', 'error': None},
        'stage': {'phase': 'current'}, 'transfer_agent': True}, 0),
    ('barren', 'Mars', 1716, 1816, {
        'state': 'awake', 'listening': True, 'busy': False, 'world': {'ready': 1, 'clients': 2},
        'operation': {'action': 'start', 'phase': 'done', 'error': None},
        'watchdog': {'restarts': [1], 'last_event': 'hang'}, 'transfer_agent': True,
        'region_view': {'epoch': {'ordinal': 3}}}, 3),
    ('moon', 'Moon', 1717, 1817, {
        'state': 'stopped', 'listening': False, 'busy': False,
        'operation': {'action': 'stop', 'phase': 'done', 'error': None}, 'transfer_agent': False}, 3),
    ('opensea', 'Open Sea', 1718, 1818, {
        'state': 'awake', 'listening': True, 'busy': True, 'world': {'ready': 1, 'clients': 1},
        'operation': {'action': 'handover', 'phase': 'loading the standby', 'error': None},
        'stage': {'phase': 'ready', 'pending': True}, 'standby': {'port': 1728, 'listening': True},
        'transfer_agent': True}, 3),
    ('barracks', 'Barracks', 1719, 1819, {
        'state': 'stopped', 'listening': False, 'busy': False,
        'operation': {'action': 'update', 'phase': 'failed',
                      'error': 'compile failed: code/modules/tdm_barracks/vote.dm:212: error: undefined var'},
        'transfer_agent': False}, 3),
    ('orbit', 'Orbit', 1720, 1820, {
        'state': 'awake', 'listening': True, 'busy': False, 'world': {'ready': 1, 'clients': 0},
        'operation': {'action': 'start', 'phase': 'done', 'error': None},
        'stage': {'phase': 'failed', 'error': 'compile.lock is held by another build'},
        'transfer_agent': True, 'region_view': {'epoch': {'ordinal': 3}}}, 3),
    ('island', 'Island', 1721, 1821, {
        'state': 'cold', 'listening': False, 'busy': False,
        'operation': {'action': 'stop', 'phase': 'done', 'error': None}, 'stage': {'phase': 'current'},
        'transfer_agent': False}, 0),
]


def check(component, behind, running=False):
    reason = None if behind and not running else ('stop the server before updating' if behind else 'up to date')
    return {'component': component, 'current': OLD if behind else NEW, 'available': NEW, 'behind': behind,
            'can_update': reason is None, 'reason': reason}


def answer(role, action):
    if role == 'shard_group.py':
        if action == 'status':
            return {'group': 'earth', 'coordinator': True,
                    'regions': {rid: dict(entry, name=name, port=port) for rid, name, port, _, entry, _ in REGIONS}}
        if action == 'check-update':
            regions = {rid: dict(check('server', behind, entry['listening']), region=rid)
                       for rid, _, _, _, entry, behind in REGIONS}
            return dict(check('server', 3, True), regions=regions)
        if action == 'help-status':
            return {'configured': True, 'stopped': False, 'config': 'player-help.json', 'regions': {
                'gaia': {'running': True, 'pid': 4312, 'wanted': True, 'enabled': True, 'heartbeat_age_seconds': 1},
                'railyard': {'running': True, 'pid': 4980, 'wanted': True, 'enabled': True, 'heartbeat_age_seconds': 2},
                'barren': {'running': False, 'pid': None, 'wanted': False, 'enabled': False}}}
    elif role == 'gaia_host.py':
        if action == 'status':
            return dict(REGIONS[0][4], port=REGIONS[0][2], lifecycle_token=True)
        if action == 'check-update':
            return check('server', 3, True)
    elif role == 'control.php':
        if action == 'status':
            return {'running': True, 'stop_pending': False, 'reload_pending': False}
        if action == 'check-update':
            return dict(check('bot', 0), fresh=True, running=True)
    return None


def stub(argv):
    role = Path(argv[0]).name
    action = next((word for word in argv[1:] if word in ('status', 'check-update', 'help-status')), None)
    result = answer(role, action)
    if result is None:
        print(json.dumps({'ok': False, 'refused': 'this is a drawing fixture; nothing runs'}))
        return 1
    print(json.dumps(dict(result, ok=True)))
    return 0


def make(target, single):
    target = Path(target).resolve()
    if target.exists():
        raise SystemExit('refusing to write into an existing folder: %s' % target)
    repo, game, bot = target / 'checkout', target / 'game', target / 'bot'
    for folder in (repo / 'scripts' / 'gaia-host', repo / 'scripts' / 'shard-group', repo / 'scripts' / 'windows' / 'host',
                   game, bot / 'scripts' / 'windows', target / 'launcher'):
        folder.mkdir(parents=True)
    here = Path(__file__).resolve()
    for copy in (repo / 'scripts' / 'gaia-host' / 'gaia_host.py', repo / 'scripts' / 'shard-group' / 'shard_group.py',
                 bot / 'scripts' / 'windows' / 'control.php'):
        shutil.copyfile(here, copy)
    for name in ('deploy.bat', 'restart-host.bat'):
        (repo / 'scripts' / 'windows' / 'host' / name).write_text('@exit /b 1\r\n', encoding='ascii')
    (game / 'civ13.dmb').write_bytes(b'')
    (game / 'gaia-host.json').write_text('{}', encoding='utf-8')
    group = target / 'earth.json'
    group.write_text(json.dumps({'group': 'earth', 'mainland': 'gaia', 'root': str(target / 'regions'), 'regions': [
        {'id': rid, 'name': name, 'port': port, 'transfer_port': travel} for rid, name, port, travel, _, _ in REGIONS]},
        indent=2), encoding='utf-8')
    profile = bot / 'profile.json'
    profile.write_text(json.dumps({'http_port': 55555}), encoding='utf-8')
    control = {'python': sys.executable, 'script': str(repo / 'scripts' / 'gaia-host' / 'gaia_host.py'),
               'config': str(game / 'gaia-host.json')}
    if not single:
        control['group'] = str(group)
    host = {'schema': 1, 'game_directory': str(game), 'world': 'civ13.dmb', 'port': REGIONS[0][2], 'control': control,
            'bot': {'php': sys.executable, 'root': str(bot), 'profile': str(profile)}}
    (target / 'launcher' / 'host.json').write_text(json.dumps(host, indent=2), encoding='utf-8')
    print(target / 'launcher')


if __name__ == '__main__':
    if len(sys.argv) >= 3 and sys.argv[1] == 'make' and Path(sys.argv[0]).name == 'host_fixture.py':
        make(sys.argv[2], '--single' in sys.argv[3:])
    else:
        sys.exit(stub(sys.argv))
