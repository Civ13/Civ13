"""Standard machine parts (docs/material-roles.md, "Machine parts").

code/modules/materials/machine_parts.dm defines one item type per part; the
material is a name and the numbers come from the part's role.

- Every part type names a role that exists and has its sprite states.
- Every route makes a part in a material its role accepts: the hand rows in
  the catalog, the anvil's Parts kind, and the parts mould.
- Every hand row names its tool in config/craft_needs.json and every part has
  a research subject.
- FROZEN pins what each craftable pair is worth against the standard part.
- A part carries no list and no material datum.
"""
from pathlib import Path
import importlib.util
import json
import re
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


roles = load('material_roles', 'tests/material_roles/test_material_roles.py')
SOURCE = (ROOT / 'code/modules/materials/machine_parts.dm').read_text(encoding='utf-8')
ANVIL = (ROOT / 'code/game/objects/structures/blacksmithing/blacksmithing.dm').read_text(encoding='utf-8', errors='ignore')
ANVIL_ROWS = (ROOT / 'code/game/objects/structures/blacksmithing/blacksmithing_recipes.dm').read_text(encoding='utf-8', errors='ignore')
WINDOW = (ROOT / 'code/game/objects/structures/blacksmithing/anvil_window.dm').read_text(encoding='utf-8')
MOULDS = (ROOT / 'code/game/objects/structures/blacksmithing/molds.dm').read_text(encoding='utf-8', errors='ignore')
RESEARCH = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8', errors='ignore')
CATALOG = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8', errors='ignore')
NEEDS = json.loads((ROOT / 'config/craft_needs.json').read_text(encoding='utf-8'))
DEFINES = (ROOT / 'code/__defines/material_roles.dm').read_text(encoding='utf-8')

PARTS = {
    '/obj/item/machine_part/gear': 'gear',
    '/obj/item/machine_part/shaft': 'shaft',
    '/obj/item/machine_part/bearing': 'bearing',
    '/obj/item/machine_part/spring': 'spring',
    '/obj/item/machine_part/belt': 'belt',
}
NOT_CAST = {'/obj/item/machine_part/spring', '/obj/item/machine_part/belt'}
# The metals a mould can hold (anvil_mold_costs) and the sheets an anvil forges.
FORGED = {'steel': 5, 'iron': 6, 'bronze': 7}

# (part role, material) -> (performance, lifetime) against the standard part.
FROZEN = {
    ('gear', 'wood'): (0.42, 0.2),
    ('gear', 'bone'): (0.35, 0.15),
    ('gear', 'copper'): (0.57, 0.4),
    ('gear', 'bronze'): (0.74, 0.85),
    ('gear', 'brass'): (0.67, 0.8),
    ('gear', 'iron'): (0.84, 0.7),
    ('gear', 'steel'): (1.0, 1.0),
    ('shaft', 'wood'): (0.48, 0.28),
    ('shaft', 'bronze'): (0.78, 0.8),
    ('shaft', 'iron'): (0.86, 0.75),
    ('shaft', 'steel'): (1.0, 1.0),
    ('bearing', 'wood'): (0.62, 0.2),
    ('bearing', 'bronze'): (0.95, 0.85),
    ('bearing', 'brass'): (0.94, 0.8),
    ('bearing', 'iron'): (0.9, 0.7),
    ('spring', 'bronze'): (0.45, 0.87),
    ('spring', 'iron'): (0.3, 0.89),
    ('spring', 'steel'): (1.0, 1.0),
    ('belt', 'rope'): (0.94, 0.8),
    ('belt', 'cloth'): (0.94, 0.8),
    ('belt', 'leather'): (1.0, 1.0),
    ('belt', 'iron'): (1.25, 2.0),
    ('belt', 'steel'): (1.25, 2.0),
}
# Soft or brittle metals a mould can hold but no part may be cast from.
REFUSED = [('gear', 'lead'), ('gear', 'gold'), ('gear', 'silver'), ('gear', 'tin'),
           ('bearing', 'lead'), ('shaft', 'tin'), ('spring', 'wood'), ('belt', 'stone')]


