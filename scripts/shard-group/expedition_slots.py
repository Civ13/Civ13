"""Expedition slots: regions of kind EXPEDITION that hold one generated land at a time.

A slot is FREE (no land; it runs its placeholder map if started) or holds a
LAND built from a world-chart template (docs/expedition-lands.md). Giving a
slot a land generates the map into the group root; the slot's next update
compiles it as the region's map (place_map in shard_group.py). Archiving moves
the slot's saved world aside and frees the slot for the next land. An archived
save (and the land it was built on) is kept 7 days so an admin can restore it
by hand, then deleted by the host service (prune_archives).

    python shard_group.py --config group.json expedition-land --region far1 --template T.json
    python shard_group.py --config group.json update-offline --region far1
    python shard_group.py --config group.json expedition-archive --region far1
    python shard_group.py --config group.json expedition-status

See docs/expedition-slots.md.
"""
import json
import os
from pathlib import Path
import shutil
import sys
import time

from gaia_host import Refused

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

SLOT_SCHEMA = 'civ13-expedition-slot/1'
# What the slot world reads about its land (code/modules/persistence/expedition_land.dm).
WORLD_FILE = 'config/expedition_land.json'
# A world's save: moved aside together when a slot is archived (as fresh_world.WORLD_PATHS).
WORLD_PATHS = ('map_saves', 'map_backups', 'map_rollback')
STATES = ('FREE', 'LAND')
HISTORY_KEPT = 50


SLOTS_FOLDER = 'expeditions'  # under the group root, beside the region worktrees
# A ship's course asks for a land (tools/transfer_storage/world_chart.py): the
# coordinator writes wanted/<slot>.json, the host service opens the slot
# (serve, open_land) and records its phase; a land it cannot open goes to
# failed/<slot>.json for the coordinator to turn the ship back.
WANTED = 'wanted'
FAILED = 'failed'
OPENING = 'opening'
ABANDONED = 'abandon'  # a land given up for good: the host archives the slot
OPENING_STALE_SECONDS = 3600
BUILDING_GIVE_UP_SECONDS = 3 * 3600
ARCHIVE_KEEP_SECONDS = 7 * 86400  # an archived land is deleted after this


def slots_dir(group):
    return Path(group['root']) / SLOTS_FOLDER


def slot_file(group, region_id):
    return slots_dir(group) / 'slots' / (region_id + '.json')


def expedition_region(group, region_id):
    region = next((r for r in group['regions'] if r['id'] == region_id), None)
    if region is None:
        raise Refused('no region %s in the group' % region_id)
    if region['kind'] != 'EXPEDITION':
        raise Refused('region %s is not an EXPEDITION slot' % region_id)
    return region


def wish_file(group, folder, region_id):
    return slots_dir(group) / folder / (region_id + '.json')


def read_wish(group, folder, region_id):
    try:
        value = json.loads(wish_file(group, folder, region_id).read_text(encoding='utf-8'))
    except (OSError, ValueError):
        return None
    return value if isinstance(value, dict) else None


def write_wish(group, folder, region_id, value):
    path = wish_file(group, folder, region_id)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + '.tmp')
    temporary.write_text(json.dumps(value, indent=1, sort_keys=True) + '\n', encoding='utf-8')
    os.replace(temporary, path)


def forget_build(host):
    """The region's build no longer matches its map: the next stage compiles
    and installs it even at the same revision."""
    for path in (host.build_file(), host.staged_file):
        path.unlink(missing_ok=True)


def read_slot(group, region_id):
    """The slot's record; a slot never given a land is FREE."""
    path = slot_file(group, region_id)
    if not path.exists():
        return {'schema': SLOT_SCHEMA, 'region': region_id, 'state': 'FREE', 'history': []}
    record = json.loads(path.read_text(encoding='utf-8'))
    if not isinstance(record, dict) or record.get('state') not in STATES or record.get('region') != region_id:
        raise Refused('slot record %s is damaged; fix or move it by hand' % path)
    return record


def write_slot(group, record):
    path = slot_file(group, record['region'])
    path.parent.mkdir(parents=True, exist_ok=True)
    record['history'] = record.get('history', [])[-HISTORY_KEPT:]
    temporary = path.with_name(path.name + '.tmp')
    temporary.write_text(json.dumps(record, indent=1) + '\n', encoding='utf-8')
    os.replace(temporary, path)


def saved_world(path):
    """The world paths in a region folder that hold anything."""
    found = []
    for name in WORLD_PATHS:
        folder = Path(path) / name
        if folder.is_dir() and any(folder.iterdir()):
            found.append(name)
    return found


