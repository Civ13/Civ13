"""Conventional pixel sprites for confirmed crafted item gaps (AGPL-3.0).
White pelt adapts Civ13 icons/obj/clothing/hats.dmi state wolfpelt.
Chitin shields are original hand-placed shapes, no third-party/AI art.
"""
from pathlib import Path
from PIL import Image,ImageDraw,PngImagePlugin
from validate import dmi
ROOT=Path(__file__).resolve().parents[2]
source=ROOT/'icons/obj/clothing/hats.dmi';w,h,states=dmi(source)
sheet=Image.open(source).convert('RGBA');n=states['wolfpelt'][0];cols=sheet.width//w
pelt=sheet.crop((n%cols*w,n//cols*h,n%cols*w+w,n//cols*h+h))
for y in range(h):
 for x in range(w):
  r,g,b,a=pelt.getpixel((x,y))
  if a:
   v=round((r+g+b)/3);v=min(247,round(v*0.72+76))
   pelt.putpixel((x,y),(v,max(0,v-3),max(0,v-7),a))
frames=[pelt]
for large in [False,True]:
 im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im)
 bounds=(7,5,24,27) if large else (8,10,23,25)
 d.ellipse(bounds,fill='#605841',outline='#302f27')
 d.ellipse((bounds[0]+2,bounds[1]+2,bounds[2]-2,bounds[3]-2),fill='#8c8560',outline='#b5ae7b')
 # Overlapping dark seams distinguish shell plates from a wooden shield.
 for y in range(bounds[1]+6,bounds[3]-1,5):
  d.line([(bounds[0]+3,y-1),(16,y+1),(bounds[2]-3,y-1)],fill='#4b4a35')
 d.line([(16,bounds[1]+3),(16,bounds[3]-3)],fill='#625d42')
 d.ellipse((13,14,18,19),fill='#a39b70',outline='#39392c')
 frames.append(im)
out=Image.new('RGBA',(96,32))
for n,im in enumerate(frames):out.paste(im,(32*n,0))
meta=PngImagePlugin.PngInfo();meta.add_text('Description','# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'+''.join(f'state = "{s}"\n\tdirs = 1\n\tframes = 1\n' for s in ['whitewolfpelt','chitin_buckler','chitin_shield'])+'# END DMI\n',zip=True)
out.save(ROOT/'icons/obj/crafted_item_repairs.dmi',format='PNG',pnginfo=meta)
