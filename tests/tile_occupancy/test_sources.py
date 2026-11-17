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
        first = body.index('tile_build_refusal(get_turf(build_loc), recipe.result_type)')
        wait = body.index('if (!do_after(user, buildtime)')
        second = body.index('tile_build_refusal(get_turf(build_loc), recipe.result_type)', first + 1)
        pay = body.index('if (use(required,')
        self.assertLess(first, wait)
        self.assertLess(wait, second)
        self.assertLess(second, pay)

    def test_floor_over_subfloor_keeps_ceiling(self):
        stack = read('code/game/objects/items/stacks/stack.dm')
        body = stack[stack.index('/obj/item/stack/proc/produce_recipe('):]
        subfloor = body.index('tile_subfloor_for(get_turf(build_loc), recipe.result_type)')
        self.assertLess(body.index('if (!do_after(user, buildtime)'), subfloor)
        self.assertLess(subfloor, body.index('building_floor_error(get_turf(build_loc))'))
        self.assertIn('floor.replace_subfloor(subfloor)', body)
        rule = read('code/game/objects/tile_occupancy.dm')
        replace = rule[rule.index('/obj/covers/proc/replace_subfloor('):]
        self.assertLess(replace.index('building_pair_id = old.building_pair_id'), replace.index('qdel(old)'))

    def test_on_floor_recipes_accept_upper_storey_floors(self):
        stack = read('code/game/objects/items/stacks/stack.dm')
        body = stack[stack.index('/obj/item/stack/proc/produce_recipe('):]
        self.assertIn('recipe.on_floor && !tile_has_floor(get_turf(user))', body)
        self.assertNotIn('isfloor(user.loc)', body)
        rule = read('code/game/objects/tile_occupancy.dm')
        self.assertIn('return isfloor(T) || tile_floor_cover(T)', rule)

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
