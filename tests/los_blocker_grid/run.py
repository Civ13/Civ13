"""Native parity check: the LOS blocker grid matches the flat blocker scan.

Extracts the pure geometry procs and los_snapshot index/query procs from
code/modules/visibility/los_context.dm into an isolated world with probe.dm,
compiles it with the pinned DreamMaker and runs it in DreamDaemon.
"""
import argparse
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/visibility/los_context.dm'
PINNED = json.loads((ROOT / 'tools/byond/version.json').read_text(encoding='utf-8'))['version']
PROCS = ['/proc/los_axis_separates(', '/proc/los_hull_axis_separates(', '/proc/los_footprint_hits_cell(',
         '/proc/los_target_blocked(', '/proc/los_bucket_index(', '/proc/los_bucket_lower(', '/proc/los_bucket_upper(',
         '/datum/los_snapshot/proc/index_blockers(', '/datum/los_snapshot/proc/ensure_blocker_bins(',
         '/datum/los_snapshot/proc/blocks_target(']
# Blocker heights (los_terrain.dm) are absent here: nothing is seen over.
TYPES = '''/proc/los_height_clears(S, B, tx, ty)
\treturn FALSE
/datum/los_cell
\tvar/cell_x
\tvar/cell_y
\tvar/tile_x
\tvar/tile_y
\tvar/atom/surface_owner
\tvar/owners = 0
'''


def fragment(text, start):
    lines = text[text.index(start):].split('\n')
    out = [lines[0]]
    for line in lines[1:]:
        if line and line[0] not in '\t ' and not line.startswith('//'):
            break
        out.append(line)
    return '\n'.join(out) + '\n'


def snapshot_vars(text):
    body = fragment(text, '/datum/los_snapshot\n')
    keep = [l for l in body.split('\n')[1:] if re.match(r'\tvar/', l) and 'datum/' not in l and 'atom/' not in l]
    return '/datum/los_snapshot\n' + '\n'.join(keep) + '\n'


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--byond-bin', type=Path, default=None, help='folder holding DreamMaker and DreamDaemon')
    a = p.parse_args()
    text = SOURCE.read_text(encoding='utf-8')
    parts = [fragment(text, name) for name in PROCS]
    tool = lambda name: str(a.byond_bin / name) if a.byond_bin else name
    with tempfile.TemporaryDirectory() as work:
        work = Path(work)
        (work / 'geometry.dm').write_text(TYPES + snapshot_vars(text) + '\n'.join(parts), encoding='utf-8')
        (work / 'probe.dm').write_text((Path(__file__).parent / 'probe.dm').read_text(encoding='utf-8'), encoding='utf-8')
        (work / 'grid.dme').write_text('#include "geometry.dm"\n#include "probe.dm"\n', encoding='utf-8')
        build = subprocess.run([tool('DreamMaker'), 'grid.dme'], cwd=work, capture_output=True, text=True)
        print(build.stdout.strip().splitlines()[-1] if build.stdout.strip() else build.stderr)
        if 'DM compiler version ' + PINNED not in build.stdout + build.stderr:
            print('warning: compiler is not the pinned ' + PINNED)
        if build.returncode or '0 errors' not in build.stdout:
            print(build.stdout + build.stderr)
            return 1
        run = subprocess.run([tool('DreamDaemon'), 'grid.dmb', '-trusted', '-close'], cwd=work, capture_output=True, text=True, timeout=600)
        log = run.stdout + run.stderr
        for line in log.splitlines():
            if 'LOS_GRID' in line or 'MISMATCH' in line:
                print(line)
        return 0 if 'LOS_GRID PASS' in log else 1


if __name__ == '__main__':
    sys.exit(main())
