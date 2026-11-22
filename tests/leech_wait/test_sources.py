"""Leech treatment waits on the patient (issue #6818).

Behaviour is covered natively (a still patient is leeched; a patient who
walks away keeps their blood and the leech stays empty):

    python3 tests/ecology_spawning/run_linux.py . tests/leech_wait/probe.dm
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/game/mob/living/simple_animal/friendly/leech.dm').read_text(encoding='utf-8')


class LeechWait(unittest.TestCase):
    def test_waits_on_patient_and_rechecks_reach(self):
        body = SOURCE.split('/obj/item/weapon/leech/attack(', 1)[1].split('\n/', 1)[0]
        self.assertIn('do_after(user,150,C)', body)
        self.assertNotIn('do_after(user,150,src)', body)
        gate = body.index('do_after(user,150,C)')
        self.assertLess(gate, body.index('user.Adjacent(C)'))
        self.assertLess(body.index('user.Adjacent(C)'), body.index('remove_reagent("blood"'))

    def test_only_humans_with_blood(self):
        body = SOURCE.split('/obj/item/weapon/leech/attack(', 1)[1].split('\n/', 1)[0]
        self.assertLess(body.index('if (!istype(C) || !C.vessel)'), body.index('do_after('))


if __name__ == '__main__':
    unittest.main()
