"""Offline source contract for per-limb radiation armor (#6276).

Behaviour is covered natively by tests/radiation_armor/probe.dm.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/1713/radiation.dm').read_text(encoding='utf-8-sig')
RAD_ACT = SOURCE.split('/mob/living/human/rad_act(amount)\n', 1)[1].split('\n/', 1)[0]


class RadiationArmor(unittest.TestCase):
    def test_armor_uses_the_organ_not_its_display_name(self):
        loop = RAD_ACT.split('for (var/obj/item/organ/external/sorgan in organs)', 1)[1].split('for(var/obj/I in src)', 1)[0]
        self.assertIn('getarmor_organ(sorgan, "rad")', loop)
        self.assertNotIn('sorgan.name', loop)


if __name__ == '__main__':
    unittest.main()
