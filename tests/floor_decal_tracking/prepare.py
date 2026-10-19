"""Freeze source-bound decal/serializer fixtures. Preparation never runs BYOND."""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
BASE = 'cc03b199128f8afed58713912c551ad7556e6bc4'
DECAL = 'code/game/turfs/flooring/floor_decal.dm'
SEASONS = 'code/modules/1713/roundstart_etc.dm'
GUARD = '\t\tif (!T.floor_decal_cache_keys) T.floor_decal_cache_keys = list()\n'
DECLARATION = '/turf/var/list/floor_decal_cache_keys\n'
CASES = ('fixed', 'eager', 'missing-lazy', 'shared')


def once(source, before, after):
    if source.count(before) != 1:
        raise ValueError(f'Expected one source anchor: {before!r}')
    return source.replace(before, after, 1)


def sources(root=ROOT, case='fixed'):
    if case not in CASES:
        raise ValueError('Unknown case')
    hashes = {}

    def read(path):
        raw = (root / path).read_bytes()
        hashes[path] = hashlib.sha256(raw).hexdigest()
        return raw.decode('utf-8').replace('\r\n', '\n')

    decal = read(DECAL)
    # Exact production prefix contains declarations, initialize and reset; all
    # cosmetic subclasses after reset/initialize are unnecessary to this probe.
    end = '/obj/effect/floor_decal/ex_act(severity)\n'
    if decal.count(end) != 1:
        raise ValueError('Missing decal extraction boundary')
    decal = decal.split(end)[0]
    if DECLARATION not in decal or decal.count(GUARD) != 1:
        raise ValueError('Lazy production anchors changed')
    if case == 'eager':
        decal = once(decal, DECLARATION, DECLARATION.rstrip() + ' = list()\n')
    elif case == 'missing-lazy':
        decal = once(decal, GUARD, '')
    elif case == 'shared':
        decal = 'var/list/fixture_shared_keys = list()\n' + once(
            decal, GUARD, GUARD.replace('= list()', '= fixture_shared_keys'))

    seasons = read(SEASONS)
    start = '\t\tif (G.season != "SPRING" && G.uses_winter_overlay)\n'
    stop = '\n//\t\tspawn (0)'
    if seasons.count(start) != 1 or seasons.count(stop) != 1:
        raise ValueError('Seasonal production anchors changed')
    block = seasons.split(start)[1].split(stop)[0]
    seasonal = '/proc/fixture_season(turf/G)\n' + '\n'.join(
        line[1:] if line.startswith('\t') else line
        for line in (start + block).rstrip().split('\n')) + '\n'

    files = {'decal.dm': decal, 'seasonal.dm': seasonal}
    flooring = read('code/game/turfs/floor.dm')
    start = '/turf/floor/proc/make_plating(var/place_product, var/defer_icon_update)\n'
    stop = '/turf/floor/levelupdate()\n'
    if flooring.count(start) != 1 or flooring.count(stop) != 1:
        raise ValueError('Floor cleanup extraction anchors changed')
    files['cleanup.dm'] = start + flooring.split(start)[1].split(stop)[0]
    environment = read('tests/world_save/roundtrip.dme')
    removed = {'roundtrip.dm', 'transfers.dm', 'player_reclaim_probe.dm', 'round_metadata.dm'}
    # Freeze every standard world-save fixture dependency, not live include paths.
    def include(match):
        name = match.group(1)
        if name in removed:
            return ''
        path = (root / 'tests/world_save' / name).resolve().relative_to(root.resolve()).as_posix()
        target = 'source/' + path
        files[target] = read(path)
        return f'#include "{target}"'
    environment = re.sub(r'^#include "([^"]+)"', include, environment, flags=re.M)
    environment = once(environment, '#define FILE_DIR "../.."', '#define FILE_DIR "__FIXTURE_RESOURCE_ROOT__"')
    environment += '\n#define TURF_LAYER 2\n#include "decal.dm"\n#include "seasonal.dm"\n#include "cleanup.dm"\n#include "probe.dm"\n'
    files['probe.dme'] = environment
    files['probe.dm'] = read('tests/floor_decal_tracking/probe.dm')
    return files, hashes


def prepare(output, root=ROOT):
    output.mkdir(parents=True, exist_ok=False)
    manifest = {'base': BASE, 'native_executed': False, 'compiler_executed': False,
                'cases': {}, 'source_sha256': {}}
    for case in CASES:
        files, hashes = sources(root, case)
        files['probe.dme'] = once(files['probe.dme'], '__FIXTURE_RESOURCE_ROOT__',
                                  (output.resolve() / case).as_posix())
        manifest['source_sha256'] = hashes
        entries = {}
        for name, text in files.items():
            path = output / case / name
            path.parent.mkdir(parents=True, exist_ok=True)
            raw = text.encode('utf-8')
            path.write_bytes(raw)
            entries[name] = hashlib.sha256(raw).hexdigest()
        for resource in ('icons/turf/floors.dmi', 'icons/turf/flooring/decals.dmi'):
            raw = (root / resource).read_bytes()
            path = output / case / resource
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
            entries[resource] = hashlib.sha256(raw).hexdigest()
            manifest['source_sha256'][resource] = entries[resource]
        manifest['cases'][case] = entries
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    print(json.dumps(prepare(args.output), indent=2))
