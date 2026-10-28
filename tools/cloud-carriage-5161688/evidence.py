"""Bounded post-cleanup evidence retention; no native calls or network."""
import hashlib
import json
import os
from pathlib import Path
import stat

CAP = 65536
WITNESSES = ('source-receipt.json', 'intro-take.json', 'intro-checks.txt',
             'intro-stop.txt', 'intro-cadence-admission.json', 'intro-cadence-start.json',
             'intro-cadence-end.json', 'intro-action-start.json',
             'intro-state-before.json', 'intro-state-after.json', 'intro-lease-result.json','intro-connected-window.json','intro-connected-phases.jsonl','intro-connected-disconnect.json')


def encoded(value):
    return (json.dumps(value, sort_keys=True, separators=(',', ':'),
                       allow_nan=False) + '\n').encode('utf-8')


def summary(value):
    try:
        raw = encoded(value)
        return {'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}
    except (TypeError, ValueError):
        return {'serialization_error': type(value).__name__[:64]}


def write_new(path, raw):
    if len(raw) >= CAP:
        raise ValueError('evidence_byte_cap')
    with Path(path).open('xb') as stream:
        if stream.write(raw) != len(raw):
            raise OSError('incomplete_evidence_write')
        stream.flush()
        os.fsync(stream.fileno())
    return {'status': 'retained', 'bytes': len(raw),
            'sha256': hashlib.sha256(raw).hexdigest()}


def retain_independent(source, output, result):
    """Attempt cleanup first, then every witness, regardless of other I/O errors."""
    source, output = Path(source), Path(output)
    records = {}
    cleanup = {'head': result.get('head'), 'run_id': result.get('run_id'),
               'admission': result.get('admission'), 'cleanup': result['cleanup']}
    try:
        raw = encoded(cleanup)
        if len(raw) >= CAP:
            # Never label an incomplete cleanup account verified.
            raw = encoded({'status': 'FAILED_CLEANUP_EVIDENCE_BOUND',
                           'all_exited': False, 'detail_omitted': True,
                           'original': summary(cleanup)})
            records['cleanup_detail'] = {'status': 'rejected', 'reason': 'byte_cap'}
        records['cleanup-receipt.json'] = write_new(output/'cleanup-receipt.json', raw)
    except (OSError, TypeError, ValueError) as error:
        records['cleanup-receipt.json'] = {'status': 'rejected', 'reason': type(error).__name__}
    for name in WITNESSES:
        path = source/name
        try:
            try:
                info = path.lstat()
            except FileNotFoundError:
                records[name] = {'status': 'absent'}
                continue
            limit = 16384 if name == 'filming-viewport.txt' else CAP
            if (not stat.S_ISREG(info.st_mode) or path.is_symlink() or
                    getattr(info, 'st_file_attributes', 0) & 0x400):
                raise ValueError('linked_or_nonregular_witness')
            if info.st_size >= limit:
                records[name] = {'status': 'rejected', 'reason': 'byte_cap',
                                 'bytes': info.st_size, 'limit': limit}
                continue
            with path.open('rb') as stream:
                raw = stream.read(limit)
            if len(raw) != info.st_size or len(raw) >= limit:
                raise ValueError('changed_or_oversize_witness')
            records[name] = write_new(output/name, raw)
        except (OSError, ValueError) as error:
            records[name] = {'status': 'rejected', 'reason': type(error).__name__}
    manifest = {'schema': 1, 'files': records, 'native_acceptance': False}
    try:
        write_new(output/'witness-receipt.json', encoded(manifest))
    except (OSError, ValueError) as error:
        records['witness-receipt.json'] = {'status': 'rejected', 'reason': type(error).__name__}
    if any(row['status'] == 'rejected' for row in records.values()):
        result['status'] = 'FAILED_EVIDENCE_RETENTION'
    return records


def write_aggregate(output, result):
    """Reference retained text; overflow emits explicit bounded failure summaries."""
    document = dict(result)
    records = document.get('independent_evidence', {})
    retained = records.get('intro-checks.txt', {})
    if retained.get('status') == 'retained':
        reference = {'artifact': 'intro-checks.txt', **retained}
        if 'native_checks' in document:
            document['native_checks'] = reference
        if 'failed_capture_readiness' in document:
            document['failed_capture_readiness'] = dict(document['failed_capture_readiness'])
            if 'native_checks' in document['failed_capture_readiness']:
                document['failed_capture_readiness']['native_checks'] = reference
    try:
        raw = encoded(document)
        if len(raw) >= CAP:
            raise ValueError('aggregate_byte_cap')
    except (TypeError, ValueError):
        result['status'] = 'FAILED_RECEIPT_BOUND'
        keys = list(document)[:64]
        raw = encoded({'status': result['status'], 'native_acceptance': False,
            'original_status': str(document.get('status'))[:128],
            'error': str(document.get('error', ''))[:1024],
            'detail_omitted': True, 'original': summary(document),
            'field_summaries': {str(k)[:128]: summary(document[k]) for k in keys},
            'unlisted_field_count': max(0, len(document)-len(keys)),
            'independent_evidence': 'cleanup-receipt.json and witness-receipt.json'})
    write_new(Path(output)/'receipt.json', raw)
