"""Execute full Gaia selection helpers with fake spatial/engine boundaries.

This is offline source control-flow evidence, not a native or live-world test.
"""
import importlib.util
from pathlib import Path
import re
import unittest
from types import SimpleNamespace as NS

ROOT = Path(__file__).resolve().parents[2]
PATH = 'code/game/objects/map_metadata/nomads/nomads_gaia.dm'
BASE = '/obj/map_metadata/nomads/gaia/proc/'
spec = importlib.util.spec_from_file_location('gaia_source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


class DMList(list):
    @property
    def len(self):
        return len(self)

    def __getitem__(self, key):
        return super().__getitem__(key - 1)

    def __iadd__(self, item):
        self.append(item)
        return self


class Tile(NS):
    def __iter__(self):
        return iter(self.contents)

    # DM atoms compare identity, not equal field dictionaries.
    def __eq__(self, other):
        return self is other


def atom(kind, **kw):
    return NS(kind=kind, density=False, radiation=0, **kw)


def istype(value, kind='/turf/floor'):
    if kind == 'ADMIN_AREA': kind = '/area/caribbean/admin'
    return value is not None and (value.kind == kind or value.kind.startswith(kind + '/'))


def tile(x=1, y=1, z=2, kind='/turf/floor/grass', **kw):
    values = dict(kind=kind, x=x, y=y, z=z, density=False, water_level=0,
                  watertile=False, radiation=0, to_be_destroyed=False,
                  contents=DMList(), area=NS(kind='/area/caribbean/nomads/forest',
                  climate='temperate', location=1, is_void_area=False, no_air=False,
                  has_gravity=True))
    values.update(kw)
    return Tile(**values)


class Fixture:
    def __init__(self, source=None):
        self.source = source or (ROOT / PATH).read_text()
        self.grid = {}
        self.draws = []
        self.draw_count = 0
        self.check_count = 0
        self.bed = None
        self.region = False
        self.env = dict(re.findall(r'^#define (GAIA_\w+) (\d+)$', self.source, re.M))
        self.env = {key: int(value) for key, value in self.env.items()}
        self.env.update(istype=istype, list=lambda *args: DMList(args),
                        typed_iter=lambda values, kind: (v for v in values if kind == "/atom/movable" or istype(v, kind)),
                        get_area=lambda value: value.area, AREA_OUTSIDE=1,
                        cardinal=((0, 1), (1, 0), (0, -1), (-1, 0)),
                        get_step=lambda t, d: self.grid.get((t.x+d[0], t.y+d[1], t.z)),
                        get_dist=lambda a, b: max(abs(a.x-b.x), abs(a.y-b.y)),
                        dm_range=lambda a, b: range(a, b+1),
                        locate=lambda x,y,z: self.grid.get((x,y,z)),
                        rand=self.rand, world=NS(maxx=500, maxy=350),
                        region_home_enabled=lambda: self.region,
                        IsGuestKey=lambda key: key.startswith('Guest'),
                        region_home_bed=lambda key: self.bed,
                        get_turf=lambda bed: bed.turf)
        for name, args in [('new_player_ground', 'T'), ('new_player_has_exit', 'start'),
                           ('pick_new_player_ground', ''), ('new_player_destination', 'lobby')]:
            body = adapter.extract(self.source.split('\n#undef GAIA_SURFACE_Z')[0], BASE+name)
            # Exactly translate DM type literals and finite integer loops. No
            # executable guards or branches are removed or reimplemented.
            body = re.sub(r'(?<![\w"\'])/(?:turf|area|obj|mob)(?:/\w+)+', lambda m: repr(m[0]), body)
            body = re.sub(r'for \(var/(\w+) = 1, \1 <= (GAIA_\w+), \1\+\+\)',
                          r'for (var/\1 in dm_range(1, \2))', body)
            fn = adapter.project(BASE+name+'()\n'+body+'\n', BASE+name, args, self.env)
            self.env[name] = fn
            setattr(self, name, fn)

    def rand(self, lo, hi):
        self.draw_count += 1
        value = self.draws.pop(0) if self.draws else lo
        assert lo <= value <= hi
        return value

    def patch(self, x=10, y=10, radius=5, z=2):
        for xx in range(x-radius, x+radius+1):
            for yy in range(y-radius, y+radius+1):
                self.grid[(xx,yy,z)] = tile(xx,yy,z)
        return self.grid[(x,y,z)]


class GaiaSpawn(unittest.TestCase):
    def test_ground_types_and_every_existing_climate(self):
        f = Fixture()
        for kind in ('grass', 'dirt', 'dirt/dry_lava', 'beach/sand', 'winter', 'gravel', 'rocky'):
            for climate in ('tundra','taiga','temperate','semiarid','sea','desert','savanna','jungle'):
                t = tile(kind='/turf/floor/'+kind)
                t.area.climate = climate
                self.assertTrue(f.new_player_ground(t), (kind, climate))

    def test_surface_sea_islands_and_swamp_ground_are_not_excluded(self):
        f=Fixture()
        for area,climate in (('/area/caribbean/sea/sea','sea'),('/area/caribbean/colonies/swamp','jungle')):
            t=tile(); t.area.kind=area; t.area.climate=climate
            self.assertTrue(f.new_player_ground(t))

    def test_rejects_water_void_walls_caves_other_levels_and_built_floors(self):
        f = Fixture()
        self.assertFalse(f.new_player_ground(None))
        for kind in ('/turf/wall', '/turf/open', '/turf/floor/beach/water',
                     '/turf/floor/beach/water/ice', '/turf/floor/lava',
                     '/turf/floor/dirt/underground/empty', '/turf/floor/wood'):
            self.assertFalse(f.new_player_ground(tile(kind=kind)), kind)
        for z in (1,3,4):
            self.assertFalse(f.new_player_ground(tile(z=z)))
        for field, value in [('density',True),('water_level',1),('watertile',True),
                             ('radiation',1),('to_be_destroyed',True)]:
            self.assertFalse(f.new_player_ground(tile(**{field:value})), field)
        for field,value in [('kind','/area/caribbean/admin'),('location',0),
                            ('is_void_area',True),('no_air',True),('has_gravity',False),
                            ('climate','unmapped')]:
            t=tile(); setattr(t.area, field, value)
            self.assertFalse(f.new_player_ground(t), field)

    def test_rechecks_dynamic_blockers_hazards_and_large_piles(self):
        f=Fixture(); t=tile()
        for kind in ('/mob/living/human','/obj/structure/wild/tallgrass','/obj/roof',
                     '/obj/covers','/obj/effect/fire','/obj/item/mine',
                     '/obj/item/weapon/beartrap'):
            t.contents=DMList([atom(kind)])
            self.assertFalse(f.new_player_ground(t), kind)
        for field in ('density','radiation'):
            blocker=atom('/obj/item'); setattr(blocker,field,True)
            t.contents=DMList([blocker]); self.assertFalse(f.new_player_ground(t))
        t.contents=DMList(atom('/obj/item') for _ in range(65))
        self.assertFalse(f.new_player_ground(t))
        t.contents=DMList([atom('/obj/item')])
        self.assertTrue(f.new_player_ground(t))

    def test_exit_requires_cardinal_clear_path_not_diagonal_or_trapped_pocket(self):
        f=Fixture(); start=f.patch(radius=1)
        self.assertFalse(f.new_player_has_exit(start))
        f=Fixture(); start=f.patch(radius=5)
        self.assertTrue(f.new_player_has_exit(start))
        for direction in f.env['cardinal']:
            f.grid[(start.x+direction[0],start.y+direction[1],2)].density=True
        self.assertFalse(f.new_player_has_exit(start))
        f.grid[(start.x+1,start.y,2)].density=False
        self.assertTrue(f.new_player_has_exit(start))

    def test_exit_membership_is_parenthesized_for_dm_precedence(self):
        # DM's `in` binds looser than `||`, so an unparenthesized membership test
        # turns the whole condition into `next in reachable` and skips the ground
        # check. The Python projection cannot see that, so pin the source form.
        source = (ROOT / PATH).read_text(encoding='utf-8')
        body = source.split(BASE + 'new_player_has_exit(', 1)[1].split('\n/', 1)[0]
        self.assertIn('(next in reachable)', body)
        for line in body.splitlines():
            if ' in ' in line and '||' in line:
                self.assertRegex(line, r'\([^()]* in [^()]*\)')

    def test_no_candidates_is_finite_and_has_no_landmark_fallback(self):
        f=Fixture()
        self.assertIsNone(f.pick_new_player_ground())
        self.assertEqual(f.draw_count, 512*2)
        body=adapter.extract(f.source,BASE+'pick_new_player_ground')
        self.assertNotIn('latejoin',body)
        self.assertNotIn('world.maxz',body)
        self.assertNotIn('sleep',body)

    def test_samples_full_coordinate_range_and_skips_invalid_draw(self):
        f=Fixture(); a=f.patch(1,1); b=f.patch(500,350)
        f.draws=[250,175,500,350]
        self.assertIs(f.pick_new_player_ground(),b)
        self.assertEqual(f.draw_count,4)
        f.draws=[1,1]
        self.assertIs(f.pick_new_player_ground(),a)
        # Enumerate all possible one-draw outcomes on a small eligible map.
        f=Fixture(); f.env['world']=NS(maxx=9,maxy=9); f.patch(5,5,4)
        selected=[]
        for x in range(1,10):
            for y in range(1,10):
                f.draws=[x,y]; selected.append(f.pick_new_player_ground())
        self.assertEqual({(t.x,t.y) for t in selected}, {(x,y) for x in range(1,10) for y in range(1,10)})

    def test_established_home_bed_and_guest_fallback(self):
        f=Fixture(); target=f.patch(); f.draws=[10,10]
        lobby=NS(client=NS(ckey='owner',key='Owner'))
        bed_turf=tile(z=1)
        f.bed=NS(turf=bed_turf,valid_character_bed=lambda human:True)
        f.region=True
        self.assertIs(f.new_player_destination(lobby),bed_turf)
        self.assertEqual(f.draw_count,0)
        lobby.client.key='Guest-1'
        self.assertIs(f.new_player_destination(lobby),target)

    def test_new_body_selected_after_reclaim_before_creation_and_handoff(self):
        src=(ROOT/'code/game/mob/new_player/new_player.dm').read_text()
        body=adapter.extract(src,'/mob/new_player/proc/create_character')
        self.assertLess(body.index('allow_new_character'),body.index('gaia.new_player_destination(src)'))
        self.assertLess(body.index('gaia.new_player_destination(src)'),body.index('new mobtype'))
        self.assertEqual(body.count('new mobtype(initial_location'),2)
        failure=body[body.index('if (!initial_location)'):body.index('if (delayed_spawning_as_job)')]
        for token in ('original_job.current_positions - 1','mind.assigned_role = null',
                      'mind.assigned_job = null','spawning = FALSE','ready = FALSE','return null'):
            self.assertIn(token,failure)
        self.assertNotIn('transfer_to',failure)
        join=adapter.extract(src,'/mob/new_player/proc/AttemptLateSpawn')
        self.assertIn('!map.uses_random_new_player_spawn(job_master.GetJob(rank))',join)
        relocate=adapter.extract((ROOT/'code/game/jobs/job_controller.dm').read_text(),
                                 '/datum/controller/occupations/proc/relocate')
        self.assertLess(relocate.index('uses_random_new_player_spawn'),relocate.index('latejoin_turfs'))

    def test_language_uses_birth_area_and_saved_identity_is_untouched(self):
        human=(ROOT/'code/game/mob/living/carbon/human/human.dm').read_text()
        self.assertIn('birth_area = get_area(new_loc)',human)
        self.assertIn('nomads_spawn(birth_area)',human)
        body=adapter.extract((ROOT/'code/game/mob/living/carbon/human/nomads_spawn.dm').read_text(),
                             '/mob/living/human/proc/nomads_spawn')
        self.assertLess(body.index('if(persistence_restored)'),body.index('var/area/mob_area'))
        self.assertIn('birth_area ? birth_area : get_area(src)',body)
        gaia=body[body.index('map.ID == MAP_NOMADS_CONTINENTAL'):body.index('else if (map.ID == MAP_NOMADS_EUROPE)')]
        for language in ('Old Norse','Latin','Egyptian','Japanese'):
            self.assertIn('add_language("'+language+'",TRUE)',gaia)

    def test_authored_map_surface_biomes_are_covered(self):
        import sys
        sys.path.insert(0,str(ROOT/'tools'))
        from mapmerge2.dmm import DMM
        m=DMM.from_file(str(ROOT/'maps/nomads/nomads_gaia.dmm'))
        self.assertEqual(m.size.z,2)
        areas=set()
        landmarks=0; outdoor=0
        for xyz,key in m.grid.items():
            entries=m.dictionary[key]
            if xyz[2] != 2: continue
            if any('JoinLateCiv' in p for p in entries): landmarks+=1
            if any(p.startswith('/turf/floor/grass') or p.startswith('/turf/floor/winter') for p in entries):
                outdoor+=1
                areas.update(p for p in entries if p.startswith('/area'))
        self.assertGreater(outdoor,10000)
        self.assertLess(landmarks, outdoor // 100)
        self.assertEqual(areas, {'/area/caribbean/nomads/'+p for p in
                         ('taiga','snow','forest','semiarid','desert','forest/Jungle','forest/savanna')} |
                         {'/area/caribbean/sea/sea','/area/caribbean/colonies/swamp','/area/caribbean/void/caves'})


if __name__ == '__main__':
    unittest.main()
