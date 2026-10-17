"""Bounded read-only agent tools over the existing private lifecycle interface.

Discovery is offline. Queries require separate runtime authorization; this
module never launches a process, changes configuration or repairs a world.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import sys

import read_blackout as reader

TOOLS = {
    'recovery': 'Read readiness, recovery hold and classified import failure; no client required.',
    'vision': 'Read the authenticated Host current body, HUD and vision snapshot.',
    'tiles': 'Compare the own tile and eight adjacent lighting samples from one capture.',
}


def discover():
    return dict(schema=1, ok=True, read_only=True, tools=[
        dict(name=name, description=description, runtime_required=True,
             input_schema=dict(type='object', additionalProperties=False,
                 required=['tool', 'root', 'revision'], properties=dict(
                     tool=dict(const=name), root=dict(type='string', minLength=1),
                     revision=dict(type='string', pattern='^[0-9a-f]{40}$'))))
        for name, description in TOOLS.items()],
        limits=dict(response_bytes=32768, request_seconds=15, tiles=9,
                    atoms_per_tile=64, registry_prefix=256),
        offline_commands=[dict(name=name, entrypoint='debug_bundle.py', schema=1,
                               runtime_required=False, max_inputs=8)
                          for name in ('pair', 'trace', 'bundle')],
        authorization='Existing loopback token; vision/tiles additionally require the connected Host.',
        unavailable=['arbitrary coordinates', 'raw logs or stack traces', 'save completion percentage',
                     'eval', 'repair', 'other players'],
        errors=['invalid_input', 'transport_unavailable', 'snapshot_rejected'])


def classify(error):
    # Never return a server exception, stack trace, private path or user text.
    if not error:
        return None
    for text, code in (
        ('non-turf location', 'lighting_non_turf_location'),
        ('owner mismatch', 'lighting_owner_mismatch'),
        ('duplicate registry entry', 'lighting_duplicate_registry'),
        ('Invalid imported lighting overlay registration', 'lighting_registration_invalid'),
        ('Intended generation import failed', 'generation_import_failed'),
    ):
        if text in error:
            return code
    return 'runtime_error_details_withheld'


def debug_state(value):
    if value is None:
        return dict(available=False, reason='not exposed by installed status schema')
    if not isinstance(value, dict) or value.get('schema') != 1:
        raise ValueError('debug schema')

    def count(number, nullable=False):
        if number is None and nullable:
            return None
        if type(number) not in (int, float) or not math.isfinite(number) or number < 0 or number != int(number):
            raise ValueError('counter')
        return number

    def flag(number):
        if type(number) not in (int, bool) or number not in (0, 1):
            raise ValueError('flag')
        return bool(number)

    progress, runtime = value['progress'], value['runtime']
    if progress.get('kind') not in ('idle', 'save', 'load') or flag(progress['percent_available']):
        raise ValueError('progress schema')
    safe_progress = dict(kind=progress['kind'], saving_z=count(progress['saving_z'], True),
                         loading_z=count(progress['loading_z'], True), percent_available=False)
    for key in ('active', 'backend_started', 'contents_started', 'mutation_started', 'restoring_players'):
        safe_progress[key] = flag(progress[key])
    if safe_progress['active'] != (safe_progress['kind'] != 'idle'):
        raise ValueError('progress consistency')
    if flag(runtime['stack_available']) or flag(runtime['proc_available']) or runtime['prefix_limit'] != 8:
        raise ValueError('runtime schema')
    sources = runtime['sources']
    if not isinstance(sources, list) or len(sources) > 8:
        raise ValueError('source bound')
    safe_sources = []
    for source in sources:
        path = source['file']
        if not isinstance(path, str) or len(path) > 160 or not re.fullmatch(r'code/[A-Za-z0-9_/.]+\.dm', path) or '..' in path:
            raise ValueError('source redaction')
        line = count(source['line'])
        if not 1 <= line <= 9999999:
            raise ValueError('source line')
        safe_sources.append(dict(file=path, line=line, **{key: count(source[key]) for key in ('logged', 'skipped', 'retired')}))
    safe_runtime = dict(cache_available=flag(runtime['cache_available']), prefix_limit=8,
                        stack_available=False, proc_available=False, sources=safe_sources,
                        **{key: count(runtime[key], True) for key in ('total', 'skipped', 'source_total')})
    return dict(available=True, schema=1, tick=count(value['tick']), progress=safe_progress, runtime=safe_runtime)


def recovery(root, revision, transport):
    config = json.loads(reader.bounded_text(Path(root) / 'supervisor.json', 16384))
    if config.get('port') != 1714:
        raise ValueError('port')
    token = reader.bounded_text(Path(config['config_directory']) / 'lifecycle-token.txt', 128)
    if not re.fullmatch(r'[0-9a-f]{32}', token):
        raise ValueError('token')
    status = transport(dict(nomads_lifecycle='1', token=token, action='status'))
    if (not isinstance(status, dict) or status.get('ok') != 1
            or status.get('revision') != revision
            or not re.fullmatch(r'[0-9a-f]{32}', status.get('session', ''))
            or len(json.dumps(status).encode('utf-8')) > reader.LIMIT
            or token in json.dumps(status)):
        raise ValueError('identity')
    flags = ('ready', 'busy', 'restart_hold', 'restart_import_complete', 'restart_intent')
    if any(type(status.get(key)) not in (int, bool) or status[key] not in (0, 1) for key in flags):
        raise ValueError('flags')
    error = status.get('error')
    if error is not None and not isinstance(error, str):
        raise ValueError('error')
    return dict(revision=revision, session=status['session'],
                **{key: bool(status[key]) for key in flags}, error_code=classify(error),
                debug=debug_state(status.get('debug')))


def run(tool, root=None, revision=None, *, transport=reader.exchange, nonce=None):
    # Library callers can supply JSON values even though argparse supplies text.
    if not isinstance(tool, str):
        return dict(schema=1, ok=False, error_code='invalid_input')
    if tool == 'discover':
        return discover()
    if tool not in TOOLS or root is None or not isinstance(revision, str) or not re.fullmatch(r'[0-9a-f]{40}', revision):
        return dict(schema=1, ok=False, error_code='invalid_input')
    try:
        if tool == 'recovery':
            data = recovery(root, revision, transport)
        else:
            capture = reader.collect(root, revision, transport=transport, nonce=nonce)
            sample = capture.get('sample')
            if not isinstance(sample, dict):
                raise ValueError('sample unavailable')
            data = {key: capture[key] for key in (
                'revision', 'session', 'request', 'partial', 'same_target', 'tick_start', 'tick_end')}
            target = capture['target']
            data['target_fingerprint'] = hashlib.sha256(json.dumps(
                [target['client_ref'], target['mob_ref']], separators=(',', ':')).encode()).hexdigest()
            keys = ('client', 'mob', 'living', 'human', 'plane_masters', 'known_hud') if tool == 'vision' else ('lighting_3x3', 'lighting_lifecycle', 'environment', 'bounded_sample_partial')
            data['sample'] = {key: sample[key] for key in keys if key in sample}
            if tool == 'tiles' and (not isinstance(sample.get('lighting_3x3'), list) or len(sample['lighting_3x3']) > 9):
                raise ValueError('tile bound')
        result = dict(schema=1, ok=True, tool=tool, data=data)
        if len(json.dumps(result, allow_nan=False).encode('utf-8')) > reader.LIMIT:
            raise ValueError('response bound')
        return result
    except (OSError, TimeoutError):
        return dict(schema=1, ok=False, tool=tool, error_code='transport_unavailable')
    except (ValueError, KeyError, TypeError, OverflowError, AttributeError):
        return dict(schema=1, ok=False, tool=tool, error_code='snapshot_rejected')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('tool', choices=['discover', *TOOLS])
    parser.add_argument('--root', type=Path)
    parser.add_argument('--revision')
    args = parser.parse_args()
    result = run(args.tool, args.root, args.revision)
    print(json.dumps(result, allow_nan=False))
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    sys.exit(main())
