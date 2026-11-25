"""Lathes (docs/material-roles.md, "Lathes").

code/modules/materials/lathes.dm: the pole lathe and the engine lathe turn
precise gear sets, shafts and bearings from stock and true rough ones.

- Each lathe has a recipe, a research subject, its build needs and sprites.
- Neither lathe needs a precise part to be built, so the first can be made.
- Every material a lathe lists can do every job it turns, has a stack to
  feed it and is craftable some other way first (no orphan material).
- Springs and belts are never turned.
- The work is rechecked after the wait and paid only then.
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
SOURCE = (ROOT / 'code/modules/materials/lathes.dm').read_text(encoding='utf-8')
SHEETS = (ROOT / 'code/modules/materials/material_sheets.dm').read_text(encoding='utf-8', errors='ignore')
RESEARCH = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8', errors='ignore')
CATALOG = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8', errors='ignore')
NEEDS = json.loads((ROOT / 'config/craft_needs.json').read_text(encoding='utf-8'))
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8', errors='ignore')

POLE = '/obj/structure/workshop_machine/lathe/pole'
ENGINE = '/obj/structure/workshop_machine/lathe/engine'
TURNED = {'/obj/item/machine_part/gear': 'gear', '/obj/item/machine_part/shaft': 'shaft',
          '/obj/item/machine_part/bearing': 'bearing'}


def listed(name):
    return re.findall(r'"(\w+)"', re.search(r'var/global/list/%s = list\(([^)]*)\)' % name, SOURCE)[1])


def proc(name):
    start = SOURCE.index(name)
    end = SOURCE.find('\n/', start + 1)
    return SOURCE[start:end if end > 0 else len(SOURCE)]


class Lathes(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.materials = roles.load_materials()
        cls.roles, cls.consts = roles.load_roles()

    def test_recipes_research_and_needs(self):
        self.assertIn('RECIPE: /material/wood/,pole lathe,%s,8,150,1,1,' % POLE, CATALOG)
        self.assertIn('RECIPE: /material/iron/,engine lathe,%s,12,200,1,1,' % ENGINE, CATALOG)
        self.assertIn('"%s" = "workshops"' % POLE, RESEARCH)
        self.assertIn('"%s" = "machined_tools"' % ENGINE, RESEARCH)
        self.assertEqual(NEEDS[POLE], {'tools': [], 'inputs': {'/obj/item/stack/material/rope': 2}})
        self.assertEqual(NEEDS[ENGINE]['tools'], ['wrench'])
        self.assertEqual(NEEDS[ENGINE]['inputs'], {'/obj/item/machine_part/gear': 1, '/obj/item/machine_part/shaft': 1,
                                                   '/obj/item/machine_part/bearing': 2})
        self.assertIn('lathes.dm', DME)

    def test_first_lathe_needs_no_precise_part(self):
        # Build inputs are matched by type alone; nothing asks for precise.
        needs = (ROOT / 'code/game/objects/items/stacks/craft_needs.dm').read_text(encoding='utf-8')
        self.assertNotIn('precise', needs)
        self.assertNotIn('machine_part', json.dumps(NEEDS[POLE]))

    def test_materials_can_do_every_turned_job(self):
        pole, engine = listed('pole_lathe_materials'), listed('engine_lathe_materials')
        self.assertEqual(pole, ['wood', 'bone', 'brass'])
        self.assertEqual(engine, ['copper', 'bronze', 'brass', 'iron', 'steel'])
        for name in pole + engine:
            self.assertRegex(SHEETS, r'default_type = "%s"' % name)
            for role in TURNED.values():
                rated = roles.rate(self.roles[role], self.materials[name], self.materials, self.consts)
                self.assertIsNotNone(rated, (role, name))

    def test_only_gears_shafts_and_bearings_are_turned(self):
        rows = re.findall(r'^\t"([\w ]+)" = list\((/obj/item/machine_part/\w+), (\d+), (\d+)\),$', SOURCE, re.M)
        self.assertEqual({row[1] for row in rows}, set(TURNED))
        refusal = proc('/obj/structure/workshop_machine/lathe/proc/turn_refusal(')
        self.assertIn('!(material_name in lathe_materials())', refusal)
        self.assertIn('return machine_part_refusal(part_type, material_name)', refusal)
        self.assertIn('turn_refusal(P.type, P.part_material)', proc('/obj/structure/workshop_machine/lathe/proc/true_part('))

    def test_work_is_rechecked_then_paid(self):
        turn = proc('/obj/structure/workshop_machine/lathe/proc/turn_part(')
        wait = turn.index('do_after(')
        self.assertLess(wait, turn.index('S.use(row[2])'))
        self.assertIn('turner_ready(H, S) && S.amount >= row[2] && !tool_refusal(H)', turn[wait:])
        self.assertIn('made.precise = TRUE', turn)
        self.assertEqual(turn.count('busy = FALSE'), 1)
        true = proc('/obj/structure/workshop_machine/lathe/proc/true_part(')
        self.assertIn('turner_ready(H, P) && !P.precise && !tool_refusal(H)', true[true.index('do_after('):])
        self.assertIn('P.wear >= MACHINE_PART_WORN_OUT', true)

    def test_each_cut_rechecks_lathe_subject_before_committing(self):
        readiness = proc('/obj/structure/workshop_machine/lathe/proc/turner_ready(')
        self.assertIn('&& crafting_recipe_allowed(H, "[type]")', readiness)
        for method, item, mutation in (
            ('turn_part', 'S', 'S.use(row[2])'),
            ('true_part', 'P', 'P.precise = TRUE'),
        ):
            cut = proc('/obj/structure/workshop_machine/lathe/proc/%s(' % method)
            wait = cut.index('do_after(')
            self.assertIn('turner_ready(H, %s)' % item, cut[:wait])
            self.assertIn('turner_ready(H, %s)' % item, cut[wait:cut.index(mutation)])
        self.assertIn('crafting_recipe_allowed(H, "[row[1]]")', proc(
            '/obj/structure/workshop_machine/lathe/proc/turn_part('))

    def test_pole_lathe_needs_a_chisel_and_the_engine_lathe_does_not(self):
        self.assertIn('craft_need_tool(H, "chisel", craft_need_candidates(H))', SOURCE)
        engine = re.search(r'^%s\n((?:\t[^\n]*\n)+)' % re.escape(ENGINE), SOURCE, re.M)[1]
        self.assertIn('needs_chisel = FALSE', engine)

    def test_sprites(self):
        script = load('create_lathes', 'tests/sprites/create_lathes.py')
        states = script.build()
        for state in ('pole_lathe', 'pole_lathe_on', 'engine_lathe', 'engine_lathe_on'):
            self.assertIn(state, states)
        self.assertEqual(len(states['pole_lathe_on'][0]), 4)
        for path, state in ((POLE, 'pole_lathe'), (ENGINE, 'engine_lathe')):
            block = re.search(r'^%s\n((?:\t[^\n]*\n)+)' % re.escape(path), SOURCE, re.M)[1]
            self.assertIn('icon_state = "%s"' % state, block)
        done = subprocess.run([sys.executable, str(ROOT / 'tests/sprites/create_lathes.py'), '--check'],
                              capture_output=True, text=True)
        self.assertEqual(done.returncode, 0, done.stdout + done.stderr)


if __name__ == '__main__':
    unittest.main()
