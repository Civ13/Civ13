"""Offline source contract for explosive activation (#6298, #6337).

Behaviour is covered natively by tests/explosive_activation/probe.dm.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/game/objects/items/weapons/grenades/grenade.dm').read_text(encoding='utf-8-sig')


def body(header):
    return SOURCE.split(header, 1)[1].split('\n/', 1)[0]


class ExplosiveActivation(unittest.TestCase):
    def test_empty_dynamite_does_not_activate(self):
        activate = body('/obj/item/weapon/grenade/dynamite/activate(')
        self.assertIn('if (state < 1)', activate)
        self.assertLess(activate.index('if (state < 1)'), activate.index('active = TRUE'))

    def test_armed_impact_grenade_detonates_once(self):
        ex_act = body('/obj/item/weapon/grenade/modern/impact/ex_act(')
        self.assertIn('impact_detonate()', ex_act)
        detonate = body('/obj/item/weapon/grenade/modern/impact/proc/impact_detonate(')
        self.assertLess(detonate.index('detonated = TRUE'), detonate.index('prime()'))
        for header in ('/obj/item/weapon/grenade/modern/impact/throw_impact(',
                       '/obj/item/weapon/grenade/modern/impact/oto35/throw_impact('):
            self.assertIn('impact_detonate()', body(header))
            self.assertNotIn('prime()', body(header))


if __name__ == '__main__':
    unittest.main()
