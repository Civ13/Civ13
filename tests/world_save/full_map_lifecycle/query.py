"""Fixed authenticated operations on a separately prepared local test host."""
import argparse
import json
from pathlib import Path
import socket
import struct
from urllib.parse import urlencode

from prepare import BASE


def read_exact(connection, count):
    result = bytearray()
    while len(result) < count:
        part = connection.recv(count - len(result))
        if not part:
            raise RuntimeError('Truncated native response')
        result.extend(part)
    return bytes(result)


def request(port, token, action, session):
    query = urlencode({'full_map_probe': '1', 'token': token,
                       'action': action, 'session': session}).encode('ascii')
    payload = b'\0' * 5 + query + b'\0'
    with socket.create_connection(('127.0.0.1', port), timeout=30) as connection:
        connection.sendall(b'\0\x83' + struct.pack('>H', len(payload)) + payload)
        header = read_exact(connection, 4)
        if header[:2] != b'\0\x83':
            raise RuntimeError('Wrong native response header')
        body = read_exact(connection, struct.unpack('>H', header[2:])[0])
    if not body or body[0] != 6:
        raise RuntimeError('Native response must be text')
    # No raw query or token appears in diagnostics.
    response = body[1:].rstrip(b'\0').decode('utf-8')
    if response == 'rejected':
        raise PermissionError('Native adapter rejected the operation')
    result = json.loads(response)
    if not isinstance(result, dict):
        raise RuntimeError('Native response must be a JSON object')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run-root', type=Path, required=True)
    parser.add_argument('--port', type=int, required=True)
    parser.add_argument('--action', choices=('status', 'start', 'restart'), default='status')
    args = parser.parse_args()
    if not 1024 <= args.port <= 65535 or args.port in (18459, 18460, 18461, 18462):
        parser.error('Use a separate test port; protected existing hosts are excluded')
    manifest = json.loads((args.run_root / 'prepare.json').read_text(encoding='utf-8'))
    if manifest['source_commit'] != BASE:
        raise RuntimeError('Prepared source identity differs from pinned source')
    token = (args.run_root / 'game/config/full-map-probe-token.txt').read_text(encoding='ascii').strip()
    status = request(args.port, token, 'status', 'observe')
    if status.get('source') != BASE or not status.get('session'):
        raise RuntimeError('Host did not authenticate the pinned source and session')
    if args.action != 'status':
        status = request(args.port, token, args.action, status['session'])
    print(json.dumps(status))


if __name__ == '__main__':
    main()
