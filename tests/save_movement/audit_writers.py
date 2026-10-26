"""Inventory residual direct location writes for review; never calls native tools.

An inventory is not an acceptance test. It deliberately includes benign local,
constructor, nullspace and renderer writes without guessing their runtime types.
Dynamic vars/list edits and arbitrary admin proc calls need separate review.
"""
import argparse
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
WRITE = re.compile(r'^\s+(?:(\w+(?:\.\w+)*)\.)?(loc|z|pixloc)\s*(?:=(?!=)|[+-]=)')


def inventory():
    rows = []
    for path in sorted((ROOT / 'code').rglob('*.dm')):
        declaration = ''
        for number, line in enumerate(path.read_text(encoding='utf-8-sig').splitlines(), 1):
            if line.startswith('/') and not line.startswith('//'):
                declaration = line
            code = line.split('//', 1)[0]
            if WRITE.match(code):
                rows.append(dict(path=path.relative_to(ROOT).as_posix(), line=number,
                                 declaration=declaration, statement=code.strip()))
    return dict(scope=__doc__, universal_coverage_verified=False,
                direct_writer_count=len(rows), direct_writers=rows)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    result = inventory()
    if args.output:
        args.output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(f"Residual direct writer statements: {result['direct_writer_count']}; universal coverage unverified")
