"""Offline source controls; these are not a native Bump fixture."""
import unittest
from pathlib import Path

import build_guard


class CandidateControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = build_guard.build(build_guard.OLD.read_bytes(),
                                       build_guard.WALKER.read_bytes(),
                                       build_guard.TACTICAL.read_bytes()).decode()

    def test_all_seven_experimental_owner_slots_are_checked(self):
        section = self.source.split('/mob/living/proc/human_animal_ordinary_bump_owned', 1)[1].split('/mob/living/Bump', 1)[0]
        for name in ('pursuit', 'follow', 'flee', 'pet_walk', 'recovery', 'pending_intent', 'wild_walk'):
            with self.subTest(name=name):
                self.assertIn('A.npc_subtile_' + name, section)
        self.assertIn('H.human_subtile_transaction', section)
        self.assertIn('H.human_subtile_offset_owned', section)
        self.assertIn('subtile_pull_ownership.owners[A]', section)

    def test_horses_excluded_in_both_mover_directions(self):
        section = self.source.split('/mob/living/proc/human_animal_ordinary_bump(', 1)[1].split('/mob/living/proc/human_animal_ordinary_bump_owned', 1)[0]
        self.assertIn('!istype(other, /mob/living/simple_animal/horse)', section)
        self.assertIn('!istype(src, /mob/living/simple_animal/horse)', section)
        for token in ('H.riding', 'H.riding_mob', 'H.buckled', 'A.ride', 'A.rider', 'A.buckled',
                      'H.pulling', 'A.pulledby', 'H.grab_list', 'A.grabbed_by'):
            self.assertIn(token, section)

    def test_both_swap_legs_are_inside_the_single_guard(self):
        guard = 'if (!(human_animal_ordinary_bump(tmob) && (ordinary_owned_at_impact || human_animal_ordinary_bump_owned(tmob))))'
        self.assertEqual(self.source.count(guard), 2)
        for line in self.source.split(guard)[1:]:
            following = line.splitlines()[1:3]
            self.assertEqual([s.strip() for s in following], ['forceMove(tmob.loc)', 'tmob.forceMove(oldloc)'])

    def test_bad_source_rejected_not_silently_adapted(self):
        old, walker, tactical = (p.read_bytes() for p in (build_guard.OLD, build_guard.WALKER, build_guard.TACTICAL))
        for i in range(3):
            args = [old, walker, tactical]
            args[i] += b'\n//changed\n'
            with self.subTest(input=i), self.assertRaises(ValueError):
                build_guard.build(*args)

    def test_known_interleg_race_is_not_claimed_fixed(self):
        # The candidate deliberately checks once before the first leg. This
        # source check documents the known lack of atomicity; it is not a pass
        # for a reentrant movement scenario.
        for part in self.source.split('forceMove(tmob.loc)')[1:]:
            before_second = part.split('tmob.forceMove(oldloc)', 1)[0]
            self.assertNotIn('human_animal_ordinary_bump_owned', before_second)


if __name__ == '__main__':
    unittest.main()
