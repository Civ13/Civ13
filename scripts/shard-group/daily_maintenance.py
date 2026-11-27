"""Daily maintenance: every region moves onto one build together, at a set time of day.

Val (2026-11-22): "a scheduled maintenance routine at a specific time of day to ensure that all
servers shut down, update, and restart on the same build."

The group config's `maintenance` object sets it (the launcher's Host tab > All regions > More >
Daily maintenance...):

    "maintenance": {"enabled": true, "time": "03:00", "warning_minutes": 10, "late_minutes": 90}

`time` is the host's local time (the quietest hours on the Earth host, 2026-11-05 to 11-22, were
1-5 AM Eastern). The host service checks every half minute (shard_group.supervise) and starts one
detached run per day (`shard_group.py maintenance --scheduled`); a host that was down or busy at
the time still starts it up to `late_minutes` afterwards, and otherwise waits for the next day.
The launcher's "Run maintenance now" starts the same run at once (`shard_group.py maintenance`).

One run:

1. resolves the group revision once (after a fetch) and pins it (<root>/.maintenance/pin.json):
   while the pin stands, load_group gives every reader that revision, so the stages, the
   handovers and any empty-region update all build the same commit even if master moves;
2. builds it beside every region that is not on it yet (stage), while everyone keeps playing.
   If any region's build fails, nothing is stopped or handed over and no region changes build:
   the run ends as failed and every world plays on;
3. gives the players of every occupied running region the same countdown at once (lifecycle
   planned_notice, `warning_minutes`); an admin's Cancel Planned Restart in a region leaves that
   region on its old build for the day;
4. hands every running region over to the build in turn (save, the new build loads it beside
   the old world, players move across); a region busy with another action is tried again later. Asleep, cold and stopped regions take the
   build without waking (update_offline). Oceans wait for their configured coastal lands
   to finish installing this revision; an unrelated busy region never holds them back;
5. removes the pin and records what each region did (<root>/.maintenance/state.json).

The gateway (the always-up world on the front door's port) is never staged, stopped or moved
(Val, 2026-11-21): it is left out. A group that does not save (TDM) is left out too: its battle
updates between rounds and its barracks when empty (battle_mapswap.py).
"""
import datetime
import json
import os
import sys
import time
from pathlib import Path

from gaia_host import Refused

FOLDER = '.maintenance'
DEFAULT_TIME = '03:00'
DEFAULT_WARNING_MINUTES = 10
DEFAULT_LATE_MINUTES = 90
MAX_WARNING_MINUTES = 60
# A pin older than this is ignored: a run that died without removing it must not hold the
# group on an old revision.
PIN_SECONDS = 8 * 3600
STAGE_SECONDS = 4 * 3600  # every region compiles in turn, 2-4 minutes each
STAGE_ATTEMPTS = 3  # a background stage that was already compiling an older commit is asked again
HANDOVER_SECONDS = 4 * 3600
POLL_SECONDS = 15
# The handover's own countdown after the maintenance countdown: a short reminder only.
WARNED_HANDOVER_SECONDS = 30
# Handover refusals that pass (another action, a save under way, memory for the standby).
RETRY_WORDS = ('another action', 'busy', 'saving', 'memory', 'standby port')


def folder(group):
    return Path(group['root']) / FOLDER


def check_settings(group):
    """Validate the group's maintenance settings and fill in their defaults (check_group).
    On by default for the live group when it saves and follows a remote, at 03:00 host time;
    off for a TDM group, a test group, or one with no remote to take new commits from."""
    settings = group.setdefault('maintenance', {})
    if type(settings) is not dict:
        raise ValueError('maintenance must be an object')
    enabled = settings.setdefault('enabled', bool(group.get('persistent', True) and group.get('live') and group.get('fetch')))
    if type(enabled) is not bool:
        raise ValueError('maintenance enabled must be true or false')
    if parse_time(settings.setdefault('time', DEFAULT_TIME)) is None:
        raise ValueError('maintenance time must be HH:MM (24-hour, host local time)')
    for key, default, high in (('warning_minutes', DEFAULT_WARNING_MINUTES, MAX_WARNING_MINUTES),
                               ('late_minutes', DEFAULT_LATE_MINUTES, 720)):
        value = settings.setdefault(key, default)
        if type(value) is not int or not 0 <= value <= high:
            raise ValueError('maintenance %s must be a whole number from 0 to %d' % (key, high))
    return settings


