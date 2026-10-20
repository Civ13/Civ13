"""Explicit private query of the installed own-host blackout diagnostic action.

Never launches BYOND or updates a server. Do not run until deployment/query is
authorized. Tokens are read from existing private files, never command arguments.
"""
import argparse
from datetime import datetime, timezone
import json
import math
from pathlib import Path
import re
import socket
import struct
import sys
import time
import urllib.parse
import uuid

LIMIT = 32768


def exchange(values):
    payload = b'\0' * 5 + urllib.parse.urlencode(values).encode('ascii') + b'\0'
    if len(payload) > 2048:
        raise ValueError('request size')
    # Existing game Topic port, never a new listener or user-selected host/port.
    deadline = time.monotonic() + 15
    with socket.create_connection(('127.0.0.1', 1714), timeout=15) as connection:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError('request deadline')
        connection.settimeout(remaining)
        connection.sendall(b'\x00\x83' + struct.pack('>H', len(payload)) + payload)

        def read_exact(count):
            result = bytearray()
            while len(result) < count:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise TimeoutError('response deadline')
                connection.settimeout(remaining)
                part = connection.recv(count - len(result))
                if not part:
                    raise ValueError('incomplete response')
                result.extend(part)
            return bytes(result)

        header = read_exact(4)
        size = struct.unpack('>H', header[2:])[0]
        if header[:2] != b'\x00\x83' or not 1 < size <= LIMIT + 2:
            raise ValueError('response frame')
        body = read_exact(size)
        if body[0] != 6:
            raise ValueError('response type')
        if body[-1:] != b'\0' or b'\0' in body[1:-1]:
            raise ValueError('response terminator')
        raw = body[1:-1]
        if len(raw) > LIMIT:
            raise ValueError('response size')
        return json.loads(raw)


def bounded_text(path, limit):
    with Path(path).open('rb') as stream:
        raw = stream.read(limit + 1)
    if len(raw) > limit:
        raise ValueError('configuration size')
    return raw.decode('utf-8-sig').strip()


def collect(root, revision, *, transport=exchange, nonce=None):
    if not re.fullmatch(r'[0-9a-f]{40}', revision):
        raise ValueError('expected revision')
    config = json.loads(bounded_text(Path(root) / 'supervisor.json', 16384))
    if config.get('port') != 1714:
        raise ValueError('authorized port')
    directory = Path(config['config_directory'])
    token = bounded_text(directory / 'lifecycle-token.txt', 128)
    if not re.fullmatch(r'[0-9a-f]{32}', token):
        raise ValueError('existing token required')
    # Match BYOND ckey normalization for an existing ASCII host account only.
    host_text = bounded_text(directory / 'host.txt', 128)
    if not host_text.isascii():
        raise ValueError('host account encoding')
    target = re.sub(r'[^a-z0-9]', '', host_text.lower())
    if not 1 <= len(target) <= 64:
        raise ValueError('existing host account required')
    base = dict(nomads_lifecycle='1', token=token)
    reader_start = datetime.now(timezone.utc).isoformat()
    status = transport(base | {'action': 'status'})
    if not isinstance(status, dict) or not status.get('ok') or status.get('revision') != revision:
        raise ValueError('runtime revision mismatch')
    session = status.get('session')
    if not isinstance(session, str) or not re.fullmatch(r'[0-9a-f]{32}', session):
        raise ValueError('runtime session unavailable')
    request = nonce or uuid.uuid4().hex
    if not re.fullmatch(r'[0-9a-f]{32}', request):
        raise ValueError('request identity')
    result = transport(base | dict(action='diagnose', session=session, operation=request, target=target))
    # A response containing the credential is never printed/saved by this reader.
    encoded = json.dumps(result)
    if len(encoded.encode('utf-8')) > LIMIT or token in encoded:
        raise ValueError('unsafe response')
    if not isinstance(result, dict) or not result.get('ok') or result.get('schema') != 1:
        raise ValueError('diagnostic unavailable')
    if result.get('revision') != revision or result.get('session') != session or result.get('request') != request:
        raise ValueError('diagnostic identity mismatch')
    if not isinstance(result.get('target'), dict) or result['target'].get('ckey') != target:
        raise ValueError('diagnostic target mismatch')
    for field in ('partial', 'same_target'):
        if type(result.get(field)) not in (bool, int) or result[field] not in (0, 1):
            raise ValueError('diagnostic consistency unavailable')
    target_fields = result['target']
    if set(target_fields) != {'ckey', 'client_ref', 'mob_ref'} or not re.fullmatch(r'\[0x[0-9a-f]{1,16}\]', target_fields.get('client_ref', '')):
        raise ValueError('client identity unavailable')
    mob_ref = target_fields.get('mob_ref')
    if mob_ref is None:
        if not result['partial']:
            raise ValueError('unmarked missing mob')
    elif not isinstance(mob_ref, str) or not re.fullmatch(r'\[0x[0-9a-f]{1,16}\]', mob_ref):
        raise ValueError('mob identity unavailable')
    if result['same_target'] != 1 and not result['partial']:
        raise ValueError('unmarked partial response')
    for field in ('tick_start', 'tick_end'):
        if type(result.get(field)) not in (int, float) or not math.isfinite(result[field]):
            raise ValueError('diagnostic freshness unavailable')
    if result['tick_end'] < result['tick_start'] or (result['tick_end'] != result['tick_start'] and not result['partial']):
        raise ValueError('unmarked stale response')
    if not all(isinstance(result.get(field), str) and result[field] for field in ('utc_start', 'utc_end', 'game_id')):
        raise ValueError('runtime identity/freshness unavailable')
    result['reader_utc_start'] = reader_start
    result['reader_utc_end'] = datetime.now(timezone.utc).isoformat()
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--revision', required=True, help='Reviewed installed game commit, 40 lowercase hex')
    args = parser.parse_args()
    try:
        print(json.dumps(collect(args.root, args.revision), indent=2))
        return 0
    except (OSError, ValueError, KeyError, TypeError):
        # No token, raw packet, filesystem content or traceback in failure output.
        print('Private diagnostic query failed; inspect revision, authorization and runtime hold before retrying.', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
