"""Build the next voted map for a TDM battle region (shard kind BATTLE).

The battle world runs this from its own worktree when its map vote ends
(code/modules/tdm_barracks/battle.dm):

    python3 scripts/shard-group/battle_mapswap.py MAP_ID

It compiles region.dme with MAP_ID selected in a second worktree,
<root>/.rotation/<region>, at the region's own commit, then swaps the new
region.dmb/region.rsc into the region's live build slot by rename, so the
running world keeps its open files. The world's next reboot loads the new map.
Progress is in data/shard-host/rotation.json: state building, ready or failed;
the world holds its reboot while it reads building.

Settings come from config/shard_build.json, which shard_group.py setup writes.

Between rounds the battle also takes the latest update (Val, 2026-11-18: civ13.com's TDM
servers update between every round when able to). When the group has update_when_empty
on (the default) and its revision has moved past the world's, the next map is built at
that revision instead, the region's worktree is moved onto it and the new build goes into
the live slot, so the reboot at the end of the round starts the new code. A fetch or
compile that fails falls back to the map alone at the old revision, and a revision whose
build failed is not tried again (data/shard-host/round-update.json).

    python3 scripts/shard-group/battle_mapswap.py --update

builds only the update, keeping the current map, for a round that ended without a vote.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from shard_map_selection import select_map_block  # noqa: E402

MAP_ID = re.compile(r'^[A-Za-z0-9_]{1,64}$')
HEX40 = re.compile(r'^[0-9a-f]{40}$')
DMB_SLOTS = ('region.dmb', 'region.b.dmb')
BUILD_SECONDS = 1800
# How long the update waits for another region's compile (a barracks building its own
# update) before the round gives up on it and builds the map alone.
COMPILE_SLOT_SECONDS = 600


def find_map(maps_dir, map_id):
    """The .dmm for a map id, as scripts/mapswap.py picks it: exact name first, then a partial match."""
    wanted = map_id.lower() + '.dmm'
    files = sorted(p for p in Path(maps_dir).rglob('*.dmm') if p.is_file())
    for path in files:
        if path.name.lower() == wanted:
            return path
    for path in files:
        if wanted in path.name.lower():
            return path
    return None


def select_map(dme_text, include):
    return select_map_block(dme_text, include, 'region.dme')


def live_slot(region_path):
    try:
        record = json.loads((region_path / 'data' / 'shard-host' / 'build.json').read_text(encoding='utf-8'))
    except (OSError, ValueError):
        record = {}
    name = record.get('file') if isinstance(record, dict) else None
    return name if name in DMB_SLOTS else DMB_SLOTS[0]


def install(source, target):
    """Copy beside the target, then rename over it: a running world keeps its open file."""
    temporary = target.with_name(target.name + '.new')
    shutil.copyfile(source, temporary)
    os.replace(temporary, target)


def compiled(code, out, dmb, before):
    """Whether a compile produced dmb. DreamMaker 516.1688 can crash on exit ("double free
    or corruption") after it saved a clean build, so a non-zero exit still counts when the
    output reports the saved .dmb with 0 errors and the file is new."""
    try:
        after = dmb.stat().st_mtime_ns
    except OSError:
        return False
    if after == before:
        return False
    return code == 0 or bool(re.search(r'\.dmb - 0 errors', out or ''))


def mtime(path):
    try:
        return path.stat().st_mtime_ns
    except OSError:
        return None


def run(command, cwd, timeout):
    done = subprocess.run(command, cwd=str(cwd), stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                          universal_newlines=True, timeout=timeout)
    return done.returncode, done.stdout or ''


def write_state(region_path, **state):
    state['time'] = int(time.time())
    folder = region_path / 'data' / 'shard-host'
    folder.mkdir(parents=True, exist_ok=True)
    temporary = folder / 'rotation.json.new'
    temporary.write_text(json.dumps(state) + '\n', encoding='utf-8')
    os.replace(temporary, folder / 'rotation.json')


def rotate(region_path, map_id, runner=run):
    """Build map_id for the region at region_path and install it. Returns the installed map path."""
    if not MAP_ID.match(map_id or ''):
        raise RuntimeError('invalid map id')
    settings = json.loads((region_path / 'config' / 'shard_build.json').read_text(encoding='utf-8'))
    git, compiler = settings['git'], settings['compiler']
    region_id = settings['region']
    if not re.match(r'^[a-z0-9_-]{1,32}$', region_id):
        raise RuntimeError('invalid region id')
    found = find_map(region_path / 'maps', map_id)
    if not found:
        raise RuntimeError('no map named %s' % map_id)
    include = str(found.relative_to(region_path)).replace('/', '\\')
    code, out = runner([git, 'rev-parse', 'HEAD'], region_path, 60)
    revision = out.strip().splitlines()[-1] if code == 0 and out.strip() else ''
    if not re.match(r'^[0-9a-f]{40}$', revision):
        raise RuntimeError('could not read the region commit')
    build = Path(settings['root']) / '.rotation' / region_id
    if not (build / '.git').exists():
        build.parent.mkdir(parents=True, exist_ok=True)
        code, out = runner([git, 'worktree', 'add', '--force', '--detach', str(build), revision], region_path, 600)
    else:
        code, out = runner([git, 'checkout', '--force', '--detach', revision], build, 600)
    if code != 0:
        raise RuntimeError('checkout failed: ' + out.strip()[-300:])
    with open(region_path / 'region.dme', encoding='utf-8', newline='') as handle:
        dme = handle.read()
    (build / 'region.dme').write_text(select_map(dme, include), encoding='utf-8', newline='')
    before = mtime(build / 'region.dmb')
    code, out = runner([compiler, '-max_errors', '0', 'region.dme'], build, BUILD_SECONDS)
    if not compiled(code, out, build / 'region.dmb', before):
        raise RuntimeError('compile failed: ' + out.strip()[-300:])
    slot = live_slot(region_path)
    install(build / 'region.rsc', region_path / slot.replace('.dmb', '.rsc'))
    install(build / 'region.dmb', region_path / slot)
    return include


# -- the update between rounds ---------------------------------------------------
def shard_group_module():
    import shard_group
    return shard_group


def region_host(region_path, sg=None):
    """The region's host (data/shard-host/host.json, written by setup), or None."""
    try:
        config = json.loads((region_path / 'data' / 'shard-host' / 'host.json').read_text(encoding='utf-8'))
    except (OSError, ValueError):
        return None
    if not isinstance(config, dict) or not config.get('group_config'):
        return None
    return (sg or shard_group_module()).RegionHost(config)


def read_json(path):
    try:
        value = json.loads(path.read_text(encoding='utf-8'))
    except (OSError, ValueError):
        return None
    return value if isinstance(value, dict) else None


def record_update(region_path, **values):
    values['time'] = int(time.time())
    folder = region_path / 'data' / 'shard-host'
    folder.mkdir(parents=True, exist_ok=True)
    temporary = folder / 'round-update.json.new'
    temporary.write_text(json.dumps(values) + '\n', encoding='utf-8')
    os.replace(temporary, folder / 'round-update.json')


def update_revision(region_path, host, runner):
    """The revision to move onto this round, or None: updates off, nothing new, never
    backwards, or a revision whose build already failed."""
    if not host.update_when_empty():
        return None
    git = host.config['git']
    code, out = runner([git, 'rev-parse', 'HEAD'], region_path, 60)
    current = out.strip().splitlines()[-1] if code == 0 and out.strip() else ''
    latest = host.latest_revision()  # fetches the group's remote
    if not HEX40.match(current) or not HEX40.match(latest or '') or latest == current:
        return None
    code, _ = runner([git, 'merge-base', '--is-ancestor', current, latest], region_path, 60)
    if code != 0:
        return None  # the world runs something newer than the group revision (set by hand)
    last = read_json(region_path / 'data' / 'shard-host' / 'round-update.json') or {}
    if last.get('phase') == 'failed' and last.get('revision') == latest:
        return None
    return latest


def rotate_onto_update(region_path, map_id, host, sg=None, runner=None):
    """Build the next map (map_id, or the current one when None) at the latest revision
    and install it with the worktree moved onto that revision. Returns the include, or
    None when there is no update to take."""
    sg = sg or shard_group_module()
    runner = runner or run
    revision = update_revision(region_path, host, runner)
    if not revision:
        return None
    try:
        group = sg.load_group(host.config['group_config'])
        region = next(r for r in group['regions'] if r['id'] == host.config['region'])
        git, compiler = host.config['git'], host.config['compiler']
        build = Path(group['root']) / '.rotation' / region['id']
        if not (build / '.git').exists():
            build.parent.mkdir(parents=True, exist_ok=True)
            code, out = runner([git, 'worktree', 'add', '--force', '--detach', str(build), revision], region_path, 600)
            if code != 0:
                raise RuntimeError('rotation worktree failed: ' + out.strip()[-300:])
        with host.group_slot('compile.lock', 'compile', lambda **values: None, COMPILE_SLOT_SECONDS):
            # The region's rotation.json names the voted map, so place_map picks it here too.
            sg.prepare_tree(group, region, build, revision, host.platform, git)
            include = sg.place_map(group, region, build)
            if map_id:
                found = find_map(build / 'maps', map_id)
                if not found or str(found.relative_to(build)).replace('/', '\\') != include:
                    raise RuntimeError('map %s is not in the update' % map_id)
            before = mtime(build / 'region.dmb')
            code, out = runner([compiler, '-max_errors', '0', 'region.dme'], build, BUILD_SECONDS)
            if not compiled(code, out, build / 'region.dmb', before):
                raise RuntimeError('compile failed: ' + out.strip()[-300:])
        # The running world keeps its loaded build; its reboot loads the new one beside the
        # source it was built from.
        if group.get('persistent'):
            host.require_mainland_update_ready(group, revision)
        sg.prepare_tree(group, region, region_path, revision, host.platform, git, live=True)
        slot = live_slot(region_path)
        install(build / 'region.rsc', region_path / slot.replace('.dmb', '.rsc'))
        install(build / 'region.dmb', region_path / slot)
        host.record_build(revision, slot)
        host.write_server_build(revision)
    except Exception as error:
        record_update(region_path, phase='failed', revision=revision, error=str(error)[-300:])
        raise
    record_update(region_path, phase='installed', revision=revision)
    return include


def previous_map(region_path):
    """The map the world was built with by the last rotation, or None (its configured map)."""
    state = read_json(region_path / 'data' / 'shard-host' / 'rotation.json') or {}
    map_id = state.get('map') if state.get('state') in ('ready', 'building') else None
    return map_id if type(map_id) is str and MAP_ID.match(map_id) else None


def main(argv):
    if len(argv) != 2:
        print('usage: battle_mapswap.py MAP_ID | --update')
        return 2
    region_path = Path.cwd()
    update_only = argv[1] == '--update'
    map_id = previous_map(region_path) if update_only else argv[1]
    if map_id:
        write_state(region_path, state='building', map=map_id)
    else:
        write_state(region_path, state='building')
    include = None
    try:
        host = region_host(region_path)
        if host:
            include = rotate_onto_update(region_path, map_id, host)
    except Exception as error:  # the map alone, at the old revision
        print('Update between rounds failed: %s' % error)
    if include:
        print('Update between rounds installed')
    elif update_only:
        if map_id:
            write_state(region_path, state='ready', map=map_id)
        else:
            write_state(region_path, state='current')
        print('No update to take')
        return 0
    else:
        try:
            include = rotate(region_path, map_id)
        except Exception as error:  # the world reads failed and reboots on the map it has
            write_state(region_path, state='failed', map=map_id, error=str(error)[-300:])
            print('Map rotation failed: %s' % error)
            return 1
    if map_id:
        write_state(region_path, state='ready', map=map_id, include=include)
    else:
        write_state(region_path, state='current', include=include)
    print('Map rotation ready: %s' % include)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
