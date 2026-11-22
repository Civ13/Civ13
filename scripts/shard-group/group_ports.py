"""The ports of a region group and its front door (the gate), changed in one action.

    python shard_group.py --config group.json ports
    python shard_group.py --config group.json set-gate --region ID [--apply]
    python shard_group.py --config group.json set-port --region ID [--port N] [--transfer-port N] [--standby-port N] [--apply]

`ports` lists every port of the group (game, transfer agent, standby, relay, relay
control, doorman), who holds it, whether it must be forwarded on the router, and any
clash. It changes nothing.

`set-gate` makes another region the front door: the world on the public port that
players and the Discord Play button join, which the bot watches and whose admins file
the group shares. The new gate takes the public port and the old gate takes the new
gate's port, so the router forward, the Play button and the bot's address stay as they
are. `set-port` moves one region to other ports.

Both print the plan and change nothing until --apply. A plan lists every port that
moves, what happens to each world, and every problem that would stop it (a port clash,
a port another program holds, a world that cannot save now). --apply starts one
detached worker that, in order:

1. saves and stops the worlds whose port moves (players get the usual countdown; a
   world asleep saved before it slept and is only ended);
2. writes the group config (a copy of the old one is kept beside it), every region's
   generated config, the bot link settings and the shared admins file of the new gate,
   and the bot's profile;
3. waits for the host service to load the new ports;
4. starts the worlds it stopped, the new gate first;
5. tells the relay the ports and every other running world the new directory.

Progress is in <root>/port-change.json. A failure before step 2 starts the stopped
worlds again and changes nothing. After step 2 the same command converges: run it
again and it carries on from what is already done.
"""
import copy
import hashlib
import json
import os
from pathlib import Path
import secrets
import shutil
import sys
import time

from gaia_host import Refused, world_saves

JOURNAL = 'port-change.json'
SERVICE_RECORD = 'host-service.json'
# As check_group: nobody lives in these, so none can be the front door.
GATE_REFUSED_KINDS = ('RAID', 'EVENT', 'TUTORIAL', 'EXPEDITION')
PORT_KEYS = ('port', 'transfer_port', 'standby_port')
RUNNING_PHASES = ('accepted', 'stopping', 'writing', 'host service', 'starting', 'telling')
SERVICE_RELOAD_SECONDS = 180
POLL_SECONDS = 5
ACCEPT_SECONDS = 60


def journal_path(group):
    return Path(group['root']) / JOURNAL


def read_json(path):
    try:
        value = json.loads(Path(path).read_text(encoding='utf-8-sig'))
    except (OSError, ValueError):
        return None
    return value if isinstance(value, dict) else None


def write_json(path, value, indent=1):
    path = Path(path)
    temporary = path.with_name(path.name + '.tmp')
    temporary.write_text(json.dumps(value, indent=indent) + '\n', encoding='utf-8')
    for attempt in range(20):
        try:
            os.replace(temporary, path)
            return
        except PermissionError:
            # Windows: the launcher or `ports` is reading the file this instant.
            if attempt == 19:
                raise
            time.sleep(0.1)


def signature(path):
    """What the host service says it loaded: the group file's SHA-256."""
    try:
        return hashlib.sha256(Path(path).read_bytes()).hexdigest()
    except OSError:
        return None


def gate_of(group):
    """The region players join directly, or None for a group without the routing relay
    (there every region is joined on its own port)."""
    return group.get('gate') if group.get('relay_port') else None


def region_of(group, region_id):
    for region in group['regions']:
        if region['id'] == region_id:
            return region
    raise Refused('no region %s in the group' % region_id)


def doorman_port(sg, group):
    return group.get('doorman_port', sg.gaia_host.FREEZE_DEFAULTS['doorman_port'])


def machine_of(sg, group, platform=None):
    return platform or sg.hosts(group, None, None)[0][1].platform


