"""Offline control-flow checks for predator feeding; does not execute BYOND."""
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/mob/living/simple_animal/hostile/tactical_ai.dm'
DECLARATION = '/mob/living/simple_animal/proc/predator_feeding_tick'
spec = spec_from_file_location('source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = module_from_spec(spec)
spec.loader.exec_module(adapter)


def run_prefix(source, *, distance=0, invalid=None, moving=False, same_target=False):
    # Project the complete admission/movement prefix. Eating remains outside this fixture.
    body = adapter.extract(source, DECLARATION)
    marker = '\tif (world.time < next_melee_attack)'
    if body.count(marker) != 1:
        raise AssertionError('Feeding prefix boundary changed')
    prefix = DECLARATION + '()\n' + body.split(marker)[0] + '\treturn "eat"\n'
    events = []
    carcass = SimpleNamespace(stat=1, loc='turf', deleted=False)
    animal = object()
    context = dict(feeding_on=carcass, stat=0, client=None, simplehunger=0,
                   predator_sated_hunger=10, moving=moving,
                   target_obj=carcass if same_target else None, src=animal)
    if invalid == 'missing':
        context['feeding_on'] = None
    elif invalid == 'deleted':
        carcass.deleted = True
    elif invalid == 'alive':
        carcass.stat = 0
    elif invalid == 'location':
        carcass.loc = 'container'
    elif invalid == 'unconscious':
        context['stat'] = 1
    elif invalid == 'client':
        context['client'] = object()
    elif invalid == 'sated':
        context['simplehunger'] = 10
    def get_dist(src, corpse):
        assert src is animal and corpse is carcass
        events.append('distance')
        return distance
    env = dict(DEAD=1, CONSCIOUS=0, QDELETED=lambda c: c.deleted,
               isturf=lambda loc: loc == 'turf', get_dist=get_dist,
               stop_feeding=lambda: events.append('stop'),
               do_movement=lambda c: events.append('move') if c is carcass else None)
    proc = adapter.project(prefix, DECLARATION, ', '.join(context), env)
    return proc(**context), events


class PredatorFeeding(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = SOURCE.read_text(encoding='utf-8-sig')

    def test_invalid_feeding_stops_before_distance_query(self):
        for invalid in ('missing', 'deleted', 'alive', 'location', 'unconscious', 'client', 'sated'):
            with self.subTest(invalid=invalid):
                result, events = run_prefix(self.source, invalid=invalid)
                self.assertFalse(result)
                self.assertEqual(events, [] if invalid == 'missing' else ['stop'])

    def test_distance_boundaries_and_existing_pursuit(self):
        for distance, expected, events in ((0, 'eat', ['distance']), (1, 'eat', ['distance']),
                                          (2, True, ['distance', 'move']), (7, True, ['distance', 'move']),
                                          (8, False, ['distance', 'stop'])):
            with self.subTest(distance=distance):
                self.assertEqual(run_prefix(self.source, distance=distance), (expected, events))
        self.assertEqual(run_prefix(self.source, distance=2, moving=True, same_target=True),
                         (True, ['distance']))
        self.assertEqual(run_prefix(self.source, distance=2, moving=True, same_target=False),
                         (True, ['distance', 'move']))

    def test_boundary_mutations_are_detected(self):
        for original, mutant, distance in (('distance > 7', 'distance >= 7', 7),
                                           ('distance > 1', 'distance >= 1', 1)):
            self.assertEqual(self.source.count(original), 1)
            self.assertNotEqual(run_prefix(self.source, distance=distance),
                                run_prefix(self.source.replace(original, mutant, 1), distance=distance))


if __name__ == '__main__':
    unittest.main()
