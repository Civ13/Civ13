"""Cutting-board production bodies with inert waits/inventory/constructors."""
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


class Record(dict):
    # DM list equality compares identity, including equal-content replacements.
    def __eq__(self, other): return self is other
    def __ne__(self, other): return self is not other


def record(*pairs): return Record(zip(pairs[::2], pairs[1::2]))


def path_is(path, parent):
    return isinstance(path, str) and (path == parent or path.startswith(parent + '/'))


def project(signature, args, env, fields=()):
    source = block(SOURCE, signature)
    source = source.replace('"[legacy.type]"', 'legacy.type').replace('"[W.type]"', 'W.type')
    source = source.replace('paid_input ? 20 : 15', '(20 if paid_input else 15)')
    source = source.replace('return ..()', 'return parent_call()')
    source = re.sub(r'(?<![\w])list\(([^\n)]*)\)',
                    lambda m: 'record(' + re.sub(r'("\w+") = ', r'\1, ', m[1]) + ')', source)
    source = source.replace('for (var/i = 1, i <= recipe["count"], i++)',
                            'for i in native_range(1, recipe["count"] + 1):')
    source = source.replace('new output_type(site)', 'construct(output_type, site)')
    return compile_body(source, signature, args, env, fields)[0]


class Fixture:
    def __init__(self):
        self.site = NS(type='/turf', x=1, y=1, z=1)
        self.actor = NS(type='/mob/living/human', loc=self.site, z=1, hands=[], disabled=False, can_drop=True)
        self.actor.incapacitated = lambda: self.actor.disabled
        self.actor.item_is_in_hands = lambda item: any(obj is item for obj in self.actor.hands)
        self.actor.canUnEquip = lambda item: self.actor.can_drop
        self.board = NS(type=BOARD, loc=self.site, input=None, icon_state='cutting_board', deleted=False)
        self.outputs = []
        self.delays = []
        self.parents = []
        self.after = lambda: True
        self.epoch = object()
        def delete(item):
            item.deleted = True; item.loc = None
            self.actor.hands[:] = [obj for obj in self.actor.hands if obj is not item]
        self.env = dict(record=record, native_range=range, ispath=path_is,
            istype=lambda obj, path=FOOD.rstrip('/'): path_is(getattr(obj, 'type', None), path),
            islist=lambda value: isinstance(value, dict), istext=lambda value: isinstance(value, str),
            text2path=lambda value: value if isinstance(value, str) and value.startswith('/') else None,
            QDELETED=lambda obj: obj is None or getattr(obj, 'deleted', False),
            isturf=lambda obj: getattr(obj, 'type', '') == '/turf',
            get_turf=lambda obj: obj.loc, get_dist=lambda user, site: max(abs(user.loc.x-site.x), abs(user.loc.y-site.y)),
            persistence_admission_identity=self.epoch, persistence_save_in_progress=False,
            persistence_active_operation=None, persistence_load_recovery_required=False,
            to_chat=lambda *args: None, playsound=lambda *args: None,
            parent_call=lambda: self.parents.append(True), qdel=delete,
            construct=lambda path, site: self.outputs.append(path),
            do_after=lambda user, delay, board: self.delays.append(delay) or self.after())
        self.recipe = project('/proc/cutting_board_recipe(', 'path', self.env)
        self.env['cutting_board_recipe'] = self.recipe
        fields = ('loc', 'input', 'icon_state', 'normalize_input', 'actor_ready', 'wait_for_preparation')
        normalize = project(BOARD + '/proc/normalize_input(', 'self', self.env, fields)
        ready = project(BOARD + '/proc/actor_ready(', 'self,user,site,save_epoch', self.env, fields)
        self.ready = ready
        wait = project(BOARD + '/proc/wait_for_preparation(', 'self,user,delay', self.env, fields)
        self.board.normalize_input = lambda: normalize(self.board)
        self.board.actor_ready = lambda *args: ready(self.board, *args)
        self.board.wait_for_preparation = lambda *args: wait(self.board, *args)
        self.attack = project(BOARD + '/attackby(', 'self,W,user', self.env, fields)
        self.scrape = project(BOARD + '/attack_hand(', 'self,user', self.env, fields)

    def item(self, path):
        item = NS(type=path, loc=self.actor, deleted=False)
        self.actor.hands.append(item)
        return item

    def load(self, name):
        item = self.item(FOOD + name)
        self.attack(self.board, item, self.actor)
        return item

    def cut(self):
        knife = self.item(KNIFE)
        self.attack(self.board, knife, self.actor)
        return knife