def check_stopped(host):
    """Refuse unless the slot's world is stopped: not listening, not asleep, not waking."""
    if host.platform.listening(host.config['port']) or host.platform.listening(host.standby_port()):
        raise Refused('the slot is running; save and stop it first')
    for marker in (host.freeze_file, host.running_file):
        if marker.exists():
            raise Refused('the slot is not explicitly stopped (%s remains); save and stop it first' % marker.name)


def stamp(now=None):
    return time.strftime('%Y%m%dT%H%M%SZ', time.gmtime(now if now is not None else time.time()))


def unused(folder, name):
    """folder/name, or folder/name-2, -3... when an earlier one took that second."""
    path, n = folder / name, 1
    while path.exists():
        n += 1
        path = folder / ('%s-%d' % (name, n))
    return path


def world_summary(report):
    """What the slot world is told about its land (WORLD_FILE)."""
    t = report['template']
    return {'schema': SLOT_SCHEMA, 'key': report.get('key'), 'biome': t['biome'], 'land_type': t['land_type'],
            'size': t['size'], 'width': report['width'], 'height': report['height'], 'area': report['area'],
            'coast': t['coast'], 'seed': t['seed'], 'slot_world': report['slot_world']}


def default_build(template, out):
    from tools.procedural_maps.land import build_land
    return build_land(template, out)


def give_land(group, host, region_id, template, key=None, build=None, now=None):
    """Generate the land for template into the group root and give it to a FREE,
    stopped slot with no saved world. The slot's next update compiles it."""
    expedition_region(group, region_id)
    check_stopped(host)
    record = read_slot(group, region_id)
    if record['state'] != 'FREE':
        raise Refused('slot %s already holds land %s; archive it first' % (region_id, record.get('key')))
    held = saved_world(host.repo)
    if held:
        raise Refused('slot %s still holds a saved world (%s); archive it first' % (region_id, ', '.join(held)))
    build = build or default_build
    out = unused(slots_dir(group) / 'lands', '%s-%s' % (region_id, stamp(now)))
    out.parent.mkdir(parents=True, exist_ok=True)
    try:
        report = build(template, out)
    except ValueError as error:
        raise Refused('the land could not be built: %s' % str(error)[:300])
    report = dict(report, key=key)
    record.update(state='LAND', key=key, land_dir=str(out), map=str(out / 'land.dmm'),
                  world=world_summary(report), given_at=stamp(now), seconds=report.get('seconds'))
    record['history'].append({'at': stamp(now), 'event': 'land', 'key': key, 'land_dir': str(out)})
    write_slot(group, record)
    forget_build(host)
    return {'region': region_id, 'state': 'LAND', 'key': key, 'map': record['map'], 'seconds': report.get('seconds'),
            'next': 'update-offline --region %s compiles the land; then start the slot' % region_id}


def archive(group, host, region_id, now=None):
    """Move a stopped slot's saved world aside and free the slot. The land folder
    and the archived save are kept."""
    expedition_region(group, region_id)
    check_stopped(host)
    record = read_slot(group, region_id)
    target = unused(slots_dir(group) / 'archive', '%s-%s' % (region_id, stamp(now)))
    moved = []
    for name in saved_world(host.repo):
        target.mkdir(parents=True, exist_ok=True)
        shutil.move(str(host.repo / name), str(target / name))
        moved.append(name)
    if host.cold_file.exists():  # a slot saved and evicted: its cold record goes with its save
        target.mkdir(parents=True, exist_ok=True)
        shutil.move(str(host.cold_file), str(target / host.cold_file.name))
        moved.append(host.cold_file.name)
    if moved:
        (target / 'slot.json').write_text(json.dumps(record, indent=1) + '\n', encoding='utf-8')
    record['history'].append({'at': stamp(now), 'event': 'archive', 'key': record.get('key'),
                              'archive': str(target) if moved else None})
    for field in ('key', 'land_dir', 'map', 'world', 'given_at', 'seconds', 'phase', 'voyage', 'refusal'):
        record.pop(field, None)
    record['state'] = 'FREE'
    write_slot(group, record)
    forget_build(host)
    return {'region': region_id, 'state': 'FREE', 'archived': moved, 'archive': str(target) if moved else None,
            'next': 'update-offline --region %s compiles the placeholder map again' % region_id}


