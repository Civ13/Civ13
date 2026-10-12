"""Native offline recovery command integration over disposable account files."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True)
    args = parser.parse_args()
    script = Path(__file__).with_name('recover.py')
    with tempfile.TemporaryDirectory(prefix='civ13-recovery-command-test-') as temporary:
        root = Path(temporary)
        owner = root / 'fixture'
        owner.mkdir()
        profile = dict(schema=1, owner='fixture', revision=1, level=2, stash=[], state='home', raid_sequence=3)
        payload = json.dumps(profile, separators=(',', ':')) + '\n'
        digest = hashlib.md5(payload.encode()).hexdigest()
        (owner / '0.snapshot').write_bytes(payload.encode())
        (owner / '0.intent').write_text(json.dumps(dict(schema=1, owner='fixture', generation=1, digest=digest)), encoding='utf-8')
        def invoke(action, success, *additional):
            result = subprocess.run([sys.executable, str(script), '--byond-bin', args.byond_bin, '--store-root', str(root), '--owner', 'fixture', '--action', action, *additional], capture_output=True, text=True, timeout=90)
            if result.returncode != (0 if success else 1):
                raise AssertionError(result.stdout + result.stderr)
            report = json.loads(result.stdout)
            assert bool(report['success']) is success, report
            return report
        before = {p.name: p.read_bytes() for p in owner.iterdir()}
        report = invoke('inspect', True)
        assert report['slots'][0]['pending'] and report['intent0']['digest'] == digest
        assert before == {p.name: p.read_bytes() for p in owner.iterdir()}
        flags = ('--generation', '1', '--offline-confirmation', 'sole-server-stopped')
        invoke('complete-snapshot', False, *flags, '--digest', '0' * 32)
        assert before == {p.name: p.read_bytes() for p in owner.iterdir()}
        report = invoke('complete-snapshot', True, *flags, '--digest', digest)
        assert report['revision'] == 1 and (owner / 'recovery.latest.json').exists()
        invoke('complete-snapshot', False, *flags, '--digest', digest)
        profile.update(revision=2, loot_state='pending', pending_item=dict(id='uncertainitem', equipment={}))
        payload = json.dumps(profile, separators=(',', ':')) + '\n'
        digest = hashlib.md5(payload.encode()).hexdigest()
        (owner / '1.snapshot').write_bytes(payload.encode())
        (owner / '1.intent').write_text(json.dumps(dict(schema=1, owner='fixture', generation=2, digest=digest)), encoding='utf-8')
        (owner / '1.commit').write_text(json.dumps(dict(generation=2, digest=digest)), encoding='utf-8')
        report = invoke('retire-delivery', True, '--generation', '2', '--item', 'uncertainitem', '--offline-confirmation', 'sole-server-stopped')
        assert report['revision'] == 3
        report = invoke('inspect', True)
        latest = max(report['slots'], key=lambda slot: slot['generation'])['profile']
        assert latest['loot_state'] == 'ready' and latest['pending_item'] is None and latest['stash'] == []
        assert latest['retired_delivery']['id'] == 'uncertainitem'
        assert (owner / 'recovery.latest.json').exists()
        # Missing revision-4 snapshot cannot authorize replay of revision-3 gear.
        latest['stash'] = [dict(id='oldgear', equipment={})]
        payload = json.dumps(latest, separators=(',', ':')) + '\n'
        digest = hashlib.md5(payload.encode()).hexdigest()
        (owner / '0.snapshot').write_bytes(payload.encode())
        (owner / '0.intent').write_text(json.dumps(dict(schema=1, owner='fixture', generation=3, digest=digest)), encoding='utf-8')
        (owner / '0.commit').write_text(json.dumps(dict(generation=3, digest=digest)), encoding='utf-8')
        digest = 'a' * 32
        (owner / '1.intent').write_text(json.dumps(dict(schema=1, owner='fixture', generation=4, digest=digest)), encoding='utf-8')
        flags = ('--generation', '4', '--digest', digest, '--offline-confirmation', 'sole-server-stopped')
        invoke('complete-snapshot', False, *flags)
        invoke('settle-loss', False, *flags, '--loss-confirmation', 'discard-account-stash')
        (owner / 'recovery.latest.json').rename(root / 'archived-recovery.json')
        report = invoke('settle-loss', True, *flags, '--loss-confirmation', 'discard-account-stash')
        assert report['revision'] == 4
        latest = max(invoke('inspect', True)['slots'], key=lambda slot: slot['generation'])['profile']
        assert latest['stash'] == [] and latest['level'] == 2 and latest['state'] == 'home'
        invoke('settle-loss', False, *flags, '--loss-confirmation', 'discard-account-stash')
        latest.update(revision=5, garage_purchase=dict(id='paidconstruction', model='piccolino', status='pending', paid_revision=5, payment=[f'paidpart{i}' for i in range(25)]))
        payload = json.dumps(latest, separators=(',', ':')) + '\n'
        digest = hashlib.md5(payload.encode()).hexdigest()
        (owner / '0.snapshot').write_bytes(payload.encode())
        (owner / '0.intent').write_text(json.dumps(dict(schema=1, owner='fixture', generation=5, digest=digest)), encoding='utf-8')
        (owner / '0.commit').write_text(json.dumps(dict(generation=5, digest=digest)), encoding='utf-8')
        flags = ('--generation', '5', '--offline-confirmation', 'sole-server-stopped', '--loss-confirmation', 'forfeit-paid-car')
        before = {p.name: p.read_bytes() for p in owner.iterdir()}
        invoke('retire-vehicle', False, *flags, '--item', 'wrongconstruction')
        assert before == {p.name: p.read_bytes() for p in owner.iterdir()}
        report = invoke('retire-vehicle', True, *flags, '--item', 'paidconstruction')
        assert report['revision'] == 6 and (owner / 'garage-recovery.latest.json').exists()
        latest = max(invoke('inspect', True)['slots'], key=lambda slot: slot['generation'])['profile']
        assert latest['garage_purchase']['status'] == 'forfeited' and latest['garage'] == [] and latest['stash'] == []
        invoke('retire-vehicle', False, *flags, '--item', 'paidconstruction')
        assert not list(root.glob('recovery_report_*'))
    print('PASS: native offline recovery inspection, digest rejection, receipts, replay, delivery retirement and explicit loss settlement')


if __name__ == '__main__':
    main()
