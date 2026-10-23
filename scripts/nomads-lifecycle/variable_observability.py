"""Bounded private variable evidence via existing status or an explicit local file.

No object lookup, eval, proc invocation, world traversal or runtime mutation.
All returned identities describe capture time only, including fresh captures.
"""
import argparse
from datetime import datetime, timezone
import json
import math
from pathlib import Path
import re
import sys

import read_blackout as reader

LIMIT = 32768
MAX_AGE_SECONDS = 60


class Rejected(ValueError):
    pass


def reject(code):
    raise Rejected(code)


def token(value, pattern, maximum=160):
    if not isinstance(value, str) or len(value) > maximum or not re.fullmatch(pattern, value):
        reject('schema_rejected')
    return value


def number(value, *, minimum=0):
    if type(value) not in (int, float) or not math.isfinite(value) or not minimum <= value <= 1e16:
        reject('schema_rejected')
    return value


def flag(value):
    if type(value) not in (int, bool) or value not in (0, 1):
        reject('schema_rejected')
    return bool(value)


def enum(value, choices):
    if not isinstance(value, str) or value not in choices:
        reject('schema_rejected')
    return value


def coordinates(value):
    return {key: number(value[key]) for key in ('x', 'y', 'z')}


def identity(value):
    if not isinstance(value, dict):
        reject('schema_rejected')
    present = flag(value['present'])
    result = dict(present=present,
                  validity=enum(value['validity'], ('capture_only',)),
                  generation=enum(value['generation'], ('unavailable',)))
    if present:
        result['lookup_ref'] = token(value['lookup_ref'], r'\[0x[0-9a-f]{1,16}\]')
        result['type'] = token(value['type'], r'/[A-Za-z0-9_/]+')
        for key in ('gc_destroyed', 'gcDestroyed'):
            result[key] = None if value[key] is None else number(value[key], minimum=-2)
    elif any(value.get(key) is not None for key in ('lookup_ref', 'type', 'gc_destroyed', 'gcDestroyed')):
        reject('schema_rejected')
    result['location_state'] = enum(value['location_state'], ('found', 'no_turf', 'not_atom', 'cycle', 'depth_limit'))
    path = value['location_chain']
    if not isinstance(path, list) or len(path) > 8:
        reject('schema_rejected')
    result['location_chain'] = [dict(lookup_ref=token(row['lookup_ref'], r'\[0x[0-9a-f]{1,16}\]'),
                                   type=token(row['type'], r'/[A-Za-z0-9_/]+')) for row in path]
    if 'native' in value:
        result['native'] = coordinates(value['native'])
    if result['location_state'] == 'found':
        turf = value['turf']
        result['turf'] = coordinates(turf) | dict(lookup_ref=token(turf['lookup_ref'], r'\[0x[0-9a-f]{1,16}\]'))
        if not path or path[-1]['lookup_ref'] != turf['lookup_ref']:
            reject('schema_rejected')
    elif 'turf' in value:
        reject('schema_rejected')
    return result


def membership(value):
    result = {key: number(value[key]) for key in ('total', 'scanned', 'matches_in_prefix')}
    if not 0 <= result['matches_in_prefix'] <= result['scanned'] <= min(256, result['total']):
        reject('schema_rejected')
    result['complete'] = flag(value['complete'])
    if result['complete'] != (result['total'] == result['scanned']):
        reject('schema_rejected')
    result['membership'] = enum(value['membership'], ('present', 'absent', 'unknown', 'unavailable'))
    expected = 'present' if result['matches_in_prefix'] else ('absent' if result['complete'] else 'unknown')
    if result['membership'] != 'unavailable' and result['membership'] != expected:
        reject('schema_rejected')
    return result


def object_state(value, *, frame=False):
    result = identity(value)
    for key in ('thrown_list', 'processing_objects'):
        result[key] = membership(value[key])
    if 'throw' in value:
        throw = value['throw']
        result['throw'] = dict(throwing=flag(throw['throwing']))
        for key in ('throwmode', 'speed', 'range', 'dist_travelled', 'throw_speed', 'throw_range'):
            # Raw runtime fields can be null (including imported state). Do not
            # silently reinterpret an unknown value as a measured zero.
            result['throw'][key] = None if throw[key] is None else number(throw[key], minimum=-1e16)
        for key in ('original_target', 'thrower', 'throw_source'):
            result['throw'][key] = identity(throw[key])
    if frame:
        result['field'] = token(value['field'], r'[A-Za-z_][A-Za-z0-9_]*', 80)
        result['entry'] = number(value['entry'])
    return result


