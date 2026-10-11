"""Hand-authored pixel sprite and a preview of those exact pixels. No AI artwork."""
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

root = Path(__file__).resolve().parents[2]
sprite = Image.new("RGBA", (32, 32))
d = ImageDraw.Draw(sprite)
d.rectangle((4, 9, 27, 12), fill="#747d86")
d.rectangle((4, 13, 27, 15), fill="#343e49")
for x in range(5, 27, 4):
    d.rectangle((x, 8, x + 1, 10), fill="#c3cbd1")
d.rectangle((6, 16, 9, 23), fill="#46505c")
d.rectangle((9, 21, 23, 24), fill="#747d86")
d.rectangle((20, 17, 23, 21), fill="#46505c")
d.rectangle((8, 23, 21, 25), fill="#29323d")
d.point((8, 18), fill="#c3cbd1")
d.point((21, 19), fill="#c3cbd1")
metadata = PngImagePlugin.PngInfo()
metadata.add_text("Description", '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\nstate = "dovetail_rail"\n\tdirs = 1\n\tframes = 1\n# END DMI\n', zip=True)
sprite.save(root / "icons/obj/guns/mounts.dmi", format="PNG", pnginfo=metadata)
preview = Image.new("RGB", (320, 220), "#20242b")
large = sprite.resize((160, 160), Image.Resampling.NEAREST)
preview.paste(large, (80, 20), large)
ImageDraw.Draw(preview).text((20, 190), "Hand-authored dovetail-to-Picatinny rail", fill="white")
output = root / "docs/images/gun-rail.png"
output.parent.mkdir(parents=True, exist_ok=True)
preview.save(output)
print(output)
