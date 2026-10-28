"""Execute production admission/commit/release bodies with bounded offline adapters."""
from pathlib import Path
import hashlib
import importlib.util
import json
import re
import sys
import struct
import zlib
from types import MethodType, SimpleNamespace as NS
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parent))
from source_adapter import ROOT, SOURCE, block, compile_body

spec=importlib.util.spec_from_file_location('woodwork_atlas',ROOT/'scripts/atlas/woodworking.py')
atlas=importlib.util.module_from_spec(spec)
spec.loader.exec_module(atlas)
TEXT=SOURCE.read_text()
SPECS=atlas.specifications(TEXT)
PREFIX='/datum/primitive_woodwork_action'


def istype(obj,kind):
    return obj is not None and (obj.type==kind or obj.type.startswith(kind+'/'))


class Fixture:
    def __init__(self,mode='pieces',knife=False,text=TEXT):
        self.outputs=[]
        self.namespaces=[]
        self.wait_hook=lambda:True
        self.construct_hook=lambda:None
        self.use_calls=[]
        self.site=NS(type='turf',identity=object())
        self.wood=NS(type='/material/wood',name='wood' if mode in ('pieces','plank') else 'wood_piece',hardness=40)
        self.blade=NS(type='/material/iron',name='iron',hardness=60) if knife or mode=='flatten' else None
        self.tool=NS(type='/obj/item/weapon/material/kitchen/utensil/knife' if knife else '/obj/item/weapon/flint',
                     deleted=False,sharp=True,sharpened=True,health=4,woodwork_owner=None)
        self.tool.get_material=lambda:self.blade
        self.tool.check_health=lambda:setattr(self.tool,'deleted',self.tool.health<=0)
        self.wedge=NS(type='/obj/item/weapon/material/wooden_wedge',deleted=False,health=4,woodwork_owner=None)
        self.wedge.get_material=lambda:NS(name='wood',hardness=40)
        self.wedge.check_health=lambda:setattr(self.wedge,'deleted',self.wedge.health<=0)
        if mode=='plank':
            self.tool.type='/obj/item/weapon/hammer'
        if mode=='flatten':
            self.tool.type='/obj/item/weapon/material/hatchet/tribal/flint'
        self.user=NS(type='/mob/living/human',deleted=False,stat=0,connected=True,reachable=True,
                     site=self.site,woodwork_owner=None)
        self.tool.loc=self.user
        self.wedge.loc=self.user
        self.user.l_hand=self.tool
        self.user.r_hand=self.wedge if mode=='plank' else None
        self.user.get_active_hand=lambda:self.user.l_hand
        self.user.item_is_in_hands=lambda obj:obj is self.user.l_hand or obj is self.user.r_hand
        self.user.incapacitated=lambda:False
        self.user.getStatCoeff=lambda kind:1
        self.source=NS(type='/obj/item/stack/material/wood' if mode in ('pieces','plank') else '/obj/item/stack/material/wood_piece',
                       deleted=False,loc=self.site,site=self.site,amount=SPECS[mode]['cost'],
                       max_amount=50,onfire=False,splitting_in_progress=False,woodwork_owner=None)
        if mode=='flatten':
            self.source.type='/obj/item/stack/material/crude_plank'
        self.source.get_material=lambda:self.wood
        self.source.can_use=lambda count:self.source.amount>=count
        def use(count):
            self.use_calls.append(count)
            self.source.amount-=count
            self.source.deleted=self.source.amount<=0
            return True
        self.source.use=use
        def construct(kind,site,count=1):
            self.outputs.append((kind,count))
            self.construct_hook()
        self.env=dict(QDELETED=lambda obj:obj is None or getattr(obj,'deleted',False),
                      istype=istype,ispath=lambda kind,parent:kind==parent or kind.startswith(parent+'/'),
                      get_turf=lambda obj:obj.site,
                      hide_worker_can_reach=lambda user,source:user.connected and user.reachable and user.stat==0 and not source.deleted and (source.loc is self.site or source.loc is user),
                      woodwork_spec=lambda mode:SPECS.get(mode), woodwork_save_epoch=object(),
                      persistence_save_in_progress=False,persistence_active_operation=None,persistence_load_recovery_required=False,
                      construct=construct,qdel=lambda obj:setattr(obj,'deleted',True),parent_new=lambda:None,
                      round=round,
                      do_after=lambda *args:self.wait_hook(),SPAN_NOTICE=lambda value:value,to_chat=lambda *args:None)
        for name,args in [('woodwork_shaping_tool','tool, workpiece'),('woodwork_wooden_hammer','tool'),('woodwork_wedge','tool'),('woodwork_flattening_tool','tool')]:
            func,ns=compile_body(text,'/proc/'+name+'(',args,self.env)
            self.env[name]=func
            self.namespaces.append(ns)
        declaration=block(text,PREFIX+'\n')
        fields=[]
        self.action=NS(deleted=False)
        for line in declaration.splitlines():
            if line.startswith('\tvar/'):
                left,*right=line.strip().split(' = ',1)
                name=left.rsplit('/',1)[-1]
                fields.append(name)
                setattr(self.action,name,False if right==['FALSE'] else None)
        for name in ('valid','commit','release','perform'):
            func,ns=compile_body(text,PREFIX+'/proc/'+name+'(', 'self',self.env,fields)
            setattr(self.action,name,MethodType(func,self.action))
            self.namespaces.append(ns)
        ctor,ns=compile_body(text,PREFIX+'/New(', 'self, S, H, T, action_mode',self.env,fields)
        self.namespaces.append(ns)
        ctor(self.action,self.source,self.user,self.tool,mode)
        self.ctor=ctor
        self.fields=fields
        self.mode=mode

    def next_action(self):
        previous=self.action
        action=NS(deleted=False)
        for field in self.fields:
            setattr(action,field,False if field in ('claimed','committed') else None)
        for name in ('valid','commit','release','perform'):
            setattr(action,name,MethodType(getattr(previous,name).__func__,action))
        self.ctor(action,self.source,self.user,self.tool,self.mode)
        self.action=action
        return action

    def set_global(self,name,value):
        for ns in self.namespaces:
            ns[name]=value

    def claim(self):
        self.action.claimed=True
        for obj in (self.source,self.user,self.tool):
            obj.woodwork_owner=self.action
        if self.action.wedge:
            self.action.wedge.woodwork_owner=self.action


