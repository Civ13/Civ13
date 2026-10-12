"""Compare production DM SHA-256/HMAC with independent Python standard-library vectors."""
import argparse
import base64
import hashlib
import hmac
import json
import os
from pathlib import Path
import random
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--negative-control', action='store_true')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    rng = random.Random(3082)
    vectors = []
    for size in (0, 1, 3, 55, 56, 63, 64, 65, 119, 120, 127, 128, 255, 8192):
        raw = bytes(rng.randrange(256) for _ in range(size))
        vectors.append({'kind': 'bytes', 'bytes': list(raw), 'expected': hashlib.sha256(raw).hexdigest()})
    for size in (0, 1, 63, 64, 65, 131, 4096):
        key = 'k' * size
        message = 'The quick brown fox jumps over the lazy dog'
        vectors.append({'kind': 'hmac', 'key': key, 'text': message,
                        'expected': hmac.new(key.encode(), message.encode(), hashlib.sha256).hexdigest()})
    fixture = json.loads((root / 'tests/extraction/signing-fixture.json').read_text())
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
        if args.negative_control:
            source = (target / 'ipc_crypto.dm').read_text()
            if source.count('"428a2f98"') != 1:
                raise RuntimeError('SHA-256 constant mutation marker changed')
            (target / 'ipc_crypto.dm').write_text(source.replace('"428a2f98"', '"428a2f99"'))
        (target / 'vectors.json').write_text(json.dumps(vectors), encoding='ascii')
        (target / 'probe.dme').write_text('#include "ipc_crypto.dm"\n#include "ipc_wire.dm"\n#include "probe.dm"\n')
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
        if (invalid_base64 || !isnull(extraction_sha256_bytes(list(-1))) || !isnull(extraction_sha256_bytes(list(256))) || !isnull(extraction_sha256_bytes(list(0.5))) || !isnull(extraction_sha256_bytes(null)))
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
        ran = subprocess.run([str(daemon), 'probe.dmb', *platform, '-safe', '-log', 'runtime.log'],
                             cwd=target, capture_output=True, text=True, timeout=60, creationflags=flags)
        result = (target / 'result.txt').read_text().strip() if (target / 'result.txt').exists() else 'MISSING'
        log = (target / 'runtime.log').read_text(errors='replace') if (target / 'runtime.log').exists() else ''
        print(result)
        if args.negative_control:
            if ran.returncode or not result.startswith('FAIL: vector 1:') or any(word in log.lower() for word in ('runtime error', 'bad ref', '## error')):
                print(log)
                raise RuntimeError('Corrupted SHA-256 negative control did not fail at the intended vector')
            print('PASS: independent vector rejects corrupted production SHA-256 constant')
            return
        if ran.returncode or not result.startswith('PASS:') or any(word in log.lower() for word in ('runtime error', 'bad ref', '## error')):
            print(log)
            raise RuntimeError('Native crypto verification failed')


if __name__ == '__main__':
    main()
