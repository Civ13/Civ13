"""Independent Python signer drives production native account linking over three processes."""
import argparse
import base64
import hashlib
import hmac
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--proof-negative-control', action='store_true')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    key = b'0123456789abcdef0123456789abcdef'
    compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    with tempfile.TemporaryDirectory(prefix='civ13-ipc-service-') as folder:
        target = Path(folder)
        files = ['account_store.dm', 'ipc_crypto.dm', 'ipc_wire.dm', 'ipc_request.dm', 'ipc_service.dm']
        for name in files:
            shutil.copy2(root / 'code/modules/1713/extraction' / name, target / name)
        if args.proof_negative_control:
            source = (target / 'ipc_service.dm').read_text()
            marker = 'extraction_ipc_equal(extraction_sha256(payload["proof"]), challenge["proof_digest"]) && '
            if source.count(marker) != 1:
                raise RuntimeError('Game-account proof mutation marker changed')
            (target / 'ipc_service.dm').write_text(source.replace(marker, ''))
        shutil.copy2(root / 'tests/extraction/ipc_probe.dm', target / 'probe.dm')
        (target / 'probe.dme').write_text(''.join(f'#include "{name}"\n' for name in files + ['probe.dm']))
        built = subprocess.run([str(compiler), '-max_errors', '0', 'probe.dme'], cwd=target,
                               capture_output=True, text=True, timeout=60, creationflags=flags)
        print(built.stdout + built.stderr)
        if built.returncode or '516.1681' not in built.stdout or '0 errors, 0 warnings' not in built.stdout:
            raise RuntimeError('Pinned compiler failed')

        def run(phase):
            (target / 'result.txt').unlink(missing_ok=True)
            platform = ['-invisible', '-close'] if os.name == 'nt' else []
            ran = subprocess.run([str(daemon), 'probe.dmb', *platform, '-safe', '-params', f'phase={phase}', '-log', 'runtime.log'],
                                 cwd=target, capture_output=True, text=True, timeout=60, creationflags=flags)
            result = (target / 'result.txt').read_text().strip() if (target / 'result.txt').exists() else 'MISSING'
            log = (target / 'runtime.log').read_text(errors='replace') if (target / 'runtime.log').exists() else ''
            print(result)
            if args.proof_negative_control and phase == 'process':
                if ran.returncode or not result.startswith('FAIL: request wrong-proof expected invalid_challenge, got '):
                    print(log)
                    raise RuntimeError('Proof omission did not fail at intended account-binding assertion')
                print('PASS: independent signed request rejects missing game-account proof verification')
                return False
            if ran.returncode or not result.startswith('PASS:') or any(word in log.lower() for word in ('runtime error', 'bad ref', '## error')):
                print(log)
                raise RuntimeError(f'Native service {phase} failed')
            return True

        run('issue')
        challenge = json.loads((target / 'challenge.json').read_text())
        cases = []

        def request(identifier, actor, action, payload, status, reason, revision=None, items=None):
            body = {'protocol': 'civ13.safehouse.v1', 'request_id': identifier, 'discord_id': actor,
                    'action': action, 'expected_account_revision': revision, 'payload': dict(sorted(payload.items()))}
            body['request_digest'] = hashlib.sha256(json.dumps(body, separators=(',', ':')).encode()).hexdigest()
            raw = json.dumps(body, separators=(',', ':')).encode()
            encoded = base64.b64encode(raw).decode()
            signed = f'civ13.safehouse.ipc.v1\nrequest\n1000\n1120\n{encoded}'
            envelope = {'protocol': 'civ13.safehouse.ipc.v1', 'issued_at': 1000, 'expires_at': 1120,
                        'body': encoded, 'mac': hmac.new(key, signed.encode(), hashlib.sha256).hexdigest()}
            case = {'id': identifier, 'wire': json.dumps(envelope, separators=(',', ':')).replace('/', '\\/'),
                    'status': status, 'reason': reason, 'items': items}
            cases.append(case)
            return body, case

        request('wrong-proof', '999', 'link.complete', {'challenge_id': challenge['challenge_id'], 'proof': 'wrong'}, 'rejected', 'invalid_challenge')
        linked, replay_link = request('link-1', '123', 'link.complete', {'challenge_id': challenge['challenge_id'], 'proof': challenge['proof']}, 'committed', 'account_linked')
        request('used-proof', '777', 'link.complete', {'challenge_id': challenge['challenge_id'], 'proof': challenge['proof']}, 'rejected', 'invalid_challenge')
        _, replay_inspect = request('inspect-1', '123', 'stash.inspect', {'page': 0}, 'committed', 'saved_snapshot', 1, 2)
        request('unlinked-inspect', '999', 'stash.inspect', {'page': 0}, 'rejected', 'unlinked_actor')
        request('stale-inspect', '123', 'room.inspect', {'page': 0}, 'rejected', 'stale_revision', 0)
        request('status-1', '123', 'trade.status', {'operation_request_id': linked['request_id'], 'operation_request_digest': linked['request_digest']}, 'committed', 'operation_status')
        request('wrong-status', '123', 'trade.status', {'operation_request_id': linked['request_id'], 'operation_request_digest': '0' * 64}, 'committed', 'operation_not_found')
        request('link-1', '777', 'link.complete', {'challenge_id': challenge['challenge_id'], 'proof': challenge['proof']}, 'rejected', 'request_id_conflict')
        (target / 'requests.json').write_text(json.dumps(cases), encoding='ascii')
        (target / 'replay.json').write_text(json.dumps([replay_link, replay_inspect]), encoding='ascii')
        if not run('process'):
            return
        run('replay')


if __name__ == '__main__':
    main()
