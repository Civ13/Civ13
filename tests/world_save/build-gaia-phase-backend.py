"""Freeze a source-only legacy Gaia backend smoke; never launch an engine."""
import argparse
import importlib.util
import json
import subprocess
from pathlib import Path

BASE = 'cbf0ebb0a46c7dceb2be8bb02010f49db49cac72'
SAVING = 'f519db25af2ecd8181209fd790c8206789010105fb36129c7dfc14aabd3978f4'
FUNCTIONS = 'afe5d78b3252099c4dc42a69f329e8ed2d45626938fe7b4f8126aa7caafb6dd2'
TICK = '3da955ebcd0d7d563a2e485773fc68aef48139718752ae864ad4ca40bf13fd7b'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repository', type=Path, required=True)
    parser.add_argument('--saving-source', type=Path, required=True)
    parser.add_argument('--functions-source', type=Path, required=True)
    parser.add_argument('--tick-source', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--datum-constructor-mode', choices=('original', 'no-location'), default='original')
    args = parser.parse_args()
    here = Path(__file__).resolve().parent
    generator = here / 'build-progress-probe.py'
    spec = importlib.util.spec_from_file_location('progress_generator', generator)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    originals = {}
    for name, expected in (('saving', SAVING), ('functions', FUNCTIONS), ('tick', TICK)):
        data = getattr(args, name + '_source').resolve(strict=True).read_bytes()
        if len(data) > 512 * 1024 or module.digest(data) != expected:
            raise ValueError(f'{name} frozen source mismatch')
        originals[name + '.dm'] = data
    saving, _ = module.instrument(originals['saving.dm'].decode().replace('\r\n', '\n'),
                                  originals['functions.dm'].decode().replace('\r\n', '\n'), phase_profile=True)
    outputs = {'saving.dm': saving.encode(), 'functions.dm': originals['functions.dm'],
               'tick.dm': originals['tick.dm'],
               'progress-probe.dm': module.profile_helper((here / 'progress-probe.dm').read_text()).encode(),
               'phase-profile.dm': (here / 'phase-profile.dm').read_bytes(),
               'backend.dm': (here / 'gaia-phase-backend.dm').read_bytes()}
    dependencies = {'predefines.dm': 'code/predefines.dm', 'stubs.dm': 'tests/world_save/stubs.dm',
                    'loading.dm': 'code/modules/persistence/loading.dm',
                    'icons/turf/floors.dmi': 'icons/turf/floors.dmi'}
    for target, source in dependencies.items():
        repository = str(args.repository.resolve(strict=True))
        result = subprocess.run(['git', '-c', 'safe.directory=' + repository, '-C', repository,
                                 'show', BASE + ':' + source], capture_output=True)
        if result.returncode:
            raise ValueError(result.stderr.decode(errors='replace'))
        outputs[target] = result.stdout
    original_loading = outputs['loading.dm']
    if args.datum_constructor_mode == 'no-location':
        loading = original_loading.decode().replace('\r\n', '\n')
        outputs['loading.dm'] = module.replace_once(loading,
            '\t\telse\n\t\t\tobject = new type(starting_loc)\n',
            '\t\telse if(ispath(type, /atom))\n\t\t\tobject = new type(starting_loc)\n'
            '\t\telse\n\t\t\tobject = new type()\n').encode()
    outputs['backend.dme'] = b'''#define TRUE 1
#define FALSE 0
#define EXCEPTION(message) new /exception(message)
#define FILE_DIR "."
#include "predefines.dm"
#include "tick.dm"
#include "stubs.dm"
#define fdel(path) delete_file_adapter(path)
#include "functions.dm"
#include "saving.dm"
#include "loading.dm"
#include "progress-probe.dm"
#include "phase-profile.dm"
#include "backend.dm"
'''
    manifest = dict(scope='source-only actual-engine legacy Gaia backend smoke; no runtime acceptance',
                    dependency_commit=BASE,
                    original_sha256={name: module.digest(data) for name, data in originals.items()},
                    generator_sha256=module.digest(Path(__file__).read_bytes()),
                    progress_generator_sha256=module.digest(generator.read_bytes()),
                    datum_constructor_mode=args.datum_constructor_mode,
                    original_loading_sha256=module.digest(original_loading),
                    generated_sha256={name: module.digest(data) for name, data in outputs.items()},
                    launch='Runtime owner selects and records exact engine source/compiler/runtime artifacts. SAVE then VERIFY in distinct guarded processes sharing only temporary storage; verify parameter enables VERIFY.',
                    limits='Legacy before_save closure only; minimal offline type adapters and explicit real-yield fixture hook. Does not exercise current atomic hooks, full Gaia, crash recovery, production IO or server latency. No fake clock. Phase yield overlaps engine flush timings; do not add them.')
    args.output_dir.mkdir(parents=True, exist_ok=False)
    for name, data in outputs.items():
        path = args.output_dir / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    for name, data in originals.items():
        path = args.output_dir / 'original' / name
        path.parent.mkdir(exist_ok=True)
        path.write_bytes(data)
    (args.output_dir / 'original' / 'loading.dm').write_bytes(original_loading)
    (args.output_dir / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    main()
