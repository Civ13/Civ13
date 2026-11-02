"""Offline execution of the selected source setters, not native DM dispatch."""
from pathlib import Path
from types import SimpleNamespace
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import project

ANIMAL = ROOT / 'code/game/mob/living/simple_animal/simple_animal.dm'
RIDING = ROOT / 'code/game/mob/living/simple_animal/riding.dm'


class MutationHooks(unittest.TestCase):
    def setter(self, declaration, argument):
        return project(ANIMAL.read_text(encoding='utf-8'), declaration,
                       'src, ' + argument, {})

    def test_following_change_invalidates_even_when_restored(self):
        set_following = self.setter('/mob/living/simple_animal/proc/npc_set_following', 'new_following')
        old, replacement, pending = object(), object(), object()
        animal = SimpleNamespace(following_mob=old, npc_subtile_pending_intent=pending)
        set_following(animal, old)
        self.assertIs(animal.npc_subtile_pending_intent, pending)
        set_following(animal, replacement)
        self.assertIsNone(animal.npc_subtile_pending_intent)
        self.assertIs(animal.following_mob, replacement)
        set_following(animal, old)
        self.assertIsNone(animal.npc_subtile_pending_intent)
        self.assertIs(animal.following_mob, old)

    def test_pet_target_change_invalidates_only_matching_intent(self):
        cases = (('npc_set_movement_target', 'movement_target', 'towards'),
                 ('npc_set_flee_target', 'flee_target', 'away'))
        for proc, field, mode in cases:
            with self.subTest(proc=proc):
                set_target = self.setter('/mob/living/simple_animal/pet/proc/' + proc, 'new_target')
                old, replacement = object(), object()
                pending = SimpleNamespace(kind='pet', mode=mode)
                pet = SimpleNamespace(**{field: old, 'npc_subtile_pending_intent': pending})
                set_target(pet, old)
                self.assertIs(pet.npc_subtile_pending_intent, pending)
                set_target(pet, replacement)
                self.assertIsNone(pet.npc_subtile_pending_intent)
                set_target(pet, old)
                self.assertIsNone(pet.npc_subtile_pending_intent)
                for other in (SimpleNamespace(kind='follow', mode=None),
                              SimpleNamespace(kind='pet', mode='away' if mode == 'towards' else 'towards')):
                    pet = SimpleNamespace(**{field: old, 'npc_subtile_pending_intent': other})
                    set_target(pet, replacement)
                    self.assertIs(pet.npc_subtile_pending_intent, other)

    def test_common_combat_target_change_invalidates_even_when_restored(self):
        set_target = self.setter('/mob/living/simple_animal/proc/npc_set_combat_target', 'new_target')
        old, replacement, pending = object(), object(), object()
        animal = SimpleNamespace(target_mob=old, npc_subtile_pending_intent=pending)
        set_target(animal, old)
        self.assertIs(animal.npc_subtile_pending_intent, pending)
        set_target(animal, replacement)
        self.assertIsNone(animal.npc_subtile_pending_intent)
        self.assertIs(animal.target_mob, replacement)
        set_target(animal, old)
        self.assertIsNone(animal.npc_subtile_pending_intent)
        self.assertIs(animal.target_mob, old)

    def test_common_wildlife_combat_writers_use_setter(self):
        paths = ('code/game/mob/living/simple_animal/simple_animal.dm',
                 'code/game/mob/living/simple_animal/simple_ai.dm',
                 'code/game/mob/living/simple_animal/hostile/tactical_ai.dm',
                 'code/game/mob/living/simple_animal/friendly/mouse.dm',
                 'code/game/mob/living/simple_animal/hostile/mammoth.dm')
        assignment = re.compile(r'(?<![=!<>])\btarget_mob\s*=(?!=)')
        observed = []
        for name in paths:
            for line in (ROOT / name).read_text(encoding='utf-8').splitlines():
                text = line.split('//', 1)[0].strip()
                if assignment.search(text) and not text.startswith('var/'):
                    observed.append((name, text))
        self.assertEqual(observed, [(ANIMAL.relative_to(ROOT).as_posix(),
                                     'src.target_mob = new_target')])

    def test_direct_assignments_are_limited_to_reviewed_setters(self):
        # Bounded lexical inventory: dynamic vars[], engine deletion and native
        # writes remain outside this source scan and need separate review.
        assignment = re.compile(r'(?<![=!<>])\b(following_mob|movement_target|flee_target)\s*=(?!=)')
        observed = []
        for path in (ROOT / 'code').rglob('*.dm'):
            for line in path.read_text(encoding='utf-8', errors='replace').splitlines():
                text = line.split('//', 1)[0].strip()
                if assignment.search(text) and not text.startswith('var/'):
                    observed.append((path.relative_to(ROOT).as_posix(), text))
        expected_path = ANIMAL.relative_to(ROOT).as_posix()
        self.assertEqual(set(observed), {(expected_path, 'src.following_mob = new_following'),
                                        (expected_path, 'src.movement_target = new_target'),
                                        (expected_path, 'src.flee_target = new_target')})
        self.assertEqual(len(observed), 3)

    def test_completed_riding_transitions_invalidate_pending(self):
        riding = RIDING.read_text(encoding='utf-8')
        mount = riding.split('/mob/living/simple_animal/MouseDrop_T(', 1)[1].split('/mob/living/simple_animal/attack_hand(', 1)[0]
        dismount = riding.split('/mob/living/simple_animal/attack_hand(', 1)[1].split('/mob/living/simple_animal/death()', 1)[0]
        death = riding.split('/mob/living/simple_animal/death()', 1)[1].split('/mob/living/simple_animal/proc/trample(', 1)[0]
        self.assertLess(mount.index('npc_subtile_pending_intent = null'), mount.index('ride = TRUE'))
        self.assertEqual(dismount.count('npc_subtile_pending_intent = null'), 2)
        for section in dismount.split('if (do_after(M, 40, src))')[1:]:
            self.assertLess(section.index('npc_subtile_pending_intent = null'), section.index('ride = FALSE'))
        self.assertLess(death.index('npc_subtile_pending_intent = null'), death.index('ride = FALSE'))
        seam = (ROOT / 'code/game/mob/living/simple_animal/subtile_movement.dm').read_text(encoding='utf-8')
        self.assertIn('!ride && !rider', seam)


if __name__ == '__main__':
    unittest.main()
