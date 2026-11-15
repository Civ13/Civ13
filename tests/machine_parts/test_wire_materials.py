"""Wire by material (docs/material-roles.md, "Wire").

code/modules/materials/wire_materials.dm adds iron, aluminium, silver and gold
cable. Copper stays the standard and loses nothing.

- Loss a tile follows conductivity; the frozen table is what players are told.
- The grid walk adds the losses up once and never delivers less than a tenth.
- A cable stores no material: its colour names the metal, so a run is one
  metal and a cut cable gives back the coil it was laid from.
- Every coil has a recipe from its own metal and a research gate.
"""
from pathlib import Path
import importlib.util
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


SOURCE = (ROOT / 'code/modules/materials/wire_materials.dm').read_text(encoding='utf-8')
CABLES = (ROOT / 'code/modules/1713/machinery/cables.dm').read_text(encoding='utf-8', errors='ignore')
COILS = (ROOT / 'code/modules/1713/machinery/cables_types.dm').read_text(encoding='utf-8', errors='ignore')
RESEARCH = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8', errors='ignore')
PROPERTIES = (ROOT / 'code/modules/materials/material_properties.dm').read_text(encoding='utf-8')
CATALOG = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8', errors='ignore')

# metal -> percent of the supply one tile costs, as the wiki tells players
LOSS = {'iron': 2.4, 'aluminium': 0.3, 'gold': 0.2, 'silver': 0.0}


def number(name):
    return float(re.search(r'#define %s (\S+)' % name, SOURCE)[1])


def proc(text, name):
    start = text.index(name)
    end = text.find('\n/', start + 1)
    return text[start:end if end > 0 else len(text)]


class WireMaterials(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # aluminium is declared outside materials.dm, so read conductivity from the property table itself
        blocks = re.findall(r'^/material/(\w+)\n((?:\t[^\n]*\n)+)', PROPERTIES, re.M)
        cls.materials = {name: {'conductivity': float(re.search(r'conductivity = ([\d.]+)', body)[1])}
                         for name, body in blocks if 'conductivity = ' in body}

    def loss(self, name):
        return max(0, number('WIRE_LOSS_PER_TILE') * (100 / self.materials[name]['conductivity'] - 1))

    def test_loss_follows_conductivity(self):
        body = proc(SOURCE, '/proc/cable_wire_loss(')
        self.assertIn('max(0, WIRE_LOSS_PER_TILE * (100 / M.conductivity - 1))', body)
        self.assertIn('if (!material_name)\n\t\treturn 0', body)
        self.assertEqual({name: round(self.loss(name) * 100, 1) for name in LOSS}, LOSS)
        # copper is the standard: it is not a listed wire and costs nothing
        self.assertEqual(self.materials['copper']['conductivity'], 100)
        listed = dict(re.findall(r'^\t"(\w+)" = "(\w+)",$', SOURCE, re.M))
        self.assertEqual(listed, {name: name for name in LOSS})

    def test_a_grid_always_delivers_something(self):
        delivered = proc(SOURCE, '/proc/cable_delivered(')
        self.assertIn('if (loss <= 0)\n\t\treturn capacity', delivered)
        self.assertIn('round(capacity * (1 - min(WIRE_LOSS_MAX, loss)), 0.1)', delivered)
        self.assertLess(number('WIRE_LOSS_MAX'), 1)
        # forty tiles of iron wire waste nearly all of it, but not all
        self.assertGreater(40 * self.loss('iron'), number('WIRE_LOSS_MAX'))

    def test_the_grid_walk_adds_losses_once(self):
        walk = proc(CABLES, '/obj/structure/cable/proc/rebuild_supply(')
        self.assertEqual(walk.count('wire_loss += cable_wire_loss(CB.cable_color)'), 1)
        # copper pays one list lookup and no call
        self.assertIn('if (cable_wire_materials[CB.cable_color])\n\t\t\twire_loss += cable_wire_loss(CB.cable_color)', walk)
        cut = walk.index('if (wire_loss > 0)\n\t\tcapacity = cable_delivered(capacity, wire_loss)')
        # the loss comes off before any consumer's request is judged
        self.assertLess(cut, walk.index('var/accepted = FALSE'))
        self.assertLess(walk.index('capacity += B.available_output()'), cut)
        self.assertIn('"grid_wire_loss"', proc(CABLES, '/obj/structure/cable/persistence_runtime_var('))

    def test_a_cable_stores_no_material(self):
        self.assertIsNone(re.search(r'\bwire_material\b', SOURCE + CABLES + COILS))
        self.assertEqual(re.findall(r'^/obj/structure/cable/var/(.*)$', SOURCE, re.M), ['tmp/grid_wire_loss = 0'])
        # laying copies the coil's colour, and cutting gives the matching coil back
        self.assertIn('C.cable_color = cable_color', COILS)
        self.assertIn('var/coil_type = cable_coil_type(cable_color)\n\t\tvar/obj/item/stack/cable_coil/salvage = new coil_type(loc)', CABLES)
        self.assertIn('return cable_wire_coils[cable_color] || /obj/item/stack/cable_coil', SOURCE)

    def test_every_coil_has_a_colour_a_recipe_and_a_gate(self):
        for name in LOSS:
            path = '/obj/item/stack/cable_coil/%s' % name
            block = re.search(r'^%s\n((?:\t[^\n]*\n)+)' % re.escape(path), SOURCE, re.M)[1]
            self.assertIn('cable_color = "%s"' % name, block)
            self.assertRegex(block, r'color = "#[0-9a-f]{6}"')
            self.assertIn('"%s" = %s,' % (name, path), SOURCE)
            self.assertIn('RECIPE: /material/%s/,%s cable coil (10m),%s,1,35,0,1,electrical,105,0,0,8,null' % (name, name, path), CATALOG)
            self.assertIn('"%s" = "electricity",' % path, RESEARCH)
        # a material colour never joins the random colour pool
        colours = CABLES[CABLES.index('var/global/list/cable_colors = list('):CABLES.index('\t)')]
        for name in LOSS:
            self.assertNotIn('"%s"' % name, colours)


if __name__ == '__main__':
    unittest.main()
