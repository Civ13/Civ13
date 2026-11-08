"""Run production explosion_remains.dm in a bounded offline BYOND world.

    python3 tests/explosion_remains/run.py --byond-bin <BYOND-516.1688-bin>
    python3 tests/explosion_remains/run.py --byond-bin <bin> --negative-control dirt
    python3 tests/explosion_remains/run.py --byond-bin <bin> --negative-control sky
    python3 tests/explosion_remains/run.py --static-only
"""
import argparse
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
CONTROLS = {
    # Earth remains above the ground: the reported Reichstag bug.
    'dirt': ([('\t\treturn /turf/floor/plating\n', '\t\treturn get_base_turf_by_area(src)\n')],
             ['upper floor leaves plating, not dirt', 'upper floor is never scorched to dirt',
              'building-level floor leaves plating', 'upper wall leaves plating']),
    # Open air that a blast may replace, with neither guard in place.
    'sky': ([('/turf/floor/broken_floor/ex_act(severity)\n\treturn FALSE\n', ''),
             ('\tif (building_open_turf(src))\n\t\treturn FALSE\n\tvar/remains', '\tvar/remains')],
            ['sky survives a blast']),
}


def read(path):
    return (ROOT / path).read_text(encoding='utf-8').replace('\r\n', '\n')


def extract(source, path):
    match = re.search(r'^' + re.escape(path) + r'\([^\n]*\)[^\n]*\n[\s\S]*?(?=^\S|\Z)', source, re.M)
    if not match:
        raise RuntimeError(f'Missing production procedure {path}')
    return match.group(0).rstrip() + '\n'


def static_checks():
    failures = []
    floor = read('code/game/turfs/floor.dm')
    if 'become_destroyed_turf()' not in extract(floor, '/turf/floor/proc/make_grass'):
        failures.append('make_grass must leave become_destroyed_turf() remains')
    plating = extract(read('code/game/turfs/floor_types.dm'), '/turf/floor/plating/ex_act')
    if plating.count('become_destroyed_turf()') != 2 or 'get_base_turf_by_area' in plating:
        failures.append('plating ex_act must use become_destroyed_turf()')
    if 'get_base_turf_by_area' in read('code/game/turfs/walls.dm'):
        failures.append('walls must use become_destroyed_turf()')
    for path in ('code/modules/projectiles/__projectiles.dm', 'code/modules/projectiles/projectile/cannon.dm'):
        if 'ChangeTurf(/turf/floor/dirt/burned)' in read(path):
            failures.append(f'{path} must scorch through scorch_ground()')
    dig = extract(read('code/game/turfs/floor_attackby.dm'), '/turf/floor/verb/Dig')
    shovel = read('code/modules/1713/tools.dm')
    if 'turf_is_above_ground(get_turf(user))' not in dig or 'turf_is_above_ground(get_turf(user))' not in shovel:
        failures.append('tunnel digging must refuse turfs above the ground')
    if '#include "code\\modules\\multiz\\explosion_remains.dm"' not in read('civ13.dme'):
        failures.append('explosion_remains.dm must be in civ13.dme')
    for failure in failures:
        print('FAIL ' + failure)
    return failures


def native(byond_bin, control):
    production = read('code/modules/multiz/explosion_remains.dm')
    if control:
        for old, new in CONTROLS[control][0]:
            if production.count(old) != 1:
                raise RuntimeError(f'{control} control anchor changed')
            production = production.replace(old, new)
    production += '\n' + extract(read('code/game/objects/building_levels.dm'), '/proc/building_open_turf')
    base = read('code/game/base_turf.dm')
    production += '\n' + extract(base, 'proc/get_base_turf') + '\n' + extract(base, 'proc/get_base_turf_by_area')
    production += '\nvar/global/list/base_turf_by_z = list("1" = /turf/floor/dirt)\n'
    compiler = byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    with tempfile.TemporaryDirectory(prefix='civ13-explosion-remains-') as directory:
        work = Path(directory)
        (work / 'production.dm').write_text(production, encoding='utf-8')
        (work / 'fixture.dm').write_text((Path(__file__).parent / 'fixture.dm').read_text(encoding='utf-8'), encoding='utf-8')
        (work / 'probe.dme').write_text('#include "fixture.dm"\n#include "production.dm"\n', encoding='utf-8')
        build = subprocess.run([str(compiler), '-max_errors', '0', 'probe.dme'], cwd=work,
                               capture_output=True, text=True, timeout=60, creationflags=flags)
        output = build.stdout + build.stderr
        if build.returncode or '0 errors, 0 warnings' not in output:
            print(output)
            raise RuntimeError('Fixture compilation failed')
        args = [str(daemon), 'probe.dmb'] + (['-invisible'] if os.name == 'nt' else []) + ['-trusted', '-log', 'runtime.log']
        result = subprocess.run(args, cwd=work, capture_output=True, text=True, timeout=30, creationflags=flags)
        log = (work / 'runtime.log').read_text(encoding='utf-8', errors='replace')
        print(log, flush=True)
        if result.returncode or re.search(r'runtime error:|Bad ref', log + result.stdout + result.stderr, re.I):
            raise RuntimeError('Native runtime diagnostics')
        if log.count('DONE explosion remains') != 1:
            raise RuntimeError('Fixture completion missing or duplicated')
        failures = re.findall(r'^FAIL (.+)$', log, re.M)
        if control:
            expected = CONTROLS[control][1]
            if failures != expected:
                raise RuntimeError(f'{control} control must fail exactly {expected!r}, got {failures!r}')
            print(f'PASS detected {control} control')
        elif failures or 'PASS explosion remains' not in log:
            raise RuntimeError('Explosion remains fixture failed')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--negative-control', choices=sorted(CONTROLS))
    parser.add_argument('--static-only', action='store_true')
    args = parser.parse_args()
    if static_checks():
        return 1
    print('PASS explosion remains wiring')
    if args.static_only:
        return 0
    if not args.byond_bin:
        parser.error('--byond-bin is required unless --static-only')
    native(args.byond_bin, args.negative_control)
    return 0


if __name__ == '__main__':
    sys.exit(main())
