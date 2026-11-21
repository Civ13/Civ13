#!/usr/bin/env python3
"""Offline source contracts for research familiarity (learning from things)."""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
MODULE = 'code/modules/research_tree/familiarity.dm'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8', errors='replace').replace('\r\n', '\n')


def define(name):
    match = re.search(r'#define %s ([0-9.]+)\b' % name, read(MODULE))
    return float(match.group(1)) if match else None


class FamiliarityTests(unittest.TestCase):
    def test_the_module_is_compiled_in(self):
        self.assertIn('#include "code\\modules\\research_tree\\familiarity.dm"', read('civ13.dme'))

    def test_clicks_and_life_feed_it(self):
        click = read('code/_onclick/click.dm')
        held = click.index('var/obj/item/W = get_active_hand() //trying to resolve an item in hand')
        self.assertLess(held, click.index('note_familiar_click(src, W, A)'))
        self.assertLess(click.index('note_familiar_click(src, W, A)'), click.index('W.attack_self(src, icon_x, icon_y)'))
        self.assertIn('handle_familiarity()', read('code/game/mob/living/carbon/human/human_life.dm'))

    def test_only_book_research_worlds_and_unknown_subjects(self):
        module = read(MODULE)
        grow = module[module.index('/mob/living/human/proc/can_grow_familiar'):module.index('/proc/clean_familiarity')]
        for needle in ('map.book_research_enabled()', 'stat != CONSCIOUS', 'N.mode == RESEARCH_MODE_BOOK',
                       'knows_recipe_node(node_id)', 'recipe_knowledge_exempt()', 'study_fraction(node_id) < 0.99'):
            self.assertIn(needle, grow)

    def test_it_never_finishes_a_subject_alone(self):
        base, step, floor = define('FAMILIARITY_CAP_BASE'), define('FAMILIARITY_CAP_STEP'), define('FAMILIARITY_CAP_FLOOR')
        self.assertLess(base, 1)
        self.assertGreater(step, 0)
        self.assertGreater(floor, 0)
        self.assertLessEqual(floor, base)
        module = read(MODULE)
        self.assertNotIn('learn_recipe_node(', module)
        self.assertIn('0.99 - before', module)

    def test_it_builds_slowly(self):
        self.assertEqual(define('FAMILIARITY_DAILY'), 0.1)
        self.assertEqual(define('FAMILIARITY_FIRST_USE'), 0.05)
        self.assertEqual(define('FAMILIARITY_REPEAT_USE'), 0.01)
        self.assertEqual(define('FAMILIARITY_NEARBY'), 0.02)

    def test_origin_does_not_matter(self):
        module = read(MODULE)
        self.assertIsNone(re.search(r'fingerprint|made_by|crafted_by|maker', module))

    def test_the_record_is_cleaned_and_forgotten_on_death(self):
        module = read(MODULE)
        self.assertIn('familiarity = clean_familiarity(familiarity)', module)
        forget = module[module.index('/mob/living/human/forget_recipe_knowledge()'):]
        self.assertIn('..()', forget[:200])
        self.assertIn('familiarity = list()', forget[:200])


if __name__ == '__main__':
    unittest.main()
