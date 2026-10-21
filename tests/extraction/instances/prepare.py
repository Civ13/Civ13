"""Freeze standalone production-source fixture inputs. Never launches BYOND."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / 'code/modules/1713/extraction/instances.dm'
PROBE = Path(__file__).with_name('probe.dm')
INCLUDE = '#include "../../../code/modules/1713/extraction/instances.dm"'


def prepare(destination):
    destination = Path(destination)
    destination.mkdir(parents=True, exist_ok=False)
    source = SOURCE.read_bytes()
    probe = PROBE.read_text(encoding='utf-8')
    if probe.count(INCLUDE) != 1:
        raise ValueError('Expected exactly one production source include')
    payloads = {
        'instances.dm': source,
        'probe.dme': probe.replace(INCLUDE, '#include "instances.dm"').encode('utf-8'),
    }
    for name, content in payloads.items():
        (destination / name).write_bytes(content)
    manifest = {
        'schema': 1,
        'scope': 'standalone source fixture, not full game or disk persistence',
        'native_executed': False,
        'inputs': {name: hashlib.sha256(content).hexdigest() for name, content in payloads.items()},
        'production_source': SOURCE.relative_to(ROOT).as_posix(),
    }
    (destination / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prepare-only', action='store_true', required=True)
    parser.add_argument('--output', type=Path, required=True, help='New, nonexistent directory')
    args = parser.parse_args()
    print(json.dumps(prepare(args.output), indent=2))
