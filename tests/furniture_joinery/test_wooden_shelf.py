"""Execute actual shared refund bodies with source-derived subtype defaults.

Offline constructors, waits and chat are adapters; this does not run DM.
The compiled crafting fixture separately contains native lifecycle assertions.
"""
from collections import Counter
import json
from pathlib import Path
import re
import struct
import sys
from types import SimpleNamespace as NS
import unittest
import zlib

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests/primitive_woodworking'))
from source_adapter import block,expr

TABLE=(ROOT/'code/game/objects/structures/table.dm').read_text()
RACK=(ROOT/'code/game/objects/structures/table_rack.dm').read_text()
FRAME=(ROOT/'code/game/objects/structures/table_frames.dm').read_text()
FIELDS=('frame','framestack','buildstack','framestackamount','buildstackamount','deconstructable','loc')


def defaults(text,signature):
    values={}
    for line in block(text,signature).splitlines()[1:]:
        line=line.split('//')[0].rstrip()
        m=re.fullmatch(r'\t(?:var/)?(\w+) = ([^/\n]+|/[^\n]+)',line)
        if m and m[1] in FIELDS+('flammable',):
            value=m[2].split('//')[0].strip()
            values[m[1]]=True if value=='TRUE' else False if value=='FALSE' else int(value) if value.isdigit() else value
    return values


def project(text,signature,args):
    text=re.sub(r'/\*.*?\*/','',text,flags=re.S)
    output=['def procedure(self,'+args+'):']
    for raw in block(text,signature).splitlines()[1:]:
        line=raw.split('//')[0].rstrip()
        if not line.strip():continue
        depth=len(line)-len(line.lstrip('\t'));line=line.strip()
        if line=='..()':line='parent_attack()'
        elif line=='if (S) shards += S':line='if S: shards.append(S)'
        elif line.startswith('if ('):line='if '+expr(line[4:-1],FIELDS)+':'
        elif line.startswith('else if ('):line='elif '+expr(line[9:-1],FIELDS)+':'
        elif line=='else':line='else:'
        elif line.startswith('for ('):
            m=re.fullmatch(r'for \(var/i = TRUE, i <= (\w+), i\+\+\)',line)
            if not m:raise AssertionError('Unreviewed loop: '+line)
            line='for i in range(1,int('+expr(m[1],FIELDS)+')+1):'
        elif line.startswith('var/'):
            left,right=line.split(' = ',1);line=left.rsplit('/',1)[-1]+' = '+expr(right,FIELDS)
        elif line.startswith('new '):
            m=re.fullmatch(r'new ([\w/]+)\s*\((.*)\)',line)
            if not m:raise AssertionError('Unreviewed constructor: '+line)
            line='construct('+expr(m[1],FIELDS)+','+expr(m[2],FIELDS)+')'
        elif line=='return':pass
        elif line.startswith('return '):line='return '+expr(line[7:],FIELDS)
        else:line=expr(line,FIELDS)
        output.append('    '*depth+line)
    return '\n'.join(output)+'\n'


class RefundFixture:
    def __init__(self,wooden=True,wait=True,subtype='/obj/structure/table/rack/shelf/wooden'):
        values=defaults(TABLE,'/obj/structure/table\n')
        if wooden:values.update(defaults(RACK,subtype+'\n'))
        self.model=NS(**values,loc='floor',deleted=False)
        self.outputs=Counter()
        self.env=dict(construct=lambda kind,loc:self.outputs.update([kind]),
                      qdel=lambda obj:setattr(obj,'deleted',True),get_turf=lambda obj:'floor',
                      to_chat=lambda *args:None,playsound=lambda *args:None,do_after=lambda *a,**k:wait,
                      TBL_DESTROY=1,TBL_DISASSEMBLE=2,TBL_DECONSTRUCT=3,
                      map=NS(ID='ordinary'),MAP_WIZARD_BOY='wizard',prob=lambda value:False,
                      get_material_by_name=lambda value:None,DEFAULT_WALL_MATERIAL='steel',
                      istype=lambda obj,kind:obj.type==kind)

    def call(self,source,signature,args,*values):
        env=dict(self.env);exec(compile(project(source,signature,args),'<production refund>', 'exec'),env)
        return env['procedure'](self.model,*values)

    def destroy(self,mode):
        self.call(TABLE,'/obj/structure/table/proc/table_destroy(', 'destroy_type,user',mode,None)


