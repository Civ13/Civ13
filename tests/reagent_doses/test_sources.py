"""Offline source contract for reagent dose fixes (#6295, #6310, #6312, #6335).

Behaviour is covered natively by tests/reagent_doses/probe.dm.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
REAGENTS = ROOT / 'code/modules/reagents'


def read(rel):
    return (REAGENTS / rel).read_text(encoding='utf-8-sig')


class ReagentDoses(unittest.TestCase):
    def test_overdose_receives_removed(self):
        life = read('Chemistry-Reagents.dm').split('/datum/reagent/proc/on_mob_life(', 1)[1].split('\n/', 1)[0]
        self.assertIn('overdose(M, alien, removed)', life)
        self.assertLess(life.index('removed = min(removed, volume)'), life.index('overdose(M, alien, removed)'))

    def test_cooling_moves_toward_target(self):
        compounds = read('Chemistry-Reagents/Chemistry-Reagents-Compounds.dm')
        self.assertIn('max(targ_temp, M.bodytemperature + (adj_temp * TEMPERATURE_DAMAGE_COEFFICIENT))', compounds)
        self.assertNotIn('min(targ_temp, M.bodytemperature - (adj_temp', compounds)
        drinks = read('Chemistry-Reagents/Chemistry-Reagents-Food-Drinks.dm')
        self.assertNotIn('min(310, M.bodytemperature - (adj_temp', drinks)

    def test_charcoal_budget_is_shared(self):
        medicine = read('Chemistry-Reagents/Chemistry-Reagents-Medicine.dm')
        helper = medicine.split('/proc/charcoal_absorb_poisons(', 1)[1].split('\n/', 1)[0]
        self.assertIn('var/budget = 3 * removed', helper)
        self.assertNotIn('remove_reagent(id, 3 * removed', helper)

    def test_pepper_spray_checks_eye_slot(self):
        drinks = read('Chemistry-Reagents/Chemistry-Reagents-Food-Drinks.dm')
        touch = drinks.split('/datum/reagent/capsaicin/condensed/affect_touch(', 1)[1].split('\n/', 1)[0]
        self.assertIn('list(H.head, H.wear_mask, H.eyes)', touch)


if __name__ == '__main__':
    unittest.main()
