"""Offline schema-1 pair, trace and sanitized bundle commands; never queries a game.

Inputs are private agent_debug JSON. Output has an explicit field allowlist:
no account, session, request, object refs, paths, raw text or absolute coordinates.
Screenshot hashes identify external files; this module never captures pixels.
"""
import argparse
from datetime import datetime
import json
import math
from pathlib import Path
import re
import sys

LIMIT = 32768
MAX_SNAPSHOTS = 8
TOOLS = ('recovery', 'vision', 'tiles')


def flag(value):
    if type(value) not in (int, bool) or value not in (0, 1):
        raise ValueError('flag')
    return bool(value)


def number(value, nullable=False):
    if value is None and nullable:
        return None
    if type(value) not in (int, float) or not math.isfinite(value) or abs(value) > 1e15:
        raise ValueError('number')
    return value


def envelope(value, tool=None):
    if not isinstance(value, dict) or value.get('schema') != 1 or value.get('ok') is not True:
        raise ValueError('envelope')
    if value.get('tool') not in TOOLS or (tool and value['tool'] != tool):
        raise ValueError('tool')
    data = value['data']
    if not isinstance(data, dict) or not isinstance(data.get('revision'), str) or not re.fullmatch(r'[0-9a-f]{40}', data['revision']):
        raise ValueError('revision')
    if value['tool'] != 'recovery':
        if flag(data['partial']) or not flag(data['same_target']):
            raise ValueError('partial snapshot')
        if number(data['tick_start']) != number(data['tick_end']):
            raise ValueError('tick consistency')
        if not isinstance(data.get('sample'), dict):
            raise ValueError('sample')
    return data


def tile(row, slot):
    if not isinstance(row, dict):
        raise ValueError('tile')
    result = dict(slot=slot, present=flag(row['present']))
    if not result['present']:
        return result
    # Slot order is dx=-1..1, dy=-1..1; slot 4 is own turf. No coordinates.
    for key in ('dynamic', 'opacity', 'opaque_atom'):
        if key in row:
            result[key] = flag(row[key])
    for key in ('luminosity', 'overlay_luminosity', 'overlay_last_luminosity'):
        if key in row:
            result[key] = number(row[key], True)
    overlay = row.get('overlay', {})
    result['overlay_present'] = flag(overlay.get('present', False))
    for key in ('alpha', 'invisibility', 'plane', 'layer'):
        if key in overlay:
            result['overlay_' + key] = number(overlay[key])
    owner = row.get('overlay_owner')
    if owner is not None:
        result['overlay_on_sample_turf'] = flag(owner['loc_is_sample_turf'])
        membership = owner['registry_membership']
        if membership not in ('present in prefix', 'absent', 'unknown beyond prefix'):
            raise ValueError('registry status')
        result['registry_membership'] = membership
    return result


def tiles(data):
    rows = data['sample']['lighting_3x3']
    if not isinstance(rows, list) or len(rows) != 9:
        raise ValueError('nine tile slots required')
    return [tile(row, i) for i, row in enumerate(rows)]


def lifecycle(data):
    source = data['sample'].get('lighting_lifecycle')
    if source is None:
        return dict(available=False)
    result = dict(available=True)
    for key in ('startup_in_progress', 'overlays_created', 'daylight_worker_available',
                'daylight_updating', 'daylight_setup'):
        result[key] = flag(source[key])
    for key in ('daylight_revision', 'overlay_queue'):
        result[key] = number(source[key], True)
    return result


def pair(value, black_slot, visible_slot):
    data = envelope(value, 'tiles')
    if any(type(i) is not int or not 0 <= i < 9 for i in (black_slot, visible_slot)) or black_slot == visible_slot:
        raise ValueError('distinct local slots required')
    rows = tiles(data)
    if not rows[black_slot]['present'] or not rows[visible_slot]['present']:
        raise ValueError('pair unavailable')
    return dict(schema=1, ok=True, command='pair', revision=data['revision'],
                tick=data['tick_start'], labels='operator supplied; rendering unverified',
                black=rows[black_slot], visible=rows[visible_slot])


def trace(values):
    if not 2 <= len(values) <= MAX_SNAPSHOTS:
        raise ValueError('trace bound')
    observations = []
    identity = None
    neighborhood = None
    previous_tick = -1
    for value in values:
        data = envelope(value, 'tiles')
        # Compare only the same process and authenticated current client/mob.
        current_identity = (data['revision'], data.get('session'), data.get('target_fingerprint'))
        if not isinstance(current_identity[1], str) or not re.fullmatch(r'[0-9a-f]{32}', current_identity[1]):
            raise ValueError('session')
        if not isinstance(current_identity[2], str) or not re.fullmatch(r'[0-9a-f]{64}', current_identity[2]):
            raise ValueError('target fingerprint')
        if identity and current_identity != identity:
            raise ValueError('mixed runtime')
        identity = current_identity
        positions = []
        for row in data['sample']['lighting_3x3']:
            positions.append(tuple(number(row[key]) for key in ('x', 'y', 'z')) if flag(row['present']) else None)
        if neighborhood is not None and positions != neighborhood:
            raise ValueError('moved neighborhood')
        neighborhood = positions
        tick = number(data['tick_start'])
        if tick <= previous_tick:
            raise ValueError('trace order')
        previous_tick = tick
        observations.append(dict(tick=tick, lifecycle=lifecycle(data), tiles=tiles(data)))
    return dict(schema=1, ok=True, command='trace', revision=identity[0],
                scope='sampled cached observations; events between samples unavailable',
                observations=observations)


