"""Material stacks rebuild their crafting recipes; saves must not carry them.

Gaia's 2026-11-13 saves held about 2,200 recipe datums on level 1 and 5,200 on
level 2, all from material stacks whose New() rebuilds the list from the material.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class StackRecipesUnsaved(unittest.TestCase):
    def test_recipes_are_a_runtime_field_of_material_stacks(self):
        text = (ROOT / 'code/modules/persistence/derived_assets.dm').read_text(encoding='utf-8')
        self.assertIn('/obj/item/stack/material/persistence_runtime_var(key)\n\treturn key == "recipes" || ..()', text)

    def test_new_and_the_recipe_list_rebuild_them(self):
        text = (ROOT / 'code/modules/materials/material_sheets.dm').read_text(encoding='utf-8')
        new = text[text.index('/obj/item/stack/material/New()'):]
        self.assertIn('recipes = material.get_recipes_civs(forced=TRUE)', new[:new.index('\n/obj/')])
        self.assertIn('recipes = material.get_recipes_civs(U)', text)


if __name__ == '__main__':
    unittest.main()
