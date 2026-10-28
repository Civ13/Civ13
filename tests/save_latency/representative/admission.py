"""Operator-bound, persistent one-use caller; JSON claims do not grant authority."""
from datetime import datetime, timezone
import getpass
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import sys
import time
import uuid

import files

HERE = Path(__file__).resolve().parent
MAX_PACKET = 1024 * 1024


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode('utf-8')


def digest(value):
    return hashlib.sha256(canonical(value)).hexdigest()


def unique(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('Duplicate admission key')
        result[key] = value
    return result


def load(path):
    path = files.unlinked(path)
    if not path.is_file() or path.stat().st_size > MAX_PACKET:
        raise ValueError('Admission must be a bounded regular file')
    with path.open('rb') as stream:
        raw = stream.read(MAX_PACKET + 1)
    if len(raw) > MAX_PACKET:
        raise ValueError('Admission grew beyond its bound')
    return json.loads(raw, object_pairs_hook=unique)


class Operator:
    clock = staticmethod(time.monotonic)
    utcnow = staticmethod(lambda: datetime.now(timezone.utc))

    @staticmethod
    def identity():
        return {'host': platform.node(), 'account': getpass.getuser(),
                'python': str(Path(sys.executable).resolve()),
                'python_sha256': files.file_sha(Path(sys.executable))}

    @staticmethod
    def claim(path, value):
        # This directory must be the operator's shared, durable reservation store,
        # not a new per-run directory. An uncertain write still consumes the name.
        with path.open('xb') as stream:
            stream.write(canonical(value) + b'\n')
            stream.flush()
            os.fsync(stream.fileno())


def invoke(repository, resource, admission, expected_digest, *, operator=None, driver=None, run=None, anchor=None):
    """The supplied digest must come from independent review, not the same file.

    Claims bind an existing external reservation; this does not create an OS port
    lock or prove that other hosts/executors honor that reservation store.
    """
    operator, driver = operator or Operator(), files.unlinked(driver or HERE)
    start, utc = anchor if anchor is not None else (operator.clock(), operator.utcnow())
    if (type(start) not in (float, int) or not float('-inf') < start <= operator.clock() < float('inf')
            or not isinstance(utc, datetime) or utc.tzinfo is None):
        raise ValueError('Caller anchor must be a real, nonfuture entry observation')
    import execute
    if not re.fullmatch(r'[0-9a-f]{64}', expected_digest or '') or digest(admission) != expected_digest:
        raise ValueError('Independently reviewed admission digest differs')
    # Detach the reviewed values from the caller's mutable dictionaries.
    admission = json.loads(canonical(admission))
    resource = json.loads(canonical(resource))
    if admission.get('schema') != 1 or admission.get('authorized') is not True:
        raise ValueError('Actual operator authorization and allocation required')
    attempt = str(uuid.UUID(admission['attempt_id']))
    if attempt != admission['attempt_id'] or resource.get('allocation_id') != attempt:
        raise ValueError('One attempt must name the same allocation')
    for key in ('executor_thread', 'resource_owner', 'reservation_id', 'authority_reference'):
        if not isinstance(admission.get(key), str) or not admission[key].strip():
            raise ValueError('Missing operator evidence: ' + key)
    repository = files.unlinked(repository).resolve()
    if repository != files.unlinked(admission['repository']).resolve() or not repository.is_dir():
        raise ValueError('Source repository binding differs')
    if admission.get('resource_sha256') != digest(resource):
        raise ValueError('Output, port, limits or resource packet changed')
    output = execute.resource_packet(resource, utc)
    ledger = files.unlinked(admission['ledger_directory'])
    if (not ledger.is_absolute() or not ledger.is_dir() or ledger == output
            or ledger.is_relative_to(output) or ledger.is_relative_to(repository)
            or ledger.is_relative_to(driver) or output.is_relative_to(ledger)):
        raise ValueError('Use an existing external persistent reservation directory')
    expiry = datetime.fromisoformat(resource['expires_utc'].replace('Z', '+00:00'))
    end = start + min(resource['setup_seconds'] + execute.CORE_SECONDS, (expiry - utc).total_seconds())
    latest = start

    def fresh():
        nonlocal latest
        latest = max(latest, operator.clock(), start + (operator.utcnow() - utc).total_seconds())
        if latest >= end:
            raise TimeoutError('Caller entry-anchored allocation expired')

    expected_sources = admission.get('driver_sha256', {})
    names = {p.name for p in driver.iterdir() if p.is_file() and (p.suffix == '.py' or p.name == 'probe.dm')}
    if not names or set(expected_sources) != names:
        raise ValueError('Complete actual caller/driver source inventory required')

    def seals():
        observed = {p.name for p in driver.iterdir() if p.is_file() and (p.suffix == '.py' or p.name == 'probe.dm')}
        if observed != names:
            raise ValueError('Actual caller/driver inventory changed')
        if operator.identity() != admission.get('identity'):
            raise ValueError('Host/account/interpreter identity differs')
        for name in sorted(names):
            if files.file_sha(files.unlinked(driver / name)) != expected_sources[name]:
                raise ValueError('Reviewed caller/driver changed: ' + name)
            fresh()
        fresh()

    def measured_resources():
        sample = admission['resource_sample']
        measured = datetime.fromisoformat(sample['measured_utc'].replace('Z', '+00:00'))
        if (measured.tzinfo is None or not 0 <= (operator.utcnow() - measured).total_seconds() <= 60
                or sample.get('host') != admission['identity']['host']
                or sample.get('cpu_accepted_by_owner') is not True
                or type(sample.get('output_volume_free_bytes')) is not int
                or sample['output_volume_free_bytes'] < resource['minimum_free_bytes']):
            raise ValueError('Current host/resource-owner admission evidence missing or stale')
        fresh()

    fresh()
    seals()
    measured_resources()
    # No invocation if hashing or the durable claim took the remaining budget.
    claim = ledger / (attempt + '.json')
    claim_value = {'attempt_id': attempt, 'admission_sha256': expected_digest,
                   'resource_sha256': digest(resource), 'state': 'CONSUMED_BEFORE_EXECUTION',
                   'native_acceptance': False}
    operator.claim(claim, claim_value)
    fresh()
    if load(claim) != claim_value:
        raise ValueError('Persistent one-use claim changed')
    seals()
    measured_resources()
    result = (run or execute.execute)(repository, resource, caller_deadline=end)
    fresh()
    if load(claim) != claim_value:
        raise ValueError('Persistent one-use claim changed during execution')
    seals()
    return result
