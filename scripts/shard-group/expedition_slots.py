"""Expedition slots: regions of kind EXPEDITION that hold one generated land at a time.

A slot is FREE (no land; it runs its placeholder map if started) or holds a
LAND built from a world-chart template (docs/expedition-lands.md). Giving a
slot a land generates the map into the group root; the slot's next update
compiles it as the region's map (place_map in shard_group.py). Archiving moves
the slot's saved world aside and frees the slot for the next land. An archived
save (and the land it was built on) is kept 7 days so an admin can restore it
by hand, then deleted by the host service (prune_archives).

Slots are the lands awake at once, not the lands there are: an idle land is
parked (its save moved to <root>/expeditions/parked/<x>-<y>/, the slot freed)
and restored into whichever slot is free when a ship or a resident next needs
it. A parked land is never pruned; only the coordinator discards one.

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

from gaia_host import Refused, replace_file
import fresh_world

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

SLOT_SCHEMA = 'civ13-expedition-slot/1'
# What the slot world reads about its land (code/modules/persistence/expedition_land.dm).
WORLD_FILE = 'config/expedition_land.json'
# The land's hill levels, river currents and flood reaches (tools/procedural_maps/terrain_files.py),
# beside its map in the land folder and where the slot world reads them. The game finds the
# other two from the first name.
TERRAIN_FILES = (('land.heights.txt', 'config/expedition_heights.txt'),
                 ('land.flow.txt', 'config/expedition_heights.flow.txt'),
                 ('land.flood.txt', 'config/expedition_heights.flood.txt'))
# Move the same world-local state when a slot is archived, parked, or restored.
WORLD_PATHS = fresh_world.WORLD_PATHS + fresh_world.WORLD_DATA_PATHS
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
PARK = 'park'  # an idle land gives its slot up: the host parks it (by slot)
DISCARD = 'discard'  # a parked land given up for good: its folder goes to the archive (by land)
PARKED = 'parked'
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
    replace_file(temporary, path)


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
    replace_file(temporary, path)


def saved_world(path):
    """The world paths in a region folder that hold anything."""
    found = []
    for name in WORLD_PATHS:
        if name in fresh_world.WORLD_DATA_PATHS:
            fresh_world.safe_world_data_path(Path(path), name)
        folder = Path(path) / name
        if folder.is_dir() and any(folder.iterdir()):
            found.append(name)
    return found


def check_stopped(host):
    """Refuse unless the slot's world is stopped: not listening, not asleep, not waking.
    A slot asleep on disk (cold: it saved, then was shut down) is stopped."""
    if host.platform.listening(host.config['port']) or host.platform.listening(host.standby_port()):
        raise Refused('the slot is running; save and stop it first')
    cold = host.cold()
    for marker in (host.freeze_file, host.running_file):
        if marker.exists() and not (cold and marker == host.running_file):
            raise Refused('the slot is not explicitly stopped (%s remains); save and stop it first' % marker.name)


def parked_dir(group, key):
    """Where the land of chart tile key ("x,y") is kept while parked."""
    x, _, y = str(key).partition(',')
    if not (x.isdigit() and y.isdigit()):
        raise Refused('a parked land is named by its chart tile, X,Y')
    return slots_dir(group) / PARKED / ('%d-%d' % (int(x), int(y)))


def move_world(source, target):
    """Move the world paths that hold anything from source to target. Returns their names."""
    moved = []
    names = saved_world(source)
    for name in names:
        if name in fresh_world.WORLD_DATA_PATHS:
            fresh_world.safe_world_data_path(Path(target), name)
    for name in names:
        (target / name).parent.mkdir(parents=True, exist_ok=True)
        if (target / name).is_dir() and not any((target / name).iterdir()):
            (target / name).rmdir()
        shutil.move(str(Path(source) / name), str(target / name))
        moved.append(name)
    return moved


def free_slot(group, host, record):
    for field in ('key', 'land_dir', 'map', 'world', 'given_at', 'seconds', 'phase', 'voyage', 'refusal', 'building_since', 'restored'):
        record.pop(field, None)
    record['state'] = 'FREE'
    write_slot(group, record)
    forget_build(host)
    # A slot that slept on disk keeps its running mark; without the land the watchdog must not start it.
    host.running_file.unlink(missing_ok=True)


def park(group, host, region_id, now=None):
    """Move a stopped slot's land and saved world to the parked folder and free
    the slot. The land comes back, save and all, with restore."""
    expedition_region(group, region_id)
    check_stopped(host)
    record = read_slot(group, region_id)
    if record['state'] != 'LAND' or not record.get('key'):
        raise Refused('slot %s holds no land of the chart to park' % region_id)
    target = parked_dir(group, record['key'])
    if target.exists():
        raise Refused('land %s is already parked in %s' % (record['key'], target))
    moved = move_world(host.repo, target)
    target.mkdir(parents=True, exist_ok=True)  # a land can be parked before its first save
    host.cold_file.unlink(missing_ok=True)  # it starts from its save wherever it is restored
    kept = {field: record.get(field) for field in ('key', 'land_dir', 'map', 'world', 'given_at', 'seconds')}
    (target / 'slot.json').write_text(json.dumps(dict(kept, parked_at=stamp(now), parked_from=region_id), indent=1) + '\n',
                                      encoding='utf-8')
    record['history'].append({'at': stamp(now), 'event': 'park', 'key': record['key'], 'parked': str(target)})
    key = record['key']
    free_slot(group, host, record)
    return {'region': region_id, 'state': 'FREE', 'parked': key, 'moved': moved, 'folder': str(target)}


def restore(group, host, region_id, key, now=None):
    """Give a FREE, stopped slot the parked land of chart tile key, with its
    saved world. The slot's next update compiles the land."""
    expedition_region(group, region_id)
    check_stopped(host)
    record = read_slot(group, region_id)
    if record['state'] != 'FREE':
        raise Refused('slot %s already holds land %s' % (region_id, record.get('key')))
    held = saved_world(host.repo)
    if held:
        raise Refused('slot %s still holds a saved world (%s); archive it first' % (region_id, ', '.join(held)))
    source = parked_dir(group, key)
    try:
        kept = json.loads((source / 'slot.json').read_text(encoding='utf-8'))
    except (OSError, ValueError):
        raise Refused('no parked land %s' % key)
    if not isinstance(kept, dict) or kept.get('key') != key or not Path(str(kept.get('map') or '')).is_file():
        raise Refused('parked land %s is damaged (%s); fix it by hand' % (key, source))
    moved = move_world(source, host.repo)
    host.cold_file.unlink(missing_ok=True)
    # A new placement: the slot's transfer agent adopts this land's save history (region.py reconcile_load).
    world = dict(kept.get('world') or {}, placed='%s@%s' % (region_id, stamp(now)))
    record.update(state='LAND', key=key, land_dir=kept.get('land_dir'), map=kept['map'], world=world,
                  given_at=kept.get('given_at'), seconds=kept.get('seconds'), restored=True)
    record['history'].append({'at': stamp(now), 'event': 'restore', 'key': key, 'moved': moved})
    write_slot(group, record)
    forget_build(host)
    shutil.rmtree(source, ignore_errors=True)
    return {'region': region_id, 'state': 'LAND', 'key': key, 'restored': moved, 'map': record['map']}


