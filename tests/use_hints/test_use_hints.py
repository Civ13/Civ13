#!/usr/bin/env python3
"""Offline source contracts for the examine use hints."""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8', errors='replace').replace('\r\n', '\n')


HINTS = read('code/game/objects/structures/use_hints.dm')
WILD = read('code/game/objects/structures/wild.dm')


class UseHints(unittest.TestCase):
    def test_the_file_is_compiled_after_tree_climbing(self):
        dme = read('civ13.dme')
        self.assertEqual(dme.count('structures\\use_hints.dm"'), 1)
        # Its /obj/structure/wild/examine chains to the one in tree_climbing.dm.
        self.assertLess(dme.index('structures\\tree_climbing.dm"'), dme.index('structures\\use_hints.dm"'))

    def test_examine_shows_the_hint_for_plants_and_ladders(self):
        for owner in ('/obj/structure/wild', '/obj/structure/multiz/ladder'):
            body = HINTS[HINTS.index(owner + '/examine('):]
            self.assertIn('. = ..()\n\tshow_use_hint(user)', body[:120])

    def test_a_disguised_hole_stays_disguised(self):
        pit = HINTS[HINTS.index('/obj/structure/multiz/ladder/ww2/tunneltop/pit/use_hint'):HINTS.index('/obj/structure/wild/examine')]
        self.assertIn('if (leaf_covered)\n\t\treturn null', pit)

    def test_palms_give_branches_and_a_stripped_tree_says_so(self):
        palm = WILD[WILD.index('/obj/structure/wild/palm\n'):WILD.index('/obj/structure/wild/palm/attackby')]
        self.assertIn('\tbranches = 2\n\tmax_branches = 2\n', palm)
        hand = WILD[WILD.index('/obj/structure/wild/attack_hand'):WILD.index('/obj/structure/wild/jungle/MouseDrop_T')]
        self.assertIn('else if (user.a_intent == I_HARM && max_branches > 0)', hand)
        self.assertIn('has no branches left to break off', hand)

    def test_magic_is_never_mentioned(self):
        self.assertNotIn('magic', HINTS.lower())


if __name__ == '__main__':
    unittest.main()