def operation(value):
    if value is None:
        return None
    result = dict(id=token(value['id'], r'operation-[1-9][0-9]*'),
                  kind=enum(value['kind'], ('save', 'load')),
                  stage=enum(value['stage'], ('admitted', 'backend', 'contents', 'restoring_players')),
                  started_tick=number(value['started_tick']))
    for key in ('backend_started', 'contents_started', 'mutation_started', 'restoring_players', 'owns_storage', 'active'):
        result[key] = flag(value[key])
    result['skip_counts_available'] = flag(value['skip_counts_available'])
    if value['skip_count_limit'] != 1000000000:
        reject('schema_rejected')
    result['skip_count_limit'] = 1000000000
    for key in ('runtime_field_skip_decisions', 'runtime_reference_skip_decisions', 'legacy_runtime_field_skip_decisions'):
        result[key] = number(value[key])
        if result[key] > result['skip_count_limit']:
            reject('schema_rejected')
    if result['runtime_reference_skip_decisions'] > result['runtime_field_skip_decisions']:
        reject('schema_rejected')
    if 'success' in value:
        result['success'] = flag(value['success'])
        result['finished_tick'] = number(value['finished_tick'])
        if result['active'] or result['finished_tick'] < result['started_tick']:
            reject('correlation_mismatch')
    return result


def envelope(value, revision, session, round_id, now, *, historical=False):
    if not isinstance(value, dict) or type(value.get('schema')) is not int or value['schema'] != 1:
        reject('schema_rejected')
    if value.get('revision') != revision or value.get('session') != session or value.get('round_id') != round_id:
        reject('correlation_mismatch')
    utc = token(value['utc'], r'\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}', 19)
    captured = datetime.strptime(utc, '%Y-%m-%d %H:%M:%S').replace(tzinfo=timezone.utc)
    age = (now - captured).total_seconds()
    if age < 0 or (not historical and age > MAX_AGE_SECONDS):
        reject('stale_snapshot')
    return dict(schema=1, revision=revision, session=session, round_id=round_id,
                tick=number(value['tick']), realtime=number(value['realtime']), utc=utc,
                age_seconds=age, freshness='historical_only' if historical else 'within_60_seconds',
                identity_validity='capture_only', live_resolution='unsupported')


def failure(value, revision, session, round_id, now, *, historical=False):
    if flag(value.get('partial', True)):
        reject('partial_snapshot')
    result = envelope(value, revision, session, round_id, now, historical=historical)
    result['snapshot_id'] = token(value['snapshot_id'], r'failure-[1-9][0-9]*')
    result['historical'] = flag(value['historical'])
    if not result['historical'] or value['live_resolution'] != 'unsupported':
        reject('schema_rejected')
    result['operation'] = operation(value['operation'])
    if not result['operation'] or not result['operation']['owns_storage']:
        reject('correlation_mismatch')
    result['kind'] = enum(value['kind'], ('cross_level_object', 'duplicate_durable_entry', 'operation_failed'))
    result['policy_classification'] = enum(value['policy_classification'],
        ('rejected_by_persistence_guard', 'operation_failed_without_reference_context'))
    if result['kind'] == 'operation_failed':
        if result['policy_classification'] != 'operation_failed_without_reference_context':
            reject('schema_rejected')
        if result['operation'].get('success') is not False:
            reject('correlation_mismatch')
        return result
    if result['operation']['kind'] != 'save':
        reject('correlation_mismatch')
    if result['policy_classification'] != 'rejected_by_persistence_guard':
        reject('schema_rejected')
    for key in ('saved_z', 'current_entry', 'first_z', 'first_entry'):
        result[key] = number(value[key])
    chain = value['owner_chain']
    if not isinstance(chain, list) or len(chain) > 8:
        reject('schema_rejected')
    result['owner_chain'] = [object_state(row, frame=True) for row in chain]
    result['owner_chain_truncated'] = flag(value['owner_chain_truncated'])
    result['source'] = object_state(value['source'], frame=bool(chain))
    if chain and result['source'] != result['owner_chain'][-1]:
        reject('correlation_mismatch')
    result['target'] = object_state(value['target'])
    return result