def status(group):
    """Every slot's state, land and when it got it."""
    answer = {}
    for region in group['regions']:
        if region['kind'] != 'EXPEDITION':
            continue
        try:
            record = read_slot(group, region['id'])
        except (Refused, OSError, ValueError) as error:
            answer[region['id']] = {'state': 'DAMAGED', 'error': str(error)[:200]}
            continue
        entry = {'state': record['state']}
        if record['state'] == 'LAND':
            entry.update(key=record.get('key'), given_at=record.get('given_at'), map=record.get('map'),
                         land=record.get('world'), phase=record.get('phase'))
        if read_wish(group, WANTED, region['id']):
            entry['wanted'] = read_wish(group, WANTED, region['id']).get('key')
        answer[region['id']] = entry
    return answer


def land_map(group, region):
    """(map path, world summary) of the land an EXPEDITION slot holds, or None for a free slot."""
    record = read_slot(group, region['id'])
    if record['state'] != 'LAND':
        return None
    path = Path(record.get('map') or '')
    if not path.is_absolute() or not path.is_file():
        raise RuntimeError('slot %s land map %s is missing' % (region['id'], record.get('map')))
    return path, record.get('world') or {}


def place_world_file(group, region, path):
    """Write (or, for a free slot, remove) the slot world's WORLD_FILE in a region worktree.
    Returns the slot's land map path, or None."""
    target = Path(path) / WORLD_FILE
    held = land_map(group, region)
    if held is None:
        target.unlink(missing_ok=True)
        return None
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(held[1], indent=1) + '\n', encoding='utf-8')
    return held[0]


def load_template(path):
    try:
        template = json.loads(Path(path).read_text(encoding='utf-8-sig'))
    except (OSError, ValueError) as error:
        raise Refused('template: %s' % error)
    # The coordinator's /chart answer wraps a tile as {"template": {...}, ...}.
    if isinstance(template, dict) and isinstance(template.get('template'), dict):
        template = template['template']
    return template


# ---------------------------------------------------------------- opening lands for ships

def fail_wish(group, region_id, key, reason, now=None):
    """Tell the coordinator the land for key could not be opened in this slot."""
    write_wish(group, FAILED, region_id, {'region': region_id, 'key': key, 'reason': str(reason)[:300], 'at': stamp(now)})
    wish_file(group, WANTED, region_id).unlink(missing_ok=True)


def open_land(group, host, region_id, update, build=None, now=None):
    """The detached worker the host service starts for a wanted land: build it
    into the slot, then stage and install its build (update: shard_group's
    update_offline). The host service starts the slot once it is installed."""
    marker = wish_file(group, OPENING, region_id)
    wish = read_wish(group, WANTED, region_id)
    given = False
    try:
        if not wish or not isinstance(wish.get('template'), dict):
            raise Refused('no land is wanted in slot %s' % region_id)
        key = wish.get('key')
        give_land(group, host, region_id, wish['template'], key=key, build=build, now=now)
        given = True
        record = read_slot(group, region_id)
        record.update(phase='building', voyage=wish.get('voyage'), building_since=int(time.time() if now is None else now))
        write_slot(group, record)
        wish_file(group, WANTED, region_id).unlink(missing_ok=True)
        answer = update(group, region_id)
        if region_id in (answer.get('skipped') or {}):
            raise Refused('its build could not start: %s' % answer['skipped'][region_id])
        return {'region': region_id, 'key': key, 'phase': 'building'}
    except (Refused, OSError, ValueError, RuntimeError) as error:
        key = wish.get('key') if wish else None
        # Only free a land this call gave; a refusal from give_land means the slot held someone else's land.
        if given and read_slot(group, region_id)['state'] == 'LAND':
            try:
                archive(group, host, region_id, now=now)
            except (Refused, OSError) as again:
                error = '%s (and the slot could not be freed: %s)' % (error, again)
        fail_wish(group, region_id, key, error, now)
        return {'region': region_id, 'key': key, 'failed': str(error)[:300]}
    finally:
        marker.unlink(missing_ok=True)


def opening(group, region_id, now):
    """True while an open_land worker for the slot is (probably) running."""
    try:
        return now - wish_file(group, OPENING, region_id).stat().st_mtime < OPENING_STALE_SECONDS
    except OSError:
        return False

