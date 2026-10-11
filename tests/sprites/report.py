"""Source-linked review queue for unresolved compiled initial sprites."""
import argparse,csv,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DYNAMIC={
 '/obj/item/clothing/shoes/fur': 'Constructor chooses fur1..fur4',
 '/obj/item/weapon/reagent_containers/food/snacks/octopus/dried': 'Constructor selects octopus_rings',
 '/obj/item/weapon/reagent_containers/food/drinks/clay/smallclaypot': 'Constructor chooses smallclaypot1..2',
 '/obj/item/weapon/reagent_containers/food/drinks/plastic/gallonjug': 'Label overlays supply appearance; missing base needs separate visual review',
 '/obj/item/weapon/reagent_containers/food/drinks/plastic/carton': 'Label overlays supply appearance; missing base needs separate visual review',
 '/obj/item/weapon/reagent_containers/food/drinks/bottle/small/custom': 'Custom fluid/label overlay construction; separate visual review',
 '/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/custom': 'Custom fluid/label overlay construction; separate visual review',
}

def main():
 parser=argparse.ArgumentParser();parser.add_argument('inventory',type=Path);parser.add_argument('output',type=Path);args=parser.parse_args()
 rows=json.loads(args.inventory.read_text());missing={r['type']:r for r in rows if not r['valid']};definitions={};references={t:[] for t in missing}
 for folder,pattern in [('code','*.dm'),('config','*.txt'),('maps','*.dmm')]:
  for f in sorted((ROOT/folder).rglob(pattern)):
   for n,line in enumerate(f.read_text(errors='replace').splitlines(),1):
    tokens=set(re.findall(r'/obj/[\w/]+',line));location=f'{f.relative_to(ROOT).as_posix()}:{n}'
    for t in tokens & missing.keys():
     if folder=='code' and line.strip()==t:
      definitions[t]=location
     elif len(references[t])<3:
      references[t].append(location)
 args.output.parent.mkdir(parents=True,exist_ok=True)
 with args.output.open('w',newline='',encoding='utf-8') as out:
  writer=csv.writer(out,delimiter='\t');writer.writerow(['type','initial_icon','initial_state','initial_invisibility','declaration','reference_examples','disposition'])
  for t,r in sorted(missing.items()):
   writer.writerow([t,r['icon'],r['state'],r['invisibility'],definitions.get(t,''),'; '.join(references[t]),DYNAMIC.get(t,'Unreviewed initial default; obtainability and dynamic rendering not established')])
 print(f'Review queue: {len(missing)} initial-default candidates, not confirmed missing sprites')
if __name__=='__main__':main()
