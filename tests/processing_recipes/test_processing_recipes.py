"""Station recipes (mortar grinding, flint and obsidian knapping) are rows in
code/modules/1713/processing_recipes.dm instead of if-chains in each station.

FROZEN is what the old chains in herbalism.dm, flint_mining.dm,
stone_age_arms.dm and obsidian.dm gave: menu order, product, amount, work time,
failure chance and whether the product needed its research. The test parses
the registry and checks the stations read it, and that the Crafting Atlas
extractor reads the same rows.
"""
from pathlib import Path
import importlib.util
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / 'code/modules/1713/processing_recipes.dm'
GROWN = '/obj/item/weapon/reagent_containers/food/snacks/grown/'

FROZEN = {
    'mortar': [
        (None, GROWN + 'wheat', 'flour', 5, 0, 0, False),
        (None, GROWN + 'oat', 'oatflour', 5, 0, 0, False),
        (None, GROWN + 'barley', 'barleyflour', 5, 0, 0, False),
        (None, GROWN + 'sunflower_seeds', 'sunflower_oil', 5, 0, 0, False),
        (None, '/obj/item/stack/farming/seeds/flax', 'linseed_oil', 2, 0, 0, False),
        (None, GROWN + 'olives', 'olive_oil', 6, 0, 0, False),
        (None, '/obj/item/weapon/reagent_containers/food/snacks/roasted_coffee', 'coffee_grounds', 3, 0, 0, False),
        (None, '/obj/item/stack/material/poppy', 'poppy_straw', 3, 0, 0, False),
        (None, '/obj/item/stack/material/coca', 'coca_leaf', 3, 0, 0, False),
        (None, '/obj/item/stack/material/cannabis', 'thc', 3, 0, 0, False),
    ],
    'flint knapping': [
        ('Sharp flake', '/obj/item/weapon/flint', None, 1, 40, 10, False),
        ('Three arrowheads', '/obj/item/weapon/flint', '/obj/item/stack/arrowhead/flint', 3, 60, 25, False),
        ('Flint knife', '/obj/item/weapon/flint', '/obj/item/weapon/material/kitchen/utensil/knife/flint', 1, 80, 35, False),
        ('Spearhead', '/obj/item/weapon/flint', '/obj/item/weapon/flint_spearhead', 1, 80, 30, False),
        ('Sickle teeth', '/obj/item/weapon/flint', '/obj/item/weapon/flint_sickle_teeth', 1, 70, 25, False),
        ('Hand axe', '/obj/item/weapon/flint', '/obj/item/weapon/material/hatchet/tribal/hand_axe', 1, 100, 30, True),
        ('Hide scraper', '/obj/item/weapon/flint', '/obj/item/weapon/material/hide_scraper', 1, 50, 15, True),
    ],
    'obsidian knapping': [
        ('Sharp flake', '/obj/item/weapon/obsidian_nodule', '/obj/item/weapon/obsidian_flake', 1, 40, 5, False),
        ('Five arrowheads', '/obj/item/weapon/obsidian_nodule', '/obj/item/stack/arrowhead/obsidian', 5, 60, 20, False),
        ('Knife', '/obj/item/weapon/obsidian_nodule', '/obj/item/weapon/material/kitchen/utensil/knife/obsidian', 1, 80, 30, False),
        ('Spearhead', '/obj/item/weapon/obsidian_nodule', '/obj/item/weapon/obsidian_spearhead', 1, 80, 25, False),
        ('Scraper', '/obj/item/weapon/obsidian_nodule', '/obj/item/weapon/material/hide_scraper/obsidian', 1, 50, 10, True),
        ('Blade core', '/obj/item/weapon/obsidian_nodule', '/obj/item/weapon/obsidian_core', 1, 100, 25, True),
    ],
}

sys.path.insert(0, str(ROOT / 'scripts'))
from atlas.interactions import registry_rows  # noqa: E402

