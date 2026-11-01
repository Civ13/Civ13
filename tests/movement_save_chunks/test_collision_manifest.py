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

    def test_explicit_object_collision_overrides_are_classified(self):
        # Source-only guard: this is an inventory check, not a DM execution or
        # a proof of constructor, after_load, or parent_type behavior.
        import json
        import re
        expected = json.loads(collision_manifest.OUTPUT.read_text(encoding='utf-8'))
        source = (collision_manifest.ROOT / 'code/modules/persistence/saving.dm').read_text(encoding='utf-8')
        profile = source.split('/proc/human_spatial_generic_object(path)', 1)[1].split('\n/', 1)[0]
        refused = ('/obj/covers', '/obj/effect/effect/smoke/bad', '/obj/item/tape',
                   '/obj/item/weapon/gun/projectile/automatic/stationary',
                   '/obj/structure/TV', '/obj/structure/barricade', '/obj/structure/closet',
                   '/obj/structure/simple_door', '/obj/structure/grille', '/obj/structure/iv_drip',
                   '/obj/structure/optable', '/obj/structure/plant_pot', '/obj/structure/railing',
                   '/obj/structure/bed', '/obj/structure/table', '/obj/structure/window',
                   '/obj/structure/barbwire', '/obj/structure/vehicleparts/frame',
                   '/obj/structure/lamp', '/obj/structure/props', '/obj/structure/basketball_hoop',
                   '/obj/structure/multiz')
        for root in refused:
            self.assertIn(root, profile)
        generic_for_humans = {'/obj/structure', '/obj/structure/wild'}
        nested = []
        for file in expected['files']:
            for item in file['declarations']:
                declaration = item['declaration']
                if not re.search(r'\b(?:CanPass|CheckExit)\(', declaration):
                    continue
                if not declaration.startswith('/'):
                    nested.append(file['path'])
                    continue
                owner = re.split(r'/(?:proc/)?(?:CanPass|CheckExit)\(', declaration)[0]
                if owner.startswith('/obj/') and owner not in generic_for_humans:
                    self.assertTrue(any(owner == root or owner.startswith(root + '/') for root in refused), owner)
        self.assertEqual(nested, ['code/modules/multiz/structures.dm'])

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
