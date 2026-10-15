"""Recheck retained Europe receipts offline; never overwrite the native result."""
import argparse
import json
from pathlib import Path

from run import compare, diagnostic_failures, verify_completed_files


def replay(root):
    for relative in ('daemon.stdout.log', 'daemon.stderr.log', 'game/native.log'):
        if not (root / relative).is_file():
            raise FileNotFoundError(f'Incomplete diagnostic evidence: {relative}')
    game = root / 'game'
    before = json.loads((root / 'before.json').read_text(encoding='utf-8'))
    after = json.loads((root / 'after.json').read_text(encoding='utf-8'))
    receipt = json.loads((game / 'full-map-before-reboot.json').read_text(encoding='utf-8'))
    compare(before, after, receipt)
    verify_completed_files(game, receipt)
    failures = diagnostic_failures(root)
    return {'scope': 'Retained-artifact replay; no new native execution',
            'source_commit': after['source'], 'generation': after['generation'],
            'functional_checks_passed': True, 'clean_diagnostics_passed': not failures,
            'diagnostics': failures}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run_root', type=Path)
    args = parser.parse_args()
    result = replay(args.run_root)
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result['clean_diagnostics_passed'] else 1)
