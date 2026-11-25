"""Run the production bench and touch procs with controlled wizard/wait boundaries."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BENCH = '/obj/structure/workshop_machine/glass_bench'


def project(source, declaration):
    match = re.search(rf'(?m)^{re.escape(declaration)}\([^\n]*\)[^\n]*\n(?:(?:\t[^\n]*|)\n)*', source)
    if not match:
        raise ValueError(f'missing production definition: {declaration}')
    return match.group()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    args = parser.parse_args()
    source = (ROOT / 'code/modules/1713/glass_stone_machines.dm').read_text()
    adjacent = (ROOT / 'code/_onclick/adjacent.dm').read_text()
    persistence = (ROOT / 'code/modules/persistence/functions.dm').read_text()
    code = '\n'.join([
        *[project(source, BENCH + path) for path in
          ('/attackby', '/proc/glory_hole', '/proc/glass_worker_ready', '/proc/blow_wares')],
        *[project(adjacent, path) for path in
          ('/atom/proc/Adjacent', '/atom/movable/Adjacent', '/turf/Adjacent', '/turf/proc/ClickCross')],
        project(persistence, '/proc/persistence_admission_changed'),
    ])
    byond = args.byond_bin.resolve()
    with tempfile.TemporaryDirectory(prefix='glass-bench-') as folder:
        directory = Path(folder)
        (directory / 'production.dm').write_text(code)
        (directory / 'fixture.dm').write_text((HERE / 'bench_probe.dm').read_text())
        (directory / 'bench.dme').write_text('#include "fixture.dm"\n#include "production.dm"\n')
        for name, flags, timeout in (
            ('dm.exe' if os.name == 'nt' else 'DreamMaker', ['bench.dme'], 60),
            ('dd.exe' if os.name == 'nt' else 'DreamDaemon',
             ['bench.dmb', '-ip', '127.0.0.1', '-nowebclient', '-safe', '-invisible', '-close'], 30),
        ):
            run = subprocess.run([str(byond / name), *flags], cwd=directory, capture_output=True,
                                 text=True, timeout=timeout)
            print(run.stdout + run.stderr, end='')
            if (run.returncode or 'runtime error' in (run.stdout + run.stderr).lower()
                    or name in ('DreamMaker', 'dm.exe') and '0 errors, 0 warnings' not in run.stdout):
                return 2
        result = json.loads((directory / 'result.json').read_text())
        print(result)
        return 0 if result == {'checks': 9, 'failures': []} else 1


if __name__ == '__main__':
    raise SystemExit(main())
