"""Source contracts for modern bridges. Never launches BYOND."""
from pathlib import Path
import glob
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import run  # noqa: E402

BRIDGES = (ROOT / 'code/modules/1713/bridges.dm').read_text(encoding='utf-8')


class ModernBridgeSourceTests(unittest.TestCase):
    def test_included_once(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertEqual(dme.count('#include "code\\modules\\1713\\bridges.dm"'), 1)

    def test_spans_are_crafted_wherever_steel_floors_are(self):
        for path in glob.glob(str(ROOT / 'config/crafting/material_recipes_*.txt')):
            text = Path(path).read_text(encoding='utf-8')
            if ',/obj/covers/steelplating,' in text:
                self.assertIn('RECIPE: /material/steel/,steel bridge span,/obj/item/weapon/bridge_span,', text, path)
            if ',/obj/covers/concretefloor,' in text:
                self.assertIn('RECIPE: /material/clay/,concrete bridge span,/obj/item/weapon/bridge_span/concrete,', text, path)

    def test_spans_need_industrial_research(self):
        nodes = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        for path in ('/obj/item/weapon/bridge_span', '/obj/item/weapon/bridge_span/concrete'):
            self.assertIn('"%s" = "reinforced_concrete"' % path, nodes)

    def test_decks_are_not_sinking_repaired_floors(self):
        # /obj/covers/repairedfloor sinks on saltwater; a bridge deck must not.
        self.assertIn('\n/obj/covers/bridge\n', BRIDGES)
        self.assertNotIn('/obj/covers/repairedfloor', BRIDGES)

    def test_crafting_allowed_while_standing_on_a_deck(self):
        stack = (ROOT / 'code/game/objects/items/stacks/stack.dm').read_text(encoding='utf-8')
        self.assertIn('istype(get_turf(H), /turf/floor/beach/water/deep) && !bridge_deck_at(get_turf(H))', stack)

    def test_native_fixture_preparation(self):
        generated = run.sources()
        self.assertIn('#include "tests/modern_bridges/probe.dm"', generated[run.PREFIX + '.dme'])
        self.assertNotRegex(generated[run.PREFIX + '.dme'], r'(?m)^#include ".*\.dmm"')


if __name__ == '__main__':
    unittest.main()
