"""Paid wooden document storage, preserving the existing document-only handler."""
import importlib.util
import json
import re
from pathlib import Path
import sys
import struct
import zlib
from types import SimpleNamespace as NS
import unittest

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests/primitive_woodworking'))
from source_adapter import block,compile_body
KIND='/obj/structure/filingcabinet/chestdrawer/wood'
TITLE='joinery: wooden document drawers'
SOURCE=(ROOT/'code/game/objects/structures/filingcabinet.dm').read_text()


class DocumentDrawers(unittest.TestCase):
    def test_paid_recipe_and_legacy_routes(self):
        rows=(ROOT/'config/crafting/material_recipes_global.txt').read_text().splitlines()
        row=next(r.split('RECIPE: ',1)[1].split(',') for r in rows if ','+TITLE+',' in r)
        self.assertEqual(row,['/material/wood/soft/',TITLE,KIND,'6','180','1','1','joinery','0','0','0','8','null'])
        spec=json.loads((ROOT/'config/crafting/furniture_joinery.json').read_text())[TITLE]
        self.assertEqual((spec['stock_type'],spec['stock_cost'],spec['component_cost']),('/obj/item/stack/material/woodplank',6,1))
        self.assertEqual(spec['tools'],['chisel','hammer'])
        nodes=(ROOT/'code/modules/research_tree/research_node.dm').read_text()
        self.assertIn('"'+KIND+'" = "fine_furniture"',nodes)
        self.assertIn('"fine_furniture", "Fine Furniture", "Industrial", 130, 1, RESEARCH_MODE_ANALYSIS, list("basic_furniture"), 2',nodes)
        legacy=[r for r in json.loads((Path(__file__).parent/'legacy-furniture.json').read_text()) if '/obj/structure/filingcabinet' in r['row']]
        self.assertTrue(legacy)
        for r in legacy:self.assertIn(r['row'],(ROOT/r['file']).read_text().splitlines())

    def test_existing_joinery_guard_covers_new_plank_route(self):
        spec=importlib.util.spec_from_file_location('drawer_joinery_contract',Path(__file__).with_name('test_contract.py'))
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        f=module.Fixture();f.spec=module.SPECS[TITLE]
        f.recipe.result_type=KIND;f.recipe.req_amount=6
        f.stock.type=f.spec['stock_type'];f.material.type='/material/wood/soft';f.stock.amount=6
        self.assertTrue(f.valid())
        f.site.append(KIND);self.assertFalse(f.valid());f.site.clear()
        f.researched=False;self.assertFalse(f.valid());f.researched=True
        f.stock.amount=5;self.assertFalse(f.valid());f.stock.amount=6
        f.component.amount=0;self.assertFalse(f.valid())

    def test_actual_document_handler_keeps_purpose(self):
        body=block(SOURCE,'/obj/structure/filingcabinet/attackby(')
        # Chat text contains DM interpolation/ternary syntax; the inert chat
        # adapter removes those strings, preserving every admission/move branch.
        body=re.sub(r'(?m)^(\t+)to_chat\(.*$',r'\1fixture_chat()',body)
        cabinet=NS(icon_state='chestdrawer',anchored=True,loc='floor')
        actor=NS(drop_item=lambda:None)
        env=dict(istype=lambda obj,kind:obj.type==kind or obj.type.startswith(kind+'/'),
                 to_chat=lambda *a:None,playsound=lambda *a:None,sleep=lambda *a:None,
                 initial=lambda state:'chestdrawer',updateUsrDialog=lambda:None,fixture_chat=lambda:None)
        action,_=compile_body(body,'/obj/structure/filingcabinet/attackby(', 'self,P,user',env,('loc','icon_state','anchored'))
        for kind in ('paper','paper_bundle','folder','hammer','cloth'):
            item=NS(type='/obj/item/weapon/'+kind,loc=actor)
            action(cabinet,item,actor)
            self.assertIs(item.loc,cabinet if kind in ('paper','paper_bundle','folder') else actor)
        base=block(SOURCE,'/obj/structure/filingcabinet\n')
        for line in ('not_disassemblable = TRUE','flammable = TRUE'):self.assertIn(line,base)
        variant=block(SOURCE,KIND+'\n')
        self.assertIn('color = "#A07449"',variant);self.assertNotIn('/attackby',variant)
        blob=(ROOT/'icons/obj/bureaucracy.dmi').read_bytes();position=8;metadata=''
        while position<len(blob):
            length=struct.unpack('>I',blob[position:position+4])[0];kind=blob[position+4:position+8];data=blob[position+8:position+8+length];position+=length+12
            if kind==b'zTXt':metadata+=zlib.decompress(data.split(b'\0',1)[1][1:]).decode()
        for state in ('chestdrawer','chestdrawer-open'):self.assertIn('state = "'+state+'"',metadata)

    def test_atlas_help_materials_and_tools(self):
        row=next(r for r in json.loads((ROOT/'UI/crafting-atlas.json').read_text())['recipes'] if r['name']==TITLE)
        self.assertEqual(row['outputs'],[dict(id=KIND,name='wooden document drawers',quantity='1')])
        self.assertEqual(sorted(x['quantity'] for x in row['inputs']),['1','6'])
        self.assertEqual(row['unlock_eras'],[2]);self.assertIn('fine_furniture',row['conditions'])
        spec=importlib.util.spec_from_file_location('drawer_help',ROOT/'scripts/player_help_bridge.py')
        helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
        context=next(x['text'] for x in helper.recipe_context(ROOT/'UI/crafting-atlas.json') if x['topic']==TITLE)
        for expected in ('6 x','1 x wooden dowel set','chisel','hammer'):self.assertIn(expected,context)


if __name__=='__main__':unittest.main()
