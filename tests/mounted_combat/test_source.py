"""Mounted charges, braced spears and shield walls: source contracts. Behaviour is in probe.dm:

    python3 tests/mounted_combat/test_source.py
    python3 tests/ecology_spawning/run_linux.py . tests/mounted_combat/probe.dm
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = (ROOT / 'code/modules/1713/mounted_combat.dm').read_text(encoding='utf-8')


class MountedCombatSource(unittest.TestCase):
    def test_ridden_steps_feed_the_charge(self):
        move = (ROOT / 'code/game/mob/mob_movement.dm').read_text(encoding='utf-8')
        self.assertIn('hoof_dust(H.riding_mob, ride_from)\n\t\t\t\tH.ride_charge_step(ride_from)', move)

    def test_shield_wall_reaches_melee_and_arrows(self):
        shields = (ROOT / 'code/game/objects/items/weapons/shields.dm').read_text(encoding='utf-8')
        defense = (ROOT / 'code/game/mob/living/carbon/human/human_defense.dm').read_text(encoding='utf-8')
        self.assertIn('return base_block_chance + shield_wall_bonus(user)', shields)
        self.assertEqual(defense.count('prob(min(SH.get_block_chance(src),92))'), 2)
        self.assertNotIn('SH.base_block_chance', defense)

    def test_shield_wall_checks_the_flanks_of_any_facing(self):
        # Issue 6921: a diagonal facing has diagonal flanks, not cardinal ones.
        self.assertIn('for (var/d in list(turn(user.dir, 90), turn(user.dir, -90)))', SRC)
        self.assertNotIn('for (var/d in cardinal)', SRC.split('proc/shield_wall_bonus', 1)[1])

    def test_charge_state_is_not_saved(self):
        self.assertIn('"charge_steps", "charge_dir", "charge_last", "braced_until", "braced_at"', SRC)

    def test_included(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertIn('#include "code\\modules\\1713\\mounted_combat.dm"', dme)


if __name__ == '__main__':
    unittest.main()
