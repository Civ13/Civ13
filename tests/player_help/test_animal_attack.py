"""Offline contracts for animal audit logging and observed injury hooks.

These inspect production DM; they do not substitute for native combat execution.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class AnimalAttackContracts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = (ROOT / 'code/game/mob/living/simple_animal/hostile/tactical_ai.dm').read_text()
        cls.attack = source.split('/mob/living/simple_animal/proc/AttackingTarget()', 1)[1].split(
            '/mob/living/simple_animal/proc/LoseTarget()', 1)[0]

    def test_alligator_uses_direct_attack_and_audits_both_participants(self):
        alligator = (ROOT / 'code/game/mob/living/simple_animal/hostile/alligator.dm').read_text()
        self.assertIn('can_bite_limbs_off = TRUE', alligator)
        self.assertNotIn('/AttackingTarget', alligator)
        self.assertEqual(self.attack.count('append_attack_log('), 2)
        self.assertIn('target_mob.append_attack_log(', self.attack)
        self.assertLess(self.attack.index('if (!Adjacent(target_mob))'), self.attack.index('append_attack_log('))
        self.assertLess(self.attack.index('append_attack_log('), self.attack.index('H.apply_damage('))
        # Calling attack_generic too would change armor, random targeting and damage.
        self.assertNotIn('.attack_generic(', self.attack)
        self.assertEqual(self.attack.count('H.apply_damage('), 1)
        self.assertEqual(self.attack.count('affecting.droplimb('), 1)

    def test_injury_requires_real_damage_or_attachment_transition(self):
        self.assertIn('var/attached_before = affecting && affecting.owner == H', self.attack)
        self.assertIn('var/lost_limb = attached_before && (!affecting || affecting.owner != H)', self.attack)
        self.assertIn('(lost_limb || H.getBruteLoss() + H.getBurnLoss() > previous_damage)', self.attack)
        self.assertLess(self.attack.index('affecting.droplimb('), self.attack.index('var/lost_limb'))
        self.assertEqual(self.attack.count('record_animal_injury('), 1)
        self.assertIn('record_animal_injury(observing_client, H, src, injury_limb, lost_limb)', self.attack)
        self.assertIn('affecting ? affecting.limb_name : null', self.attack)
        # droplimb can refuse cannot_amputate, and intentionally returns no boolean.
        organs = (ROOT / 'code/modules/organs/organ_external.dm').read_text()
        self.assertIn('if (cannot_amputate || !owner)', organs)
        self.assertIn('victim.organs_by_name[limb_name] = null', organs)

    def test_pre_hit_visibility_and_awareness_not_post_hit_consciousness(self):
        observed = self.attack.split('var/observed_attack = ', 1)[1].split('\n', 1)[0]
        for guard in ('observing_client.mob == H', 'observing_client.eye == H', 'H.stat == CONSCIOUS', 'H.sleeping <= 0',
                      '!H.blinded', '!H.eye_blind', 'H.sdisabilities & BLIND',
                      '!H.find_trait("Blind")', '!H.paralysis',
                      'H.see_invisible >= invisibility', 'src in view(H)'):
            self.assertIn(guard, observed)
        self.assertLess(self.attack.index('var/observed_attack'), self.attack.index('H.apply_damage('))
        post_hit = self.attack.split('var/lost_limb', 1)[1]
        self.assertNotIn('H.stat', post_hit)
        self.assertNotIn('H.sleeping', post_hit)
        self.assertIn('if (observed_attack && player_help_service', post_hit)

    def test_legacy_damage_choices_remain_unchanged(self):
        for operation in ('var/damage = pick(melee_damage_lower, melee_damage_upper)',
                          'if (prob(95) || !can_bite_limbs_off)',
                          'H.apply_damage(damage, BRUTE, affecting, H.run_armor_check(affecting, "melee"), sharp=1, edge=1)',
                          'affecting.droplimb(FALSE, DROPLIMB_EDGE)',
                          'L.adjustBruteLoss(damage)', 'NB.mood -= 10'):
            self.assertEqual(self.attack.count(operation), 1)


if __name__ == '__main__':
    unittest.main()
