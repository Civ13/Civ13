"""Offline exact bakery source contracts, not native compilation."""
import hashlib,re,unittest
from pathlib import Path
HERE=Path(__file__).resolve().parent
class BakeryScene(unittest.TestCase):
    def test_exact_reviewed_source_and_map(self):
        for name,sha in SEALS.items():self.assertEqual(hashlib.sha256((HERE/'changed-source/filming'/name).read_bytes()).hexdigest(),sha)
    def test_native_recipe_handlers_and_unchanged_timer(self):
        s=(HERE/'changed-source/filming/actions.dm').read_text()
        for token in ['bakery_flour.attack_self(bakery_baker)','bakery_oven.attackby(bakery_dough, bakery_baker)','bakery_oven.attack_hand(bakery_baker)','bakery_counter.attackby(bread, bakery_baker','bakery_pickup(bakery_customer, bread)','cooking_time == 50','"identical produced placed and received flatbread"'] :self.assertIn(token,s)
        setup,take=s.split('/proc/bakery_take()',1)
        self.assertNotIn('bakery_flour.attack_self',setup)
        self.assertLess(take.index('bakery_flour.attack_self'),take.index('bakery_oven.attackby'))
        self.assertLess(take.index('bakery_oven.attackby'),take.index('bakery_pickup(bakery_customer, bread)'))
        self.assertIn('if (!(D in old_dough))',take)
        self.assertNotRegex(s,r'new\s+/obj/.+(?:flatbread|sliceable/bread)')
        self.assertNotRegex(s,r'\.(?:cooking_time|rise_ready_at|risen|leavened)\s*=(?!=)')
    def test_fixed_map_dimensions_witnesses_and_bounded_take(self):
        s=(HERE/'changed-source/filming/scene.dm').read_text()
        self.assertIn('maxx == 15 && maxy == 15 && maxz == 1',s)
        self.assertNotRegex(s,r'(?m)^\tmax[xyz]\s*=')
        self.assertIn('"authored bakery oven and counter"',s)
        self.assertIn('bakery_take()',s)
        self.assertNotIn('sleep(20)\n\t\tvar/datum',s)

SEALS={'actions.dm': 'e2ddf216bd1d89de2ea761be1a4a531f934621d634cea88107d60996c687821f', 'scene.dm': '23f6b3e4b9022d13127c94fecc5795c2bcf5c77ed2a8c220f233db4273a9501b', 'bakery.dmm': 'c78f44ca5f834be56e382fa2e71e84d814cce4fa0ea1ec872912fddb33b97788'}
