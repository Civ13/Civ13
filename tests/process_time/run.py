"""Compile extracted production dispatch/lifetimes with inert effect adapters."""
import argparse
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PROCS = {
    'code/processes/_process.dm': ['/process/proc/configured_interval_seconds'],
    'code/game/objects/objs.dm': ['/obj/proc/process_interval'],
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
            production.append(match[0])
    source = '\n'.join(production)
    if control == 'units':
        source = source.replace('schedule_interval / (1 SECOND)', 'schedule_interval')
    elif control == 'legacy':
        source = source.replace('return process()', 'return process(configured_seconds)')
    elif control == 'fuel':
        source = source.replace('fuel - configured_seconds / 2', 'fuel - 1')
    with tempfile.TemporaryDirectory(prefix='civ13-process-time-') as directory:
        temp = Path(directory)
        (temp / 'production.dm').write_text(source)
        (temp / 'fixture.dm').write_text((Path(__file__).parent / 'fixture.dm').read_text())
        (temp / 'probe.dme').write_text('#include "fixture.dm"\n#include "production.dm"\n')
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
        failed = result.returncode != 0 or 'FAIL ' in log
        if 'runtime error:' in log or (control and not failed) or (not control and (failed or 'PASS process time' not in log)):
            raise RuntimeError('Unexpected runtime result')
        print('Negative control detected' if control else 'Production regression passed')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--negative-control', choices=['units', 'legacy', 'fuel'])
    args = parser.parse_args()
    run(args.byond_bin.resolve(), args.negative_control)
