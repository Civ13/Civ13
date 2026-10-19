"""Compile the normal-startup client fixture only; never run/bootstrap the game."""
import argparse
import json
from pathlib import Path
import subprocess

from compile_check import verify_log
from prepare_client_gather import prepare


def run(root, output, expected, byond_bin):
    source = prepare(root, output, expected)
    compiler = next((p for p in (Path(byond_bin) / 'DreamMaker', Path(byond_bin) / 'dm.exe') if p.is_file()), None)
    if compiler is None:
        raise ValueError('pinned compiler executable missing')
    log = Path(output) / 'compiler.log'
    with log.open('wb') as stream:
        result = subprocess.run([str(compiler.resolve()), '-max_errors', '0', 'client_gather.dme'],
                                cwd=source, stdout=stream, stderr=subprocess.STDOUT, timeout=180)
    if log.stat().st_size > 2097152:
        raise ValueError('compiler log exceeded review bound')
    verify_log(log.read_text(encoding='utf-8', errors='replace'), result.returncode)
    return {'commit': expected, 'compiler': '516.1681', 'errors': 0, 'warnings': 0,
            'runtime': 'not_run', 'ordinary_client_acceptance': 'not_run'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--expected-commit', required=True)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--evidence-dir', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(run(Path(__file__).resolve().parents[2], args.evidence_dir,
                         args.expected_commit, args.byond_bin)))


if __name__ == '__main__':
    main()
