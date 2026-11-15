"""Force-feeding someone past capacity makes them throw up (Val, 2026-11-15).

Feeding another person no longer stops at the fullness limit: the food or
drink goes down, and if the stomach is then past what it holds, they vomit.
Eating for yourself keeps its refusal. The native behaviour (stomach
fullness, purge, toxin relief) is checked in tests/chemistry/biochemistry.dm.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SNACKS = ROOT / 'code/modules/reagents/reagent_containers/food/snacks.dm'
KITCHEN = ROOT / 'code/game/objects/items/weapons/material/kitchen.dm'
CONTAINERS = ROOT / 'code/modules/reagents/reagent_containers.dm'
HUMAN = ROOT / 'code/game/mob/living/carbon/human/human.dm'


def proc_body(text, signature):
    start = text.index(signature)
    rest = text[start + len(signature):]
    end = re.search(r'\n(?=\S)', rest)
    return rest[: end.start() if end else len(rest)]


class OverfedVomitTest(unittest.TestCase):
    def test_snacks_feed_other_vomits_instead_of_refusing(self):
        body = proc_body(SNACKS.read_text(encoding='utf-8'),
                         '/obj/item/weapon/reagent_containers/food/snacks/attack(')
        feed_other = body[body.index('//If you\'re feeding somebody'):]
        self.assertNotIn('cannot force anymore', feed_other)
        self.assertIn('C != user && C.is_overfed()', body)
        self.assertIn('C.overfed_vomit(user)', body)
        # Eating for yourself still refuses past the limit.
        self.assertIn('You cannot force any more of [src] to go down your throat.', body)

    def test_utensil_feeds_after_checks_and_vomits(self):
        body = proc_body(KITCHEN.read_text(encoding='utf-8'),
                         '/obj/item/weapon/material/kitchen/utensil/attack(')
        self_part, other_part = body.split('else\n\t\t\tuser.visible_message', 1)
        self.assertLess(self_part.index('food_fullness_limit()'), self_part.index('trans_to_mob'))
        self.assertLess(other_part.index('do_mob'), other_part.index('trans_to_mob'))
        self.assertIn('M.overfed_vomit(user)', other_part)

    def test_drinks_force_fed_vomit(self):
        body = proc_body(CONTAINERS.read_text(encoding='utf-8'),
                         '/obj/item/weapon/reagent_containers/proc/standard_feed_mob(')
        self.assertLess(body.index('trans_to_mob'), body.index('overfed.is_overfed()'))
        self.assertIn('target != user', body)

    def test_all_vomiting_purges_the_stomach(self):
        text = HUMAN.read_text(encoding='utf-8')
        throw_up = proc_body(text, '/mob/living/human/proc/throw_up(')
        self.assertIn('ingested.remove_any', throw_up)
        self.assertIn('stomach_holds_poison()', throw_up)
        for name in ('vomit()', 'vomit_blood()'):
            self.assertIn('throw_up(', proc_body(text, '/mob/living/human/proc/' + name))


if __name__ == '__main__':
    unittest.main()
