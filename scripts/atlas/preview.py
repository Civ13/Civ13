"""Contact sheet of genuine engine-exported frames; not gameplay evidence."""
import json
from pathlib import Path
import sys
from PIL import Image, ImageDraw

folder=Path(sys.argv[1])
output=Path(sys.argv[2])
data=json.loads((folder/'crafting-data.json').read_text())
types=['/material/wood/soft','/material/iron','/material/steel',
       '/obj/item/blackpowder_part/stock/pistol',
       '/obj/item/blackpowder_part/barrel/pistol',
       '/obj/item/blackpowder_part/mechanism',
       '/obj/item/weapon/flint/sharpened',
       '/obj/item/blackpowder_part/mechanism#flint_loaded',
       '/obj/item/blackpowder_part/stock/pistol#barrel_attached',
       '/obj/item/weapon/gun/projectile/flintlock/pistol',
       '/obj/item/blackpowder_part/stock/musket#barrel_attached',
       '/obj/item/weapon/gun/projectile/flintlock/musket']
labels={x['id']:x['name'] for r in data['recipes'] for x in r['inputs']+r['outputs']}
sheet=Image.new('RGB',(960,540),'#192638')
draw=ImageDraw.Draw(sheet)
for index,key in enumerate(types):
    resource=data['resources'][key]
    assert not resource['source_symbol'], 'Preview needs resolved real item/material sprite: '+key
    frame=Image.open(folder/resource['image']).convert('RGBA')
    assert frame.getbbox(), 'Transparent preview: '+key
    frame.thumbnail((96,96),Image.Resampling.NEAREST)
    # Enlargement preserves the source pixels exactly.
    frame=frame.resize((frame.width*3,frame.height*3),Image.Resampling.NEAREST)
    left=(index%4)*240;top=(index//4)*180
    sheet.paste(frame,(left+72,top+15),frame)
    draw.text((left+12,top+120),labels[key],fill='white')
    draw.text((left+12,top+140),resource['state'],fill='#a9bbd2')
    draw.text((left+12,top+155),'Actual DMI first frame',fill='#8fe0ab')
output.parent.mkdir(parents=True,exist_ok=True)
sheet.save(output)
print(output)
