"""Offline wiring checks for underground excavation (no compiler or game).

The native probe (probe.dm) covers the dug-out yields; these check that every
tunnel shaft route leaves its dirt and that the shovel override loads after
the base cave-rock attackby it extends.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


class Wiring(unittest.TestCase):
    def test_every_tunnel_shaft_leaves_dirt(self):
        tools = read('code/modules/1713/tools.dm')
        dug = read('code/modules/multiz/dug_underground.dm')
        # Shovel dig down and dig up on native levels, then the dug cave level.
        self.assertEqual(tools.count('excavation_shaft_spoil(user)'), 2)
        self.assertEqual(dug.count('excavation_shaft_spoil(user)'), 2)
        for text in (tools, dug):
            for match in re.finditer(r'excavation_shaft_spoil\(user\)', text):
                before = text[:match.start()].rsplit('\n', 2)[-2]
                self.assertIn('finish', before, 'spoil follows a finished shaft message')

    def test_override_loads_after_base_attackby(self):
        dme = read('civ13.dme').splitlines()
        base = dme.index('#include "code\\game\\turfs\\flooring\\flooring_premade.dm"')
        trench = dme.index('#include "code\\modules\\1713\\trench.dm"')
        mine = dme.index('#include "code\\modules\\1713\\underground_excavation.dm"')
        self.assertGreater(mine, base)
        self.assertGreater(mine, trench)
        module = read('code/modules/1713/underground_excavation.dm')
        self.assertIn('/turf/floor/dirt/underground/attackby(obj/item/C, mob/user)', module)
        self.assertIn('return ..()', module)


if __name__ == '__main__':
    unittest.main()
