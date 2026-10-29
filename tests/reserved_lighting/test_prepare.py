"""Offline source extraction/control tests, never gameplay or allocation evidence."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('reserved_prepare', Path(__file__).with_name('prepare.py'))
prepare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare)
ROOT = Path(__file__).resolve().parents[2]


class SourcePreparation(unittest.TestCase):
    def test_each_control_changes_only_its_production_source(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            positive = prepare.prepare(ROOT, root/'positive')
            for name, (rel, before, after) in prepare.CONTROLS.items():
                control = prepare.prepare(ROOT, root/name, name)
                changed = [p for p in prepare.FILES if positive['files'][p] != control['files'][p]]
                self.assertEqual(changed, [rel])
                self.assertEqual((root/name/rel).read_text(), (root/'positive'/rel).read_text().replace(before, after, 1))

    def test_preparation_keeps_production_source_and_disables_world_startup(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)/'fixture'
            receipt = prepare.prepare(ROOT, out)
            for rel in prepare.FILES:
                self.assertEqual((ROOT/rel).read_text(), (out/rel).read_text())
            dme = (out/'probe.dme').read_text()
            self.assertNotIn('#include "maps\\', dme)
            self.assertNotIn('.dmf"', dme)
            self.assertIn('tests/reserved_lighting/probe.dm', dme)
            self.assertNotIn('/world/New()', (out/'world.dm').read_text(encoding='utf-8'))
            self.assertNotIn('var/global/datum/global_init/init = new ()', (out/'world.dm').read_text(encoding='utf-8'))
            self.assertIn('var/global/datum/global_init/init = null', (out/'world.dm').read_text(encoding='utf-8'))
            self.assertIn('var/global/datum/global_init/init = new ()', (ROOT/'code/world.dm').read_text(encoding='utf-8'))
            for name, signature in (('movement.dm', '/client/proc/unused_reserved_movement_new()'),
                                    ('client_procs.dm', '/client/proc/unused_reserved_client_new(TopicData)')):
                adapter = (out/name).read_text(encoding='utf-8')
                self.assertIn(signature+'\n\treturn\n', adapter)
                self.assertNotIn('/client/New(', adapter)
            self.assertIn('UNRUN', receipt['verification'])


if __name__ == '__main__':
    unittest.main()
