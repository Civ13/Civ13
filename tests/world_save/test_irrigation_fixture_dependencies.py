"""Source-bound compatibility tests; no compiler, daemon or network."""
import importlib.util
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/1713/trench.dm').read_text(encoding='utf-8')
FIXTURE = (ROOT / 'tests/world_save/stubs.dm').read_text(encoding='utf-8')
spec = importlib.util.spec_from_file_location('irrigation_source_adapter', ROOT / 'tests/irrigation_persistence/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


class FixtureDependencies(unittest.TestCase):
    def test_reset_and_scalar_preflight_are_exact_production_bodies(self):
        for signature in ('/turf/floor/proc/irrigation_prepare_load()',
                          '/proc/irrigation_saved_scalar(savefile/F, field, version)'):
            with self.subTest(signature=signature):
                self.assertEqual(adapter.procedure(FIXTURE, signature), adapter.procedure(SOURCE, signature))
        real = adapter.procedure(SOURCE, '/proc/validate_saved_irrigation(savefile/F, version)')
        fixture = adapter.procedure(FIXTURE, '/proc/fixture_validate_saved_irrigation(savefile/F, version)')
        self.assertEqual(fixture.replace('/proc/fixture_validate_saved_irrigation(',
                                         '/proc/validate_saved_irrigation(', 1), real)

    def test_fixture_refuses_active_channels_and_retains_real_legacy_preflight(self):
        body = adapter.procedure(FIXTURE, '/proc/validate_saved_irrigation(savefile/F, version)')
        self.assertIn('if (F.dir.Find("irrigation_save_version"))\n'
                      '\t\tthrow EXCEPTION("Irrigation channels require the production trench fixture")\n'
                      '\treturn fixture_validate_saved_irrigation(F, version)', body)
        production = adapter.validator(SOURCE)
        scalar = lambda value: {'kind': 'value', 'value': value}
        neutral = adapter.FileEntry({'name': scalar('ordinary floor')})
        self.assertTrue(production(neutral, 2))
        channel = adapter.FileEntry({'irrigation_save_version': scalar(1), 'irrigation': scalar(1),
                                     'flooded': scalar(1), 'salty': scalar(0)})
        self.assertTrue(production(channel, 2))
        self.assertTrue(channel.dir.Find('irrigation_save_version'))  # Fixture must reject this valid channel.
        for invalid in (adapter.FileEntry({'irrigation': scalar(1)}),
                        adapter.FileEntry({'name': scalar('irrigation channel')}),
                        adapter.FileEntry({'name': {'kind': 'reference', 'value': 'bad'}})):
            with self.subTest(entry=invalid), self.assertRaises(ValueError):
                production(invalid, 2)

    def test_focused_roundtrip_keeps_real_loader_and_fixture_adapter(self):
        dme = (ROOT / 'tests/world_save/roundtrip.dme').read_text()
        self.assertEqual(len(re.findall(r'^#include "stubs\.dm"$', dme, re.M)), 1)
        self.assertEqual(len(re.findall(r'^#include "../../code/modules/persistence/loading\.dm"$', dme, re.M)), 1)
        self.assertIn('restored_floor.irrigation_prepare_load()', (ROOT / 'code/modules/persistence/loading.dm').read_text())
        self.assertIn('validate_saved_irrigation(F, version)', (ROOT / 'code/modules/persistence/loading.dm').read_text())


if __name__ == '__main__':
    unittest.main()
