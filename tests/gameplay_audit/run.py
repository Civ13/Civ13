"""Gameplay audit regressions (2026-11-07 live Gaia audit).

Native: remove_reagent("ethanol") spends ethanol even when another reagent was
added first, and draws mixed alcohols in turn (the proc is extracted from the
real holder source). Source checks: mine cave-ins can still roll after the tile
has been dug out, the Me emote reaches custom_emote, wheels dragged onto
anything but a frame fall through to MouseDrop_T, and parenthesized `in`.

    python3 tests/gameplay_audit/run.py [--byond-bin DIR]
"""
import argparse
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def block(source, start):
    """The proc body that starts at `start`, up to the next top-level definition."""
    index = source.index(start)
    end = re.search(r'\n(?=[/\w])', source[index + len(start):])
    return source[index:index + len(start) + (end.start() if end else len(source))]


def source_checks():
    failures = []
    floor = read('code/game/turfs/floor_attackby.dm')
    if '/turf/floor/proc/mine_supported()' not in floor:
        failures.append('mine_supported must be a /turf/floor proc so a dug tile can answer')
    collapse = block(floor, '/turf/floor/dirt/underground/collapse_check()')
    if 'if (!istype(src, /turf/floor/dirt/underground))' in collapse:
        failures.append('collapse_check must not return just because the tile was dug out')
    if 'if (!istype(src, /turf/floor) || density)' not in collapse:
        failures.append('collapse_check should only skip a tile that is solid again')
    if 'range (1))' in collapse or 'in range(1, src))' not in collapse:
        failures.append('major cave-in must centre on the tile, not usr')
    emote = read('code/game/mob/living/carbon/human/emotes/emote.dm')
    me = emote[emote.index('\t\t\tif ("me")'):emote.index('\t\t\tif ("salute")')]
    if 'return custom_emote(m_type, message)' not in me:
        failures.append('the Me emote must show its message')
    wheel = read('code/modules/1713/machinery/modular_vehicles/movement.dm')
    drop = wheel[wheel.index('\tMouseDrop(var/obj/structure/vehicleparts/frame/VP)'):wheel.index('\tattackby(var/obj/item/I')]
    if not drop.rstrip().endswith('return ..()'):
        failures.append('a wheel dragged onto a non-frame must reach MouseDrop_T')
    for path, text in (('code/modules/1713/machinery/modular_vehicles/car_workshop.dm', '(action in list("Copy", "Rekey"))'),
                       ('code/modules/paperwork/lifecycle.dm', '(source in lifecycle_sources)')):
        if text not in read(path):
            failures.append(f'{path}: `in` must be parenthesized inside &&')
    return failures


def native(byond_bin):
    holder = read('code/modules/reagents/Chemistry-Holder.dm')
    proc = block(holder, '/datum/reagents/proc/remove_reagent(')
    win = os.name == 'nt'
    compiler = byond_bin / ('dm.exe' if win else 'DreamMaker')
    daemon = byond_bin / ('dd.exe' if win else 'DreamDaemon')
    with tempfile.TemporaryDirectory(prefix='civ13-gameplay-audit-') as directory:
        temp = Path(directory)
        (temp / 'probe.dm').write_text((HERE / 'ethanol_probe.dm').read_text(encoding='utf-8'), encoding='utf-8')
        (temp / 'holder.dm').write_text(proc, encoding='utf-8')
        (temp / 'probe.dme').write_text('#include "probe.dm"\n#include "holder.dm"\n', encoding='utf-8')
        built = subprocess.run([str(compiler), 'probe.dme'], cwd=temp, capture_output=True, text=True, timeout=120)
        print(built.stdout, end='')
        if built.returncode or '0 errors' not in built.stdout:
            return ['fixture compile failed: ' + built.stderr]
        subprocess.run([str(daemon), 'probe.dmb', '-invisible', '-trusted', '-log', 'runtime.log'],
                       cwd=temp, capture_output=True, timeout=60)
        log = (temp / 'runtime.log').read_text(encoding='utf-8', errors='replace')
        print(log, end='')
        failures = re.findall(r'^FAIL (.+)$', log, re.M)
        if re.search(r'runtime error', log, re.I):
            failures.append('runtime error in probe')
        if 'PASS gameplay audit ethanol' not in log:
            failures.append('probe did not pass')
        return failures


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', type=Path)
    args = parser.parse_args()
    failures = source_checks()
    if args.byond_bin:
        failures += native(args.byond_bin)
    for failure in failures:
        print('FAIL', failure)
    if failures:
        return 1
    print('PASS gameplay audit' + (' (source + native)' if args.byond_bin else ' (source)'))
    return 0


if __name__ == '__main__':
    sys.exit(main())