class CuttingBoard(unittest.TestCase):
    def test_frozen_conversion_yields_delays_and_all_intake_icons(self):
        for row in ROUTES:
            with self.subTest(food=row['input']):
                f = Fixture(); item = f.load(row['input'])
                self.assertTrue(item.deleted)
                self.assertEqual(dict(f.board.input), {'type': FOOD + row['input']})
                self.assertEqual(f.board.icon_state, row['icon'])
                f.cut()
                self.assertIsNone(f.board.input)
                self.assertEqual(f.outputs, [FOOD + row['output']] * row['count'])
                self.assertEqual(f.delays, [row['delay']] if row['delay'] else [])
                f.cut(); self.assertEqual(len(f.outputs), row['count'])

    def test_occupied_unsupported_and_nonremovable_food_is_not_consumed(self):
        f = Fixture(); f.load('meat'); paid = f.board.input
        refused = f.load('rawcutlet')
        self.assertFalse(refused.deleted); self.assertIs(f.board.input, paid)
        for name, removable in (('bread', True), ('meat', False)):
            f = Fixture(); f.actor.can_drop = removable
            refused = f.load(name)
            self.assertFalse(refused.deleted); self.assertIsNone(f.board.input)

    def test_rejections_keep_paid_input_and_produce_nothing(self):
        for change in ('cancelled', 'replacement', 'mutated', 'knife', 'moved', 'epoch', 'save', 'disabled'):
            with self.subTest(change=change):
                f = Fixture(); f.load('rawfish'); paid = f.board.input
                def after():
                    if change == 'replacement': f.board.input = record('type', paid['type'])
                    if change == 'mutated': paid['type'] = FOOD + 'meat'
                    if change == 'knife': f.actor.hands.clear()
                    if change == 'moved': f.board.loc = NS(type='/turf', x=5, y=5, z=1)
                    if change == 'epoch': f.ready.__globals__['persistence_admission_identity'] = object()
                    if change == 'save': f.ready.__globals__['persistence_save_in_progress'] = True
                    if change == 'disabled': f.actor.disabled = True
                    return change != 'cancelled'
                f.after = after; f.cut()
                self.assertIsNotNone(f.board.input); self.assertEqual(f.outputs, [])

    def test_competing_processing_and_constructor_reentry_cannot_duplicate_food(self):
        f = Fixture(); f.load('rawfish')
        def after():
            f.after = lambda: True
            f.cut()
            return True
        f.after = after; f.cut()
        self.assertEqual(f.outputs, [FOOD + 'mince'] * 2)
        f = Fixture(); f.load('meatball')
        def construct(path, site):
            f.outputs.append(path)
            f.cut()
        f.attack.__globals__['construct'] = construct
        f.cut(); self.assertEqual(f.outputs, [FOOD + 'patty'])

    def test_scraping_and_cleaning_revalidate_paid_slot_and_dirty_state(self):
        f = Fixture(); f.load('meat'); paid = f.board.input
        f.after = lambda: setattr(f.board, 'input', record('type', paid['type'])) or True
        f.scrape(f.board, f.actor)
        self.assertIsNotNone(f.board.input); self.assertEqual(f.board.icon_state, 'cutting_board_steak')
        f.after = lambda: True; f.scrape(f.board, f.actor)
        self.assertIsNone(f.board.input); self.assertEqual(f.board.icon_state, 'cutting_board_dirty')
        f.after = lambda: f.load('rawcutlet') or True
        f.scrape(f.board, f.actor)
        self.assertIsNotNone(f.board.input); self.assertEqual(f.board.icon_state, 'cutting_board_cutlet')

    def test_gc_legacy_marker_migrates_but_live_object_cannot_mint_food(self):
        f = Fixture(); f.board.input = NS(type=FOOD + 'meat', deleted=True)
        f.cut(); self.assertEqual(f.outputs, [FOOD + 'mince'] * 2)
        f = Fixture(); f.board.input = f.item(FOOD + 'meat')
        f.cut(); self.assertEqual(f.outputs, [])
        f = Fixture(); f.load('rawcutlet')
        data = json.loads(json.dumps(f.board.input))
        f.board.input = record(*[value for pair in data.items() for value in pair])
        f.cut(); self.assertEqual(f.outputs, [FOOD + 'mince'])

    def test_parent_dispatch_occurs_once_and_invalid_sites_do_not_start_actions(self):
        f = Fixture(); f.attack(f.board, f.item('/obj/item/weapon/wrench'), f.actor)
        self.assertEqual(f.parents, [True])
        f = Fixture(); f.board.loc = None
        food = f.load('meat')
        self.assertFalse(food.deleted); self.assertEqual(f.delays, [])

    def test_original_recipes_research_and_saved_type_marker_contract(self):
        rows = json.loads(Path(__file__).with_name('legacy-production-storage.json').read_text())
        self.assertEqual(len(rows), 34)
        for row in rows:
            self.assertIn(row['row'], (ROOT / row['file']).read_text().splitlines())
        # The global route uses finished planks; faction recipes keep their costs.
        self.assertIn('RECIPE: /material/wood/soft/,cutting board,' + BOARD + ',5,50,0,1,kitchen,20,0,0,8,null',
                      (ROOT / 'config/crafting/material_recipes_global.txt').read_text())
        self.assertIn('"' + BOARD + '" = "cooperage"',
                      (ROOT / 'code/modules/research_tree/research_node.dm').read_text())
        save_source = (ROOT / 'code/modules/persistence/functions.dm').read_text()
        self.assertIn('!istype(src, /obj/structure)', block(save_source, '/datum/proc/get_saved_vars('))
        self.assertIn('normalize_input()', block(SOURCE, BOARD + '/before_save('))


if __name__ == '__main__':
    unittest.main()
