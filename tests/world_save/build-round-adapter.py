"""Extract actual fresh-round setup; isolate only its external effects."""
import hashlib


def generate(root, control=None):
    path = root / 'code/game/gameticker.dm'
    source = path.read_text(encoding='utf-8')
    marker = '/datum/controller/gameticker/proc/setup()'
    if source.count(marker) != 1:
        raise RuntimeError('Round setup marker changed')
    start = source.index(marker)
    end = source.index('\n/datum/controller/gameticker/proc/close_jobs()', start)
    body = source[start:end]
    if control == 'setup':
        marker = '\tif(map_storage.round_restored) return TRUE\n'
        if body.count(marker) != 2:
            raise RuntimeError('Round resume guard changed')
        body = body.replace(marker, '')
    return body, {path.relative_to(root).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()}
