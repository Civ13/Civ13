#!/usr/bin/env python3
"""Lint Civ13 .dmm maps with the mapmerge2 parser.

Errors (exit 1): the map does not parse, contains merge-conflict markers, or a
used tile entry has no turf, more than one area, an area that is not last, or a
path outside /obj, /mob, /turf and /area.

Warnings (reported, never fatal): an object listed after a turf (an underlay
stack), more than one turf in a tile, or an /obj/item on a wall turf.

The rules are a trimmed adaptation of CM-SS13's tools/maplint
(https://github.com/cmss13-devs/cmss13, AGPL-3.0). Civ13 maps routinely
var-edit areas and stack duplicate objects, so CM's lints for those are left out.

Usage:
  python3 scripts/maplint.py                  # every map under maps/
  python3 scripts/maplint.py FILE.dmm ...     # only these maps
  python3 scripts/maplint.py --changed BASE   # maps changed since git BASE
  add --github for workflow annotations, --warnings to print warnings
"""

import argparse
import concurrent.futures
import contextlib
import io
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))

from mapmerge2 import dmm  # noqa: E402

CONFLICT_MARKERS = ('<<<<<<<', '>>>>>>>', '|||||||')
RANK = (('/obj', 0), ('/mob', 0), ('/turf', 1), ('/area', 2))


def rank(path):
    for prefix, value in RANK:
        if path == prefix or path.startswith(prefix + '/'):
            return value
    return None


def lint_entry(entry):
    """Return (errors, warnings) for one tile entry tuple."""
    errors, warnings = [], []
    types = [p.split('{', 1)[0] for p in entry]
    ranks = [rank(t) for t in types]
    unknown = [t for t, r in zip(types, ranks) if r is None]
    if unknown:
        errors.append('path outside /obj, /mob, /turf, /area: ' + ', '.join(unknown))
        return errors, warnings
    turfs = [t for t, r in zip(types, ranks) if r == 1]
    areas = [t for t, r in zip(types, ranks) if r == 2]
    if not turfs:
        errors.append('tile has no turf')
    if len(areas) > 1:
        errors.append('tile has %d areas' % len(areas))
    if areas and ranks[-1] != 2:
        errors.append('area is not the last entry')
    if len(turfs) > 1:
        warnings.append('tile stacks %d turfs' % len(turfs))
    if ranks != sorted(ranks):
        warnings.append('object listed after a turf')
    if turfs and turfs[-1].startswith('/turf/wall') and any(t.startswith('/obj/item') for t in types):
        warnings.append('item on a wall turf')
    return errors, warnings


def lint_file(path):
    """Return (errors, warnings) as lists of (key or None, message)."""
    text = pathlib.Path(path).read_text(encoding='utf-8', errors='replace')
    for number, line in enumerate(text.splitlines(), 1):
        if line.startswith(CONFLICT_MARKERS):
            return [(None, 'merge-conflict marker on line %d' % number)], []
    try:
        with contextlib.redirect_stdout(io.StringIO()):  # parser prints notices
            parsed = dmm.DMM.from_file(str(path))
    except Exception as exc:  # the parser raises plain ValueError/KeyError
        return [(None, 'does not parse: %s' % exc)], []
    used = set(parsed.grid.values())
    errors, warnings = [], []
    for key, entry in sorted(parsed.dictionary.items()):
        if key not in used:
            continue
        name = dmm.num_to_key(key, parsed.key_length)
        entry_errors, entry_warnings = lint_entry(entry)
        errors += [(name, m) for m in entry_errors]
        warnings += [(name, m) for m in entry_warnings]
    return errors, warnings


def changed_maps(base):
    out = subprocess.check_output(
        ['git', 'diff', '--name-only', '--diff-filter=ACMR', base, '--', '*.dmm'],
        cwd=ROOT, text=True)
    return [ROOT / line for line in out.splitlines() if line.strip()]


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('files', nargs='*')
    parser.add_argument('--changed', metavar='BASE')
    parser.add_argument('--github', action='store_true')
    parser.add_argument('--warnings', action='store_true')
    args = parser.parse_args(argv)
    if args.changed:
        files = changed_maps(args.changed)
    elif args.files:
        files = [pathlib.Path(f) for f in args.files]
    else:
        files = sorted((ROOT / 'maps').rglob('*.dmm'))
    error_count = warning_count = 0
    if len(files) > 8:
        with concurrent.futures.ProcessPoolExecutor() as pool:
            results = list(pool.map(lint_file, files, chunksize=4))
    else:
        results = [lint_file(path) for path in files]
    for path, (errors, warnings) in zip(files, results):
        try:
            shown = path.resolve().relative_to(ROOT).as_posix()
        except ValueError:
            shown = str(path)
        for level, items in (('error', errors), ('warning', warnings if args.warnings else [])):
            for key, message in items:
                where = ' key "%s"' % key if key else ''
                if args.github:
                    print('::%s file=%s::%s%s' % (level, shown, message, where))
                else:
                    print('%s: %s:%s %s' % (level, shown, where, message))
        error_count += len(errors)
        warning_count += len(warnings)
    print('maplint: %d map(s), %d error(s), %d warning(s)' % (len(files), error_count, warning_count))
    return 1 if error_count else 0


if __name__ == '__main__':
    sys.exit(main())
