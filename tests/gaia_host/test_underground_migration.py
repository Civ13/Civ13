"""Offline tests for scripts/shard-group/underground_migration.py (migrate-underground)."""
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts/gaia-host'))
SPEC = importlib.util.spec_from_file_location('shard_group', ROOT / 'scripts/shard-group/shard_group.py')
shard_group = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(shard_group)
migration = shard_group.underground_migration

OLD = 'round-v2:' + 'a' * 32
NEW = 'round-v2:' + 'b' * 32


class FakePlatform:
    def __init__(self):
        self.open = set()

    def listening(self, port):
        return port in self.open


class FakeHost:
    def __init__(self, base):
        self.state_dir = base / 'state'
        self.stage_lock = base / 'stage.lock'
        self.platform = FakePlatform()
        self.state = 'stopped'
        self.busy = False

    def status(self):
        return {'state': self.state, 'listening': self.state == 'awake', 'busy': self.busy}

    def standby_port(self):
        return 1799


class MigrateUndergroundTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        self.group = {'group': 'earth', 'root': str(self.base / 'regions'), 'daemon': 'DreamDaemon',
                      'regions': [{'id': 'gaia', 'port': 1744}], 'transfers': False}
        self.region = self.base / 'regions' / 'gaia'
        self.saves = self.region / 'map_saves'
        self.saves.mkdir(parents=True)
        for name, body in (('map.txt', 'meta'), ('1.sav', 'old cave'), ('2.sav', 'surface')):
            (self.saves / name).write_text(body)
        (self.saves / 'save_complete.txt').write_text(OLD + '\n')
        (self.region / 'region.dmb').write_bytes(b'dmb')
        (self.region / 'region.rsc').write_bytes(b'rsc')
        (self.region / 'config').mkdir()
        (self.region / 'config' / 'config.txt').write_text('SERVER_NAME x\n')
        (self.region / 'config' / 'lifecycle-token.txt').write_text('secret\n')
        self.host = FakeHost(self.base)
        self.runs = []
        self.patch = mock.patch.object(shard_group, 'region_config',
                                       lambda group, region: {'state_dir': str(self.host.state_dir)})
        self.patch.start()

    def tearDown(self):
        self.patch.stop()
        self.tmp.cleanup()

    def world(self, migrate_ok=True, validate_ok=True):
        """A fake DreamDaemon: the migration rewrites level 1, the validator vouches for the files."""
        def run(argv, folder, timeout):
            self.runs.append((argv, folder))
            saves = folder / 'map_saves'
            if 'migrate_underground=1' in argv:
                self.assertFalse((folder / 'config' / 'lifecycle-token.txt').exists())
                if migrate_ok:
                    (saves / '1.sav').write_text('unformed rock')
                    (saves / 'save_complete.txt').write_text(NEW + '\n')
                report = {'ok': 1, 'lifted': {'players': ['val'], 'items': 3}} if migrate_ok else {'ok': 0, 'error': 'boom'}
                (folder / 'underground_migration.json').write_text(json.dumps(report))
                return 0
            self.assertIn('validate_save=1', argv)
            files = {p.name: shard_group.file_md5(p) for p in saves.iterdir()
                     if p.name not in shard_group.VALIDATOR_SKIPPED_SAVES}
            if validate_ok:
                (saves / 'validated.json').write_text(json.dumps(
                    {'kind': 'full', 'generation': NEW, 'files': files}))
            (folder / 'validation_result.json').write_text(json.dumps(
                {'ok': int(validate_ok), 'full': int(validate_ok), 'error': None if validate_ok else 'Missing level'}))
            return 0
        return run

    def migrate(self, **world):
        return migration.migrate(shard_group, self.group, self.host, 'gaia', run=self.world(**world), now=lambda: 0)

    def test_migrates_validates_and_swaps_the_save_in(self):
        report = self.migrate()
        self.assertTrue(report['ok'])
        self.assertEqual(NEW, report['generation'])
        self.assertEqual(['val'], report['migration']['lifted']['players'])
        self.assertEqual('unformed rock', (self.saves / '1.sav').read_text())
        self.assertEqual('full', json.loads((self.saves / 'validated.json').read_text())['kind'])
        backup = Path(report['backup'])
        self.assertEqual('old cave', (backup / '1.sav').read_text())
        self.assertTrue((backup / 'backup-receipt.json').exists())
        self.assertEqual(2, len(self.runs))
        self.assertEqual('region.dmb', self.runs[0][0][self.runs[0][0].index('DreamDaemon') + 1])
        self.assertFalse((self.base / 'regions' / '.migration' / 'gaia').exists())
        self.assertFalse((self.region / 'map_saves.pre-underground').exists())

    def test_a_migrated_save_that_lost_the_transfer_ledger_is_refused(self):
        ledger = {'generation': 'round-v2:old', 'effects': [], 'ledger_seq': 10}
        (self.saves / 'round.json').write_text(json.dumps({'transfer': ledger}))
        inner = self.world()

        def run(argv, folder, timeout):
            if 'migrate_underground=1' in argv:
                (folder / 'map_saves' / 'round.json').write_text(json.dumps({}))
            return inner(argv, folder, timeout)
        with self.assertRaisesRegex(migration.Refused, 'lost the transfer ledger'):
            migration.migrate(shard_group, self.group, self.host, 'gaia', run=run, now=lambda: 0)
        self.assertEqual('old cave', (self.saves / '1.sav').read_text())
        # A migration that keeps it goes through.
        self.assertTrue(migration.migrate(shard_group, self.group, self.host, 'gaia', run=inner, now=lambda: 60)['ok'])
        self.assertEqual(ledger, json.loads((self.saves / 'round.json').read_text())['transfer'])

    def test_a_failed_migration_leaves_the_region_alone(self):
        with self.assertRaisesRegex(shard_group.Refused, 'boom'):
            self.migrate(migrate_ok=False)
        self.assertEqual('old cave', (self.saves / '1.sav').read_text())
        self.assertEqual(1, len(self.runs))

    def test_a_save_that_does_not_validate_leaves_the_region_alone(self):
        with self.assertRaisesRegex(shard_group.Refused, 'did not validate'):
            self.migrate(validate_ok=False)
        self.assertEqual('old cave', (self.saves / '1.sav').read_text())
        self.assertFalse((self.saves / 'validated.json').exists())

    def test_refuses_a_running_busy_or_unsaved_region(self):
        self.host.state = 'awake'
        with self.assertRaisesRegex(shard_group.Refused, 'Save and stop'):
            self.migrate()
        self.host.state, self.host.busy = 'cold', True
        with self.assertRaisesRegex(shard_group.Refused, 'busy'):
            self.migrate()
        self.host.busy = False
        (self.saves / 'save_complete.txt').unlink()
        with self.assertRaisesRegex(shard_group.Refused, 'no completed save'):
            self.migrate()
        self.assertEqual([], self.runs)

    def test_the_action_is_offered(self):
        self.assertIn('migrate-underground', shard_group.GROUP_ACTIONS)
        argv = migration.migration_argv(shard_group, self.group, 'region.dmb', 'migrate_underground=1')
        self.assertIn('migrate_underground=1', argv)
        self.assertNotIn('validate_save=1', argv)
        self.assertIn('migrate_underground.log', argv)


if __name__ == '__main__':
    unittest.main()