def parse_time(text):
    """(hour, minute) for 'HH:MM', or None."""
    if type(text) is not str or len(text) != 5 or text[2] != ':' or not (text[:2] + text[3:]).isdigit():
        return None
    hour, minute = int(text[:2]), int(text[3:])
    return (hour, minute) if hour < 24 and minute < 60 else None


# -- the revision pin ---------------------------------------------------------------------

def read_json(path):
    try:
        value = json.loads(Path(path).read_text(encoding='utf-8'))
    except (OSError, ValueError):
        return {}
    return value if type(value) is dict else {}


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + '.tmp')
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n', encoding='utf-8')
    os.replace(temporary, path)


def active_pin_record(group, now=None):
    """The one atomic commit pin while a confirmed group build sync runs."""
    pin = read_json(folder(group) / 'pin.json')
    revision = pin.get('revision')
    started = pin.get('started')
    if type(revision) is not str or len(revision) != 40 or any(c not in '0123456789abcdef' for c in revision):
        return None
    if type(started) not in (int, float) or not 0 <= (now or time.time()) - started <= PIN_SECONDS:
        return None
    return pin


def active_pin(group, now=None):
    pin = active_pin_record(group, now)
    return pin['revision'] if pin else None


def apply_pin(group):
    """check_group: while a maintenance run stands, the group revision is the pinned commit."""
    pin = active_pin_record(group)
    if not pin:
        return None
    pinned = pin['revision']
    group['unpinned_revision'] = group['revision']
    group['revision'] = pinned
    if pin.get('mode') == 'match-mainland':
        group['mainland_match_revision'] = pinned
    return pinned


# -- scheduling (the host service) ----------------------------------------------------------

def slot_for(settings, now):
    """The datetime of today's slot (host local time) for a timestamp."""
    hour, minute = parse_time(settings['time'])
    local = datetime.datetime.fromtimestamp(now)
    return local, local.replace(hour=hour, minute=minute, second=0, microsecond=0)


def due(group, now=None):
    """Today's date (YYYY-MM-DD) when the daily run should start now, else None."""
    settings = group.get('maintenance') or {}
    if not settings.get('enabled') or not group.get('persistent', True):
        return None
    now = time.time() if now is None else now
    local, slot = slot_for(settings, now)
    if local < slot or (local - slot).total_seconds() > settings.get('late_minutes', DEFAULT_LATE_MINUTES) * 60:
        return None
    day = slot.strftime('%Y-%m-%d')
    state = read_json(folder(group) / 'state.json')
    if state.get('day') == day and state.get('scheduled'):
        return None  # today's run already started (or ended)
    return day


def next_run(group, now=None):
    """'YYYY-MM-DD HH:MM' of the next scheduled start, or None when it is off."""
    settings = group.get('maintenance') or {}
    if not settings.get('enabled') or not group.get('persistent', True):
        return None
    now = time.time() if now is None else now
    local, slot = slot_for(settings, now)
    state = read_json(folder(group) / 'state.json')
    if local >= slot and (state.get('day') == slot.strftime('%Y-%m-%d') and state.get('scheduled')
                          or (local - slot).total_seconds() > settings.get('late_minutes', DEFAULT_LATE_MINUTES) * 60):
        slot += datetime.timedelta(days=1)
    return slot.strftime('%Y-%m-%d %H:%M')


def running(this, group):
    """The pid of a live maintenance run, or None."""
    lock = read_json(folder(group) / 'run.json')
    pid = lock.get('pid')
    return pid if type(pid) is int and this.process_alive(pid) else None


def worker_argv(group, scheduled, match_mainland=False):
    argv = [group.get('python') or sys.executable, '-I', '-B', str(Path(__file__).with_name('shard_group.py')),
            '--config', group['_path'], 'match-mainland' if match_mainland else 'maintenance']
    return argv + ['--scheduled'] if scheduled else argv


def ensure(this, group, start, now=None):
    """supervise(): start today's run when it is due. The day it started, or None."""
    day = due(group, now)
    if not day or running(this, group):
        return None
    write_json(folder(group) / 'state.json', {'day': day, 'scheduled': True, 'phase': 'starting',
                                              'started': int(now or time.time())})
    start(worker_argv(group, True), group['root'], str(folder(group) / 'maintenance.log'))
    return day