def change_running(sg, group):
    """The journal of a port change whose worker still runs, or None."""
    journal = read_json(journal_path(group))
    if not journal or journal.get('phase') not in RUNNING_PHASES:
        return None
    if type(journal.get('pid')) is int:
        return journal if sg.process_alive(journal['pid']) else None
    # Accepted a moment ago: its worker has not written its pid yet.
    started = journal.get('started')
    return journal if type(started) is int and 0 <= time.time() - started < ACCEPT_SECONDS else None


def service_state(sg, group, machine):
    """'reloads': a host service that loads a changed group file by itself runs;
    'old': something answers on the doorman port but left no record (a host service from
    before port changes, which would keep watching the old ports); 'none': no service."""
    record = read_json(Path(group['root']) / SERVICE_RECORD)
    if record and type(record.get('pid')) is int and sg.process_alive(record['pid']):
        return 'reloads'
    return 'old' if machine.listening(doorman_port(sg, group)) else 'none'


# -- the report ----------------------------------------------------------------------
def port_rows(sg, group, machine):
    gate = gate_of(group)
    rows = []
    for region in group['regions']:
        routed = bool(group.get('relay_port')) and region['id'] != gate
        rows.append({'port': region['port'], 'use': 'game', 'region': region['id'], 'name': region['name'],
                     # Forward on the router: the gate's port, or every game port without a relay.
                     'public': not routed, 'gate': region['id'] == gate})
        if region.get('transfer_port'):
            rows.append({'port': region['transfer_port'], 'use': 'transfer agent', 'region': region['id'],
                         'name': region['name'], 'public': False})
        rows.append({'port': region['standby_port'], 'use': 'standby (handover)', 'region': region['id'],
                     'name': region['name'], 'public': False})
    if group.get('relay_port'):
        rows.append({'port': group['relay_port'], 'use': 'relay', 'region': None, 'public': True})
        rows.append({'port': group['relay_control_port'], 'use': 'relay control', 'region': None, 'public': False})
    rows.append({'port': doorman_port(sg, group), 'use': 'doorman', 'region': None, 'public': True})
    for row in rows:
        # A standby port is only held during a handover; asking would say nothing.
        row['listening'] = None if row['use'].startswith('standby') else bool(machine.listening(row['port']))
    return sorted(rows, key=lambda row: (row['port'], row['use']))


def clashes(rows):
    seen, problems = {}, []
    for row in rows:
        owner = '%s%s' % (row['use'], ' of %s' % row['region'] if row['region'] else '')
        if row['port'] in seen:
            problems.append('port %d is used twice: %s and %s' % (row['port'], seen[row['port']], owner))
        seen.setdefault(row['port'], owner)
    return problems


def report(sg, group, platform=None):
    machine = machine_of(sg, group, platform)
    rows = port_rows(sg, group, machine)
    journal = read_json(journal_path(group))
    change = None
    if journal:
        change = {key: journal.get(key) for key in ('operation', 'kind', 'phase', 'error', 'changed', 'gate', 'changes',
                                                    'restart_needed', 'bot', 'log', 'updated')}
        change['running'] = change_running(sg, group) is not None
    return {'group': group['group'], 'gate': gate_of(group), 'mainland': group['mainland'],
            'public_host': group['public_host'], 'public_ports': sorted(row['port'] for row in rows if row['public']),
            'ports': rows, 'problems': clashes(rows), 'host_service': service_state(sg, group, machine), 'change': change}


# -- plans ---------------------------------------------------------------------------
def changed_raw(raw, changes, gate):
    """The group file's JSON with the planned ports (and gate) written in."""
    new = copy.deepcopy(raw)
    for region in new['regions']:
        for key, (_old, value) in changes.get(region['id'], {}).items():
            if value is None:
                region.pop(key, None)
            else:
                region[key] = value
    if gate:
        new['gate'] = gate[1]
    return new


