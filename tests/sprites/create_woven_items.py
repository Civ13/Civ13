#!/usr/bin/env python3
"""Packs the carried (item) state of each woven format into one 32x32 sheet,
icons/obj/woven_items.dmi, by cropping the centre 32x32 of Fable's "item"
state in icons/obj/woven_<format>.dmi (drawn by make_weaving.py in the
project files). Run from the repository root."""
from PIL import Image
from PIL.PngImagePlugin import PngInfo

FORMATS = ['rug_small', 'rug_runner', 'rug_large', 'tapestry', 'tapestry_wide']
sheet = Image.new('RGBA', (32 * len(FORMATS), 32), (0, 0, 0, 0))
for i, f in enumerate(FORMATS):
    im = Image.open(f'icons/obj/woven_{f}.dmi').convert('RGBA')
    w, h = im.size[0] // 3, im.size[1]
    item = im.crop((2 * w, 0, 3 * w, h))
    x0, y0 = (w - 32) // 2, (h - 32) // 2
    sheet.paste(item.crop((x0, y0, x0 + 32, y0 + 32)), (i * 32, 0))
desc = "# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n" + "".join(f'state = "{f}"\n\tdirs = 1\n\tframes = 1\n' for f in FORMATS) + "# END DMI\n"
meta = PngInfo()
meta.add_text("Description", desc, zip=True)
sheet.save('icons/obj/woven_items.dmi', format='PNG', pnginfo=meta)
