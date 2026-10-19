"""One-time, source-only migration with a reviewable expression fingerprint."""
import hashlib
import json
from pathlib import Path
import re


def migrate(root):
    pattern = re.compile(r'^(\s*)((?:\w+\.)?)attack_log\s*\+=\s*(.+)$')
    changes = {}
    inventory = []
    for path in sorted((root / 'code').rglob('*.dm')):
        original = path.read_text(encoding='utf-8')
        lines = original.splitlines(keepends=True)
        for index, line in enumerate(lines):
            if 'attack_log' not in line or '+=' not in line:
                continue
            match = pattern.fullmatch(line.rstrip('\n'))
            if not match:
                raise ValueError(f'Unreviewed writer syntax: {path}:{index + 1}')
            indent, owner, entry = match.groups()
            lines[index] = f'{indent}{owner}append_attack_log({entry})\n'
            inventory.append({'path': path.relative_to(root).as_posix(),
                              'owner': owner,
                              'expression_sha256': hashlib.sha256(entry.encode()).hexdigest()})
        changed = ''.join(lines)
        if changed != original:
            changes[path] = changed
    if len(inventory) != 86 or len(changes) != 29:
        raise ValueError(f'Unexpected migration: {len(inventory)} writers / {len(changes)} files')
    for path, content in changes.items():
        path.write_text(content, encoding='utf-8', newline='')
    output = root / 'tests/attack_history/writer-migration.json'
    output.write_text(json.dumps({'source_commit': 'a24ae39a29f304ef5bec570f4634e4fb279973e6',
                                  'writers': inventory}, indent=2) + '\n', encoding='utf-8')
    print(f'Migrated {len(inventory)} writers in {len(changes)} files; expressions unchanged')


if __name__ == '__main__':
    migrate(Path(__file__).resolve().parents[2])
