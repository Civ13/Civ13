"""Plain tools in other materials (docs/material-roles.md, "Plain tools").

config/recipe_variants.json lists the materials a hammer, chisel, wrench, saw
and the other plain tools may be made of; scripts/recipe_variants.py writes one
ordinary catalog row per material, and code/modules/materials/tool_materials.dm
makes the built tool take that material.

- The generated block in the catalog is current and is the last thing in it.
- Every variant's product accepts materials (tool_noun, tool_role), its
  material can do the job, has a stack to craft from and a research subject.
- FROZEN_SPEEDS pins how fast each new pair works against the usual tool, and
  every pair stays inside 0.4 to 1.5.
- Tools in their usual material are untouched: speed 1, no rename.
"""
from pathlib import Path
import importlib.util
import json
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


roles = load('material_roles', 'tests/material_roles/test_material_roles.py')
generator = load('recipe_variants', 'scripts/recipe_variants.py')
DATA = json.loads((ROOT / 'config/recipe_variants.json').read_text(encoding='utf-8'))
SOURCE = (ROOT / 'code/modules/materials/tool_materials.dm').read_text(encoding='utf-8')
PLAIN = [ROOT / 'code/modules/1713/tools.dm', ROOT / 'code/game/objects/items/weapons/tools.dm',
         ROOT / 'code/modules/materials/tool_materials.dm']
SHEETS = (ROOT / 'code/modules/materials/material_sheets.dm').read_text(encoding='utf-8', errors='ignore')
RESEARCH = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8', errors='ignore')

# (tool noun, material) -> speed against the usual material, two places.
FROZEN_SPEEDS = {
    ('hammer', 'copper'): 0.87,
    ('hammer', 'bronze'): 0.98,
    ('hammer', 'steel'): 1.06,
    ('chisel', 'bone'): 0.71,
    ('chisel', 'copper'): 0.66,
    ('chisel', 'bronze'): 0.87,
    ('chisel', 'steel'): 1.12,
    ('saw', 'copper'): 0.66,
    ('saw', 'bronze'): 0.87,
    ('saw', 'steel'): 1.12,
    ('wrench', 'bronze'): 0.84,
    ('wrench', 'steel'): 1.25,
    ('wirecutters', 'iron'): 0.89,
    ('wirecutters', 'bronze'): 0.77,
    ('crowbar', 'bronze'): 0.84,
    ('crowbar', 'steel'): 1.25,
}


def blocks():
    found = {}
    for source in PLAIN:
        for path, body in roles.type_blocks(source.read_text(encoding='utf-8', errors='ignore'), '/obj/item/weapon').items():
            found.setdefault(path, {}).update(body)
    return found


