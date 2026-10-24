"""Offline reader compatibility, preparation and DM publication source controls.

These checks do not execute DM or establish Windows ACL/native I/O behavior.
"""
from datetime import timedelta
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

from test_variable_observability import ROOT, NOW, REVISION, SESSION, ROUND, failure, m


class Publication(unittest.TestCase):
    def assert_private_sink(self, source):
        body = source.split('/map_storage/proc/variable_observability_publish(list/evidence)\n', 1)[1].split('\n/map_storage/proc/', 1)[0]
        guard = 'if(!("variable-observability/" in flist("data/desktop-supervisor/variable-observability"))) return FALSE'
        self.assertLess(body.index('last_variable_failure = evidence'), body.index('\ttry\n'))
        self.assertLess(body.index(guard), body.index('fdel(path)'))
        self.assertLess(body.index(guard), body.index('text2file(encoded, path)'))
        self.assertIn('var/path = "data/desktop-supervisor/variable-observability/last-failure.json"', body)
        self.assertIn('if(fexists(path) && !fdel(path)) return FALSE', body)
        self.assertIn('\tcatch\n\t\treturn FALSE', body)
        self.assertNotIn('data/variable-observability-last-failure.json', body)

    def test_private_directory_and_io_failure_boundary_with_omission_controls(self):
        source = (ROOT / 'code/modules/persistence/variable_observability.dm').read_text()
        self.assert_private_sink(source)
        for removed in ('last_variable_failure = evidence', '\ttry\n',
                        'if(!("variable-observability/" in flist("data/desktop-supervisor/variable-observability"))) return FALSE',
                        'if(fexists(path) && !fdel(path)) return FALSE', '\tcatch\n\t\treturn FALSE'):
            with self.subTest(removed=removed), self.assertRaises((AssertionError, ValueError)):
                self.assert_private_sink(source.replace(removed, 'REMOVED', 1))

    def test_explicit_historical_input_still_reads_both_old_and_new_paths(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for relative in ('data/variable-observability-last-failure.json',
                             'data/desktop-supervisor/variable-observability/last-failure.json'):
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(json.dumps(failure()))
                args = dict(input_path=path, revision=REVISION, session=SESSION, round_id=ROUND,
                            now=NOW + timedelta(seconds=120))
                self.assertEqual(m.run(**args)['error_code'], 'stale_snapshot')
                result = m.run(**args, historical=True)
                self.assertTrue(result['ok'])
                self.assertEqual(result['data']['freshness'], 'historical_only')
                self.assertEqual(result['data']['source']['field'], 'original_target')

    def test_fixture_modes_prepare_storage_without_permissions_or_execution(self):
        path = Path(__file__).with_name('prepare_variable_probe.py')
        spec = importlib.util.spec_from_file_location('prepare_publication_probe', path)
        prepare = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(prepare)
        with tempfile.TemporaryDirectory() as folder:
            for mode in ('writable', 'missing', 'unwritable', 'obstructed'):
                output = Path(folder) / mode
                receipt = prepare.prepare(output, mode)
                self.assertTrue(receipt['prepared_only'])
                self.assertFalse(receipt['native_verified'])
                self.assertEqual(receipt['publication_mode'], mode)
                self.assertEqual(receipt['unwritable_fixture_permissions_required'], mode == 'unwritable')
                self.assertEqual((output / 'data/desktop-supervisor/variable-observability').is_dir(), mode != 'missing')
                self.assertEqual((output / 'data/desktop-supervisor/variable-observability/last-failure.json').is_dir(), mode == 'obstructed')
                if mode == 'obstructed':
                    self.assertEqual((output / 'data/desktop-supervisor/variable-observability/last-failure.json/retained-control.txt').read_text(), 'retained obstruction')
                self.assertFalse((output / 'config/variable-observability.txt').exists())
                self.assertEqual((output / 'config/variable-probe-mode.txt').read_text(), mode)
            with self.assertRaises(ValueError):
                prepare.prepare(Path(folder) / 'invalid', 'invalid')
            self.assertFalse((Path(folder) / 'invalid').exists())


if __name__ == '__main__':
    unittest.main()
