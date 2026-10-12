"""Compile extracted production dispatch/lifetimes with inert effect adapters."""
import argparse
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PROCS = {
    'code/processes/_process.dm': ['/process/proc/configured_interval_seconds'],
    'code/game/objects/objs.dm': ['/obj/proc/process_interval', '/proc/object_interval_probability'],
    'code/processes/obj.dm': ['/process/obj/fire'],
    'code/modules/1713/punishment.dm': [
        '/obj/structure/noose/process', '/obj/structure/noose/process_interval', '/obj/structure/noose/proc/fire',
        '/obj/structure/gallows/process', '/obj/structure/gallows/process_interval', '/obj/structure/gallows/proc/fire'],
    'code/game/objects/items/weapons/candle.dm': [
        '/obj/item/weapon/flame/candle/process', '/obj/item/weapon/flame/candle/process_interval',
        '/obj/item/weapon/flame/candle/lard/process', '/obj/item/weapon/flame/candle/lard/process_interval'],
    'code/game/objects/items/weapons/cigs_lighters.dm': [
        '/obj/item/weapon/flame/match/process', '/obj/item/weapon/flame/match/process_interval'],
    'code/game/objects/items/devices/flashlight.dm': [
        '/obj/item/flashlight/flare/process', '/obj/item/flashlight/flare/process_interval'],
}

def run(byond, control):
    production = []
    for file, paths in PROCS.items():
        source = (ROOT / file).read_text()
        for path in paths:
            match = re.search(r'^' + re.escape(path) + r'\([^\n]*\)\n.*?(?=^/|\Z)', source, re.M | re.S)
            if not match:
                raise RuntimeError('Missing production proc ' + path)
            body = match[0]
            if file.endswith('punishment.dm'):
                body = body.replace('prob(', 'test_probability(')
                body = body.replace("'sound/effects/gore/bullethit3.ogg'", "'" + (ROOT / 'sound/effects/gore/bullethit3.ogg').as_posix() + "'")
            production.append(body)
    source = '\n'.join(production)
    if control == 'units':
        source = source.replace('schedule_interval / (1 SECOND)', 'schedule_interval')
    elif control == 'legacy':
        source = source.replace('return process()', 'return process(configured_seconds)')
    elif control == 'fuel':
        source = source.replace('fuel - configured_seconds / 2', 'fuel - 1')
    elif control == 'probability':
        source = source.replace('100 * (1 - (1 - percent / 100) ** (configured_seconds / 2))', 'percent')
    elif control == 'damage':
        source = source.replace('2.5 * configured_seconds', '5')
    elif control == 'dispatch':
        source = source.replace('O.process_interval(configured_interval_seconds())', 'O.process()')
    with tempfile.TemporaryDirectory(prefix='civ13-process-time-') as directory:
        temp = Path(directory)
        (temp / 'production.dm').write_text(source)
        (temp / 'defines.dm').write_text((ROOT / 'code/processes/___defines.dm').read_text())
        (temp / 'fixture.dm').write_text((Path(__file__).parent / 'fixture.dm').read_text())
        (temp / 'probe.dme').write_text('#include "defines.dm"\n#include "fixture.dm"\n#include "production.dm"\n')
        windows = (byond / 'dm.exe').exists()
        compile_result = subprocess.run([str(byond / ('dm.exe' if windows else 'DreamMaker')), 'probe.dme'], cwd=temp, capture_output=True, text=True, timeout=60)
        print(compile_result.stdout)
        if compile_result.returncode or '516.1681' not in compile_result.stdout or '0 errors, 0 warnings' not in compile_result.stdout:
            raise RuntimeError('Compilation failed')
        try:
            result = subprocess.run([str(byond / ('dd.exe' if windows else 'DreamDaemon')), 'probe.dmb', '-invisible', '-safe', '-log', 'runtime.log'], cwd=temp, capture_output=True, text=True, timeout=20)
        except subprocess.TimeoutExpired:
            print((temp / 'runtime.log').read_text())
            raise
        log = (temp / 'runtime.log').read_text()
        print(log)
        expected_failures = {
            'units': 'FAIL deciseconds conversion',
            'legacy': 'FAIL legacy received time as actor',
            'fuel': 'FAIL fractional flare lifetime',
            'probability': 'FAIL probability survival composition',
            'damage': 'FAIL fractional damage rate',
            'dispatch': 'FAIL production loop seconds dispatch',
        }
        if (result.returncode != 0 or re.search(r'runtime error:|Bad ref|CRASH', log, re.I)
                or 'PASS process time' not in log
                or (control and expected_failures[control] not in log)
                or (not control and 'FAIL ' in log)):
            raise RuntimeError('Unexpected runtime result')
        print('Negative control detected' if control else 'Production regression passed')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--negative-control', choices=['units', 'legacy', 'fuel', 'probability', 'damage', 'dispatch'])
    args = parser.parse_args()
    run(args.byond_bin.resolve(), args.negative_control)