def request(this, group, start, match_mainland=False):
    """The launcher's Run maintenance now: start a run at once (refused while one runs)."""
    if not group.get('persistent', True):
        raise Refused('a group that does not save updates between rounds; daily maintenance is for saving groups')
    pid = running(this, group)
    if pid:
        raise Refused('maintenance is already running (pid %d)' % pid)
    folder(group).mkdir(parents=True, exist_ok=True)
    pid = start(worker_argv(group, False, match_mainland), group['root'], str(folder(group) / 'maintenance.log'))
    return {'accepted': True, 'action': 'match-mainland' if match_mainland else 'maintenance', 'pid': pid}


def status(this, group, now=None):
    """What the launcher shows: the settings, the next start and the last run."""
    settings = group.get('maintenance') or {}
    state = read_json(folder(group) / 'state.json')
    return {'enabled': bool(settings.get('enabled')) and bool(group.get('persistent', True)),
            'time': settings.get('time'), 'warning_minutes': settings.get('warning_minutes'),
            'late_minutes': settings.get('late_minutes'), 'persistent': bool(group.get('persistent', True)),
            'next': next_run(group, now), 'running': running(this, group) is not None,
            'pinned': active_pin(group, now), 'last': state or None}


# -- the run ------------------------------------------------------------------------------