def plan_gate(sg, group, region_id, platform=None, bot_profile=None):
    old = gate_of(group)
    if old is None:
        raise Refused('this group has no routing relay, so every region is joined on its own port; use set-port to move one')
    new = region_of(group, region_id)
    if new['kind'] in GATE_REFUSED_KINDS:
        raise Refused('a %s region cannot be the front door' % new['kind'])
    raw = read_json(group['_path']) or {}
    changes = {}
    early = []
    machine = machine_of(sg, group, platform)
    if new['kind'] == 'GATEWAY' and old != region_id and machine.listening(region_of(group, old)['port']) \
            and not machine.listening(new['port']):
        # While the front door plays, the gateway must already run, so the public port is
        # never left waiting on its first build. With the group stopped there is nothing to
        # keep up: only the ports change, and the next start brings the gateway up on it.
        early.append('the gateway %s is not running on port %d; start it first (add-gateway --apply starts it)'
                     % (region_id, new['port']))
    if old != region_id:
        was = region_of(group, old)
        changes[region_id] = {'port': [new['port'], was['port']]}
        changes[old] = {'port': [was['port'], new['port']]}
        listed = {entry['id']: entry.get('public') for entry in raw.get('regions', [])}
        # The front door keeps its hub listing: the new gate is listed as the old one was.
        if listed.get(old) is not None and listed.get(region_id) != listed.get(old):
            changes[region_id]['public'] = [listed.get(region_id), listed.get(old)]
    plan = build_plan(sg, group, 'set-gate', changes, [old, region_id], platform, bot_profile)
    plan['problems'][:0] = early
    return plan


def plan_port(sg, group, region_id, port=None, transfer_port=None, standby_port=None, platform=None, bot_profile=None):
    region = region_of(group, region_id)
    raw = read_json(group['_path']) or {}
    written = next((entry for entry in raw.get('regions', []) if entry.get('id') == region_id), {})
    change = {}
    for key, value in (('port', port), ('transfer_port', transfer_port), ('standby_port', standby_port)):
        if value is None:
            continue
        if type(value) is not int or not 1024 <= value <= 65535:
            raise Refused('%s must be a whole number from 1024 to 65535' % key.replace('_', ' '))
        # A standby port the group file does not name is a default: naming it is a change.
        current = written.get(key) if key == 'standby_port' else region.get(key)
        if key == 'transfer_port' and current is None:
            raise Refused('this group has no travel (no region has a transfer port)')
        if value != current:
            change[key] = [current, value]
    if not change:
        raise Refused('nothing to change: %s already uses those ports' % region_id)
    return build_plan(sg, group, 'set-port', {region_id: change}, None, platform, bot_profile)


def moves_world(change):
    """Whether a region's world must be stopped for its change (a standby port is only config)."""
    return 'port' in change or 'transfer_port' in change


