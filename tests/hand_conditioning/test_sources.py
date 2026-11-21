"""Hand conditioning and the unarmed skill: offline seam checks.

The native probe (probe.dm, run.py) checks sets, caps, risk, injuries, fading
and the skill in a real build. These checks keep the wiring it cannot reach:
recipes, the research node, the punch hooks, the skill lists and the include.
"""
from pathlib import Path
import re
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


SOURCE = read('code/modules/1713/martial_arts/hand_conditioning.dm')
ATTACK = read('code/game/mob/living/carbon/human/human_attackhand.dm')
PUNCH = read('code/game/mob/living/carbon/human/punch_injury.dm')
RECIPES = read('config/crafting/material_recipes_global.txt')
NODES = read('code/modules/research_tree/research_node.dm')
DEFINES = read('code/game/mob/living/carbon/human/human_defines.dm')
STATS = read('code/game/mob/living/carbon/human/human_stats.dm')
LEARNING = read('code/modules/research_tree/learning_by_doing.dm')
DME = read('civ13.dme')

GEAR = {
    '/obj/structure/striking_post': ('/material/wood/', 4),
    '/obj/structure/striking_post/gravel_pail': ('/material/wood/', 3),
}


class HandConditioningSources(unittest.TestCase):
    def test_source_is_compiled(self):
        self.assertIn('#include "code\\modules\\1713\\martial_arts\\hand_conditioning.dm"', DME)

    def test_gear_has_recipes_and_research(self):
        self.assertIn('register_research_node(new /datum/research_node("martial_disciplines", "Martial Disciplines", '
                      '"Military", 60, 0, RESEARCH_MODE_ANALYSIS, null, 0))', NODES)
        rows = {}
        for line in RECIPES.splitlines():
            if line.startswith('RECIPE: '):
                cells = line[len('RECIPE: '):].split(',')
                rows[cells[2]] = cells
        for path, (material, cost) in GEAR.items():
            row = rows[path]
            self.assertEqual(len(row), 13, path)
            self.assertEqual((row[0], int(row[3]), row[5], row[7]), (material, cost, '1', 'sports'), path)
            self.assertIn('"%s" = "martial_disciplines",' % path, NODES)

    def test_punches_use_the_skill_and_conditioning(self):
        self.assertIn('real_damage *= H.unarmed_damage_mult()', ATTACK)
        self.assertIn('H.practice_unarmed(0.5, src)', ATTACK)
        self.assertIn('chance *= hand_conditioning_factor()', PUNCH)

    def test_unarmed_is_a_full_skill(self):
        self.assertIn('"unarmed" = list(100,100),', DEFINES)
        self.assertIn('"swimming", "unarmed").Find(statname)', STATS)
        self.assertIn('"unarmed" = "military",', LEARNING)

    def test_rock_needs_harm_intent(self):
        self.assertIn('/turf/wall/rockwall/attack_hand(mob/living/human/H)\n'
                      '\tif (istype(H) && H.a_intent == I_HARM && Adjacent(H))', SOURCE)



class Art(unittest.TestCase):
    def test_art_is_reproducible(self):
        script = ROOT / 'tests/sprites/create_martial_training.py'
        result = subprocess.run([sys.executable, str(script), '--check'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("icons/obj/martial_training.dmi", SOURCE)
        for state in re.findall(r'icon_state = "(\w+)"', SOURCE):
            self.assertIn("'%s'" % state, script.read_text(encoding='utf-8'), state)


if __name__ == '__main__':
    unittest.main()
