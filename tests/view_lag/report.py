"""Turns a view lag run's raw files into summary.json and report.md.

Pure functions only, so it runs anywhere (selftest.py covers the maths):
    python3 tests/view_lag/report.py <evidence folder>

Inputs in the folder: result.json (probe), network.json and client.json
(written by run.py). A missing client.json or network.json (headless
rehearsal) leaves those columns empty.
"""
import json
from pathlib import Path
import statistics
import sys

# A captured frame counts as the map scrolling when this share of sampled
# bytes changed; smaller changes are animations (water, idle sprites, HUD).
SCROLL_SHARE = 0.10
ANY_SHARE = 0.002
# Gaps between scrolling frames while a key is held. A smooth glide redraws at
# the capture rate; a gap this long is a visible hitch.
HITCH_S = 0.100
BIG_HITCH_S = 0.250
# Frames right after a key goes down or up are not counted as walking.
HOLD_WARMUP_S = 0.35
TAP_WINDOW_S = 1.0


def percentile(values, share):
    if not values:
        return None
    ordered = sorted(values)
    index = min(len(ordered) - 1, max(0, round(share * (len(ordered) - 1))))
    return ordered[index]


def rounded(value, places=1):
    return None if value is None else round(value, places)


def frame_stats(frames, holds=(), taps=()):
    """frames: [(t, changed_share)], holds: [(down, up)], taps: [down].

    Returns what the player saw: how often the picture changed, the gaps in
    scrolling while a key was held, and key-to-picture time for taps.
    """
    out = {'frames': len(frames)}
    if len(frames) < 2:
        return out
    span = frames[-1][0] - frames[0][0]
    out['capture_hz'] = rounded(len(frames) / span) if span > 0 else None
    changes = [t for t, share in frames if share >= ANY_SHARE]
    out['change_hz'] = rounded(len(changes) / span) if span > 0 else None
    gaps = []
    held_seconds = 0.0
    for down, up in holds:
        start = down + HOLD_WARMUP_S
        if up <= start:
            continue
        held_seconds += up - start
        scroll = [t for t, share in frames if start <= t <= up and share >= SCROLL_SHARE]
        edges = [start] + scroll + [up]
        gaps += [b - a for a, b in zip(edges, edges[1:])]
    if holds:
        out['held_seconds'] = rounded(held_seconds, 2)
        out['scroll_hz'] = rounded((len(gaps) - len(holds)) / held_seconds) if held_seconds else None
        out['gap_p50_ms'] = rounded((percentile(gaps, 0.5) or 0) * 1000)
        out['gap_p95_ms'] = rounded((percentile(gaps, 0.95) or 0) * 1000)
        out['gap_max_ms'] = rounded((max(gaps) if gaps else 0) * 1000)
        minutes = held_seconds / 60 if held_seconds else None
        out['hitches_per_min'] = rounded(sum(1 for g in gaps if g >= HITCH_S) / minutes) if minutes else None
        out['big_hitches_per_min'] = rounded(sum(1 for g in gaps if g >= BIG_HITCH_S) / minutes) if minutes else None
    if taps:
        latencies = []
        missed = 0
        for down in taps:
            hit = next((t for t, share in frames if down < t <= down + TAP_WINDOW_S and share >= SCROLL_SHARE), None)
            if hit is None:
                missed += 1
            else:
                latencies.append(hit - down)
        out['taps'] = len(taps)
        out['taps_missed'] = missed
        out['tap_ms_p50'] = rounded((percentile(latencies, 0.5) or 0) * 1000) if latencies else None
        out['tap_ms_p95'] = rounded((percentile(latencies, 0.95) or 0) * 1000) if latencies else None
    return out


def step_stats(gaps_ds, tick_lag):
    """Server-side step rhythm of the camera mob, in milliseconds."""
    if not gaps_ds:
        return {}
    ms = [g * 100 for g in gaps_ds]
    return {'step_ms_p50': rounded(percentile(ms, 0.5)), 'step_ms_p95': rounded(percentile(ms, 0.95)),
            'step_ms_spread': rounded(statistics.pstdev(ms)) if len(ms) > 1 else 0}


def glide_match(row):
    """How far the glide time is from the real step interval (1.0 = matched).

    glide_size is pixels per tick; a 32 px tile takes 32 / glide ticks to glide.
    Below 1 the glide finishes early and the camera waits (stutter); above 1
    the next step starts mid-glide (the camera jumps ahead).
    """
    glide = row.get('glide_avg') or 0
    step = row.get('step_ms_p50')
    tick_ms = (row.get('tick_lag') or 0.5) * 100
    if not glide or not step:
        return None
    return round((32 / glide) * tick_ms / step, 2)


def stage_rows(result, network, client):
    rows = {}
    for name, row in (result.get('stages') or {}).items():
        out = {k: row.get(k) for k in ('role', 'kind', 'seconds', 'tick_usage_avg', 'tick_usage_p95', 'tick_usage_max', 'cpu_avg',
                                       'map_cpu_avg', 'map_cpu_max', 'glide_avg', 'moves', 'images_max', 'images_end', 'screen_max',
                                       'see_invisible', 'los_presenter', 'compositor', 'tick_lag')}
        out.update(step_stats(row.get('step_gaps_ds') or [], row.get('tick_lag')))
        out['glide_vs_step'] = glide_match(out)
        net = (network or {}).get(name)
        if net:
            seconds = row.get('seconds') or 1
            out['kbps_down'] = round(net.get('down', 0) * 8 / 1000 / seconds, 1)
            out['kbps_up'] = round(net.get('up', 0) * 8 / 1000 / seconds, 1)
        seen = (client or {}).get(name)
        if seen:
            out.update(frame_stats([tuple(f) for f in seen.get('frames', [])], [tuple(h) for h in seen.get('holds', [])], seen.get('taps', [])))
            out['focus_ok'] = seen.get('focus_ok')
        out['top_procs'] = [{'name': p.get('name'), 'self': p.get('self'), 'total': p.get('total'), 'calls': p.get('calls')}
                            for p in (row.get('top_procs') or [])[:10]]
        rows[name] = out
    return rows


