"""Bounded copy-on-write staging tests; no container or BYOND process."""
import hashlib
import json
import os
from pathlib import Path
import tempfile
import unittest
import build_guard
import materialize_pair
import source_binding
import stage_bundle


class PairControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.inputs = source_binding.read_inputs(['git', '-C', str(Path(__file__).resolve().parents[2])], source_binding.BASE)
        cls.old_guard = build_guard.OLD.read_bytes()
        cls.observer = Path(__file__).with_name('bump_fixture_observer.dm').read_bytes()
        cls.scenario = Path(__file__).with_name('bump_fixture_probe.dm').read_bytes()

    def setup_fixture(self, root):
        out = Path(root) / 'npc-smoke'
        stage = out / 'stage'
        stage.mkdir(parents=True)
        data = dict(self.inputs)
        probe = data[stage_bundle.PROBE].decode().replace('\t\t\thuman_subtile_fixture_headless()', '\t\t\tnpc_subtile_fixture()', 1)
        probe = probe.replace('"checks" = human_subtile_fixture_checks,',
                              '"checks" = human_subtile_fixture_checks, "npc_checks" = npc_subtile_checks, "npc_rows" = npc_subtile_rows,', 1)
        data[stage_bundle.PROBE] = probe.encode()
        overlay = stage_bundle.reconstruct(self.inputs, self.old_guard, self.observer, self.scenario, False)
        suffix = (b'\n#include "tests\\human_subtile\\bump_fixture_observer.dm"\n'
                  b'\n#include "tests\\human_subtile\\bump_fixture_probe.dm"\n')
        data['human_subtile.dme'] = overlay['human_subtile.dme'][:-len(suffix)]
        data['unmodified_asset.bin'] = b'one shared read-only asset'
        for rel, raw in data.items():
            dest = stage / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(raw)
        return out, {'dme': 'stage/human_subtile.dme',
                     'stage_files': {rel: materialize_pair.digest(raw) for rel, raw in data.items()}}

    def test_mutable_overlay_isolated_and_unmodified_input_shared(self):
        with tempfile.TemporaryDirectory() as tmp:
            out, manifest = self.setup_fixture(tmp)
            parent, old = materialize_pair.prepare_pair(out, manifest, self.inputs, self.old_guard, self.observer, self.scenario)
            self.assertEqual(old['bump_variant'], 'baseline')
            self.assertEqual(manifest['bump_variant'], 'candidate')
            self.assertTrue(os.path.samefile(parent / 'stage/unmodified_asset.bin', out / 'stage/unmodified_asset.bin'))
            for rel in (stage_bundle.LIVING, stage_bundle.PROBE, stage_bundle.OBSERVER, stage_bundle.SCENARIO, 'human_subtile.dme'):
                self.assertFalse(os.path.samefile(parent / 'stage' / rel, out / 'stage' / rel))
            self.assertNotEqual((parent / 'stage' / stage_bundle.LIVING).read_bytes(),
                                (out / 'stage' / stage_bundle.LIVING).read_bytes())

    def test_wrong_prepared_probe_fails_before_parent_clone(self):
        with tempfile.TemporaryDirectory() as tmp:
            out, manifest = self.setup_fixture(tmp)
            path = out / 'stage' / stage_bundle.PROBE
            path.write_bytes(path.read_bytes() + b'\n// unexpected')
            with self.assertRaises(ValueError):
                materialize_pair.prepare_pair(out, manifest, self.inputs, self.old_guard, self.observer, self.scenario)
            self.assertFalse((Path(tmp) / 'npc-parent').exists())

    def test_wrong_goat_or_human_source_fails_before_parent_clone(self):
        for rel in ('code/game/mob/living/simple_animal/friendly/farm_animals.dm',
                    'code/game/mob/living/carbon/human/subtile_movement.dm'):
            with self.subTest(rel=rel), tempfile.TemporaryDirectory() as tmp:
                out, manifest = self.setup_fixture(tmp)
                path = out / 'stage' / rel
                path.write_bytes(path.read_bytes() + b'\n// unexpected')
                with self.assertRaises(ValueError):
                    materialize_pair.prepare_pair(out, manifest, self.inputs, self.old_guard, self.observer, self.scenario)
                self.assertFalse((Path(tmp) / 'npc-parent').exists())


if __name__ == '__main__':
    unittest.main()
