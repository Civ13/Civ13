"""Offline source contract for salting container restore (#6446).

Behaviour is covered natively by tests/salting_restore/probe.dm.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/1713/complex_production.dm').read_text(encoding='utf-8-sig')


class SaltingRestore(unittest.TestCase):
    def test_after_load_restarts_a_running_batch(self):
        hook = SOURCE.split('/obj/structure/salting_container/after_load()', 1)[1].split('\n/', 1)[0]
        self.assertIn('..()', hook)
        self.assertIn('if (salting)', hook)
        self.assertIn('salting()', hook.split('if (salting)', 1)[1])


if __name__ == '__main__':
    unittest.main()
