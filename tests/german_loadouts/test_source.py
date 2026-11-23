"""Source checks for issues 6988 and 6989: the German Jarl and spearman keep their whole loadout.
Native probe: python3 tests/ecology_spawning/run_linux.py . tests/german_loadouts/probe.dm
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ANCIENT = ROOT / 'code/modules/1713/jobs/ancient.dm'


def job_body(text, path):
    start = text.index(path + '/equip(')
    return text[start:text.index('\n/datum/', start + 1)]


class GermanLoadoutTest(unittest.TestCase):
    def setUp(self):
        self.text = ANCIENT.read_text(encoding='utf-8')

    def test_jarl_holds_scutum(self):
        body = job_body(self.text, '/datum/job/german/chieftain')
        self.assertIn('new /obj/item/weapon/shield/scutum(H), slot_r_hand', body)
        self.assertNotIn('scutum(H), slot_r_store', body)

    def test_spearman_shoulders_spare_pike(self):
        body = job_body(self.text, '/datum/job/german/spearman')
        self.assertIn('new /obj/item/weapon/material/spear/sarissa/pike(H), slot_shoulder', body)
        self.assertNotIn('pike(H), slot_belt', body)


if __name__ == '__main__':
    unittest.main()
