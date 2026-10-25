"""Authored DMM witnesses and fail-closed ordering, not a native map proof."""
from pathlib import Path
import re
import unittest
ROOT=Path(__file__).parent
SCENE=(ROOT/'changed-source/filming/scene.dm').read_text()

class MapReadiness(unittest.TestCase):
    def test_fixed_witnesses_match_authored_dmm_coordinates(self):
        dmm=(ROOT/'changed-source/filming/bakery.dmm').read_text()
        definitions=dict(re.findall(r'^"(\w+)" = (.*)$',dmm,re.M))
        rows=dmm.split('(1,1,1) = {"\n')[1].split('\n"}')[0].splitlines()
        self.assertEqual(len(rows),13);self.assertTrue(all(len(r)==30 for r in rows))
        witnesses=re.findall(r'list\((\d+), (\d+), (/turf/[^,]+), ([^)]+)\)',SCENE)
        self.assertEqual(len(witnesses),6)
        for x,y,turf,obj in witnesses:
            x,y=int(x),int(y);cell=definitions[rows[13-y][2*(x-1):2*x]]
            self.assertIn(turf+',',cell)
            self.assertIn('/area/caribbean/desert/buildings',cell)
            if obj!='null':self.assertIn(obj+',',cell)
        self.assertIn('list(7, 7, /turf/floor/wood_broken, /obj/structure/table/wood)',SCENE)
        self.assertIn('list(6, 8, /turf/floor/wood, /obj/structure/oven)',SCENE)

    def test_assertions_bracket_initialization_and_precede_admission(self):
        startup=SCENE.split('/world/New()\n')[1]
        tokens=['filming_assert_authored_map("world New before fixture initialization")','movementMachine = new','A.initialize()','apply_restored_lighting()','filming_assert_authored_map("after fixture initialization before listener")','filming_ready = TRUE','OpenPort(filming_allowed_port)']
        positions=[startup.index(t) for t in tokens];self.assertEqual(positions,sorted(positions))
        client=SCENE.split('/client/New()\n')[1].split('/client/Del()')[0]
        self.assertLess(client.index('filming_assert_authored_map("client admission")'),client.index('filming_observer_client = src'))
        self.assertLess(client.index('filming_assert_authored_map("client admission")'),client.index('cloud-client.txt'))

    def test_diagnostic_precedes_fail_closed_check(self):
        helper=SCENE.split('/proc/filming_assert_authored_map(phase)')[1].split('/client/New()')[0]
        self.assertLess(helper.index('text2file('),helper.index('filming_check(ok,'))
        for gate in ('T.type == expected_turf','A.type == /area/caribbean/desert/buildings','O.loc == T','world.maxx == 15 && world.maxy == 13 && world.maxz == 1'):
            self.assertIn(gate,helper)
        self.assertNotIn('new /',helper);self.assertNotIn('ChangeTurf',helper)
        self.assertNotIn('forceMove',helper);self.assertNotIn('sleep(',helper)

    def test_single_unconditional_map_include_and_no_map_reconstruction(self):
        dme=(ROOT/'changed-source/civ13.dme').read_text()
        self.assertEqual(re.findall(r'#include "[^"]+\.dmm"',dme),['#include "filming\\bakery.dmm"'])
        self.assertNotIn('#if',dme)
        helper=SCENE.split('/proc/filming_assert_authored_map(phase)')[1].split('/client/New()')[0]
        self.assertNotRegex(helper,r'world\.max[xyz]\s*=(?!=)')
        self.assertIn('copytext(actual_turf, 1, 129)',helper)
        self.assertIn('copytext(actual_area, 1, 129)',helper)

if __name__=='__main__':unittest.main()
