"""Current-source freshness and new-recipe negative control, no game startup."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class AtlasTests(unittest.TestCase):
    def test_recipe_addition_and_stale_catalog(self):
        source=ROOT/'config/crafting/material_recipes_abashiri.txt'
        original=source.read_bytes()
        with tempfile.TemporaryDirectory() as folder:
            output=Path(folder)/'catalog.json'
            unused_output=Path(folder)/'unused-website'
            command=[sys.executable,str(ROOT/'scripts/build-crafting-atlas.py'),'--catalog-only','--output',str(unused_output)]
            subprocess.run(command+['--game-catalog',str(output)],check=True,capture_output=True)
            self.assertFalse(unused_output.exists(), 'Catalog-only builds must not create website output directories')
            before=json.loads(output.read_text())
            bench=next(r for r in before['recipes'] if r['name']=='Workbench Pickaxe')
            self.assertEqual({x['id'] for x in bench['inputs']},{'/obj/item/weapon/material/part/pickaxe','/obj/item/weapon/material/handle'})
            self.assertEqual(bench['outputs'][0]['id'],'/obj/item/weapon/material/pickaxe')
            self.assertTrue(before['acquisition'])
            for resource_id,routes in before['acquisition'].items():
                self.assertIn(resource_id,before['resources'])
                self.assertTrue(all(route.get('name') and route.get('file') and route.get('audit_commit') for route in routes))
            self.assertFalse(any(key.startswith('material:') for key in before['acquisition']))
            cut=next(route for route in before['acquisition']['/obj/item/stack/grass_cuttings'] if route['name']=='Cut grass fibres')
            self.assertIn('flint',cut['tools'])
            twine=next(route for route in before['acquisition']['/obj/item/stack/crude_twine'] if route['name']=='Twist crude twine')
            self.assertIn('/obj/item/stack/grass_cuttings',twine['inputs'])
            self.assertTrue(twine['steps'])
            sifter=next(route for route in before['acquisition']['/obj/item/stack/ore/iron'] if route['name']=='Powered soil sifter')
            self.assertIn('150',sifter['conditions'])
            self.assertIn('/obj/item/stack/ore/coal',sifter['outputs'])
            crab=next(route for route in before['acquisition']['/mob/living/simple_animal/crab/small/dead'] if route['name']=='Shallow saltwater cage fishing')
            self.assertNotIn('/obj/item/weapon/reagent_containers/food/snacks/rawcrab',crab['outputs'])

            direct=next(r for r in before['recipes'] if r['name']=='Flintlock Pistol [iron]')
            self.assertEqual([(x['id'],x['quantity']) for x in direct['inputs']],[('/material/iron','20')])
            finish=next(r for r in before['recipes'] if r['name']=='Finish Flintlock pistol assembly')
            self.assertEqual({x['id'] for x in finish['inputs']},{'/obj/item/blackpowder_part/stock/pistol#barrel_attached','/obj/item/blackpowder_part/mechanism#flint_loaded'})
            self.assertEqual(finish['outputs'][0]['id'],direct['outputs'][0]['id'])
            attached=next(r for r in before['recipes'] if r['name']=='Attach pistol barrel')
            self.assertEqual({x['id'] for x in attached['inputs']},{'/obj/item/blackpowder_part/stock/pistol','/obj/item/blackpowder_part/barrel/pistol'})
            load=next(r for r in before['recipes'] if r['name']=='Load sharpened flint into mechanism')
            self.assertIn('/obj/item/weapon/flint/sharpened',{x['id'] for x in load['inputs']})
            self.assertEqual(before['resources']['/obj/item/blackpowder_part/stock/pistol#barrel_attached']['state'],'wood_frame_barrel_pistol')
            self.assertEqual(before['resources']['/material/wood/soft']['type'],'/obj/item/stack/material/woodplank')
            self.assertTrue(any(r['name']=='pistol butt' and r['inputs'][0]['id']=='/material/wood/soft' and r['inputs'][0]['quantity']=='1' for r in before['recipes']))
            self.assertTrue(all(len(r['inputs'])==1 for r in before['recipes'] if r['kind']=='Anvil'))
            try:
                source.write_bytes(original+b'\nRECIPE: /obj/item/stack/material/wood,Atlas test sentinel,/obj/item/weapon/paper,2,10,0,0,test,0,0,0,9,wood\n')
                stale=subprocess.run(command+['--check-game-catalog',str(output)],capture_output=True,text=True)
                self.assertNotEqual(stale.returncode,0)
                self.assertIn('Stale game atlas',stale.stderr)
                subprocess.run(command+['--game-catalog',str(output)],check=True,capture_output=True)
                after=json.loads(output.read_text())
                self.assertEqual(len(after['recipes']),len(before['recipes'])+1)
                recipe=next(r for r in after['recipes'] if r['name']=='Atlas test sentinel')
                self.assertEqual(recipe['inputs'][0]['quantity'],'2')
                self.assertEqual(recipe['outputs'][0]['id'],'/obj/item/weapon/paper')
                self.assertIn('/obj/item/weapon/paper',after['resources'])
            finally:
                source.write_bytes(original)

    def test_procedural_source_change_requires_review(self):
        source=ROOT/'code/modules/1713/gunsmithing/blackpowder_assembly.dm'
        original=source.read_bytes()
        try:
            source.write_bytes(original.replace(b'has_flint = TRUE',b'has_flint = FALSE'))
            run=subprocess.run([sys.executable,str(ROOT/'scripts/build-crafting-atlas.py'),'--catalog-only'],capture_output=True,text=True)
            self.assertNotEqual(run.returncode,0)
            self.assertIn('Procedural source changed: review atlas',run.stderr)
        finally:
            source.write_bytes(original)

if __name__=='__main__':
    unittest.main()
