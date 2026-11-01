"""Source-only collision override inventory; never executes game code.

This is a review tripwire, not proof that an unlisted type is safe. It scans
the production DM source roots, including nested declarations and parent_type assignments.
Files containing declarations are hashed in full after newline normalization.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = Path(__file__).with_name('collision_overrides.json')
DECLARATION = re.compile(r'^\s*(?:(?:/[A-Za-z0-9_]+)+/)?(?:proc/)?(CanPass|CheckExit)\s*\(')
PARENT = re.compile(r'^\s*parent_type\s*=')
INCLUDE = re.compile(r'^\s*#include\s+"([^"]+\.dm)"', re.I | re.M)


def inventory(root):
    entries = []
    dme = (root / 'civ13.dme').read_text(encoding='utf-8')
    for include in INCLUDE.findall(dme):
        parts = include.replace('\\', '/').split('/')
        if len(parts) < 2 or parts[0].lower() not in ('code', 'interface') or '..' in parts:
            raise ValueError('Production DM include outside collision inventory roots: ' + include)
    paths = [path for folder in ('code', 'interface') for path in (root / folder).rglob('*.dm')]
    for path in sorted(paths):
        content = path.read_text(encoding='utf-8', errors='replace')
        for include in INCLUDE.findall(content):
            resolved = (path.parent / include.replace('\\', '/')).resolve()
            if not any(resolved.is_relative_to((root / folder).resolve()) for folder in ('code', 'interface')):
                raise ValueError('Nested DM include outside collision inventory roots: ' + include)
        hits = []
        for number, line in enumerate(content.splitlines(), 1):
            if DECLARATION.match(line) or PARENT.match(line):
                hits.append({'line': number, 'declaration': line.strip()})
        if hits:
            entries.append({'path': path.relative_to(root).as_posix(),
                            'sha256_normalized': hashlib.sha256(content.encode('utf-8')).hexdigest(),
                            'declarations': hits})
    return {'schema': 1, 'scope': 'production code and interface DM roots; collision declarations and parent_type assignments', 'files': entries}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    current = inventory(ROOT)
    if args.write:
        OUTPUT.write_text(json.dumps(current, indent=2) + '\n', encoding='utf-8', newline='\n')
        return
    if json.loads(OUTPUT.read_text(encoding='utf-8')) != current:
        raise SystemExit('Collision source inventory changed; audit overrides and parent types before refreshing it')


if __name__ == '__main__':
    main()
