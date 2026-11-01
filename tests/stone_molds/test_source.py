"""Offline current-source projections. No BYOND, network, game or saves."""
from pathlib import Path
from types import SimpleNamespace as NS
import importlib.util
import json
import re
import struct
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[2]
MOLDS = 'code/game/objects/structures/blacksmithing/molds.dm'
STACK = 'code/game/objects/items/stacks/stack.dm'
_spec = importlib.util.spec_from_file_location('stone_mold_source_adapter', ROOT/'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(adapter)
SHAPES = {'': (3,100,'ingots','bronze_working'), 'axehead': (3,10,'axes','stone_arms'),
          'sword': (10,40,'swords','stone_arms'), 'knife': (2,20,'knives','stone_arms'),
          'spearhead': (3,3,'spearheads','stone_arms'), 'pickaxe': (6,3,'pickaxes','stone_arms'),
          'shovel': (6,3,'shovels','basic_tools'), 'arrowhead': (2,50,'arrowheads','stone_arms')}

def read(path):
    return (ROOT/path).read_text(encoding='utf-8')

def path(shape):
    return '/obj/item/weapon/clay/mold/' + (shape+'/' if shape else '') + 'fired/sandstone'

def block(source, typepath):
    match = re.search(r'^'+re.escape(typepath)+r'\n((?:\t[^\n]*\n|\n)*)', source, re.M)
    if not match:
        raise AssertionError('Missing type '+typepath)
    return match[1]

def sprite_states():
    raw=(ROOT/'icons/obj/metallurgy.dmi').read_bytes()
    offset=8
    while offset < len(raw):
        size,kind=struct.unpack('>I4s',raw[offset:offset+8])
        data=raw[offset+8:offset+8+size]
        if kind==b'zTXt' and data.startswith(b'Description\x00\x00'):
            return zlib.decompress(data[len(b'Description\x00\x00'):]).decode()
        offset+=size+12
    raise AssertionError('Missing DMI metadata')

def commit_contract(stack):
    # Legacy stack code contains unindented block comments inside this proc.
    # Select through the next absolute declaration, preserving the full body.
    body = re.split(r'\n/(?=\w)', stack.split('/obj/item/stack/proc/produce_recipe(',1)[1],maxsplit=1)[0]
    assert body.count('!carving.valid()') == 2, 'admission and completion guards'
    assert body.index('!do_after(user, buildtime)') < body.rindex('!carving.valid()') < body.index('if (use(required,'), 'post-wait before payment'
    assert body.index('if (use(required,') < body.index('if ((joinery || carving) && H && recipe.time)') < body.index('O = new recipe.result_type'), 'paid XP and output'
    assert 'quantity != 1 || !carving.valid()' in body, 'single mold batch'
    assert '(joinery || carving) ? null : H' in body, 'exact paid material'
    assert 'H && !joinery && !carving' in body, 'no prepayment XP'

def project_valid(source, **changes):
    """Translate the complete production valid() proc; only engine calls are fakes."""
    site, epoch = object(), object()
    actor = NS(civilization='test', woodwork_owner=False, loc=site,
               incapacitated=lambda: False)
    stock = NS(loc=actor, woodwork_owner=False, amount=20,
               crafting_stack_accessible=lambda h: True,
               get_material=lambda: NS(type='/material/sandstone'))
    stock.can_use = lambda n: stock.amount >= n
    recipe = NS(result_type=path('axehead'), req_amount=3)
    tools = {'chisel': NS(available=True), 'hammer': NS(available=True)}
    env = dict(actor=actor, stock=stock, recipe=recipe, stock_loc=actor, site=site,
               save_epoch=epoch, tools=tools, persistence_admission_identity=epoch,
               persistence_save_in_progress=False, persistence_active_operation=False,
               persistence_load_recovery_required=False,
               QDELETED=lambda x: x is None or getattr(x,'deleted',False),
               get_turf=lambda h: h.loc, stone_mold_type=lambda p: p==path('axehead'),
               get_recipe_node_req=lambda p: 'stone_arms',
               map=NS(ordinal_age=0, is_node_done=lambda f,n: True),
               list=lambda *args: args,
               stone_mold_tool_available=lambda h,i,r: i is not None and i.available)
    for key, value in changes.items():
        if '.' in key:
            target, field = key.split('.')
            setattr(env[target], field, value)
        else:
            env[key] = value
    # Explicit DM typepath and interpolation boundaries; every proc line executes.
    source = source.replace('actual.type != /material/sandstone', 'actual.type != "sandstone_type"')
    stock_material = stock.get_material
    stock.get_material = lambda: NS(type='sandstone_type' if stock_material().type=='/material/sandstone' else 'other')
    source = source.replace('get_recipe_node_req("[recipe.result_type]")', 'get_recipe_node_req(recipe.result_type)')
    return adapter.project(source, '/datum/stone_mold_carving/proc/valid', '', env)()

class StoneMoldTests(unittest.TestCase):
    def test_recipes_preserve_clay_and_match_obtainable_stone_tools(self):
        rows = [line.split('RECIPE: ',1)[1].split(',') for line in read('config/crafting/material_recipes_global.txt').splitlines()
                if line.startswith('RECIPE: ')]
        by_output = {r[2]:r for r in rows}
        nodes = dict(re.findall(r'"(/obj/[^"]+)" = "([^"]+)"', read('code/modules/research_tree/research_node.dm')))
        for shape,(cost,capacity,kind,gate) in SHAPES.items():
            with self.subTest(shape=shape):
                row=by_output[path(shape)]
                self.assertEqual(len(row),13)
                self.assertEqual(row[0],'/material/sandstone/')
                self.assertEqual(row[3:], [str(cost),'120','0','1','molds','0','0','0','8','null'])
                self.assertEqual(nodes[path(shape)],gate)
                clay='/obj/item/weapon/clay/mold'+('/'+shape if shape else '')
                self.assertEqual(nodes[clay],gate)
                self.assertIn(clay,by_output)
        self.assertFalse(any('claypot/fired/sandstone' in r[2] or 'key/fired/sandstone' in r[2] for r in rows))
        self.assertEqual(nodes['/obj/item/weapon/chisel'],'basic_tools')
        self.assertEqual(nodes['/obj/item/weapon/hammer'],'basic_tools')
        mining=read('code/game/turfs/floor_attackby.dm')
        self.assertIn('new/obj/item/stack/material/sandstone(src)',mining)
        self.assertIn('/turf/floor/dirt/underground/sandy',mining)

    def test_inherited_casting_capacity_icons_and_prototypes(self):
        source=read(MOLDS)
        for shape,(_,capacity,kind,_) in SHAPES.items():
            with self.subTest(shape=shape):
                stone=block(source,path(shape))
                clay=block(source,path(shape).removesuffix('/sandstone'))
                for value in ('stone_mold = TRUE','result = null','color = SANDSTONE_MOLD_COLOR'):
                    self.assertIn(value,stone)
                for value in ('fired = TRUE',f'max_capacity = {capacity}',f'craftable_classes = "{kind}"'):
                    self.assertIn(value,clay)
                base=shape or 'ingot'
                for state in (f'{base}_mold_empty',f'{base}_mold_full'):
                    self.assertIn('state = "'+state+'"',sprite_states())
        nodes=read('code/modules/research_tree/research_node.dm')
        self.assertIn('null, 1, /obj/item/weapon/clay/mold/axehead)',nodes)
        self.assertTrue(path('axehead').startswith('/obj/item/weapon/clay/mold/axehead/'))
        self.assertIn('istype(W, N.prototype_type)',read('code/modules/research_tree/research_bench.dm'))
        for file in ('blacksmithing.dm','refining.dm'):
            self.assertIn('/obj/item/weapon/clay/mold',read('code/game/objects/structures/blacksmithing/'+file))
        self.assertIn('if (istype(I, /obj/item/weapon/clay/mold))',source)

    def test_complete_valid_proc_rejects_late_changes(self):
        source=read(MOLDS)
        self.assertTrue(project_valid(source))
        cases=[{'stock.amount':2}, {'stock.loc':object()}, {'actor.loc':object()},
               {'actor.woodwork_owner':True}, {'stock.woodwork_owner':True},
               {'persistence_save_in_progress':True}, {'persistence_active_operation':True},
               {'persistence_load_recovery_required':True}, {'persistence_admission_identity':object()},
               {'tools':{'chisel':None,'hammer':NS(available=True)}},
               {'tools':{'chisel':NS(available=False),'hammer':NS(available=True)}},
               {'map':NS(ordinal_age=0,is_node_done=lambda f,n:False)},
               {'stock.get_material':lambda: NS(type='/material/stone')},
               {'get_recipe_node_req':lambda p:None}]
        for case in cases:
            with self.subTest(change=case):
                self.assertFalse(project_valid(source,**case))

    def test_causal_omission_controls(self):
        source=read(MOLDS)
        for guard,case in [('save_epoch != persistence_admission_identity', {'persistence_admission_identity':object()}),
                           ('actual.type != /material/sandstone', {'stock.get_material':lambda: NS(type='/material/stone')}),
                           ('!map.is_node_done(actor.civilization, node)', {'map':NS(ordinal_age=0,is_node_done=lambda f,n:False)})]:
            with self.subTest(guard=guard):
                self.assertEqual(source.count(guard),1)
                mutated=source.replace(guard,'FALSE')
                self.assertFalse(project_valid(source,**case))
                self.assertTrue(project_valid(mutated,**case))
        stack=read(STACK)
        commit_contract(stack)
        mutated=stack.replace('if (carving && !carving.valid())','if (FALSE)')
        with self.assertRaises(AssertionError):
            commit_contract(mutated)

    def test_tools_are_real_equipment_or_bounded_ground_and_retained(self):
        source=read(MOLDS)
        tool=adapter.extract(source,'/proc/stone_mold_tool_available')
        for token in ('I.health <= 0','I.woodwork_owner','H.get_inventory_slot(I)','I.loc == get_turf(H)',
                      '/obj/item/weapon/chisel','/obj/item/weapon/hammer','/obj/item/weapon/gongmallet'):
            self.assertIn(token,tool)
        constructor=adapter.extract(source,'/datum/stone_mold_carving/New')
        self.assertIn('++visited > 32',constructor)
        self.assertIn('H.get_equipped_item(slot)',constructor)
        valid=adapter.extract(source,'/datum/stone_mold_carving/proc/valid')
        self.assertIn('tools[role]',valid)
        self.assertNotIn('get_equipped_item',valid)

    def test_oven_guard_and_reference_instructions(self):
        oven=read('code/game/objects/structures/kitchen/oven.dm')
        branch=oven.split('var/obj/item/weapon/clay/CL = I',1)[1]
        self.assertLess(branch.index('if (stone_mold_type(CL.type))'),branch.index('contents += new CL.result(src)'))
        self.assertIn('continue // Carved stone',branch)
        self.assertIn('no firing needed',read(STACK))
        for file in ('scripts/build-crafting-atlas.py','scripts/player_help_bridge.py'):
            source=read(file)
            self.assertIn('hammer/mallet',source)
            self.assertIn('fired clay blacksmith pot/jug',source)
        self.assertIn('stone_molds',read('scripts/ci_baseline.py'))

    def test_generated_atlas_names_gates_and_native_wiring(self):
        catalog=json.loads(read('UI/crafting-atlas.json'))
        required=json.loads(read('tests/sprites/required-types.json'))
        for shape in SHAPES:
            with self.subTest(shape=shape):
                row=next(r for r in catalog['recipes'] if r['outputs'][0]['id']==path(shape))
                name='sandstone '+(shape or 'ingot')+' mold'
                self.assertEqual(row['outputs'][0]['name'],name)
                self.assertEqual(catalog['resources'][path(shape)]['name'],name)
                self.assertIn('hammer/mallet',row['conditions'])
                self.assertIn('Ready without firing',row['conditions'])
                self.assertIn('Explicit research node: '+SHAPES[shape][3],row['conditions'])
                self.assertIn(path(shape),required)
        self.assertIn('recipe_ci_stone_molds()',read('tests/crafting/checks.dm'))
        self.assertIn('/tests/crafting/stone_molds.dm',read('scripts/check-recipes.py'))

if __name__=='__main__':
    unittest.main()
