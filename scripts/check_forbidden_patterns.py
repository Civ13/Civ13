"""Forbidden source patterns with a per-file ratchet baseline; no BYOND runtime.

Modelled on the grep checks CM-SS13 runs in CI (tools/ci/check_grep.sh in
cmss13-devs/cmss13, AGPL-3.0), rewritten for Civ13's offline baseline. Each
pattern names a bug class Civ13 has already paid for. Existing occurrences are
recorded per file in tools/lint/forbidden_patterns_baseline.json; a file may
only lower its count. New files and raised counts fail with the offending lines.

    python3 scripts/check_forbidden_patterns.py            # check against the baseline
    python3 scripts/check_forbidden_patterns.py --write    # lower the baseline to today
    python3 scripts/check_forbidden_patterns.py --report   # counts per pattern only
"""
import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASELINE = ROOT / 'tools/lint/forbidden_patterns_baseline.json'
SOURCE_DIRS = ('code',)
MAP_DIRS = ('maps',)

# name: (description, file kind, matcher). A matcher takes the file text and
# returns (line_number, line) pairs. Comment-only matches are ignored for .dm.
PATTERNS = {
    'spawn': ('spawn() keeps a sleeping proc alive across freeze/resume and cannot be '
              'cancelled; prefer addtimer(CALLBACK(...)) or a /process',
              'dm', re.compile(r'(?<![\w.])spawn\s*\(')),
    'in_world': ('"in world" walks every atom in the game; use a typed global list '
                 'or a /process list',
                 'dm', re.compile(r'\bin\s+world\s*\)')),
    'wwinput_untyped_result': ('WWinput() with no type or choices argument is an alert that '
                               'returns TRUE; its result is not a choice (issue #3748)',
                               'dm', None),
    'merge_marker': ('Unresolved merge conflict marker', 'any',
                     re.compile(r'^(<<<<<<< |>>>>>>> )')),
}
WWINPUT_USE = re.compile(r'(=|==|!=|\bif\s*\(|\breturn\b|\bswitch\s*\(|\|\||&&|!)\s*WWinput\s*\(')
WWINPUT_CALL = re.compile(r'WWinput\s*\(')


def strip_comment(line):
    """Drop a trailing // comment and blank the inside of string literals.

    Blanked strings keep their length, so columns and the quotes themselves
    survive; only the text between the quotes becomes spaces.
    """
    out = []
    quote = None
    index = 0
    while index < len(line):
        char = line[index]
        if quote:
            if char == '\\':
                out.append('  ')
                index += 2
                continue
            if char == quote:
                quote = None
                out.append(char)
            else:
                out.append(' ')
        elif char in ('"', "'"):
            quote = char
            out.append(char)
        elif line.startswith('//', index):
            break
        else:
            out.append(char)
        index += 1
    return ''.join(out)


def code_lines(text):
    """Yield (number, line) with // and /* */ comments removed."""
    in_block = False
    for number, raw in enumerate(text.splitlines(), 1):
        line = raw
        if in_block:
            end = line.find('*/')
            if end < 0:
                continue
            line = line[end + 2:]
            in_block = False
        while True:
            start = line.find('/*')
            if start < 0:
                break
            end = line.find('*/', start + 2)
            if end < 0:
                line = line[:start]
                in_block = True
                break
            line = line[:start] + line[end + 2:]
        yield number, strip_comment(line)


def call_arguments(text, start):
    """Count the arguments of the call whose opening parenthesis is at text[start].

    Returns (count, complete). Nested parentheses, brackets and string literals
    are skipped; an unterminated call (spanning more lines than were given) is
    reported as incomplete.
    """
    depth = 0
    count = 0
    seen = False
    quote = None
    index = start
    while index < len(text):
        char = text[index]
        if quote:
            if char == '\\':
                index += 1
            elif char == quote:
                quote = None
        elif char in ('"', "'"):
            quote = char
        elif char in '([{':
            depth += 1
        elif char in ')]}':
            depth -= 1
            if depth == 0:
                return (count + 1 if seen else 0), True
        elif depth == 1 and char == ',':
            count += 1
        elif depth == 1 and not char.isspace():
            seen = True
        index += 1
    return count, False


def wwinput_matches(text):
    """WWinput calls whose result is used although fewer than five arguments are given."""
    lines = list(code_lines(text))
    hits = []
    for position, (number, line) in enumerate(lines):
        if not WWINPUT_USE.search(line):
            continue
        call = WWINPUT_CALL.search(line)
        window = line
        extra = 0
        count, complete = call_arguments(window, call.end() - 1)
        while not complete and extra < 6 and position + extra + 1 < len(lines):
            extra += 1
            window += '\n' + lines[position + extra][1]
            count, complete = call_arguments(window, call.end() - 1)
        if complete and count < 5:
            hits.append((number, line.strip()))
    return hits


