"""Execute the production tool handler with synthetic type/message/GC boundaries.

These tests do not compile DM, render clients or establish native deletion behavior.
"""
import json
from pathlib import Path
import re
from types import SimpleNamespace
import unittest
from test_sources import proc

ROOT = Path(__file__).resolve().parents[2]
FARM = (ROOT/'code/game/objects/farming.dm').read_text()
TOOLS = (ROOT/'code/modules/1713/tools.dm').read_text()
SIGNATURE = '/obj/structure/farming/plant/tree/attackby('
SHOVELS = sorted(set(re.findall(r'^(/obj/item/weapon/material/shovel(?:/\w+)*)\s*$', TOOLS, re.M)))
CUTTERS = ['/obj/item/weapon/material/hatchet', '/obj/item/weapon/material/hatchet/steel',
           '/obj/item/weapon/attachment/bayonet', '/obj/item/weapon/material/kitchen/utensil/knife',
           '/obj/item/weapon/material/scythe']
REJECTED = CUTTERS + ['/obj/item/weapon/foldable_shovel', '/obj/item/weapon/foldable_shovel/trench/etool',
                     '/obj/item/weapon/material/pickaxe', '/obj/item/weapon/material/kitchen/utensil/spoon',
                     '/obj/item/weapon/material/part/shovel', '/obj/item/weapon/clay/mold/shovel',
                     '/obj/item/weapon/material/shovel_impostor']


def translated_handler(source=FARM):
    body = proc(source, SIGNATURE).splitlines()[1:]
    lines = ['def attack(W, user, src):']
    for raw in body:
        text = raw.strip()
        if not text or text.startswith('//'): continue
        depth = len(raw) - len(raw.lstrip('\t'))
        if text.startswith('if ('):
            text = 'if ' + text[4:-1] + ':'
        text = re.sub(r'(?<![\w])/(?:\w+/)*\w+', lambda m: repr(m[0]), text)
        text = text.replace('||', ' or ').replace('&&', ' and ')
        if not (text.startswith(('if ', 'to_chat(', 'qdel(')) or text == 'return'):
            raise AssertionError('Unsupported handler statement: ' + text)
        lines.append('    '*depth + text)
    messages = []
    env = {'istype': lambda W, path: W is not None and (W.kind == path or W.kind.startswith(path+'/')),
           'to_chat': lambda user,text: messages.append(text), 'SPAN_WARNING': lambda text:text,
           'qdel': lambda plant: setattr(plant,'retired',True)}
    exec(compile('\n'.join(lines),'<production-tree-attackby>','exec'),env)
    return env['attack'], messages


class Uprooting(unittest.TestCase):
    def test_all_declared_open_shovels_and_stages(self):
        self.assertGreaterEqual(len(SHOVELS),10)
        for tool in SHOVELS:
            for stage in (1,6,7,10,11):
                with self.subTest(tool=tool,stage=stage):
                    attack,messages = translated_handler()
                    tree=SimpleNamespace(retired=False,stage=stage)
                    attack(SimpleNamespace(kind=tool),object(),tree)
                    self.assertTrue(tree.retired)
                    self.assertEqual(len(messages),1)
                    self.assertIn('You uproot',messages[0])

    def test_cutters_folded_shovels_and_nonshovels_rejected(self):
        for tool in REJECTED:
            for stage in (1,11):
                with self.subTest(tool=tool,stage=stage):
                    attack,messages=translated_handler();tree=SimpleNamespace(retired=False,stage=stage)
                    attack(SimpleNamespace(kind=tool),object(),tree)
                    self.assertFalse(tree.retired)
                    if tool in CUTTERS or tool.startswith('/obj/item/weapon/foldable_shovel'):
                        self.assertEqual(len(messages),1)
                        self.assertIn('unfolded shovel',messages[0])

    def test_no_parent_harvest_refund_or_new_wait(self):
        body=proc(FARM,SIGNATURE)
        for forbidden in ('..(', 'spawn_seeds(', 'spawn_produce(', 'new ', 'sleep(', 'spawn(', 'del(src)'):
            if forbidden == 'del(src)':
                self.assertNotRegex(body,r'(?<!q)\bdel\(src\)')
            else:self.assertNotIn(forbidden,body)
        self.assertEqual(body.count('qdel(src)'),1)
        self.assertIn('qdel(src)\n\t\treturn',body)
        ordinary=proc(FARM,'/obj/structure/farming/plant/attackby(')
        self.assertIn('/obj/item/weapon/material/hatchet',ordinary)
        self.assertIn('spawn_seeds()',ordinary)
        self.assertIn('spawn_produce()',ordinary)

    def test_declared_open_and_folded_hierarchy_is_distinct(self):
        for path in ('/obj/item/weapon/material/shovel/spade/wood',
                     '/obj/item/weapon/material/shovel/trench/foldable/etool/german',
                     '/obj/item/weapon/material/shovel/bone'):
            self.assertIn(path,SHOVELS)
        self.assertIn('/obj/item/weapon/foldable_shovel/secondary_attack_self',TOOLS)
        self.assertIn('var/path = /obj/item/weapon/material/shovel/spade/foldable',TOOLS)
        self.assertFalse(any(x.startswith('/obj/item/weapon/foldable_shovel') for x in SHOVELS))

    def test_tool_gate_mutants_change_behavior(self):
        old='if (istype(W, /obj/item/weapon/material/shovel))'
        self.assertEqual(FARM.count(old),1)
        for replacement,tool,wanted in [
            ('if (istype(W, /obj/item/weapon/material/hatchet))',CUTTERS[0],False),
            ('if (istype(W, /obj/item/weapon/foldable_shovel))','/obj/item/weapon/foldable_shovel',False),
            ('if (istype(W, /obj/item/weapon/material/shovel/spade))','/obj/item/weapon/material/shovel',True)]:
            mutant=FARM.replace(old,replacement,1);attack,_=translated_handler(mutant)
            tree=SimpleNamespace(retired=False);attack(SimpleNamespace(kind=tool),None,tree)
            self.assertNotEqual(tree.retired,wanted)

    def test_guidance_and_catalog_do_not_claim_cutting_uproots(self):
        self.assertIn('Uproot it with a shovel for no logs or seeds.',FARM)
        for relative in ('scripts/atlas/resource-sources.json','UI/crafting-atlas.json'):
            value=json.loads((ROOT/relative).read_text())
            routes=value['mechanisms'] if 'mechanisms' in value else value['acquisition']['/obj/structure/wild/tree/live_tree']
            route=next(x for x in routes if x['name']=='Grow a timber tree')
            text=' '.join(route['steps'])
            self.assertIn('requires a shovel or spade',text)
            self.assertIn('knives and hatchets cannot uproot',text)
            self.assertNotIn('cutting a seedling only uproots',text)

    def test_native_probe_covers_tools_cleanup_and_no_refund(self):
        text=(ROOT/'tests/tree_planting/probe.dm').read_text()
        for marker in ('tree_uproot_fixture(H)', 'typesof(/obj/item/weapon/material/shovel)',
                       'list(1, 11)', 'shovel uprooting retires tree processing',
                       'nonshovel tool preserves seedling state', 'uprooting returns no wood or seeds'):
            self.assertIn(marker,text)

if __name__=='__main__':unittest.main()
