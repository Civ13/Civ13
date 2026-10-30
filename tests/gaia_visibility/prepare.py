"""Stage an immutable full-source Gaia visibility packet. Never compile or launch."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[2]
SELF = 'tests/gaia_visibility/prepare.py'
FIXTURE = 'tests/gaia_visibility/fixture.dm'
CONTROLS = ('native-los', 'white-root', 'double-offset')


def git(repo, *args):
    return subprocess.check_output(['git', '-C', str(repo), *args])


def sha(data):
    return hashlib.sha256(data).hexdigest()


def scene():
    definitions = {
        'a': '/turf/floor/grass,/area/caribbean/nomads/forest',
        'm': '/obj/map_metadata/nomads/gaia,/turf/floor/grass,/area/caribbean/nomads/forest',
        't': '/obj/structure/wild/tree/live_tree,/turf/floor/grass,/area/caribbean/nomads/forest',
        'p': '/obj/structure/wild/tree/live_tree/pine,/turf/floor/grass,/area/caribbean/nomads/forest',
        's': '/obj/structure/wild/tree/live_tree/pine/snow,/turf/floor/winter/grass,/area/caribbean/nomads/forest',
        'j': '/obj/structure/wild/jungle,/turf/floor/grass,/area/caribbean/nomads/forest',
        'l': '/obj/structure/wild/palm,/turf/floor/grass,/area/caribbean/nomads/forest',
        'c': '/obj/structure/wild/tallgrass,/obj/structure/wild/rock,/turf/floor/grass,/area/caribbean/nomads/forest',
        'd': '/obj/structure/simple_door,/turf/floor/grass,/area/caribbean/nomads/forest',
        'r': '/obj/roof,/turf/floor/grass,/area/caribbean/nomads/forest',
        'w': '/turf/wall,/area/caribbean/nomads/forest',
    }
    out = [f'"{key}" = ({value})' for key, value in definitions.items()]
    for z in (1, 2):
        cells = [['a'] * 48 for _ in range(48)]
        def put(x, y, key):
            cells[48-y][x-1] = key
        if z == 1:
            put(2, 2, 'm')
        for index, (x, y) in enumerate(( (x,y) for y in (20,24,28) for x in (20,23,26,29) )):
            put(x, y, ('t','p','j','l','s')[index % 5])
        for x in range(18, 31):
            put(x, 18, 'c')
        for y in range(21, 28):
            put(33, y, 'd' if y == 24 else 'w')
        put(38, 24, 'r')
        out.append(f'\n(1,1,{z}) = {{"\n' + '\n'.join(''.join(row) for row in cells) + '\n"}')
    return ('\n'.join(out) + '\n').encode()


def change_once(data, before, after):
    if data.count(before) != 1:
        raise ValueError('negative-control anchor drift')
    return data.replace(before, after)


def prepare(output, head, *, control=None, repo=ROOT):
    if not re.fullmatch(r'[0-9a-f]{40}', head):
        raise ValueError('head must be an immutable full lowercase commit SHA')
    if control is not None and control not in CONTROLS:
        raise ValueError('unknown control')
    resolved = git(repo, 'rev-parse', '--verify', head + '^{commit}').decode().strip()
    if resolved != head:
        raise ValueError('head does not identify that exact commit')
    # Both fixture and staging algorithm must belong to the recorded candidate.
    committed_tool = git(repo, 'show', head + ':' + SELF)
    if committed_tool != Path(__file__).read_bytes():
        raise ValueError('prepare.py is not the exact candidate version; commit it first')
    output = Path(output).absolute()
    if output.exists() or output.is_symlink():
        raise FileExistsError(output)
    # The asset tree is large: archive to a temporary disk file, then copy and
    # hash in bounded chunks. Only the DME and explicit mutations enter RAM.
    with tempfile.TemporaryFile() as archive:
        subprocess.run(['git', '-C', str(repo), 'archive', '--format=tar', head], stdout=archive, check=True)
        archive.seek(0)
        with tarfile.open(fileobj=archive, mode='r:') as tar:
            members = {}
            for member in tar:
                name = PurePosixPath(member.name)
                if name.is_absolute() or '..' in name.parts:
                    raise ValueError('unsafe archive path')
                if member.isdir():
                    continue
                if not member.isfile():
                    raise ValueError('links/special files are not admitted')
                members[str(name)] = member

            def read_small(name):
                member = members.get(name)
                if member is None:
                    raise ValueError('missing committed dependency: ' + name)
                if member.size > 8 * 1024 * 1024:
                    raise ValueError('unexpectedly large source input: ' + name)
                return tar.extractfile(member).read()

            read_small(FIXTURE)
            version = json.loads(read_small('tools/byond/version.json'))['version']
            dme = read_small('civ13.dme').decode()
            begin, end = '// BEGIN_SELECTED_MAP', '// END_SELECTED_MAP'
            if dme.count(begin) != 1 or dme.count(end) != 1:
                raise ValueError('selected-map boundary drift')
            a, b = dme.index(begin), dme.index(end) + len(end)
            dme = dme[:a] + '#include "tests/gaia_visibility/scene.dmm"' + dme[b:]
            prefix = '#define GAIA_VISIBILITY_FIXTURE_BUILD\n'
            updates = {}
            if control == 'native-los':
                prefix += '#define CIV13_GEOMETRIC_LOS_CORE 0\n#define CIV13_ROOT_TREE_PRESENTATION 0\n'
            elif control == 'white-root':
                path = 'code/modules/visibility/root_light_snapshot.dm'
                anchor = b'/proc/root_light_rgb(turf/root, mob/viewer)\n'
                updates[path] = change_once(read_small(path), anchor, anchor + b'\treturn "#ffffff" // prepared causal control only\n')
            elif control == 'double-offset':
                path = 'code/modules/visibility/root_tree_presenter.dm'
                updates[path] = change_once(read_small(path), b'\tI.pixel_x = 0\n', b'\tI.pixel_x = T.pixel_x\n')
            updates['gaia_visibility.dme'] = (prefix + dme + '\n#include "' + FIXTURE + '"\n').encode()
            updates['tests/gaia_visibility/scene.dmm'] = scene()
            # Validate all paths and control anchors before creating destination.
            output.mkdir(parents=True, exist_ok=False)
            hashes = {}
            for name, member in members.items():
                target = output / name
                target.parent.mkdir(parents=True, exist_ok=True)
                digest = hashlib.sha256()
                with tar.extractfile(member) as source, target.open('wb') as sink:
                    while chunk := source.read(1024 * 1024):
                        digest.update(chunk)
                        sink.write(chunk)
                hashes[name] = {'original_sha256': digest.hexdigest(), 'prepared_sha256': digest.hexdigest()}
            for name, data in updates.items():
                target = output / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
                hashes.setdefault(name, {'original_sha256': None})['prepared_sha256'] = sha(data)
    manifest = {
        'schema': 1, 'head': head, 'control': control,
        'scope': 'preparation_only_full_game_startup_NOT_admitted_for_execution',
        'compiled': False, 'executed': False, 'client_pixel_evidence': False,
        'toolchain': version,
        'entrypoint': 'gaia_visibility.dme',
        'scene': {'width': 48, 'height': 48, 'levels': 2, 'roots_per_level': 12, 'real_clients_required': 3},
        'files': dict(sorted(hashes.items())),
    }
    (output / 'gaia-visibility-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')

    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--head', required=True)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--control', choices=CONTROLS)
    args = parser.parse_args()
    result = prepare(args.output, args.head, control=args.control)
    print(json.dumps({key: result[key] for key in ('head', 'control', 'scope', 'compiled', 'executed')}))
