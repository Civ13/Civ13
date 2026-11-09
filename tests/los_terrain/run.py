"""Native check for height-aware line of sight (code/modules/visibility/los_terrain.dm).

Compiles los_terrain.dm and the height parser into an isolated world with
probe.dm, runs it on Gaia's height file for random eyes (offsets, postures,
view radii) and compares every hidden ground cell with the Python reference
below. Also prints the sweep cost and checks that grading clears the cache.
"""
import argparse
import json
import math
import random
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HEIGHTS = ROOT / 'maps/heights/nomads_gaia.txt'
GEOMETRY = ['/proc/los_axis_separates(', '/proc/los_hull_axis_separates(', '/proc/los_footprint_hits_cell(',
            '/proc/los_target_blocked(', '/datum/los_snapshot/proc/index_blockers(', '/datum/los_snapshot/proc/blocks_target(']
SEE_OVER = {'hill_far_ground': 0, 'hill_close_behind_wall': 1, 'hill_person_two_behind_wall': 0, 'hill_indoors': 1,
            'hill_line_clears': 1, 'hill_tree': 1, 'flat_wall': 1, 'flat_see_over': 0}
PINNED = json.loads((ROOT / 'tools/byond/version.json').read_text(encoding='utf-8'))['version']


def fragment(text, start):
    lines = text[text.index(start):].split('\n')
    out = [lines[0]]
    for line in lines[1:]:
        if line and line[0] not in '\t ' and not line.startswith('//'):
            break
        out.append(line)
    return '\n'.join(out) + '\n'


def heights():
    lines = HEIGHTS.read_text().split('\n')
    mx, my = map(int, lines[1].split()[1:])
    rows = lines[3:3 + my]
    return lambda x, y: int(rows[my - y][x - 1], 16) if 1 <= x <= mx and 1 <= y <= my else 0


def reference(H, x, y, sx, sy, lying, radius):
    """Independent restatement of los_terrain_for/build/sweep_cell/despeckle."""
    q = lambda s: math.floor(s / 16 + 0.5) * 16
    qx, qy = q(sx), q(sy)
    tx, ty = x + math.floor(qx / 32 + 0.5), y + math.floor(qy / 32 + 0.5)
    fx, fy = x + qx / 32 - tx, y + qy / 32 - ty
    cells = [(i, j) for i in range(-radius, radius + 1) for j in range(-radius, radius + 1)]
    g = {c: H(tx + c[0], ty + c[1]) for c in cells}
    if all(v == g[(0, 0)] for v in g.values()):
        return None
    eye = g[(0, 0)] + (0.5 if lying else 1.5)
    floor, need = dict(g), {}
    for k in range(2, radius + 1):
        for i, j in [c for c in cells if max(abs(c[0]), abs(c[1])) == k]:
            if abs(i) >= abs(j):
                s = 1 if i > 0 else -1
                d, dp = i - fx, i - s - fx
                c = fy + (j - fy) * dp / d
                lo = math.floor(c)
                t = c - lo
                a = floor[(i - s, max(1 - k, min(k - 1, lo)))]
                b = floor[(i - s, max(1 - k, min(k - 1, lo + 1)))]
            else:
                s = 1 if j > 0 else -1
                d, dp = j - fy, j - s - fy
                c = fx + (i - fx) * dp / d
                lo = math.floor(c)
                t = c - lo
                a = floor[(max(1 - k, min(k - 1, lo)), j - s)]
                b = floor[(max(1 - k, min(k - 1, lo + 1)), j - s)]
            need[(i, j)] = eye + (a + (b - a) * t - eye) * d / dp
            floor[(i, j)] = max(floor[(i, j)], need[(i, j)])
    hidden = lambda c: c in need and g[c] + 0.25 < need[c] - 0.001
    speck = [c for c in cells if hidden(c) and sum(hidden((c[0] + a, c[1] + b)) for a in (-1, 0, 1) for b in (-1, 0, 1) if a or b) <= 2]
    for c in speck:
        need[c] = g[c]
    return (tx, ty), {f'{c[0]},{c[1]}' for c in cells if hidden(c)}


