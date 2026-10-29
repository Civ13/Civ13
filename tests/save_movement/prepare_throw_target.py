"""Source-only tiny disk fixture preparation. No compiler/runtime launch mode."""
import argparse
import importlib.util
from pathlib import Path
import tempfile

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('throw_target_base', ROOT / 'tests/world_save/run-cross-level.py')
BASE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BASE)


def prepare(output):
    output = Path(output)
    receipt = BASE.prepare(output)
    raw = (ROOT / 'code/game/atoms_movable.dm').read_bytes()
    paths = ('/atom/movable/proc/clear_throw_launch', '/atom/movable/proc/begin_throw_launch',
             '/atom/movable/proc/update_throw_launch', '/atom/movable/proc/throw_at',
             '/atom/movable/proc/finished_throwing')
    projection = '\n'.join(BASE.extract_proc(raw.decode('utf-8-sig'), proc) for proc in paths)
    receipt['source_sha256']['code/game/atoms_movable.dm'] = BASE.sha(raw)
    receipt['source_projections']['throw_cleanup.dm'] = {
        'source': 'code/game/atoms_movable.dm', 'procedures': paths, 'sha256': BASE.sha(projection.encode())}
    (output / 'throw_cleanup.dm').write_text(projection, encoding='utf-8')
    raw = (ROOT / 'tests/save_movement/throw_target_probe.dm').read_bytes()
    receipt['source_sha256']['tests/save_movement/throw_target_probe.dm'] = BASE.sha(raw)
    (output / 'throw_target_probe.dm').write_bytes(raw)
    path = output / 'cross_level_probe.dm'
    text = path.read_text(encoding='utf-8')
    if text.count('/world/New()\n') != 1:
        raise RuntimeError('Expected exactly one inherited fixture startup')
    path.write_text(text[:text.index('/world/New()\n')], encoding='utf-8')
    path = output / 'probe.dme'
    path.write_text(path.read_text(encoding='utf-8') +
                    '\n#include "throw_cleanup.dm"\n#include "throw_target_probe.dm"\n', encoding='utf-8')
    receipt.update(scope=__doc__, prepared_only=True, native_verified=False,
                   actual_gameplay_verified=False, actual_stack_constructors_verified=False)
    BASE.refresh_receipt(output, receipt)
    return receipt


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prepare-only', required=True, action='store_true')
    args = parser.parse_args()
    output = Path(tempfile.mkdtemp(prefix='civ13-throw-target-'))
    prepare(output)
    print(f'Prepared only: {output}; native compilation/runtime NOT RUN')