class ToolMaterials(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.blocks = blocks()
        cls.materials = roles.load_materials()
        cls.roles, cls.consts = roles.load_roles()

    def value(self, path, var):
        raw = roles.inherited(self.blocks, path, var)
        return raw.split('//')[0].strip().strip('"') if raw else None

    def performance(self, role_const, material):
        role = self.roles[self.consts[role_const].strip('"')]
        rating = roles.rate(role, self.materials[material], self.materials, self.consts)
        return rating[0] if rating else None

    def speed(self, path, material):
        role = self.value(path, 'tool_role')
        usual, now = self.performance(role, self.value(path, 'tool_material')), self.performance(role, material)
        return max(0.4, min(1.5, now / usual))

    def test_generated_block_is_current_and_last(self):
        catalog = (ROOT / DATA['catalog']).read_text(encoding='utf-8')
        self.assertEqual(generator.render(catalog, DATA), catalog)
        self.assertTrue(catalog.endswith(generator.END + '\n'))
        _, block = generator.split_block(catalog)
        self.assertEqual(len(block), sum(len(v['materials']) for v in DATA['variants']))

    def test_templates_are_hand_written_rows(self):
        head, _ = generator.split_block((ROOT / DATA['catalog']).read_text(encoding='utf-8'))
        rows = generator.catalog_rows(head)
        for variant in DATA['variants']:
            template = variant['template']
            matches = [r for r in rows if r[2] == variant['result'] and r[1] == template['title']
                       and r[0] == '/material/%s/' % template['material']]
            self.assertEqual(len(matches), 1, variant['result'])
            self.assertNotIn(template['material'], variant['materials'])

    def test_products_accept_their_materials(self):
        for variant in DATA['variants']:
            path = variant['result']
            self.assertEqual(self.value(path, 'tool_noun'), variant['noun'], path)
            role = self.value(path, 'tool_role')
            self.assertIn(role, self.consts, path)
            usual = self.value(path, 'tool_material')
            self.assertIsNotNone(self.performance(role, usual), path)
            self.assertNotIn(usual, variant['materials'], path)
            self.assertIn('"%s" = "' % path, RESEARCH, path)
            for material in variant['materials']:
                self.assertIsNotNone(self.performance(role, material), f'{path} {material}')
                self.assertRegex(SHEETS, r'(?m)^/obj/item/stack/material/%s$' % material)

    def test_speeds_are_frozen_and_bounded(self):
        seen = {}
        for variant in DATA['variants']:
            for material in variant['materials']:
                speed = self.speed(variant['result'], material)
                self.assertGreaterEqual(speed, 0.4)
                self.assertLessEqual(speed, 1.5)
                seen[(variant['noun'], material)] = round(speed, 2)
        for key, expected in FROZEN_SPEEDS.items():
            self.assertEqual(seen[key], expected, key)
        # Better metal is never slower in the same tool.
        self.assertLess(seen[('saw', 'copper')], seen[('saw', 'bronze')])
        self.assertLess(seen[('saw', 'bronze')], 1)
        self.assertGreater(seen[('saw', 'steel')], 1)

    def test_usual_material_changes_nothing(self):
        setter = SOURCE[SOURCE.index('/obj/item/proc/set_tool_material('):SOURCE.index('/proc/tool_speed(')]
        self.assertLess(setter.index('if (M.name == initial(tool_material))\n\t\treturn TRUE'), setter.index('tool_material = M.name'))
        speed = SOURCE[SOURCE.index('/proc/tool_speed('):SOURCE.index('/proc/tool_work_time(')]
        self.assertIn('I.tool_material == initial(I.tool_material))\n\t\treturn 1', speed)
        self.assertIn('max(0.4, min(1.5, now / usual))', speed)

    def test_named_variants_keep_their_own_names(self):
        for path, noun in (('/obj/item/weapon/hammer/modern', 'clawhammer'), ('/obj/item/weapon/hammer/tribalhammer', 'mallet'),
                           ('/obj/item/weapon/wirecutters/boltcutters', 'boltcutters'), ('/obj/item/weapon/crowbar/prybar', 'prybar')):
            self.assertEqual(self.value(path, 'tool_noun'), noun)

    def test_recipes_and_work_sites_use_it(self):
        weapons = (ROOT / 'code/game/objects/weapons.dm').read_text(encoding='utf-8', errors='ignore').replace('\r', '')
        self.assertIn('/obj/item/weapon/New(newloc, crafted_material)', weapons)
        self.assertIn('if (tool_noun && istext(crafted_material))\n\t\tset_tool_material(crafted_material)', weapons)
        self.assertIn('(hatchet ? 80 : 60)/user.getStatCoeff("strength")/tool_speed(tool)', SHEETS)
        helpers = (ROOT / 'code/_helpers/tools.dm').read_text(encoding='utf-8')
        self.assertIn('delay = tool_work_time(user.get_active_hand(), delay)', helpers)

    def test_only_sparking_materials_spark(self):
        sparking = {name for name, material in self.materials.items() if material['sparks']}
        self.assertEqual(sparking & {'iron', 'steel', 'flint'}, {'iron', 'steel', 'flint'})
        for safe in ('copper', 'bronze', 'brass', 'wood', 'bone', 'stone', 'lead', 'gold'):
            self.assertNotIn(safe, sparking)

    def test_sparks_need_a_deliberate_blow_on_powder_or_fuel(self):
        struck = SOURCE[SOURCE.index('/barrel/struck_by_tool('):SOURCE.index('#undef TOOL_SPARK_CHANCE')]
        gate = 'if (!user || user.a_intent != I_HARM || !tool_throws_sparks(I) || !spark_volatile())\n\t\treturn FALSE'
        self.assertIn(gate, struck)
        self.assertLess(struck.index(gate), struck.index('prob(TOOL_SPARK_CHANCE)'))
        self.assertLess(struck.index('message_admins('), struck.index('spark_explode()'))
        self.assertIn('#define TOOL_SPARK_CHANCE 4\n', SOURCE)
        self.assertIn('if (!isitem(I) || !I.tool_flags)\n\t\treturn FALSE', SOURCE)
        glass = (ROOT / 'code/modules/reagents/reagent_containers/glass.dm').read_text(encoding='utf-8', errors='ignore').replace('\r', '')
        click = (ROOT / 'code/_onclick/item_attack.dm').read_text(encoding='utf-8', errors='ignore').replace('\r', '')
        self.assertLess(click.index('if (A.struck_by_tool(src, user))\n\t\treturn TRUE'), click.index('resolved = A.attackby(src, user, icon_x, icon_y)'))
        self.assertIn('/atom/proc/struck_by_tool(obj/item/I, mob/living/user)\n\treturn FALSE', SOURCE)
        self.assertIn('\tspark_warning(user)\n', glass)
        self.assertIn('bronze, copper, wood and bone are safe', SOURCE)


if __name__ == '__main__':
    unittest.main()