def discard_parked(group, key, now=None):
    """A parked land given up for good: its folder goes to the archive, to be
    pruned like any archived land. Returns the archive folder or None."""
    source = parked_dir(group, key)
    if not source.is_dir():
        return None
    target = unused(slots_dir(group) / 'archive', 'parked-%s-%s' % (source.name, stamp(now)))
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(source), str(target))
    os.utime(target, (time.time() if now is None else now,) * 2)
    return target


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
    # placed: the slot's transfer agent tells one land's saves from the next by it (region.py reconcile_load).
    record.update(state='LAND', key=key, land_dir=str(out), map=str(out / 'land.dmm'),
                  world=dict(world_summary(report), placed='%s@%s' % (region_id, stamp(now))),
                  given_at=stamp(now), seconds=report.get('seconds'))
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
    moved = move_world(host.repo, target)
    if host.cold_file.exists():  # a slot saved and evicted: its cold record goes with its save
        target.mkdir(parents=True, exist_ok=True)
        shutil.move(str(host.cold_file), str(target / host.cold_file.name))
        moved.append(host.cold_file.name)
    if moved:
        (target / 'slot.json').write_text(json.dumps(record, indent=1) + '\n', encoding='utf-8')
    record['history'].append({'at': stamp(now), 'event': 'archive', 'key': record.get('key'),
                              'archive': str(target) if moved else None})
    free_slot(group, host, record)
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


