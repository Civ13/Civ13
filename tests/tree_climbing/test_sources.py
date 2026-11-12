"""Climbing trees: offline seam checks.

The native probe (probe.dm, run.py) checks the behaviour in a real build:
climbing from the next tile, sight from the canopy, animals that cannot follow,
climbing down to the starting spot and falling when the tree goes away. These
checks keep the hooks that the probe cannot reach in place.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


CLIMB = read('code/game/objects/structures/tree_climbing.dm')
TERRAIN = read('code/modules/visibility/los_terrain.dm')
CONTEXT = read('code/modules/visibility/los_context.dm')
CLICK = read('code/_onclick/other_mobs.dm')
MOVE = read('code/game/mob/mob_movement.dm')
AI = read('code/game/mob/living/simple_animal/hostile/tactical_ai.dm')
HUMAN = read('code/game/mob/living/carbon/human/human.dm')
DME = read('civ13.dme')


def proc(text, name):
    start = text.index(name)
    end = re.search(r'\n(?=/|#define|\Z)', text[start + 1:])
    return text[start:start + 1 + end.start()] if end else text[start:]


class TreeClimbingSources(unittest.TestCase):
    def test_included_before_wild(self):
        self.assertLess(DME.index('structures\\tree_climbing.dm'), DME.index('structures\\wild.dm'))

    def test_climber_sight(self):
        hides = proc(TERRAIN, '/proc/los_foliage_hides(')
        self.assertIn('los_in_foliage(viewer) && !los_up_tree(viewer)', hides)
        self.assertIn('|| los_in_foliage(target)', hides)
        self.assertIn('return LOS_EYE_CLIMBED', proc(TERRAIN, '/proc/los_eye_level('))
        self.assertIn('los_canopy_field_for(', proc(TERRAIN, '/proc/los_terrain_for('))
        self.assertIn('los_up_tree(body)', proc(CONTEXT, '/datum/los_context/proc/policy_key('))

    def test_click_move_and_look_hooks(self):
        unarmed = proc(CLICK, '/mob/living/human/UnarmedAttack(')
        self.assertLess(unarmed.index('grab_climb_ledge(A)'), unarmed.index('grab_climb_tree(A)'))
        self.assertLess(unarmed.index('grab_climb_tree(A)'), unarmed.index('A.attack_hand('))
        self.assertIn('start_climb_down()', proc(MOVE, '/client/Move('))
        self.assertIn('if (climbed_tree)', proc(HUMAN, '/mob/living/human/proc/look_into_distance('))

    def test_animals_left_at_the_foot(self):
        self.assertIn('if (!can_reach_tree_climber(L)) continue', proc(AI, '/mob/living/simple_animal/proc/FindTarget('))
        self.assertIn('!can_reach_tree_climber(target_mob)', proc(AI, '/mob/living/simple_animal/proc/AttackTarget('))
        reach = proc(CLIMB, '/mob/living/simple_animal/proc/can_reach_tree_climber(')
        self.assertIn('can_climb_trees', reach)
        self.assertIn('/mob/living/simple_animal/hostile/human', reach)

    def test_gorilla_foraging_and_hiding_keep_grab(self):
        grab = proc(CLIMB, '/mob/living/human/proc/grab_climb_tree(')
        self.assertIn('gorillaman && W.edible && W.leaves >= 1', grab)
        self.assertIn('W.stored_unit', grab)


if __name__ == '__main__':
    unittest.main()
