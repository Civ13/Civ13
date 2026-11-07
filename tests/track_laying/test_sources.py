"""Source contracts for laying track by hand. Never launches BYOND."""
from pathlib import Path
import glob
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import run  # noqa: E402

LAYING = (ROOT / 'code/modules/1713/track_laying.dm').read_text(encoding='utf-8')


class TrackLayingSourceTests(unittest.TestCase):
    def test_included_once(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertEqual(dme.count('#include "code\\modules\\1713\\track_laying.dm"'), 1)

    def test_track_is_laid_from_parts_not_crafted_whole(self):
        for path in glob.glob(str(ROOT / 'config/crafting/material_recipes_*.txt')):
            text = Path(path).read_text(encoding='utf-8')
            for old in ('/obj/structure/rails/regular,', '/obj/structure/rails/regular/horizontal,', '/obj/structure/rails/turn,'):
                self.assertNotIn(old, text, path)
            if 'trains,93' in text:
                self.assertRegex(text, r'(?m)^RECIPE: /material/iron/,rails,/obj/item/stack/rail_lengths,', path)
                self.assertRegex(text, r'(?m)^RECIPE: /material/wood/,railway sleepers,/obj/item/stack/rail_sleepers,', path)

    def test_parts_need_the_rail_research(self):
        nodes = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        for path in ('/obj/item/stack/rail_lengths', '/obj/item/stack/rail_sleepers'):
            self.assertIn('"%s" = "rail_steam"' % path, nodes)
        self.assertNotIn('"/obj/structure/rails/regular" = "rail_steam"', nodes)

    def test_unfinished_track_is_not_rail(self):
        # Trains, stations and the rail network look for /obj/structure/rails.
        self.assertIn('\n/obj/structure/rail_bed\n', LAYING)
        self.assertNotRegex(LAYING, r'(?m)^/obj/structure/rails/rail_bed')

    def test_hammer_no_longer_turns_rails_into_wood(self):
        body = LAYING[LAYING.index('/obj/structure/rails/attackby('):]
        hammer = body.index('istype(W, /obj/item/weapon/hammer)')
        self.assertLess(hammer, body.index('return ..()'))

    def test_native_fixture_preparation(self):
        generated = run.sources()
        self.assertIn('#include "tests/track_laying/probe.dm"', generated[run.PREFIX + '.dme'])
        self.assertNotRegex(generated[run.PREFIX + '.dme'], r'(?m)^#include ".*\.dmm"')


if __name__ == '__main__':
    unittest.main()
