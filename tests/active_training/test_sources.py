"""Training gear, the tread wheel, treadmill and skipping rope: offline seam checks.

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
    '/obj/item/weapon/skipping_rope': ('/material/rope/', 2, 0, 'basic_tools'),
    '/obj/structure/treadwheel': ('/material/wood/', 8, 30, 'primitive_construction'),
    '/obj/structure/treadwheel/treadmill': ('/material/steel/', 6, 105, 'factories'),
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
            # items are made in the hand, wheels and treadmills one to a tile
            self.assertEqual(row[5], '1' if path.startswith('/obj/structure') else '0', path)
            self.assertIn('"%s" = "%s",' % (path, node), NODES)
        # neither the first fixtures nor the obstacle course can be built any more
        for old in ('/obj/structure/exercise', '/obj/structure/training_course'):
            self.assertNotIn(old, RECIPES)
            self.assertNotIn('"%s' % old, NODES)
            self.assertNotIn(old, read('config/craft_needs.json'))

    def test_crafting_gate_matches_the_recipes(self):
        self.assertIn('/datum/craft_guard/skill_gate/exercise/allowed(mob/living/human/H, result_type)\n\treturn exercise_can_build(H, result_type)', CORE)
        self.assertIn('if (exercise_modern_gear(result_type))\n\t\treturn 105', CORE)
        self.assertIn('if (result_type == /obj/item/weapon/lifting_weight || result_type == /obj/item/weapon/skipping_rope)\n\t\treturn 0\n\treturn 30', CORE)
        self.assertIn('map.ordinal_age >= 8', CORE)

    def test_sessions_run_continuously_until_stopped(self):
        """One use starts a session (Val, 2026-11-22): it repeats lift by lift and
        skip by skip, draining stamina, and only the player, the stamina pool or a
        real refusal ends it. Nothing trains on a timer by itself."""
        self.assertIn('#define LIFT_HEAVE_TIME 8', GEAR)
        self.assertIn('#define LIFT_HOLD_TIME 12', GEAR)
        self.assertIn('#define SKIP_TIME 20', COURSE)
        self.assertIn('while (isnull(stop_reason))\n\t\tstop_reason = lift(H, token)', GEAR)
        self.assertIn('while (isnull(stop_reason))\n\t\tstop_reason = skip(H, token)', COURSE)
        self.assertIn('H.training_spend_stamina(duration)', GEAR)
        self.assertIn('H.training_spend_stamina(SKIP_TIME)', COURSE)
        for text in (GEAR, COURSE):
            self.assertNotIn('spawn(', text)
            self.assertNotIn('LIFT_SET_WINDOW', text)
            self.assertNotIn('SKIP_SET_WINDOW', text)
        self.assertNotIn('Exercise Step', CORE + GEAR + COURSE)
        defines = read('code/__defines/training.dm')
        self.assertIn('#define TRAINING_STAMINA_DRAIN 0.014', defines)
        self.assertIn('#include "code\\__defines\\training.dm"', DME)
        self.assertIn('return stats["stamina"][2] * TRAINING_STAMINA_DRAIN * duration / 10', CORE)
        # Stop Exercise ends every kind of session, not only equipment sets.
        self.assertIn('return exercise_equipment || floor_exercise_busy || scholar_practising', CORE)

    def test_walking_with_a_weight_reaches_the_carry_hook(self):
        turf = read('code/game/turfs/turf.dm')
        entered = turf[turf.index('/turf/Entered(atom/A, atom/OL)'):]
        self.assertIn('if (H.l_hand || H.r_hand)\n\t\t\t\tH.exercise_carry_step()', entered)

    def test_movement_keys_reach_the_wheel(self):
        movement = read('code/game/mob/mob_movement.dm')
        hook = movement.index('if (istype(mob.buckled, /obj/structure/treadwheel))')
        self.assertLess(hook, movement.index('\tif (!mob.canmove)\n'))
        self.assertIn('if (istype(mob.buckled, /obj/structure/treadwheel))\n\t\tmove_delay = world.time + mob.movement_delay()\n\t\treturn mob.buckled.relaymove(mob, direct)', movement)
        self.assertIn('/obj/structure/treadwheel/relaymove(mob/user, direction)', COURSE)

    def test_runtime_fields_stay_out_of_saves(self):
        body = re.search(r'^/mob/living/human/persistence_runtime_var\(key\)\n\t(.*)\n', CORE, re.M)[1]
        for key in ('exercise_rest_epoch', 'exercise_equipment', 'survival_rest_since', 'survival_actions',
                    'survival_workload', 'exercise_token'):
            self.assertIn('"%s"' % key, body)
        self.assertNotIn('"exercise_fatigue"', body)
        self.assertIn('return (key in list("reps", "lifting", "carry_tiles", "winded")) || ..()', GEAR)
        self.assertIn('return (key in list("strides", "run_strides", "last_stride")) || ..()', COURSE)
        self.assertIn('return (key in list("skips", "skipping", "winded")) || ..()', COURSE)

    def test_old_fixtures_convert_after_load(self):
        self.assertIn('/obj/structure/exercise/after_load()\n\t. = ..()\n\taddtimer(CALLBACK(src, PROC_REF(replace_legacy)), 10)', CORE)
        for old, new in (('/obj/structure/exercise\n', '/obj/item/weapon/lifting_weight/heavy'),
                         ('/obj/structure/exercise/course\n', '/obj/structure/treadwheel'),
                         ('/obj/structure/exercise/modern\n', '/obj/item/weapon/lifting_weight/barbell'),
                         ('/obj/structure/exercise/modern/course\n', '/obj/structure/treadwheel/treadmill')):
            block = CORE[CORE.index('\n' + old):]
            block = block[:block.index('\n\n')]
            self.assertIn('replacement = ' + new, block)

    def test_old_course_pieces_convert_after_load(self):
        self.assertIn('/obj/structure/training_course/after_load()\n\t. = ..()\n\taddtimer(CALLBACK(src, PROC_REF(replace_legacy)), 10)', COURSE)
        for old, new in (('/obj/structure/training_course/post\n', 'replacement = /obj/structure/treadwheel'),
                         ('/obj/structure/training_course/post/finish\n', 'amount = 3'),
                         ('/obj/structure/training_course/hurdle/steel\n', 'replacement = /obj/item/stack/material/steel'),
                         ('/obj/structure/training_course/balance_log\n', 'amount = 4')):
            block = COURSE[COURSE.index('\n' + old):]
            block = block[:block.index('\n\n')]
            self.assertIn(new, block)

    def test_art_is_reproducible(self):
        result = subprocess.run([sys.executable, str(ROOT / 'tests/sprites/create_training_gear.py'), '--check'],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for text in (CORE, GEAR, COURSE):
            for state in re.findall(r'(?:icon_state|turning_state) = "(\w+)"|\? "(\w+)" :', text):
                state = state[0] or state[1]
                self.assertIn('\'%s\'' % state, read('tests/sprites/create_training_gear.py'), state)


if __name__ == '__main__':
    unittest.main()
