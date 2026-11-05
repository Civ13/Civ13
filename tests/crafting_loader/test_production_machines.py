"""Factionless players can build the bakelizer once their era reaches WW1. Source text only.

The bakelizer is the only way to turn crude petroleum into plastic. It sat under the
specialist Tailoring tree (Synthetic Fabrics), which factionless players can never
research and which no era grants, so it vanished from the steel Production menu.
"""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_basic_clothing import factionless_recipes, research  # noqa: E402

BAKELIZER = '/obj/structure/bakelizer'


class FactionlessProductionMachines(unittest.TestCase):
    def test_bakelizer_is_on_a_main_tree_node(self):
        nodes, requirements = research()
        node = requirements[BAKELIZER]
        self.assertEqual(nodes[node][1], 'Main')
        self.assertEqual(requirements['/obj/structure/refinery'], node)

    def test_factionless_can_build_bakelizer_from_ww1(self):
        nodes, requirements = research()
        for era in range(5, 9):
            self.assertIn(BAKELIZER, factionless_recipes(era, nodes, requirements), era)


if __name__ == '__main__':
    unittest.main()
