"""Extract production radiation procedures into a bounded offline BYOND fixture."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import tempfile


def extract(source, path):
    match = re.search(r'^' + re.escape(path) + r'\([^\n]*\)[^\n]*\n[\s\S]*?(?=^/|\Z)', source, re.M)
    if not match:
        raise RuntimeError(f'Missing production procedure {path}')
    return match.group(0).rstrip()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--negative-control', choices=('cross-z', 'normalization'))
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    source = (root / 'code/modules/1713/radiation.dm').read_text(encoding='utf-8')
    paths = ['/proc/nuke_map', '/proc/radiation_pulse', '/atom/proc/rad_act',
             '/turf/floor/rad_act', '/turf/floor/grass/rad_act',
             '/turf/floor/beach/water/rad_act', '/mob/living/rad_act',
             '/mob/living/human/rad_act', '/mob/living/human/proc/getarmor_rad']
    production = '\n\n'.join(extract(source, path) for path in paths)
    if args.negative_control == 'cross-z':
        if production.count('if (W.z == event_z)') != 2:
            raise RuntimeError('Window/wild control anchors changed')
        production = production.replace('if (W.z == event_z)', 'if (TRUE)')
    elif args.negative_control == 'normalization':
        anchor = '\tepicenter = get_turf(epicenter)\n'
        if production.count(anchor) != 1:
            raise RuntimeError('Normalization control anchor changed')
        production = production.replace(anchor, '', 1)
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    with tempfile.TemporaryDirectory(prefix='civ13-radiation-scope-') as directory:
        work = Path(directory)
        (work / 'production.dm').write_text(production, encoding='utf-8')
        (work / 'fixture.dm').write_text((Path(__file__).parent / 'fixture.dm').read_text(encoding='utf-8'), encoding='utf-8')
        (work / 'probe.dme').write_text('#include "fixture.dm"\n#include "production.dm"\n', encoding='utf-8')
        build = subprocess.run([str(compiler), '-max_errors', '0', 'probe.dme'], cwd=work,
                               capture_output=True, text=True, timeout=60, creationflags=flags)
        output = build.stdout + build.stderr
        print(output, flush=True)
        if build.returncode or not re.search(r'DM compiler version 516\.1681\b', output) or '0 errors, 0 warnings' not in output:
            raise RuntimeError('Pinned fixture compilation failed')
        result = subprocess.run([str(daemon), 'probe.dmb', '-invisible', '-safe', '-log', 'runtime.log'],
                                cwd=work, capture_output=True, text=True, timeout=20, creationflags=flags)
        output = (work / 'runtime.log').read_text(encoding='utf-8', errors='replace') + result.stdout + result.stderr
        print(output, flush=True)
        failed = result.returncode or re.search(r'runtime error:|FAIL |Bad ref', output, re.I) or 'PASS radiation scope' not in output
        if args.negative_control:
            if not failed or 'FAIL ' not in output:
                raise RuntimeError('Negative control did not fail a fixture assertion')
            print(f'PASS detected {args.negative_control} control')
        elif failed:
            raise RuntimeError('Radiation scope fixture failed')


if __name__ == '__main__':
    main()
