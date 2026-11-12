"""Source-projected frog Life control flow, with fake engine boundaries.

These offline models do not execute BYOND or establish native gameplay behavior.
"""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/mob/living/simple_animal/friendly/lizard.dm'
DECL = '/mob/living/simple_animal/frog/Life'
FROG = '/mob/living/simple_animal/frog'
spec = importlib.util.spec_from_file_location('source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


def run_life(source, occupants, rolls):
    """Project the entire Life body; substitute only external engine effects."""
    body = adapter.extract(source, DECL)
    body = body.replace('istype(loc, /turf/floor/beach/water)', 'istype(loc, WATER)')
    body = body.replace('new/obj/item/weapon/reagent_containers/food/snacks/frogegg', 'egg')
    body = body.replace('..()', 'parent()')
    events, visits = [], []
    rolls = iter(rolls)
    src = SimpleNamespace(loc='land')

    def prob(chance):
        events.append(('prob', chance))
        return next(rolls)

    def typed_iter(items, kind):
        for item in items:
            if item == kind or item.startswith(kind + '/'):
                if kind == FROG:
                    visits.append(item)
                yield item

    env = dict(src=src, loc=src.loc, WATER='water', move_to_delay=1,
               range=lambda distance, actor: occupants,
               typed_iter=typed_iter, prob=prob,
               isturf=lambda loc: loc == 'land', istype=lambda loc, kind: loc == kind,
               egg=lambda loc: events.append(('egg', loc)),
               parent=lambda: events.append(('parent',)),
               npc_subtile_contact_settled=lambda mob: False,
               visible_message=lambda message: events.append(('message', message)),
               qdel=lambda mob: events.append(('qdel', mob)),
               adjustBruteLoss=lambda amount: events.append(('heal', amount)),
               walk_towards=lambda *args: events.append(('walk',)),
               deferred=lambda delay: False)
    proc = adapter.project('/proc/projected()\n' + body + '\n', '/proc/projected', '', env)
    proc()
    return events, visits


class FrogBreedingCountTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = SOURCE.read_text(encoding='utf-8')
        cls.guard = '\t\t\tif (frogCount > 2)\n\t\t\t\tbreak\n'
        if cls.guard not in cls.source:
            raise AssertionError('Expected frog count guard directly after increment')
        cls.original = cls.source.replace(cls.guard, '', 1)

    def occupants(self, count):
        # Nonfrogs and a frog subtype exercise the typed range iteration.
        frogs = [FROG if i % 2 == 0 else FROG + '/poisonous' for i in range(count)]
        return ['/obj/item', '/mob/living/simple_animal/fly'] + frogs + ['/mob/living/simple_animal/goat']

    def test_threshold_matches_original_and_stops_after_third_frog(self):
        for count in (0, 1, 2, 3, 20):
            with self.subTest(count=count):
                occupants = self.occupants(count)
                events, visits = run_life(self.source, occupants, [True, True])
                old_events, old_visits = run_life(self.original, occupants, [True, True])
                self.assertEqual(events, old_events)
                self.assertEqual(events, [('prob', 1), ('prob', 17)] +
                                 ([('egg', 'land')] if count <= 2 else []) + [('parent',)])
                self.assertEqual(len(visits), min(count, 3))
                self.assertEqual(len(old_visits), count)

    def test_probability_short_circuit_and_parent_are_preserved(self):
        for rolls, expected in (([False], [('prob', 1), ('parent',)]),
                                ([True, False], [('prob', 1), ('prob', 17), ('parent',)])):
            for source in (self.original, self.source):
                events, visits = run_life(source, self.occupants(20), rolls)
                self.assertEqual(events, expected)
                self.assertEqual(visits, [])

    def test_breaking_at_two_is_a_detected_regression(self):
        mutant = self.source.replace('if (frogCount > 2)', 'if (frogCount >= 2)', 1)
        events, visits = run_life(mutant, self.occupants(3), [True, True])
        expected, _ = run_life(self.original, self.occupants(3), [True, True])
        self.assertIn(('egg', 'land'), events)
        self.assertNotEqual(events, expected)
        self.assertEqual(len(visits), 2)


if __name__ == '__main__':
    unittest.main()

