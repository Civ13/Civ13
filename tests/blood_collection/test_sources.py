"""Offline source contract for blood collection (#6239).

Behaviour is covered natively by tests/blood_collection/probe.dm.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
BLOOD = (ROOT / 'code/modules/organs/blood.dm').read_text(encoding='utf-8-sig')
IV = (ROOT / 'code/game/objects/structures/iv_drip.dm').read_text(encoding='utf-8-sig')


def body(source, header):
    return source.split(header + '\n', 1)[1].split('\n/', 1)[0]


class BloodCollection(unittest.TestCase):
    def test_other_donor_refused_before_relabel(self):
        take = body(BLOOD, '/mob/living/human/proc/take_blood(obj/item/weapon/reagent_containers/container, var/amount)')
        guard = take.index('if (B && (!B.data || B.data["donor"] != src))')
        self.assertLess(guard, take.index('B.volume += amount'))
        self.assertLess(guard, take.index('B.data["blood_type"] ='))

    def test_refused_collection_takes_no_blood(self):
        take = body(BLOOD, '/mob/living/human/take_blood(obj/item/weapon/reagent_containers/container, var/amount)')
        self.assertIn('if (.)\n\t\tvessel.remove_reagent("blood",amount)', take)

    def test_iv_drip_handles_refusal(self):
        refused = IV.split("else if (prob(5))", 1)[1]
        self.assertLess(refused.index('if (held && (!held.data || held.data["donor"] != T))'),
                        refused.index("holds someone else's blood"))


if __name__ == '__main__':
    unittest.main()