def parked(group):
    """Every parked land: chart tile -> when it was parked and from which slot."""
    folder = slots_dir(group) / PARKED
    answer = {}
    for entry in sorted(folder.iterdir()) if folder.is_dir() else ():
        try:
            kept = json.loads((entry / 'slot.json').read_text(encoding='utf-8'))
            answer[str(kept['key'])] = {'parked_at': kept.get('parked_at'), 'from': kept.get('parked_from')}
        except (OSError, ValueError, KeyError, TypeError):
            answer[entry.name] = {'error': 'damaged'}
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
    """Write (or, for a free slot, remove) the slot world's WORLD_FILE and its land's
    terrain files in a region worktree. Returns the slot's land map path, or None."""
    target = Path(path) / WORLD_FILE
    held = land_map(group, region)
    for name, place in TERRAIN_FILES:
        source = held[0].parent / name if held else None
        if source is not None and source.is_file():
            (Path(path) / place).parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, Path(path) / place)
        else:  # a free slot, or a land made before lands had them: the world is flat
            (Path(path) / place).unlink(missing_ok=True)
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

def fail_wish(group, region_id, key, reason, now=None, parked=False):
    """Tell the coordinator the land for key could not be opened in this slot.
    parked: it was a parked land, and is parked still."""
    write_wish(group, FAILED, region_id, {'region': region_id, 'key': key, 'reason': str(reason)[:300], 'at': stamp(now),
                                          'parked': bool(parked)})
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
        if wish.get('parked'):
            restore(group, host, region_id, key, now=now)
        else:
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
                # A restored land goes back to the parked folder: it is somebody's, never archived for a failed build.
                (park if wish.get('parked') else archive)(group, host, region_id, now=now)
            except (Refused, OSError) as again:
                error = '%s (and the slot could not be freed: %s)' % (error, again)
        fail_wish(group, region_id, key, error, now, parked=bool(wish and wish.get('parked')))
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
    # Parked lands the coordinator gave up for good (nobody settled them, nobody came for 7 days).
    folder = slots_dir(group) / DISCARD
    for wish in sorted(folder.glob('*.json')) if folder.is_dir() else ():
        try:
            key = (json.loads(wish.read_text(encoding='utf-8')) or {}).get('key')
            moved = discard_parked(group, key, now)
            wish.unlink(missing_ok=True)
            done.setdefault('discarded', []).append({'key': key, 'archive': str(moved) if moved else None})
        except (OSError, ValueError, AttributeError, Refused) as error:
            done.setdefault('discard_errors', []).append(str(error)[:200])
    for region, host in hosts:
        if region['kind'] != 'EXPEDITION':
            continue
        name = region['id']
        try:
            record = read_slot(group, name)
            idle = read_wish(group, PARK, name)
            if idle and not read_wish(group, ABANDONED, name):
                # An idle land gives its slot to another: save, stop, park, free. Somebody
                # there again (a ship that was already under way) calls the parking off.
                if host.lock.exists():
                    continue
                if record['state'] != 'LAND' or record.get('key') != idle.get('key') or record.get('phase') == 'building':
                    wish_file(group, PARK, name).unlink(missing_ok=True)
                    done[name] = {'park_dropped': idle.get('key')}
                    continue
                if host.platform.listening(host.config['port']) and not host.frozen():
                    world = host.world() or {}
                    if world.get('clients'):
                        # The coordinator finds the wish gone and the land still here: called off.
                        wish_file(group, PARK, name).unlink(missing_ok=True)
                        done[name] = {'park_called_off': idle.get('key')}
                        continue
                if host.frozen() or host.platform.listening(host.config['port']):
                    done[name] = {'stopping': host.request('stop')}
                    continue
                park(group, host, name, now=now)
                wish_file(group, PARK, name).unlink(missing_ok=True)
                done[name] = {'parked': idle.get('key')}
                continue
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
                fail_wish(group, name, wish.get('key'), 'the slot already holds land %s' % record.get('key'), now,
                          parked=bool(wish.get('parked')))
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
        # A restored land is somebody's: back to the parked folder, never the archive.
        (park if record.get('restored') else archive)(group, host, name)
        fail_wish(group, name, key, problem, now, parked=bool(record.get('restored')))
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
