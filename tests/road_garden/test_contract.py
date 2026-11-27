"""Source contracts for reclaiming a player-packed road, not a native playtest."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
ROADS = (ROOT / 'code/game/objects/covers_types/cover_roads.dm').read_text()
FLOORS = (ROOT / 'code/game/turfs/floor_attackby.dm').read_text()
CHANGING = (ROOT / 'code/game/turfs/turf_changing.dm').read_text()


def body(source, path):
    match = re.search(r'^' + re.escape(path) + r'[^\n]*\n([\s\S]*?)(?=^/|\Z)', source, re.M)
    if not match:
        raise AssertionError(f'Missing proc: {path}')
    return match[1]


class ReclaimedRoad(unittest.TestCase):
    def test_only_new_hand_packed_roads_have_the_new_interaction(self):
        self.assertEqual(FLOORS.count('new /obj/covers/roads/dirt/worked(T)'), 1)
        create = FLOORS.index('new /obj/covers/roads/dirt/worked(T)')
        action = FLOORS.rfind('if (user.a_intent == I_DISARM)', 0, create)
        self.assertIn('if (!T || T.weather_snow > 0 || (locate(/obj/covers) in T))', FLOORS[action:create])
        self.assertGreater(action, FLOORS.rfind('else if (istype(C, /obj/item/weapon/plough))', 0, create))
        ordinary = body(ROADS, '/obj/covers/roads/dirt/attackby(')
        self.assertIn('is_tool(O, TOOL_SHOVEL)', ordinary)
        self.assertNotIn('garden', ordinary)
        reclaim = body(ROADS, '/obj/covers/roads/dirt/worked/attackby(')
        self.assertIn('user.a_intent != I_HELP)\n\t\treturn ..()', reclaim)

    def test_rechecks_after_wait_before_world_mutation(self):
        reclaim = body(ROADS, '/obj/covers/roads/dirt/worked/attackby(')
        guard = 'problem = garden_reclaim_problem(ground, user, tool)'
        self.assertEqual(reclaim.count(guard), 2)
        before, after = reclaim.split('if (!do_after(')
        self.assertIn(guard, before)
        self.assertLess(after.index(guard), after.index('ground.ChangeTurf('))
        self.assertIn('if (problem)\n\t\tto_chat(user, SPAN_WARNING(problem))\n\t\treturn TRUE', after)
        gate = body(ROADS, '/obj/covers/roads/dirt/worked/proc/garden_reclaim_problem(')
        for check in ('persistence_save_in_progress', 'persistence_active_operation', 'persistence_load_recovery_required',
                      'QDELETED(src)', 'loc != ground', '!user.Adjacent(src)', 'user.incapacitated()', 'user.restrained()',
                      'user.a_intent != I_HELP', 'QDELETED(tool)', 'user.get_active_hand() != tool'):
            self.assertIn(check, gate)

    def test_only_natural_farmable_turf_without_water_snow_or_occupants(self):
        gate = body(ROADS, '/obj/covers/roads/dirt/worked/proc/garden_reclaim_problem(')
        types = re.search(r'ground\.type in list\(([^)]+)\)', gate)[1].split(', ')
        self.assertEqual(types, [
            '/turf/floor/grass', '/turf/floor/dirt', '/turf/floor/dirt/fertile',
            '/turf/floor/dirt/medium_fertile', '/turf/floor/dirt/infertile',
        ])
        for check in ('ground.density', 'ground.flooring.type != ground.initial_flooring',
                      'ground.weather_snow > 0', 'ground.water_level > 0', 'origin_water_level > 0',
                      'flood_depth_at(ground) > 0', 'blocker.density', 'istype(blocker, /obj/covers)',
                      'istype(blocker, /obj/structure)', 'istype(blocker, /obj/roof)'):
            self.assertIn(check, gate)

    def test_garden_is_real_ploughed_soil_without_stock_or_refund_creation(self):
        reclaim = body(ROADS, '/obj/covers/roads/dirt/worked/attackby(')
        self.assertIn('ground.ChangeTurf(/turf/floor/dirt/ploughed)', reclaim)
        self.assertIn('garden.soil_nutrition = old_nutrition', reclaim)
        self.assertIn('recovery_delay = max(1, old_soil.soil_recovery_deadline - world.time)', reclaim)
        self.assertIn('garden.soil_recovery_schedule(recovery_delay)', reclaim)
        self.assertIn('garden.available_dirt = old_dirt', reclaim)
        self.assertIn('amount = 0\n\tqdel(src)', reclaim)
        self.assertNotIn('new /obj/item', reclaim)
        self.assertIn('W.terrain_grade = old_terrain_grade', CHANGING)
        self.assertIn('W.pollution_take_over(old_pollution, old_pollution_index)', CHANGING)
        self.assertIn('istype(src, /turf/floor/dirt/ploughed) && istype(H) && is_plowed == TRUE', FLOORS)

    def test_hand_and_cattle_field_conversions_share_soil_transfer(self):
        cattle = (ROOT / 'code/game/mob/living/simple_animal/friendly/farm_animals.dm').read_text()
        dirt = (ROOT / 'code/game/turfs/flooring/flooring_premade.dm').read_text()
        for source in (FLOORS, cattle):
            for suffix in ('', '/flooded'):
                self.assertIn(f'T.till_into_field(/turf/floor/dirt/ploughed{suffix})', source)
        transfer = body(dirt, '/turf/proc/till_into_field(')
        before, after = transfer.split('var/turf/floor/dirt/ploughed/field = ChangeTurf')
        for field in ('available_dirt', 'soil_nutrition', 'soil_recovery_deadline'):
            self.assertIn(f'soil.{field}', before)
        self.assertIn('soil.soil_recovery_unregister()', before)
        self.assertIn('max(0, soil.soil_recovery_deadline - world.time)', before)
        self.assertIn('field.available_dirt = dirt_stock', after)
        self.assertIn('field.soil_nutrition = nutrition', after)
        self.assertIn('field.soil_recovery_schedule(recovery_delay)', after)
        self.assertNotIn('soil_recovery_index', transfer)


if __name__ == '__main__':
    unittest.main()