# Lower is better for every compared metric except the frame and scroll rates.
COMPARED = (
    ('walk', 'tick_usage_avg', 'server tick % walking', False),
    ('walk', 'map_cpu_avg', 'map send % walking', False),
    ('crowd', 'tick_usage_avg', 'server tick % in a crowd', False),
    ('walk', 'kbps_down', 'kbps walking', False),
    ('crowd', 'kbps_down', 'kbps in a crowd', False),
    ('walk', 'scroll_hz', 'scroll frames/s walking', True),
    ('walk', 'hitches_per_min', 'hitches/min walking', False),
    ('walk', 'gap_p95_ms', 'p95 frame gap ms walking', False),
    ('crowd', 'hitches_per_min', 'hitches/min in a crowd', False),
    ('taps', 'tap_ms_p50', 'key to picture ms', False),
    ('still', 'change_hz', 'redraws/s standing', True),
)


def mean_of(rows, roles, kind, metric):
    values = [rows.get(f'{role}_{kind}', {}).get(metric) for role in roles]
    values = [v for v in values if isinstance(v, (int, float))]
    return sum(values) / len(values) if values else None


def attribution(rows):
    """For each human_no_X role: the share of the human-to-ghost gap it closes."""
    roles = sorted({r['role'] for r in rows.values() if r.get('role')})
    humans = [r for r in roles if r in ('human', 'human_repeat')]
    ghosts = [r for r in roles if r in ('ghost', 'ghost_repeat')]
    table = []
    for kind, metric, label, higher_better in COMPARED:
        human = mean_of(rows, humans, kind, metric)
        ghost = mean_of(rows, ghosts, kind, metric)
        entry = {'metric': label, 'human': rounded(human), 'ghost': rounded(ghost), 'closed': {}}
        gap = None if human is None or ghost is None else human - ghost
        for role in roles:
            if role in humans or role in ghosts:
                continue
            value = mean_of(rows, [role], kind, metric)
            entry.setdefault('values', {})[role] = rounded(value)
            if value is not None and gap and abs(gap) > 1e-9:
                entry['closed'][role] = round((human - value) / gap, 2)
        table.append(entry)
    return table


def markdown(summary):
    rows = summary['stages']
    lines = ['# Player view vs ghost view', '', f"Commit {summary.get('tested_commit')}, map {((summary.get('metrics') or {}).get('map') or {}).get('id')}.", '']
    lines += ['## Gap closed per switch', '',
              'Share of the human-to-ghost difference each switch removes (1.0 = all of it, negative = worse).', '']
    table = summary['attribution']
    roles = sorted({role for entry in table for role in entry.get('values', {})})
    lines.append('| Metric | Human | Ghost | ' + ' | '.join(roles) + ' |')
    lines.append('| --- | --- | --- | ' + ' | '.join('---' for _ in roles) + ' |')
    for entry in table:
        cells = []
        for role in roles:
            value = entry.get('values', {}).get(role)
            closed = entry['closed'].get(role)
            cells.append('-' if value is None else (f'{value} ({closed:+.0%})' if closed is not None else f'{value}'))
        lines.append(f"| {entry['metric']} | {entry['human']} | {entry['ghost']} | " + ' | '.join(cells) + ' |')
    lines += ['', '## Every stage', '']
    cols = ('tick_usage_avg', 'map_cpu_avg', 'kbps_down', 'scroll_hz', 'hitches_per_min', 'gap_p95_ms', 'tap_ms_p50', 'change_hz', 'step_ms_p50', 'glide_vs_step', 'images_max', 'screen_max')
    lines.append('| Stage | ' + ' | '.join(cols) + ' |')
    lines.append('| --- | ' + ' | '.join('---' for _ in cols) + ' |')
    for name, row in rows.items():
        lines.append(f'| {name} | ' + ' | '.join('-' if row.get(c) is None else str(row.get(c)) for c in cols) + ' |')
    lines += ['', '## Heaviest procs walking (self time, first five per role)', '']
    for name, row in rows.items():
        if not name.endswith('_walk'):
            continue
        procs = ', '.join(f"{p['name']} {p['self']}" for p in row.get('top_procs', [])[:5])
        lines.append(f'- **{name}**: {procs or "none recorded"}')
    return '\n'.join(lines) + '\n'


def build(folder):
    folder = Path(folder)

    def load(name):
        try:
            return json.loads((folder / name).read_text(encoding='utf-8'))
        except (FileNotFoundError, json.JSONDecodeError):
            return None

    result = load('result.json') or {'stages': load('stages.json') or {}}
    rows = stage_rows(result, load('network.json'), load('client.json'))
    manifest = load('manifest.json') or {}
    summary = {'passed': bool(result.get('passed')), 'failure': result.get('failure'), 'failed_phase': result.get('failed_phase'),
               'tested_commit': manifest.get('tested_commit') or ((result.get('metrics') or {}).get('map') or {}).get('tested_commit'),
               'metrics': result.get('metrics'), 'roles': result.get('roles'), 'stages': rows, 'attribution': attribution(rows)}
    (folder / 'summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
    (folder / 'report.md').write_text(markdown(summary), encoding='utf-8')
    return summary


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: report.py <evidence folder>')
    print(markdown(build(sys.argv[1])))
