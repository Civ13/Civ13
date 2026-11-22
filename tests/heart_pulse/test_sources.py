"""Offline source contract for heart pulse updates (#6228, #6229).

Behaviour is covered natively by tests/heart_pulse/probe.dm.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
HEART = (ROOT / 'code/modules/organs/internal/heart.dm').read_text(encoding='utf-8-sig')
PULSE = HEART.split('/obj/item/organ/heart/proc/handle_pulse()\n', 1)[1].split('\n/', 1)[0]


class HeartPulse(unittest.TestCase):
    def test_blood_loss_uses_percentage(self):
        self.assertIn('owner.get_blood_volume() <= BLOOD_VOLUME_BAD', PULSE)
        self.assertNotIn('vessel.get_reagent_amount("blood")) <= BLOOD_VOLUME_BAD', PULSE)

    def test_clamp_only_with_pulse_drug(self):
        self.assertIn('var/chem_pulse = owner.chem_effects[CE_PULSE]', PULSE)
        guard = PULSE.index('if (chem_pulse)')
        clamp = PULSE.index('pulse = Clamp(pulse + chem_pulse, PULSE_SLOW, PULSE_2FAST)')
        self.assertLess(guard, clamp)
        self.assertEqual(PULSE.count('Clamp('), 1)


if __name__ == '__main__':
    unittest.main()
