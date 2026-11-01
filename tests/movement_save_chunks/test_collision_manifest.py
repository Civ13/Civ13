"""Offline collision source drift checks; this does not classify passability."""
from pathlib import Path
import tempfile
import unittest

import collision_manifest


class CollisionManifestTests(unittest.TestCase):
    def test_current_source_matches_review_inventory(self):
        import json
        expected = json.loads(collision_manifest.OUTPUT.read_text(encoding='utf-8'))
        self.assertEqual(collision_manifest.inventory(collision_manifest.ROOT), expected)

    def test_tile_only_candidate_does_not_claim_fractional_collision_classification(self):
        source = (collision_manifest.ROOT / 'code/modules/persistence/saving.dm').read_text(encoding='utf-8')
        self.assertNotIn('/proc/human_spatial_generic_object(path)', source)
        tile = source.split('/map_storage/proc/inspect_human_saved_tile_and_links(', 1)[1].split('\n/map_storage/proc/', 1)[0]
        self.assertIn('Human saved tile has a dense object', tile)
        self.assertNotIn('CanPass(', tile)

    def test_new_nested_override_parent_change_and_body_change_are_visible(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            code = root / 'code'
            code.mkdir()
            (root / 'civ13.dme').write_text('#include "code/fixture.dm"\n', encoding='utf-8')
            fixture = code / 'fixture.dm'
            fixture.write_text('/obj/example\n\tCanPass(atom/A)\n\t\treturn !density\n', encoding='utf-8')
            original = collision_manifest.inventory(root)
            self.assertEqual(len(original['files'][0]['declarations']), 1)
            fixture.write_text('/obj/example\n\tCanPass(atom/A)\n\t\treturn TRUE\n', encoding='utf-8')
            self.assertNotEqual(collision_manifest.inventory(root), original)
            fixture.write_text('/obj/example\n\tparent_type = /obj/other\n\tCheckExit()\n\t\treturn TRUE\n', encoding='utf-8')
            changed = collision_manifest.inventory(root)
            self.assertEqual(len(changed['files'][0]['declarations']), 2)
            self.assertNotEqual(changed, original)
            (root / 'civ13.dme').write_text('#include "outside/hidden.dm"\n', encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'outside collision inventory'):
                collision_manifest.inventory(root)


if __name__ == '__main__':
    unittest.main()
