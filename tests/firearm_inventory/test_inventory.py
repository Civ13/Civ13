import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('firearm_inventory', ROOT / 'scripts/firearm_inventory.py')
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class InventoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'code').mkdir()
        (self.root / 'config/crafting').mkdir(parents=True)

    def write(self, text, name='guns.dm'):
        (self.root / 'code' / name).write_text(text)

    def test_inherited_values_are_not_reported_missing(self):
        self.write('/obj/item/weapon/gun\n\tcaliber = "9mm"\n/obj/item/weapon/gun/child\n\tname = "child"\n')
        result = audit.inventory(self.root)
        self.assertEqual(result['declarations'][1]['assignments'], [])
        self.assertIn('No direct assignment does not mean a missing value', ' '.join(result['limitations']))

    def test_proc_assignments_and_comments_are_not_defaults(self):
        self.write('/* /obj/item/weapon/gun/fake\n /* nested */ */\n/obj/item/weapon/gun\n\tcaliber = "http://example" // note\n/obj/item/weapon/gun/New()\n\tcaliber = "runtime"\n')
        rows = audit.inventory(self.root)['declarations']
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]['line'], 3)
        self.assertEqual(rows[0]['assignments'][0]['expression'], '"http://example"')

    def test_reopened_types_and_explicit_parent_are_preserved(self):
        self.write('/obj/item/weapon/gun/a\n\tparent_type = /obj/item/weapon/gun/b\n/obj/item/weapon/gun/a\n\tcaliber = CALIBER_MACRO\n')
        rows = audit.inventory(self.root)['declarations']
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[0]['assignments'][0]['field'], 'parent_type')
        self.assertEqual(rows[1]['assignments'][0]['expression'], 'CALIBER_MACRO')

    def test_factory_dynamic_and_literal_references(self):
        self.write('/obj/structure/factory/proc/make()\n\tnew /obj/item/weapon/gun/a(src)\n\tnew output_type(src)\n\tvar/message = "/obj/item/weapon/gun/fake"\n', 'factory_machines.dm')
        result = audit.inventory(self.root)
        self.assertEqual([r['path'] for r in result['references']], ['/obj/item/weapon/gun/a'])
        self.assertEqual(len(result['review']), 2)

    def test_clothing_outside_armor_branch_and_casing_links(self):
        self.write('/obj/item/clothing/suit/coat\n\tarmor = list(melee = 25)\n/obj/item/ammo_casing/a\n\tprojectile_type = /obj/item/projectile/bullet\n')
        self.assertEqual(audit.inventory(self.root)['summary']['declaration_blocks'], {'casing': 1, 'clothing': 1})

    def test_preprocessor_and_space_indent_are_uncertain(self):
        self.write('#ifdef TEST\n/obj/item/weapon/gun\n    caliber = "test"\n#endif\n')
        result = audit.inventory(self.root)
        self.assertEqual(result['declarations'][0]['assignments'], [])
        self.assertEqual(len(result['review']), 3)

    def test_bounds_and_missing_root(self):
        self.write('/obj/item/weapon/gun\n')
        for limits in ({'max_files': 0}, {'max_bytes': 1}):
            with self.assertRaises(ValueError):
                audit.inventory(self.root, **limits)
        with self.assertRaises(ValueError):
            audit.inventory(self.root / 'absent')

    def test_symlink_rejected(self):
        self.write('')
        (self.root / 'code/link.dm').symlink_to(self.root / 'code/guns.dm')
        with self.assertRaises(ValueError):
            audit.inventory(self.root)

    def test_deterministic_and_source_bound(self):
        self.write('/obj/item/weapon/gun\n')
        first = audit.inventory(self.root)
        self.assertEqual(first, audit.inventory(self.root))
        self.write('/obj/item/weapon/gun\n// edited\n')
        self.assertNotEqual(first['sources'], audit.inventory(self.root)['sources'])

    def test_catalog_reference(self):
        (self.root / 'config/crafting/material_recipes_test.txt').write_text('RECIPE: steel,Gun,/obj/item/weapon/gun/test,1\n')
        self.assertEqual(audit.inventory(self.root)['references'][0]['context'], 'catalog')

    def test_multiline_string_cannot_forge_default(self):
        self.write('/obj/item/weapon/gun\n\tdesc = {"long text\n\tcaliber = fake\n"}\n\tcaliber = "real"\n')
        rows = audit.inventory(self.root)['declarations'][0]['assignments']
        self.assertEqual([r['expression'] for r in rows], ['"real"'])

    def test_long_string_with_bare_quote_cannot_forge_type(self):
        for opener in ('{"', '@{"'):
            self.write('/obj/item/weapon/gun\n\tdesc = ' + opener + 'A quote: "\n/obj/item/weapon/gun/fake\n"}\n\tcaliber = "real"\n')
            rows = audit.inventory(self.root)['declarations']
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0]['assignments'][0]['expression'], '"real"')

    def test_symlink_directory_rejected(self):
        (self.root / 'code/link').symlink_to(self.root / 'config', target_is_directory=True)
        with self.assertRaises(ValueError):
            audit.inventory(self.root)

    def test_unsupported_inline_type_is_reviewed(self):
        self.write('/obj/item/weapon/gun { caliber = "x" }\n')
        result = audit.inventory(self.root)
        self.assertEqual(result['declarations'], [])
        self.assertEqual(result['review'][0]['reason'], 'unsupported declaration syntax')

    def test_repeated_references_are_bounded(self):
        self.write(' '.join(['/obj/item/weapon/gun/a'] * 1000), 'factory.dm')
        rows = audit.inventory(self.root)['references']
        self.assertEqual(len(rows), 1)
        self.assertEqual(len(rows[0]['source']), audit.EXCERPT_CHARS)
        self.assertTrue(rows[0]['source_truncated'])

    def test_symlink_scan_root_rejected(self):
        (self.root / 'code').rmdir()
        (self.root / 'code').symlink_to(self.root / 'config', target_is_directory=True)
        with self.assertRaises(ValueError):
            audit.inventory(self.root)

    def test_record_limit_fails_explicitly(self):
        self.write('/obj/item/weapon/gun\n\tcaliber = "x"\n')
        with patch.object(audit, 'LIMIT_RECORDS', 1):
            with self.assertRaisesRegex(ValueError, 'record limit'):
                audit.inventory(self.root)

    def test_similarly_named_non_family_is_excluded(self):
        self.write('/obj/item/weapon/gunpowder\n')
        self.assertEqual(audit.inventory(self.root)['declarations'], [])


if __name__ == '__main__':
    unittest.main()
