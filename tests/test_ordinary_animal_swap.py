"""Offline source and behavioral contracts for the ordinary animal swap veto."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'code/game/mob/living/living.dm'


def veto(source, target, *, help_intent=True, restrained=False, horse=False,
         rider=False, throwing=False, leaping=False, pulling=False, grabbed=False):
    # Independent externally visible behavior model; does not execute DM.
    pair = (source, target) in {('human', 'animal'), ('animal', 'human')}
    return pair and help_intent and not any((restrained, horse, rider, throwing,
                                              leaping, pulling, grabbed))


class OrdinaryAnimalSwapTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = SOURCE.read_text(encoding='utf-8')
        cls.helper = cls.source.partition('/mob/living/proc/ordinary_human_animal_swap')[2].split('/mob/living/Bump', 1)[0]
        cls.bump = cls.source.split('/mob/living/Bump', 1)[1].split('/proc/swap_density_check', 1)[0]

    def test_idle_and_owned_pairs_are_both_vetoed_in_both_directions(self):
        for pair in (('human', 'animal'), ('animal', 'human')):
            with self.subTest(pair=pair):
                self.assertTrue(veto(*pair))
                # No ownership condition exists: idle and owned follow the same veto.
                self.assertNotIn('subtile', self.helper)

    def test_veto_precedes_both_legacy_legs_and_clears_guard(self):
        block = self.bump.split('if (can_swap_with(tmob))', 1)[1]
        expected = '\n\t\t\t\tif (ordinary_human_animal_swap(tmob))\n\t\t\t\t\tnow_pushing = FALSE\n\t\t\t\t\treturn\n'
        self.assertTrue(block.startswith(' // mutual brohugs all around!'+expected))
        self.assertLess(block.index('ordinary_human_animal_swap(tmob)'), block.index('forceMove(tmob.loc)'))
        self.assertLess(block.index('ordinary_human_animal_swap(tmob)'), block.index('tmob.forceMove(oldloc)'))
        self.assertNotIn('forceMove', self.helper)

    def test_only_human_nonhorse_animal_pairs(self):
        self.assertFalse(veto('human', 'human'))
        self.assertFalse(veto('animal', 'animal'))
        self.assertFalse(veto('human', 'animal', horse=True))
        self.assertIn('istype(A, /mob/living/simple_animal/horse)', self.helper)
        self.assertIn('ishuman(src) && istype(other, /mob/living/simple_animal)', self.helper)
        self.assertIn('istype(src, /mob/living/simple_animal) && ishuman(other)', self.helper)

    def test_riders_and_both_animal_mount_fields_are_excluded(self):
        self.assertFalse(veto('human', 'animal', rider=True))
        for field in ('H.riding', 'H.riding_mob', 'A.ride', 'A.rider'):
            self.assertIn(field, self.helper)
        self.assertIn('if (H.riding)', self.bump)
        self.assertIn('else if (istype(src, /mob/living/simple_animal/horse))', self.bump)

    def test_linked_grab_and_pull_states_are_excluded_for_both(self):
        for state in ('pulling', 'grabbed'):
            self.assertFalse(veto('animal', 'human', **{state: True}))
        for actor in ('H', 'A'):
            for field in ('pulling', 'pulledby', 'grab_list', 'grabbed_by'):
                self.assertIn(actor+'.'+field, self.helper)

    def test_nonhelp_restrained_thrown_and_leaping_are_excluded(self):
        for kw in ({'help_intent': False}, {'restrained': True}, {'throwing': True}, {'leaping': True}):
            self.assertFalse(veto('human', 'animal', **kw))
        for part in ('a_intent != I_HELP', 'restrained()', 'other.restrained()',
                     'H.throwing', 'A.throwing', 'H.status_flags & LEAPING', 'A.status_flags & LEAPING'):
            self.assertIn(part, self.helper)
        self.assertLess(self.bump.index('if (status_flags & LEAPING)'), self.bump.index('if (can_swap_with(tmob))'))

    def test_existing_non_swap_and_generic_push_remain(self):
        self.assertIn('if (!can_move_mob(tmob, FALSE, FALSE))', self.bump)
        self.assertIn('step(AM, t)', self.bump)
        self.assertIn('G.adjust_position()', self.bump)
        self.assertEqual(self.bump.count('\n\t\t\t..()'), 1)

    def test_registry_keeps_shared_source_fallback(self):
        registry = (ROOT / 'scripts/ci_baseline.py').read_text(encoding='utf-8')
        entry = "'ordinary_animal_swap': {'files': ('tests/test_ordinary_animal_swap.py',)"
        self.assertIn(entry, registry)
        self.assertIn("'paths': (), 'shared_paths': ('code/game/mob/living/living.dm',)", registry)


if __name__ == '__main__':
    unittest.main()
