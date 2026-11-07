"""Execute complete production movement predicates with fake engine boundaries.

Offline control-flow evidence only: no BYOND, native collision, savefile or
connected-client claims. The shared adapter rejects unsupported source syntax.
"""
import importlib.util
from pathlib import Path
import re
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
ANIMAL = '/mob/living/simple_animal'
WATER = '/turf/floor/beach/water'
DEEP = WATER + '/deep'
FAMILY = ('chick', 'chicken', 'rooster')
ANIMAL_PATH = 'code/game/mob/living/simple_animal/simple_animal.dm'
BIRDS_PATH = 'code/game/mob/living/simple_animal/friendly/birds.dm'
FLOOR_PATH = 'code/game/turfs/floor_types.dm'
SOURCES = {path: (ROOT / path).read_text() for path in (ANIMAL_PATH, BIRDS_PATH, FLOOR_PATH)}
spec = importlib.util.spec_from_file_location('chicken_water_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


def istype(value, kind):
    return value is not None and (value.kind == kind or value.kind.startswith(kind + '/'))


class DMList(list):
    def __iadd__(self, value):
        self.append(value)
        return self


class Turf:
    def __init__(self, harness, kind='/turf/floor/grass', density=False, covers=()):
        self.harness, self.kind, self.density = harness, kind, density
        self.contents = [SimpleNamespace(kind=kind) for kind in covers]

    def iscovered(self):
        return self.harness.call(FLOOR_PATH, '/turf/proc/iscovered', '',
                                 dict(src=self, typed_iter=lambda items, kind: [x for x in items if istype(x, kind)]))


class Harness:
    def __init__(self, sources=None):
        self.sources = dict(SOURCES if sources is None else sources)
        self.neighbors = {}
        self.steps = []

    def call(self, path, declaration, args, env, *values):
        body = adapter.extract(self.sources[path], declaration)
        # Replace only absolute type literals and the inherited engine boundary.
        # Typed local/loop declarations are handled by the shared DM adapter.
        body = re.sub(r'(?<![\w])/(?:[A-Za-z_]\w*/)*[A-Za-z_]\w*', lambda m: repr(m[0]), body)
        body = body.replace('..()', 'parent()')
        proc = adapter.project('/proc/projected_target()\n' + body + '\n',
                               '/proc/projected_target', args, dict(istype=istype, **env))
        return proc(*values)

    def animal(self, kind='chicken', flying=True):
        animal = SimpleNamespace(kind=ANIMAL + '/' + kind, flying=flying, loc=Turf(self))
        animal.can_cross_deep_water = lambda: self.crosses(animal)
        return animal

    def crosses(self, animal):
        kind = animal.kind
        while kind != ANIMAL:
            declaration = kind + '/can_cross_deep_water'
            if declaration + '()' in self.sources[BIRDS_PATH]:
                return self.call(BIRDS_PATH, declaration, '', dict(flying=animal.flying))
            kind = kind.rsplit('/', 1)[0]
        return self.call(ANIMAL_PATH, ANIMAL + '/proc/can_cross_deep_water', '', dict(flying=animal.flying))

    def directions(self, animal):
        return self.call(ANIMAL_PATH, ANIMAL + '/proc/get_valid_move_dirs', '',
                         dict(src=animal, cardinal=(1, 2, 4, 8), list=DMList,
                              flying=animal.flying, can_cross_deep_water=animal.can_cross_deep_water,
                              get_step=lambda actor, direction: self.neighbors.get(direction)))

    def can_pass(self, turf, mover):
        if not istype(turf, DEEP):
            return not turf.density  # Unchanged engine parent boundary.
        return self.call(FLOOR_PATH, DEEP + '/CanPass', 'mover',
                         dict(iscovered=turf.iscovered, parent=lambda: not turf.density,
                              ishuman=lambda value: istype(value, '/mob/living/human')), mover)

    def step(self, animal, turf, interval):
        self.steps.append((turf, interval))
        if not self.can_pass(turf, animal):
            return False
        animal.loc = turf
        return True

    def smart_step(self, animal, turf):
        return self.call(ANIMAL_PATH, ANIMAL + '/proc/smart_step_towards', 'target',
                         dict(src=animal, loc=animal.loc, move_to_delay=3,
                              get_step_towards2=lambda actor, target: turf,
                              isturf=lambda value: isinstance(value, Turf),
                              ai_step=lambda target, interval: self.step(animal, target, interval)), turf)


class ChickenWaterTests(unittest.TestCase):
    def test_all_chicken_types_and_descendants_reject_saved_flying_values(self):
        h = Harness()
        for species in FAMILY:
            for kind in (species, species + '/future_subtype'):
                for flying in (False, True, 1, 99):
                    with self.subTest(kind=kind, flying=flying):
                        bird = h.animal(kind, flying)
                        self.assertFalse(bird.can_cross_deep_water())
                        self.assertFalse(h.can_pass(Turf(h, DEEP), bird))
                        self.assertEqual(bird.flying, flying)

    def test_every_deep_turf_and_gaia_ocean_uses_the_restriction(self):
        types = set(re.findall(r'^(' + re.escape(DEEP) + r'(?:/\w+)*)$', SOURCES[FLOOR_PATH], re.M))
        self.assertTrue({DEEP, DEEP + '/saltwater', DEEP + '/saltwater/shipline',
                         DEEP + '/saltwater/underwater', DEEP + '/jungle', DEEP + '/swamp'} <= types)
        gaia = (ROOT / 'maps/nomads/nomads_gaia.dmm').read_text()
        mapped = set(re.findall(re.escape(DEEP) + r'(?:/\w+)*', gaia))
        self.assertTrue(mapped)
        self.assertTrue(mapped <= types)
        h = Harness()
        for kind in types:
            for species in FAMILY:
                bird, ocean = h.animal(species), Turf(h, kind)
                h.neighbors = {1: ocean}
                with self.subTest(turf=kind, species=species):
                    self.assertEqual(h.directions(bird), [])
                    self.assertFalse(h.can_pass(ocean, bird))

    def test_wandering_keeps_land_shallows_and_covered_water(self):
        h = Harness()
        for species in FAMILY:
            bird = h.animal(species)
            h.neighbors = {1: Turf(h), 2: Turf(h, WATER + '/shallowsaltwater'),
                           4: Turf(h, DEEP), 8: Turf(h, DEEP, covers=('/obj/covers/wood',))}
            self.assertEqual(h.directions(bird), [1, 2, 8])
            h.neighbors = {1: Turf(h, density=True), 2: None,
                           4: Turf(h, '/turf/floor/broken_floor'), 8: Turf(h, DEEP)}
            self.assertEqual(h.directions(bird), [])

    def test_existing_bridges_boats_and_other_cover_types_remain_passable(self):
        covers = re.findall(r'for\s*\(var(/[^\s]+)/\w+ in src.contents\)',
                            adapter.extract(SOURCES[FLOOR_PATH], '/turf/proc/iscovered'))
        self.assertEqual(len(covers), 8)
        self.assertIn('/obj/covers', covers)
        self.assertIn('/obj/structure/vehicle/boat', covers)
        self.assertIn('/obj/structure/vehicle/raft', covers)
        for cover in covers:
            for species in FAMILY:
                h = Harness()
                bird, bridge = h.animal(species), Turf(h, DEEP + '/saltwater', covers=(cover,))
                h.neighbors = {1: bridge}
                self.assertEqual(h.directions(bird), [1])
                self.assertTrue(h.can_pass(bridge, bird))
                bridge.contents.clear()
                self.assertFalse(h.can_pass(bridge, bird))

    def test_other_fliers_and_ground_animals_keep_their_previous_policy(self):
        h = Harness()
        for species in ('parrot', 'turkey_f', 'turkey_m', 'turkeychick', 'duck', 'bat', 'goat'):
            for flying in (False, True):
                bird, ocean = h.animal(species, flying), Turf(h, DEEP)
                h.neighbors = {1: ocean}
                self.assertEqual(bird.can_cross_deep_water(), flying)
                self.assertEqual(h.can_pass(ocean, bird), flying)
                self.assertEqual(h.directions(bird), [1] if flying else [])

    def test_targeted_food_step_cannot_bypass_turf_collision(self):
        h = Harness()
        for species in FAMILY:
            bird, ocean = h.animal(species), Turf(h, DEEP)
            before = bird.loc
            self.assertFalse(h.smart_step(bird, ocean))
            self.assertIs(bird.loc, before)
            self.assertEqual(h.steps[-1], (ocean, 3))
            shore = Turf(h, WATER)
            self.assertTrue(h.smart_step(bird, shore))
            self.assertIs(bird.loc, shore)

    def test_already_stranded_birds_can_leave_for_land_without_relocation(self):
        h = Harness()
        for species in FAMILY:
            bird = h.animal(species)
            bird.loc = Turf(h, DEEP)
            shore = Turf(h)
            h.neighbors = {1: shore, 2: Turf(h, DEEP)}
            self.assertEqual(h.directions(bird), [1])
            self.assertTrue(h.smart_step(bird, shore))
            self.assertIs(bird.loc, shore)

    def test_humans_projectiles_and_smoke_are_unchanged(self):
        h = Harness()
        ocean = Turf(h, DEEP)
        human = SimpleNamespace(kind='/mob/living/human', wear_suit=None)
        self.assertFalse(h.can_pass(ocean, human))
        human.wear_suit = SimpleNamespace(kind='/obj/item/clothing/suit/lifejacket')
        self.assertTrue(h.can_pass(ocean, human))
        for kind in ('/obj/item/projectile', '/obj/effect/effect/smoke', '/obj/item'):
            self.assertTrue(h.can_pass(ocean, SimpleNamespace(kind=kind)))

    def test_native_movement_and_ai_wiring_keep_the_shared_checks(self):
        turf = (ROOT / 'code/game/turfs/turf.dm').read_text()
        self.assertIn('if (!CanPass(mover, src))\n\t\tmover.Bump(src, TRUE)\n\t\treturn FALSE', turf)
        ai = (ROOT / 'code/game/mob/living/simple_animal/simple_ai.dm').read_text()
        wander = ai.split('\t\tif ("wander")\n', 1)[1].split('\t\tif ("hunt",', 1)[0]
        self.assertIn('var/list/valid_dirs = get_valid_move_dirs()', wander)
        self.assertIn('var/moving_to = pick(valid_dirs)', wander)
        self.assertIn('ai_step(get_step(src, moving_to), move_to_delay)', wander)
        pathfinding = (ROOT / 'code/pathfinding.dm').read_text()
        passable = adapter.extract(pathfinding, '/proc/checkTurfPassable')
        self.assertIn('if(istype(T, /turf/floor/beach/water/deep))\n\t\treturn FALSE', passable)
        self.assertLess(passable.index('if(T.iscovered())'), passable.index('if(istype(T, /turf/floor/beach/water/deep))'))

    def test_removing_species_policy_or_either_call_site_reproduces_bug(self):
        for species in FAMILY:
            sources = dict(SOURCES)
            declaration = ANIMAL + '/' + species + '/can_cross_deep_water()\n\treturn FALSE\n'
            self.assertIn(declaration, sources[BIRDS_PATH])
            sources[BIRDS_PATH] = sources[BIRDS_PATH].replace(declaration, '')
            h = Harness(sources)
            bird, ocean = h.animal(species), Turf(h, DEEP)
            h.neighbors = {1: ocean}
            self.assertEqual(h.directions(bird), [1])
            self.assertTrue(h.can_pass(ocean, bird))
        sources = dict(SOURCES)
        sources[ANIMAL_PATH] = sources[ANIMAL_PATH].replace('!can_cross_deep_water()', '!flying')
        h = Harness(sources)
        h.neighbors = {1: Turf(h, DEEP)}
        self.assertEqual(h.directions(h.animal()), [1])
        sources = dict(SOURCES)
        sources[FLOOR_PATH] = sources[FLOOR_PATH].replace('SA.can_cross_deep_water()', 'SA.flying')
        h = Harness(sources)
        bird, ocean = h.animal(), Turf(h, DEEP)
        self.assertTrue(h.smart_step(bird, ocean))


if __name__ == '__main__':
    unittest.main()
