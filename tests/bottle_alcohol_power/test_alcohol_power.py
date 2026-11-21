"""Offline projection of the bottle alcohol-power procs, not BYOND execution."""
import copy
import importlib.util
import re
import unittest
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
SOURCE_PATH = ROOT / 'code/modules/reagents/reagent_containers/food/drinks/bottle.dm'
spec = importlib.util.spec_from_file_location('source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
BOTTLE = '/obj/item/weapon/reagent_containers/food/drinks/bottle/proc/'


class Reagent:
    def __init__(self, strength, volume):
        self.strength = strength
        self.volume = volume


class Ethanol(Reagent):
    pass


def holder(*reagents):
    return SimpleNamespace(reagent_list=list(reagents))


def typed_iter(values, path):
    if path != '/datum/reagent':
        raise AssertionError('Unexpected DM loop type: ' + path)
    return (value for value in values if isinstance(value, Reagent))


def compile_proc(source, name, args, env):
    # The common projector handles the complete procedure body. Map DM's
    # implicit return variable and path literal to their Python equivalents,
    # then make the implicit return explicit; no executable DM lines are removed.
    body = adapter.extract(source, BOTTLE + name)
    body = re.sub(r'(?<!\w)\.(?!\w)', 'dm_result', body)
    body = body.replace('/datum/reagent/ethanol)', 'ETHANOL_TYPE)')
    projected = '/proc/selected()\n' + body + '\n\treturn dm_result\n'
    return adapter.project(projected, '/proc/selected', args, env)


def projected_calculator(source):
    env = {
        'min': min,
        'max': max,
        'ETHANOL_TYPE': Ethanol,
        'istype': isinstance,
        'typed_iter': typed_iter,
    }
    env['accumulate_alcohol_power'] = compile_proc(source, 'accumulate_alcohol_power', 'holder, power', env)
    return compile_proc(source, 'calculate_alcohol_power', 'reagents, rag', env)


class BottleAlcoholPower(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = SOURCE_PATH.read_text(encoding='utf-8-sig')
        cls.calculate = staticmethod(projected_calculator(cls.source))

    def test_missing_and_empty_holders(self):
        for bottle, rag in ((None, None), (holder(), None), (None, SimpleNamespace(reagents=None)),
                            (None, SimpleNamespace(reagents=holder())), (holder(), SimpleNamespace(reagents=holder()))):
            with self.subTest(bottle=bottle, rag=rag):
                self.assertEqual(self.calculate(bottle, rag), 0)

    def test_each_holder_is_counted_and_non_ethanol_is_ignored(self):
        bottle = holder(Ethanol(30, 2), Reagent(1000, 100), Ethanol(50, 3))
        rag = SimpleNamespace(reagents=holder(Reagent(1000, 100), Ethanol(40, 4)))
        bottle_list = bottle.reagent_list
        rag_list = rag.reagents.reagent_list
        originals = tuple(bottle_list), tuple(rag_list)
        before = copy.deepcopy((bottle, rag))
        self.assertEqual(self.calculate(bottle, None), 210)
        self.assertEqual(self.calculate(None, rag), 160)
        self.assertEqual(self.calculate(bottle, rag), 370)
        self.assertIs(bottle.reagent_list, bottle_list)
        self.assertIs(rag.reagents.reagent_list, rag_list)
        self.assertEqual((tuple(bottle_list), tuple(rag_list)), originals)
        for actual, saved in zip((bottle, rag.reagents), (before[0], before[1].reagents)):
            self.assertEqual([(type(x), x.strength, x.volume) for x in actual.reagent_list],
                             [(type(x), x.strength, x.volume) for x in saved.reagent_list])

    def test_same_holder_in_both_locations_is_counted_twice(self):
        shared = holder(Ethanol(30, 2))
        self.assertEqual(self.calculate(shared, SimpleNamespace(reagents=shared)), 120)

    def test_strength_clamp_boundaries_and_volume_weight(self):
        for strength, expected in ((-10, 25), (24, 25), (25, 25), (26, 26),
                                   (49, 49), (50, 50), (51, 50), (100, 50)):
            with self.subTest(strength=strength):
                self.assertEqual(self.calculate(holder(Ethanol(strength, 3)), None), expected * 3)

    def test_running_total_is_accumulated_bottle_first(self):
        # Each small contribution is rounded away individually in the Python
        # projection. Subtotaling the rag separately first would add four.
        large = float(2**54)
        bottle = holder(Ethanol(25, large / 25))
        rag = SimpleNamespace(reagents=holder(*(Ethanol(25, 1 / 25) for _ in range(4))))
        self.assertEqual(self.calculate(bottle, rag), large)
        self.assertNotEqual(large + sum(25 * x.volume for x in rag.reagents.reagent_list), large)

    def test_negative_controls_detect_changed_policy(self):
        clamp_mutant = self.source.replace('min(max(E.strength, 25), 50)', 'min(max(E.strength, 20), 50)', 1)
        self.assertNotEqual(clamp_mutant, self.source)
        self.assertNotEqual(projected_calculator(clamp_mutant)(holder(Ethanol(10, 1)), None), 25)
        rag_mutant = self.source.replace('if (rag && rag.reagents)', 'if (FALSE && rag.reagents)', 1)
        self.assertNotEqual(rag_mutant, self.source)
        self.assertNotEqual(projected_calculator(rag_mutant)(None, SimpleNamespace(reagents=holder(Ethanol(30, 1)))), 30)


if __name__ == '__main__':
    unittest.main()
