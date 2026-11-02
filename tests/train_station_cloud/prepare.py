"""Offline only: reproduce exact Git bytes and deterministic native fixture inputs."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

PIN = 'ec86e58fa67fdd7baea265d8716a64ae6f9a2d99'
PATHS = ('AGENTS.md', 'CODEX.md', 'code/modules/1713/trains.dm',
         'config/crafting/material_recipes_global.txt', 'icons/obj/vehicles/trains.dmi',
         'icons/obj/vehicles/train_lever.dmi', 'tools/byond/version.json',
         'scripts/byond_toolchain.py', 'scripts/byond_runtime.py',
         'tests/world_save/current_runtime.py', '.github/workflows/train-collision.yml',
         'tests/train_collision/run.sh', 'tests/train_collision/fixture.dm',
         '.github/workflows/wildlife-cardinal-cadence.yml')


def record(data):
    return {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}


def production_bytes(raw):
    """Rail/lever/base movement and locomotive scheduler; no algorithm rewrites.

    The storage/cargo UI, fuel-loading UI and examination methods are excluded.
    Audio file literals become null; playsound itself is an inert fixture seam.
    Actual train sprite resources remain unchanged.
    """
    import re
    text = raw.decode('utf-8')
    first, rest = text.split('/obj/structure/trains/storage\n', 1)
    loco = '/obj/structure/trains/locomotive\n' + rest.split('/obj/structure/trains/locomotive\n', 1)[1]
    loco = loco.split('/obj/structure/trains/locomotive/examine(', 1)[0]
    return re.sub(r"'sound/[^']+'", 'null', first + loco).encode('utf-8')


def prepare(repo, out):
    out.mkdir(parents=True, exist_ok=False)
    git = ['git', '-c', 'safe.directory=' + repo.as_posix(), '-C', str(repo)]
    def read(*args):
        return subprocess.check_output([*git, *args], timeout=30)
    assert read('rev-parse', PIN + '^{commit}').decode().strip() == PIN
    manifest = {'source_commit': PIN, 'source_tree': read('rev-parse', PIN + '^{tree}').decode().strip(),
                'scope': 'native extracted train fixture; not full game or client capture',
                'original': {}, 'generated': {}, 'native_executed': False}
    for name in PATHS:
        raw = read('show', PIN + ':' + name)
        path = out / 'original' / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(raw)
        manifest['original'][name] = {**record(raw), 'git_blob': read('rev-parse', PIN + ':' + name).decode().strip()}
    stage = out / 'stage'
    stage.mkdir()
    raw = production_bytes((out / 'original/code/modules/1713/trains.dm').read_bytes())
    (stage / 'production.dm').write_bytes(raw)
    here = Path(__file__).resolve().parent
    for name in ('adapters.dm', 'fixture.dm'):
        (stage / name).write_bytes((here / name).read_bytes())
    for name in ('trains.dmi', 'train_lever.dmi'):
        dest = stage / 'icons/obj/vehicles' / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes((out / 'original/icons/obj/vehicles' / name).read_bytes())
    (stage / 'proof.dme').write_text('#define SOURCE_PIN "' + PIN + '"\n#include "adapters.dm"\n#include "production.dm"\n#include "fixture.dm"\n', encoding='utf8', newline='\n')
    for path in sorted(stage.rglob('*')):
        if path.is_file():
            manifest['generated'][path.relative_to(stage).as_posix()] = record(path.read_bytes())
    (out / 'source-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf8')
    return manifest


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--repo', required=True, type=Path)
    p.add_argument('--output', required=True, type=Path)
    a = p.parse_args()
    print(json.dumps(prepare(a.repo.resolve(), a.output.resolve()), indent=2))
