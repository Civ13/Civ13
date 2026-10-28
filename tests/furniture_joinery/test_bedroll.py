"""Portable bedding identity and actual generic structure-refund regression.

Source bodies run through bounded offline constructor/chat/wait adapters.
The compiled crafting fixture separately executes the actual DM procedures.
"""
import importlib.util
import json
from pathlib import Path
import re
import struct
import subprocess
import sys
import tempfile
from types import SimpleNamespace as NS
import unittest
import zlib

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests/primitive_woodworking'))
from source_adapter import block,expr
SOURCE=(ROOT/'code/game/objects/items/weapons/nomadstuff.dm').read_text()
BED=(ROOT/'code/game/objects/structures/stool_bed_chair_nest/bed.dm').read_text()
STRUCTURE=(ROOT/'code/game/objects/structures.dm').read_text()
ITEM='/obj/item/weapon/bedroll'
UNROLLED='/obj/structure/bed/bedroll'
FIELDS=('loc','used','running','unrolled_type','rolled_type','not_disassemblable','contents')


def defaults(signature):
    text=SOURCE if signature.startswith((ITEM,UNROLLED)) else BED
    # Typepaths also occur as default values before their declarations.
    start=re.search('^'+re.escape(signature)+r'\n',text,re.M)
    if not start:raise AssertionError('Missing type declaration: '+signature)
    text=text[start.start():]
    result={}
    for line in block(text,signature+'\n').splitlines()[1:]:
        m=re.fullmatch(r'\t(?:var/)?(\w+) = (.+)',line.split('//')[0].rstrip())
        if m and m[1] in FIELDS+('bedding_material',):
            value=m[2]
            result[m[1]]=True if value=='TRUE' else False if value=='FALSE' else json.loads(value) if value.startswith('"') else value
    return result


def procedure(signature,env,hammer=False):
    body=block(SOURCE,signature).splitlines()[1:]
    if hammer:
        text=block(STRUCTURE,'/obj/structure/attackby(')
        body=text[text.index('\telse if (istype(O, /obj/item/weapon/hammer)'):].splitlines()
        body[0]=body[0].replace('else if','if',1)
    output=['def action(self,user,O=None):']
    for raw in body:
        line=raw.split('//')[0].rstrip()
        if not line.strip():continue
        depth=len(line)-len(line.lstrip('\t'));line=line.strip()
        if line.startswith('var/'):
            left,right=line.split(' = ',1);line=left.rsplit('/',1)[-1]+' = '+right
        m=re.fullmatch(r'(?:(\w+) = )?new\s+([\w/]+)\((.*)\)',line)
        if m:line=(m[1]+' = ' if m[1] else '')+'construct('+expr(m[2],FIELDS)+','+expr(m[3],FIELDS)+')'
        elif line.startswith('if ('):line='if '+expr(line[4:-1],FIELDS)+':'
        elif line.startswith('for (var/'):
            match=re.fullmatch(r'for \(var/[\w/]+/(\w+) in (\w+)\)',line)
            if not match:raise AssertionError('Unreviewed loop: '+line)
            line='for '+match[1]+' in '+expr(match[2],FIELDS)+':'
        elif line.startswith('return '):line='return '+expr(line[7:],FIELDS)
        else:line=expr(line,FIELDS)
        output.append('    '*depth+line)
    namespace=dict(env);exec(compile('\n'.join(output)+'\n','<production bedroll>','exec'),namespace)
    return namespace['action']


class Bedding:
    def __init__(self):
        self.objects=[]
        self.env=dict(construct=self.new,qdel=lambda obj:setattr(obj,'deleted',True),
                      to_chat=lambda *a:None,playsound=lambda *a:None,SPAN_NOTICE=lambda text:text,
                      do_after=lambda *a:True,get_turf=lambda obj:'floor',istype=lambda obj,kind:obj.type==kind)

    def new(self,kind,loc='floor'):
        if kind.startswith(ITEM):values=defaults(ITEM)
        elif kind.startswith(UNROLLED):
            values=defaults('/obj/structure/bed');values.update(defaults(UNROLLED))
        else:values={}
        if kind.endswith('/cloth'):values.update(defaults(ITEM+'/cloth' if kind.startswith(ITEM) else UNROLLED+'/cloth'))
        obj=NS(**values,type=kind,loc=loc,contents=[],deleted=False)
        self.objects.append(obj);return obj


