"""Check a source-only Gaia packet against its original full frozen inventory."""
import argparse
import hashlib
import json
from pathlib import Path


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--packet', type=Path, required=True)
    parser.add_argument('--original-manifest', type=Path, required=True)
    parser.add_argument('--receipt', type=Path, required=True)
    args = parser.parse_args()
    packet = args.packet.resolve(strict=True)
    packet_bytes = (packet / 'manifest.json').read_bytes()
    original_bytes = args.original_manifest.resolve(strict=True).read_bytes()
    candidate = json.loads(packet_bytes)
    original = json.loads(original_bytes.decode('utf-8-sig'))
    if candidate['base_commit'] != original['game_head']:
        raise ValueError('Original game commit mismatch')
    if Path(candidate['source_root']).resolve() != Path(original['source_root']).resolve():
        raise ValueError('Original source root mismatch')
    if candidate['source_inventory'] != original['source_files']:
        raise ValueError('Original full source inventory mismatch')
    expected = {name: row['sha256'] for name, row in candidate['source_inventory'].items()}
    for name, pinned in candidate['original_pins'].items():
        if expected[name] != pinned or digest((packet / 'originals' / name).read_bytes()) != pinned:
            raise ValueError('Retained original mismatch: ' + name)
    expected.update(candidate['generated_sha256'])
    actual = {}
    for file in (packet / 'source').rglob('*'):
        if file.is_symlink():
            raise ValueError('Unexpected source symlink')
        if file.is_file():
            actual[file.relative_to(packet / 'source').as_posix()] = digest(file.read_bytes())
    if actual != expected:
        raise ValueError('Generated closure mismatch')
    probe_hash = actual['tests/world_save/new_process_probe.dm']
    dme = (packet / 'source/civ13.dme').read_text(encoding='utf-8')
    if dme.count('#define NEW_PROCESS_ADAPTER_SHA256 "' + probe_hash + '"') != 1:
        raise ValueError('Probe dispatcher authentication hash mismatch')
    if dme.count('#include "' + candidate['map'] + '"') != 1:
        raise ValueError('Actual full Gaia map include mismatch')
    receipt = dict(scope='source inventory/hash consistency only; no compilation/runtime acceptance',
                   packet_manifest_sha256=digest(packet_bytes), original_manifest_sha256=digest(original_bytes),
                   audit_script_sha256=digest(Path(__file__).read_bytes()),
                   original_files=len(candidate['source_inventory']), generated_files=len(candidate['generated_sha256']),
                   output_files=len(actual), map_sha256=actual[candidate['map']],
                   source_inventory_equal=True, output_closure_equal=True, probe_macro_bound=True,
                   runtime='UNRUN; runtime owner must freeze actual compatible host/compiler/resources and execute SAVE/fresh VERIFY')
    with args.receipt.open('x', encoding='utf-8') as file:
        file.write(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt))


if __name__ == '__main__':
    main()
