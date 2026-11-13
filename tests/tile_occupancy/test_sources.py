"""One floor and one wall per tile: offline seam checks.

The native probe (probe.dm, run.py) builds through the real crafting path and
the brick, dirt and snow foundations. These checks keep every build path wired
to the shared refusal in code/game/objects/tile_occupancy.dm.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


class TileOccupancySources(unittest.TestCase):
    def test_included(self):
        self.assertIn('#include "code\\game\\objects\\tile_occupancy.dm"', read('civ13.dme'))

    def test_crafting_checks_before_and_after_wait(self):
        stack = read('code/game/objects/items/stacks/stack.dm')
        body = stack[stack.index('/obj/item/stack/proc/produce_recipe('):]
        first = body.index('tile_build_refusal(get_turf(user), recipe.result_type)')
        wait = body.index('if (!do_after(user, buildtime)')
        second = body.index('tile_build_refusal(get_turf(user), recipe.result_type)', first + 1)
        pay = body.index('if (use(required,')
        self.assertLess(first, wait)
        self.assertLess(wait, second)
        self.assertLess(second, pay)

    def test_wall_foundations_checked(self):
        for path, count in (('code/game/objects/items/clay_items.dm', 7),
                            ('code/modules/1713/barriers/sandbag.dm', 2),
                            ('code/modules/1713/barriers/snow_walls.dm', 2)):
            self.assertEqual(read(path).count('wall_foundation_tile_free(user,'), count, path)

    def test_hole_covers_checked(self):
        for path in ('code/game/objects/covers.dm', 'code/modules/multiz/open_space.dm'):
            text = read(path)
            self.assertLess(text.index('tile_build_refusal(get_step(user, user.dir)'),
                            text.index('(get_step(user, user.dir), user)'), path)


if __name__ == '__main__':
    unittest.main()
