"""Offline exact bakery source contracts, not native compilation."""
import hashlib,json,re,unittest
from pathlib import Path
HERE=Path(__file__).resolve().parent
class BakeryScene(unittest.TestCase):
    def test_exact_reviewed_source_and_map(self):
        d=json.loads((HERE/'derived-source.json').read_text())
        for name in ('actions.dm','scene.dm','bakery.dmm'):
            self.assertEqual(hashlib.sha256((HERE/'changed-source/filming'/name).read_bytes()).hexdigest(),d['changes']['filming/'+name])
        self.assertEqual(d['changes']['filming/bakery.dmm'],'6f361982bb0c8dd5822d0aae840651e7826db69eda91fa63dc12665a134597ae')
    def test_native_recipe_handlers_and_unchanged_timer(self):
        s=(HERE/'changed-source/filming/actions.dm').read_text()
        for token in ['bakery_flour.attack_self(bakery_baker)','bakery_oven.attackby(bakery_dough, bakery_baker)','bakery_oven.attack_hand(bakery_baker)','bakery_counter.attackby(bread, bakery_baker','bakery_pickup(bakery_customer, bread)','cooking_time == 50','"identical produced placed and received flatbread"'] :self.assertIn(token,s)
        setup,take=s.split('/proc/bakery_take()',1)
        self.assertIn('"two preplaced loaves found"',setup)
        self.assertIn('"counter cleared before preflight"',setup)
        self.assertEqual(setup.count('qdel(old'),2)
        self.assertIn('var/picked_at = world.time\n\tsleep(10)',take)
        self.assertNotIn('bakery_flour.attack_self',setup)
        self.assertLess(take.index('bakery_flour.attack_self'),take.index('bakery_oven.attackby'))
        self.assertLess(take.index('bakery_oven.attackby'),take.index('bakery_pickup(bakery_customer, bread)'))
        self.assertIn('if (!(D in old_dough))',take)
        self.assertNotRegex(s,r'new\s+/obj/.+(?:flatbread|sliceable/bread)')
        self.assertNotRegex(s,r'\.(?:cooking_time|rise_ready_at|risen|leavened)\s*=(?!=)')
        route=(HERE/'changed-source/filming/city_route_actions.review.dm').read_text()
        for token in ('city_plant.attackby(city_knife, city_courier)', 'city_mill.attackby(wheat, city_courier)', 'bakery_counter.attackby(flour, city_courier', 'bakery_pickup(bakery_baker, flour)'):
            self.assertIn(token,route)
    def test_fixed_map_dimensions_witnesses_and_bounded_take(self):
        s=(HERE/'changed-source/filming/scene.dm').read_text()
        self.assertIn('maxx == 96 && maxy == 75 && maxz == 1',s)
        self.assertNotRegex(s,r'(?m)^\tmax[xyz]\s*=')
        self.assertIn('"authored bakery oven and mill"',s)
        self.assertIn('bakery_take()',s)
        self.assertNotIn('sleep(20)\n\t\tvar/datum',s)