def ray_reference(H, ax, ay, alying, bx, by, blying):
    """Independent restatement of los_terrain_ray_blocked for a human target."""
    dx, dy = bx - ax, by - ay
    steps = max(abs(dx), abs(dy))
    if steps < 3:
        return 0
    eye = H(ax, ay) + (0.5 if alying else 1.5)
    rise = H(bx, by) + (0.5 if blying else 1.5) - eye
    for n in range(2, steps):
        t = n / steps
        if H(ax + math.floor(dx * t + 0.5), ay + math.floor(dy * t + 0.5)) > eye + rise * t + 0.001:
            return 1
    return 0


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--byond-bin', type=Path, default=None, help='folder holding DreamMaker and DreamDaemon')
    p.add_argument('--eyes', type=int, default=300)
    p.add_argument('--pairs', type=int, default=3000)
    a = p.parse_args()
    tool = lambda name: str(a.byond_bin / name) if a.byond_bin else name
    H = heights()
    rng = random.Random(13)
    eyes = []
    while len(eyes) < a.eyes:
        x, y = rng.randint(2, 499), rng.randint(2, 349)
        eyes.append([x, y, rng.choice([0, 3, 4, 11, 12, 16, 20, 27, 31]), rng.choice([0, 5, 8, 19, 28]),
                     int(rng.random() < 0.25), rng.choice([9, 9, 12, 4])])
    pairs = []
    while len(pairs) < a.pairs:
        x, y = rng.randint(16, 485), rng.randint(16, 335)
        pairs.append([x, y, int(rng.random() < 0.25), x + rng.randint(-14, 14), y + rng.randint(-14, 14),
                      int(rng.random() < 0.25)])
    terrain = (ROOT / 'code/modules/1713/terrain_height.dm').read_text(encoding='utf-8')
    parser = ''.join(fragment(terrain, name) for name in
                     ['/datum/terrain_heights\n', '/datum/terrain_heights/proc/at(', '/proc/terrain_heights_parse(', '/proc/terrain_height_row_valid('])
    parser = '\n'.join(l for l in parser.split('\n') if 'base_rows_by_z' not in l)
    # The 2D blocker geometry the height rule plugs into.
    core = (ROOT / 'code/modules/visibility/los_context.dm').read_text(encoding='utf-8')
    geometry = ''.join(fragment(core, name) for name in GEOMETRY)
    geometry += fragment(core, '/datum/los_cell\n') + fragment(core, '/datum/los_snapshot\n')
    with tempfile.TemporaryDirectory() as work:
        work = Path(work)
        (work / 'parser.dm').write_text(parser + geometry, encoding='utf-8')
        (work / 'los_terrain.dm').write_text((ROOT / 'code/modules/visibility/los_terrain.dm').read_text(encoding='utf-8'), encoding='utf-8')
        (work / 'probe.dm').write_text((Path(__file__).parent / 'probe.dm').read_text(encoding='utf-8'), encoding='utf-8')
        (work / 'heights.txt').write_text(HEIGHTS.read_text(encoding='utf-8'), encoding='utf-8')
        (work / 'eyes.json').write_text(json.dumps(eyes), encoding='utf-8')
        (work / 'pairs.json').write_text(json.dumps(pairs), encoding='utf-8')
        (work / 'probe.dme').write_text('#include "parser.dm"\n#include "los_terrain.dm"\n#include "probe.dm"\n', encoding='utf-8')
        build = subprocess.run([tool('DreamMaker'), 'probe.dme'], cwd=work, capture_output=True, text=True)
        print(build.stdout.strip().splitlines()[-1] if build.stdout.strip() else build.stderr)
        if 'DM compiler version ' + PINNED not in build.stdout + build.stderr:
            print('warning: compiler is not the pinned ' + PINNED)
        if build.returncode or '0 errors' not in build.stdout:
            print(build.stdout + build.stderr)
            return 1
        run = subprocess.run([tool('DreamDaemon'), 'probe.dmb', '-trusted', '-close'], cwd=work,
                             capture_output=True, text=True, timeout=600)
        if not (work / 'result.json').exists():
            print(run.stdout + run.stderr)
            return 1
        result = json.loads((work / 'result.json').read_text())
    bad = 0
    hidden_total = 0
    for eye, got in zip(eyes, result['fields']):
        want = reference(H, *eye)
        if want is None or got is None:
            if want is not None or got is not None:
                bad += 1
                print('MISMATCH flat', eye)
            continue
        if tuple(got['tile']) != want[0] or set(got['hidden']) != want[1]:
            bad += 1
            print('MISMATCH', eye, sorted(set(got['hidden']) ^ want[1])[:8])
        hidden_total += len(want[1])
    per = result['build_ds'] * 100 / max(1, result['builds'])
    print(f"sweep: {result['builds']} fresh fields (radius 9) in {result['build_ds'] / 10:.1f} s, {per:.2f} ms each; "
          f"20000 cached lookups in {result['cached_ds'] / 10:.1f} s; {hidden_total} hidden cells compared")
    for name, want in SEE_OVER.items():
        if result['see_over'].get(name) != want:
            bad += 1
            print('MISMATCH see-over', name, result['see_over'].get(name), 'want', want)
    print('see-over cases:', ', '.join(f'{k}={v}' for k, v in result['see_over'].items()))
    want_rays = [ray_reference(H, *pair) for pair in pairs]
    ray_bad = sum(1 for got, want in zip(result['rays'], want_rays) if got != want)
    if ray_bad:
        bad += 1
        print(f'MISMATCH NPC sight rays: {ray_bad} of {len(pairs)} differ from the reference')
    agree = result['agree'] * 100 / max(1, len(pairs))
    print(f"NPC sight: {sum(want_rays)} of {len(pairs)} pairs hidden; agrees with the player sweep on {agree:.1f}%; "
          f"{20 * len(pairs)} rays in {result['ray_ds'] / 10:.1f} s, {result['ray_ds'] * 100 / max(1, 20 * len(pairs)):.4f} ms each")
    if agree < 90:
        bad += 1
        print('MISMATCH NPC sight agrees with the player sweep on under 90% of pairs')
    if not result['cleared']:
        bad += 1
        print('MISMATCH grading did not clear the cache and refresh viewers')
    print('LOS_TERRAIN PASS' if not bad else f'LOS_TERRAIN FAIL ({bad})')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
