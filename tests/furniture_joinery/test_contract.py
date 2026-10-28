"""Checked-in recipe parity, source-derived admission, Atlas and Help contracts.

The bounded projection executes guard expressions with offline inventory adapters;
native waits/consumption are covered separately by tests/crafting/furniture_joinery.dm.
"""
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys
from types import SimpleNamespace as NS
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'tests/primitive_woodworking'))
from source_adapter import block, expr

TEXT = (ROOT/'code/game/objects/items/stacks/furniture_joinery.dm').read_text()
SPECS = json.loads((ROOT/'config/crafting/furniture_joinery.json').read_text())


def project_guard():
    body = block(TEXT, '/datum/furniture_joinery_action/proc/valid()')
    fields = ('spec', 'actor', 'stock', 'stock_loc', 'site', 'save_epoch', 'recipe', 'tools', 'component')
    lines = ['def valid(self):']
    for raw in body.splitlines()[1:]:
        line = raw.split('//')[0].rstrip()
        if not line.strip():
            continue
        depth = len(line)-len(line.lstrip('\t'))
        line = line.strip().replace('"[recipe.result_type]"', 'recipe.result_type')
        line = line.replace('stock:onfire', 'stock.onfire').replace('stock:splitting_in_progress', 'stock.splitting_in_progress')
        if line.startswith('var/'):
            left, right = line.split(' = ', 1)
            line = left.rsplit('/', 1)[-1]+' = '+expr(right, fields)
        elif line.startswith('if ('):
            line = 'if '+expr(line[4:-1], fields)+':'
        elif line.startswith('for (var/'):
            variable, iterable = line[9:-1].split(' in ', 1)
            line = 'for '+variable+' in '+expr(iterable, fields)+':'
        elif line.startswith('return '):
            line = 'return '+expr(line[7:], fields)
        else:
            raise AssertionError('Unreviewed DM syntax: '+line)
        lines.append('    '*depth+line)
    return '\n'.join(lines)


class Fixture:
    def __init__(self):
        self.site=[]
        self.actor=NS(deleted=False, woodwork_owner=None, civilization='f', site=self.site)
        self.actor.incapacitated=lambda:False
        self.actor.item_is_in_hands=lambda item:item is self.component
        self.spec=SPECS['joinery: hewn chair (wooden pegs)']
        self.recipe=NS(result_type=self.spec['result_type'], req_amount=4, one_per_turf=True)
        self.stock_loc=self.actor
        self.stock=NS(deleted=False, type=self.spec['stock_type'], loc=self.actor, woodwork_owner=None, onfire=False, splitting_in_progress=False, amount=4)
        self.stock.can_use=lambda n:self.stock.amount>=n
        self.stock.crafting_stack_accessible=lambda actor:self.stock.loc is actor
        self.material=NS(type='/material/wood')
        self.stock.get_material=lambda:self.material
        self.component=NS(deleted=False, type='/obj/item/stack/wooden_dowels', loc=self.actor, woodwork_owner=None, amount=1, equipped=True)
        self.component.can_use=lambda n:self.component.amount>=n
        self.tools={role:NS(deleted=False,equipped=True,loc=self.actor,health=None) for role in self.spec['tools']}
        self.save_epoch=object()
        self.researched=True
        env=dict(QDELETED=lambda x:x is None or x.deleted,
                 persistence_save_in_progress=False, persistence_active_operation=None, persistence_load_recovery_required=False,
                 persistence_admission_identity=self.save_epoch,
                 get_turf=lambda x:x.site, text2path=lambda x:x, locate=lambda x:x,
                 istype=lambda x,p:x.type==p, get_recipe_node_req=lambda x:'basic_furniture',
                 map=NS(is_node_done=lambda f,n:self.researched),
                 furniture_joinery_equipped=lambda a,i:i is not None and not i.deleted and i.loc is a and i.equipped and (i.health is None or i.health>0) if hasattr(i,'health') else i is not None and not i.deleted and i.loc is a and i.equipped,
                 furniture_joinery_tool=lambda i,r,m:i is not None and not i.deleted)
        exec(compile(project_guard(), '<production joinery guard>', 'exec'),env)
        self.valid=lambda:env['valid'](self)
        self.env=env