def regex_matches(text, regex, kind):
    source = code_lines(text) if kind == 'dm' else enumerate(text.splitlines(), 1)
    return [(number, line.strip()) for number, line in source if regex.search(line)]


def files_for(kind, root=ROOT):
    if kind == 'dm':
        yield from (root / 'civ13.dme',) if (root / 'civ13.dme').is_file() else ()
        for directory in SOURCE_DIRS:
            yield from sorted((root / directory).rglob('*.dm'))
    elif kind == 'dmm':
        for directory in MAP_DIRS:
            yield from sorted((root / directory).rglob('*.dmm'))
    else:
        yield from files_for('dm', root)
        yield from files_for('dmm', root)


def scan(root=ROOT):
    """Return {pattern: {relative path: [(line, text), ...]}} for every hit."""
    hits = {name: {} for name in PATTERNS}
    cache = {}
    for name, (_, kind, regex) in PATTERNS.items():
        for path in files_for(kind, root):
            if path not in cache:
                cache[path] = path.read_text(encoding='utf-8', errors='replace')
            text = cache[path]
            if name == 'wwinput_untyped_result':
                found = wwinput_matches(text)
            else:
                found = regex_matches(text, regex, 'dm' if path.suffix in ('.dm', '.dme') else 'any')
            if found:
                hits[name][path.relative_to(root).as_posix()] = found
    return hits


def counts(hits):
    return {name: {path: len(lines) for path, lines in sorted(files.items())}
            for name, files in hits.items()}


def load_baseline(path=BASELINE):
    if not path.is_file():
        return {name: {} for name in PATTERNS}
    data = json.loads(path.read_text(encoding='utf-8'))
    return {name: dict(data.get('patterns', {}).get(name, {})) for name in PATTERNS}


def compare(hits, baseline):
    """Return (violations, lowered). A violation is (pattern, path, allowed, lines)."""
    violations = []
    lowered = []
    current = counts(hits)
    for name in PATTERNS:
        for path, count in current[name].items():
            allowed = baseline[name].get(path, 0)
            if count > allowed:
                violations.append((name, path, allowed, hits[name][path]))
            elif count < allowed:
                lowered.append((name, path, allowed, count))
        for path, allowed in baseline[name].items():
            if path not in current[name]:
                lowered.append((name, path, allowed, 0))
    return violations, lowered


def write_baseline(hits, path=BASELINE):
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        'schema': 1,
        'note': 'Per-file counts of forbidden source patterns. A file may only lower its count; '
                'regenerate with python3 scripts/check_forbidden_patterns.py --write.',
        'patterns': counts(hits),
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=False) + '\n', encoding='utf-8')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--write', action='store_true', help='rewrite the baseline to the current counts')
    parser.add_argument('--report', action='store_true', help='print totals per pattern and exit')
    parser.add_argument('--root', default=str(ROOT))
    parser.add_argument('--baseline', default=str(BASELINE))
    args = parser.parse_args(argv)
    root = Path(args.root)
    hits = scan(root)
    totals = {name: sum(len(lines) for lines in files.values()) for name, files in hits.items()}
    if args.report:
        for name, total in totals.items():
            print(f'{name}: {total} in {len(hits[name])} files')
        return 0
    baseline_path = Path(args.baseline)
    violations, lowered = compare(hits, load_baseline(baseline_path))
    if args.write:
        write_baseline(hits, baseline_path)
        print(f'Wrote {baseline_path.relative_to(root) if baseline_path.is_relative_to(root) else baseline_path}: '
              + ', '.join(f'{name}={total}' for name, total in totals.items()))
        return 0
    for name, path, allowed, lines in violations:
        print(f'{name}: {path} has {len(lines)} occurrence(s), baseline allows {allowed}')
        print('  ' + PATTERNS[name][0])
        for number, line in lines[:20]:
            print(f'  {path}:{number}: {line}')
    if lowered:
        print(f'{len(lowered)} baseline row(s) can be lowered: run --write to record the improvement')
    if violations:
        print(f'{len(violations)} forbidden-pattern violation(s)')
        return 1
    print('No new forbidden patterns: ' + ', '.join(f'{name}={total}' for name, total in totals.items()))
    return 0


if __name__ == '__main__':
    sys.exit(main())
