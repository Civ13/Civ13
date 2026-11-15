"""Native fixture for mountain seams: compiles the real mountain_seams.dm,
resource_stock.dm and hex2num() against small stubs and runs it in
DreamDaemon. Checks seam ground rules, reveal markers, loads and regrowth,
age gates, bedrock stone and the pickaxe action, and that the DM hash matches
the Python mirror used by test_source.py.

    python3 tests/mountain_seams/native.py --byond-bin DIR
"""
import argparse
import hashlib
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


def hex2num():
    source = read('code/_helpers/type2type.dm')
    start = source.index('/proc/hex2num(hex)')
    end = re.search(r'\n(?=[/\w#])', source[start + 1:])
    return source[start:start + 1 + end.start()]


def run(byond_bin):
    win = os.name == 'nt'
    compiler = byond_bin / ('dm.exe' if win else 'DreamMaker')
    daemon = byond_bin / ('dd.exe' if win else 'DreamDaemon')
    seams = re.sub(r"'(sound/[^']+)'", r'"\1"', read('code/modules/1713/mountain_seams.dm'))
    with tempfile.TemporaryDirectory(prefix='civ13-mountain-seams-') as directory:
        temp = Path(directory)
        (temp / 'probe.dm').write_text((HERE / 'probe.dm').read_text(encoding='utf-8'), encoding='utf-8')
        (temp / 'stock.dm').write_text(read('code/_helpers/resource_stock.dm'), encoding='utf-8')
        (temp / 'hex.dm').write_text(hex2num() + '\n', encoding='utf-8')
        (temp / 'seams.dm').write_text(seams, encoding='utf-8')
        (temp / 'probe.dme').write_text(
            '#include "probe.dm"\n#include "stock.dm"\n#include "hex.dm"\n#include "seams.dm"\n', encoding='utf-8')
        built = subprocess.run([str(compiler), 'probe.dme'], cwd=temp, capture_output=True, text=True, timeout=120)
        print(built.stdout, end='')
        if built.returncode or '0 errors' not in built.stdout:
            return ['fixture compile failed: ' + built.stdout + built.stderr]
        subprocess.run([str(daemon), 'probe.dmb', '-invisible', '-trusted', '-log', 'runtime.log'],
                       cwd=temp, capture_output=True, timeout=120)
        log = (temp / 'runtime.log').read_text(encoding='utf-8', errors='replace')
    print(log, end='')
    failures = re.findall(r'^FAIL (.+)$', log, re.M)
    if re.search(r'runtime error', log, re.I):
        failures.append('runtime error in probe')
    for text, value in re.findall(r'^HASH (.+)=(\d+)$', log, re.M):
        expected = int(hashlib.md5(text.encode()).hexdigest()[:4], 16)
        if int(value) != expected:
            failures.append(f'DM hash of {text} is {value}, Python mirror says {expected}')
    if len(re.findall(r'^HASH ', log, re.M)) != 3:
        failures.append('hash parity lines missing')
    if 'PASS mountain seams probe' not in log:
        failures.append('probe did not pass')
    return failures


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', type=Path, required=True)
    failures = run(parser.parse_args().byond_bin)
    for failure in failures:
        print('FAIL', failure)
    return 1 if failures else 0


if __name__ == '__main__':
    sys.exit(main())
