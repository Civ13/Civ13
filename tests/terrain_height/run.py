"""Compile and run the terrain height probe against the committed sources.

Usage: python3 tests/terrain_height/run.py --byond-bin <dir with DreamMaker/DreamDaemon>
"""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[2]
WANTED = ['civ13.dme', 'code', 'icons', 'sound', 'UI', 'interface', 'config', 'tests/terrain_height']


def isolate(stage):
    world = stage / 'code/world.dm'
    text = world.read_text(encoding='utf-8')
    start = text.index('/world/New()')
    parent = text.index('\n\t..()', start)
    text = text[:parent] + text[parent:].replace('\n\t..()', '', 1)
    text = text.replace('/world/New()', '/world/proc/unused_terrain_height_startup()', 1)
    marker = '/datum/global_init/New()\n'
    if text.count(marker) != 1:
        raise RuntimeError('Startup isolation anchor drift: code/world.dm')
    world.write_text(text.replace(marker, marker + '\treturn\n', 1), encoding='utf-8')
    globals_dm = stage / 'code/controllers/mc/globals.dm'
    text = globals_dm.read_text(encoding='utf-8')
    marker = '/datum/controller/global_vars/New()\n'
    if text.count(marker) != 1:
        raise RuntimeError('Startup isolation anchor drift: globals.dm')
    globals_dm.write_text(text.replace(marker, marker + '\treturn\n', 1), encoding='utf-8')
    dme = stage / 'civ13.dme'
    lines = [line for line in dme.read_text(encoding='utf-8').splitlines()
             if not re.match(r'#include "maps[\\/].*\.dmm"', line)]
    lines.append('#include "tests\\terrain_height\\probe.dm"')
    dme.write_text('\n'.join(lines) + '\n', encoding='utf-8')


def compare_lights(work):
    """The game's corner lights must match the tool's, which baked the sprites."""
    import importlib.util
    import numpy
    spec = importlib.util.spec_from_file_location('terrain_heights', ROOT / 'scripts/terrain_heights.py')
    tool = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(tool)
    _, _, levels = tool.read_heights(ROOT / 'tests/terrain_height/fixture.txt')
    expected = [''.join(tool.SHADE_KEYS[v + 2] for v in row) for row in tool.corner_lights(numpy, levels[1])]
    path = work / 'lights.txt'
    actual = path.read_text(encoding='ascii').strip().split('\n') if path.exists() else []
    return 'PASS' if actual == expected else f'FAIL lights differ: game {actual} tool {expected}'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--keep', action='store_true')
    args = parser.parse_args()
    work = Path(tempfile.mkdtemp(prefix='civ13-terrain-height-'))
    try:
        archive = subprocess.Popen(['git', '-C', str(ROOT), 'archive', '--format=tar', 'HEAD', '--', *WANTED],
                                   stdout=subprocess.PIPE)
        with tarfile.open(fileobj=archive.stdout, mode='r|') as tar:
            tar.extractall(work, filter='data')
        if archive.wait() != 0:
            raise RuntimeError('git archive failed')
        isolate(work)
        compiled = subprocess.run([str(args.byond_bin / 'DreamMaker'), '-max_errors', '0', 'civ13.dme'],
                                  cwd=work, capture_output=True, text=True)
        if compiled.returncode != 0 or not re.search(r'\b0 errors, 0 warnings', compiled.stdout + compiled.stderr):
            print(compiled.stdout[-4000:], compiled.stderr[-4000:])
            return 1
        subprocess.run([str(args.byond_bin / 'DreamDaemon'), 'civ13.dmb', '-trusted', '-invisible'],
                       cwd=work, capture_output=True, timeout=300)
        result = (work / 'result.txt').read_text(encoding='utf-8').strip() if (work / 'result.txt').exists() else 'FAIL no result'
        receipt = json.loads((work / 'receipt.json').read_text(encoding='utf-8')) if (work / 'receipt.json').exists() else {}
        print(result, json.dumps(receipt))
        if result == 'PASS':
            result = compare_lights(work)
            print(result)
        return 0 if result == 'PASS' else 1
    finally:
        if args.keep:
            print(f'Kept {work}')
        else:
            shutil.rmtree(work, ignore_errors=True)


if __name__ == '__main__':
    raise SystemExit(main())
