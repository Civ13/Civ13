"""Expedition slots: regions of kind EXPEDITION that hold one generated land at a time.

A slot is FREE (no land; it runs its placeholder map if started) or holds a
LAND built from a world-chart template (docs/expedition-lands.md). Giving a
slot a land generates the map into the group root; the slot's next update
compiles it as the region's map (place_map in shard_group.py). Archiving moves
the slot's saved world aside and frees the slot for the next land. Nothing is
ever deleted: lands and archived saves stay under <root>/expeditions/.

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
    for field in ('key', 'land_dir', 'map', 'world', 'given_at', 'seconds'):
        record.pop(field, None)
    record['state'] = 'FREE'
    write_slot(group, record)
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
                         land=record.get('world'))
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
