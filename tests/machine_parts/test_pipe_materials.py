"""Pipes by material (docs/material-roles.md, "Pipes").

code/modules/materials/pipe_materials.dm lets one pipe type be made of any
material and gives hand-made pipe a pump, an intake, a cistern and a trough.

- A pipe's pressure follows its material's toughness, steel is 1, and the
  frozen table below is what players are told.
- A network runs at its weakest pipe, surveyed once per rebuilt network.
- Lead is the only toxic pipe: it warns on examine and taints tanks at low odds.
- Every new piece has a recipe, and every result type a research gate.
- factory_pipes.dm is wrapped, not edited.
"""
from pathlib import Path
import importlib.util
import json
import math
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


roles = load('material_roles', 'tests/material_roles/test_material_roles.py')
SOURCE = (ROOT / 'code/modules/materials/pipe_materials.dm').read_text(encoding='utf-8')
PIPES = (ROOT / 'code/modules/1713/factory_pipes.dm').read_text(encoding='utf-8', errors='ignore')
RESEARCH = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8', errors='ignore')
CATALOG = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8', errors='ignore')
NEEDS = json.loads((ROOT / 'config/craft_needs.json').read_text(encoding='utf-8'))
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8', errors='ignore')

# material -> share of a pump's flow, as the wiki tells players
PRESSURE = {'bamboo': 0.55, 'wood': 0.65, 'lead': 0.45, 'copper': 0.75, 'iron': 0.9, 'steel': 1.0}
GATES = {
    '/obj/structure/fluid_pipe/plain': 'basic_tools',
    '/obj/structure/fluid_tank/cistern': 'cooperage',
    '/obj/structure/fluid_intake/wooden': 'cooperage',
    '/obj/structure/water_tap/trough': 'cooperage',
    '/obj/structure/fluid_pump/hand': 'workshops',
}


def proc(name):
    start = SOURCE.index(name)
    end = SOURCE.find('\n/', start + 1)
    return SOURCE[start:end if end > 0 else len(SOURCE)]


def rows():
    found = []
    for line in CATALOG.splitlines():
        if line.startswith('RECIPE: '):
            fields = line[len('RECIPE: '):].split(',')
            if len(fields) == 13:
                found.append(fields)
    return found


