"""Compare production DM SHA-256/HMAC with independent Python standard-library vectors."""
import argparse
import base64
from datetime import datetime, timezone
import hashlib
import hmac
import json
import os
from pathlib import Path
import random
import shutil
import subprocess
import tempfile
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--negative-control', action='store_true')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    rng = random.Random(3082)
    vectors = []
    for date in ('1970-01-01 00:00:00', '2000-02-29 23:59:59', '2026-10-12 06:00:01', '2100-03-01 00:00:00'):
        vectors.append({'kind': 'calendar', 'text': date,
                        'expected': str(int(datetime.strptime(date, '%Y-%m-%d %H:%M:%S').replace(tzinfo=timezone.utc).timestamp()))})
    for date in ('2001-02-29 00:00:00', '2100-02-29 00:00:00', '2026-00-01 00:00:00', '2026-01-01 aa:00:00'):
        vectors.append({'kind': 'calendar', 'text': date, 'expected': None})
    for coarse, ticks, exact in (('2026-10-11 23:59:59', 10, '2026-10-12 00:00:01'),
                                 ('2026-10-12 00:00:00', 863990, '2026-10-11 23:59:59'),
                                 ('2026-10-12 06:00:00', 216130, '2026-10-12 06:00:13')):
        vectors.append({'kind': 'clock', 'text': coarse, 'ticks': ticks,
                        'expected': str(int(datetime.strptime(exact, '%Y-%m-%d %H:%M:%S').replace(tzinfo=timezone.utc).timestamp()))})
    for size in (0, 1, 3, 55, 56, 63, 64, 65, 119, 120, 127, 128, 255, 8192):
        raw = bytes(rng.randrange(256) for _ in range(size))
        vectors.append({'kind': 'bytes', 'bytes': list(raw), 'expected': hashlib.sha256(raw).hexdigest()})
    for size in (0, 1, 63, 64, 65, 131, 4096):
        key = 'k' * size
        message = 'The quick brown fox jumps over the lazy dog'
        vectors.append({'kind': 'hmac', 'key': key, 'text': message,
                        'expected': hmac.new(key.encode(), message.encode(), hashlib.sha256).hexdigest()})
    fixture = json.loads((root / 'tests/extraction/signing-fixture.json').read_text())
    payloads = {'link.challenge': {'challenge_id': 'challenge-1'},
                'link.complete': {'challenge_id': 'challenge-1', 'proof': 'proof-1'},
                'stash.inspect': {'page': 0}, 'room.inspect': {'page': 7},
                'stash.detail': {'item_id': 'item-1', 'page': 31},
                'market.browse': {'page': 15},
                'room.quote': {'operation': 'upgrade', 'item_ids': ['item-1']},
                'room.manage': {'confirmation_token': 'token-1'},
                'trade.quote': {'item_ids': ['item-1', 'item-2'], 'sale_kind': 'server_buyback'},
                'trade.confirm': {'confirmation_token': 'token-1'},
                'trade.status': {'operation_request_digest': 'a' * 64, 'operation_request_id': 'original-1'},
                'market.list': {'confirmation_token': 'token-1'},
                'market.buy': {'confirmation_token': 'token-1'},
                'market.cancel': {'confirmation_token': 'token-1'}}
    for action, payload in payloads.items():
        request = {'protocol': 'civ13.safehouse.v1', 'request_id': 'request-1', 'discord_id': '1234567890123456789012',
                   'action': action, 'expected_account_revision': 4, 'payload': payload}
        unsigned = json.dumps(request, separators=(',', ':'))
        request['request_digest'] = hashlib.sha256(unsigned.encode()).hexdigest()
        raw = json.dumps(request, separators=(',', ':'))
        vectors.append({'kind': 'request', 'text': raw, 'accepted': True})
        for altered in (raw.replace('request-1', 'request-2'), raw + ' ',
                        raw.replace('"discord_id":', '"discord_id":"0","discord_id":'),
                        raw.replace('"expected_account_revision":4', '"expected_account_revision":4.0')):
            vectors.append({'kind': 'request', 'text': altered, 'accepted': False})
    invalid_requests = [
        ('stash.detail', {'item_id': 'item-1', 'page': 32}, '123', 4),
        ('stash.detail', {'item_id': '../account', 'page': 0}, '123', 4),
        ('market.browse', {'page': 16}, '123', 4),
        ('market.browse', {'page': 0, 'owner': 'victim'}, '123', 4),
        ('room.quote', {'operation': 'upgrade', 'item_ids': ['item-1']}, '123', None),
        ('room.quote', {'operation': 'downgrade', 'item_ids': ['item-1']}, '123', 4),
        ('room.quote', {'operation': 'upgrade', 'item_ids': ['same', 'same']}, '123', 4),
        ('room.quote', {'operation': 'upgrade', 'item_ids': []}, '123', 4),
        ('stash.inspect', {'page': -1}, '123', 4),
        ('stash.inspect', {'page': 8}, '123', 4),
        ('stash.inspect', {'page': 0, 'owner': 'victim'}, '123', 4),
        ('stash.inspect', {'page': 0}, '123x', 4),
        ('stash.inspect', {'page': 0}, '123', -1),
        ('stash.inspect', {'page': 0}, '123', 1.5),
        ('trade.quote', {'item_ids': ['same', 'same'], 'sale_kind': 'server_buyback'}, '123', 4),
        ('trade.quote', {'item_ids': [], 'sale_kind': 'server_buyback'}, '123', 4),
        ('trade.quote', {'item_ids': ['../account'], 'sale_kind': 'server_buyback'}, '123', 4),
        ('trade.quote', {'item_ids': ['item-1'], 'sale_kind': 'server_buyback'}, '123', None),
        ('trade.quote', {'listing_id': 'listing-1', 'sale_kind': 'player_purchase', 'price': 1}, '123', 4),
        ('trade.quote', {'listing_id': 'listing-1', 'sale_kind': 'unsupported'}, '123', 4),
        ('unknown.action', {'page': 0}, '123', 4),
    ]
    for action, payload, actor, revision in invalid_requests:
        request = {'protocol': 'civ13.safehouse.v1', 'request_id': 'request-1', 'discord_id': actor,
                   'action': action, 'expected_account_revision': revision, 'payload': payload}
        request['request_digest'] = hashlib.sha256(json.dumps(request, separators=(',', ':')).encode()).hexdigest()
        vectors.append({'kind': 'request', 'text': json.dumps(request, separators=(',', ':')), 'accepted': False})
    for kind in ('player_listing', 'player_purchase', 'listing_cancel'):
        payload = {'item_ids': ['item-1'], 'sale_kind': kind} if kind == 'player_listing' else {'listing_id': 'listing-1', 'sale_kind': kind}
        request = {'protocol': 'civ13.safehouse.v1', 'request_id': 'quote-1', 'discord_id': '123', 'action': 'trade.quote', 'expected_account_revision': 4, 'payload': payload}
        request['request_digest'] = hashlib.sha256(json.dumps(request, separators=(',', ':')).encode()).hexdigest()
        vectors.append({'kind': 'request', 'text': json.dumps(request, separators=(',', ':')), 'accepted': True})
    for payload in ({'operation_request_id': 'original-1', 'operation_request_digest': 'a' * 64},
                    {'operation_request_digest': 'a' * 64, 'operation_request_id': 'original-1'}):
        request = {'protocol': 'civ13.safehouse.v1', 'request_id': 'recovery-1', 'discord_id': '123',
                   'action': 'trade.status', 'expected_account_revision': None, 'payload': payload}
        request['request_digest'] = hashlib.sha256(json.dumps(request, separators=(',', ':')).encode()).hexdigest()
        vectors.append({'kind': 'request', 'text': json.dumps(request, separators=(',', ':')), 'accepted': True})
    for size in (1, 2, 3, 4, 55, 256, 8192):
        raw = bytes(rng.randrange(256) for _ in range(size))
        vectors.append({'kind': 'base64', 'body': base64.b64encode(raw).decode(), 'bytes': list(raw)})
    envelope = fixture['envelope']
    signed = '\n'.join((envelope['protocol'], fixture['direction'], str(envelope['issued_at']),
                        str(envelope['expires_at']), envelope['body']))
    assert hmac.new(fixture['synthetic_key'].encode(), signed.encode(), hashlib.sha256).hexdigest() == envelope['mac']
    vectors.append({'kind': 'hmac', 'key': fixture['synthetic_key'], 'text': signed, 'expected': envelope['mac']})
    for timestamp in (1000, 1_800_000_001, 1_800_000_127, 1_800_057_599):
        body = base64.b64encode(b'{"value":"binary-safe / encoding"}').decode()
        issued, expires = timestamp, timestamp + 120
        signed = f'civ13.safehouse.ipc.v1\nrequest\n{issued}\n{expires}\n{body}'
        mac = hmac.new(fixture['synthetic_key'].encode(), signed.encode(), hashlib.sha256).hexdigest()
        wire = json.dumps({'protocol': 'civ13.safehouse.ipc.v1', 'issued_at': issued,
                           'expires_at': expires, 'body': body, 'mac': mac}, separators=(',', ':')).replace('/', '\\/')
        for offset, accepted in ((-6, False), (-5, True), (0, True), (120, True), (121, False)):
            vectors.append({'kind': 'wire', 'key': fixture['synthetic_key'], 'wire': wire,
                            'now': str(timestamp + offset), 'accepted': accepted})
        for altered in (wire.replace(mac, '0' * 64), wire.replace('"issued_at":', '"issued_at":0,"issued_at":'),
                        wire.replace(str(expires), str(expires + 1)), wire + ' '):
            vectors.append({'kind': 'wire', 'key': fixture['synthetic_key'], 'wire': altered,
                            'now': str(timestamp), 'accepted': False})
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    with tempfile.TemporaryDirectory(prefix='civ13-ipc-crypto-') as folder:
        target = Path(folder)
        shutil.copy2(root / 'code/modules/1713/extraction/ipc_crypto.dm', target / 'ipc_crypto.dm')
        shutil.copy2(root / 'code/modules/1713/extraction/ipc_wire.dm', target / 'ipc_wire.dm')
        shutil.copy2(root / 'code/modules/1713/extraction/ipc_request.dm', target / 'ipc_request.dm')
        if args.negative_control:
            source = (target / 'ipc_crypto.dm').read_text()
            if source.count('"428a2f98"') != 1:
                raise RuntimeError('SHA-256 constant mutation marker changed')
            (target / 'ipc_crypto.dm').write_text(source.replace('"428a2f98"', '"428a2f99"'))
        (target / 'vectors.json').write_text(json.dumps(vectors), encoding='ascii')
        (target / 'probe.dme').write_text('#include "ipc_crypto.dm"\n#include "ipc_wire.dm"\n#include "ipc_request.dm"\n#include "probe.dm"\n')
        (target / 'probe.dm').write_text('''world
    New()
        ..()
        world.OpenPort(0)
        var/list/vectors = json_decode(file2text("vectors.json"))
        var/count = 0
        for (var/list/vector in vectors)
            var/actual
            if (vector["kind"] == "bytes")
                actual = extraction_crypto_hex(extraction_sha256_bytes(vector["bytes"]))
            else if (vector["kind"] == "wire")
                actual = islist(extraction_ipc_verify(vector["wire"], vector["key"], vector["now"]))
                vector["expected"] = vector["accepted"]
            else if (vector["kind"] == "base64")
                actual = json_encode(extraction_ipc_base64_decode(vector["body"]))
                vector["expected"] = json_encode(vector["bytes"])
            else if (vector["kind"] == "request")
                actual = islist(extraction_ipc_request(extraction_crypto_bytes(vector["text"])))
                vector["expected"] = vector["accepted"]
            else if (vector["kind"] == "calendar")
                actual = extraction_ipc_time_text(extraction_ipc_calendar(vector["text"]))
            else if (vector["kind"] == "clock")
                actual = extraction_ipc_clock(vector["text"], vector["ticks"])
            else
                actual = extraction_hmac_sha256(vector["key"], vector["text"])
            count++
            if (actual != vector["expected"])
                text2file("FAIL: vector [count]: [actual]", "result.txt")
                shutdown()
                return
        var/invalid_base64 = FALSE
        for (var/value in list("A", "AA=A", "A===", "AB==", "AAB=", "AA==AAAA", "AA== ", "!!!!"))
            if (!isnull(extraction_ipc_base64_decode(value))) invalid_base64 = TRUE
        var/clock_difference = extraction_ipc_elapsed(extraction_ipc_time(extraction_ipc_now()), extraction_ipc_time(file2text("clock.txt")))
        if (isnull(clock_difference) || abs(clock_difference) > 3)
            text2file("FAIL: native UTC clock [clock_difference]", "result.txt")
        else if (invalid_base64 || !isnull(extraction_sha256_bytes(list(-1))) || !isnull(extraction_sha256_bytes(list(256))) || !isnull(extraction_sha256_bytes(list(0.5))) || !isnull(extraction_sha256_bytes(null)))
            text2file("FAIL: malformed bytes", "result.txt")
        else
            text2file("PASS: [count] independent signing/envelope vectors and malformed input rejection", "result.txt")
        shutdown()
''')
        compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
        daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
        built = subprocess.run([str(compiler), '-max_errors', '0', 'probe.dme'], cwd=target,
                               capture_output=True, text=True, timeout=60, creationflags=flags)
        print(built.stdout + built.stderr)
        if built.returncode or '516.1681' not in built.stdout or '0 errors, 0 warnings' not in built.stdout:
            raise RuntimeError('Pinned compiler failed')
        platform = ['-invisible', '-close'] if os.name == 'nt' else []
        (target / 'clock.txt').write_text(str(int(time.time())))
        ran = subprocess.run([str(daemon), 'probe.dmb', *platform, '-safe', '-log', 'runtime.log'],
                             cwd=target, capture_output=True, text=True, timeout=60, creationflags=flags)
        result = (target / 'result.txt').read_text().strip() if (target / 'result.txt').exists() else 'MISSING'
        log = (target / 'runtime.log').read_text(errors='replace') if (target / 'runtime.log').exists() else ''
        print(result)
        if args.negative_control:
            first_sha = next(index for index, vector in enumerate(vectors, 1) if vector['kind'] == 'bytes')
            if ran.returncode or not result.startswith(f'FAIL: vector {first_sha}:') or any(word in log.lower() for word in ('runtime error', 'bad ref', '## error')):
                print(log)
                raise RuntimeError('Corrupted SHA-256 negative control did not fail at the intended vector')
            print('PASS: independent vector rejects corrupted production SHA-256 constant')
            return
        if ran.returncode or not result.startswith('PASS:') or any(word in log.lower() for word in ('runtime error', 'bad ref', '## error')):
            print(log)
            raise RuntimeError('Native crypto verification failed')


if __name__ == '__main__':
    main()
