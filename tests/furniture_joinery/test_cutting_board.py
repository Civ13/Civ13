"""Production-body projections with inert inventory, waits and reagent holders."""
import json
from pathlib import Path
import re
import sys
from types import SimpleNamespace as NS
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/primitive_woodworking'))
from source_adapter import block, compile_body
SOURCE = (ROOT / 'code/modules/1713/cutting_board.dm').read_text()
BOARD = '/obj/structure/cutting_board'
FOOD = '/obj/item/weapon/reagent_containers/food/snacks/'
KNIFE = '/obj/item/weapon/material/kitchen/utensil/knife/wood'
ROUTES = json.loads(Path(__file__).with_name('cutting-board-routes.json').read_text())
TRACE_CASES = json.loads(Path(__file__).with_name('cutting-board-trace-cases.json').read_text())
MINIMUM = float(re.search(r'^#define MINIMUM_CHEMICAL_VOLUME (\S+)',
    (ROOT / 'code/__defines/chemistry.dm').read_text(), re.M)[1])


def path_is(path, parent):
    return isinstance(path, str) and (path == parent or path.startswith(parent + '/'))


def project(signature, args, env, fields=()):
    source = block(SOURCE, signature)
    source = source.replace('paid_input ? 20 : 15', '(20 if paid_input else 15)')
    source = source.replace('return ..()', 'return parent_call()')
    source = source.replace('food.contents.len', 'len(food.contents)')
    source = source.replace('for (var/datum/reagent/part in food.reagents.reagent_list)',
                            'for part in food.reagents.reagent_list:')
    source = re.sub(r'(?<![\w])list\(([^\n)]*)\)',
                    lambda m: 'record(' + re.sub(r'("\w+") = ', r'\1, ', m[1]) + ')', source)
    source = source.replace('for (var/i = 1, i <= recipe["count"], i++)',
                            'for i in native_range(1, recipe["count"] + 1):')
    source = source.replace('new output_type(site)', 'construct(output_type, site)')
    return compile_body(source, signature, args, env, fields)[0]


class Holder(dict):
    @property
    def total_volume(self): return sum(self.values())
    def __bool__(self): return True  # A real empty reagent datum still exists.
    def clear_reagents(self): self.clear()
    @property
    def reagent_list(self): return [NS(id=key, volume=value) for key, value in self.items()]
    def prune(self):
        for key, value in list(self.items()):
            if value < MINIMUM: del self[key]
    def add_reagent(self, key, value):
        self[key] = self.get(key, 0) + value
        self.prune()
    def trans_to_holder(self, target, amount):
        fraction = amount / self.total_volume if self.total_volume else 0
        for key, value in list(self.items()):
            target.add_reagent(key, value * fraction)
            self[key] -= value * fraction
            self.prune()


class Food(NS):
    def __eq__(self, other): return self is other
    def __ne__(self, other): return self is not other
    def forceMove(self, loc): self.loc = loc
    def mark_salted_meat(self):
        multiplier = 4 if path_is(self.type, FOOD + 'driedmeat') else 2
        self.salted_meat = True; self.decay *= multiplier; self.decaytimer *= multiplier
    def rot(self): self.rotten = True


