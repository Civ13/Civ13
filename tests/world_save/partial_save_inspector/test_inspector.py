import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('inspector', Path(__file__).with_name('inspect-partial-save.py'))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


def report(version='. = 2\n'):
    return {'schema_version_export': version, 'port': 0, 'highest_entry': 513,
            'records': [{'entry': 513, 'type_export': '. = /obj/structure/bed/wood\n',
                         'fields': ['type', 'name', 'lastattacked']},
                        {'entry': 2, 'type_export': 'type = /mob/living/human\n',
                         'fields': ['type']}]}


class InspectorTests(unittest.TestCase):
    def test_primitive_version_forms(self):
        for version in ['2', '. = 2\n', '/format_version = 2\n', 'format_version = 2\n']:
            with self.subTest(version=version):
                self.assertEqual(m.sanitize_report(report(version))['format_version'], 2)

    def test_no_data_values(self):
        raw = report()
        raw['private_ignored'] = 'PRIVATE_TEST_PLAYER'
        raw['records'][0]['ignored_value'] = 'PRIVATE_TEST_PASSWORD'
        text = json.dumps(m.sanitize_report(raw))
        self.assertNotIn('PRIVATE_TEST', text)
        self.assertIn('/obj/structure/bed/wood', text)

    def test_type_string_not_accepted(self):
        self.assertEqual(m.exported_type('. = "/mob/PlayerPrivateName"'), 'unavailable')
        self.assertEqual(m.exported_type('. = /mob/living/human\nname = "PRIVATE"'), 'unavailable')
        self.assertEqual(m.exported_type('. = /mob/living/human'), '/mob/living/human')

    def test_wrong_version_rejected(self):
        for value in ['. = 1', '. = list(2)', '. = 2\nprivate = "secret"']:
            with self.assertRaises(RuntimeError):
                m.sanitize_report(report(value))

    def test_non_schema_field_rejected(self):
        raw = report()
        raw['records'][0]['fields'].append('Player Name: private')
        with self.assertRaises(RuntimeError):
            m.sanitize_report(raw)

    def test_order_rejected(self):
        raw = report()
        raw['records'].reverse()
        with self.assertRaises(RuntimeError):
            m.sanitize_report(raw)

    def test_report_is_bounded(self):
        raw = report()
        raw['records'][0]['fields'] = ['field_'+str(i) for i in range(300)]
        clean = m.sanitize_report(raw)
        self.assertEqual(len(clean['records'][0]['field_names']), 128)
        self.assertTrue(clean['records'][0]['field_names_truncated'])
        self.assertEqual(clean['records'][0]['field_count'], 300)

    def test_port_rejected(self):
        raw = report()
        raw['port'] = 1715
        with self.assertRaises(RuntimeError):
            m.sanitize_report(raw)

    def test_copy_preserves_source(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            source, dest = root/'source.sav', root/'copy.sav'
            source.write_bytes(b'private save data' * 100)
            before = source.read_bytes(), source.stat().st_mtime_ns
            result = m.stable_copy(source, dest)
            self.assertEqual(dest.read_bytes(), source.read_bytes())
            self.assertEqual(result['sha256'], m.digest(source))
            self.assertEqual(before, (source.read_bytes(), source.stat().st_mtime_ns))

    def test_copy_never_overwrites(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            source, dest = root/'source.sav', root/'copy.sav'
            source.write_bytes(b'source')
            dest.write_bytes(b'existing')
            with self.assertRaises(FileExistsError):
                m.stable_copy(source, dest)
            self.assertEqual(dest.read_bytes(), b'existing')

    def test_symlink_source_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            (root/'actual').write_bytes(b'source')
            (root/'source').symlink_to(root/'actual')
            with self.assertRaises(RuntimeError):
                m.stable_copy(root/'source', root/'copy')

    def test_oversize_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            (root/'source').write_bytes(b'12345')
            with patch.object(m, 'MAX_BYTES', 4), self.assertRaises(RuntimeError):
                m.stable_copy(root/'source', root/'copy')
            self.assertFalse((root/'copy').exists())

    def test_mutating_source_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            source = root/'source'
            source.write_bytes(b'original')
            actual_read = m.os.read
            changed = False
            def read(fd, size):
                nonlocal changed
                block = actual_read(fd, size)
                if block and not changed:
                    changed = True
                    with source.open('ab') as out:
                        out.write(b'mutation')
                return block
            with patch.object(m.os, 'read', read), self.assertRaises(RuntimeError):
                m.stable_copy(source, root/'copy')

    def test_reader_has_no_game_import_or_value_deserialization(self):
        self.assertNotIn('#include', m.READER)
        self.assertNotIn('>>', m.READER)
        self.assertNotIn('F[', m.READER)
        self.assertNotIn('new /obj', m.READER)
        self.assertNotIn('new /mob', m.READER)
        self.assertNotIn('/obj/inspector_fixture', m.READER)
        self.assertNotIn('/mob/inspector_fixture', m.READER)
        self.assertIn('F.ExportText("[path]/type")', m.READER)
        self.assertIn('var/ref = max(numeric_ids)', m.READER)
        self.assertIn('records.len < 12', m.READER)

    def test_reader_fail_closed_catch(self):
        new_body = m.READER.rsplit('/world/New()', 1)[1]
        self.assertIn('try\n', new_body)
        self.assertIn('catch(var/exception/E)', new_body)
        self.assertIn('del(world)\n        return', new_body)

    def test_native_cli_project_trusted_loopback(self):
        with patch.object(m, 'native_run', return_value='') as run:
            m.run_world(Path('/tmp/staging'), 'reader', 'sample')
            argv = run.call_args.args[0]
            self.assertIn('-trusted', argv)
            self.assertNotIn('-safe', argv)
            self.assertEqual(argv[argv.index('-ip') + 1], '127.0.0.1')
            self.assertIn('-nowebclient', argv)

    def test_selftest_rejects_any_private_source_argument(self):
        with patch.object(m.sys, 'argv', ['inspector', '--self-test-only', '--source', '/tmp/map_saves/2.sav']), \
                patch.object(m, 'stable_copy') as copy:
            with self.assertRaisesRegex(RuntimeError, 'must not receive a private source'):
                m.main()
            copy.assert_not_called()

    def test_selftest_returns_before_source_copy(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp).resolve()
            bin_path = home/'bin'
            bin_path.mkdir()
            for name in ('DreamMaker', 'DreamDaemon'):
                executable = bin_path/name
                executable.write_text('fixture-only placeholder')
                executable.chmod(0o700)
            with patch.object(m.sys, 'argv', ['inspector', '--self-test-only']), \
                    patch.object(m, 'BIN', bin_path), patch.object(m.os, 'geteuid', return_value=1000), \
                    patch.object(m.Path, 'home', return_value=home), patch.object(m, 'selftest') as selftest, \
                    patch.object(m, 'stable_copy') as copy, patch('builtins.print'):
                previous_umask = os.umask(0o077)
                try:
                    m.main()
                finally:
                    os.umask(previous_umask)
                selftest.assert_called_once()
                copy.assert_not_called()


if __name__ == '__main__':
    unittest.main()
