"""Offline wiring checks for labour speed (code/modules/materials/work_speed.dm).

The native probe (probe.dm) checks the numbers; these check that every
digging, mining, chopping and tilling wait goes through work_delay and that
the old per-file formulas are gone.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


SITES = {
    'code/game/turfs/floor_attackby.dm': ('work_delay(H, 40, WORK_SHIFT, SH)', 'work_delay(H, 27, WORK_SHIFT, SH)', 'earth_pile_out(T, user, "dirt")', 'earth_pile_out(T, user, "sand")',
        'work_delay(H, 100, WORK_DIG, SH)', 'work_delay(user, 50, WORK_TILL, PL)', 'work_delay(H, 70, WORK_TILL, PL)',
        'work_delay(H, 320, WORK_MINE, C)', 'work_delay(actor, 120, WORK_MINE, tool)'),
    'code/modules/1713/trench.dm': ('work_delay(user, 30, WORK_DIG, C)', 'work_delay(user, 15, WORK_DIG, C)', 'work_delay(H, 58, WORK_DIG, C)'),
    'code/modules/1713/tools.dm': ('work_delay(user, 25, WORK_DIG, src)', 'work_delay(user, 100, WORK_DIG, src)',
        'work_delay(user, 150, WORK_DIG, src)', 'dug_underground_dig_time(user, 400)', 'dug_underground_dig_time(user, 200)'),
    'code/modules/1713/sewers.dm': ('work_delay(user, cesspit ? 150 : 40, WORK_DIG, src)',),
    'code/modules/1713/underground_excavation.dm': ('work_delay_per_speed(H, delay, WORK_DIG, S)', 'work_delay_per_speed(H, BACKFILL_TIME, WORK_SHIFT, tool)'),
    'code/modules/1713/dug_wells.dm': ('WORK_DIG, S)', 'work_delay_per_speed(user, WELL_DIG_TIME, WORK_DIG, src)'),
    'code/modules/1713/road_tamping.dm': ('work_delay(user, TAMPING_TIME, WORK_DIG, src)', 'work_delay(user, GRADING_TIME, WORK_DIG, tool)', 'work_delay(user, TAMPING_TIME, WORK_DIG, C)', 'wheelbarrow_for(user, "dirt", FALSE)', 'earth_pile_out(T, user)'),
    'code/modules/1713/stone_age_storage.dm': ('work_delay(user, STORAGE_PIT_DIG_TIME_SHOVEL, WORK_DIG, tool)',),
    'code/modules/1713/placer.dm': ('work_delay(src, PAY_DIRT_DIG_TIME, WORK_DIG, get_active_hand())',),
    'code/modules/1713/open_cave_roof.dm': ('work_delay_per_speed(user, OPEN_CAVE_ROOF_TIME, WORK_MINE, P)',),
    'code/modules/1713/mountain_seams.dm': ('work_delay_per_speed(H, MOUNTAIN_SEAM_WORK, WORK_MINE, P)',),
    'code/modules/provinces/province_rich.dm': ('work_delay_per_speed(H, RICH_SEAM_WORK, WORK_MINE, P)',),
    'code/game/objects/structures/wild.dm': ('work_delay(user, CHOP_TREE_TIME, WORK_CHOP, HT)', 'work_delay(user, 50, WORK_DIG, W)'),
    'code/game/objects/covers_types/cover_roads.dm': ('work_delay(user, 45, WORK_MINE, O)', 'work_delay(user, 30, WORK_SHIFT, O)'),
    'code/modules/multiz/dug_underground.dm': ('work_delay(user, base / max(0.25, craft * craft), WORK_DIG, user.get_active_hand())',),
}


class Wiring(unittest.TestCase):
    def test_included_and_defines_shared(self):
        self.assertIn('#include "code\\modules\\materials\\work_speed.dm"', read('civ13.dme'))
        defines = read('code/__defines/tools.dm')
        for name in ('WORK_DIG', 'WORK_MINE', 'WORK_CHOP', 'WORK_TILL', 'WORK_SHIFT', 'WORK_MIN_MULT', 'WORK_MAX_MULT', 'CHOP_TREE_TIME'):
            self.assertRegex(defines, r'(?m)^#define ' + name + r'\b')

    def test_every_labour_site_uses_work_delay(self):
        for path, calls in SITES.items():
            text = read(path)
            for call in calls:
                with self.subTest(path=path, call=call):
                    self.assertIn(call, text)

    def test_old_formulas_are_gone(self):
        old = re.compile(r'getStatCoeff\("strength"\)\)?\s*/\s*(?:max\(0\.1, )?(?:SH|S|P|PL|tool:?)\.?usespeed|chopping_speed, user\.loc|\(10 - S\.dig_speed\)|/\(12/S\.dig_speed\)')
        for path in SITES:
            with self.subTest(path=path):
                self.assertIsNone(old.search(read(path)))
        self.assertNotIn('dig_speed', read('code/modules/1713/tools.dm'))

    def test_dead_branches_removed(self):
        trench = read('code/modules/1713/trench.dm')
        self.assertEqual(trench.count('/turf/floor/dirt/attackby('), 1)
        roads = read('code/game/objects/covers_types/cover_roads.dm')
        self.assertNotIn('pickaxe/jackhammer', roads)
        self.assertNotIn('pickaxe/bone', roads)

    def test_reviewed_formula(self):
        module = read('code/modules/materials/work_speed.dm')
        for line in ('WORK_DIG = 1.5', 'WORK_MINE = 2', 'WORK_CHOP = 1.7', 'WORK_TILL = 1',
                     'WORK_DIG = list("strength" = 0.7, "stamina" = 0.3)',
                     'WORK_MINE = list("strength" = 0.8, "stamina" = 0.2)',
                     'WORK_CHOP = list("strength" = 0.7, "dexterity" = 0.3)',
                     'WORK_TILL = list("farming" = 0.6, "strength" = 0.4)',
                     'return max(0.5, total)'):
            self.assertIn(line, module)


class ToolTiers(unittest.TestCase):
    def test_hatchets_get_faster_with_each_metal(self):
        speeds = read('code/modules/materials/tool_speeds.dm')
        self.assertIn('"stone" = 3.3, "bronze" = 1.9, "iron" = 1.7, "steel" = 1.4', speeds)

    def test_navvy_shovel_is_the_fastest_hand_shovel(self):
        tools = read('code/modules/1713/tools.dm')
        block = tools[tools.index('/obj/item/weapon/material/shovel/navvy\n'):]
        block = block[:block.index('\n\n')]
        self.assertIn('usespeed = 2.5', block)
        self.assertIn('default_material = "steel"', block)
        self.assertIn('"/obj/item/weapon/material/shovel/navvy" = "machined_tools"', read('code/modules/research_tree/research_node.dm'))
        self.assertIn('RECIPE: /material/steel/,navvy shovel,/obj/item/weapon/material/shovel/navvy,', read('config/crafting/material_recipes_global.txt'))


class EarthworkingTools(unittest.TestCase):
    def test_mattock_and_wheelbarrow_are_craftable_and_gated(self):
        self.assertIn('#include "code\\modules\\1713\\earthworking_tools.dm"', read('civ13.dme'))
        nodes = read('code/modules/research_tree/research_node.dm')
        self.assertIn('"/obj/item/weapon/material/shovel/mattock" = "bronze_working"', nodes)
        self.assertIn('"/obj/structure/wheelbarrow" = "iron_tools"', nodes)
        recipes = read('config/crafting/material_recipes_global.txt')
        for metal in ('copper', 'bronze', 'iron', 'steel'):
            self.assertIn('RECIPE: /material/%s/,%s mattock,/obj/item/weapon/material/shovel/mattock,3,70,0,1,tools,0,0,0,8,%s' % (metal, metal, metal), recipes)
        self.assertIn('RECIPE: /material/wood/,wheelbarrow,/obj/structure/wheelbarrow,8,120,1,1,logistics,', recipes)

    def test_mattock_breaks_ground_but_shovels_slowly(self):
        module = read('code/modules/1713/earthworking_tools.dm')
        self.assertIn('shifting_mult = 0.5', module)
        self.assertIn('/obj/item/weapon/material/shovel/mattock = list("copper" = 1.3, "bronze" = 1.6, "iron" = 2, "steel" = 2.5)', read('code/modules/materials/tool_speeds.dm'))
        self.assertIn('if (kind == WORK_SHIFT && ("shifting_mult" in tool.vars)', read('code/modules/materials/work_speed.dm'))


if __name__ == '__main__':
    unittest.main()
