"""Offline source contract for the flashlight eye exam (#6253).

Behaviour is covered natively by tests/flashlight_eyes/probe.dm.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/game/objects/items/devices/flashlight.dm').read_text(encoding='utf-8-sig')
ATTACK = SOURCE.split('/obj/item/flashlight/attack(mob/living/human/M as mob, mob/user as mob)\n', 1)[1].split('\n/', 1)[0]


class FlashlightEyes(unittest.TestCase):
    def test_findings_are_for_another_patient(self):
        self.assertIn('if (H != user)', ATTACK)
        self.assertNotIn('if (H == user)', ATTACK)

    def test_missing_eyes_stop_before_damage_is_read(self):
        missing = ATTACK.index("You can't find any")
        stop = ATTACK.index('return', missing)
        self.assertLess(stop, ATTACK.index('vision.damage'))
        self.assertLess(stop, ATTACK.index('directs [src]'))


if __name__ == '__main__':
    unittest.main()
