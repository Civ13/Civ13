"""Native round trip for the map area exporter (code/modules/admin/map_area_export.dm).

1. A small world builds a scene and exports part of it with the real exporter.
2. DreamMaker compiles the exported .dmm as the map of a second world.
3. That world reports every tile; it must match the exported area with mobs,
   object contents, renames and runtime objects left out.

    python3 tests/map_area_export/run.py --byond-bin ~/byond-516.1688/byond/bin

Never downloads anything; works only in a temporary directory.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
EXPORTER = ROOT / 'code/modules/admin/map_area_export.dm'


def byond_env(bin_dir):
    env = dict(os.environ)
    if os.name != 'nt':
        env['LD_LIBRARY_PATH'] = os.pathsep.join(p for p in (str(bin_dir), env.get('LD_LIBRARY_PATH')) if p)
    return env


def compile_world(directory, includes, bin_dir):
    (directory / 'test.dme').write_text(''.join('#include "%s"\n' % name for name in includes), encoding='utf-8')
    maker = bin_dir / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    result = subprocess.run([str(maker), 'test.dme'], cwd=directory, capture_output=True, text=True, env=byond_env(bin_dir))
    if '- 0 errors, 0 warnings' not in result.stdout:
        raise AssertionError('compile failed in %s:\n%s%s' % (directory.name, result.stdout, result.stderr))


def run_world(directory, bin_dir):
    daemon = bin_dir / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    result = subprocess.run([str(daemon), 'test.dmb', '-trusted', '-invisible'], cwd=directory, capture_output=True,
                            text=True, env=byond_env(bin_dir), timeout=60)
    output = result.stdout + result.stderr
    if 'runtime error' in output:
        raise AssertionError('runtime error in %s:\n%s' % (directory.name, output))


def check(bin_dir):
    failures = []
    with tempfile.TemporaryDirectory(prefix='map-export-') as tmp:
        scene, compiled = Path(tmp) / 'scene', Path(tmp) / 'compiled'
        for directory in (scene, compiled):
            directory.mkdir()
            shutil.copy(HERE / 'stubs.dm', directory / 'stubs.dm')
        shutil.copy(EXPORTER, scene / 'map_area_export.dm')
        shutil.copy(HERE / 'scene.dm', scene / 'scene.dm')
        compile_world(scene, ['stubs.dm', 'map_area_export.dm', 'scene.dm'], bin_dir)
        run_world(scene, bin_dir)
        dmm = (scene / 'export.dmm').read_text(encoding='utf-8')
        report = json.loads((scene / 'report.json').read_text(encoding='utf-8'))
        expected = json.loads((scene / 'expected.json').read_text(encoding='utf-8'))

        shutil.copy(scene / 'export.dmm', compiled / 'export.dmm')
        shutil.copy(HERE / 'compiled.dm', compiled / 'compiled.dm')
        compile_world(compiled, ['stubs.dm', 'compiled.dm', 'export.dmm'], bin_dir)
        run_world(compiled, bin_dir)
        found = json.loads((compiled / 'found.json').read_text(encoding='utf-8'))

        if found != expected:
            for key in sorted(set(found) | set(expected)):
                if found.get(key) != expected.get(key):
                    failures.append('tile %s: expected %s, found %s' % (key, expected.get(key), found.get(key)))
        want = {'tiles': 12, 'width': 4, 'height': 3, 'objects': 5, 'mobs_left_out': 2, 'contents_left_out': 2,
                'renamed_objects_reset': 1, 'runtime_objects_left_out': 1}
        for key, value in want.items():
            if report.get(key) != value:
                failures.append('report %s: expected %s, got %s' % (key, value, report.get(key)))
        if '/obj/structure/chair{dir = 4; pixel_x = 4; pixel_y = -3}' not in dmm:
            failures.append('the chair model lost its fields:\n' + dmm)
        if 'player text' in dmm or '/mob/' in dmm or 'apple' in dmm or 'lighting_overlay' in dmm:
            failures.append('left-out content reached the map:\n' + dmm)
        if (scene / 'refusal.txt').read_text().strip() != 'refused':
            failures.append('corners on different levels were accepted')
    return failures


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--byond-bin', required=True, type=Path)
    args = parser.parse_args(argv)
    failures = check(args.byond_bin.expanduser())
    for failure in failures:
        print('FAIL: ' + failure)
    print('map area export round trip: %s' % ('failed' if failures else 'passed'))
    return 1 if failures else 0


if __name__ == '__main__':
    sys.exit(main())
