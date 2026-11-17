"""Training gear and the obstacle course: offline seam checks.

The native probe (probe.dm, run.py) checks the behaviour in a real build. These
checks keep the wiring the probe cannot reach: recipes, research, the crafting
gate, the walking hook, saved fields and the art.
"""
import json
from pathlib import Path
import re
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


CORE = read('code/modules/1713/active_training.dm')
GEAR = read('code/modules/1713/training_gear.dm')
COURSE = read('code/modules/1713/training_course.dm')
RECIPES = read('config/crafting/material_recipes_global.txt')
NODES = read('code/modules/research_tree/research_node.dm')
DME = read('civ13.dme')

GEAR_RECIPES = {
    '/obj/item/weapon/lifting_weight': ('/material/stone/', 2, 0, 'basic_tools'),
    '/obj/item/weapon/lifting_weight/heavy': ('/material/stone/', 5, 30, 'basic_tools'),
    '/obj/item/weapon/lifting_weight/great': ('/material/stone/', 10, 30, 'basic_tools'),
    '/obj/item/weapon/lifting_weight/hand_weights': ('/material/bronze/', 3, 30, 'bronze_working'),
    '/obj/item/weapon/lifting_weight/barbell': ('/material/iron/', 12, 105, 'factories'),
    '/obj/structure/training_course/post': ('/material/wood/', 4, 30, 'primitive_construction'),
    '/obj/structure/training_course/post/finish': ('/material/wood/', 3, 30, 'primitive_construction'),
    '/obj/structure/training_course/hurdle': ('/material/wood/', 3, 30, 'primitive_construction'),
    '/obj/structure/training_course/balance_log': ('/material/wood/', 4, 30, 'primitive_construction'),
    '/obj/structure/training_course/hurdle/steel': ('/material/steel/', 3, 105, 'factories'),
}


class TrainingGearSources(unittest.TestCase):
    def test_sources_are_compiled(self):
        for name in ('active_training.dm', 'training_gear.dm', 'training_course.dm'):
            self.assertIn('#include "code\\modules\\1713\\%s"' % name, DME)

    def test_every_piece_has_a_recipe_and_research(self):
        rows = {}
        for line in RECIPES.splitlines():
            if line.startswith('RECIPE: '):
                cells = line[len('RECIPE: '):].split(',')
                rows[cells[2]] = cells
        for path, (material, cost, skill, node) in GEAR_RECIPES.items():
            self.assertIn(path, rows, path)
            row = rows[path]
            self.assertEqual(len(row), 13, path)
            self.assertEqual((row[0], int(row[3]), row[7], int(row[8])), (material, cost, 'sports', skill), path)
            # items are made in the hand, course pieces one to a tile
            self.assertEqual(row[5], '1' if path.startswith('/obj/structure') else '0', path)
            self.assertIn('"%s" = "%s",' % (path, node), NODES)
        self.assertNotIn('/obj/structure/exercise', RECIPES)
        self.assertNotIn('"/obj/structure/exercise', NODES)

    def test_start_post_flag_takes_cloth_or_leather(self):
        needs = json.loads(read('config/craft_needs.json'))
        self.assertEqual(needs['/obj/structure/training_course/post'],
                         {'tools': [], 'inputs': {'/obj/item/stack/material/cloth': 1}})
        craft = read('code/game/objects/items/stacks/craft_needs.dm')
        self.assertIn('/obj/item/stack/material/cloth = list(/obj/item/stack/material/woolcloth, /obj/item/stack/material/leather),', craft)

    def test_crafting_gate_matches_the_recipes(self):
        self.assertIn('/datum/craft_guard/skill_gate/exercise/allowed(mob/living/human/H, result_type)\n\treturn exercise_can_build(H, result_type)', CORE)
        self.assertIn('if (exercise_modern_gear(result_type))\n\t\treturn 105', CORE)
        self.assertIn('if (result_type == /obj/item/weapon/lifting_weight)\n\t\treturn 0\n\treturn 30', CORE)
        self.assertIn('map.ordinal_age >= 8', CORE)

    def test_no_waiting_timers_pay_skills(self):
        """Lifts are two seconds each and started by hand; nothing loops by itself."""
        self.assertIn('#define LIFT_HEAVE_TIME 8', GEAR)
        self.assertIn('#define LIFT_HOLD_TIME 12', GEAR)
        for text in (GEAR, COURSE):
            self.assertNotIn('while (', text)
            self.assertNotIn('spawn(', text)
        self.assertNotIn('Exercise Step', CORE + GEAR + COURSE)

    def test_walking_with_a_weight_reaches_the_carry_hook(self):
        turf = read('code/game/turfs/turf.dm')
        entered = turf[turf.index('/turf/Entered(atom/A, atom/OL)'):]
        self.assertIn('if (H.l_hand || H.r_hand)\n\t\t\t\tH.exercise_carry_step()', entered)

    def test_runtime_fields_stay_out_of_saves(self):
        body = re.search(r'^/mob/living/human/persistence_runtime_var\(key\)\n\t(.*)\n', CORE, re.M)[1]
        for key in ('exercise_rest_epoch', 'exercise_equipment', 'survival_rest_since', 'survival_actions',
                    'survival_workload', 'exercise_token', 'course_vault_at'):
            self.assertIn('"%s"' % key, body)
        self.assertNotIn('"exercise_fatigue"', body)
        self.assertIn('return (key in list("reps", "lifting", "carry_tiles")) || ..()', GEAR)
        # the best time is the course's lasting record
        for field in ('best_time', 'best_count', 'best_name'):
            self.assertRegex(COURSE, r'\n\tvar/%s = ' % field)

    def test_old_fixtures_convert_after_load(self):
        self.assertIn('/obj/structure/exercise/after_load()\n\t. = ..()\n\taddtimer(CALLBACK(src, PROC_REF(replace_legacy)), 10)', CORE)
        for old, new in (('/obj/structure/exercise\n', '/obj/item/weapon/lifting_weight/heavy'),
                         ('/obj/structure/exercise/course\n', '/obj/structure/training_course/post'),
                         ('/obj/structure/exercise/modern\n', '/obj/item/weapon/lifting_weight/barbell'),
                         ('/obj/structure/exercise/modern/course\n', '/obj/structure/training_course/post')):
            block = CORE[CORE.index('\n' + old):]
            block = block[:block.index('\n\n')]
            self.assertIn('replacement = ' + new, block)

    def test_art_is_reproducible(self):
        result = subprocess.run([sys.executable, str(ROOT / 'tests/sprites/create_training_gear.py'), '--check'],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for text in (CORE, GEAR, COURSE):
            for state in re.findall(r'icon_state = "(\w+)"', text):
                self.assertIn('\'%s\'' % state, read('tests/sprites/create_training_gear.py'), state)


if __name__ == '__main__':
    unittest.main()