def prune_archives(group, now=None):
    """Deletes archived saves older than ARCHIVE_KEEP_SECONDS, with the land
    folder each was built from when no slot holds that land now. Returns the
    archive folder names deleted."""
    now = time.time() if now is None else now
    folder = slots_dir(group) / 'archive'
    if not folder.is_dir():
        return []
    held = set()
    for region in group['regions']:
        if region['kind'] == 'EXPEDITION' and slot_file(group, region['id']).exists():
            record = read_slot(group, region['id'])
            if record.get('land_dir'):
                held.add(str(Path(record['land_dir']).resolve()))
    lands = (slots_dir(group) / 'lands').resolve()
    gone = []
    for entry in sorted(folder.iterdir()):
        if not entry.is_dir() or now - entry.stat().st_mtime < ARCHIVE_KEEP_SECONDS:
            continue
        land = None
        try:
            land = json.loads((entry / 'slot.json').read_text(encoding='utf-8')).get('land_dir')
        except (OSError, ValueError, AttributeError):
            land = None
        shutil.rmtree(entry, ignore_errors=True)
        gone.append(entry.name)
        if land:
            land = Path(land).resolve()
            if land.parent == lands and str(land) not in held and land.is_dir():
                shutil.rmtree(land, ignore_errors=True)
    return gone


def serve(group, hosts, launch, now=None):
    """One host service pass over the expedition slots: open a wanted land in
    its slot (launch starts the open_land worker for a region id), then start
    a slot once its land's build is installed. hosts: (region, host) pairs.
    Returns what it did, by region."""
    now = time.time() if now is None else now
    done = {}
    try:
        pruned = prune_archives(group, now)
    except (OSError, Refused) as error:
        pruned = []
        done['archive'] = {'error': str(error)[:200]}
    if pruned:
        done['archive'] = {'deleted': pruned}
    for region, host in hosts:
        if region['kind'] != 'EXPEDITION':
            continue
        name = region['id']
        try:
            record = read_slot(group, name)
            gone = read_wish(group, ABANDONED, name)
            if gone:
                # The land was abandoned (or nobody came for 7 days): save, stop, archive, free.
                if host.lock.exists():
                    continue
                if host.frozen() or host.platform.listening(host.config['port']):
                    done[name] = {'stopping': host.request('stop')}
                    continue
                if record['state'] == 'LAND':
                    archive(group, host, name)
                wish_file(group, ABANDONED, name).unlink(missing_ok=True)
                done[name] = {'archived': gone.get('key')}
                continue
            wish = read_wish(group, WANTED, name)
            if wish and record['state'] == 'FREE':
                if opening(group, name, now) or host.lock.exists():
                    continue
                if host.platform.listening(host.config['port']):
                    # A free slot running its placeholder map is stopped first.
                    done[name] = {'stopping': host.request('stop')}
                    continue
                marker = wish_file(group, OPENING, name)
                marker.parent.mkdir(parents=True, exist_ok=True)
                marker.write_text(stamp(now) + '\n', encoding='utf-8')
                launch(name)
                done[name] = {'opening': wish.get('key')}
            elif wish and record['state'] == 'LAND' and not opening(group, name, now):
                fail_wish(group, name, wish.get('key'), 'the slot already holds land %s' % record.get('key'), now)
                done[name] = {'refused': wish.get('key')}
            elif record['state'] == 'LAND' and record.get('phase') == 'building':
                done[name] = start_when_built(group, host, record, now)
        except Refused as refusal:
            done[name] = {'waiting': str(refusal)[:200]}
        except (OSError, ValueError, RuntimeError) as error:
            done[name] = {'error': str(error)[:200]}
    return {k: v for k, v in done.items() if v}


def start_when_built(group, host, record, now):
    """A slot whose land is building: start it once the build is installed;
    give the land up (and tell the coordinator) when the build failed."""
    name = record['region']
    if host.lock.exists() or host.stage_lock.exists() or host.install_marker.exists():
        return None
    stage = host.read_json(host.stage_file) or {}
    problem = None
    if stage.get('phase') == 'failed':
        problem = 'its build failed: %s' % str(stage.get('error') or '')[:200]
    elif (host.read_state() or {}).get('action') == 'update' and (host.read_state() or {}).get('error'):
        problem = 'its build could not be installed: %s' % str(host.read_state()['error'])[:200]
    elif str(stage.get('install') or '').startswith('not installed'):
        problem = 'its build was %s' % stage['install']
    elif now - (record.get('building_since') or now) > BUILDING_GIVE_UP_SECONDS:
        problem = 'its build took too long'
    if problem:
        key = record.get('key')
        archive(group, host, name)
        fail_wish(group, name, key, problem, now)
        return {'failed': problem}
    if not host.built_revision():
        return None
    if not host.platform.listening(host.config['port']):
        host.request('start')
    record = read_slot(group, name)
    record['phase'] = 'started'
    record['history'].append({'at': stamp(now), 'event': 'started', 'key': record.get('key')})
    write_slot(group, record)
    return {'started': record.get('key')}
