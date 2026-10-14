"""Freeze the original full Gaia source with narrow reviewed deltas; no engine execution."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path


PINS = {
    'code/modules/persistence/saving.dm': 'f519db25af2ecd8181209fd790c8206789010105fb36129c7dfc14aabd3978f4',
    'code/modules/persistence/functions.dm': 'afe5d78b3252099c4dc42a69f329e8ed2d45626938fe7b4f8126aa7caafb6dd2',
    'code/modules/persistence/loading.dm': '51f3a99006045483f05d9e43d28d1893067bc436654916783138c2653d31a93b',
    'code/__defines/_tick.dm': '3da955ebcd0d7d563a2e485773fc68aef48139718752ae864ad4ca40bf13fd7b',
    'tests/world_save/new_process_probe.dm': '05c797618209d381f24c9ecd20b69f91e8ca7151ac0666ee6729bf22f52db64f',
    'civ13.dme': '9d5e2eef92565c7454d58dcfc5a5f22aec2d107f8a492318b248b3f9ee43a775',
}
WRAPPER = 'b0ee2bcdbc9c8268d152c3e41b7d6e3c6c1265a1fb871165ce7647a08fada8c3'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def text(data):
    return data.decode('utf-8').replace('\r\n', '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-root', type=Path, required=True)
    parser.add_argument('--wrapper-dir', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--setup-readiness-marker', action='store_true',
                        help='Test-only marker after original setup_everything final yield')
    args = parser.parse_args()
    source = args.source_root.resolve(strict=True)
    output = args.output_dir.resolve()
    if output.exists() or output == source or source in output.parents:
        raise ValueError('Output must be a new directory outside the source')
    originals = {}
    pins = dict(PINS)
    if args.setup_readiness_marker:
        pins['code/setup.dm'] = 'a748fd96ef63a6cc6322766baad3684b6aee9579cbe4e3ebd3e76cfc69b6f30d'
    for name, expected in pins.items():
        data = (source / name).read_bytes()
        if digest(data) != expected:
            raise ValueError('Frozen input mismatch: ' + name)
        originals[name] = data
    here = Path(__file__).resolve().parent
    generator = here / 'build-progress-probe.py'
    spec = importlib.util.spec_from_file_location('gaia_progress_generator', generator)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    saving, _ = module.instrument(text(originals['code/modules/persistence/saving.dm']),
                                  text(originals['code/modules/persistence/functions.dm']), phase_profile=True)
    loading = module.replace_once(text(originals['code/modules/persistence/loading.dm']),
        '\t\telse\n\t\t\tobject = new type(starting_loc)\n',
        '\t\telse if(ispath(type, /atom))\n\t\t\tobject = new type(starting_loc)\n'
        '\t\telse\n\t\t\tobject = new type()\n')
    functions = module.replace_once(text(originals['code/modules/persistence/functions.dm']),
        '/datum/proc/get_saved_vars()\n',
        '// Unsupported composite appearance must not reset restored scalar visual fields.\n'
        '/atom/persistence_runtime_var(key)\n\treturn key == "appearance" || ..()\n\n'
        '/datum/proc/get_saved_vars()\n')
    probe = module.replace_once(text(originals['tests/world_save/new_process_probe.dm']),
        '\t\t\tC.name = marker_name\n',
        '\t\t\tC.name = marker_name\n\t\t\tC.transform = matrix(8, 9, 10, 11, 12, 13)\n'
        '\t\t\tC.color = "#123456"\n\t\t\tC.alpha = 173\n')
    probe = module.replace_once(probe, '\t\t\t\tcrate_count++\n',
        '\t\t\t\tcrate_count++\n\t\t\t\tvar/matrix/restored_transform = C.transform\n'
        '\t\t\t\tif(!restored_transform || restored_transform.a != 8 || restored_transform.b != 9 || restored_transform.c != 10 || restored_transform.d != 11 || restored_transform.e != 12 || restored_transform.f != 13 || C.color != "#123456" || C.alpha != 173)\n'
        '\t\t\t\t\tthrow EXCEPTION("Restored crate visual fields changed")\n')
    wrapper = (args.wrapper_dir / 'gaia-host-save-wrapper.dm').read_bytes()
    if digest(wrapper) != WRAPPER:
        raise ValueError('Reviewed wrapper mismatch')
    dme = text(originals['civ13.dme'])
    if dme.count('#include "maps/nomads/nomads_gaia.dmm"') != 1:
        raise ValueError('Actual full Gaia map include missing')
    dme = module.replace_once(dme, '#define NEW_PROCESS_ADAPTER_SHA256 "' + PINS['tests/world_save/new_process_probe.dm'] + '"',
                              '#define NEW_PROCESS_ADAPTER_SHA256 "' + digest(probe.encode()) + '"')
    dme += ('\n#include "tests/world_save/gaia-progress-probe.dm"\n'
            '#include "tests/world_save/gaia-phase-profile.dm"\n'
            '#include "tests/world_save/gaia-host-save-wrapper.dm"\n')
    generated = {
        'code/modules/persistence/saving.dm': saving.encode(),
        'code/modules/persistence/functions.dm': functions.encode(),
        'code/modules/persistence/loading.dm': loading.encode(),
        'tests/world_save/new_process_probe.dm': probe.encode(),
        'civ13.dme': dme.encode(),
        'tests/world_save/gaia-progress-probe.dm': module.profile_helper(text((here / 'progress-probe.dm').read_bytes())).encode(),
        'tests/world_save/gaia-phase-profile.dm': (here / 'phase-profile.dm').read_bytes(),
        'tests/world_save/gaia-host-save-wrapper.dm': wrapper,
    }
    if args.setup_readiness_marker:
        setup = originals['code/setup.dm']
        if not text(setup).endswith('\tadmin_notice("<span class=\'danger\'>Initializations complete.</span>", R_DEBUG)\n\tsleep(-1)'):
            raise ValueError('Unexpected original setup completion tail')
        # Append after the original final yield. Preserve every original byte and wait.
        generated['code/setup.dm'] = setup + b'\n\tnew_process_dispatch_init_complete = TRUE\n'
    # Resolve all edits before output creation; preserve every original source byte.
    inventory = {}
    output.mkdir(parents=True)
    for file in sorted(source.rglob('*')):
        if file.is_symlink():
            raise ValueError('Source symlinks are unsupported')
        if not file.is_file():
            continue
        name = file.relative_to(source).as_posix()
        data = file.read_bytes()
        inventory[name] = dict(bytes=len(data), sha256=digest(data))
        target = output / 'source' / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(generated.get(name, data))
    for name, data in generated.items():
        target = output / 'source' / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    for name, data in originals.items():
        target = output / 'originals' / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    manifest = dict(scope='source-only full Gaia legacy closure; uncompiled and no recovery/cost acceptance',
                    base_commit='cbf0ebb0a46c7dceb2be8bb02010f49db49cac72',
                    source_root=str(source), source_inventory=inventory,
                    original_pins=pins, generated_sha256={name: digest(data) for name, data in generated.items()},
                    setup_readiness_marker=args.setup_readiness_marker,
                    generator_sha256=digest(Path(__file__).read_bytes()),
                    phase_generator_sha256=digest(generator.read_bytes()),
                    helper_input_sha256=digest((here / 'progress-probe.dm').read_bytes()),
                    map='maps/nomads/nomads_gaia.dmm',
                    public_proc='/proc/gaia_host_run_save_probe', observed_global='gaia_host_save_state',
                    source_semantics='Original legacy saver/closure plus phase wrappers and narrowly adapted3152 constructor/appearance fixes. Current atomic fixture acceptance is separate.',
                    engine_binding='Runtime owner must freeze compatible engine/compiler/host/resource hashes before execution. No engine included or launched.',
                    limits='Logical wrapper return is not durable completion. Aggregate null-filter includes all resources. Preserve normal close/dirty updates, stopped two-shard generation and distinct fresh VERIFY.')
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(dict(files=len(inventory), source_bytes=sum(row['bytes'] for row in inventory.values()),
                         generated=len(generated), manifest_sha256=digest((output / 'manifest.json').read_bytes()))))


if __name__ == '__main__':
    main()
