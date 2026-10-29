"""Actual barrel admission/consumption bodies with inert inventory/holders."""
import json
from pathlib import Path
import sys
from types import SimpleNamespace as NS
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).parent))
sys.path.insert(0, str(ROOT / 'tests/primitive_woodworking'))
from source_adapter import block, compile_body
from test_cutting_board import Holder, Food, path_is

SOURCE = (ROOT / 'code/modules/reagents/reagent_containers/glass.dm').read_text()
BARREL = '/obj/item/weapon/reagent_containers/glass/barrel'
ORE = '/obj/item/stack/ore/'
POO = '/obj/item/weapon/reagent_containers/food/snacks/poo'
ROUTES = json.loads(Path(__file__).with_name('barrel-ingredient-routes.json').read_text())


def project(signature, args, env, fields=()):
    body = block(SOURCE, signature).replace('return ..()', 'return parent_call()')
    body = body.replace('P.contents.len', 'len(P.contents)')
    body = body.replace('new /datum/reagents(reagents.maximum_volume)', 'holder(reagents.maximum_volume)')
    body = body.replace('list()', 'dict()').replace('expected.len', 'len(expected)')
    body = body.replace('expected -= part.id', 'expected.pop(part.id, None)')
    for collection in ('reagents', 'source', 'probe'):
        body = body.replace('for (var/datum/reagent/part in ' + collection + '.reagent_list)',
                            'for part in ' + collection + '.reagent_list:')
    return compile_body(body, signature, args, env, fields)[0]


class Reagents(Holder):
    def __init__(self, capacity=50, **values):
        super().__init__(values); self.capacity = capacity; self.prune()
    def get_free_space(self): return self.capacity - self.total_volume
    @property
    def maximum_volume(self): return self.capacity
    def add_reagent(self, key, amount, safety=False):
        super().add_reagent(key, min(amount, self.get_free_space()))
    def trans_to(self, target, amount, multiplier, copy):
        if not target.simulated or not target.is_open_container(): return 0
        amount = min(amount, self.total_volume, target.reagents.get_free_space())
        self.trans_to_holder(target.reagents, amount)
        return amount


class Fixture:
    def __init__(self):
        self.site = NS(type='/turf', x=3, y=2, z=1)
        self.actor_site = NS(type='/turf', x=2, y=2, z=1)
        self.actor = NS(type='/mob/living/human', loc=self.actor_site, z=1, hands=[], disabled=False, can_drop=True)
        self.actor.incapacitated = lambda: self.actor.disabled
        self.actor.item_is_in_hands = lambda item: any(i is item for i in self.actor.hands)
        self.actor.canUnEquip = lambda item: self.actor.can_drop
        self.barrel = NS(type=BARREL, loc=self.site, z=1, deleted=False, opened=True,
                         simulated=True, reagents=Reagents(250))
        self.barrel.is_open_container = lambda: self.barrel.opened
        self.parent_calls = []
        def delete(item):
            item.deleted = True; item.loc = None
            self.actor.hands[:] = [i for i in self.actor.hands if i is not item]
        self.delete = delete
        def turf(obj):
            while obj is not None and obj.type != '/turf': obj = obj.loc
            return obj
        env = dict(istype=lambda item, path: path_is(getattr(item, 'type', None), path),
            QDELETED=lambda obj: obj is None or getattr(obj, 'deleted', False),
            isturf=lambda obj: getattr(obj, 'type', None) == '/turf',
            get_dist=lambda a,b: max(abs(turf(a).x-turf(b).x), abs(turf(a).y-turf(b).y)),
            get_turf=turf,
            persistence_save_in_progress=False, persistence_active_operation=None,
            persistence_load_recovery_required=False, qdel=delete, to_chat=lambda *args: None,
            parent_call=lambda: self.parent_calls.append(True), holder=Reagents)
        self.powder = project('/proc/barrel_powder_reagent(', 'I', env)
        env['barrel_powder_reagent'] = self.powder
        fields = ('loc', 'z', 'reagents', 'is_open_container', 'ingredient_actor_ready', 'payload_fits_without_loss')
        self.ready = project(BARREL + '/proc/ingredient_actor_ready(', 'self,I,user', env, fields)
        self.barrel.ingredient_actor_ready = lambda *args: self.ready(self.barrel, *args)
        preview = project(BARREL + '/proc/payload_fits_without_loss(', 'self,source', env, fields)
        self.barrel.payload_fits_without_loss = lambda source: preview(self.barrel, source)
        self.attack = project(BARREL + '/attackby(', 'self,I,user', env, fields)

    def stock(self, name='sulphur', amount=2):
        stock = NS(type=ORE + name, amount=amount, loc=self.actor, deleted=False, fail_use=False, uses=[])
        stock.can_use = lambda count: stock.amount >= count
        def use(count):
            stock.uses.append(count)
            if stock.fail_use or not stock.can_use(count): return False
            stock.amount -= count
            if stock.amount <= 0: self.delete(stock)
            return True
        stock.use = use
        self.actor.hands.append(stock)
        return stock

    def manure(self, amount=10, **extra):
        item = Food(type=POO, loc=self.actor, deleted=False, contents=[],
                    reagents=Reagents(50, poo=amount, **extra))
        self.actor.hands.append(item)
        return item