class Run:
    def __init__(self, this, group, scheduled=False, platform=None, sleep=time.sleep, clock=time.time, match_mainland=False):
        self.this, self.group, self.scheduled = this, group, scheduled
        self.platform, self.sleep, self.clock = platform, sleep, clock
        self.match_mainland = match_mainland
        self.dir = folder(group)
        self.state = {}

    def save(self, **values):
        self.state.update(values, updated=int(self.clock()))
        write_json(self.dir / 'state.json', self.state)

    def note(self, region_id, **values):
        self.state.setdefault('regions', {}).setdefault(region_id, {}).update(values)
        self.save()

    def run(self):
        self.dir.mkdir(parents=True, exist_ok=True)
        lock = self.dir / 'run.json'
        try:
            descriptor = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        except FileExistsError:
            held = read_json(lock).get('pid')
            if type(held) is int and self.this.process_alive(held):
                raise Refused('maintenance is already running (pid %d)' % held)
            os.remove(lock)  # left by a run that died
            descriptor = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        with os.fdopen(descriptor, 'w') as handle:
            handle.write(json.dumps({'pid': os.getpid(), 'started': int(self.clock())}))
        started = int(self.clock())
        day = datetime.datetime.fromtimestamp(started).strftime('%Y-%m-%d')
        previous = read_json(self.dir / 'state.json')
        self.state = {'day': day, 'scheduled': self.scheduled or (previous.get('day') == day and bool(previous.get('scheduled'))),
                      'started': started, 'phase': 'starting', 'regions': {}, 'error': None, 'finished': None}
        if self.match_mainland:
            self.state['mode'] = 'match-mainland'
        self.save()
        try:
            result = self.steps()
            self.save(phase='done' if not result.get('problems') else 'done with problems', result=result,
                      finished=int(self.clock()))
            return result
        except Exception as error:
            self.save(phase='failed', error=str(error)[:500], finished=int(self.clock()))
            raise
        finally:
            for name in ('pin.json', 'run.json'):
                try:
                    os.remove(self.dir / name)
                except OSError:
                    pass

    def checked_mainland_revision(self, host):
        """Take a trusted live build stamp, not a checkout HEAD or staged build."""
        locked = getattr(host, 'lock', None)
        if (locked is not None and locked.exists()) or host.frozen() or not host.platform.listening(host.config['port']):
            raise Refused('the mainland is not awake and idle; wait for its active build to settle')
        revision = host.built_revision()
        if (locked is not None and locked.exists()) or not self.this.HEX40.fullmatch(revision or ''):
            raise Refused('the mainland has no verified active build to match')
        return revision

    def forward_build(self, current, target):
        if not self.this.HEX40.fullmatch(current or ''):
            return False
        platform = self.platform or self.this.Platform()
        code, _ = platform.run([self.group['git'], 'merge-base', '--is-ancestor', current, target],
                               cwd=self.group['repository'], timeout=60)
        return code == 0

    def steps(self):
        this, group = self.this, self.group
        if not group.get('persistent', True):
            raise Refused('a group that does not save updates between rounds; daily maintenance is for saving groups')
        # A pin left by a run that died must not decide today's revision.
        try:
            os.remove(self.dir / 'pin.json')
        except OSError:
            pass
        regions = []
        for region, host in this.hosts(group, platform=self.platform):
            name = region['id']
            if host.holds_its_port():
                self.note(name, result='left running: the gateway stays on its port')
                continue
            if not (host.repo / '.git').exists():
                self.note(name, result='skipped: not set up')
                continue
            if this.fresh_world.pending(host).exists():
                self.note(name, result='skipped: interrupted fresh-world archive')
                continue
            regions.append((region, host))
        if self.match_mainland:
            mainland = next((host for region, host in regions if region['id'] == group['mainland']), None)
            if mainland is None:
                raise Refused('the mainland is not available to establish a matching build')
            self.save(phase='checking the mainland build')
            revision = self.checked_mainland_revision(mainland)
            blocked = [region['id'] for region, host in regions
                       if not self.forward_build(host.built_revision(), revision)]
            if blocked:
                raise Refused('cannot safely match the mainland: these regions have newer, diverged, or unknown builds: '
                              + ', '.join(blocked) + '. Use the latest group update instead.')
            if self.checked_mainland_revision(mainland) != revision:
                raise Refused('the mainland changed builds before the match started; try again')
            # Never schedule a restart or build for the source of a match.
            regions = [(r, h) for r, h in regions if h is not mainland]
            self.note(group['mainland'], result='already on the build (mainland left running)')
        else:
            unpinned = group.get('unpinned_revision') or group['revision']
            self.save(phase='checking for updates')
            this.fetch_remote(group, self.platform)
            code, out = (self.platform or this.Platform()).run([group['git'], 'rev-parse', unpinned],
                                                               cwd=group['repository'], timeout=60)
            revision = out.strip().splitlines()[-1] if code == 0 and out.strip() else ''
            if not this.HEX40.match(revision):
                raise RuntimeError('could not resolve the group revision %s' % unpinned)
        pin = {'revision': revision, 'started': int(self.clock())}
        if self.match_mainland:
            pin['mode'] = 'match-mainland'
        write_json(self.dir / 'pin.json', pin)
        self.save(revision=revision)
        failed = self.stage(regions, revision)
        if failed:
            # The same build everywhere or no change anywhere: nothing was stopped.
            raise RuntimeError('the build of %s did not finish, so no region was updated (every world keeps '
                               'playing on its build): %s' % (', '.join(sorted(failed)),
                                                               '; '.join('%s: %s' % item for item in sorted(failed.items()))[:400]))
        behind = [(r, h) for r, h in regions if h.built_revision() != revision]
        live, offline = [], []
        for region, host in behind:
            (offline if host.frozen() or not host.platform.listening(host.config['port']) else live).append((region, host))
        for region, host in regions:
            if (region, host) not in behind:
                self.note(region['id'], result='already on the build')
        installing = self.install_offline([(r, h) for r, h in offline if r['kind'] != 'OCEANIC'])
        cancelled = self.warn(live)
        self.hand_over([(r, h) for r, h in live if r['id'] not in cancelled], revision,
                       offline_oceans=[(r, h) for r, h in offline if r['kind'] == 'OCEANIC'],
                       installing=installing if self.match_mainland else None)
        problems = {name: entry.get('result') for name, entry in self.state['regions'].items()
                    if not str(entry.get('result', '')).startswith(('already on', 'handed over', 'left running: the gateway',
                                                                     'installing while', 'installed while', 'skipped: not set up'))}
        return {'revision': revision, 'problems': problems}

    def stage(self, regions, revision):
        """Build the revision beside every region that does not run or hold it yet; the
        regions whose build failed, with why."""
        self.save(phase='building the update beside the running worlds')
        failed = {}
        for attempt in range(STAGE_ATTEMPTS):
            waiting = []
            for region, host in regions:
                if host.built_revision() == revision or host.staged_revision() == revision:
                    continue
                try:
                    host.request_stage(urgent=True)
                except Refused as refusal:
                    if 'already being staged' not in str(refusal):
                        failed[region['id']] = str(refusal)
                        continue
                self.note(region['id'], result='building')
                waiting.append((region, host))
            if not waiting:
                break
            deadline = self.clock() + STAGE_SECONDS
            while any(host.stage_running() for _region, host in waiting):
                if self.clock() > deadline:
                    for region, host in waiting:
                        if host.stage_running():
                            failed[region['id']] = 'the build took too long'
                    return failed
                self.sleep(POLL_SECONDS)
            for region, host in waiting:
                if host.built_revision() == revision or host.staged_revision() == revision:
                    self.note(region['id'], result='built')
                    continue
                stage = host.read_json(host.stage_file) or {}
                if stage.get('phase') == 'failed' and stage.get('revision') in (None, revision):
                    failed[region['id']] = stage.get('error') or 'the build failed'
                # else a stage that was already compiling an older commit finished: ask again
        for region, host in regions:
            if region['id'] not in failed and host.built_revision() != revision and host.staged_revision() != revision:
                failed[region['id']] = 'the build is not ready'
        for name, why in failed.items():
            self.note(name, result='build failed: %s' % str(why)[:300])
        return failed

    def install_offline(self, offline):
        """Queue asleep, cold and stopped regions without waking them (update_offline)."""
        accepted = {}
        for region, host in offline:
            name = region['id']
            try:
                answer = self.this.update_offline(self.group, name, self.platform)
            except (Refused, OSError, RuntimeError, ValueError) as error:
                self.note(name, result='not updated: %s' % str(error)[:300])
                continue
            if name in answer.get('accepted', {}):
                state = answer['accepted'][name].get('state', 'down')
                accepted[name] = (host, state)
                self.note(name, result='installing while %s' % state)
            else:
                self.note(name, result='not updated: %s' % answer.get('skipped', {}).get(name, 'refused'))
        return accepted

    def world(self, host):
        try:
            return host.world() or {}
        except (OSError, RuntimeError, ValueError):
            return {}

    def warn(self, live):
        """Every occupied running region counts down together. The ids whose countdown an
        admin called off in game (they keep their build today)."""
        minutes = (self.group.get('maintenance') or {}).get('warning_minutes', DEFAULT_WARNING_MINUTES)
        warned = []
        if minutes:
            for region, host in live:
                status = self.world(host)
                if not status.get('clients') or not status.get('planned_notice'):
                    continue
                try:
                    answer = host.platform.query(host.config['port'], host.token(), 'planned_notice',
                                                 extra={'seconds': str(minutes * 60)})
                except (OSError, RuntimeError, ValueError) as error:
                    self.note(region['id'], notice='not sent: %s' % str(error)[:200])
                    continue
                if answer.get('notice') == 'started':
                    warned.append((region, host))
                    self.note(region['id'], notice='players warned (%d min)' % minutes, warned=True)
                else:
                    self.note(region['id'], notice='refused: %s' % answer.get('notice'))
        if not warned:
            return set()
        self.save(phase='players warned; handing over in %d minutes' % minutes)
        end = self.clock() + minutes * 60
        cancelled = set()
        while self.clock() < end:
            self.sleep(min(POLL_SECONDS, max(1, end - self.clock())))
            for region, host in warned:
                if region['id'] in cancelled:
                    continue
                status = self.world(host)
                if status and status.get('shutdown_in') is None:
                    cancelled.add(region['id'])
                    self.note(region['id'], result='called off in game by an admin; left on its build today')
        return cancelled

    def ocean_waiting(self, host, revision):
        """Return (coastal reason, final) for an ocean not ready in this run."""
        blockers = host.ocean_update_blockers(self.group, revision)
        if not blockers:
            return None, False
        states = self.state['regions']
        finished = ('called off', 'not updated', 'handover failed', 'handed over, but', 'skipped:')
        final = any(name not in states or str(states[name].get('result', '')).startswith(finished)
                    for name in blockers)
        return 'waiting for coastal land builds: ' + ', '.join(blockers), final

    def hand_over(self, live, revision, offline_oceans=(), installing=None):
        """Hand live regions over, and install offline oceans once their lands are ready."""
        self.save(phase='handing over')
        pending = sorted(live, key=lambda pair: pair[0]['kind'] == 'OCEANIC')
        offline = list(offline_oceans)
        operations = {}
        installing_offline = dict(installing or {})
        deadline = self.clock() + HANDOVER_SECONDS
        while pending or offline or operations or installing_offline:
            for region, host in list(offline):
                reason, final = self.ocean_waiting(host, revision)
                if reason:
                    self.note(region['id'], result=('not updated: ' if final else '') + reason)
                    if final:
                        offline.remove((region, host))
                    continue
                offline.remove((region, host))
                installing_offline.update(self.install_offline([(region, host)]))
            for region, host in list(pending):
                if region['kind'] == 'OCEANIC':
                    reason, final = self.ocean_waiting(host, revision)
                    if reason:
                        self.note(region['id'], result=('not updated: ' if final else '') + reason)
                        if final:
                            pending.remove((region, host))
                        continue
                try:
                    answer = host.request('handover')
                except Refused as refusal:
                    text = str(refusal)
                    if not any(word in text.lower() for word in RETRY_WORDS):
                        pending.remove((region, host))
                        self.note(region['id'], result='not updated: %s' % text[:300])
                        continue
                    # Another action (a save, a sleep, an empty-region update) holds this region, or
                    # the machine cannot hold a standby yet: the others go ahead, and it is asked
                    # again on the next pass.
                    self.note(region['id'], result='waiting: %s' % text[:200])
                    continue
                pending.remove((region, host))
                operations[region['id']] = (host, answer['operation'])
                self.note(region['id'], result='handing over')
            for name, (host, operation) in list(operations.items()):
                state = host.read_state()
                if state.get('operation') != operation:
                    continue
                if state.get('phase') == 'done':
                    del operations[name]
                    self.note(name, result='handed over' if host.built_revision() == revision
                              else 'handed over, but runs %s' % host.built_revision())
                elif state.get('phase') in ('failed', 'killed'):
                    del operations[name]
                    self.note(name, result='handover failed (the old world plays on): %s' % str(state.get('error'))[:300])
            # Keep the maintenance pin until these newly admitted oceans have
            # taken the candidate build, not merely until the request is queued.
            for name, (host, prior_state) in list(installing_offline.items()):
                if host.built_revision() == revision:
                    del installing_offline[name]
                    self.note(name, result='installed while %s' % prior_state)
                elif not host.stage_running() and not host.install_marker.exists() and not host.lock.exists():
                    stage = host.read_json(host.stage_file) or {}
                    status = host.read_state() or {}
                    if stage.get('phase') == 'failed' or str(stage.get('install', '')).startswith('not installed'):
                        del installing_offline[name]
                        self.note(name, result='not updated: %s' % (stage.get('install') or stage.get('error') or 'stage failed'))
                    elif status.get('action') == 'update' and status.get('phase') in ('failed', 'killed'):
                        del installing_offline[name]
                        self.note(name, result='not updated: %s' % (status.get('error') or 'offline install failed'))
            if not (pending or offline or operations or installing_offline):
                break
            if self.clock() > deadline:
                for region, host in pending + offline:
                    reason = self.ocean_waiting(host, revision)[0] if region['kind'] == 'OCEANIC' else None
                    self.note(region['id'], result='not updated: ' + (reason or 'still busy at the end of maintenance'))
                for name in operations:
                    self.note(name, result='handover still running at the end of maintenance')
                for name in installing_offline:
                    self.note(name, result='not updated: offline install did not finish during the update')
                break
            self.sleep(POLL_SECONDS)


def run(this, group, scheduled=False, platform=None, sleep=time.sleep, clock=time.time, match_mainland=False):
    return Run(this, group, scheduled, platform, sleep, clock, match_mainland).run()


def handover_warning(group, region_id):
    """RegionHost.shutdown_warning: a region whose players already had the maintenance
    countdown gets only a short reminder before its handover saves; None otherwise."""
    if not active_pin(group):
        return None
    state = read_json(folder(group) / 'state.json')
    if state.get('phase') != 'handing over' or not (state.get('regions') or {}).get(region_id, {}).get('warned'):
        return None
    return min(WARNED_HANDOVER_SECONDS, group['shutdown_warning_seconds'])