class PipeMaterials(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.materials = roles.load_materials()

    def pressure(self, name):
        low = float(re.search(r'#define PIPE_PRESSURE_MIN (\S+)', SOURCE)[1])
        # DM round(x, 0.05) rounds to the nearest multiple
        return max(low, min(1, round(math.floor(math.sqrt(self.materials[name]['toughness'] / 100) / 0.05 + 0.5) * 0.05, 2)))

    def test_pressure_follows_toughness(self):
        body = proc('/proc/pipe_pressure(')
        self.assertIn('max(PIPE_PRESSURE_MIN, min(1, round(sqrt(M.toughness / 100), 0.05)))', body)
        self.assertEqual({name: self.pressure(name) for name in PRESSURE}, PRESSURE)
        # nothing beats steel, and nothing stops a network altogether
        for name in self.materials:
            self.assertGreaterEqual(self.pressure(name), 0.25, name)
            self.assertLessEqual(self.pressure(name), 1, name)

    def test_only_lead_is_toxic_among_pipe_materials(self):
        self.assertEqual([name for name in PRESSURE if self.materials[name]['toxic']], ['lead'])
        self.assertIn('return M ? M.toxic : FALSE', proc('/proc/pipe_material_toxic('))
        examine = proc('/obj/structure/fluid_pipe/examine(')
        self.assertIn('if (pipe_material_toxic(pipe_material))\n\t\tto_chat(user, SPAN_WARNING(', examine)
        self.assertIn('if (network && network.toxic_pipes)\n\t\tto_chat(user, SPAN_WARNING(', examine)

    def test_a_pipe_stores_one_name(self):
        base = re.search(r'^/obj/structure/fluid_pipe\n((?:\t[^\n]*\n)+)', SOURCE, re.M)[1]
        self.assertEqual([line for line in base.splitlines() if not line.strip().startswith('//')], ['\tvar/pipe_material = "steel"'])
        new = proc('/obj/structure/fluid_pipe/New(newloc, material_name)')
        self.assertIn('if (istext(material_name) && get_material_by_name(material_name))\n\t\tpipe_material = material_name\n\t..(newloc)\n\tapply_pipe_material()', new)
        # a loaded pipe gets its look back, and a steel pipe is untouched
        self.assertIn('/obj/structure/fluid_pipe/after_load()\n\t. = ..()\n\tapply_pipe_material()', SOURCE)
        self.assertIn('if (!M || pipe_material == "steel")\n\t\treturn', proc('/obj/structure/fluid_pipe/proc/apply_pipe_material('))
        self.assertIn('/obj/structure/fluid_pipe/valve/apply_pipe_material()\n\treturn', SOURCE)

    def test_a_network_runs_at_its_weakest_pipe(self):
        survey = proc('/datum/fluid_network/proc/survey_pipes(')
        self.assertIn('if (rating < pressure)\n\t\t\tpressure = rating\n\t\t\tweakest = P.pipe_material', survey)
        rate = proc('/datum/fluid_network/pumped_rate(')
        self.assertIn('. = ..()\n\tif (. > 0)\n\t\tif (!pressure)\n\t\t\tsurvey_pipes()\n\t\t. = max(1, round(. * pressure))', rate)
        # networks are new datums on every rebuild, so the survey is never stale
        self.assertIn('var/datum/fluid_network/N = new', PIPES)
        self.assertIn('var/pressure = 0', SOURCE)

    def test_lead_taints_at_low_odds(self):
        chance = float(re.search(r'#define PIPE_TOXIN_CHANCE (\S+)', SOURCE)[1])
        self.assertGreater(chance, 0)
        self.assertLessEqual(chance, 5)
        step = proc('/datum/fluid_network/network_step(')
        self.assertIn('. = ..()\n\tif (. > 0 && toxic_pipes && prob(PIPE_TOXIN_CHANCE))\n\t\ttaint_from_pipes()', step)
        taint = proc('/datum/fluid_network/proc/taint_from_pipes(')
        # only something that asks for lead gets it: filtered tanks and fuel lines refuse
        self.assertIn('O.fluid_demand("lead") > 0', taint)
        self.assertIn('taker.fluid_receive("lead", 1, null)', taint)
        self.assertIn('/datum/reagent/lead/affect_blood(', SOURCE)

    def test_factory_pipes_are_wrapped_not_edited(self):
        for name in ('pipe_material', 'pipe_pressure', 'survey_pipes', 'taint_from_pipes'):
            self.assertNotIn(name, PIPES)
        self.assertLess(DME.index('modules\\1713\\factory_pipes.dm'), DME.index('modules\\materials\\pipe_materials.dm'))

    def test_hand_pump_needs_no_power(self):
        pump = SOURCE[SOURCE.index('/obj/structure/fluid_pump/hand\n'):SOURCE.index('/obj/structure/fluid_intake/wooden')]
        self.assertIn('powerneeded = 0', pump)
        self.assertIn('var/tmp/pumped_until = 0', pump)
        self.assertIn('return world.time < pumped_until || mechanical_drive_factor(src) < 1', pump)
        self.assertIn('on = (anchored && isturf(loc) && driven()) ? TRUE : FALSE\n\tpowered = on', pump)
        hand = proc('/obj/structure/fluid_pump/hand/attack_hand(')
        self.assertLess(hand.index('pumped_until = world.time + HAND_PUMP_RUN'), hand.index('if (!do_after(H, HAND_PUMP_STROKE, src))'))
        # a pull must outlast the stroke and the two-second network step
        run = float(re.search(r'#define HAND_PUMP_RUN (\d+)', SOURCE)[1])
        stroke = float(re.search(r'#define HAND_PUMP_STROKE (\d+)', SOURCE)[1])
        self.assertGreaterEqual(run, stroke + 20)

    def test_every_piece_has_a_recipe_and_a_gate(self):
        crafted = {}
        for fields in rows():
            if fields[2] in GATES:
                crafted.setdefault(fields[2], []).append(fields)
        self.assertEqual(set(crafted), set(GATES))
        pipes = {fields[0].strip('/').split('/')[-1]: fields[12] for fields in crafted['/obj/structure/fluid_pipe/plain']}
        # the stack a pipe is made from is the material it is made of
        self.assertEqual(pipes, {name: name for name in PRESSURE if name != 'steel'})
        for path, node in GATES.items():
            self.assertIn('"%s" = "%s",' % (path, node), RESEARCH)
            self.assertRegex(SOURCE, r'(?m)^%s$' % re.escape(path))
        self.assertEqual(NEEDS['/obj/structure/fluid_pump/hand']['inputs'], {'/obj/item/machine_part/shaft': 1})


if __name__ == '__main__':
    unittest.main()