class BarrelIngredients(unittest.TestCase):
    def test_frozen_ore_doses_use_one_unit_and_allow_exact_capacity(self):
        for row in ROUTES:
            for count in (1, 2, 25):
                f = Fixture(); f.barrel.reagents.add_reagent('water', 247)
                stock = f.stock(row['input'], count)
                f.attack(f.barrel, stock, f.actor)
                self.assertEqual(stock.amount, count-row['stock'])
                self.assertEqual(stock.uses, [1]); self.assertEqual(stock.deleted, count == 1)
                self.assertEqual(f.barrel.reagents[row['reagent']], row['dose'])
                self.assertEqual(f.barrel.reagents.total_volume, 250)
        f = Fixture(); stock = f.stock('sulphur/preset', 25)
        f.attack(f.barrel, stock, f.actor)
        self.assertEqual(stock.amount, 24); self.assertEqual(f.barrel.reagents['sulfur'], 3)

    def test_invalid_stock_capacity_closed_or_failed_use_never_adds_reagents(self):
        for change in ('zero', 'fraction', 'closed', 'capacity', 'failed use'):
            f = Fixture(); stock = f.stock()
            if change == 'zero': stock.amount = 0
            if change == 'fraction': stock.amount = .5
            if change == 'closed': f.barrel.opened = False
            if change == 'capacity':
                f.barrel.reagents.capacity = 8; f.barrel.reagents.add_reagent('water', 6)
            if change == 'failed use': stock.fail_use = True
            before = stock.amount
            recipient = dict(f.barrel.reagents)
            f.attack(f.barrel, stock, f.actor)
            self.assertEqual(stock.amount, before, change)
            self.assertFalse(stock.deleted); self.assertNotIn('sulfur', f.barrel.reagents)
            self.assertEqual(dict(f.barrel.reagents), recipient)

    def test_actor_stock_location_and_persistence_guards_preserve_inputs(self):
        for change in ('far', 'other z', 'target nested', 'actor nested', 'stock moved', 'no hands', 'disabled', 'bound', 'save', 'operation', 'recovery'):
            f = Fixture(); stock = f.stock()
            if change == 'far': f.site.x = 6
            if change == 'other z': f.actor.z = 2; f.actor_site.z = 2
            if change == 'target nested': f.barrel.loc = NS(type='/obj/item/storage', loc=f.site)
            if change == 'actor nested': f.actor.loc = NS(type='/obj/container', loc=f.actor_site)
            if change == 'stock moved': stock.loc = f.site
            if change == 'no hands': f.actor.hands.clear()
            if change == 'disabled': f.actor.disabled = True
            if change == 'bound': f.actor.can_drop = False
            key = {'save':'persistence_save_in_progress','operation':'persistence_active_operation','recovery':'persistence_load_recovery_required'}.get(change)
            if key: f.ready.__globals__[key] = True
            f.attack(f.barrel, stock, f.actor)
            self.assertEqual(stock.amount, 2, change); self.assertEqual(f.barrel.reagents.total_volume, 0)
        f = Fixture(); f.barrel.loc = f.actor; f.barrel.z = 0; stock = f.stock()
        f.attack(f.barrel, stock, f.actor)
        self.assertEqual(stock.amount, 1)  # A barrel carried by the actor remains usable.

    def test_whole_depleted_and_trace_payloads_transfer_without_material_loss(self):
        for amount, trace in ((10, 0), (6, 0), (9.99, .01)):
            f = Fixture(); item = f.manure(amount, cyanide=trace)
            water = 239 if trace else 240
            f.barrel.reagents.add_reagent('water', water)
            f.attack(f.barrel, item, f.actor)
            self.assertTrue(item.deleted)
            self.assertAlmostEqual(f.barrel.reagents.get('poo', 0), amount)
            self.assertAlmostEqual(f.barrel.reagents.get('cyanide', 0), trace)
            self.assertAlmostEqual(f.barrel.reagents.total_volume, water+amount+trace)

    def test_partial_zero_oversized_empty_and_child_payloads_stay_intact(self):
        for change in ('partial room', 'trace capacity', 'closed', 'zero transfer', 'oversized', 'empty', 'child'):
            f = Fixture(); item = f.manure()
            if change == 'partial room': f.barrel.reagents.add_reagent('water', 246.5)
            if change == 'trace capacity':
                item.reagents['poo'] = 9.99; item.reagents.add_reagent('cyanide', .01)
                f.barrel.reagents.add_reagent('water', 240)
            if change == 'closed': f.barrel.opened = False
            if change == 'zero transfer': f.barrel.simulated = False
            if change == 'oversized': item.reagents.add_reagent('cyanide', .01)
            if change == 'empty': item.reagents.clear_reagents()
            if change == 'child': item.contents.append(object())
            before = dict(item.reagents)
            recipient = dict(f.barrel.reagents)
            f.attack(f.barrel, item, f.actor)
            self.assertFalse(item.deleted, change); self.assertIs(item.loc, f.actor)
            self.assertEqual(dict(item.reagents), before); self.assertNotIn('poo', f.barrel.reagents)
            self.assertEqual(dict(f.barrel.reagents), recipient)

    def test_unrelated_items_dispatch_parent_once_even_when_full_or_closed(self):
        f = Fixture(); f.barrel.opened = False
        f.barrel.reagents.add_reagent('water', 250)
        f.attack(f.barrel, NS(type='/obj/item/weapon/wrench'), f.actor)
        self.assertEqual(f.parent_calls, [True])

    def test_existing_barrel_recipe_rows_are_preserved(self):
        rows = json.loads(Path(__file__).with_name('legacy-production-storage.json').read_text())
        barrel_rows = [row for row in rows if ',/obj/item/weapon/reagent_containers/glass/barrel,' in row['row']]
        self.assertTrue(barrel_rows)
        for row in barrel_rows:
            self.assertIn(row['row'], (ROOT / row['file']).read_text().splitlines())


if __name__ == '__main__':
    unittest.main()