def bundle(values, *, screenshot_sha256=None, screenshot_utc=None, black_slot=None, visible_slot=None):
    if not 1 <= len(values) <= MAX_SNAPSHOTS:
        raise ValueError('bundle bound')
    if screenshot_sha256 is not None and (not isinstance(screenshot_sha256, str) or not re.fullmatch(r'[0-9a-f]{64}', screenshot_sha256)):
        raise ValueError('screenshot hash')
    if (screenshot_sha256 is None) != (screenshot_utc is None):
        raise ValueError('screenshot identity pair')
    if screenshot_utc is not None:
        if not isinstance(screenshot_utc, str) or not re.fullmatch(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z', screenshot_utc):
            raise ValueError('screenshot UTC')
        datetime.strptime(screenshot_utc, '%Y-%m-%dT%H:%M:%SZ')
    summaries, revisions, tile_values = [], set(), []
    for value in values:
        data = envelope(value)
        revisions.add(data['revision'])
        summary = dict(tool=value['tool'])
        if value['tool'] == 'tiles':
            summary.update(tick=data['tick_start'], tiles=tiles(data), lifecycle=lifecycle(data))
            tile_values.append(value)
        elif value['tool'] == 'vision':
            sample = data['sample']
            summary['tick'] = data['tick_start']
            summary['camera_on_own_mob'] = sample.get('client', {}).get('eye_relation') == 'own mob'
            summary['vision'] = {key: number(sample['mob'][key]) for key in
                                 ('sight', 'see_in_dark', 'see_invisible', 'blinded') if key in sample.get('mob', {})}
            # Health, character type/names and saved return positions are private.
        else:
            for key in ('ready', 'busy', 'restart_hold', 'restart_import_complete', 'restart_intent'):
                summary[key] = flag(data[key])
            debug = data.get('debug', {})
            summary['debug_available'] = flag(debug.get('available', False))
            if summary['debug_available']:
                progress = debug['progress']
                if progress['kind'] not in ('idle', 'save', 'load'):
                    raise ValueError('progress')
                summary['progress'] = dict(kind=progress['kind'], saving_z=number(progress['saving_z'], True),
                                           loading_z=number(progress['loading_z'], True), percent_available=False)
                for key in ('active', 'backend_started', 'contents_started', 'mutation_started', 'restoring_players'):
                    summary['progress'][key] = flag(progress[key])
        summaries.append(summary)
    if len(revisions) != 1:
        raise ValueError('mixed revision')
    result = dict(schema=1, ok=True, command='bundle', revision=revisions.pop(),
                  sanitized=True, evidence='cached diagnostics; no gameplay acceptance', snapshots=summaries,
                  screenshot=dict(source='external capture', sha256=screenshot_sha256, utc=screenshot_utc,
                                  pixels_captured_by_tool=False, correlation_verified=False),
                  reproduction=['Use the same reviewed build and isolated map fixture.',
                                'Connect the configured Host with its existing R_HOST permission.',
                                'Capture the actual client externally; record its time and SHA-256.',
                                'Read vision and tiles at the same position; compare the named local slots.',
                                'Collect at most eight ordered tile snapshots for an observed lighting trace.'])
    if black_slot is not None or visible_slot is not None:
        if not tile_values:
            raise ValueError('pair needs tiles')
        result['pair'] = pair(tile_values[-1], black_slot, visible_slot)
    return result


def load(path):
    with Path(path).open('rb') as stream:
        raw = stream.read(LIMIT + 1)
    if len(raw) > LIMIT:
        raise ValueError('input size')
    def reject(_):
        raise ValueError('nonfinite JSON')
    return json.loads(raw.decode('utf-8-sig'), parse_constant=reject)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('pair', 'trace', 'bundle'))
    parser.add_argument('--input', type=Path, action='append', required=True)
    parser.add_argument('--black-slot', type=int)
    parser.add_argument('--visible-slot', type=int)
    parser.add_argument('--screenshot-sha256')
    parser.add_argument('--screenshot-utc')
    args = parser.parse_args()
    try:
        if not 1 <= len(args.input) <= MAX_SNAPSHOTS:
            raise ValueError('input count')
        values = [load(path) for path in args.input]
        if args.command == 'pair':
            if len(values) != 1:
                raise ValueError('pair count')
            result = pair(values[0], args.black_slot, args.visible_slot)
        elif args.command == 'trace':
            result = trace(values)
        else:
            result = bundle(values, screenshot_sha256=args.screenshot_sha256, screenshot_utc=args.screenshot_utc,
                            black_slot=args.black_slot, visible_slot=args.visible_slot)
        encoded = json.dumps(result, allow_nan=False)
        if len(encoded.encode()) > LIMIT:
            raise ValueError('output size')
        print(encoded)
        return 0
    except (OSError, ValueError, KeyError, TypeError, AttributeError, OverflowError):
        print(json.dumps(dict(schema=1, ok=False, error_code='input_rejected')))
        return 1


if __name__ == '__main__':
    sys.exit(main())
