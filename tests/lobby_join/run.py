"""Run the closed-port Join control fixture in temporary offline storage."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

from prepare import stage


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', required=True, type=Path)
    args = parser.parse_args()
    binary = args.byond_bin.resolve()
    compiler = binary / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = binary / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    root = Path(tempfile.mkdtemp(prefix='civ13-join-'))
    work = root / 'control'
    print(f'Isolated Join evidence: {root}', flush=True)
    stage(work)
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    phases = (
        ('compile', [str(compiler), '-max_errors', '0', 'control.dme']),
        ('runtime', [str(daemon), 'control.dmb', *(['-invisible', '-close'] if os.name == 'nt' else []),
                     '-safe', '-log', 'native.log']),
    )
    for name, command in phases:
        try:
            result = subprocess.run(command, cwd=work, capture_output=True, text=True,
                                    timeout=45, creationflags=flags)
        except subprocess.TimeoutExpired as error:
            (root / (name + '.stdout.log')).write_bytes(error.stdout or b'')
            (root / (name + '.stderr.log')).write_bytes(error.stderr or b'')
            raise
        output = result.stdout + result.stderr
        (root / (name + '.log')).write_text(output)
        if result.returncode or re.search(r'BUG:|runtime error:|fatal error|segmentation', output, re.I):
            raise RuntimeError(f'{name} failed: {output}')
        if name == 'compile' and ('516.1681' not in output or '0 errors, 0 warnings' not in output):
            raise RuntimeError('Pinned warning-free compiler result absent')
    native_log = work / 'native.log'
    if native_log.exists() and re.search(r'BUG:|runtime error:|fatal error|segmentation', native_log.read_text(), re.I):
        raise RuntimeError('Native runtime diagnostics invalidate the result')
    result = json.loads((work / 'result.json').read_text())
    required = {'negative_control_stale_round_detected', 'negative_control_stale_role_detected',
                'native_join_verb_visible', 'negative_control_invisible_verb_detected',
                'engine_explicit_zero_metadata', 'engine_nonzero_metadata',
                'negative_control_inherited_verb_detected',
                'normal_cleanup', 'duplicate_locked', 'exception_cleanup'}
    if not result.get('pass') or result.get('failures') or result.get('port') or not required <= set(result['checks']):
        raise RuntimeError(f'Join control assertions failed: {result}')
    print(json.dumps(result))


if __name__ == '__main__':
    main()