class Contracts(unittest.TestCase):
    def test_legacy_rows_preserved_without_git_history(self):
        for item in json.loads((Path(__file__).parent/'legacy-furniture.json').read_text()):
            self.assertIn(item['row'], (ROOT/item['file']).read_text().splitlines())

    def test_explicit_route_data_matches_catalog_and_no_hidden_bulk(self):
        rows=[r.split('RECIPE: ',1)[1].split(',') for r in (ROOT/'config/crafting/material_recipes_global.txt').read_text().splitlines() if r.startswith('RECIPE: ') and ',joinery: ' in r]
        self.assertEqual(set(SPECS),{r[1] for r in rows})
        self.assertEqual(len(rows),4)
        for row in rows:
            spec=SPECS[row[1]]
            self.assertEqual(spec['result_type'],row[2])
            self.assertEqual(spec['stock_cost'],int(row[3]))
            self.assertEqual(row[11],'8')
        stock=(ROOT/'code/game/objects/items/stacks/stack.dm').read_text()
        self.assertIn('quantity != 1 || !joinery.valid()', stock)
        self.assertLess(stock.index('if (joinery && !joinery.valid())'),stock.index('if (use(required, joinery ? null : H))'))
        self.assertLess(stock.index('if (use(required, joinery ? null : H))'),stock.index('joinery.consume_component()'))
        self.assertIn('component.use(spec["component_cost"])',TEXT)
        self.assertIn('blade.health -= 0.25',TEXT)

    def test_guard_rejects_changed_inputs_tools_research_and_saves(self):
        f=Fixture();self.assertTrue(f.valid())
        changes={
            'insufficient logs':lambda f:setattr(f.stock,'amount',3),
            'insufficient pegs':lambda f:setattr(f.component,'amount',0),
            'wrong component':lambda f:setattr(f.component,'type','/obj/item/stack/rods'),
            'nested pegs':lambda f:setattr(f.component,'loc',object()),
            'unequipped tool':lambda f:setattr(f.tools['chisel'],'equipped',False),
            'broken tool':lambda f:setattr(f.tools['hammer'],'health',0),
            'deleted tool':lambda f:setattr(f.tools['hammer'],'deleted',True),
            'foreign logs':lambda f:setattr(f.stock,'loc',object()),
            'crude planks':lambda f:setattr(f.stock,'type','/obj/item/stack/material/crude_plank'),
            'wrong material':lambda f:setattr(f.material,'type','/material/wood/hard'),
            'burning logs':lambda f:setattr(f.stock,'onfire',True),
            'busy stock':lambda f:setattr(f.stock,'woodwork_owner',object()),
            'lost research':lambda f:setattr(f,'researched',False),
            'occupied tile':lambda f:f.site.append(f.recipe.result_type),
            'save crossed':lambda f:f.env.update(persistence_admission_identity=object()),
            'saving':lambda f:f.env.update(persistence_save_in_progress=True),
        }
        for label,change in changes.items():
            with self.subTest(label=label):
                f=Fixture();change(f);self.assertFalse(f.valid())

    def test_atlas_secondary_ingredients_help_and_freshness(self):
        subprocess.run([sys.executable,str(ROOT/'scripts/build-crafting-atlas.py'),'--catalog-only','--check-game-catalog',str(ROOT/'UI/crafting-atlas.json')],cwd=ROOT,check=True,capture_output=True)
        data=json.loads((ROOT/'UI/crafting-atlas.json').read_text())
        selected=[r for r in data['recipes'] if r['name'] in SPECS]
        self.assertEqual(len(selected),4)
        spec=importlib.util.spec_from_file_location('help_joinery',ROOT/'scripts/player_help_bridge.py')
        helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
        contexts=helper.recipe_context(ROOT/'UI/crafting-atlas.json')
        for row in selected:
            self.assertEqual(row['unlock_eras'],[0])
            self.assertIn('Tools reused',row['conditions'])
            if SPECS[row['name']]['component_cost']:
                self.assertIn({'id':'/obj/item/stack/wooden_dowels','name':'wooden dowel set','quantity':str(SPECS[row['name']]['component_cost'])},row['inputs'])
            context=next(c['text'] for c in contexts if c['topic']==row['name'])
            self.assertIn('Equipped',context)
            self.assertNotIn('unknown here',context)


if __name__=='__main__':
    unittest.main()
