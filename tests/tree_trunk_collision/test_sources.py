"""Trees block only around the trunk drawn at their pixel offset.

The native probe (probe.dm, run.py) checks the behaviour in a real build: a
free-moving body walks up to the trunk, beside it and through the rest of the
tree's tile, while whole-tile movers still find the tile blocked. These checks
keep the seams in place.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
WILD = (ROOT / 'code/game/objects/structures/wild.dm').read_text(encoding='utf-8')
TURF = (ROOT / 'code/game/turfs/turf.dm').read_text(encoding='utf-8')
FARMING = (ROOT / 'code/game/objects/farming.dm').read_text(encoding='utf-8')
WILLOW = (ROOT / 'code/modules/ecology/willow_trees.dm').read_text(encoding='utf-8')
PROBE = (ROOT / 'tests/tree_trunk_collision/probe.dm').read_text(encoding='utf-8')


def proc(text, name):
    start = text.index(name)
    end = re.search(r'\n(?=/|#define|\Z)', text[start + 1:])
    return text[start:start + 1 + end.start()] if end else text[start:]


class TreeTrunkSources(unittest.TestCase):
    def test_box_stays_inside_tile(self):
        body = proc(WILD, '/obj/structure/wild/proc/fit_trunk_bounds()')
        self.assertIn('if (!trunk_center_x)', body)
        self.assertIn('world.icon_size - width', body)
        self.assertIn('world.icon_size - height', body)
        self.assertIn('trunk_fitted = TRUE', body)
        self.assertNotIn('step_x', body)

    def test_trees_fit_after_offsets(self):
        for name in ('/obj/structure/wild/tree/New()', '/obj/structure/wild/jungle/New()\n\t..()\n\tpixel_x'):
            body = proc(WILD, name)
            self.assertIn('pixel_x = rand(8,24) - trunk_center_x', body)
            self.assertTrue(body.rstrip().endswith('fit_trunk_bounds()'), name)
        self.assertIn('fit_trunk_bounds()', proc(WILD, '/obj/structure/wild/after_load()'))
        # A matured sapling resets its offset, then calls change_season().
        self.assertIn('T.pixel_x = initial(T.pixel_x)', FARMING)
        self.assertIn('T.change_season()', FARMING)
        self.assertIn('fit_trunk_bounds()', proc(WILD, '/obj/structure/wild/tree/live_tree/update_icon()'))
        self.assertIn('W.fit_trunk_bounds()', WILLOW)

    def test_trunk_centres_match_sprite_widths(self):
        # 32px small trees centre at 16; 64px trees at 32.
        self.assertRegex(proc(WILD, '/obj/structure/wild/tree\n'), r'trunk_center_x = 16')
        for name in ('/obj/structure/wild/tree/cactus\n', '/obj/structure/wild/tree/dead_tree\n',
                     '/obj/structure/wild/tree/live_tree\n', '/obj/structure/wild/jungle\n'):
            self.assertIn('trunk_center_x = 32', proc(WILD, name), name)
        self.assertNotIn('bound_height = 64', proc(WILD, '/obj/structure/wild/jungle\n'))

    def test_only_free_movement_skips_tile_check(self):
        mover = proc(WILD, '/proc/trunk_collision_mover(')
        self.assertIn('ishuman(mover)', mover)
        self.assertIn('human_subtile_transaction', mover)
        enter = proc(TURF, '/turf/Enter(')
        self.assertIn('var/trunk_mover = trunk_collision_mover(mover)', enter)
        self.assertIn('if (trunk_mover && istype(obstacle, /obj/structure/wild))', enter)
        cross = proc(WILD, '/obj/structure/wild/Cross(')
        # Same arguments as turf/Enter, so height checks still block.
        self.assertIn('CanPass(mover, mover.loc, TRUE, FALSE)', cross)

    def test_probe_covers_behaviour(self):
        for label in ('west_walk_stops_at_trunk', 'north_past_trunk', 'south_past_trunk',
                      'north_stops_at_trunk_base', 'south_stops_at_trunk_top', 'trunk_bumps_tree',
                      'tile_mover_blocked_by_tree', 'clamped_box_inside_tile', 'after_load_refits',
                      'palm_whole_tile', 'random_trunk_inside_tile_'):
            self.assertIn('"' + label, PROBE)


if __name__ == '__main__':
    unittest.main()
