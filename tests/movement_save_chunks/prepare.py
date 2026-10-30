"""Create a hash-bound isolated source packet only; never compile or launch."""
import hashlib
import json
from pathlib import Path
import tempfile

ROOT = Path(__file__).resolve().parents[2]
FILES = ['code/predefines.dm', 'tests/world_save/stubs.dm',
         'code/modules/multiz/world_z_budget.dm', 'code/modules/persistence/functions.dm',
         'code/modules/persistence/player_reclaim.dm', 'code/modules/persistence/saving.dm',
         'code/modules/persistence/loading.dm', 'tests/movement_save_chunks/probe.dm']

def prepare(output):
    hashes = {}
    for name in FILES:
        data = (ROOT / name).read_bytes()
        dest = output / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)
        hashes[name] = hashlib.sha256(data).hexdigest()
    header = ('#define TRUE 1\n#define FALSE 0\n#define TICK_CHECK fixture_tick_check()\n'
              '#define TICK_LIMIT_TO_RUN 100\n#define EXCEPTION(message) new /exception(message)\n')
    (output / 'probe.dme').write_text(header + ''.join(f'#include "{name}"\n' for name in FILES))
    hashes['probe.dme'] = hashlib.sha256((output / 'probe.dme').read_bytes()).hexdigest()
    (output / 'receipt.json').write_text(json.dumps({'execution': 'not_run', 'sources': hashes,
        'scenarios': ['walking', 'reference', 'frontier', 'frontier-delete', 'delete', 'inventory', 'cross-z', 'yield', 'depth']}, indent=2))
    return hashes

if __name__ == '__main__':
    output = Path(tempfile.mkdtemp(prefix='civ13-moving-save-source-'))
    prepare(output)
    print(output)
