"""Prepare a fresh full-map test tree; never launch, install or overwrite a host."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import secrets
import subprocess
import zipfile

BASE = 'b0e398add3800a0cc505bce1574d536904c5a9d5'
DISPATCH = '/world/Topic(T, addr, master, key)\n'
HOOK = ('\tif("full_map_probe" in params2list(T))\n'
        '\t\treturn full_map_probe_topic(T, addr)\n')


def instrument_world(source):
    if source.count(DISPATCH) != 1:
        raise ValueError('Expected one production world.Topic declaration')
    return source.replace(DISPATCH, DISPATCH + HOOK, 1)


def insert_once(source, anchor, addition):
    if source.count(anchor) != 1:
        raise ValueError(f'Expected one instrumentation anchor: {anchor!r}')
    return source.replace(anchor, anchor + addition, 1)


def instrument_lifecycle(relative, source):
    """Observe completed production work without replacing its procedures."""
    if relative.endswith('gameticker.dm'):
        return insert_once(source, '\t\tsetup_autobalance()\n',
                           '\t\tfull_map_probe_setup_done = TRUE\n')
    if relative.endswith('roundstart_etc.dm'):
        for atom in ('salmon', 'fish', 'piranha', 'anthill'):
            expression = {'salmon': 'fish/salmon', 'fish': 'fish',
                          'piranha': 'piranha', 'anthill': 'anthill'}[atom]
            source = insert_once(source, f'\t\t\tnew/obj/structure/{expression}(areaspawn)\n',
                                 f'\t\tfull_map_probe_nature_done += "{atom}"\n')
        return source
    return insert_once(source,
                       '/datum/persistence_restart_transaction/proc/request_restart()\n',
                       '\tfull_map_probe_record_generation()\n')


def prepare(repository, output):
    repository = repository.resolve(strict=True)
    output = output.resolve()
    # An existing directory may contain another host or irreplaceable saves.
    output.mkdir(parents=True, exist_ok=False)
    archive = output / 'source.zip'
    subprocess.run(['git', '-C', str(repository), 'archive', '--format=zip',
                    f'--output={archive}', BASE], check=True)
    game = output / 'game'
    with zipfile.ZipFile(archive) as exported:
        exported.extractall(game)
    adapter = Path(__file__).with_name('control.dm').read_bytes()
    (game / 'full-map-probe.dm').write_bytes(adapter)
    world_path = game / 'code/world.dm'
    original_world = world_path.read_text(encoding='utf-8')
    world_path.write_text(instrument_world(original_world), encoding='utf-8', newline='\n')
    instrumented = {}
    for relative in ('code/game/gameticker.dm',
                     'code/modules/1713/roundstart_etc.dm',
                     'code/modules/persistence/restart_transaction.dm'):
        path = game / relative
        original = path.read_text(encoding='utf-8')
        modified = instrument_lifecycle(relative, original)
        path.write_text(modified, encoding='utf-8', newline='\n')
        instrumented[relative] = {'original_sha256': hashlib.sha256(original.encode()).hexdigest(),
                                  'instrumented_sha256': hashlib.sha256(modified.encode()).hexdigest()}
    progress_path = game / 'tests/world_save/build-progress-probe.py'
    spec = importlib.util.spec_from_file_location('frozen_save_progress', progress_path)
    progress = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(progress)
    saving_path = game / 'code/modules/persistence/saving.dm'
    saving = saving_path.read_text(encoding='utf-8')
    functions = (game / 'code/modules/persistence/functions.dm').read_text(encoding='utf-8')
    observed_saving, unchanged_functions = progress.instrument(saving, functions)
    if functions != unchanged_functions:
        raise ValueError('Progress instrumentation changed serializer helpers')
    saving_path.write_text(observed_saving, encoding='utf-8', newline='\n')
    instrumented['code/modules/persistence/saving.dm'] = {
        'original_sha256': hashlib.sha256(saving.encode()).hexdigest(),
        'instrumented_sha256': hashlib.sha256(observed_saving.encode()).hexdigest(),
        'generator_sha256': hashlib.sha256(progress_path.read_bytes()).hexdigest(),
        'helper_sha256': hashlib.sha256((game / 'tests/world_save/progress-probe.dm').read_bytes()).hexdigest()}
    environment = (game / 'civ13.dme').read_text(encoding='utf-8')
    original_map = '#include "maps\\nomads\\nomads.dmm"'
    if environment.count(original_map) != 1:
        raise ValueError('Expected one default Nomads map include')
    environment = environment.replace(original_map, '#include "maps\\nomads\\nomads_europe.dmm"')
    (game / 'full-map-europe.dme').write_text(
        environment + '\n#include "full-map-probe.dm"\n#include "tests/world_save/progress-probe.dm"\n',
        encoding='utf-8', newline='\n')
    # Exported configuration still needs isolation review before launch.
    # Preparation does not expose a listener or copy production configuration.
    (game / 'config/full-map-probe-token.txt').write_text(secrets.token_hex(32), encoding='ascii')
    manifest = {'source_commit': BASE, 'map': 'maps/nomads/nomads_europe.dmm',
                'adapter_sha256': hashlib.sha256(adapter).hexdigest(),
                'original_world_sha256': hashlib.sha256(original_world.encode()).hexdigest(),
                'instrumented_world_sha256': hashlib.sha256(world_path.read_bytes()).hexdigest(),
                'lifecycle_instrumentation': instrumented,
                'entrypoint': 'full-map-europe.dme', 'launched': False,
                'configuration_review_required': True,
                'limits': ['No real client, player-body or inventory acceptance',
                           'No save or recovery has run during preparation']}
    (output / 'prepare.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repository', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(prepare(args.repository, args.output), indent=2))