class Fixture:
    def __init__(self):
        self.site = NS(type='/turf', x=1, y=1, z=1)
        self.actor = NS(type='/mob/living/human', loc=self.site, z=1, hands=[], disabled=False, can_drop=True)
        self.actor.incapacitated = lambda: self.actor.disabled
        self.actor.item_is_in_hands = lambda item: any(obj is item for obj in self.actor.hands)
        self.actor.canUnEquip = lambda item: self.actor.can_drop
        def remove(item):
            self.actor.hands[:] = [obj for obj in self.actor.hands if obj is not item]
            item.loc = self.actor.loc
        self.actor.remove_from_mob = remove
        self.board = NS(type=BOARD, loc=self.site, input=None, icon_state='cutting_board', deleted=False)
        self.outputs, self.food_outputs, self.delays, self.parents = [], [], [], []
        self.after = lambda: True
        self.epoch = object()
        def delete(item):
            item.deleted = True; item.loc = None
            self.actor.hands[:] = [obj for obj in self.actor.hands if obj is not item]
        self.env = dict(record=lambda *pairs: dict(zip(pairs[::2], pairs[1::2])), native_range=range,
            MINIMUM_CHEMICAL_VOLUME=MINIMUM,
            istype=lambda obj, path=FOOD.rstrip('/'): path_is(getattr(obj, 'type', None), path),
            QDELETED=lambda obj: obj is None or getattr(obj, 'deleted', False),
            isturf=lambda obj: getattr(obj, 'type', '') == '/turf',
            get_turf=lambda obj: obj.loc, get_dist=lambda user, site: max(abs(user.loc.x-site.x), abs(user.loc.y-site.y)),
            persistence_admission_identity=self.epoch, persistence_save_in_progress=False,
            persistence_active_operation=None, persistence_load_recovery_required=False,
            to_chat=lambda *args: None, playsound=lambda *args: None,
            parent_call=lambda: self.parents.append(True), qdel=delete, construct=self.construct,
            do_after=lambda user, delay, board: self.delays.append(delay) or self.after())
        self.recipe = project('/proc/cutting_board_recipe(', 'path', self.env)
        self.env['cutting_board_recipe'] = self.recipe
        self.split_safe = project('/proc/cutting_board_reagents_can_split(', 'food', self.env)
        self.env['cutting_board_reagents_can_split'] = self.split_safe
        self.safe = project('/proc/cutting_board_food_is_safe(', 'food', self.env)
        self.transfer = project('/proc/cutting_board_transfer_food(', 'food,output,remaining', self.env)
        self.env.update(cutting_board_food_is_safe=self.safe, cutting_board_transfer_food=self.transfer)
        fields = ('loc', 'input', 'icon_state', 'normalize_input', 'actor_ready', 'wait_for_preparation')
        normalize = project(BOARD + '/proc/normalize_input(', 'self', self.env, fields)
        self.ready = project(BOARD + '/proc/actor_ready(', 'self,user,site,save_epoch', self.env, fields)
        wait = project(BOARD + '/proc/wait_for_preparation(', 'self,user,delay', self.env, fields)
        self.board.normalize_input = lambda: normalize(self.board)
        self.board.actor_ready = lambda *args: self.ready(self.board, *args)
        self.board.wait_for_preparation = lambda *args: wait(self.board, *args)
        self.attack = project(BOARD + '/attackby(', 'self,W,user', self.env, fields)
        self.scrape = project(BOARD + '/attack_hand(', 'self,user', self.env, fields)

    def food(self, name, loc=None):
        return Food(type=FOOD + name, loc=loc, deleted=False, contents=[],
                    rotten=False, decay=150000 if name.startswith('driedmeat') else 12000,
                    decaytimer=0, rots=not name.startswith('driedmeat'), salted_meat=False,
                    raw=True, roasted=False, boiled=False, disgusting=False, satisfaction=-3,
                    non_vegetarian=True, radiation=0,
                    reagents=Holder(protein=5))
    def construct(self, path, site):
        output = self.food(path.removeprefix(FOOD), site)
        self.outputs.append(path); self.food_outputs.append(output)
        return output
    def item(self, path):
        item = self.food(path.removeprefix(FOOD), self.actor) if path.startswith(FOOD) else NS(type=path, loc=self.actor, deleted=False)
        self.actor.hands.append(item)
        return item
    def load(self, name):
        item = self.item(FOOD + name); self.attack(self.board, item, self.actor)
        return item
    def cut(self):
        knife = self.item(KNIFE); self.attack(self.board, knife, self.actor)
        return knife


