"""Bounded source-evidence inventory, not a DM compiler or migration validator."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
FAMILIES = {
    'firearm': '/obj/item/weapon/gun',
    'casing': '/obj/item/ammo_casing',
    'magazine': '/obj/item/ammo_magazine',
    'projectile': '/obj/item/projectile',
    # Include all clothing: armor can be assigned outside armor-named branches.
    'clothing': '/obj/item/clothing',
}
TYPE = re.compile(r'/[A-Za-z_][A-Za-z_0-9]*(?:/[A-Za-z_][A-Za-z_0-9]*)*')
FIELDS = {'parent_type', 'caliber', 'ammo_type', 'magazine_type', 'projectile_type',
          'max_shells', 'load_method', 'armor', 'body_parts_covered', 'damage',
          'penetrating', 'accuracy', 'recoil', 'fire_delay', 'automatic'}
ASSIGNMENT = re.compile(r'\s*(?:var/(?:[\w]+/)*)?(\w+)\s*=\s*(.+)')
LIMIT_FILES = 10000
LIMIT_BYTES = 128 * 1024 * 1024
LIMIT_FILE_BYTES = 4 * 1024 * 1024
LIMIT_RECORDS = 50000
EXCERPT_CHARS = 512


def masked(source, strings=False):
    """Blank comments (and optionally literals), preserving offsets/newlines.

    Handles nested block comments, escaped quotes and DM long text literals.
    Long literals end at quote-brace, not a bare quote. No interpolation evaluation.
    """
    out = list(source)
    i, depth, quote = 0, 0, None
    while i < len(source):
        c, pair = source[i], source[i:i + 2]
        if depth:
            if pair == '/*':
                depth += 1
            elif pair == '*/':
                depth -= 1
            else:
                if c != '\n':
                    out[i] = ' '
                i += 1
                continue
            out[i:i + 2] = '  '
            i += 2
        elif quote:
            if quote == '"}' and pair == quote:
                if strings:
                    out[i:i + 2] = '  '
                quote = None
                i += 2
                continue
            if strings and c != '\n':
                out[i] = ' '
            if c == '\\' and i + 1 < len(source):
                if strings and source[i + 1] != '\n':
                    out[i + 1] = ' '
                i += 2
                continue
            if c == quote:
                quote = None
            i += 1
        elif pair == '//':
            end = source.find('\n', i)
            end = len(source) if end < 0 else end
            out[i:end] = ' ' * (end - i)
            i = end
        elif pair == '/*':
            depth = 1
            out[i:i + 2] = '  '
            i += 2
        elif pair == '{"':
            quote = '"}'
            if strings:
                out[i:i + 2] = '  '
            i += 2
        else:
            if c in '\"\'':
                quote = c
                if strings:
                    out[i] = ' '
            i += 1
    return ''.join(out)


def family(path):
    return next((name for name, prefix in FAMILIES.items()
                 if path == prefix or path.startswith(prefix + '/')), None)


def inventory(root=ROOT, max_files=LIMIT_FILES, max_bytes=LIMIT_BYTES):
    root = Path(root).resolve()
    paths = []
    for directory, suffix in (('code', '.dm'), ('config/crafting', '.txt')):
        base = root / directory
        if any((root / Path(*Path(directory).parts[:i])).is_symlink()
               for i in range(1, len(Path(directory).parts) + 1)):
            raise ValueError(f'symlinked source directory: {directory}')
        if not base.is_dir():
            raise ValueError(f'required source directory missing: {directory}')
        for path in base.rglob('*'):
            if path.is_symlink() or root not in path.resolve().parents:
                raise ValueError(f'source outside root or symlink: {path}')
            if not path.is_file() or path.suffix != suffix:
                continue
            paths.append(path)
            if len(paths) > max_files:
                raise ValueError('source file limit exceeded')
    declarations, references, review, manifest = [], [], [], []
    total = 0
    records = 0

    def append(destination, record):
        nonlocal records
        records += 1
        if records > LIMIT_RECORDS:
            raise ValueError('evidence record limit exceeded')
        destination.append(record)

    def excerpt(text):
        text = text.strip()
        return {'source': text[:EXCERPT_CHARS], 'source_truncated': len(text) > EXCERPT_CHARS}

    for path in sorted(paths):
        size = path.stat().st_size
        total += size
        if size > LIMIT_FILE_BYTES or total > max_bytes:
            raise ValueError('source byte limit exceeded')
        # Bounded read also protects against a file growing after stat.
        with path.open('rb') as source_file:
            data = source_file.read(LIMIT_FILE_BYTES + 1)
        if len(data) != size:
            raise ValueError(f'source changed while reading: {path}')
        source = data.decode('utf-8-sig')
        relative = path.relative_to(root).as_posix()
        manifest.append({'file': relative, 'sha256': hashlib.sha256(data).hexdigest()})
        text_lines = masked(source).splitlines()
        code_lines = masked(source, strings=True).splitlines()
        current = None
        factory = 'factory' in path.stem or '/factory/' in relative
        catalog = relative.startswith('config/crafting/')
        for number, (text, code) in enumerate(zip(text_lines, code_lines), 1):
            location = {'file': relative, 'line': number}
            if code and not code[0].isspace():
                current = None
                header = TYPE.fullmatch(code.strip())
                if header and family(header[0]):
                    current = dict(location, path=header[0], family=family(header[0]), assignments=[],
                                   inheritance={'status': 'unresolved',
                                                'lexical_parent_candidate': header[0].rsplit('/', 1)[0]})
                    append(declarations, current)
                elif code.startswith('/') and '(' not in code and any(p in code for p in FAMILIES.values()):
                    append(review, dict(location, reason='unsupported declaration syntax', **excerpt(text)))
            assignment = ASSIGNMENT.fullmatch(text)
            # Only one indentation level; procedure/local assignments are not defaults.
            direct = text.startswith('\t') and not text.startswith(('\t\t', '\t '))
            if current and direct and assignment and assignment[1] in FIELDS and '=' in code:
                append(current['assignments'], dict(location, field=assignment[1],
                    expression=assignment[2].strip()[:EXCERPT_CHARS],
                    expression_truncated=len(assignment[2].strip()) > EXCERPT_CHARS))
            if current and code.strip() and not code.startswith('\t') and code[0].isspace():
                append(review, dict(location, reason='space-indented declaration body; defaults not extracted'))
            if factory or catalog:
                seen = set()
                for match in TYPE.finditer(text if catalog else code):
                    if family(match[0]) and match[0] not in seen:
                        seen.add(match[0])
                        append(references, dict(location, path=match[0], family=family(match[0]),
                                               context='catalog' if catalog else 'factory', **excerpt(text)))
                if factory and re.search(r'\b(new|text2path|typesof|subtypesof)\b', code):
                    append(review, dict(location, reason='factory construction/type selection requires runtime review', **excerpt(text)))
            if code.lstrip().startswith(('#if', '#else', '#endif', '#include')):
                append(review, dict(location, reason='preprocessor context not evaluated', **excerpt(text)))
    counts = Counter(row['family'] for row in declarations)
    return {'schema_version': 1, 'scope': 'lexical source evidence only; no effective defaults, era or reachability proof',
            'limitations': ['All code/*.dm recursively, not the active DME include graph.',
                            'Only absolute standalone type headers and tab-indented direct assignments are extracted.',
                            'Repeated declarations are preserved; source order is not compiler include order.',
                            'Inheritance, macros, relative declarations, proc mutation and dynamic paths are unresolved.',
                            'No direct assignment does not mean a missing value; review parents and runtime initialization.',
                            'Factory references and catalogs are candidates, not confirmed recipes or acquisition routes.'],
            'summary': {'files': len(manifest), 'bytes': total, 'declaration_blocks': dict(sorted(counts.items())),
                        'references': len(references), 'review_items': len(review)},
            'sources': manifest, 'declarations': declarations, 'references': references, 'review': review}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--output', type=Path, help='JSON file; default stdout')
    args = parser.parse_args()
    try:
        result = json.dumps(inventory(args.root), indent=2) + '\n'
    except (OSError, UnicodeError, ValueError) as error:
        parser.exit(2, f'firearm inventory: {error}\n')
    if args.output:
        args.output.write_text(result, encoding='utf-8')
    else:
        print(result, end='')


if __name__ == '__main__':
    main()