def build_plan(sg, group, kind, changes, gate, platform, bot_profile):
    machine = machine_of(sg, group, platform)
    raw = read_json(group['_path'])
    if raw is None:
        raise Refused('could not read the group config')
    problems, warnings = [], []
    new_group = None
    try:
        new_group = sg.check_group(changed_raw(raw, changes, gate), group['_path'])
    except ValueError as error:
        problems.append(str(error))
    if new_group:
        door = doorman_port(sg, new_group)
        for region in new_group['regions']:
            for key in ('port', 'transfer_port'):
                if region.get(key) == door:
                    problems.append('region %s %s %d is the doorman port' % (region['id'], key.replace('_', ' '), door))
    vacated = {old for change in changes.values() for key, (old, _new) in change.items() if key in PORT_KEYS and old}
    for region_id, change in sorted(changes.items()):
        for key, (_old, value) in change.items():
            if key in PORT_KEYS and key != 'standby_port' and value not in vacated and machine.listening(value):
                problems.append('port %d (for %s) is in use by another program on this machine' % (value, region_id))
    if change_running(sg, group):
        problems.append('another port change is still running; wait for it to finish')
    if (Path(group['root']) / '.staging' / 'handover.lock').exists():
        problems.append('a handover is running; wait for it to finish')
    service = service_state(sg, group, machine)
    stopping = [region_id for region_id, change in changes.items() if moves_world(change)]
    if service == 'old' and stopping:
        problems.append('the host service runs code from before port changes and would keep watching the old ports; '
                        'restart it first (restart-host.bat, or Restart host service in the launcher)')
    regions = {}
    for region, host in sg.hosts(group, None, platform):
        if region['id'] not in stopping:
            continue
        entry = regions[region['id']] = {'name': region['name']}
        if not (host.repo / '.git').exists():
            entry.update(state='not set up', action='only its ports in the group file change')
            continue
        if host.lock.exists():
            problems.append('%s is running an action (%s); wait for it to finish' % (region['id'], (host.read_state() or {}).get('action')))
        if host.frozen():
            entry.update(state='asleep', action='ended while asleep (it saved before it slept); it wakes on its new port')
        elif host.platform.listening(region['port']):
            world = host.world()
            entry.update(state='awake', players=(world or {}).get('clients'), action='saved and stopped, then started on its new port')
            if not host.token():
                problems.append('%s has no config/lifecycle-token.txt, so its world cannot be asked to save' % region['id'])
            elif not world:
                problems.append('%s does not answer, so it cannot be asked to save' % region['id'])
            elif world_saves(world) and (world.get('busy') or not world.get('ready')):
                problems.append('%s is busy or not ready, so it cannot save now; try again in a minute' % region['id'])
        else:
            entry.update(state='cold' if host.cold() else 'stopped', action='not running: only its ports change')
    if gate:
        # The front door is brought up, unless the whole group is down (stopped for
        # maintenance): then only the ports change and the next start brings it up.
        down = not any(machine.listening(r['port']) for r in group['regions'])
        regions.setdefault(gate[1], {'name': region_of(group, gate[1])['name']})['start'] = not down
    plan = {'kind': kind, 'config': group['_path'], 'gate': gate, 'changes': changes, 'regions': regions,
            'problems': problems, 'warnings': warnings, 'already': not changes, 'host_service': service,
            'public_ports': sorted(row['port'] for row in port_rows(sg, new_group, machine) if row['public']) if new_group else None}
    if gate:
        # The front door's files and bot link lines move to the group once; later moves carry nothing.
        front = sg.plan_front_door(group, gate)
        plan['front_door'] = front if front['files'] or front['keys'] else None
        if front['files'] and any((sg.region_dir(group, r['id']) / '.git').exists() for r in group['regions']):
            warnings.append('every region must run a build that reads the shared admins file from %s: update the '
                            'regions before or right after this, or they keep reading the old copy' % front['folder'])
        plan['bot'] = plan_bot(sg, new_group or group, gate[1], bot_profile or group.get('bot_profile'), warnings, adopting=True,
                               moved=gate[0] != gate[1] or bool(front['files']))
    elif new_group and gate_of(group) in changes and 'port' in changes[gate_of(group)]:
        # The front door itself moves to another port: the outside world has to follow.
        port = changes[gate_of(group)]['port'][1]
        warnings.append('%s is the front door: forward port %d on the router and point the Discord Play button and the '
                        'launcher at it, or players cannot join' % (gate_of(group), port))
        plan['bot'] = plan_bot(sg, new_group, gate_of(group), bot_profile or group.get('bot_profile'), warnings)
    plan['steps'] = describe(sg, group, plan)
    return plan


def norm(path):
    return os.path.normcase(os.path.normpath(str(path))).replace('\\', '/')


def bot_servers(profile, group):
    """The profile's servers that watch this group (their region_group is this group file)."""
    servers = profile.get('servers')
    if not isinstance(servers, dict):
        return {}
    return {name: server for name, server in servers.items()
            if isinstance(server, dict) and isinstance(server.get('region_group'), str)
            and norm(server['region_group']) == norm(group['_path'])}


