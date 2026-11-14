"""Offline source contracts for climbing down, standing ladders and stairs.

Behaviour is covered natively by tests/edge_climbing/run_native.py.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/multiz/edge_climbing.dm').read_text(encoding='utf-8-sig')


def proc(name):
    return SOURCE.split(name + '\n', 1)[1].split('\n/', 1)[0]


class EdgeClimbing(unittest.TestCase):
    def test_included_in_build(self):
        self.assertIn('#include "code\\modules\\multiz\\edge_climbing.dm"', (ROOT / 'civ13.dme').read_text())

    def test_descent_reuses_climber_and_landing_checks(self):
        source = proc('/proc/edge_descent_destination(mob/living/human/H, direction, list/why)')
        for guard in ('ledge_climber_problem(H)', 'edge_open_air(edge)', 'edge_open_air(here)', 'multiz_level_below(edge.z)',
                      'ledge_landing_clear(destination)', 'map.check_caribbean_block(H, destination)',
                      'persistence_movement_allowed(H, destination)'):
            self.assertIn(guard, source)

    def test_descent_revalidates_after_wait(self):
        source = proc('/mob/living/human/proc/climb_down_edge(direction)')
        self.assertLess(source.index('do_after'), source.index('edge_descent_destination(src, direction) != destination'))
        self.assertLess(source.index('edge_descent_destination(src, direction) != destination'), source.index('trench_climb_place(src, destination)'))

    def test_grab_click_and_verb_wired(self):
        click = (ROOT / 'code/_onclick/other_mobs.dm').read_text()
        unarmed = click.split('/mob/living/human/UnarmedAttack(', 1)[1].split('\n/', 1)[0]
        self.assertLess(unarmed.index('grab_climb_down_edge(A)'), unarmed.index('A.attack_hand('))
        source = proc('/mob/living/human/proc/grab_climb_down_edge(atom/A)')
        self.assertIn('a_intent != I_GRAB || get_active_hand()', source)
        self.assertNotIn('do_after', source)
        tree = (ROOT / 'code/game/objects/structures/tree_climbing.dm').read_text()
        verb = tree.split('/mob/living/human/verb/climb_down_tree_verb()', 1)[1].split('\n/', 1)[0]
        self.assertIn('climb_down_any_edge()', verb)

    def test_ladder_pair_is_unnumbered_and_removed_together(self):
        self.assertEqual(SOURCE.count('ladder_list -= src'), 2)
        self.assertEqual(SOURCE.count('qdel(other)'), 2)
        place = proc('/obj/item/weapon/hole_ladder/proc/try_stand_ladder(atom/A, mob/user)')
        self.assertLess(place.index('do_after'), place.rindex('placed_ladder_spot(T, user, why)'))
        self.assertLess(place.rindex('placed_ladder_spot(T, user, why)'), place.index('qdel(src)'))

    def test_stairs_need_open_stairwell_and_top_floor(self):
        source = proc('/proc/stairs_destination(mob/living/human/H, obj/covers/S, list/why)')
        self.assertIn('edge_open_air(well)', source)
        self.assertIn('ledge_landing_clear(landing)', source)
        for path in ('/obj/covers/wood/stairs', '/obj/covers/cobblestone/stairs', '/obj/covers/sandstone/stairs'):
            self.assertIn(path + '\n\tstairs = TRUE', SOURCE)

    def test_stairwells_step_down_instead_of_falling(self):
        building = (ROOT / 'code/game/objects/building_levels.dm').read_text()
        entered = building.split('/turf/sky/building/Entered(atom/movable/A)', 1)[1].split('\n/', 1)[0]
        self.assertLess(entered.index('stairs_soft_descent(A, below)'), entered.index('A.forceMove(below)'))
        open_space = (ROOT / 'code/modules/multiz/open_space.dm').read_text()
        entered = open_space.split('/turf/floor/broken_floor/Entered(atom/movable/A)', 1)[1].split('\n/', 1)[0]
        self.assertLess(entered.index('stairs_soft_descent(A, floorbelowz)'), entered.index('persistence_set_z(A.z - 1)'))
        self.assertIn('stairs_step_on(H, src, OL)', (ROOT / 'code/game/turfs/turf.dm').read_text())

    def test_stairs_cooldown_is_runtime_only(self):
        self.assertIn('/mob/living/human/var/tmp/stairs_moved_at', SOURCE)
        self.assertIn('key == "stairs_moved_at"', SOURCE)


if __name__ == '__main__':
    unittest.main()
