"""Compile supported hub selections without running the deployment launcher."""
import argparse
import importlib.util
import os
from pathlib import Path
import subprocess
import uuid


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    spec = importlib.util.spec_from_file_location('map_environment', root / 'scripts/map_environment.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    compiler = args.byond_bin.resolve() / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    source = (root / 'civ13.dme').read_text(encoding='utf-8')
    for selection in ('maps/extraction/industrial_district.dmm', 'maps/2013/alleyway.dmm', 'maps/1969/bank_robbery.dmm'):
        prefix = root / ('.extraction_catalog_' + uuid.uuid4().hex)
        try:
            prefix.with_suffix('.dme').write_text(module.select_map(source, selection), encoding='utf-8')
            result = subprocess.run([str(compiler), '-max_errors', '0', prefix.name + '.dme'],
                                    cwd=root, capture_output=True, text=True, timeout=90,
                                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
            output = result.stdout + result.stderr
            if result.returncode or '516.1681' not in output or '0 errors, 0 warnings' not in output:
                print(output)
                raise RuntimeError('Catalog compile failed: ' + selection)
            print('PASS: pinned catalog compile ' + selection)
        finally:
            for suffix in ('.dme', '.dmb', '.rsc'):
                prefix.with_suffix(suffix).unlink(missing_ok=True)


if __name__ == '__main__':
    main()