def bot_wanted(sg, group, gate_id, server, adopting=False):
    """The values a bot server entry needs to watch gate_id: only keys it already has, so a
    bot that works its paths out from the group file by itself is left alone. adopting:
    set-gate is about to move the shared admins file to the group's front-door folder."""
    folder = sg.region_dir(group, gate_id).as_posix()
    wanted = {'port': region_of(group, gate_id)['port']}
    if server.get('follow_front_door') is True:
        return wanted  # the bot takes its paths from the group file when it starts (PortableProfile::followFrontDoor)
    if 'basedir' in server:
        wanted['basedir'] = folder
    if 'admin_file' in server:
        shared = adopting or sg.front_shared(group)
        wanted['admin_file'] = (sg.front_dir(group).as_posix() if shared else folder) + '/SQL/admins.txt'
    host = server.get('gaia_host')
    if isinstance(host, dict) and 'config' in host:
        wanted['gaia_host.config'] = folder + '/data/shard-host/host.json'
    return wanted


def bot_current(server, key):
    if key == 'gaia_host.config':
        return server['gaia_host'].get('config')
    return server.get(key)


def plan_bot(sg, group, gate_id, profile_path, warnings, adopting=False, moved=False):
    """What set-gate changes in the bot's profile.json, or None without one."""
    if not profile_path:
        return None
    profile = read_json(profile_path)
    if profile is None:
        warnings.append('the bot profile %s could not be read, so the bot was not repointed' % profile_path)
        return None
    servers = bot_servers(profile, group)
    if not servers:
        warnings.append('no server in the bot profile names this group (region_group), so the bot was not repointed')
        return None
    changed = {}
    for name, server in servers.items():
        for key, value in bot_wanted(sg, group, gate_id, server, adopting).items():
            if bot_current(server, key) != value:
                changed.setdefault(name, {})[key] = [bot_current(server, key), value]
    # A bot that follows the front door has nothing to rewrite, but it only looks when it starts.
    follows = any(server.get('follow_front_door') is True for server in servers.values())
    return {'profile': str(profile_path), 'servers': changed, 'restart': bool(changed) or (follows and moved)}


def apply_bot(sg, group, gate_id, profile_path, stamp):
    """Repoint the bot profile at gate_id. Returns the plan it carried out, or None."""
    plan = plan_bot(sg, group, gate_id, profile_path, [])  # after the write: the front-door folder says where admins live
    if not plan or not plan['servers']:
        return plan
    profile = read_json(profile_path)
    for name, changes in plan['servers'].items():
        server = profile['servers'][name]
        for key, (_old, value) in changes.items():
            if key == 'gaia_host.config':
                server['gaia_host']['config'] = value
            else:
                server[key] = value
    shutil.copy2(profile_path, '%s.bak-%s' % (profile_path, stamp))
    write_json(profile_path, profile, indent=2)
    return plan


def describe(sg, group, plan):
    """The plan as the sentences the launcher and the console show."""
    steps = []
    name = lambda region_id: region_of(group, region_id)['name']
    for region_id, change in plan['changes'].items():
        moved = ', '.join('%s %s -> %s' % (key.replace('_', ' '), old if old is not None else 'default', new)
                          for key, (old, new) in change.items() if key in PORT_KEYS)
        if moved:
            steps.append('%s: %s.' % (name(region_id), moved))
    for region_id, entry in plan['regions'].items():
        if entry.get('state') == 'awake':
            players = entry.get('players')
            steps.append('%s is running%s: it is saved and stopped (players get the usual countdown), then started again.'
                         % (entry['name'], ' with %d online' % players if players else ''))
        elif entry.get('state') == 'asleep':
            steps.append('%s is asleep: it is ended as it is (it saved before it slept).' % entry['name'])
    gate = plan.get('gate')
    if gate and gate[0] != gate[1]:
        steps.append('%s becomes the front door on port %d; %s moves behind the relay.'
                     % (name(gate[1]), region_of(group, gate[0])['port'], name(gate[0])))
        steps.append('The router forward, the Play button and the launcher address stay as they are.')
    elif gate:
        steps.append('%s is already the front door; its files, the bot and the running worlds are checked again.' % name(gate[1]))
    front = plan.get('front_door')
    if front:
        what = ['the bot link settings (%s)' % ', '.join(front['keys'])] if front['keys'] else []
        what += ['the shared admins files'] if front['files'] else []
        steps.append('%s move to the group\'s front-door folder, where they follow whichever region is the front door.'
                     % (lambda text: text[0].upper() + text[1:])(' and '.join(what)))
    bot = plan.get('bot')
    if bot and bot['servers']:
        steps.append('The bot profile is pointed at %s; restart the bot afterwards.' % name((gate or [None, gate_of(group)])[1]))
    if plan['changes']:
        steps.append('Worlds that keep running learn the new ports without a restart.')
    return steps


