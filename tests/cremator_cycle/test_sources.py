"""Offline source contract for the cremator cycle (#6273).

Behaviour is covered natively by tests/cremator_cycle/probe.dm.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/game/objects/structures/morgue.dm').read_text(encoding='utf-8-sig')
CREMATE = SOURCE.split('/obj/structure/cremator/proc/cremate(', 1)[1].split('\n/', 1)[0]


class CrematorCycle(unittest.TestCase):
    def test_only_the_end_of_the_cycle_clears_running(self):
        clears = [line.strip() for line in CREMATE.splitlines()
                  if line.strip().startswith('cremating =') and not line.strip().endswith('TRUE')]
        self.assertEqual(clears, ['cremating = FALSE'])
        self.assertGreater(CREMATE.index('cremating = FALSE'), CREMATE.index('new /obj/effect/decal/cleanable/ash'))


if __name__ == '__main__':
    unittest.main()