class BedrollContracts(unittest.TestCase):
    def test_compact_inventory_retains_review_metadata_and_includes_bedding(self):
        spec=importlib.util.spec_from_file_location('bedroll_audit',ROOT/'scripts/audit-crafting-recipes.py')
        audit=importlib.util.module_from_spec(spec);spec.loader.exec_module(audit)
        current=audit.inventory()
        self.assertEqual(sum('/obj/item/weapon/bedroll' in row['output'] for row in current['furniture']),12)
        checked=json.loads((ROOT/'docs/crafting-recipe-audit-index.json').read_text())
        for key in ('catalogs','categories'):self.assertEqual(checked[key],current[key])
        self.assertEqual(checked['current_furniture_candidates'],len(current['furniture']))
        with tempfile.TemporaryDirectory() as directory:
            output=Path(directory)/'summary.json'
            output.write_text(json.dumps(dict(reviewed=['keep'],furniture=['omit raw rows'])))
            subprocess.run([sys.executable,str(ROOT/'scripts/audit-crafting-recipes.py'),'--summary','--output',str(output)],check=True,capture_output=True)
            summary=json.loads(output.read_text())
            self.assertEqual(summary['reviewed'],['keep']);self.assertNotIn('furniture',summary)
            self.assertEqual(summary['current_furniture_candidates'],len(current['furniture']))

    def test_legacy_routes_are_preserved_and_cloth_recipe_pays_for_weaving(self):
        rows=[dict(file=p.relative_to(ROOT).as_posix(),row=line) for p in (ROOT/'config/crafting').glob('material_recipes_*.txt') for line in p.read_text().splitlines() if line.startswith('RECIPE: ')]
        for old in json.loads((Path(__file__).parent/'legacy-bedrolls.json').read_text()):self.assertIn(old,rows)
        cloth=[r['row'].split('RECIPE: ',1)[1].split(',') for r in rows if ',cloth bedroll,' in r['row']]
        self.assertEqual(cloth,[['/material/cloth/','cloth bedroll',ITEM+'/cloth','4','100','0','1','furniture','0','0','0','8','null']])
        nodes=(ROOT/'code/modules/research_tree/research_node.dm').read_text()
        self.assertIn('"'+ITEM+'/cloth" = "weaving"',nodes)
        self.assertIn('"'+ITEM+'" = "weaving"',nodes)

    def test_production_unroll_and_fold_preserve_each_type_without_duplication(self):
        for suffix in ('','/cloth'):
            f=Bedding();user=NS(loc='floor');rolled=f.new(ITEM+suffix)
            for _ in range(3):
                procedure(ITEM+'/attack_self(',f.env)(rolled,user)
                bed=f.objects[-1];self.assertTrue(rolled.deleted);self.assertEqual(bed.type,UNROLLED+suffix)
                rolled=procedure(UNROLLED+'/proc/fold_up(',f.env)(bed,user)
                self.assertTrue(bed.deleted);self.assertEqual(rolled.type,ITEM+suffix)
                self.assertEqual(sum(not obj.deleted for obj in f.objects),1)
                self.assertEqual(defaults(bed.type)['bedding_material'] if suffix else defaults(UNROLLED)['bedding_material'],'cloth' if suffix else 'leather')

    def test_used_bedding_cannot_be_folded(self):
        for suffix in ('','/cloth'):
            f=Bedding();bed=f.new(UNROLLED+suffix);bed.used=True
            self.assertIsNone(procedure(UNROLLED+'/proc/fold_up(',f.env)(bed,None))
            self.assertFalse(bed.deleted);self.assertEqual(f.objects,[bed])

    def test_actual_generic_hammer_branch_no_longer_manufactures_wood(self):
        for suffix in ('','/cloth'):
            f=Bedding();bed=f.new(UNROLLED+suffix)
            procedure('',f.env,hammer=True)(bed,None,NS(type='/obj/item/weapon/hammer'))
            self.assertFalse(bed.deleted);self.assertEqual(f.objects,[bed])
            # Old inherited FALSE admits the real branch: one log from textile.
            bed.not_disassemblable=False
            procedure('',f.env,hammer=True)(bed,None,NS(type='/obj/item/weapon/hammer'))
            self.assertTrue(bed.deleted);self.assertEqual(f.objects[-1].type,'/obj/item/stack/material/wood')

    def test_atlas_and_help_name_the_paid_cloth_alternative(self):
        data=json.loads((ROOT/'UI/crafting-atlas.json').read_text())
        row=next(r for r in data['recipes'] if r['name']=='cloth bedroll')
        self.assertEqual(row['inputs'],[dict(id='/material/cloth',name='cloth',quantity='4')])
        self.assertEqual(row['outputs'],[dict(id=ITEM+'/cloth',name='cloth bedroll',quantity='1')])
        self.assertEqual(row['unlock_eras'],[0]);self.assertIn('weaving',row['conditions'])
        spec=importlib.util.spec_from_file_location('bedroll_help',ROOT/'scripts/player_help_bridge.py')
        helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
        context=next(x['text'] for x in helper.recipe_context(ROOT/'UI/crafting-atlas.json') if x['topic']=='cloth bedroll')
        self.assertIn('4 x cloth',context);self.assertIn('1 x cloth bedroll',context)

    def test_reused_real_bedroll_states_exist(self):
        blob=(ROOT/'icons/obj/items.dmi').read_bytes();position=8;metadata=''
        while position<len(blob):
            length=struct.unpack('>I',blob[position:position+4])[0];kind=blob[position+4:position+8];data=blob[position+8:position+8+length];position+=length+12
            if kind==b'zTXt':metadata+=zlib.decompress(data.split(b'\0',1)[1][1:]).decode()
            elif kind==b'tEXt':metadata+=data.decode(errors='replace')
        for state in ('bedroll_r','bedroll_o','bedroll_w'):self.assertIn('state = "'+state+'"',metadata)


