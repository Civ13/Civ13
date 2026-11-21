"""Martial schools: offline seam checks.

The native probe (probe.dm, run.py) checks choosing, ranks, forms, practice and
travel in a real build. These checks keep the wiring it cannot reach: the era
coverage of the school list against the research tree, the rank defines, the
include and the region travel hooks.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8-sig')


LEARNING = read('code/modules/research_tree/learning_by_doing.dm')
SOURCE = read('code/modules/1713/martial_arts/martial_schools.dm')
NODES = read('code/modules/research_tree/research_node.dm')
DEFINES = read('code/__defines/martial.dm')
TRAVEL = read('code/modules/persistence/region_travel.dm')
MOVES = read('code/modules/1713/martial_arts/martial_moves.dm')
GRAB = read('code/game/mob/grab.dm')
LIVING = read('code/game/mob/living/living.dm')
MIND = read('code/datums/mind.dm')
TRAINING = read('code/modules/1713/martial_arts/martial_training.dm')
RECIPES = read('config/crafting/material_recipes_global.txt')
ATTACK = read('code/game/mob/living/carbon/human/human_attackhand.dm')
CONDITIONING = read('code/modules/1713/martial_arts/hand_conditioning.dm')
DME = read('civ13.dme')

SCHOOL = re.compile(r'^\t"(\w+)" = list\("([^"]+)", (\d), "(\w+)", "[^"]+"\)', re.M)


class Schools(unittest.TestCase):
    def setUp(self):
        self.schools = SCHOOL.findall(SOURCE)

    def test_every_era_opens_a_school(self):
        self.assertEqual(len(self.schools), 12)
        self.assertEqual({int(era) for _, _, era, _ in self.schools}, set(range(10)))

    def test_each_school_has_its_node_in_its_era(self):
        for school_id, name, era, node in self.schools:
            m = re.search(r'research_node\("%s", "%s", "Military", \d+, \d+, RESEARCH_MODE_ANALYSIS, '
                          r'list\("martial_disciplines"\), (\d)\)' % (node, re.escape(name)), NODES)
            self.assertTrue(m, school_id)
            self.assertEqual(m[1], era, school_id)

    def test_schools_are_unarmed_and_never_retire(self):
        # Minimum era only: nothing in the file closes a school later.
        self.assertNotIn('ordinal_age', SOURCE)
        self.assertNotIn('/obj/item/weapon', SOURCE)


class Training(unittest.TestCase):
    def test_gear_recipes_and_research(self):
        for material, name, path, node in (
                ('leather', 'heavy bag', '/obj/structure/martial_gear/heavy_bag', 'martial_disciplines'),
                ('wood', 'wooden dummy', '/obj/structure/martial_gear/wooden_dummy', 'school_wing_chun'),
                ('leather', 'wrestling mat', '/obj/structure/martial_gear/wrestling_mat', 'school_grappling')):
            self.assertRegex(RECIPES, r'RECIPE: /material/%s/,%s,%s,\d+,\d+,1,1,sports,' % (material, name, path))
            self.assertIn('"%s" = "%s",' % (path, node), NODES)

    def test_company_multipliers(self):
        for name, value in (('PARTNER', '1.5'), ('MASTER', '2'), ('SPARRING', '2.5')):
            self.assertIn('#define MARTIAL_%s_MULT %s' % (name, value), TRAINING)
        # The Master bonuses are behind the verified soft whitelist.
        self.assertIn('account_verified(other.ckey)', TRAINING)
        self.assertIn('amount *= martial_training_mult(sparring)', SOURCE)
        self.assertIn('H.practice_unarmed(0.5, src)', ATTACK)
        self.assertIn('martial_practice(amount / 2, sparring)', CONDITIONING)

    def test_training_defines_are_undefined(self):
        for name in re.findall(r'^#define (\w+)', TRAINING, re.M):
            self.assertIn('#undef %s' % name, TRAINING)
        self.assertIn('#include "code\\modules\\1713\\martial_arts\\martial_training.dm"', DME)


class Moves(unittest.TestCase):
    def test_every_school_has_moves(self):
        for school_id, _, _, _ in SCHOOL.findall(SOURCE):
            self.assertIn('if ("%s")' % school_id, MOVES)

    def test_moves_ride_the_normal_paths(self):
        self.assertIn('real_damage *= H.martial_punch_mult(hit_zone)', ATTACK)
        self.assertIn('ratio *= martial_grapple_edge(assailant, affecting)', GRAB)
        self.assertEqual(LIVING.count('martial_grapple_edge(src, G.assailant)'), 2)
        self.assertIn('#include "code\\modules\\1713\\martial_arts\\martial_moves.dm"', DME)

    def test_old_ss13_arts_are_retired(self):
        for name in ('_martial', 'boxing', 'kravmaga', 'sleepingcarp', 'wrestling'):
            self.assertFalse((ROOT / ('code/modules/1713/martial_arts/%s.dm' % name)).exists(), name)
            self.assertNotIn('martial_arts\\%s.dm' % name, DME)
        self.assertNotIn('martial_art', MIND)
        self.assertNotIn('mind.martial_art', ATTACK)

    def test_no_new_global_initialisers(self):
        # The world's global initialiser is at the compiler's size limit.
        self.assertNotRegex(MOVES, r'(?m)^var/global/')
        self.assertEqual(len(re.findall(r'(?m)^var/global/', SOURCE)), 1)

    def test_fight_gains_are_capped_and_mastery_pays_once(self):
        self.assertIn('var/fight = sparring && sparring != src && !martial_teacher_ok(sparring)', SOURCE)
        self.assertIn('amount = min(amount, martial_fight_room())', SOURCE)
        self.assertIn('note_martial_mastery(MARTIAL_MASTERY_LEVELS)', SOURCE)
        self.assertIn('skill_mastery_key("military", "school")', LEARNING)


class Wiring(unittest.TestCase):
    def test_rank_defines(self):
        for i, rank in enumerate(('NONE', 'NOVICE', 'STUDENT', 'ADEPT', 'MASTER')):
            self.assertIn('#define MARTIAL_RANK_%s %d' % (rank, i), DEFINES)

    def test_included(self):
        self.assertIn('#include "code\\__defines\\martial.dm"', DME)
        self.assertIn('#include "code\\modules\\1713\\martial_arts\\martial_schools.dm"', DME)

    def test_rank_api_for_the_reaction_engine(self):
        self.assertIn('/mob/living/human/proc/martial_rank(school_id)', SOURCE)
        self.assertRegex(SOURCE, r'\n\tvar/martial_school = null')

    def test_solo_training_and_practice_hooks(self):
        self.assertIn('verb/practise_martial_forms_verb()', SOURCE)
        
    def test_travel_hooks(self):
        self.assertIn('P["martial"] = martial', TRAVEL)
        self.assertIn('!martial_travel_valid(P["martial"])', TRAVEL)
        self.assertIn('H.martial_travel_restore(P["martial"])', TRAVEL)

    def test_file_local_defines_are_undefined(self):
        for name in re.findall(r'^#define (\w+)', SOURCE, re.M):
            self.assertIn('#undef %s' % name, SOURCE)


if __name__ == '__main__':
    unittest.main()