class CuttingBoard(unittest.TestCase):
    def test_frozen_yields_delays_icons_and_one_owned_live_input(self):
        for row in ROUTES:
            with self.subTest(food=row['input']):
                f = Fixture(); item = f.load(row['input'])
                self.assertFalse(item.deleted); self.assertIs(item.loc, f.board)
                self.assertIs(f.board.input, item); self.assertNotIn(item, f.actor.hands)
                self.assertEqual(f.board.icon_state, row['icon'])
                f.cut()
                self.assertTrue(item.deleted); self.assertIsNone(f.board.input)
                self.assertEqual(f.outputs, [FOOD + row['output']] * row['count'])
                self.assertEqual(f.delays, [row['delay']] if row['delay'] else [])
                self.assertAlmostEqual(sum(o.reagents.total_volume for o in f.food_outputs), 5)
                f.cut(); self.assertEqual(len(f.outputs), row['count'])

    def test_occupied_unsupported_and_nonremovable_food_is_not_consumed(self):
        f = Fixture(); paid = f.load('meat'); refused = f.load('rawcutlet')
        self.assertIs(refused.loc, f.actor); self.assertIs(f.board.input, paid)
        for name, removable in (('bread', True), ('meat', False), ('meat/poisonfrog', True), ('driedmeat/minced_driedmeat', True)):
            f = Fixture(); f.actor.can_drop = removable; refused = f.load(name)
            self.assertFalse(refused.deleted); self.assertIs(refused.loc, f.actor)
            self.assertIsNone(f.board.input)

    def test_rotten_expired_disabled_and_unrepresentable_intake_remains_in_hand(self):
        for change in ('rotten', 'threshold', 'expired', 'no decay', 'over capacity', 'contents'):
            f = Fixture(); food = f.item(FOOD + 'meat')
            if change == 'rotten': food.rotten = True
            if change == 'threshold': food.decaytimer = food.decay / 2
            if change == 'expired': food.decaytimer = food.decay
            if change == 'no decay': food.decay = 0
            if change == 'over capacity': food.reagents['cyanide'] = 50
            if change == 'contents': food.contents.append(object())
            f.attack(f.board, food, f.actor)
            self.assertIs(food.loc, f.actor, change); self.assertFalse(food.deleted)
            self.assertIsNone(f.board.input)

    def test_relative_age_salt_reagents_and_preparation_flags_are_retained(self):
        f = Fixture(); food = f.item(FOOD + 'meat')
        food.decaytimer = 2400; food.mark_salted_meat(); food.reagents['cyanide'] = 3
        food.disgusting = True; food.satisfaction = -20; food.raw = False; food.roasted = True
        food.radiation = 137
        f.attack(f.board, food, f.actor)
        f.after = lambda: setattr(food, 'decaytimer', food.decaytimer + 600) or True
        fraction = (food.decaytimer + 600) / food.decay
        f.cut()
        self.assertAlmostEqual(sum(o.reagents['protein'] for o in f.food_outputs), 5)
        self.assertAlmostEqual(sum(o.reagents['cyanide'] for o in f.food_outputs), 3)
        for output in f.food_outputs:
            self.assertTrue(output.salted_meat); self.assertAlmostEqual(output.decaytimer / output.decay, fraction)
            self.assertTrue(output.disgusting); self.assertTrue(output.roasted)
            self.assertFalse(output.raw); self.assertEqual(output.satisfaction, -20)
            self.assertEqual(output.radiation, 137); self.assertTrue(output.non_vegetarian)

    def test_dried_output_cannot_be_minced_repeatedly_or_reset_age(self):
        f = Fixture(); food = f.item(FOOD + 'driedmeat')
        food.decaytimer = food.decay * .8; food.mark_salted_meat()
        f.attack(f.board, food, f.actor); f.cut()
        output = f.food_outputs[0]; age = output.decaytimer
        self.assertAlmostEqual(age / output.decay, .8)
        output.loc = f.actor; f.actor.hands.append(output)
        for _ in range(3): f.attack(f.board, output, f.actor); f.cut()
        self.assertEqual(len(f.outputs), 1); self.assertIs(output.loc, f.actor)
        self.assertEqual(output.decaytimer, age)

    def test_trace_boundary_controls_preserve_or_refuse_the_entire_paid_input(self):
        self.assertEqual(MINIMUM, .01)
        for name, count in (('meat', 2), ('rawfish', 2), ('rawcutlet', 1)):
            for row in TRACE_CASES:
                with self.subTest(food=name, dose=row['dose']):
                    f = Fixture(); food = f.item(FOOD + name)
                    food.reagents = Holder(protein=1)
                    food.reagents.add_reagent('cyanide', row['dose'])
                    self.assertAlmostEqual(food.reagents.get('cyanide', 0), row['stored'])
                    expected = count == 1 or row['two_outputs']
                    f.attack(f.board, food, f.actor)
                    if not expected:
                        self.assertIs(food.loc, f.actor); self.assertFalse(food.deleted)
                        self.assertAlmostEqual(food.reagents['cyanide'], row['stored'])
                        self.assertIsNone(f.board.input); f.cut(); self.assertEqual(f.outputs, [])
                    else:
                        self.assertIs(f.board.input, food); f.cut()
                        self.assertEqual(len(f.outputs), count)
                        self.assertAlmostEqual(sum(o.reagents.get('cyanide', 0) for o in f.food_outputs), row['stored'])
                        self.assertAlmostEqual(sum(o.reagents.get('protein', 0) for o in f.food_outputs), 1)

    def test_trace_adapter_reproduces_original_loss_without_the_guard(self):
        chemistry = (ROOT / 'code/modules/reagents/Chemistry-Holder.dm').read_text()
        self.assertIn('R.volume < MINIMUM_CHEMICAL_VOLUME',
                      block(chemistry, '/datum/reagents/proc/update_total('))
        source, first, second = Holder(cyanide=.01), Holder(), Holder()
        source.trans_to_holder(first, source.total_volume / 2)
        source.trans_to_holder(second, source.total_volume)
        self.assertEqual(first.total_volume + second.total_volume, 0)

    def test_rejections_revalidate_live_food_location_state_and_actions(self):
        for change in ('cancelled', 'replacement', 'mutated', 'food moved', 'rotted', 'expired', 'late trace', 'knife', 'moved', 'epoch', 'save', 'disabled'):
            with self.subTest(change=change):
                f = Fixture(); paid = f.load('rawfish')
                def after():
                    if change == 'replacement': f.board.input = f.food('rawfish', f.board)
                    if change == 'mutated': paid.type = FOOD + 'meat'
                    if change == 'food moved': paid.loc = f.site
                    if change == 'rotted': paid.rotten = True
                    if change == 'expired': paid.decaytimer = paid.decay
                    if change == 'late trace': paid.reagents.add_reagent('cyanide', .01)
                    if change == 'knife': f.actor.hands.clear()
                    if change == 'moved': f.board.loc = NS(type='/turf', x=5, y=5, z=1)
                    if change == 'epoch': f.ready.__globals__['persistence_admission_identity'] = object()
                    if change == 'save': f.ready.__globals__['persistence_save_in_progress'] = True
                    if change == 'disabled': f.actor.disabled = True
                    return change != 'cancelled'
                f.after = after; f.cut()
                self.assertIsNotNone(f.board.input); self.assertEqual(f.outputs, [])
                self.assertFalse(paid.deleted)

    def test_competing_processing_and_constructor_reentry_cannot_duplicate(self):
        f = Fixture(); f.load('rawfish')
        def after():
            f.after = lambda: True; f.cut(); return True
        f.after = after; f.cut(); self.assertEqual(f.outputs, [FOOD + 'mince'] * 2)
        f = Fixture(); f.load('meatball')
        def construct(path, site):
            output = f.construct(path, site); f.cut(); return output
        f.attack.__globals__['construct'] = construct
        f.cut(); self.assertEqual(f.outputs, [FOOD + 'patty'])

    def test_scraping_revalidates_then_destroys_only_owned_input(self):
        f = Fixture(); original = f.load('meat'); replacement = f.food('meat', f.board)
        f.after = lambda: setattr(f.board, 'input', replacement) or True
        f.scrape(f.board, f.actor)
        self.assertIs(f.board.input, replacement); self.assertFalse(original.deleted)
        f.after = lambda: True; f.scrape(f.board, f.actor)
        self.assertTrue(replacement.deleted); self.assertIsNone(f.board.input)
        self.assertFalse(original.deleted)
        f.after = lambda: f.load('rawcutlet') or True
        f.scrape(f.board, f.actor); self.assertIsNotNone(f.board.input)
        f = Fixture(); food = f.load('meat')
        f.after = lambda: setattr(food, 'loc', f.site) or True
        f.scrape(f.board, f.actor)
        self.assertIs(f.board.input, food); self.assertFalse(food.deleted)

    def test_expired_or_old_type_only_markers_cannot_mint_fresh_food(self):
        for marker in (dict(type=FOOD + 'meat'), NS(type=FOOD + 'meat', deleted=True)):
            f = Fixture(); f.board.input = marker; f.cut()
            self.assertEqual(f.outputs, [])
        f = Fixture(); f.board.input = f.item(FOOD + 'meat'); f.cut()
        self.assertEqual(f.outputs, [])

    def test_parent_dispatch_occurs_once_and_invalid_sites_cannot_admit(self):
        f = Fixture(); f.attack(f.board, f.item('/obj/item/weapon/wrench'), f.actor)
        self.assertEqual(f.parents, [True])
        f = Fixture(); f.board.loc = None; food = f.load('meat')
        self.assertIs(food.loc, f.actor); self.assertEqual(f.delays, [])

    def test_original_recipes_research_decay_and_saved_child_contract(self):
        rows = json.loads(Path(__file__).with_name('legacy-production-storage.json').read_text())
        self.assertEqual(len(rows), 34)
        for row in rows: self.assertIn(row['row'], (ROOT / row['file']).read_text().splitlines())
        self.assertIn('"' + BOARD + '" = "cooperage"', (ROOT / 'code/modules/research_tree/research_node.dm').read_text())
        save_source = (ROOT / 'code/modules/persistence/functions.dm').read_text()
        self.assertIn('!istype(src, /obj/structure)', block(save_source, '/datum/proc/get_saved_vars('))
        self.assertIn('load_contents = 1', save_source)
        decay = (ROOT / 'code/modules/reagents/reagent_containers/food.dm').read_text()
        self.assertIn('isturf(loc) || istype(loc, /obj/structure/cutting_board)', decay)
        self.assertIn('decaytimer += 600', decay.split('istype(loc, /obj/structure/cutting_board)', 1)[1].split('else ', 1)[0])


if __name__ == '__main__':
    unittest.main()