class WoodenShelfContracts(unittest.TestCase):
    def test_only_wooden_subtype_replaces_metal_defaults(self):
        base=defaults(TABLE,'/obj/structure/table\n')
        self.assertEqual({k:base[k] for k in ('frame','framestack','buildstack','framestackamount','buildstackamount')},
                         dict(frame='/obj/structure/table_frame',framestack='/obj/item/stack/rods',buildstack='/obj/item/stack/material/iron',framestackamount=2,buildstackamount=True))
        self.assertEqual(defaults(RACK,'/obj/structure/table/rack/shelf\n'),{})
        wooden=RefundFixture().model
        self.assertEqual(wooden.frame,'/obj/structure/table_frame/wood')
        self.assertEqual(wooden.framestack,wooden.buildstack)
        self.assertEqual(wooden.buildstack,'/obj/item/stack/material/woodplank')
        self.assertTrue(wooden.flammable)

    def test_actual_destroy_and_deconstruct_recover_three_planks(self):
        for mode in (1,3):
            f=RefundFixture();f.destroy(mode)
            self.assertTrue(f.model.deleted)
            self.assertEqual(f.outputs,{'/obj/item/stack/material/woodplank':3})

    def test_actual_disassembly_and_frame_wrench_refund_only_wood(self):
        f=RefundFixture();f.destroy(2)
        self.assertEqual(f.outputs,{'/obj/structure/table_frame/wood':1,'/obj/item/stack/material/woodplank':1})
        f.outputs.clear()
        frame=defaults(FRAME,'/obj/structure/table_frame\n')
        frame.update(defaults(FRAME,'/obj/structure/table_frame/wood\n'))
        f.model=NS(**frame,loc='floor',deleted=False)
        # The actual wooden frame delegates its wrench branch to this parent.
        self.assertIn('if (istype(I, /obj/item/weapon/wrench))\n\t\t..()',FRAME)
        f.call(FRAME,'/obj/structure/table_frame/attackby(', 'I,user,params',NS(type='/obj/item/weapon/wrench'),None,None)
        self.assertEqual(f.outputs,{'/obj/item/stack/material/wood':2})

    def test_broken_parts_and_legacy_wizard_conversion_keep_wood(self):
        for map_id,kind in [('ordinary','/obj/item/stack/material/woodplank'),('wizard','/obj/item/wand_part/mdf_board')]:
            f=RefundFixture();f.env['map'].ID=map_id
            f.call(TABLE,'/obj/structure/table/proc/break_to_parts(', 'full_return',False)
            self.assertEqual(f.outputs,{kind:1})

    def test_interrupted_disassembly_and_deconstruction_refund_nothing(self):
        for mode in (2,3):
            f=RefundFixture(wait=False);f.destroy(mode)
            self.assertFalse(f.model.deleted);self.assertFalse(f.outputs)

    def test_old_inherited_metal_is_detected_and_recovery_cannot_exceed_cost(self):
        old=RefundFixture(wooden=False);old.destroy(3)
        self.assertEqual(old.outputs,{'/obj/item/stack/rods':2,'/obj/item/stack/material/iron':1})
        rows=[r.split('RECIPE: ',1)[1].split(',') for r in (ROOT/'config/crafting/material_recipes_global.txt').read_text().splitlines() if r.startswith('RECIPE: ')]
        shelf=[r for r in rows if r[2]=='/obj/structure/table/rack/shelf/wooden']
        self.assertEqual(len(shelf),1);self.assertEqual((shelf[0][0],shelf[0][3],shelf[0][11]),('/material/wood/soft/','6','8'))
        for mode in (1,3):
            f=RefundFixture();f.destroy(mode)
            self.assertLessEqual(sum(f.outputs.values()),int(shelf[0][3]))
        # Wood frame + top -> 2 logs + 1 plank after full disassembly, also < 6.
        self.assertLess(2+1,int(shelf[0][3]))

    def test_atlas_research_material_and_actual_art(self):
        data=json.loads((ROOT/'UI/crafting-atlas.json').read_text())
        recipe=next(r for r in data['recipes'] if r['outputs'][0]['id']=='/obj/structure/table/rack/shelf/wooden')
        self.assertEqual(recipe['unlock_eras'],[2])
        self.assertEqual(recipe['inputs'][0]['id'],'/material/wood/soft')
        self.assertEqual(recipe['inputs'][0]['quantity'],'6')
        self.assertIn('fine_furniture',recipe['conditions'])
        blob=(ROOT/'icons/obj/structures.dmi').read_bytes();pos=8;metadata=''
        while pos<len(blob):
            size=struct.unpack('>I',blob[pos:pos+4])[0];kind=blob[pos+4:pos+8];data=blob[pos+8:pos+8+size];pos+=size+12
            if kind==b'zTXt':metadata+=zlib.decompress(data.split(b'\0',1)[1][1:]).decode()
            elif kind==b'tEXt':metadata+=data.decode(errors='replace')
        self.assertIn('state = "shelfwood"',metadata)