class HammockContracts(unittest.TestCase):
    def test_paid_route_research_and_catalog_are_consistent(self):
        path='/obj/structure/bed/hammock'
        lines=(ROOT/'config/crafting/material_recipes_global.txt').read_text().splitlines()
        rows=[x.split('RECIPE: ',1)[1].split(',') for x in lines if x.startswith('RECIPE: ') and ','+path+',' in x]
        self.assertEqual(rows,[['/material/rope/','rope hammock',path,'6','180','1','1','furniture','0','0','0','8','rope']])
        self.assertIn('"'+path+'" = "weaving"',(ROOT/'code/modules/research_tree/research_node.dm').read_text())
        data=json.loads((ROOT/'UI/crafting-atlas.json').read_text())
        row=next(r for r in data['recipes'] if r['name']=='rope hammock')
        self.assertEqual(row['inputs'],[dict(id='/material/rope',name='rope',quantity='6')])
        self.assertEqual(row['outputs'],[dict(id=path,name='hammock',quantity='1')])
        self.assertEqual(row['unlock_eras'],[0]);self.assertIn('weaving',row['conditions'])

    def test_hammock_refuses_real_generic_wood_refund_with_old_default_control(self):
        f=Bedding()
        values=defaults('/obj/structure/bed') | defaults('/obj/structure/bed/hammock')
        bed=NS(**values,type='/obj/structure/bed/hammock',loc='floor',contents=[],deleted=False)
        f.objects.append(bed)
        hammer=NS(type='/obj/item/weapon/hammer')
        procedure('',f.env,hammer=True)(bed,None,hammer)
        self.assertFalse(bed.deleted);self.assertEqual(f.objects,[bed])
        bed.not_disassemblable=False
        procedure('',f.env,hammer=True)(bed,None,hammer)
        self.assertTrue(bed.deleted);self.assertEqual(f.objects[-1].type,'/obj/item/stack/material/wood')
        # Ordinary wooden beds retain their existing dispatch policy.
        self.assertFalse(defaults('/obj/structure/bed')['not_disassemblable'])


if __name__=='__main__':unittest.main()