class WoodworkingContracts(unittest.TestCase):
    def test_each_production_action_pays_exactly_once_and_exhausts_inputs(self):
        for mode,spec in SPECS.items():
            with self.subTest(mode=mode):
                f=Fixture(mode)
                self.assertTrue(f.action.perform())
                self.assertEqual(f.use_calls,[spec['cost']])
                self.assertEqual(f.source.amount,0)
                self.assertEqual(f.outputs,[(spec['output'],spec['count'])]+([('/obj/item/stack/bark',spec['bark'])] if spec['bark'] else []))
                self.assertIsNone(f.user.woodwork_owner)
                self.assertIsNone(f.tool.woodwork_owner)
                self.assertFalse(f.action.commit())
                self.assertEqual(len(f.use_calls),1)

    def test_commit_requires_ownership_not_just_compatible_items(self):
        f=Fixture()
        self.assertFalse(f.action.commit())
        self.assertEqual(f.use_calls,[])

    def test_fractional_or_oversized_counts_cannot_hide_a_dm_numeric_debit(self):
        for count in (1.5,51,16777216):
            f=Fixture()
            f.source.amount=count
            f.action.source_count=count
            self.assertFalse(f.action.perform())
            self.assertEqual(f.use_calls,[])

    def test_cancel_move_transfer_stack_change_tool_loss_and_save_holds_pay_nothing(self):
        mutations={
            'cancel':lambda f:False,
            'source_transfer':lambda f:setattr(f.source,'loc',NS(type='/obj/storage')),
            'actor_move':lambda f:setattr(f.user,'site',NS(type='turf')),
            'stock_split':lambda f:setattr(f.source,'amount',f.source.amount+1),
            'tool_transfer':lambda f:setattr(f.tool,'loc',f.site),
            'tool_loss':lambda f:setattr(f.tool,'deleted',True),
            'hand_swap':lambda f:setattr(f.user,'l_hand',None),
            'tool_wear_elsewhere':lambda f:setattr(f.tool,'health',3),
            'disconnect':lambda f:setattr(f.user,'connected',False),
            'incapacitated':lambda f:setattr(f.user,'incapacitated',lambda:True),
            'unconscious':lambda f:setattr(f.user,'stat',1),
            'burning':lambda f:setattr(f.source,'onfire',True),
            'legacy_cutter':lambda f:setattr(f.source,'splitting_in_progress',True),
            'save_busy':lambda f:f.set_global('persistence_save_in_progress',True),
            'operation_busy':lambda f:f.set_global('persistence_active_operation',object()),
            'recovery_hold':lambda f:f.set_global('persistence_load_recovery_required',True),
            'save_completed_during_wait':lambda f:f.set_global('woodwork_save_epoch',object()),
        }
        for name,mutate in mutations.items():
            f=Fixture()
            f.wait_hook=lambda:False if mutate(f) is False else True
            with self.subTest(name=name):
                self.assertFalse(f.action.perform())
                self.assertEqual(f.use_calls,[])
                self.assertEqual(f.outputs,[])
                self.assertIsNone(f.user.woodwork_owner)

    def test_split_requires_real_wooden_hammer_and_held_wedge(self):
        for change in ('missing','dropped','broken','modern_hammer','metal_wedge','claimed_wedge'):
            f=Fixture('plank')
            if change=='missing': f.action.wedge=None
            if change=='dropped': f.wedge.loc=f.site
            if change=='broken': f.wedge.health=0
            if change=='modern_hammer': f.tool.type='/obj/item/weapon/hammer/modern'
            if change=='metal_wedge': f.wedge.get_material=lambda:NS(name='steel',hardness=60)
            if change=='claimed_wedge': f.wedge.woodwork_owner=object()
            with self.subTest(change=change):
                self.assertFalse(f.action.perform())
                self.assertEqual(f.use_calls,[])
        f=Fixture('plank')
        f.wait_hook=lambda:setattr(f.wedge,'loc',f.site) or True
        self.assertFalse(f.action.perform())
        self.assertEqual(f.use_calls,[])

    def test_shaping_uses_actual_material_hardness_and_explicit_flint_exception(self):
        for hardness,accepted in ((39,False),(40,False),(41,True),(90,True)):
            f=Fixture(knife=True)
            f.blade.hardness=hardness
            # Snapshot after selecting actual workpiece/blade values.
            f.action.blade_hardness=hardness
            with self.subTest(hardness=hardness): self.assertEqual(bool(f.action.valid()),accepted)
        for kind in ('/obj/item/weapon/material/sword','/obj/item/weapon/material/hatchet','/obj/item/weapon/saw'):
            f=Fixture(knife=True)
            f.tool.type=kind
            f.blade.hardness=1000
            self.assertFalse(f.action.valid())
        f=Fixture()
        self.assertTrue(f.action.valid())
        f.tool.sharpened=False
        self.assertFalse(f.action.valid())
        f=Fixture(knife=True)
        f.wait_hook=lambda:setattr(f.blade,'hardness',40) or True
        self.assertFalse(f.action.perform())

    def test_partial_stack_repetition_and_constructor_reentry_cannot_duplicate(self):
        f=Fixture('plank')
        f.source.amount=4
        f.action.source_count=4
        reentry=[]
        f.construct_hook=lambda:reentry.append(f.action.commit())
        self.assertTrue(f.action.perform())
        self.assertEqual(f.source.amount,2)
        self.assertTrue(all(value is False for value in reentry))
        self.assertEqual(f.use_calls,[2])
        self.assertIsNone(f.source.woodwork_owner)
        self.assertTrue(f.next_action().perform())
        self.assertEqual(f.source.amount,0)
        self.assertEqual(f.use_calls,[2,2])
        self.assertFalse(f.next_action().perform())
        self.assertEqual(f.use_calls,[2,2])

    def test_mutation_controls_expose_missing_save_and_knife_type_guards(self):
        weakened=TEXT.replace(' || save_epoch != woodwork_save_epoch','')
        self.assertNotEqual(weakened,TEXT)
        f=Fixture(text=weakened)
        f.wait_hook=lambda:f.set_global('woodwork_save_epoch',object()) or True
        self.assertTrue(f.action.perform(), 'control must reproduce false completion across a save')
        weakened=TEXT.replace('!istype(tool, /obj/item/weapon/material/kitchen/utensil/knife) || ','')
        f=Fixture(knife=True,text=weakened)
        f.tool.type='/obj/item/weapon/material/sword'
        self.assertTrue(f.action.valid(), 'control must expose an arbitrary harder non-knife tool')

    def test_wait_claim_and_stale_release_do_not_take_newer_owner(self):
        f=Fixture('plank')
        newer=object()
        def wait():
            self.assertTrue(f.action.claimed)
            self.assertIs(f.user.woodwork_owner,f.action)
            self.assertIs(f.wedge.woodwork_owner,f.action)
            f.tool.woodwork_owner=newer
            return True
        f.wait_hook=wait
        self.assertFalse(f.action.perform())
        self.assertIs(f.tool.woodwork_owner,newer)
        self.assertEqual(f.use_calls,[])

    def test_successful_material_tool_wear_and_nonmaterial_flint_convention(self):
        f=Fixture(knife=True)
        self.assertTrue(f.action.perform())
        self.assertEqual(f.tool.health,3.75)
        f=Fixture()
        self.assertTrue(f.action.perform())
        self.assertEqual(f.tool.health,4)
        f=Fixture('plank')
        self.assertTrue(f.action.perform())
        self.assertEqual(f.wedge.health,3.75)
        self.assertEqual(f.tool.health,4)

    def test_save_epoch_hook_is_on_admitted_operation_constructor_and_owners_excluded(self):
        funcs=(ROOT/'code/modules/persistence/functions.dm').read_text()
        begin=block(funcs,'/proc/begin_persistence_operation(')
        self.assertLess(begin.index('if(transaction'),begin.index('operation = new'))
        self.assertLess(begin.index('operation = new'),begin.index('persistence_active_operation = operation'))
        constructor=block(TEXT,'/datum/persistence_world_operation/New()')
        self.assertIn('woodwork_save_epoch = new /datum',constructor)
        self.assertIn('key == "woodwork_owner"',block(funcs,'/atom/movable/persistence_runtime_var('))
        self.assertIn('should_save = FALSE',block(TEXT,PREFIX+'\n'))

    def test_balances_atlas_and_hosted_wiring_are_source_bound(self):
        self.assertEqual((SPECS['plank']['cost'],SPECS['plank']['count'],SPECS['plank']['delay']),(2,1,240))
        self.assertEqual(SPECS['pieces']['cost'],SPECS['pieces']['count'])
        self.assertEqual(SPECS['mallet']['cost'],5)
        self.assertEqual(SPECS['mallet']['output'],'/obj/item/weapon/hammer/tribalhammer')
        records=[]
        def add(*args): records.append(args)
        variants={}
        routes=atlas.add_woodworking({atlas.SOURCE:TEXT},add,[],variants)
        self.assertEqual(len(routes),5)
        self.assertTrue(all('not guaranteed' in row['conditions'] for row in routes))
        workflow=(ROOT/'.github/workflows/test.yml').read_text()
        self.assertIn("'tests/primitive_woodworking'",workflow)
        self.assertIn('unittest discover -s tests/primitive_woodworking',workflow)
        dme=(ROOT/'civ13.dme').read_text()
        self.assertIn('primitive_woodworking.dm',dme)
        recipes=(ROOT/'config/crafting/material_recipes_global.txt').read_text()
        self.assertIn('/material/wood/soft/,wood handle,',recipes)
        self.assertIn('/material/wood/soft/,plank handle,',recipes)
        with self.assertRaises(ValueError):
            atlas.specifications(TEXT+'\n\t\tif ("unreviewed")\n\t\t\treturn list("cost" = 1, "count" = 1, "delay" = 1, "output" = /obj/item/stack/bark, "bark" = 0)\n')

    def test_crude_planks_require_flattening_and_never_charge_tool_wear(self):
        self.assertEqual(SPECS['plank']['output'],'/obj/item/stack/material/crude_plank')
        self.assertEqual((SPECS['flatten']['cost'],SPECS['flatten']['count']),(1,1))
        f=Fixture('flatten')
        f.tool.check_health=lambda:self.fail('flattening must not charge axe wear')
        self.assertTrue(f.action.perform())
        self.assertEqual(f.tool.health,4)
        self.assertEqual(f.outputs,[('/obj/item/stack/material/woodplank',1)])
        f=Fixture('flatten')
        f.wait_hook=lambda:setattr(f.tool,'loc',f.site) or True
        self.assertFalse(f.action.perform())
        self.assertEqual(f.use_calls,[])
        self.assertEqual(f.tool.health,4)
        materials=(ROOT/'code/modules/materials/materials.dm').read_text()
        crude=block(materials,'/material/wood/crude_plank\n')
        self.assertIn('processing_only = TRUE',crude)
        self.assertIn('stack_type = /obj/item/stack/material/crude_plank',crude)
        recipes=(ROOT/'config/crafting/material_recipes_global.txt').read_text()
        self.assertNotIn('/material/wood/crude_plank/',recipes)
        item=block(TEXT,'/obj/item/stack/material/crude_plank\n')
        self.assertIn('default_type = "crude_plank"',item)
        self.assertNotIn('parent_type = /obj/item/stack/material/woodplank',item)

    def test_flattening_admits_sharp_nonwood_objects_and_flint_but_not_wood(self):
        for kind in ('/obj/item/weapon/material/sword','/obj/item/weapon/material/hatchet','/obj/item/weapon/material/kitchen/utensil/knife'):
            f=Fixture('flatten')
            f.tool.type=kind
            f.tool.tool_handle_material='wood'
            self.assertTrue(f.action.perform())
            self.assertEqual(f.tool.health,4)
        f=Fixture('flatten')
        f.tool.type='/obj/item/weapon/flint'
        f.blade=None
        f.action.blade=None
        self.assertTrue(f.action.perform())
        for working_type in ('/material/wood','/material/wood/hard','/material/wood/soft'):
            f=Fixture('flatten')
            f.blade.type=working_type
            self.assertFalse(f.action.valid())
        f=Fixture('flatten')
        f.tool.get_material=lambda:None
        f.action.blade=None
        self.assertFalse(f.action.valid())
        f=Fixture('flatten')
        f.tool.sharp=False
        self.assertFalse(f.action.valid())
        f=Fixture('flatten')
        f.wait_hook=lambda:setattr(f.blade,'type','/material/wood') or True
        self.assertFalse(f.action.perform())
        self.assertEqual(f.use_calls,[])

    def test_generated_help_keeps_crude_and_finished_routes_distinct(self):
        path=ROOT/'UI/crafting-atlas.json'
        bridge_spec=importlib.util.spec_from_file_location('woodwork_help',ROOT/'scripts/player_help_bridge.py')
        bridge=importlib.util.module_from_spec(bridge_spec)
        bridge_spec.loader.exec_module(bridge)
        rows=bridge.acquisition_context(path)
        split=[row for row in rows if 'Split crude planks with wooden hammer and wedge' in row['text']]
        flattened=[row for row in rows if 'Flatten crude planks with a sharp non-wooden tool' in row['text']]
        self.assertTrue(split)
        self.assertTrue(flattened)
        self.assertTrue(all('before finished-plank recipes' in row['text'] for row in split))
        self.assertTrue(all('Sharpened flint qualifies' in row['text'] for row in flattened))
        data=json.loads(path.read_text())
        crude='/material/wood/crude_plank'
        finished='/material/wood/soft'
        self.assertIn(crude,data['resources'])
        self.assertIn(finished,data['resources'])
        handle_recipes=[row for row in data['recipes'] if any(out['id']=='/obj/item/weapon/material/handle' for out in row.get('outputs',[]))]
        self.assertTrue(handle_recipes)
        self.assertFalse(any(item['id']==crude for row in handle_recipes for item in row['inputs']))

    def test_reused_art_states_exist_in_actual_png_metadata(self):
        for path,state in [('icons/obj/materials.dmi','sheet-wood'),('icons/obj/old_weapons.dmi','sharpened_stick'),('icons/misc/tribal.dmi','tribalhammer')]:
            raw=(ROOT/path).read_bytes()
            self.assertEqual(raw[:8],b'\x89PNG\r\n\x1a\n')
            offset=8
            descriptions=[]
            while offset<len(raw):
                length=struct.unpack('>I',raw[offset:offset+4])[0]
                kind=raw[offset+4:offset+8]
                data=raw[offset+8:offset+8+length]
                offset+=length+12
                if kind==b'zTXt':
                    key,payload=data.split(b'\0',1)
                    if key==b'Description':
                        self.assertEqual(payload[0],0)
                        descriptions.append(zlib.decompress(payload[1:]).decode())
                elif kind==b'tEXt':
                    key,payload=data.split(b'\0',1)
                    if key==b'Description': descriptions.append(payload.decode())
            states=re.findall(r'^state = "([^"]*)"','\n'.join(descriptions),re.M)
            self.assertIn(state,states,(path,state))


if __name__=='__main__':
    unittest.main()
