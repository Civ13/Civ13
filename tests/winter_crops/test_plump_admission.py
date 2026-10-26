"""Source-derived admission projection and debit-order contract, not native DM."""
import itertools
import re
import unittest
from types import SimpleNamespace as State
from test_sources import FARM, ROOT, Turf, block, compile_proc

SIGNATURE = '/obj/item/stack/farming/seeds/plump_helmet/planting_error(turf/T)'
MAPS = ('MAP_NOMADS_CONTINENTAL', 'MAP_NOMADS_PANGEA', 'MAP_NOMADS_NEW_WORLD',
        'MAP_NOMADS_MEDITERRANEAN', 'MAP_NOMADS_EUROPE', 'MAP_NOMADS_GAIA')


def strings(value):
    return set(re.findall(r'"([^"]+)"', value))


def declared_list(body, name):
    return strings(re.search(r'\b'+name+r' = list\(([^\n]+)\)', body)[1])


def admission(source=FARM):
    proc, ns = compile_proc(block(source, SIGNATURE), 'def check(T):')
    ns.update({name: name for name in MAPS})
    ns['map'] = State(ID=MAPS[1])
    ns['season'] = 'WINTER'
    return proc, ns


def debit_guard(source):
    """Pin actual floor early return before any spawn, skill or seed mutation."""
    start=source.index('\t\t\tif (istype(C, /obj/item/stack/farming/seeds))', source.index('var/obj/item/stack/farming/seeds/TS'))
    end=source.index('\t\t\tif (ishuman(user))',start)
    guard=source[start:end]
    expected='''\t\t\tif (istype(C, /obj/item/stack/farming/seeds))
\t\t\t\tTS = C
\t\t\t\tvar/planting_error = TS.planting_error(src)
\t\t\t\tif (planting_error)
\t\t\t\t\tto_chat(user, SPAN_WARNING(planting_error))
\t\t\t\t\treturn
'''
    if guard != expected:
        raise ValueError('Planting rejection must return before resource payment')
    tail=source[end:source.index('\n\telse if (istype(C, /obj/item/weapon/plough))',end)]
    assert 'TS.spawn_plant(src)' in tail and 'C.amount -= 1' in tail
    return guard


class PlumpAdmission(unittest.TestCase):
    def test_inherited_growth_rule_and_lists_stay_in_parity(self):
        crop=block(FARM,'/obj/structure/farming/plant/mushroom')
        growth=block(FARM,'/obj/structure/farming/plant/proc/growth()')
        rule=block(FARM,SIGNATURE)
        biome=re.search(r'A.climate in list\(([^\n]+)\)\)\)',rule)[1]
        season=re.search(r'season in list\(([^\n]+)\)\)\)',rule)[1]
        self.assertEqual(strings(biome),declared_list(crop,'biomes'))
        self.assertEqual(strings(season),declared_list(crop,'seasons'))
        self.assertEqual(set(re.findall(r'MAP_NOMADS_\w+',rule)),set(re.findall(r'MAP_NOMADS_\w+',growth)))
        self.assertIn('list("jungle", "desert", "savanna").Find(currcl)',growth)
        self.assertIn('A.climate in list("jungle", "desert", "savanna")',rule)
        self.assertIn('a && a.location == 0 && (istype(src, /obj/structure/farming/plant/mushroom)',growth)
        self.assertIn('if (i == currcl)',growth)
        self.assertIn('if (season == k)',growth)
        self.assertIn('if (count > 0 || ! list(',growth)

    def test_complete_boundary_matrix_matches_effective_growth(self):
        check,ns=admission()
        crop=block(FARM,'/obj/structure/farming/plant/mushroom')
        biomes=declared_list(crop,'biomes');seasons=declared_list(crop,'seasons')
        for map_id,location,climate,season in itertools.product((*MAPS,'OTHER'),(0,1,2),(*sorted(biomes),'desert','semiarid','unknown'),(*sorted(seasons),'Dry Season','unknown')):
            ns['map'].ID=map_id;ns['season']=season
            expected=location==0 or map_id not in MAPS or (climate in biomes and (climate in {'jungle','desert','savanna'} or season in seasons))
            with self.subTest(map=map_id,location=location,climate=climate,season=season):
                self.assertEqual(check(Turf(area=State(location=location,climate=climate))) is None,expected)
        for map_id in (*MAPS,'OTHER'):
            ns['map'].ID=map_id
            self.assertIsNotNone(check(Turf(area=None)))

    def test_rejected_spores_pay_neither_seeds_nor_constructor_soil(self):
        floor=(ROOT/'code/game/turfs/floor_attackby.dm').read_text()
        guard=debit_guard(floor)
        # Execute only the pinned early-return branch; a sentinel stands for the
        # later constructor/debit. No native interaction or soil scheduler claim.
        check,ns=admission()
        def transaction(turf, resources):
            error=check(turf)
            if error:
                return error
            resources['spawn_calls']+=1
            resources['seeds']-=1
            resources['soil']-=3
        for climate,season in [('desert','WINTER'),('semiarid','SUMMER'),('temperate','Dry Season')]:
            ns['season']=season;resources=dict(spawn_calls=0,seeds=2,soil=150)
            self.assertIsNotNone(transaction(Turf(area=State(location=1,climate=climate)),resources))
            self.assertEqual(resources,dict(spawn_calls=0,seeds=2,soil=150))
        with self.assertRaises(ValueError):
            debit_guard(floor.replace(guard,guard.replace('\t\t\t\t\treturn\n','')))
        with self.assertRaises(ValueError):
            debit_guard(floor.replace(guard,guard.replace('TS = C','TS = C\n\t\t\t\tTS.spawn_plant(src)')))

    def test_ordinary_admission_and_foraging_unchanged(self):
        self.assertEqual(block(FARM,'/obj/item/stack/farming/seeds/proc/planting_error(turf/T)').strip(),'return null')
        seed=block(FARM,'/obj/item/stack/farming/seeds/plump_helmet')
        self.assertNotIn('biomes =',seed);self.assertNotIn('seasons =',seed)
        # Rejecting climate must not create a temporary crop (its constructor pays soil).
        body=block(FARM,SIGNATURE)
        self.assertNotRegex(body,r'\bnew\b|spawn_plant|soil_nutrition|amount\s*[-=]')

    def test_causal_controls_detect_lost_indoor_and_map_bypasses(self):
        for old,new in [('A.location == 0','A.location == 1'),('if (!(map.ID in list(','if ((map.ID in list(')]:
            check,ns=admission(FARM.replace(old,new))
            ns['map'].ID='OTHER' if 'map.ID' in old else MAPS[1]
            self.assertIsNotNone(check(Turf(area=State(location=1 if 'map.ID' in old else 0,climate='desert'))))


if __name__=='__main__': unittest.main()