spec = importlib.util.spec_from_file_location('source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
action_adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(action_adapter)


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


class ProcessingRecipeTest(unittest.TestCase):
    def test_rows_match_the_old_chains(self):
        source = REGISTRY.read_text(encoding='utf-8')
        for station, rows in FROZEN.items():
            found = [(r['choice'], r['input'], r['output'], r['amount'], r['delay'], r['fail'], r['gated'])
                     for r in registry_rows(source, station)]
            self.assertEqual(found, rows, station)

    def test_stations_read_the_registry(self):
        herbs = read('code/modules/1713/herbalism.dm')
        grind = herbs[herbs.index('/proc/mortar_grind_result('):herbs.index('/obj/item/weapon/reagent_containers/glass/mortar/attackby')]
        self.assertIn('processing_recipe_for_input("mortar", I)', grind)
        self.assertNotIn('istype(', grind)
        for path, station in (('code/modules/1713/flint_mining.dm', 'flint knapping'),
                              ('code/modules/1713/obsidian.dm', 'obsidian knapping')):
            text = read(path)
            self.assertIn(f'processing_recipe_choices("{station}", H)', text)
            self.assertIn(f'processing_recipe_choice("{station}", choice)', text)
            self.assertIn('var/obj/item/result = processing_recipe_make(R, T, H)', text)
            self.assertNotIn('switch (choice)', text[text.index('/proc/knap('):].split('\n/', 1)[0])
        self.assertNotIn('stone_age_knap', read('code/modules/1713/stone_age_arms.dm'))

    def test_refused_and_special_rows(self):
        source = REGISTRY.read_text(encoding='utf-8')
        make = source[source.index('/proc/processing_recipe_make('):]
        self.assertIn('if (!R || !ispath(R.output) || !processing_recipe_allowed(R, H))', make)
        flint = read('code/modules/1713/flint_mining.dm')
        knap = flint[flint.index('/obj/item/weapon/flint/proc/knap('):].split('\n/', 1)[0]
        self.assertIn('if (sharpened)\n\t\toptions -= "Sharp flake"', knap)
        self.assertLess(knap.index('if (!R.output)\n\t\tsharpen()'), knap.index('processing_recipe_make(R, T, H)'))



class MortarGrindContract(unittest.TestCase):
    """Execute both grind bodies and the shared access check with fake engine boundaries."""

    def setUp(self):
        from types import SimpleNamespace
        self.state = SimpleNamespace(grinding=False, deleted=False, opened=True)
        self.worker_tile = ('turf', 0, 0, 1)
        self.near = ('turf', 1, 0, 1)
        self.far = ('turf', 4, 0, 1)
        self.user = SimpleNamespace(loc=self.worker_tile, visible_message=lambda *args: None)
        self.carrier = SimpleNamespace(loc=self.near)
        self.bag = SimpleNamespace(loc=self.near, storage=True)
        self.state.loc = self.near
        self.noop = lambda: None
        self.on_wait = self.noop
        self.waits = 0
        self.messages = []
        self.flour = []
        self.pigments = []
        self.space = 30
        self.state.reagents = SimpleNamespace(
            get_free_space=lambda: self.space,
            add_reagent=lambda reagent, amount: self.flour.append((reagent, amount)),
        )
        self.user.put_in_hands = self.pigments.append

        def turf(value):
            return isinstance(value, tuple) and value[0] == 'turf'

        def depth(container=None):
            found = self.state
            count = 0
            while found is not None and not turf(found):
                parent = found.loc
                if container is not None and parent is container:
                    return count
                count += int(getattr(parent, 'storage', False))
                found = parent
            return count if container is None and turf(found) else -1

        def adjacent(user):
            place = self.state.loc
            if place is user:
                return True
            if getattr(place, 'storage', False):
                place = place.loc  # item Adjacent recurses into one item
            if place is user:
                return True
            return (
                turf(place) and turf(user.loc) and place[3] == user.loc[3]
                and max(abs(place[1] - user.loc[1]), abs(place[2] - user.loc[2])) <= 1
            )

        def wait(user, delay, target):
            self.waits += 1
            original_location = target.loc
            self.on_wait()
            return target.loc is original_location  # no check of carrier or lid here

        env = {
            'QDELETED': lambda thing: thing is None or getattr(thing, 'deleted', False),
            'is_open_container': lambda: self.state.opened,
            'storage_depth': depth, 'storage_depth_turf': depth,
            'isturf': turf, 'Adjacent': adjacent, 'get_turf': lambda person: person.loc,
            'to_chat': lambda user, message: self.messages.append(message),
            'SPAN_WARNING': str, 'SPAN_NOTICE': str, 'do_after': wait,
            'mortar_grind_result': lambda item: {'flour': 5} if item.kind == 'wheat' else None,
            'mortar_pigment_result': lambda item: 'ochre' if item.kind == 'clay' else None,
            'spawn_pigment': lambda pigment_type, _: pigment_type,
            'parent_attack': lambda item, user: None,
            'is_stack': lambda item: item.kind == 'clay', 'qdel': lambda item: setattr(item, 'deleted', True),
            'persistence_save_in_progress': False, 'persistence_active_operation': False,
            'persistence_load_recovery_required': False, 'MORTAR_GRIND_TIME': 30,
            'PAINT_GRIND_TIME': 20, 'mortar': self.state,
        }
        # Replace only the unsupported engine syntax, not conditions or their order.
        herbs = read('code/modules/1713/herbalism.dm')
        paint = read('code/modules/paintings/paintings.dm')
        prefix = '/obj/item/weapon/reagent_containers/glass/mortar'

        def projected(source, name, arguments):
            source = source.replace('if (grinding', 'if (mortar.grinding').replace('grinding = ', 'mortar.grinding = ')
            source = source.replace('reagents.', 'mortar.reagents.').replace('isturf(loc)', 'isturf(src.loc)')
            source = source.replace('istype(W, /obj/item/stack)', 'is_stack(W)')
            source = source.replace('new pigment_type(get_turf(user))', 'spawn_pigment(pigment_type, get_turf(user))')
            source = source.replace('return ..()', 'return parent_attack(W, user)')
            return action_adapter.project(source, prefix + name, arguments, env)

        env['grind_access'] = lambda actor: projected(herbs, '/proc/grind_access', 'src, user')(self.state, actor)
        for func in ('can_grind', 'finish_grinding', 'start_grinding'):
            env[func] = self.bound(projected(herbs, '/proc/' + func, 'src, W, user'))
        env['grind_pigment'] = self.bound(projected(paint, '/proc/grind_pigment', 'src, W, user'))
        self.attack = self.bound(projected(herbs, '/attackby', 'src, W, user'))
        self.env = env

    def bound(self, action):
        return lambda item, actor: action(self.state, item, actor)

    def grind(self, kind):
        from types import SimpleNamespace
        item = SimpleNamespace(kind=kind, remaining=2, deleted=False)
        item.use = lambda n: setattr(item, 'remaining', item.remaining - n) or True
        self.attack(item, self.user)
        self.assertFalse(self.state.grinding)
        return item

    def assert_unspent(self, item):
        self.assertFalse(item.deleted)
        self.assertEqual(item.remaining, 2)
        self.assertEqual((self.flour, self.pigments), ([], []))

    def test_both_routes_refuse_a_closed_lid_before_wait_or_payment(self):
        for kind in ('wheat', 'clay'):
            with self.subTest(kind=kind):
                self.setUp()
                self.state.opened = False
                self.assert_unspent(self.grind(kind))
                self.assertEqual(self.waits, 0)
                self.assertIn("Open the lid before grinding.", self.messages)

    def test_both_routes_recheck_lid_after_the_wait(self):
        for kind in ('wheat', 'clay'):
            with self.subTest(kind=kind):
                self.setUp()
                self.on_wait = lambda: setattr(self.state, 'opened', False)
                self.assert_unspent(self.grind(kind))
                self.assertEqual(self.waits, 1)
                self.assertIn("Open the lid before grinding.", self.messages)

    def test_both_routes_recheck_floor_bag_reach_with_unchanged_bowl_loc(self):
        for kind in ('wheat', 'clay'):
            for destination in ('carried', 'far'):
                with self.subTest(kind=kind, destination=destination):
                    self.setUp()
                    self.state.loc = self.bag
                    self.on_wait = lambda: setattr(self.bag, 'loc', self.carrier if destination == 'carried' else self.far)
                    self.assert_unspent(self.grind(kind))
                    self.assertEqual(self.waits, 1)
                    self.assertIs(self.state.loc, self.bag)
                    self.assertIn("You cannot reach the mortar to grind in it.", self.messages)

    def test_both_routes_preserve_ground_held_and_reachable_bag_success(self):
        for kind in ('wheat', 'clay'):
            for place in ('near', 'held', 'floor bag', 'own bag'):
                with self.subTest(kind=kind, place=place):
                    self.setUp()
                    if place == 'held':
                        self.state.loc = self.user
                    elif place.endswith('bag'):
                        self.state.loc = self.bag
                        if place == 'own bag':
                            self.bag.loc = self.user
                    item = self.grind(kind)
                    self.assertEqual(self.waits, 1)
                    self.assertEqual((item.deleted, item.remaining), (True, 2) if kind == 'wheat' else (False, 1))
                    self.assertEqual(self.flour, [('flour', 5)] if kind == 'wheat' else [])
                    self.assertEqual(self.pigments, ['ochre'] if kind == 'clay' else [])

    def test_food_still_checks_room_and_both_routes_still_respect_save_holds(self):
        self.space = 4
        self.assert_unspent(self.grind('wheat'))
        self.assertEqual(self.waits, 0)
        for kind in ('wheat', 'clay'):
            with self.subTest(kind=kind):
                self.setUp()
                self.on_wait = lambda: self.env.update(persistence_active_operation=True)
                self.assert_unspent(self.grind(kind))
                self.assertEqual(self.waits, 1)


if __name__ == '__main__':
    unittest.main()
