"""Bounded, atomic terminal evidence; no native or network effects."""
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile

CAP = 65536


def encode(value):
    raw = (json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False) + '\n').encode('ascii')
    if len(raw) >= CAP:
        raise ValueError('Terminal receipt cap exceeded')
    return raw


def summary(value):
    try:
        raw = json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode('ascii')
        return {'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}
    except (TypeError, ValueError):
        return {'detail_serialization_failed': True}


def checkpoint(evidence):
    """Prefer exact cleanup rows; an explicit bounded fallback stays failed."""
    value = {key: evidence[key] for key in ('scope', 'head', 'error', 'cleanup', 'secondary_errors') if key in evidence}
    value.update(schema=1, result='FAIL; receipt finalization unconfirmed', terminal_committed=False)
    try:
        return encode(value)
    except (TypeError, ValueError):
        rows = evidence.get('cleanup', [])
        # The runner owns at most three Jobs. Unexpected additional rows remain
        # explicit uncertainty rather than disappearing into verified cleanup.
        cleanup = []
        for row in rows[:3]:
            cleanup.append({'phase': str(row.get('phase', 'unknown'))[:32],
                            'all_exited': row.get('all_exited') is True,
                            'error': str(row.get('error', ''))[:256],
                            'detail_omitted': True, 'original': summary(row)})
        return encode({'schema': 1, 'result': 'FAIL; receipt finalization unconfirmed',
                       'terminal_committed': False, 'detail_omitted': True,
                       'head': str(evidence.get('head', 'unknown'))[:64],
                       'error': str(evidence.get('error', ''))[:256],
                       'cleanup': cleanup, 'cleanup_rows_omitted': max(0, len(rows)-3),
                       'original_cleanup': summary(rows),
                       'secondary_errors': [{'phase': str(row.get('phase', 'unknown'))[:32],
                                             'error': str(row.get('error', ''))[:256]}
                                            for row in evidence.get('secondary_errors', [])[:8]],
                       'original_secondary_errors': summary(evidence.get('secondary_errors', []))})


def atomic_write(path, raw, *, expected=None, before_commit=lambda: None):
    """Flush a sibling temporary file, then publish it in one replacement."""
    path = Path(path)
    if len(raw) >= CAP:
        raise ValueError('Terminal receipt cap exceeded')
    def unchanged():
        if path.is_symlink():
            return False
        if expected is None:
            return not path.exists()
        return path.is_file() and path.stat().st_size < CAP and path.read_bytes() == expected
    if not unchanged():
        raise RuntimeError('Unexpected terminal receipt target')
    fd, temporary = tempfile.mkstemp(prefix='.'+path.name+'.', suffix='.tmp', dir=path.parent)
    temporary = Path(temporary)
    try:
        with os.fdopen(fd, 'wb') as stream:
            if stream.write(raw) != len(raw):
                raise OSError('Incomplete terminal receipt write')
            stream.flush()
            os.fsync(stream.fileno())
        # Check the original entry budget after all serialization/write/fsync
        # work, immediately before replacing the still-failed checkpoint.
        before_commit()
        if not unchanged():
            raise RuntimeError('Terminal receipt changed before commit')
        os.replace(temporary, path)
        temporary = None
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def persist(output, evidence, check):
    """Cleanup/checkpoint first; independently retain core evidence before finalizing."""
    output = Path(output)
    pending = checkpoint(evidence)
    saved = None
    failures = []
    for name in ('cleanup-receipt.json', 'receipt.json'):
        try:
            atomic_write(output/name, pending)
            if name == 'receipt.json':
                saved = pending
        except BaseException as error:
            failures.append({'phase': name, 'error': str(error)[:1024]})
    # These are this fixture's actual witnesses, not a gameplay take/viewport
    # claim. Failure of one must not prevent retention of the other.
    for name, keys in (
            ('source-receipt.json', ('head', 'source_sha256', 'input_sprite_sha256')),
            ('capture-receipt.json', ('head', 'captures', 'client'))):
        try:
            check()
            raw = encode({'scope': evidence['scope'],
                          **{key: evidence[key] for key in keys if key in evidence}})
            atomic_write(output/name, raw, before_commit=check)
        except BaseException as error:
            failures.append({'phase': name, 'error': str(error)[:1024]})
    try:
        if failures:
            raise RuntimeError('Independent terminal evidence retention failed')
        if str(evidence.get('result', '')).startswith('PASS'):
            rows = evidence.get('cleanup', [])
            if (len(rows) != 3 or {row.get('phase') for row in rows} != {'compile','server','client'} or
                    any(row.get('all_exited') is not True or row.get('error') or row.get('errors') for row in rows) or evidence['secondary_errors'] or
                    evidence.get('error') is not None or evidence.get('client') != 'guest=1;version=516;build=1688' or
                    not evidence.get('source_sha256') or set(evidence.get('captures', {})) != {'red','blue'}):
                raise RuntimeError('Incomplete terminal acceptance evidence')
            for phase, row in evidence['captures'].items():
                path = output/(phase+'.png')
                if (path.is_symlink() or not path.is_file() or path.stat().st_size > 1024**2 or
                        row.get('size') not in ([224,224], (224,224)) or
                        re.fullmatch('[0-9a-f]{64}', row.get('sha256', '')) is None):
                    raise RuntimeError('Invalid terminal capture evidence')
                with path.open('rb') as stream:
                    raw = stream.read(1024**2+1)
                if len(raw) > 1024**2 or hashlib.sha256(raw).hexdigest() != row['sha256']:
                    raise RuntimeError('Changed terminal capture evidence')
        raw = encode(dict(evidence, terminal_committed=True))
        atomic_write(output/'receipt.json', raw, expected=saved, before_commit=check)
        return
    except BaseException as error:
        failures.append({'phase': 'final-receipt', 'error': str(error)[:1024]})
        evidence['secondary_errors'].extend(failures)
        evidence['result'] = 'FAIL; receipt finalization unconfirmed'
        # One bounded corrective write, even after the budget expires. If it
        # fails, the earlier failed checkpoint and independent cleanup remain.
        try:
            atomic_write(output/'receipt.json', checkpoint(evidence), expected=saved)
        except BaseException as corrective:
            evidence['secondary_errors'].append({'phase': 'receipt-write', 'error': str(corrective)[:1024]})
        raise