def inspect(value, revision, session, round_id, *, now=None, status=True, historical=False):
    now = now or datetime.now(timezone.utc)
    if not status:
        return failure(value, revision, session, round_id, now, historical=historical)
    if historical:
        reject('invalid_input')
    if not isinstance(value, dict) or value.get('schema') != 1:
        reject('unavailable')
    if not flag(value.get('enabled', False)):
        reject('disabled')
    result = envelope(value, revision, session, round_id, now)
    result['operation'] = operation(value['operation'])
    result['last_operation'] = operation(value['last_operation'])
    result['failure'] = None
    result['failure_error'] = None
    if value['failure'] is not None:
        # Current ownership has its own fresh, correlated header. An old or
        # rejected retained record must not hide that independently valid state.
        try:
            old = failure(value['failure'], revision, session, round_id, now)
            if not 0 <= result['tick'] - old['tick'] <= 600 or not 0 <= result['realtime'] - old['realtime'] <= 600:
                reject('stale_snapshot')
            owner = result['operation'] or result['last_operation']
            if not owner or owner['id'] != old['operation']['id']:
                reject('correlation_mismatch')
        except Rejected as error:
            result['failure_error'] = str(error)
        except (ValueError, KeyError, TypeError, OverflowError, AttributeError, RecursionError):
            result['failure_error'] = 'schema_rejected'
        else:
            result['failure'] = old
    return result


def identity_header(value, revision, session, *, now=None):
    """Discovery only: a bounded current header, never retained object evidence."""
    if value is None:
        return dict(available=False, reason='unavailable')
    if not isinstance(value, dict) or value.get('schema') != 1:
        reject('schema_rejected')
    if not flag(value.get('enabled', False)):
        return dict(available=False, reason='disabled')
    round_id = token(value['round_id'], r'[A-Za-z0-9_-]{1,160}')
    return dict(available=True, **envelope(value, revision, session, round_id,
                                         now or datetime.now(timezone.utc)))


def run(*, revision, session, round_id, root=None, input_path=None, transport=reader.exchange, now=None, historical=False):
    try:
        token(revision, r'[0-9a-f]{40}')
        token(session, r'[0-9a-f]{32}')
        token(round_id, r'[A-Za-z0-9_-]{1,160}')
        if (root is None) == (input_path is None):
            reject('invalid_input')
        if historical and input_path is None:
            reject('invalid_input')
        if input_path is not None:
            raw = reader.bounded_text(input_path, LIMIT + 2)
            if len(raw.encode('utf-8')) > LIMIT:
                reject('schema_rejected')
            value = json.loads(raw)
            data = inspect(value, revision, session, round_id, now=now, status=False, historical=historical)
        else:
            config = json.loads(reader.bounded_text(Path(root) / 'supervisor.json', 16384))
            if config.get('port') != 1714:
                reject('invalid_input')
            credential = reader.bounded_text(Path(config['config_directory']) / 'lifecycle-token.txt', 128)
            token(credential, r'[0-9a-f]{32}')
            value = transport(dict(nomads_lifecycle='1', token=credential, action='status'))
            encoded = json.dumps(value, allow_nan=False)
            if len(encoded.encode('utf-8')) > LIMIT or credential in encoded:
                reject('schema_rejected')
            if not isinstance(value, dict) or value.get('ok') != 1 or value.get('revision') != revision or value.get('session') != session:
                reject('correlation_mismatch')
            data = inspect(value.get('debug', {}).get('variables'), revision, session, round_id, now=now)
        result = dict(schema=1, ok=True, read_only=True, data=data)
        if len(json.dumps(result, allow_nan=False).encode('utf-8')) > LIMIT:
            reject('schema_rejected')
        return result
    except Rejected as error:
        return dict(schema=1, ok=False, error_code=str(error))
    except (OSError, TimeoutError):
        return dict(schema=1, ok=False, error_code='transport_or_file_unavailable')
    except (ValueError, KeyError, TypeError, OverflowError, AttributeError, RecursionError):
        return dict(schema=1, ok=False, error_code='schema_rejected')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument('--root', type=Path, help='Existing private lifecycle supervisor root; one status query')
    source.add_argument('--input', type=Path, help='Explicit private automatic failure file; offline')
    parser.add_argument('--revision', required=True)
    parser.add_argument('--session', required=True)
    parser.add_argument('--round-id', required=True)
    parser.add_argument('--historical', action='store_true', help='Offline --input only; explicitly inspect old capture-time evidence')
    args = parser.parse_args()
    result = run(revision=args.revision, session=args.session, round_id=args.round_id,
                 root=args.root, input_path=args.input, historical=args.historical)
    print(json.dumps(result, allow_nan=False))
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    sys.exit(main())
