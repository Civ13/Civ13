"""Prepare reviewable ClickOn/real-wait source overlays. Never compile or launch BYOND."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
ORIGINAL = 'cc03b199128f8afed58713912c551ad7556e6bc4'
TRAINING = 'code/modules/1713/active_training.dm'
PREFIX = '.active_training_click'


def git(*args):
    """Run Git with the supplied arguments in ROOT and return stdout bytes."""
    return subprocess.check_output(['git', '-C', str(ROOT), *args])


def sha(data):
    """Return the hexadecimal SHA-256 digest of the supplied bytes."""
    return hashlib.sha256(data).hexdigest()


def prepare(output, original_silence=False):
    """Write five source overlays and metadata to an empty external directory.

    Use the pinned original training blob when original_silence is true;
    otherwise use the working tree. Return metadata with input and overlay
    hashes. Reject unsafe output paths or ambiguous source markers with
    ValueError. No compiler or game process is launched.
    """
    output = output.resolve()
    if output.is_relative_to(ROOT.resolve()):
        raise ValueError('Keep prepared evidence outside the source checkout')
    if output.exists() and any(output.iterdir()):
        raise ValueError('Preserve existing evidence; output must be empty')
    head = git('rev-parse', 'HEAD').decode().strip()
    inputs = ['civ13.dme', 'code/world.dm', 'code/controllers/mc/globals.dm', TRAINING,
              'tests/active_training/game.dm', 'tests/active_training/click_game.dm',
              'tests/active_training/prepare_click.py', 'tests/active_training/run.ps1',
              'tests/active_training/verify_click.py', 'code/_onclick/click.dm',
              'code/_onclick/other_mobs.dm', 'code/_onclick/item_attack.dm',
              'code/game/objects/structures.dm', 'code/_helpers/mobs.dm',
              'code/datums/progressbar.dm']
    blobs = {path: (ROOT / path).read_bytes() for path in inputs}
    def text(path):
        """Decode a captured input as UTF-8, stripping its BOM and normalizing newlines."""
        return blobs[path].decode('utf-8-sig').replace('\r\n', '\n').replace('\r', '\n')
    world = text('code/world.dm')
    marker = '/world/New()'
    if world.count(marker) != 1:
        raise ValueError('World startup target missing or ambiguous')
    world = world.replace(marker, '/world/proc/unused_active_training_startup()', 1)
    offset = world.index('/world/proc/unused_active_training_startup()')
    world = world[:offset] + re.sub(r'^\t\.\.\(\)\s*$', '', world[offset:], count=1, flags=re.M)
    marker = '/datum/global_init/New()\n'
    if world.count(marker) != 1:
        raise ValueError('Global initialization target missing or ambiguous')
    world = world.replace(marker, marker + '\treturn\n', 1)
    globals_source = text('code/controllers/mc/globals.dm')
    marker = '/datum/controller/global_vars/New()\n'
    if globals_source.count(marker) != 1:
        raise ValueError('Global controller target missing or ambiguous')
    globals_source = globals_source.replace(marker, marker + '\tGLOB = src\n\treturn\n', 1)
    original_blob = git('show', ORIGINAL + ':' + TRAINING) if original_silence else None
    training = original_blob.decode('utf-8-sig').replace('\r\n', '\n') if original_silence else text(TRAINING)
    # Observe the exact production call arguments, then forward to real chat.
    # This generated-source adapter is not proof of connected chat rendering.
    training = training.replace('to_chat(', 'training_click_chat(')
    shared = text('tests/active_training/game.dm')
    marker = '/obj/structure/exercise/training_fixture/exercise_wait'
    if shared.count(marker) != 1:
        raise ValueError('Existing fixture setup boundary changed')
    fixture = shared.split(marker, 1)[0] + text('tests/active_training/click_game.dm')
    dme = text('civ13.dme')
    for path, name in [('code/world.dm', '_world.dm'),
                       ('code/controllers/mc/globals.dm', '_globals.dm'),
                       (TRAINING, '_training.dm')]:
        include = '#include "' + path.replace('/', '\\') + '"'
        if dme.count(include) != 1:
            raise ValueError('Include missing or ambiguous: ' + path)
        dme = dme.replace(include, '#include "' + PREFIX + name + '"', 1)
    dme, maps = re.subn(r'^#include "[^"\r\n]*\.dmm"\s*$', '', dme, flags=re.M)
    if maps != 1:
        raise ValueError('Expected exactly one map include')
    dme += '\n#include "' + PREFIX + '_fixture.dm"\n'
    sources = {PREFIX + '.dme': dme, PREFIX + '_world.dm': world,
               PREFIX + '_globals.dm': globals_source, PREFIX + '_training.dm': training,
               PREFIX + '_fixture.dm': fixture}
    output.mkdir(parents=True, exist_ok=True)
    overlay = output / 'overlay'
    overlay.mkdir()
    for name, value in sources.items():
        (overlay / name).write_bytes(value.encode('utf-8'))
    metadata = {'checkout_head': head, 'control': 'original-silence' if original_silence else 'candidate',
                'original_control_commit': ORIGINAL if original_silence else None,
                'original_control_sha256': sha(original_blob) if original_blob is not None else None,
                'inputs_sha256': {path: sha(data) for path, data in blobs.items()},
                'generated_sha256': {name: sha(value.encode('utf-8')) for name, value in sources.items()},
                'scope': 'Source preparation only; real ClickOn/do_after/time, minimal startup and inventory/chat observation adapters; no connected client',
                'execution': 'Not run. Root must review and materialize overlay only in a disposable source copy matching input hashes; never compile in the protected world.',
                'proposed_native_bounds': {'compiler_seconds': 180, 'runtime_wall_seconds': 100, 'fixture_deadline_ticks': 900}}
    (output / 'metadata.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
    return metadata


def main():
    """Parse output and control options, then prepare source overlays only."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--original-silence', action='store_true')
    args = parser.parse_args()
    prepare(args.output, args.original_silence)
    print('Prepared source only; no compiler or runtime launched')


if __name__ == '__main__':
    main()
