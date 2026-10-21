"""Read fixed status only from the prepared local Gaia observer."""
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


def request(port, token):
    query = urlencode({'gaia_probe': '1', 'token': token, 'action': 'status'}).encode('ascii')
    payload = b'\0' * 5 + query + b'\0'
    with socket.create_connection(('127.0.0.1', port), timeout=15) as connection:
        connection.sendall(b'\0\x83' + struct.pack('>H', len(payload)) + payload)
        header = read_exact(connection, 4)
        if header[:2] != b'\0\x83':
            raise RuntimeError('Wrong native response header')
        body = read_exact(connection, struct.unpack('>H', header[2:])[0])
    if not body or body[0] != 6:
        raise RuntimeError('Native response must be text')
    response = body[1:].rstrip(b'\0').decode('utf-8')
    if response == 'rejected':
        raise PermissionError('Observer rejected the request')
    result = json.loads(response)
    if not isinstance(result, dict) or result.get('revision') != BASE or not result.get('session'):
        raise RuntimeError('Observer identity differs from pinned source')
    return result


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--run-root', type=Path, required=True)
    p.add_argument('--port', type=int, required=True)
    a = p.parse_args()
    if not 1024 <= a.port <= 65535 or a.port in (18459, 18460, 18461, 18462, 18463):
        p.error('Use a separate isolated port')
    receipt = json.loads((a.run_root / 'prepare.json').read_text(encoding='utf-8'))
    if receipt['source_commit'] != BASE:
        raise RuntimeError('Preparation identity differs')
    token = (a.run_root / 'game/config/lifecycle-token.txt').read_text(encoding='ascii').strip()
    print(json.dumps(request(a.port, token)))
