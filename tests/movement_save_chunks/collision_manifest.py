"""Source-only collision override inventory; never executes game code.

This is a review tripwire, not proof that an unlisted type is safe. It scans
the production DM source roots, including nested declarations and parent_type assignments.
Each declaration records its owning type block and a hash of its own indented
body, so edits elsewhere in the same file (and line shifts) do not trip it.
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
        lines = content.splitlines()
        hits = []
        for number, line in enumerate(lines):
            if DECLARATION.match(line) or PARENT.match(line):
                hits.append({'owner': owner(lines, number), 'declaration': line.strip(),
                             'sha256_body': hashlib.sha256(body(lines, number).encode('utf-8')).hexdigest()})
        if hits:
            entries.append({'path': path.relative_to(root).as_posix(), 'declarations': hits})
    return {'schema': 2, 'scope': 'production code and interface DM roots; collision declarations and parent_type assignments, hashed per declaration body', 'files': entries}


def indent(line):
    return len(line) - len(line.lstrip(' \t'))


def body(lines, start):
    """The declaration line plus every deeper-indented (or blank) line after it."""
    depth = indent(lines[start])
    end = start + 1
    while end < len(lines) and (not lines[end].strip() or indent(lines[end]) > depth):
        end += 1
    while end > start + 1 and not lines[end - 1].strip():
        end -= 1
    return '\n'.join(line.rstrip() for line in lines[start:end])


def owner(lines, start):
    """Nearest less-indented, non-comment line above: the enclosing type block."""
    depth = indent(lines[start])
    for line in reversed(lines[:start]):
        text = line.strip()
        if text and not text.startswith('//') and indent(line) < depth:
            return text
    return ''



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
