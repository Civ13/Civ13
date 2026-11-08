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
"""
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

MAP_ID = re.compile(r'^[A-Za-z0-9_]{1,64}$')
MAP_BLOCK = re.compile(r'// BEGIN_SELECTED_MAP\r?\n.*?// END_SELECTED_MAP', re.S)
DMB_SLOTS = ('region.dmb', 'region.b.dmb')
BUILD_SECONDS = 1800


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
    if not MAP_BLOCK.search(dme_text):
        raise RuntimeError('region.dme has no selected-map block')
    newline = '\r\n' if '\r\n' in dme_text else '\n'
    block = '// BEGIN_SELECTED_MAP' + newline + '#include "' + include + '"' + newline + '// END_SELECTED_MAP'
    return MAP_BLOCK.sub(lambda _: block, dme_text, count=1)


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
    code, out = runner([compiler, '-max_errors', '0', 'region.dme'], build, BUILD_SECONDS)
    if code != 0 or not (build / 'region.dmb').exists():
        raise RuntimeError('compile failed: ' + out.strip()[-300:])
    slot = live_slot(region_path)
    install(build / 'region.rsc', region_path / slot.replace('.dmb', '.rsc'))
    install(build / 'region.dmb', region_path / slot)
    return include


def main(argv):
    if len(argv) != 2:
        print('usage: battle_mapswap.py MAP_ID')
        return 2
    region_path = Path.cwd()
    map_id = argv[1]
    write_state(region_path, state='building', map=map_id)
    try:
        include = rotate(region_path, map_id)
    except Exception as error:  # the world reads failed and reboots on the map it has
        write_state(region_path, state='failed', map=map_id, error=str(error)[-300:])
        print('Map rotation failed: %s' % error)
        return 1
    write_state(region_path, state='ready', map=map_id, include=include)
    print('Map rotation ready: %s' % include)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
