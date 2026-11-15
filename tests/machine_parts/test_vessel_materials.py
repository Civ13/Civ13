"""Holding tanks by material (docs/material-roles.md, "Tanks").

code/modules/materials/vessel_materials.dm lets the holding tank be made of
copper, bronze, lead or iron as well as steel.

- A steel tank is untouched: acid only eats metal that corrodes faster than
  steel, and of the tank metals that is iron alone.
- Lead is the only toxic tank metal, and both hazards warn on examine.
- A tank stores one material name; the wooden cistern keeps its own look.
- Every metal has a recipe from its own stack, and the type a research gate.
- The tinted sprite is reproduced by its script.
"""
from pathlib import Path
import re
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/materials/vessel_materials.dm').read_text(encoding='utf-8')
PIPES = (ROOT / 'code/modules/1713/factory_pipes.dm').read_text(encoding='utf-8', errors='ignore')
PROPERTIES = (ROOT / 'code/modules/materials/material_properties.dm').read_text(encoding='utf-8')
RESEARCH = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8', errors='ignore')
CATALOG = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8', errors='ignore')
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8', errors='ignore')

METALS = ('copper', 'bronze', 'lead', 'iron')


def prop(material, name, default):
    body = re.search(r'^/material/%s\n((?:\t[^\n]*\n)+)' % material, PROPERTIES, re.M)[1]
    found = re.search(r'\t%s = (\S+)' % name, body)
    return found[1] if found else default


def proc(name):
    start = SOURCE.index(name)
    end = SOURCE.find('\n/', start + 1)
    return SOURCE[start:end if end > 0 else len(SOURCE)]


class VesselMaterials(unittest.TestCase):
    def test_acid_eats_iron_and_spares_steel(self):
        limit = float(re.search(r'#define VESSEL_ACID_CORROSION (\S+)', SOURCE)[1])
        self.assertIn('return M ? M.corrosion > VESSEL_ACID_CORROSION : FALSE', proc('/proc/vessel_acid_eats('))
        eaten = [name for name in METALS + ('steel',) if float(prop(name, 'corrosion', '40')) > limit]
        self.assertEqual(eaten, ['iron'])
        self.assertIn('istype(chemical_reagents_list[id], /datum/reagent/acid)', proc('/proc/reagent_is_acid('))

    def test_only_lead_is_toxic(self):
        self.assertEqual([name for name in METALS + ('steel',) if prop(name, 'toxic', 'FALSE') == 'TRUE'], ['lead'])

    def test_a_steel_tank_is_untouched(self):
        receive = proc('/obj/structure/fluid_tank/fluid_receive(')
        self.assertIn('. = ..()\n\tif (. <= 0 || tank_material == "steel")\n\t\treturn', receive)
        self.assertIn('reagents.remove_reagent(id, min(., VESSEL_ACID_LOSS))', receive)
        self.assertIn('prob(VESSEL_TOXIN_CHANCE) && fluid_add_to(reagents, "lead", 1, null) > 0', receive)
        self.assertIn('if (!M || tank_material == "steel")\n\t\treturn', proc('/obj/structure/fluid_tank/proc/apply_tank_material('))
        for name in ('tank_material', 'vessel_acid_eats'):
            self.assertNotIn(name, PIPES)
        self.assertLess(DME.index('modules\\1713\\factory_pipes.dm'), DME.index('modules\\materials\\vessel_materials.dm'))

    def test_hazards_warn_on_examine(self):
        examine = proc('/obj/structure/fluid_tank/examine(')
        self.assertIn('if (pipe_material_toxic(tank_material))\n\t\tto_chat(user, SPAN_WARNING(', examine)
        self.assertIn('if (vessel_acid_eats(tank_material))\n\t\tto_chat(user, SPAN_WARNING(', examine)

    def test_a_tank_stores_one_name(self):
        base = re.search(r'^/obj/structure/fluid_tank\n((?:\t[^\n]*\n)+)', SOURCE, re.M)[1]
        self.assertEqual([line for line in base.splitlines() if not line.strip().startswith('//')], ['\tvar/tank_material = "steel"'])
        self.assertIn('/obj/structure/fluid_tank/after_load()\n\t. = ..()\n\tapply_tank_material()', SOURCE)
        self.assertIn('/obj/structure/fluid_tank/cistern\n\ttank_material = "wood"', SOURCE)
        self.assertIn('/obj/structure/fluid_tank/cistern/apply_tank_material()\n\treturn', SOURCE)

    def test_recipes_and_gate(self):
        for name in METALS:
            self.assertIn('RECIPE: /material/%s/,%s tank,/obj/structure/fluid_tank/plain,10,150,1,1,plumbing,0,0,0,8,%s' % (name, name, name), CATALOG)
        self.assertIn('"/obj/structure/fluid_tank/plain" = "bronze_working",', RESEARCH)

    def test_sprite_is_reproducible(self):
        self.assertIn("icon = 'icons/obj/fluid_tanks.dmi'\n\ticon_state = \"tank\"", SOURCE)
        done = subprocess.run([sys.executable, str(ROOT / 'tests/sprites/create_fluid_tanks.py'), '--check'],
                              capture_output=True, text=True)
        self.assertEqual(done.returncode, 0, done.stdout + done.stderr)


if __name__ == '__main__':
    unittest.main()
