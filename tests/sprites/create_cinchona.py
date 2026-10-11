"""Original hand-placed 32px cinchona sprig, no external or generated artwork.
Run with Pillow to reproduce icons/obj/food/cinchona.dmi; released under Civ13 AGPL-3.0.
"""
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
im = Image.new('RGBA', (32, 32))
d = ImageDraw.Draw(im)
# Brown bark, paired oval leaves, central veins and pale buds.
d.line([(10, 27), (14, 20), (17, 13), (20, 6)], fill='#573a27', width=2)
d.line([(11, 27), (15, 20), (18, 13), (21, 6)], fill='#a17443')
for points in [[(15,20),(7,19),(5,14),(10,14),(15,18)], [(16,18),(22,15),(27,16),(24,21),(18,22)], [(18,13),(12,11),(11,6),(15,7),(19,11)], [(20,9),(24,5),(28,6),(26,11),(21,12)]]:
 d.polygon(points, fill='#315934', outline='#203e29')
 d.line([points[0], points[2]], fill='#739150')
 d.point(points[1], fill='#91a965')
d.rectangle((19,3,20,4), fill='#ded0ad')
d.point((21,2), fill='#f2e6c7')
meta = PngImagePlugin.PngInfo()
meta.add_text('Description', '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\nstate = "cinchona"\n\tdirs = 1\n\tframes = 1\n# END DMI\n', zip=True)
im.save(ROOT / 'icons/obj/food/cinchona.dmi', format='PNG', pnginfo=meta)

