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
    def test_moving_covers_claim_only_their_own_tile(self):
        source = (ROOT / 'code/game/objects/tile_occupancy.dm').read_text()
        self.assertIn('C.loc == T && C.is_floor_cover() && !QDELETED(C)', source)
        self.assertIn('O.loc == T && O.takes_wall_slot() && !QDELETED(O)', source)

    def test_included(self):
        self.assertIn('#include "code\\game\\objects\\tile_occupancy.dm"', read('civ13.dme'))

    def test_crafting_checks_before_and_after_wait(self):
        stack = read('code/game/objects/items/stacks/stack.dm')
        body = stack[stack.index('/obj/item/stack/proc/produce_recipe('):]
        first = body.index('tile_build_refusal(get_turf(build_loc), recipe.result_type)')
        wait = body.index('if (!do_after(user, buildtime, ship_craft = ship_craft)')
        second = body.index('tile_build_refusal(get_turf(build_loc), recipe.result_type)', first + 1)
        pay = body.index('if (use(required,')
        self.assertLess(first, wait)
        self.assertLess(wait, second)
        self.assertLess(second, pay)

    def test_floor_over_subfloor_keeps_ceiling(self):
        stack = read('code/game/objects/items/stacks/stack.dm')
        body = stack[stack.index('/obj/item/stack/proc/produce_recipe('):]
        subfloor = body.index('tile_subfloor_for(get_turf(build_loc), recipe.result_type)')
        self.assertLess(body.index('if (!do_after(user, buildtime, ship_craft = ship_craft)'), subfloor)
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

    def test_storey_floor_removal_keeps_or_asks(self):
        covers = read('code/game/objects/covers.dm')
        hammer = covers[covers.index('if (is_tool(W, TOOL_HAMMER))'):]
        self.assertLess(hammer.index('building_slab_removal_confirmed(user, src)'), hammer.index('do_after(user, 50, src)'))
        self.assertIn('revert_to_subfloor()', hammer[:hammer.index('qdel(src)')])
        roof = read('code/game/objects/roof_stuff.dm')
        roof_hammer = roof[roof.index('/obj/roof/attackby('):]
        roof_hammer = roof_hammer[roof_hammer.index('is_tool(W, TOOL_HAMMER)'):]
        self.assertLess(roof_hammer.index('building_slab_removal_confirmed(user, src)'), roof_hammer.index('do_after(user, 60, src)'))

    def test_lost_supports_recheck_storeys_above(self):
        for path in ('code/game/objects/covers_types/cover_walltypes.dm', 'code/game/objects/roof_stuff.dm',
                     'code/game/objects/structures/door.dm', 'code/game/objects/building_buttresses.dm',
                     'code/game/turfs/walls.dm', 'code/game/objects/building_levels.dm'):
            self.assertIn('building_recheck_storeys_above(', read(path), path)

    def test_beds_accept_upper_floors(self):
        self.assertIn('if(!tile_has_floor(T) || T.density', read('code/modules/persistence/bed_return.dm'))

    def test_floor_cover_item_one_floor_per_tile(self):
        covers = read('code/game/objects/covers.dm')
        body = covers[covers.index('/obj/item/weapon/covers/attack_self('):]
        body = body[:body.index('/obj/item/weapon/covers/ship/attack_self(')]
        self.assertEqual(body.count('tile_build_refusal(target, /obj/covers/repairedfloor)'), 2)
        self.assertLess(body.rindex('tile_build_refusal(target'), body.index('new(target)'))

    def test_open_air_click_lays_floor_cover(self):
        sky = read('code/modules/multiz/open_space.dm')
        body = sky[sky.index('/turf/sky/attackby('):]
        self.assertIn('istype(W, /obj/item/weapon/covers)', body)
        self.assertIn('W.attack_self(user)', body)

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
