"""Prepare a relocatable native collector probe, without compiling or running it."""
import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def prepare(output):
    output = Path(output)
    output.mkdir(parents=True, exist_ok=False)
    for name in ('config', 'data'):
        (output / name).mkdir()
    sources = {
        'variable_observability.dm': ROOT / 'code/modules/persistence/variable_observability.dm',
        'probe.dm': Path(__file__).with_name('variable_probe.dm'),
    }
    hashes = {}
    for name, path in sources.items():
        raw = path.read_bytes()
        (output / name).write_bytes(raw)
        hashes[str(path.relative_to(ROOT))] = hashlib.sha256(raw).hexdigest()
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
        scope='Production collector with minimal data/auth adapters; not full serializer, transport or gameplay acceptance')
    (output / 'receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    return receipt


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True, help='New temporary packet directory')
    args = parser.parse_args()
    print(json.dumps(prepare(args.output)))
