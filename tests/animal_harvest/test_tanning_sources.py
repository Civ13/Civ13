"""Offline source contracts, not a substitute for native DM/gameplay execution.

Evaluate the production admission predicates against cancellation/input matrices,
derive conversion costs from production, and retain historical/mutated controls.
"""
import ast
import importlib.util
from pathlib import Path
import re
import subprocess
from types import SimpleNamespace as NS
import unittest

ROOT = Path(__file__).resolve().parents[2]
BASE = '1650445ede7924070698de31d34e8e8afb913d29'
LEATHER = 'code/game/objects/items/stacks/sheets/leather.dm'
ANIMALS = 'code/modules/1713/animal_harvest.dm'
RACK = 'code/game/objects/structures/converters.dm'
SHEETS = 'code/modules/materials/material_sheets.dm'
MATERIALS = 'code/modules/materials/materials.dm'


def source(path):
    return (ROOT / path).read_text(encoding='utf-8')


def baseline(path):
    return subprocess.check_output(['git', 'show', BASE + ':' + path], cwd=ROOT).decode().replace('\r\n', '\n')


def block(text, name):
    match = re.search(r'^' + re.escape(name) + r'(?:\([^\n]*\))?\n(.*?)(?=^/|\Z)', text, re.M | re.S)
    if not match:
        raise AssertionError('Missing production declaration: ' + name)
    return match[0]


def predicate(text, name):
    return next(line.strip()[7:] for line in block(text, name).splitlines() if line.strip().startswith('return '))


def gate(expression, context):
    """Restricted evaluation of literal production boolean/type predicates only."""
    expression = re.sub(r'(/[\w/]+)', lambda m: repr(m[1]), expression)
    expression = expression.replace('&&', ' and ').replace('||', ' or ')
    expression = re.sub(r'!(?!=)', ' not ', expression).strip()
    tree = ast.parse(expression, mode='eval')
    allowed = (ast.Expression, ast.BoolOp, ast.And, ast.Or, ast.UnaryOp, ast.Not,
               ast.Compare, ast.Eq, ast.NotEq, ast.Lt, ast.Gt, ast.LtE, ast.GtE,
               ast.Call, ast.Name, ast.Load, ast.Attribute, ast.Constant)
    for node in ast.walk(tree):
        if not isinstance(node, allowed):
            raise AssertionError('Unsupported source predicate node: ' + ast.dump(node))
        if isinstance(node, ast.Attribute) and node.attr.startswith('_'):
            raise AssertionError('Unexpected private attribute')
    functions = {
        'QDELETED': lambda obj: obj is None or obj.deleted,
        'istype': lambda obj, kind=None: obj is not None and (obj.living if kind is None else obj.type == kind or obj.type.startswith(kind + '/')),
        'isturf': lambda obj: obj is not None and getattr(obj, 'type', None) == 'turf',
        'get_turf': lambda obj: obj.site,
        'CONSCIOUS': 0,
    }
    return eval(compile(tree, '<production predicate>', 'eval'), {'__builtins__': {}}, functions | context)


def scenario():
    site = NS(type='turf', token=object())
    user = NS(type='/mob/living/human', living=True, deleted=False, stat=0, site=site,
              connected=True, reachable=True, hands=[])
    user.hide_worker_connected = lambda: user.connected
    user.Adjacent = lambda obj: user.reachable
    user.item_is_in_hands = lambda obj: any(obj is held for held in user.hands)
    item = NS(type='/obj/item/stack/material/rawhide', deleted=False, loc=site, site=site, amount=3)
    tool = NS(type='/obj/item/weapon/material/kitchen/utensil/knife', deleted=False, loc=user, sharp=True)
    user.hands = [tool]
    return site, user, item, tool


