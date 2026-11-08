"""Cotton is only food for ruminants.

Offline source/control-flow evidence: the production animal_can_eat() body is
executed through the shared DM source adapter with fake types, and the AI and
hand-feeding call sites are checked for the guard. No BYOND or game is launched.
"""
import importlib.util
from pathlib import Path
import re
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
ANIMAL = '/mob/living/simple_animal'
SA = 'code/game/mob/living/simple_animal/simple_animal.dm'
AI = 'code/game/mob/living/simple_animal/simple_ai.dm'
spec = importlib.util.spec_from_file_location('animal_cotton_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)

COTTON_PLANT = '/obj/structure/farming/plant/cotton'
COTTON_SEEDS = '/obj/item/stack/farming/seeds/cotton'
RUMINANTS = {
    'code/game/mob/living/simple_animal/friendly/farm_animals.dm': ('cattle', 'goat', 'sheep', 'camel'),
    'code/game/mob/living/simple_animal/friendly/deer.dm': ('deer',),
    'code/game/mob/living/simple_animal/hostile/buffalo.dm': ('hostile/buffalo', 'bison', 'bisonbull'),
}


def istype(value, kind):
    return value.kind == kind or value.kind.startswith(kind + '/')


def type_block(source, path):
    match = re.search(r'^' + re.escape(path) + r'\n((?:[ \t]+[^\n]*\n|\n(?=[ \t]))*)', source, re.M)
    if not match:
        raise AssertionError(f'missing {path}')
    return match[1]


def can_eat(ruminant, kind):
    source = adapter.read(SA)
    body = adapter.extract(source, ANIMAL + '/proc/animal_can_eat')
    body = re.sub(r'(?<![\w"])/(?:[A-Za-z_]\w*/)*[A-Za-z_]\w*', lambda m: repr(m[0]), body)
    proc = adapter.project('/proc/projected_target(atom/food)\n' + body + '\n', '/proc/projected_target',
                           'food', dict(istype=istype, ruminant=ruminant))
    return proc(SimpleNamespace(kind=kind))


class AnimalCottonTest(unittest.TestCase):
    def test_only_ruminants_eat_cotton(self):
        for kind in (COTTON_PLANT, COTTON_SEEDS):
            self.assertFalse(can_eat(False, kind), kind)
            self.assertTrue(can_eat(True, kind), kind)

    def test_other_food_unchanged(self):
        for kind in ('/obj/structure/farming/plant/wheat', '/obj/item/stack/farming/seeds/wheat',
                     '/obj/item/weapon/reagent_containers/food/snacks/grown/wheat'):
            self.assertTrue(can_eat(False, kind), kind)

    def test_ai_skips_inedible_crops_and_seeds(self):
        body = adapter.extract(adapter.read(AI), ANIMAL + '/proc/check_food')
        for loop in (r'for \(var/obj/item/stack/farming/seeds/SD in range\(2, src\)\)\n\t+if \(!animal_can_eat\(SD\)\)\n\t+continue',
                     r'for \(var/obj/structure/farming/plant/PL in range\(2, src\)\)\n\t+if \(!animal_can_eat\(PL\)\)\n\t+continue',
                     r'for \(var/obj/structure/farming/plant/PL in range\(8, src\)\)\n\t+if \(!animal_can_eat\(PL\)\)\n\t+continue'):
            self.assertRegex(body, loop)

    def test_hand_feeding_refuses_inedible(self):
        body = adapter.extract(adapter.read(SA), ANIMAL + '/proc/feed')
        self.assertRegex(body, r'^\tif \(stat == CONSCIOUS\)\n\t\tif \(!animal_can_eat\(O\)\)\n[^\n]*\n\t\t\treturn')

    def test_ruminants_flagged(self):
        self.assertRegex(adapter.read(SA), r'\n\tvar/ruminant = FALSE\b')
        for path, kinds in RUMINANTS.items():
            source = adapter.read(path)
            for kind in kinds:
                self.assertIn('\truminant = TRUE\n', type_block(source, ANIMAL + '/' + kind), kind)

    def test_crop_eaters_are_not_ruminants(self):
        # Pigs, boars, rabbits, mice, birds, monkeys, gorillas, mammoths: none may opt in.
        for path in (ROOT / 'code').rglob('*.dm'):
            source = path.read_text(encoding='utf-8-sig', errors='replace')
            for match in re.finditer(r'^(/mob/living/simple_animal/[\w/]+)\n', source, re.M):
                block = type_block(source, match[1])
                if re.search(r'^\tgranivore = 1', block, re.M):
                    self.assertNotIn('\truminant = TRUE', block, match[1])


if __name__ == '__main__':
    unittest.main()
