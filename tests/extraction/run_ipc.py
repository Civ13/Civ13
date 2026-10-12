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
    parser.add_argument('--publication-negative-control', action='store_true')
    parser.add_argument('--output', type=Path, help='New directory for synthetic compatibility fixture files')
    args = parser.parse_args()
    if args.proof_negative_control and args.publication_negative_control:
        parser.error('Choose one negative control')
    if args.output and (args.proof_negative_control or args.publication_negative_control or args.output.exists()):
        parser.error('Output requires a new directory and the unmutated fixture')
    root = Path(__file__).resolve().parents[2]
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    key = b'0123456789abcdef0123456789abcdef'
    compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    with tempfile.TemporaryDirectory(prefix='civ13-ipc-service-') as folder:
        target = Path(folder)
        files = ['account_store.dm', 'ipc_crypto.dm', 'ipc_wire.dm', 'ipc_request.dm', 'ipc_projection.dm', 'ipc_service.dm', 'ipc_spool.dm']
        for name in files:
            shutil.copy2(root / 'code/modules/1713/extraction' / name, target / name)
        if args.proof_negative_control:
            source = (target / 'ipc_service.dm').read_text()
            marker = 'extraction_ipc_equal(extraction_sha256(payload["proof"]), challenge["proof_digest"]) && '
            if source.count(marker) != 1:
                raise RuntimeError('Game-account proof mutation marker changed')
            (target / 'ipc_service.dm').write_text(source.replace(marker, ''))
        if args.publication_negative_control:
            source = (target / 'ipc_spool.dm').read_text()
            marker = ' || extraction_ipc_base64_encode(extraction_crypto_bytes(json_encode(response))) != envelope?["body"]'
            if source.count(marker) != 1:
                raise RuntimeError('Durable reply comparison mutation marker changed')
            (target / 'ipc_spool.dm').write_text(source.replace(marker, ''))
        shutil.copy2(root / 'tests/extraction/ipc_probe.dm', target / 'probe.dm')
        # This historical linking fixture deliberately contains opaque legacy
        # equipment. Production graph projection is covered by the full-source
        # equipment/economics runners; here it reports detail unavailable.
        (target / 'adapters.dm').write_text('/datum/extraction_equipment_codec/proc/validate(list/graph)\n\treturn FALSE\n')
        (target / 'probe.dme').write_text(''.join(f'#include "{name}"\n' for name in ['adapters.dm'] + files + ['probe.dm']))
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
            if args.publication_negative_control and phase == 'replay':
                if ran.returncode or not result.startswith('FAIL: authenticated marker alone cannot replace original durable receipt'):
                    print(log)
                    raise RuntimeError('Publication control did not fail at intended durable-receipt assertion')
                print('PASS: authenticated publication marker cannot substitute a different economic receipt')
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
        spool = target / 'data/safehouse_spool'
        inspect_key = hashlib.sha256(b'inspect-1').hexdigest()
        link_key = hashlib.sha256(b'link-1').hexdigest()
        if not (spool / f'{inspect_key}.reply.pending').exists():
            raise RuntimeError('Interrupted reply lost its publication marker')
        if args.output:
            shutil.copytree(spool, args.output / 'before-restart')
        if not run('replay'):
            return
        for identifier, file_key in (('inspect-1', inspect_key), ('link-1', link_key)):
            wire = json.loads((spool / f'{file_key}.reply').read_text())
            signed = f'civ13.safehouse.ipc.v1\nreply\n{wire["issued_at"]}\n{wire["expires_at"]}\n{wire["body"]}'
            if wire['mac'] != hmac.new(key, signed.encode(), hashlib.sha256).hexdigest():
                raise RuntimeError('Native published reply differs from independent signer')
            response = json.loads(base64.b64decode(wire['body'], validate=True))
            if response['request_id'] != identifier or response['status'] != 'committed' or wire['issued_at'] != 1000 or wire['expires_at'] != 1120:
                raise RuntimeError('Recovery changed immutable reply identity or time window')
            if (spool / f'{file_key}.reply.pending').exists():
                raise RuntimeError('Completed authenticated reply still marked unpublished')
        print('PASS: independent signer validates native immutable replies and expired-marker recovery')
        if args.output:
            source_head = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=root, check=True,
                                         capture_output=True, text=True).stdout.strip()
            source_dirty = bool(subprocess.run(['git', 'status', '--porcelain'], cwd=root, check=True,
                                               capture_output=True, text=True).stdout.strip())
            shutil.copytree(spool, args.output / 'after-restart')
            manifest = {'synthetic': True, 'source_head': source_head, 'source_dirty': source_dirty,
                        'protocol': 'civ13.safehouse.ipc.v1', 'key': key.decode(), 'clock': 1000,
                        'issued_at': 1000, 'expires_at': 1120,
                        'requests': {'inspect-1': inspect_key, 'link-1': link_key}}
            (args.output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='ascii')
            print(f'PASS: synthetic bot compatibility fixtures written to {args.output}')


if __name__ == '__main__':
    main()
