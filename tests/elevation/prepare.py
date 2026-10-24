"""Prepare source-only native elevation fixture. Never launch native tools."""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
SOURCES = ('code/predefines.dm', 'tests/world_save/stubs.dm',
           'code/modules/multiz/world_z_budget.dm', 'code/modules/persistence/functions.dm',
           'code/modules/persistence/player_reclaim.dm', 'code/modules/persistence/saving.dm',
           'code/modules/persistence/loading.dm', 'tests/elevation/probe.dm')


def prepare(output):
    # A fresh destination preserves previous failed/prepared evidence.
    if output.exists():
        raise ValueError('Output must be a new directory')
    originals = {p: (ROOT / p).read_bytes() for p in SOURCES}
    macros = (ROOT / 'code/_macros.dm').read_text()
    macro = '#define get_turf(A) get_step(A,0)'
    if macros.splitlines().count(macro) != 1:
        raise ValueError('Production physical-turf macro changed')
    stub = originals['tests/world_save/stubs.dm'].decode().replace('\r\n', '\n')
    metadata_path = 'code/game/objects/map_metadata/_map_metadata.dm'
    metadata = (ROOT / metadata_path).read_bytes()
    runtime = re.search(r'^/obj/map_metadata/persistence_runtime_var\(var/key\)\n(.*?)(?=^/|\Z)',
                        metadata.decode().replace('\r\n', '\n'), re.M | re.S)
    if not runtime:
        raise ValueError('Production map runtime hook changed')
    old = '/proc/get_turf(atom/A)\n\twhile(A && !isturf(A))\n\t\tA = A.loc\n\treturn A\n'
    if stub.count(old) != 1:
        raise ValueError('Physical-turf adapter anchor changed')
    output.mkdir(parents=True)
    for path, data in originals.items():
        if path == 'tests/world_save/stubs.dm':
            data = stub.replace(old, macro + '\n').encode()
        (output / Path(path).name).write_bytes(data)
    (output / 'map_runtime.dm').write_text(runtime[0], encoding='utf-8')
    environment = ('#define TRUE 1\n#define FALSE 0\n'
                   '#define TICK_CHECK fixture_tick_check()\n#define TICK_LIMIT_TO_RUN 100\n'
                   '#define EXCEPTION(message) new /exception(message)\n'
                   f'#define FILE_DIR "{ROOT.as_posix()}"\n')
    for name in ('predefines.dm', 'stubs.dm', 'world_z_budget.dm', 'functions.dm', 'map_runtime.dm',
                 'player_reclaim.dm', 'saving.dm', 'loading.dm', 'probe.dm'):
        environment += f'#include "{name}"\n'
    (output / 'elevation.dme').write_text(environment, encoding='utf-8')
    receipt = dict(prepared_only=True, native_executed=False, dimensions=[8, 6, 2],
                   required_byond='516.1681',
                   source_sha256={p: hashlib.sha256(data).hexdigest() for p, data in originals.items()},
                   map_runtime_source_sha256=hashlib.sha256(metadata).hexdigest(),
                   macro_source_sha256=hashlib.sha256((ROOT / 'code/_macros.dm').read_bytes()).hexdigest(),
                   adapters=['minimal world-save stubs; physical-turf adapter replaced by production get_turf macro',
                             'no durable round-v2 graph; offline header tests cover optional round-v2 elevation',
                             'native area reassignment models roof seam; production roof objects not constructed'],
                   generated_sha256={p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in output.iterdir()})
    (output / 'preparation.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    return receipt


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    prepare(args.output.resolve())
    print('Prepared native fixture source only: ' + str(args.output))