class WoodenFurnitureRefundContracts(unittest.TestCase):
    CASES=(('/obj/structure/table/fancy',7,3,1),
           ('/obj/structure/table/rack/coatrack',3,2,0))

    def test_all_catalog_inputs_are_wood_and_existing_costs_are_retained(self):
        rows=[line.split('RECIPE: ',1)[1].split(',')
              for path in (ROOT/'config/crafting').glob('*.txt')
              for line in path.read_text().splitlines() if line.startswith('RECIPE: ')]
        for subtype,cost,_,_ in self.CASES:
            routes=[r for r in rows if r[2]==subtype]
            self.assertEqual(len(routes),7)
            self.assertEqual({(r[0],int(r[3])) for r in routes},
                             {('/material/wood/',cost),('/material/wood/soft/',cost)})

    def test_production_recovery_and_cancellation_for_both_wood_types(self):
        for subtype,cost,recovery,top in self.CASES:
            for mode in (1,3):
                f=RefundFixture(subtype=subtype);f.destroy(mode)
                self.assertEqual(f.outputs,{'/obj/item/stack/material/woodplank':recovery})
                self.assertTrue(f.model.deleted);self.assertLess(recovery,cost)
            f=RefundFixture(subtype=subtype)
            f.call(TABLE,'/obj/structure/table/proc/break_to_parts(', 'full_return',False)
            self.assertEqual(f.outputs,{'/obj/item/stack/material/woodplank':1})
            for mode in (2,3):
                f=RefundFixture(subtype=subtype,wait=False);f.destroy(mode)
                self.assertFalse(f.outputs);self.assertFalse(f.model.deleted)

    def test_disassembled_frame_cycles_lose_wood_instead_of_farming_residue(self):
        for subtype,cost,_,top in self.CASES:
            f=RefundFixture(subtype=subtype);f.destroy(2)
            expected=Counter({'/obj/structure/table_frame/wood':1})
            if top:expected['/obj/item/stack/material/woodplank']=top
            self.assertEqual(f.outputs,expected)
            self.assertTrue(f.model.flammable)
            frame=defaults(FRAME,'/obj/structure/table_frame\n')
            frame.update(defaults(FRAME,'/obj/structure/table_frame/wood\n'))
            f.model=NS(**frame,loc='floor',deleted=False);f.outputs.clear()
            f.call(FRAME,'/obj/structure/table_frame/attackby(', 'I,user,params',NS(type='/obj/item/weapon/wrench'),None,None)
            self.assertEqual(f.outputs,{'/obj/item/stack/material/wood':2})
            self.assertLess(sum(f.outputs.values())+top,cost)
            # Alternatively, resurfacing the actual frame spends one fresh log.
            f.outputs.clear();spent=[]
            stock=NS(type='/obj/item/stack/material/wood',amount=1,use=spent.append)
            f.model.deleted=False
            f.call(FRAME,'/obj/structure/table_frame/wood/attackby(', 'I,user,params',stock,None,None)
            self.assertEqual(spent,[1]);self.assertEqual(f.outputs,{'/obj/structure/table/wood':1})
            wood_table=defaults(TABLE,'/obj/structure/table\n')
            wood_table.update(defaults(TABLE,'/obj/structure/table/wood\n'))
            f.model=NS(**wood_table,loc='floor',deleted=False);f.outputs.clear();f.destroy(3)
            self.assertEqual(f.outputs,{'/obj/item/stack/material/wood':3})
            self.assertLess(sum(f.outputs.values())+top,cost+sum(spent))


if __name__=='__main__':unittest.main()
