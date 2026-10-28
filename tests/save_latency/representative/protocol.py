"""Fail-closed phase orchestration; effects supplied by the separately owned host."""
import re


def clear(value):
    # DM TRUE/FALSE constants serialize as 1/0, not necessarily JSON booleans.
    return type(value) in (int, bool) and value == 0


def process_identity(receipt):
    if (not isinstance(receipt, dict) or type(receipt.get('pid')) is not int or receipt['pid'] <= 0
            or not isinstance(receipt.get('started_utc'), str) or not receipt['started_utc']
            or not isinstance(receipt.get('binary_sha256'), str)
            or not re.fullmatch('[0-9a-f]{64}', receipt['binary_sha256'])):
        raise ValueError('Missing owned process creation and binary receipt')
    return receipt['pid'], receipt['started_utc']


def checked_status(status, commit, session=None):
    if (not isinstance(status, dict) or status.get('source') != commit
            or not isinstance(status.get('session'), str) or not status['session']
            or (session is not None and status['session'] != session)):
        raise ValueError('Wrong source or boot session')
    if status.get('clients') != 0 or status.get('error') or status.get('storage_error'):
        raise ValueError('Host clients or persistence error invalidates the run')
    rep = status.get('representative')
    if not isinstance(rep, dict) or rep.get('error') or rep.get('phase') == 'failed':
        raise ValueError('Missing or failed representative adapter')
    return rep


def saved_receipt(status, commit, session, phase, marker):
    rep = checked_status(status, commit, session)
    receipt = rep.get('receipt')
    if (rep.get('phase') != phase or rep.get('marker') != marker
            or not clear(status.get('save_busy')) or not isinstance(receipt, dict)
            or receipt.get('marker') != marker or receipt.get('session') != session):
        raise ValueError('Incomplete or wrong save phase')
    identity = receipt.get('identity')
    if (not isinstance(identity, dict) or identity.get('version') != 1
            or not isinstance(identity.get('generation'), str)
            or not re.fullmatch(r'round-v2:[0-9a-f]{32}', identity['generation'])
            or any(not isinstance(identity.get(key), str) or not re.fullmatch('[0-9a-f]{32}', identity[key])
                   for key in ('metadata', 'round'))
            or status.get('generation') != identity['generation']):
        raise ValueError('Missing production completed-generation identity')
    return dict(identity)


def compare_reader(before, after, commit, identity, marker, writer_process, reader_process, environment=None):
    checked_status(before, commit)
    rep = checked_status(after, commit)
    if process_identity(writer_process) == process_identity(reader_process):
        raise ValueError('Reader requires distinct owned process identity')
    if writer_process['binary_sha256'] != reader_process['binary_sha256']:
        raise ValueError('Reader binary differs from writer')
    if after['session'] == before['session']:
        raise ValueError('Fresh reader reused the writer boot')
    for field in ('map', 'maxx', 'maxy', 'maxz', 'game_id'):
        if before.get(field) is None or after.get(field) != before[field]:
            raise ValueError('Reader changed world identity: ' + field)
    if (not after.get('import_complete') or not after.get('playing')
            or any(not clear(after.get(key)) for key in ('save_busy', 'restart_busy', 'restart_hold', 'intent'))
            or after.get('generation') != identity['generation'] or rep.get('marker') != marker):
        raise ValueError('Reader failed actual completed import')
    original = before.get('fixture', {})
    restored = after.get('fixture', {})
    if (not isinstance(original.get('baseline'), dict) or not original['baseline']
            or restored.get('crates') != 1 or restored.get('nested_knives') != 1
            or restored.get('baseline') != original.get('baseline') or not restored.get('seeded')):
        raise ValueError('Reader lost or duplicated actual representative objects')
    if before.get('representative_boundaries') != after.get('representative_boundaries'):
        raise ValueError('Reader changed actual boundary turf types')
    if environment is not None:
        if (not isinstance(environment, dict) or not all(key in environment for key in ('season', 'time_of_day', 'research_clock'))
                or any(after.get(key) != environment[key] for key in ('season', 'time_of_day'))
                or type(after.get('research_clock')) not in (int, float)
                or after['research_clock'] < environment['research_clock']):
            raise ValueError('Reader changed saved environment or research clock')


def two_saves(host, commit, deadline, clock):
    """host exposes real session-bound query/poll and monotonic phase evidence.

    There is deliberately no fake default host and no native execution CLI.
    The production effect boundary is not available until an executor is admitted.
    """
    if deadline <= clock():
        raise TimeoutError('Aggregate phase budget exhausted')
    initial = host.status()
    checked_status(initial, commit)
    if not initial.get('ready') or initial.get('generation'):
        raise ValueError('First save requires ready world and empty output generation')
    session = initial['session']
    identities = []
    for action, phase, marker in (('first', 'first_complete', 1), ('second', 'second_complete', 2)):
        if clock() >= deadline:
            raise TimeoutError('Aggregate phase budget exhausted')
        accepted = host.query(action, session)
        checked_status(accepted, commit, session)
        completed = host.poll(phase, session, deadline)
        if clock() >= deadline:
            raise TimeoutError('Completed phase exceeded aggregate budget')
        identity = saved_receipt(completed, commit, session, phase, marker)
        if identities and identity['generation'] == identities[-1]['generation']:
            raise ValueError('Second save reused first generation')
        identities.append(identity)
    return {'writer_session': session, 'identities': identities,
            'fresh_active_reader': 'NOT EXECUTED', 'fresh_backup_reader': 'NOT EXECUTED',
            'acceptance': False}
