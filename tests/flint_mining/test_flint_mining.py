"""Offline source checks for flint mining; see run.py for the native probe."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('flint_mining_run', Path(__file__).with_name('run.py'))
run = importlib.util.module_from_spec(spec)
spec.loader.exec_module(run)


class FlintMiningSource(unittest.TestCase):
    def test_source_contracts(self):
        self.assertEqual(run.source_checks(), [])

    def test_fletching_checks_reject_contract_regressions(self):
        ammo = run.read('code/modules/projectiles/_ammo_casing.dm')
        controls = (
            ('material = "flint"', 'material = "gods"'),
            ('if (F.sharpened)', 'if (TRUE)'),
            ('if (!crafting_recipe_allowed(user, result)) return FALSE',
             'if (!crafting_recipe_allowed(user, result)) return TRUE'),
            ('AH.amount--', 'AH.amount++'),
            ('\treturn TRUE\n\n/obj/item/ammo_casing/arrow/attackby',
             '\treturn FALSE\n\n/obj/item/ammo_casing/arrow/attackby'),
            ('attach_arrowhead(W, user, "/obj/item/ammo_casing/bolt")',
             'attach_arrowhead(W, user, "/obj/item/ammo_casing/arrow")'),
        )
        for original, replacement in controls:
            with self.subTest(original=original):
                self.assertIn(original, ammo)
                self.assertTrue(run.fletching_checks(ammo.replace(original, replacement, 1)))


if __name__ == '__main__':
    unittest.main()
