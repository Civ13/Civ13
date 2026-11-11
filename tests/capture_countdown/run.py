"""Tick-by-tick parity of the shared objective-capture countdown.

Builds two small standalone DreamDaemon fixtures from the same stubs and
scripted rounds (tests/capture_countdown/probe.dm):

- original: the frozen pre-refactor update_win_condition() bodies of the base
  map and of Camp, Oasis and Two Tribes (original_update_win_condition.dm.txt);
- current: the live update_win_condition() and shared capture_* procs.

Every other proc (win times, army names, stat message) is extracted from the
live source for both builds. world.time is rewritten to a scripted clock in
both. The runner compares every tick of every round: return value, countdown,
winner/loser, hashes, round end, chat lines and battle reports.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
MAPS = ROOT / 'code/game/objects/map_metadata'
PINNED_BYOND = json.loads((ROOT / 'tools/byond/version.json').read_text(encoding='utf-8'))['version']
MAP_NAMES = ('camp', 'oasis', 'twotribes')
BASE_PROCS = ('next_win_time', 'current_stat_message', 'announce_current_win_condition',
              'short_win_time', 'long_win_time', 'roundend_condition_def2name',
              'roundend_condition_def2army', 'army2name')
SHARED_PROCS = ('capture_countdown_elapsed', 'update_capture_state', 'capture_branch')
MAP_PROCS = ('short_win_time', 'long_win_time', 'roundend_condition_def2name',
             'roundend_condition_def2army', 'army2name')
MAP_VARS = ('victory_time', 'capture_objective_name', 'capture_verb', 'capture_notice_in_font',
            'no_winner', 'roundend_condition_sides', 'battle_name', 'faction1', 'faction2')
INFINITY_FILE = 'code/predefines.dm'
SEEDS = 12
# Mutations of the current build that the comparison must catch.
CONTROLS = {
    'branch-order': ('!capture_branch(1, 2, 1.33, FALSE) && !capture_branch(1, 2, 1.01, TRUE)',
                     '!capture_branch(1, 2, 1.01, TRUE) && !capture_branch(1, 2, 1.33, FALSE)'),
    'timer': ('(long_timer ? long_win_time(defender_flag) : short_win_time(defender_flag))',
              '(long_timer ? short_win_time(defender_flag) : long_win_time(defender_flag))'),
    'verb': ('\tcapture_verb = "has"\n', '\tcapture_verb = "have"\n'),
    'chat-style': ('\tcapture_notice_in_font = TRUE\n', '\tcapture_notice_in_font = FALSE\n'),
}
TICKS = 2400


def proc_block(source, type_path, name, required=True):
    """Return one top-level proc definition (header plus indented body)."""
    pattern = r'(?m)^' + re.escape(type_path) + r'/(?:proc/)?' + re.escape(name) + r'\(.*\)\n(?:(?:[\t ].*|//.*|)\n)*'
    matches = re.findall(pattern, source)
    if len(matches) > 1:
        raise ValueError(f'ambiguous {type_path}/{name}')
    if not matches:
        if required:
            raise ValueError(f'missing {type_path}/{name}')
        return ''
    return matches[0].rstrip('\n') + '\n'


def type_vars(source, type_path):
    """Return the whitelisted var assignments of a map type definition."""
    match = re.search(r'(?m)^' + re.escape(type_path) + r'\n((?:(?:[\t ].*|)\n)*)', source)
    if not match:
        raise ValueError(f'missing {type_path}')
    lines = match.group(1).split('\n')
    out, i = [], 0
    while i < len(lines):
        line = lines[i]
        name = line.strip().split('=', 1)[0].strip()
        if name in MAP_VARS:
            chunk = [line]
            depth = line.count('(') - line.count(')')
            while depth > 0:
                i += 1
                chunk.append(lines[i])
                depth += lines[i].count('(') - lines[i].count(')')
            out.extend(chunk)
        i += 1
    return type_path + '\n' + '\n'.join(out) + '\n'


def defines():
    """Plain text/number defines the extracted procs use (factions and map IDs)."""
    out = []
    for rel in ('code/__defines/faction_lang_defines.dm', 'code/__defines/maps.dm'):
        for line in (ROOT / rel).read_text(encoding='utf-8').splitlines():
            if re.match(r'#define [A-Z0-9_]+ ("[^"]*"|-?\d+)\s*(//.*)?$', line):
                out.append(line)
    macros = (ROOT / 'code/_macros.dm').read_text(encoding='utf-8')
    for name in ('SPAN', 'SPAN_NOTICE'):
        out += re.findall(r'(?m)^#define ' + name + r'\(.*$', macros)
    out += re.findall(r'(?m)^#define INFINITY\b.*$', (ROOT / INFINITY_FILE).read_text(encoding='utf-8'))
    if len(out) < 3 or not out[-1].startswith('#define INFINITY'):
        raise ValueError('missing SPAN/INFINITY macros')
    return '\n'.join(out) + '\n'


def sources(variant, control=None):
    if variant not in ('original', 'current'):
        raise ValueError(variant)
    base = (MAPS / '_map_metadata.dm').read_text(encoding='utf-8')
    maps = {n: (MAPS / f'{n}.dm').read_text(encoding='utf-8') for n in MAP_NAMES}
    parts = [defines(), f'#define CAPTURE_SEEDS {SEEDS}\n#define CAPTURE_TICKS {TICKS}\n']
    parts += [proc_block(base, '/obj/map_metadata', p) for p in BASE_PROCS]
    for name in MAP_NAMES:
        parts.append(type_vars(maps[name], f'/obj/map_metadata/{name}'))
        parts += [proc_block(maps[name], f'/obj/map_metadata/{name}', p, required=False) for p in MAP_PROCS]
    if variant == 'original':
        parts.append((HERE / 'original_update_win_condition.dm.txt').read_text(encoding='utf-8'))
    else:
        parts.append(proc_block(base, '/obj/map_metadata', 'update_win_condition'))
        parts += [proc_block(base, '/obj/map_metadata', p) for p in SHARED_PROCS]
        parts += [proc_block(maps[n], f'/obj/map_metadata/{n}', 'update_win_condition') for n in MAP_NAMES]
    code = '\n'.join(parts)
    code = code.replace('world.time', 'capture_clock')
    if control:
        old, new = CONTROLS[control]
        if old not in code:
            raise ValueError(f'control {control} anchor missing')
        code = code.replace(old, new)
    return code


def build_and_run(binary, variant, work, control=None):
    folder = work / variant
    folder.mkdir(parents=True)
    (folder / 'extracted.dm').write_text(sources(variant, control), encoding='utf-8', newline='\n')
    shutil.copy2(HERE / 'probe.dm', folder / 'probe.dm')
    (folder / 'capture.dme').write_text('#include "extracted.dm"\n#include "probe.dm"\n', encoding='utf-8')
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    compiler = binary / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    build = subprocess.run([str(compiler), '-max_errors', '0', 'capture.dme'], cwd=folder,
                           capture_output=True, text=True, timeout=180, creationflags=flags)
    log = build.stdout + build.stderr
    (folder / 'compile.log').write_text(log, encoding='utf-8')
    if build.returncode or PINNED_BYOND not in log or '0 errors, 0 warnings' not in log:
        print(log)
        raise ValueError(f'{variant}: pinned compilation failed')
    daemon = binary / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    run = subprocess.run([str(daemon), 'capture.dmb', '-invisible', '-close', '-trusted', '-log', 'runtime.log'],
                         cwd=folder, capture_output=True, timeout=300, creationflags=flags)
    diagnostics = (folder / 'runtime.log').read_text(encoding='utf-8', errors='replace') if (folder / 'runtime.log').exists() else ''
    diagnostics += (run.stdout + run.stderr).decode(errors='replace')
    if re.search(r'runtime error|BUG:', diagnostics, re.I) or 'COMPLETE capture countdown trace' not in diagnostics:
        print(diagnostics)
        raise ValueError(f'{variant}: native run failed')
    raw = json.loads((folder / 'trace.json').read_text(encoding='utf-8'))
    return {key: [json.loads(line) for line in lines] for key, lines in raw.items()}


def compare(original, current):
    """Return (mismatches, coverage) across every round and tick."""
    mismatches = []
    coverage = {}
    if sorted(original) != sorted(current):
        return ['round lists differ'], coverage
    for key in sorted(original):
        a, b = original[key], current[key]
        case = coverage.setdefault(key.split('/')[0], dict(rounds=0, ticks=0, countdowns_started=0,
                                   countdowns_lost=0, capture_wins=0, deadline_reports=0, wipes=0))
        case['rounds'] += 1
        if len(a) != len(b):
            mismatches.append(f'{key}: {len(a)} vs {len(b)} ticks')
            continue
        for x, y in zip(a, b):
            case['ticks'] += 1
            if x != y:
                fields = sorted(k for k in x if x.get(k) != y.get(k))
                mismatches.append(f'{key} tick {x["tick"]}: {fields} original={[x[f] for f in fields]} current={[y[f] for f in fields]}')
                break
            for event in x['events']:
                if 'will win in' in event:
                    case['countdowns_started'] += 1
                elif 'lost control' in event:
                    case['countdowns_lost'] += 1
                elif 'was victorious' in event:
                    case['capture_wins'] += 1
                elif event == 'battle_report':
                    case['deadline_reports'] += 1
                elif event == 'wipe':
                    case['wipes'] += 1
    return mismatches, coverage


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--evidence-dir', type=Path)
    parser.add_argument('--negative-control', choices=sorted(CONTROLS),
                        help='mutate the current build; the run passes only if a mismatch is found')
    args = parser.parse_args()
    work = Path(tempfile.mkdtemp(prefix='capture_countdown_'))
    try:
        original = build_and_run(args.byond_bin.resolve(), 'original', work)
        current = build_and_run(args.byond_bin.resolve(), 'current', work, args.negative_control)
        mismatches, coverage = compare(original, current)
        report = dict(mismatches=mismatches[:20], mismatch_count=len(mismatches), coverage=coverage)
        if args.evidence_dir:
            args.evidence_dir.mkdir(parents=True, exist_ok=True)
            (args.evidence_dir / 'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
            for variant in ('original', 'current'):
                shutil.copy2(work / variant / 'trace.json', args.evidence_dir / f'trace-{variant}.json')
        print(json.dumps(report, indent=2))
        if args.negative_control:
            if not mismatches:
                raise SystemExit(f'FAIL control {args.negative_control} went undetected')
            print(f'PASS control {args.negative_control} detected')
            return
        if mismatches:
            raise SystemExit('FAIL capture countdown differs from the original')
        for case, counts in sorted(coverage.items()):
            needed = ['countdowns_started', 'countdowns_lost', 'capture_wins', 'wipes']
            if case in MAP_NAMES:
                needed.append('deadline_reports')
            for name in needed:
                if not counts[name]:
                    raise SystemExit(f'FAIL {case} scenarios never exercised {name}')
        rounds = sum(c['rounds'] for c in coverage.values())
        ticks = sum(c['ticks'] for c in coverage.values())
        print(f'PASS {rounds} rounds, {ticks} ticks identical')
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == '__main__':
    sys.exit(main())
