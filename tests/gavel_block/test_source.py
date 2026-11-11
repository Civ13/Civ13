"""Offline source contract for gavel block item interactions (#4515); does not execute DM."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
COURT = ROOT / "code/game/objects/items/courtitems.dm"


def attackby_body(source):
    return source.split('/obj/item/weapon/gavelblock/attackby(', 1)[1].split('\n/', 1)[0]


def project(body, item):
    """Return 'gavel' for the hammer branch, 'parent' if inherited handling runs, else 'ignored'."""
    if item == 'gavelhammer':
        return 'gavel'
    other = body.split('else', 1)[1]
    return 'parent' if 'return ..()' in other else 'ignored'


class GavelBlockSource(unittest.TestCase):
    def setUp(self):
        self.body = attackby_body(COURT.read_text(encoding="utf-8"))

    def test_hammer_strikes_block(self):
        self.assertIn("sound/effects/gavel.ogg", self.body)
        self.assertEqual(project(self.body, 'gavelhammer'), 'gavel')

    def test_other_items_use_inherited_handler(self):
        self.assertEqual(project(self.body, 'storage_bag'), 'parent')
        old = self.body.replace('return ..()', 'return', 1)
        self.assertEqual(project(old, 'storage_bag'), 'ignored')


if __name__ == "__main__":
    unittest.main()
