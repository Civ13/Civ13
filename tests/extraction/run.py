"""Pinned BYOND production account journal checks in isolated temporary storage."""
import argparse
from pathlib import Path
import os
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    binary = args.byond_bin.resolve()
    compiler = binary / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = binary / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    with tempfile.TemporaryDirectory(prefix='civ13-extraction-') as temp:
        target = Path(temp)
        (target / 'tests/extraction').mkdir(parents=True)
        (target / 'code/modules/1713/extraction').mkdir(parents=True)
        shutil.copy2(root / 'tests/extraction/store_probe.dm', target / 'tests/extraction/store_probe.dm')
        shutil.copy2(root / 'code/modules/1713/extraction/account_store.dm', target / 'code/modules/1713/extraction/account_store.dm')
        (target / 'probe.dme').write_text('#include "tests/extraction/store_probe.dm"\n', encoding='utf-8')
        built = subprocess.run([str(compiler), '-max_errors', '0', 'probe.dme'], cwd=target,
                               capture_output=True, text=True, timeout=60, creationflags=flags)
        print(built.stdout + built.stderr)
        if built.returncode or '516.1681' not in built.stdout or '0 errors, 0 warnings' not in built.stdout:
            raise RuntimeError('Pinned compile failed')
        platform = ['-invisible', '-close'] if os.name == 'nt' else []
        ran = subprocess.run([str(daemon), 'probe.dmb', *platform, '-safe', '-log', 'runtime.log'],
                             cwd=target, capture_output=True, text=True, timeout=45, creationflags=flags)
        result = (target / 'result.txt').read_text().strip() if (target / 'result.txt').exists() else 'MISSING'
        log = (target / 'runtime.log').read_text(errors='replace') if (target / 'runtime.log').exists() else ''
        print(result)
        if ran.returncode or not result.startswith('PASS:') or any(x in log.lower() for x in ('runtime error', 'bad ref', '## error')):
            print(log)
            raise RuntimeError('Account journal verification failed')


if __name__ == '__main__':
    main()
