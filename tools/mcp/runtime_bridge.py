"""Fixed, redacted adapter for the existing private one-request readers."""
import json
import os
from pathlib import Path
import re
import sys

SCRIPTS = Path(__file__).resolve().parents[2] / 'scripts' / 'nomads-lifecycle'
sys.path.insert(0, str(SCRIPTS))
import agent_debug
import variable_observability

ERRORS = frozenset(('invalid_input', 'transport_unavailable', 'transport_or_file_unavailable',
    'snapshot_rejected', 'stale_snapshot', 'schema_rejected', 'unavailable', 'disabled',
    'partial_snapshot', 'correlation_mismatch'))


def run(method, config, *, transport=None, now=None):
    root, revision, session, round_id = (config.get(k, '') for k in ('root', 'revision', 'session', 'round'))
    if (method not in ('recovery', 'variables') or not isinstance(root, str) or not Path(root).is_absolute()
            or root.startswith(('\\\\', '//'))
            or not isinstance(revision, str) or not re.fullmatch(r'[0-9a-f]{40}', revision)
            or not isinstance(session, str) or not re.fullmatch(r'[0-9a-f]{32}', session)
            or not isinstance(round_id, str) or not re.fullmatch(r'[A-Za-z0-9_-]{1,160}', round_id)):
        return dict(ok=False, error_code='invalid_configuration')
    if method == 'recovery':
        kwargs = {'transport': transport} if transport else {}
        result = agent_debug.run('recovery', root, revision, **kwargs)
        if not result.get('ok'):
            return dict(ok=False, error_code=result.get('error_code') if result.get('error_code') in ERRORS else 'snapshot_rejected')
        data = result['data']
        if data['session'] != session:
            return dict(ok=False, error_code='correlation_mismatch')
        debug = data['debug']
        if not debug.get('available') or debug.get('freshness') != 'within_60_seconds':
            return dict(ok=False, error_code='freshness_unavailable')
        return dict(ok=True, read_only=True, revision=revision, freshness=debug['freshness'],
                    age_seconds=debug['age_seconds'], tick=debug['tick'], progress=debug['progress'],
                    **{key: data[key] for key in ('ready', 'busy', 'restart_hold', 'restart_import_complete',
                                                 'restart_intent', 'error_code', 'captured_zone_row')})
    kwargs = {'transport': transport} if transport else {}
    result = variable_observability.run(root=root, revision=revision, session=session,
                                        round_id=round_id, now=now, **kwargs)
    if not result.get('ok'):
        return dict(ok=False, error_code=result.get('error_code') if result.get('error_code') in ERRORS else 'snapshot_rejected')
    data = result['data']
    # Never return source/target objects, native refs, arbitrary types or paths.
    operation_keys = ('id', 'kind', 'stage', 'started_tick', 'backend_started', 'contents_started',
                      'mutation_started', 'restoring_players', 'owns_storage', 'active', 'success',
                      'finished_tick', 'skip_counts_available', 'runtime_field_skip_decisions',
                      'runtime_reference_skip_decisions', 'legacy_runtime_field_skip_decisions')
    def operation(value):
        return {key: value[key] for key in operation_keys if key in value} if value else None
    failure = data.get('failure')
    return dict(ok=True, read_only=True, revision=revision, freshness=data['freshness'],
                age_seconds=data['age_seconds'], tick=data['tick'], operation=operation(data['operation']),
                last_operation=operation(data['last_operation']), failure_error=data['failure_error'],
                failure={key: failure[key] for key in ('kind', 'policy_classification') if key in failure} if failure else None)


def main():
    config = {key: os.environ.get('CIV13_RUNTIME_' + env, '') for key, env in (
        ('root', 'ROOT'), ('revision', 'REVISION'), ('session', 'SESSION'), ('round', 'ROUND'))}
    try:
        value = run(sys.argv[1] if len(sys.argv) == 2 else '', config)
        payload = json.dumps(value, allow_nan=False, separators=(',', ':'))
        if len(payload.encode('utf-8')) > 32768:
            raise ValueError('response limit')
    except Exception:
        payload = '{"ok":false,"error_code":"snapshot_rejected"}'
    print(payload)


if __name__ == '__main__':
    main()
