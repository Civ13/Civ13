"""One-shot operator grant binding. No signature/authentication claim; no native IO."""
import os
import re
from pathlib import Path
from prepare import HEAD, TREE, ADAPTER, bounded_file, canonical, digest
from oracle import strict_json


def consume_grant(path, controller, binding):
    path = Path(path).absolute()
    if any(p.is_symlink() for p in (path, *path.parents)):
        raise ValueError('Linked grant path')
    raw = bounded_file(path, 16384)
    grant = strict_json(raw)
    expected = {'schema': 1, 'adapter': ADAPTER, 'head': HEAD, 'tree': TREE,
                'candidate_manifest_sha256': binding,
                'controller_sha256': digest(canonical(controller)),
                'archive_sha256': '16278f318cdeb4b77c57868dd7135032fde717ea6226269d22b2a1a50968e7f9',
                'phases': 12, 'compiler_phases': 5, 'daemon_phases': 7,
                'aggregate_wall_seconds': 1200}
    if set(grant) != set(expected) | {'grant_id'} or any(grant.get(k) != v or type(grant[k]) is not type(v) for k,v in expected.items()):
        raise ValueError('Grant is not bound to this exact activation')
    if not isinstance(grant['grant_id'],str) or not re.fullmatch(r'[A-Za-z0-9_-]{1,80}',grant['grant_id']):
        raise ValueError('Invalid grant identity')
    if bounded_file(path,16384) != raw:
        raise ValueError('Grant changed during admission')
    marker = path.with_name(path.name + '.consumed')
    # Consume before native spawn. Partial marker or later failure stays consumed.
    fd = os.open(marker, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    try:
        data = canonical({'grant_sha256': digest(raw), 'grant_id': grant['grant_id'], 'controller_sha256': expected['controller_sha256']})
        with os.fdopen(fd,'wb') as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
    except BaseException:
        # No retry or marker removal, even if receipt writing failed.
        raise
    return {'grant_id': grant['grant_id'], 'grant_sha256': digest(raw), 'consumed': True}