class TanningSourceContracts(unittest.TestCase):
    def test_preview_counts_animated_empty_states_before_named_material_states(self):
        from PIL import Image
        spec=importlib.util.spec_from_file_location('harvest_sprite_preview',ROOT/'tests/animal_harvest/preview.py')
        preview=importlib.util.module_from_spec(spec)
        spec.loader.exec_module(preview)
        path=ROOT/'icons/obj/materials.dmi'
        image=Image.open(path)
        description=image.info['Description']
        self.assertRegex(description,r'state = ""\n\tdirs = 1\n\tframes = 4')
        # The named logs state follows four unnamed animation cells, not cell 0.
        width=int(re.search(r'width = (\d+)',description)[1])
        height=int(re.search(r'height = (\d+)',description)[1])
        columns=image.width//width
        x,y=(4%columns)*width,(4//columns)*height
        expected=image.convert('RGBA').crop((x,y,x+width,y+height))
        actual=preview.state(path,'logs')
        self.assertEqual(actual.tobytes(),expected.tobytes())
        self.assertNotEqual(actual.tobytes(),image.convert('RGBA').crop((0,0,width,height)).tobytes())

    def test_existing_corpse_claim_cancellation_and_anatomy_are_unchanged(self):
        old, new = baseline(ANIMALS), source(ANIMALS)
        for name in ('/mob/living/simple_animal/proc/harvest_animal',
                     '/mob/living/simple_animal/proc/harvest_valid',
                     '/mob/living/simple_animal/proc/harvest_mammal'):
            self.assertEqual(block(old, name), block(new, name))
        name = '/mob/living/simple_animal/proc/harvest_products'
        self.assertEqual(block(old, name).split('\tif (mammal)')[0], block(new, name).split('\tif (mammal)')[0])
        self.assertNotIn('new /obj/item/stack/material/leather', new)

    def test_fur_pelt_outputs_and_their_quantities_remain_available(self):
        pattern = r'new (/obj/item/stack/material/pelt/[\w/]+)\(site, (\d+)\)'
        self.assertEqual(re.findall(pattern, source(ANIMALS)), re.findall(pattern, baseline(ANIMALS)))

    def test_turkey_skin_is_one_unit_without_mammal_reclassification(self):
        text = source(ANIMALS)
        skin = block(text, '/mob/living/simple_animal/proc/harvest_skin_yield')
        turkey_gate = re.search(r'\tif \((.*)\)\n\t\treturn (\d+)', skin)
        self.assertIsNotNone(turkey_gate)
        for species, expected in (('turkey_f', True), ('turkey_m', True), ('turkeychick', False),
                                  ('chicken', False), ('crab', False), ('cattle/cow', False)):
            obj = NS(type='/mob/living/simple_animal/' + species)
            self.assertEqual(gate(turkey_gate[1], {'src': obj}), expected)
        self.assertEqual(int(turkey_gate[2]), 1)
        self.assertNotIn('turkey', block(text, '/mob/living/simple_animal/proc/harvest_mammal'))
        bounds = re.search(r'return min\((\d+), max\((\d+), butcher_yield\(\)-(\d+)\)\)', skin)
        self.assertIsNotNone(bounds)
        cap, floor, deducted = map(int, bounds.groups())
        for size, expected in ((1,1), (2,1), (3,1), (4,2), (5,3), (8,6), (999,6)):
            self.assertEqual(min(cap, max(floor, size-deducted)), expected)

    def test_preparation_gate_rejects_lost_tool_source_movement_empty_or_disconnected(self):
        text = source(LEATHER)
        reach = predicate(text, '/proc/hide_worker_can_reach')
        valid = predicate(text, '/obj/item/stack/material/proc/hide_preparation_valid')
        cases = ('valid', 'disconnected', 'unconscious', 'distant', 'deleted_hide', 'deleted_tool',
                 'dropped_tool', 'not_held', 'blunt', 'empty', 'source_moved', 'nested_source', 'container_tool')
        for case in cases:
            site, user, item, tool = scenario()
            origin = item.loc
            if case == 'disconnected': user.connected = False
            if case == 'unconscious': user.stat = 1
            if case == 'distant': user.reachable = False
            if case == 'deleted_hide': item.deleted = True
            if case == 'deleted_tool': tool.deleted = True
            if case == 'dropped_tool': tool.loc = site
            if case == 'not_held': user.hands = []
            if case == 'blunt': tool.sharp = False
            if case == 'empty': item.amount = 0
            if case == 'source_moved': item.site = NS(type='turf')
            if case == 'nested_source': item.loc = NS(type='/obj/item/bag')
            if case == 'container_tool': tool.type = '/obj/item/weapon/reagent_containers/glass'
            context = {'src': item, 'user': user, 'tool': tool, 'loc': item.loc, 'source_loc': origin,
                       'site': site, 'amount': item.amount,
                       'hide_worker_can_reach': lambda u, s: gate(reach, {'user':u, 'source':s})}
            with self.subTest(case=case):
                self.assertEqual(bool(gate(valid, context)), case == 'valid')

    def test_cancelled_wait_or_failed_revalidation_cannot_reach_payment(self):
        text = block(source(LEATHER), '/obj/item/stack/material/proc/prepare_hide')
        guard = re.search(r'if \((!completed.*)\)\n\t\treturn FALSE', text)[1]
        for completed, valid in ((False,False), (False,True), (True,False), (True,True)):
            self.assertEqual(gate(guard, {'completed':completed, 'hide_preparation_valid':lambda *a:valid,
                                         'user':None, 'tool':None, 'source_loc':None, 'site':None}), not(completed and valid))
        self.assertLess(text.index('preparing_hide = TRUE'), text.index('hide_preparation_wait'))
        self.assertLess(text.index('preparing_hide = FALSE'), text.index('if (!completed'))
        self.assertLess(text.index('if (!completed'), text.index('if (!use('))

    def assert_single_piece_conversion(self, text):
        prep = block(text, '/obj/item/stack/material/proc/prepare_hide')
        paid = int(re.search(r'if \(!use\((\d+)\)\)', prep)[1])
        made = int(re.search(r'new /obj/item/stack/material/hairlesshide\(site, (\d+)\)', prep)[1])
        self.assertEqual((paid,made), (1,1))
        liquid = block(text, '/obj/item/stack/material/proc/apply_hide_liquid')
        self.assertIn('if (!use(1))', liquid)
        self.assertIn('new output_type(site, 1)', liquid)
        self.assertLess(liquid.index('if (!use(1))'), liquid.index('remove_reagent'))
        self.assertLess(liquid.index('remove_reagent'), liquid.index('new output_type'))
        self.assertEqual(prep.count('new /obj/item/stack/material/hairlesshide'), 1)
        self.assertEqual(prep.count('use(1)'), 1)

    def test_all_processing_stages_preserve_one_piece_per_paid_unit(self):
        text = source(LEATHER)
        self.assert_single_piece_conversion(text)
        self.assertIn('W, "water", /obj/item/stack/material/wethide', text)
        self.assertIn('W, "tannin", /obj/item/stack/material/leather', text)
        rack = block(source(RACK), '/obj/structure/converter/tanning/proc/finish_hide_drying')
        self.assertIn('if (!hide.use(count))', rack)
        self.assertIn('new /obj/item/stack/material/dryhide(src, count, FALSE)', rack)
        self.assertNotIn('leather_amount', text)
        with self.assertRaises(AssertionError):
            self.assert_single_piece_conversion(text.replace('hairlesshide(site, 1)', 'hairlesshide(site, 3)'))
        with self.assertRaises(AssertionError):
            self.assert_single_piece_conversion(baseline(LEATHER))

    def test_liquids_are_exactly_paid_and_closed_empty_or_unheld_vessels_reject(self):
        text = source(LEATHER)
        reach = predicate(text, '/proc/hide_worker_can_reach')
        valid = predicate(text, '/proc/hide_liquid_valid')
        for dose in (0, 1, 4.9, 5, 10):
            for opened in (False,True):
                site,user,item,tool = scenario()
                vessel = NS(type='/obj/item/weapon/reagent_containers/glass', deleted=False,loc=user)
                vessel.is_open_container = lambda: opened
                vessel.reagents = NS(has_reagent=lambda rid,cost: rid == 'water' and dose >= cost)
                user.hands = [vessel]
                context = {'user':user, 'source':item, 'vessel':vessel, 'reagent_id':'water', 'cost':5,
                           'hide_worker_can_reach':lambda u,s:gate(reach,{'user':u,'source':s})}
                self.assertEqual(bool(gate(valid,context)), opened and dose >= 5)
                user.hands = []
                self.assertFalse(gate(valid,context))
        bark = block(text, '/obj/item/stack/bark/attackby')
        consumed = int(re.search(r'remove_reagent\("water", (\d+)\)', bark)[1])
        produced = int(re.search(r'add_reagent\("tannin", (\d+)\)', bark)[1])
        self.assertEqual((consumed,produced), (10,10))
        self.assertLess(bark.index('if (!use(1))'), bark.index('remove_reagent'))
        self.assertNotIn('/touch_obj', text)
        self.assertIn('id = "tannin"', block(text, '/datum/reagent/tannin'))

    def test_rack_accepts_only_wet_hide_not_inherited_lead_or_prepared_hide(self):
        def accepted(text):
            parent = block(text, '/obj/structure/converter')
            child = block(text, '/obj/structure/converter/tanning')
            attrs = dict(re.findall(r'^\t(?:var/)?(input1?) = (\S+)', parent, re.M))
            attrs.update(dict(re.findall(r'^\t(input1?) = (\S+)', child, re.M)))
            return {kind for kind in attrs.values() if kind != 'null'}
        self.assertEqual(accepted(source(RACK)), {'/obj/item/stack/material/wethide'})
        self.assertIn('/obj/item/stack/material/lead', accepted(baseline(RACK)))
        self.assertIn('/obj/item/stack/material/lead', accepted(source(RACK).replace('\tinput1 = null\n', '', 1)))

    def test_rack_stale_cancelled_replaced_or_depleted_batches_reject(self):
        finish = block(source(RACK), '/obj/structure/converter/tanning/proc/finish_hide_drying')
        rejection = re.search(r'\tif \((.*)\)\n\t\treturn FALSE', finish)[1]
        for case in ('valid','deleted_rack','old_epoch','cancelled','moved_rack','deleted_hide','removed_hide','changed_amount','empty','overfull'):
            site,user,item,tool = scenario()
            rack = NS(deleted=False,loc=site)
            item.loc = rack
            item.max_amount = 50
            env = {'src':rack,'epoch':2,'drying_epoch':2,'filled':True,'loc':site,'site':site,'hide':item,'count':3}
            if case == 'deleted_rack': rack.deleted=True
            if case == 'old_epoch': env['epoch']=1
            if case == 'cancelled': env['filled']=False
            if case == 'moved_rack': env['loc']=None
            if case == 'deleted_hide': item.deleted=True
            if case == 'removed_hide': item.loc=site
            if case == 'changed_amount': item.amount=2
            if case == 'empty': env['count']=0; item.amount=0
            if case == 'overfull': env['count']=51; item.amount=51
            with self.subTest(case=case): self.assertEqual(bool(gate(rejection,env)),case!='valid')

    def test_saves_preserve_stage_identities_and_drop_only_runtime_ownership(self):
        text,materials = source(LEATHER),source(MATERIALS)
        for kind in ('rawhide','hairlesshide','wethide','dryhide'):
            decl = block(text,'/obj/item/stack/material/'+kind)
            self.assertIn('default_type = "'+kind+'"',decl)
            self.assertIn('stack_type = /obj/item/stack/material/'+kind,block(materials,'/material/'+kind))
        self.assertEqual(block(materials,'/material/leather'),block(baseline(MATERIALS),'/material/leather'))
        self.assertIn('key == "preparing_hide" || ..()',text)
        rack=source(RACK)
        self.assertIn('"drying_epoch", "filled"',block(rack,'/obj/structure/converter/tanning/persistence_runtime_var'))
        self.assertIn('start_hide_drying(hide)',block(rack,'/obj/structure/converter/tanning/after_load'))
        release=block(rack,'/obj/structure/converter/tanning/proc/release_hides')
        self.assertLess(release.index('drying_epoch++'),release.index('I.forceMove(site)'))
        for method in ('Destroy','Del'):
            self.assertIn('release_hides()',block(rack,'/obj/structure/converter/tanning/'+method))

    def test_bark_is_a_paid_log_byproduct_without_new_mode_or_era_gates(self):
        text=source(SHEETS)
        cut=block(text,'/obj/item/stack/material/wood/proc/cut_logs')
        self.assertLess(cut.index('if (!completed'),cut.index('if (!use(cost))'))
        self.assertLess(cut.index('if (!use(cost))'),cut.index('new /obj/item/stack/bark'))
        self.assertIn('new /obj/item/stack/bark(site, cost)',cut)
        self.assertIn('new /obj/item/stack/material/woodplank(site, planks)',cut)
        for word in ('map.ID','ordinal_age','is_node_done'):
            self.assertNotIn(word,cut+source(LEATHER))
        self.assertIn('/obj/structure/converter/tanning',source('config/crafting/material_recipes_global.txt'))
        self.assertIn('"/obj/structure/converter/tanning" = "resource_processing"',source('code/modules/research_tree/research_node.dm'))

    def test_log_cutter_revalidates_both_tool_routes_stock_and_location(self):
        text,leather=source(SHEETS),source(LEATHER)
        valid=predicate(text,'/obj/item/stack/material/wood/proc/log_cutting_valid')
        reach=predicate(leather,'/proc/hide_worker_can_reach')
        cut=block(text,'/obj/item/stack/material/wood/proc/cut_logs')
        costs=tuple(map(int,re.search(r'var/cost = hatchet \? (\d+) : (\d+)',cut).groups()))
        planks=tuple(map(int,re.search(r'var/planks = hatchet \? (\d+) : (\d+)',cut).groups()))
        self.assertEqual((costs,planks),((2,1),(1,4)))
        for index,kind in enumerate(('/obj/item/weapon/material/hatchet','/obj/item/weapon/saw')):
            for case in ('valid','empty','moved','burning','unheld','disconnected','wrong_tool'):
                site,user,item,tool=scenario()
                tool.type=kind
                if case=='empty': item.amount=costs[index]-1
                if case=='moved': item.loc=None
                if case=='unheld': user.hands=[]
                if case=='disconnected': user.connected=False
                if case=='wrong_tool': tool.type='/obj/item/weapon/material/kitchen/utensil/knife'
                env={'src':item,'user':user,'tool':tool,'source_loc':site,'site':site,'loc':item.loc,
                     'amount':item.amount,'cost':costs[index],'onfire':case=='burning',
                     'hide_worker_can_reach':lambda u,s:gate(reach,{'user':u,'source':s})}
                with self.subTest(tool=kind,case=case):
                    self.assertEqual(bool(gate(valid,env)),case=='valid')


if __name__ == '__main__':
    unittest.main()
