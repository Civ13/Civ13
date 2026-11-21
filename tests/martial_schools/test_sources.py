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


SOURCE = read('code/modules/1713/martial_arts/martial_schools.dm')
NODES = read('code/modules/research_tree/research_node.dm')
DEFINES = read('code/__defines/martial.dm')
TRAVEL = read('code/modules/persistence/region_travel.dm')
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
        self.assertIn('martial_practice(amount / 2)', CONDITIONING)

    def test_travel_hooks(self):
        self.assertIn('P["martial"] = martial', TRAVEL)
        self.assertIn('!martial_travel_valid(P["martial"])', TRAVEL)
        self.assertIn('H.martial_travel_restore(P["martial"])', TRAVEL)

    def test_file_local_defines_are_undefined(self):
        for name in re.findall(r'^#define (\w+)', SOURCE, re.M):
            self.assertIn('#undef %s' % name, SOURCE)


if __name__ == '__main__':
    unittest.main()