def hand_rows():
    rows = []
    for line in CATALOG.splitlines():
        if line.startswith('RECIPE: '):
            cols = line[len('RECIPE: '):].strip().split(',')
            if len(cols) == 13 and cols[2] in PARTS:
                rows.append(cols)
    return rows


def anvil_rows():
    return re.findall(r'^\t"([^"]+)" = list\("\1","parts",(\d+),(\d+),(\d+),(\d+),(\d+),(\d+),(/obj/item/machine_part/\w+)\),$',
                      ANVIL_ROWS, re.M)


class MachineParts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.materials = roles.load_materials()
        cls.roles, cls.consts = roles.load_roles()

    def rating(self, role, material):
        return roles.rate(self.roles[role], self.materials[material], self.materials, self.consts)

    def test_types_roles_and_sprites(self):
        role_ids = dict(re.findall(r'#define (ROLE_\w+)\s+"(\w+)"', DEFINES))
        script = load('create_machine_parts', 'tests/sprites/create_machine_parts.py')
        states = set(script.build())
        for path, role in PARTS.items():
            block = re.search(r'^' + re.escape(path) + r'\n((?:\t[^\n]*\n)+)', SOURCE, re.M)
            self.assertTrue(block, path)
            self.assertEqual(role_ids[re.search(r'part_role = (ROLE_\w+)', block[1])[1]], role)
            self.assertIn(role, self.roles)
            self.assertIn(re.search(r'icon_state = "(\w+)"', block[1])[1], states)
        for state in re.findall(r'\? "(\w+)" : "(\w+)"', SOURCE):
            for name in state:
                if ' ' not in name and name not in ('wooden',):
                    self.assertIn(name, states, name)
        for state in ('parts_mold_raw', 'parts_mold_empty', 'parts_mold_full'):
            self.assertIn(state, states)

    def test_sprite_sheet_is_current(self):
        done = subprocess.run([sys.executable, str(ROOT / 'tests/sprites/create_machine_parts.py'), '--check'],
                              capture_output=True, text=True)
        self.assertEqual(done.returncode, 0, done.stdout + done.stderr)

    def test_frozen_ratings(self):
        for (role, material), expected in FROZEN.items():
            rated = self.rating(role, material)
            self.assertIsNotNone(rated, (role, material))
            self.assertEqual((round(rated[0], 2), round(rated[1], 2)), expected, (role, material))
        for role, material in REFUSED:
            self.assertIsNone(self.rating(role, material), (role, material))

    def test_hand_rows(self):
        rows = hand_rows()
        made = {(PARTS[cols[2]], cols[12]) for cols in rows}
        self.assertEqual(made, {('gear', 'wood'), ('gear', 'bone'), ('shaft', 'wood'), ('bearing', 'wood'),
                                ('belt', 'rope'), ('belt', 'leather'), ('belt', 'cloth')})
        for cols in rows:
            # the row pays in the material the part is made of
            self.assertEqual(cols[0], '/material/%s/' % cols[12], cols[1])
            self.assertIsNotNone(self.rating(PARTS[cols[2]], cols[12]), cols[1])
            self.assertIn((PARTS[cols[2]], cols[12]), FROZEN, cols[1])
            self.assertTrue(NEEDS[cols[2]]['tools'], cols[1])
        self.assertEqual(NEEDS['/obj/item/machine_part/gear']['tools'], ['chisel'])
        self.assertEqual(NEEDS['/obj/item/machine_part/shaft']['tools'], ['hatchet'])
        self.assertEqual(NEEDS['/obj/item/machine_part/belt']['tools'], ['knife'])
        self.assertNotIn('/obj/item/machine_part/spring', NEEDS)

    def test_anvil_rows(self):
        rows = anvil_rows()
        self.assertEqual({row[7] for row in rows}, set(PARTS))
        for name, first, last, steel, iron, bronze, kevlar, path in rows:
            self.assertEqual((first, last, kevlar), ('0', '8', '0'), name)
            for metal, cost in (('steel', steel), ('iron', iron), ('bronze', bronze)):
                self.assertGreater(int(cost), 0, name)
                self.assertIsNotNone(self.rating(PARTS[path], metal), (name, metal))
        self.assertIn('optlist += "parts"', ANVIL)
        self.assertIn('!H.orc &&', ANVIL[ANVIL.index('optlist += "parts"') - 220:ANVIL.index('optlist += "parts"')])

    def test_every_menu_asks_the_role(self):
        offered = ANVIL_ROWS[ANVIL_ROWS.index('/proc/anvil_recipe_offered('):]
        self.assertIn('machine_part_refusal(row[9], material, cast)', offered)
        self.assertIn('anvil_recipe_offered(anvil_recipes[i], choice, anvil_recipes[i][material_index], material_name)', ANVIL)
        self.assertEqual(ANVIL.count('anvil_recipe_offered(anvil_recipes[i], category, mat, material, TRUE)'), 1)
        self.assertIn('if (!anvil_recipe_offered(row, category, mat, material, TRUE))', ANVIL)
        self.assertIn('anvil_recipe_offered(R, R[2], R[metal[1]], metal[2])', WINDOW)
        refusal = SOURCE[SOURCE.index('/proc/machine_part_refusal('):]
        self.assertIn('cast && !initial(P.castable)', refusal)
        self.assertIn('part_refusal(initial(P.part_role), material_name)', refusal)

    def test_mould(self):
        self.assertIn('if ("parts")\n\t\t\t\t\t\treturn forge_mold_recipe(ML, user, H, "parts")', ANVIL)
        raw = re.search(r'^/obj/item/weapon/clay/mold/parts\n((?:\t[^\n]*\n)+)', MOULDS, re.M)[1]
        fired = re.search(r'^/obj/item/weapon/clay/mold/parts/fired\n((?:\t[^\n]*\n)+)', MOULDS, re.M)[1]
        self.assertIn('result = /obj/item/weapon/clay/mold/parts/fired', raw)
        self.assertIn('base_icon = "parts_mold"', raw)
        self.assertIn('craftable_classes = "parts"', fired)
        self.assertIn('fired = TRUE', fired)
        self.assertIn('RECIPE: /material/clay/,unfired parts mold,/obj/item/weapon/clay/mold/parts,', CATALOG)
        costs = dict(re.findall(r'^\t"(\w+)" = list\((\d), [\d.]+\),', ANVIL_ROWS, re.M))
        self.assertEqual(costs['brass'], '7')
        cast = set()
        for metal in costs:
            for path, role in PARTS.items():
                if path not in NOT_CAST and self.rating(role, metal):
                    cast.add((role, metal))
        self.assertEqual(cast, {(role, metal) for role in ('gear', 'shaft', 'bearing')
                                for metal in ('bronze', 'brass', 'copper', 'iron', 'steel')})
        for path in NOT_CAST:
            block = re.search(r'^' + re.escape(path) + r'\n((?:\t[^\n]*\n)+)', SOURCE, re.M)[1]
            self.assertIn('castable = FALSE', block)

    def test_research_subjects(self):
        for path in list(PARTS) + ['/obj/item/weapon/clay/mold/parts']:
            self.assertRegex(RESEARCH, r'"%s" = "(basic_tools|bronze_working)"' % re.escape(path))

    def test_a_part_is_small(self):
        base = re.search(r'^/obj/item/machine_part\n((?:\t[^\n]*\n)+)', SOURCE, re.M)[1]
        self.assertNotIn('list/', base)
        self.assertNotIn('var/material/', base)
        self.assertEqual(set(re.findall(r'^\tvar/(\w+)', base, re.M)),
                         {'part_role', 'part_material', 'precise', 'wear', 'part_noun', 'castable'})


if __name__ == '__main__':
    unittest.main()
