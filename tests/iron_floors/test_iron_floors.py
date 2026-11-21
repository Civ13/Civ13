"""Offline checks: iron plate and grating floors are buildable, gated and drawn."""
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/art_ports'))
from pocket_stronghold_food import state_names  # noqa: E402

SOURCE = (ROOT / 'code/modules/1713/iron_floors.dm').read_text(encoding='utf-8')
RECIPES = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
NODES = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
FLOORS = {'/obj/covers/iron_plate': 'iron_plate', '/obj/covers/iron_grating': 'iron_grating'}


def body(head):
    match = re.search(r'^' + re.escape(head) + r'\n((?:^[ \t].*\n)+)', SOURCE, re.M)
    assert match, head
    return match[1]


class IronFloorTest(unittest.TestCase):
    def test_floors_are_iron_recipes_behind_iron_smithing(self):
        for path in FLOORS:
            with self.subTest(path=path):
                rows = [r for r in RECIPES.splitlines() if r.startswith('RECIPE: ') and r.split(',')[2] == path]
                self.assertEqual(len(rows), 1)
                self.assertTrue(rows[0].startswith('RECIPE: /material/iron/,'))
                self.assertIn(f'"{path}" = "iron_smithing"', NODES)

    def test_floors_are_fireproof_walkable_iron(self):
        for path, state in FLOORS.items():
            with self.subTest(path=path):
                text = body(path)
                for line in (f'icon_state = "{state}"', 'flammable = FALSE', 'wood = FALSE', 'layer = 1.99',
                             'material = "Iron"', 'buildstack = /obj/item/stack/material/iron', 'amount = 0'):
                    self.assertIn(line, text)
                self.assertNotRegex(text, r'\bdensity\s*=')

    def test_grating_drains_only_loose_muck_under_a_footstep(self):
        crossed = body('/obj/covers/iron_grating/Crossed(atom/movable/AM)')
        self.assertLess(crossed.index('isliving(AM)'), crossed.index('drain_muck()'))
        self.assertIn('return ..()', crossed)
        keeps = body('/obj/covers/iron_grating/proc/drains(obj/effect/decal/cleanable/C)')
        for kept in ('blood/gibs', 'blood/writing', 'cleanable/cobweb', 'cleanable/molten_item'):
            self.assertIn(kept, keeps)
        drain = body('/obj/covers/iron_grating/proc/drain_muck()')
        self.assertIn('for (var/obj/effect/decal/cleanable/C in loc)', drain)
        self.assertNotIn('/obj/covers/iron_plate/Crossed', SOURCE)

    def test_art_and_include_exist(self):
        states = state_names(ROOT / 'icons/turf/flooring/iron.dmi')
        for state in FLOORS.values():
            self.assertIn(state, states)
        self.assertIn('#include "code\\modules\\1713\\iron_floors.dm"', (ROOT / 'civ13.dme').read_text())


if __name__ == '__main__':
    unittest.main()