# -- apply ---------------------------------------------------------------------------
def apply(sg, group, plan, start=None):
    """Accept a plan and hand it to a detached worker. Refuses a plan with problems."""
    if plan['problems']:
        raise Refused('; '.join(plan['problems']))
    operation = secrets.token_hex(16)
    root = Path(group['root'])
    root.mkdir(parents=True, exist_ok=True)
    journal = {'operation': operation, 'kind': plan['kind'], 'phase': 'accepted', 'error': None, 'changed': False,
               'gate': plan.get('gate'), 'changes': plan['changes'], 'plan': plan, 'log': [],
               'started': int(time.time()), 'updated': int(time.time()), 'pid': None}
    write_json(journal_path(group), journal)
    argv = [sys.executable, '-I', '-B', str(Path(sg.__file__).resolve()), '--config', group['_path'], '--ports-worker', operation]
    # The worker records its own pid: two writers of one journal could collide.
    (start or sg.detach)(argv, root, root / 'port-change.log')
    return {'accepted': True, 'operation': operation, 'journal': str(journal_path(group)), 'plan': plan}


class Worker:
    def __init__(self, sg, group, operation, platform=None, sleep=time.sleep, clock=time.monotonic):
        self.sg, self.group, self.platform, self.sleep, self.clock = sg, group, platform, sleep, clock
        self.path = journal_path(group)
        self.journal = read_json(self.path) or {}
        self.valid = self.journal.get('operation') == operation
        self.plan = self.journal.get('plan') or {}

    def record(self, **values):
        self.journal.update(values, updated=int(time.time()))
        write_json(self.path, self.journal)

    def note(self, text):
        self.journal.setdefault('log', []).append(text)
        self.record()

    def phase(self, name):
        self.record(phase=name)

    def host(self, group, region_id):
        return self.sg.hosts(group, region_id, self.platform)[0][1]

    def wait(self, done, timeout, what):
        deadline = self.clock() + timeout
        while not done():
            if self.clock() >= deadline:
                raise RuntimeError('%s did not finish in %d minutes' % (what, timeout // 60))
            self.sleep(POLL_SECONDS)

    def failed_action(self, host, operation):
        """The error of the host action `operation`, or None while it has none."""
        state = host.read_state() or {}
        if state.get('operation') == operation and (state.get('error') or state.get('phase') == 'failed'):
            return state.get('error') or '%s failed' % state.get('action')
        return None

    def run(self):
        if not self.valid:
            return False
        self.record(pid=os.getpid())
        try:
            self.steps()
        except Exception as error:  # every failure lands in the journal the launcher reads
            self.record(phase='failed', error=str(error)[:600])
            return False
        return True

    def steps(self):
        sg, old = self.sg, self.group
        changes = self.plan['changes']
        gate = self.plan.get('gate')
        moving = [region_id for region_id, change in changes.items() if moves_world(change)]
        self.phase('stopping')
        restart = self.stop(old, moving)
        self.record(restart=restart)
        self.phase('writing')
        new = self.write(old, changes, gate)
        self.record(changed=True)
        self.phase('host service')
        self.wait_for_service(new)
        self.phase('starting')
        wanted = list(restart)
        if gate and gate[1] not in wanted:
            if self.plan['regions'].get(gate[1], {}).get('start', True):
                wanted.insert(0, gate[1])  # the front door is brought up
        elif gate:
            wanted.sort(key=lambda region_id: region_id != gate[1])  # and first
        self.start(new, wanted)
        self.phase('telling')
        self.record(restart_needed=self.tell(new, set(moving) | set(wanted)))
        self.phase('done')

    # 1. save and stop the worlds whose port moves
    def stop(self, group, moving):
        restart, waiting = [], {}
        try:
            for region_id in moving:
                host = self.host(group, region_id)
                if not (host.repo / '.git').exists():
                    continue
                if host.frozen():
                    try:
                        host.evict('port change')
                        self.note('%s: ended while asleep' % region_id)
                        continue
                    except Refused:
                        pass  # a world that does not save before sleeping: stop it the usual way
                if host.platform.listening(host.config['port']):
                    restart.append(region_id)
                    waiting[region_id] = (host, host.request('stop')['operation'])
                    self.note('%s: saving and stopping' % region_id)
            for region_id, (host, operation) in waiting.items():
                def stopped(host=host, operation=operation, region_id=region_id):
                    error = self.failed_action(host, operation)
                    if error:
                        raise RuntimeError('%s did not stop: %s' % (region_id, error))
                    return not host.platform.listening(host.config['port']) and not host.lock.exists()
                self.wait(stopped, host.config['save_timeout_seconds'] + self.group['shutdown_warning_seconds'] + 600,
                          'the save and stop of %s' % region_id)
                self.note('%s: stopped' % region_id)
        except Exception as error:
            # Nothing was written: bring back what this run stopped, and change nothing.
            for region_id in restart:
                host = self.host(group, region_id)
                if not host.platform.listening(host.config['port']) and not host.lock.exists():
                    try:
                        host.request('start')
                        self.note('%s: started again on its old port' % region_id)
                    except Refused as refusal:
                        self.note('%s: could not be started again: %s' % (region_id, refusal))
            raise RuntimeError('%s; nothing was changed' % error)
        return restart

    # 2. the group file, every region's generated config, the gate's settings and files, the bot
    def write(self, group, changes, gate):
        sg = self.sg
        stamp = time.strftime('%Y%m%d-%H%M%S', time.gmtime())
        path = Path(group['_path'])
        raw = read_json(path)
        if raw is None:
            raise RuntimeError('could not read the group config')
        new_raw = changed_raw(raw, changes, gate)
        sg.check_group(copy.deepcopy(new_raw), str(path))  # never write a file the next load refuses
        if new_raw != raw:
            shutil.copy2(path, path.with_name('%s.bak-%s' % (path.name, stamp)))
            write_json(path, new_raw, indent=2)
            self.note('group config written (the old one is kept as %s.bak-%s)' % (path.name, stamp))
        new = sg.load_group(path)
        for region in new['regions']:
            folder = sg.region_dir(new, region['id'])
            if (folder / '.git').exists():
                sg.write_region_files(new, region, folder)
        # An agent on a port its region left would keep that port and its store.
        for region_id, change in changes.items():
            if 'transfer_port' in change and change['transfer_port'][0]:
                machine = sg.RegionPlatform(sg.region_config(new, region_of(new, region_id)))
                for pid in machine.listener_pids(change['transfer_port'][0]):
                    machine.terminate(pid)
        if gate:
            # From the old front door (or the new one, when a move is run again): its admins files and bot link lines
            # become the group's, so this and every later move carries nothing between regions.
            adopted = sg.adopt_front_door(group, stamp, gate)
            if adopted:
                self.note('moved to the front-door folder: %s' % ', '.join(adopted))
            if gate[0] != gate[1] and (sg.front_dir(new) / 'config.local.txt').is_file():
                for region_id in gate:  # the two worlds the bot link moves between; both are stopped
                    if not (sg.region_dir(new, region_id) / '.git').exists():
                        continue
                    _done, refused = sg.apply_config(new, region_id, self.platform)
                    if region_id in refused:
                        raise RuntimeError('could not write the config of %s: %s' % (region_id, refused[region_id]))
                self.note('the bot link settings follow %s' % gate[1])
        target = (gate or [None, gate_of(new)])[1]
        profile = (self.plan.get('bot') or {}).get('profile')
        if profile and target:
            bot = apply_bot(sg, new, target, profile, stamp)
            if bot:
                bot['restart'] = bot['restart'] or bool(self.plan['bot'].get('restart'))
            self.record(bot=bot)
        return new

    # 3. the host service watches every region by its port: it must load the new ones first
    def wait_for_service(self, group):
        sg = self.sg
        machine = machine_of(sg, group, self.platform)
        state = service_state(sg, group, machine)
        if state == 'none':
            return
        wanted = signature(group['_path'])
        record = Path(group['root']) / SERVICE_RECORD
        loaded = lambda: (read_json(record) or {}).get('signature') == wanted
        try:
            if state == 'old':
                raise RuntimeError('timed out')
            self.wait(loaded, SERVICE_RELOAD_SECONDS, 'the host service')
        except RuntimeError:
            raise RuntimeError('the new ports are written, but the host service has not loaded them; restart it '
                               '(restart-host.bat, or Restart host service in the launcher) and run the same command again')
        self.note('host service loaded the new ports')

    # 4. start what was stopped, the gate first
    def start(self, group, wanted):
        waiting = {}
        for region_id in wanted:
            host = self.host(group, region_id)
            if not (host.repo / '.git').exists() or host.frozen() or host.platform.listening(host.config['port']):
                continue
            if host.lock.exists():
                raise RuntimeError('%s is running another action; run the same command again when it has finished' % region_id)
            try:
                waiting[region_id] = (host, host.request('start')['operation'])
            except Refused as refusal:
                raise RuntimeError('%s could not be started: %s; fix that and run the same command again' % (region_id, refusal))
            self.note('%s: starting on port %d' % (region_id, host.config['port']))
        for region_id, (host, operation) in waiting.items():
            def started(host=host, operation=operation, region_id=region_id):
                error = self.failed_action(host, operation)
                if error:
                    raise RuntimeError('%s did not start: %s; fix that and run the same command again' % (region_id, error))
                return host.platform.listening(host.config['port']) and not host.lock.exists()
            self.wait(started, host.config['start_timeout_seconds'] + 3600, 'the start of %s' % region_id)
            self.note('%s: running' % region_id)

    # 5. the relay and the worlds that kept running
    def tell(self, group, fresh):
        sg = self.sg
        if group.get('relay_port') and sg.relay_pid(group):
            try:
                self.note('relay told ports: %s' % sg.relay_add_ports(group))
            except Exception as error:  # the host service teaches it at its next pass
                self.note('relay not told: %s' % str(error)[:200])
        behind = []
        for region, host in sg.hosts(group, None, self.platform):
            if region['id'] in fresh or host.frozen() or not host.platform.listening(region['port']):
                continue
            answer = None
            try:
                if host.token():
                    answer = host.platform.query(region['port'], host.token(), 'reload_group')
            except (OSError, RuntimeError, ValueError):
                answer = None
            if not isinstance(answer, dict) or answer.get('reload') != 'reloaded':
                behind.append(region['id'])  # an older build: it learns the ports at its next restart
        if behind:
            self.note('running an older build, they learn the new ports at their next restart: %s' % ', '.join(behind))
        return behind


def work(sg, group, operation, platform=None, sleep=time.sleep, clock=time.monotonic):
    return Worker(sg, group, operation, platform, sleep, clock).run()
