"""Offline fixture-only fresh-world transaction tests; never start a real server."""
import io
import json
from pathlib import Path
import sys
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import test_shard_group as fixture
shard_group = fixture.shard_group
fresh = shard_group.fresh_world


class FreshWorldTests(unittest.TestCase):
    setUp = fixture.ShardGroupTests.setUp
    tearDown = fixture.ShardGroupTests.tearDown
    write_group = fixture.ShardGroupTests.write_group
    def host(self):
        host = shard_group.hosts(self.write_group(), 'gaia', self.machine)[0][1]
        host.state_dir.mkdir(parents=True)
        (host.repo / '.git').write_text('gitdir: test')
        (host.repo / 'region.dmb').write_bytes(b'fixture')
        (host.repo / 'config').mkdir()
        for name in fresh.WORLD_PATHS:
            (host.repo / name).mkdir()
            (host.repo / name / 'fixture').write_text(name)
        return host

    def test_fresh_roundtrip_archive_preserves_accounts(self):
        host = self.host()
        accounts = host.repo / 'data/player_saves'
        accounts.mkdir(); (accounts / 'val.sav').write_bytes(b'account')
        result = fresh.request(host, 'gaia')
        with mock.patch.object(host, 'do_start') as start:
            host.work('fresh-world', result['operation'])
        start.assert_called_once()
        archive = Path(host.read_state()['archive'])
        for name in fresh.WORLD_PATHS:
            if name == "map_saves":
                self.assertEqual(list((host.repo / name).iterdir()), [])
            else:
                self.assertFalse((host.repo / name).exists())
            self.assertEqual((archive / name / 'fixture').read_text(), name)
        self.assertEqual((accounts / 'val.sav').read_bytes(), b'account')
        self.assertFalse(fresh.pending(host).exists())
        self.assertFalse(host.lock.exists())
        self.assertEqual(host.read_state()['phase'], 'done')

    def test_fresh_actual_start_uses_empty_save_without_update(self):
        host = self.host(); result = fresh.request(host, 'gaia')
        def start_task():
            self.machine.up.add(host.config['port'])
            return 0, 'fixture started'
        with mock.patch.object(host, 'start_task', side_effect=start_task):
            host.work('fresh-world', result['operation'])
        self.assertEqual(host.read_state()['phase'], 'done')
        self.assertIsNone(shard_group.gaia_host.check_save(host.repo / 'map_saves'))
        self.assertTrue(host.running_file.exists())
        self.assertFalse(any('fetch' in call[0] for call in self.machine.calls))

    def test_fresh_linked_archive_destination_refused(self):
        host = self.host()
        (host.state_dir / 'fresh-world-archives').symlink_to(host.repo / 'config', target_is_directory=True)
        with self.assertRaisesRegex(shard_group.Refused, 'archive'): fresh.request(host, 'gaia')

    def test_fresh_empty_save_creation_failure_holds(self):
        host = self.host(); result = fresh.request(host, 'gaia')
        mkdir = Path.mkdir
        def fail_empty(path, *args, **kwargs):
            if path == host.repo / 'map_saves': raise OSError('fixture mkdir failure')
            return mkdir(path, *args, **kwargs)
        with mock.patch.object(Path, 'mkdir', fail_empty), mock.patch.object(host, 'do_start') as start:
            host.work('fresh-world', result['operation'])
        start.assert_not_called()
        self.assertTrue(fresh.pending(host).exists())
        archive = Path(host.read_state()['archive'])
        for name in fresh.WORLD_PATHS: self.assertTrue((archive / name / 'fixture').exists())

    def test_fresh_wrong_confirmation_does_nothing(self):
        host = self.host()
        with self.assertRaises(shard_group.Refused): fresh.request(host, 'deep')
        self.assertTrue((host.repo / 'map_saves/fixture').exists())
        self.assertEqual(self.machine.detached, [])

    def test_fresh_running_refused(self):
        host = self.host(); self.machine.up.add(host.config['port'])
        with self.assertRaisesRegex(shard_group.Refused, 'stop'): fresh.request(host, 'gaia')
        self.assertFalse(host.lock.exists())

    def test_fresh_transfer_group_refused(self):
        host = self.host()
        for i, region in enumerate(self.group['regions']): region['transfer_port'] = 47000+i
        self.write_group()
        with self.assertRaisesRegex(shard_group.Refused, 'connected'): fresh.request(host, 'gaia')

    def test_fresh_existing_database_refused(self):
        host = self.host(); (host.state_dir / 'transfers.sqlite').write_bytes(b'db')
        with self.assertRaisesRegex(shard_group.Refused, 'transfer'): fresh.request(host, 'gaia')

    def test_fresh_separate_domain_refused(self):
        host = self.host(); (host.repo / 'data/extraction_accounts').mkdir()
        with self.assertRaisesRegex(shard_group.Refused, 'extraction'): fresh.request(host, 'gaia')

    def test_fresh_links_refused(self):
        host = self.host()
        (host.repo / 'map_saves/link').symlink_to(host.repo / 'config', target_is_directory=True)
        with self.assertRaisesRegex(shard_group.Refused, 'linked'): fresh.request(host, 'gaia')

    def test_fresh_partial_move_blocks_start_and_watchdog(self):
        host = self.host(); result = fresh.request(host, 'gaia')
        rename = fresh.os.rename
        def fail_second(source, dest):
            if source.name == 'map_backups': raise OSError('fixture interrupted')
            rename(source, dest)
        with mock.patch.object(fresh.os, 'rename', side_effect=fail_second), mock.patch.object(host, 'do_start') as start:
            host.work('fresh-world', result['operation'])
        start.assert_not_called()
        self.assertTrue(fresh.pending(host).exists())
        with self.assertRaisesRegex(shard_group.Refused, 'recovery'): host.request('start')
        with self.assertRaises(shard_group.Refused): host.thaw()
        self.assertEqual(host.watch_step(None), (None, 30))
        archive = Path(host.read_state()['archive'])
        self.assertTrue((archive / 'map_saves/fixture').exists())
        self.assertTrue((host.repo / 'map_backups/fixture').exists())

    def test_fresh_start_failure_keeps_archive(self):
        host = self.host(); result = fresh.request(host, 'gaia')
        with mock.patch.object(host, 'do_start', side_effect=RuntimeError('fixture boot failure')):
            host.work('fresh-world', result['operation'])
        self.assertFalse(fresh.pending(host).exists())
        self.assertTrue((Path(host.read_state()['archive']) / 'map_saves/fixture').exists())
        self.assertEqual(host.read_state()['phase'], 'failed')

    def test_fresh_rechecks_state_in_worker(self):
        host = self.host(); result = fresh.request(host, 'gaia')
        self.machine.up.add(host.config['port'])
        with mock.patch.object(host, 'do_start') as start: host.work('fresh-world', result['operation'])
        start.assert_not_called()
        self.assertTrue((host.repo / 'map_saves/fixture').exists())

    def test_fresh_cli_answer_is_ok_for_the_launcher(self):
        # LocalHosting.ParseGroup treats an answer without "ok" as "the group script gave no answer".
        host = self.host()
        out = io.StringIO()
        with mock.patch.object(shard_group, 'hosts', return_value=[({'id': 'gaia'}, host)]), mock.patch('sys.stdout', out):
            code = shard_group.main(['--config', str(self.path), 'fresh-world', '--region', 'gaia', '--confirm-region', 'gaia'])
        answer = json.loads(out.getvalue())
        self.assertEqual(0, code)
        self.assertIs(True, answer['ok'])
        self.assertEqual(['gaia'], list(answer['accepted']))
        self.assertEqual('fresh-world', answer['accepted']['gaia']['action'])

    def test_fresh_cli_mismatched_confirmation_refused(self):
        self.write_group()
        out = io.StringIO()
        with mock.patch('sys.stdout', out):
            code = shard_group.main(['--config', str(self.path), 'fresh-world', '--region', 'gaia', '--confirm-region', 'deep'])
        self.assertEqual(1, code)
        self.assertIs(False, json.loads(out.getvalue())['ok'])
        self.assertEqual(self.machine.detached, [])


if __name__ == '__main__':
    unittest.main()
