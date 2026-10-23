"""Prepare a relocatable native collector probe, without compiling or running it."""
import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MOVABLE_FIELDS = ('throwing', 'throwmode', 'speed', 'range', 'dist_travelled',
                  'throw_speed', 'throw_range', 'original_target', 'thrower', 'throw_source')


def movable_declarations(source):
    """Project only the named base fields, preserving production initializers."""
    block = re.search(r'^/atom/movable\n((?:\t[^\n]*\n|\n)+)', source, re.M)
    if not block:
        raise ValueError('Production movable declaration changed')
    rows = []
    for field in MOVABLE_FIELDS:
        matches = re.findall(r'^\tvar/(?:[A-Za-z_/]+/)?' + field + r'(?:\s*=.*)?$', block.group(1), re.M)
        if len(matches) != 1:
            raise ValueError('Production movable field declaration changed: ' + field)
        rows.append(matches[0])
    return '/atom/movable\n' + '\n'.join(rows) + '\n'


def prepare(output, publication_mode='writable'):
    if publication_mode not in ('writable', 'missing', 'unwritable'):
        raise ValueError('Unknown publication mode')
    output = Path(output)
    output.mkdir(parents=True, exist_ok=False)
    for name in ('config', 'data'):
        (output / name).mkdir()
    private_output = output / 'data/desktop-supervisor/variable-observability'
    if publication_mode != 'missing':
        private_output.mkdir(parents=True)
    # Preparation never sets permissions. The unwritable case needs a separately
    # reviewed fixture-only denial before native execution can prove anything.
    (output / 'config/variable-probe-mode.txt').write_text(publication_mode, encoding='ascii')
    sources = {
        'variable_observability.dm': ROOT / 'code/modules/persistence/variable_observability.dm',
        'probe.dm': Path(__file__).with_name('variable_probe.dm'),
    }
    hashes = {}
    for name, path in sources.items():
        raw = path.read_bytes()
        (output / name).write_bytes(raw)
        hashes[str(path.relative_to(ROOT))] = hashlib.sha256(raw).hexdigest()
    movable_path = ROOT / 'code/game/atoms_movable.dm'
    raw = movable_path.read_bytes()
    (output / 'movable_defaults.dm').write_text(movable_declarations(raw.decode('utf-8-sig')), encoding='utf-8')
    hashes[str(movable_path.relative_to(ROOT))] = hashlib.sha256(raw).hexdigest()
    text_path = ROOT / 'code/_helpers/text.dm'
    raw = text_path.read_bytes()
    text = raw.decode('utf-8-sig')
    procs = []
    for name in ('trim_left', 'trim_right', 'trim'):
        match = re.search(r'^/proc/' + name + r'\(text\)\n(?:\t[^\n]*\n|\n)+', text, re.M)
        if not match:
            raise ValueError('Production trim projection changed')
        procs.append(match.group())
    (output / 'trim.dm').write_text('\n'.join(procs), encoding='utf-8')
    hashes[str(text_path.relative_to(ROOT))] = hashlib.sha256(raw).hexdigest()
    (output / 'probe.dme').write_text('#include "probe.dm"\n', encoding='utf-8')
    receipt = dict(schema=1, prepared_only=True, native_verified=False, source_sha256=hashes,
        publication_mode=publication_mode,
        unwritable_fixture_permissions_required=publication_mode == 'unwritable',
        scope='Production collector with minimal data/auth adapters; not full serializer, transport or gameplay acceptance')
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    return receipt


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True, help='New temporary packet directory')
    parser.add_argument('--publication-mode', choices=('writable', 'missing', 'unwritable'), default='writable')
    args = parser.parse_args()
    print(json.dumps(prepare(args.output, args.publication_mode)))
