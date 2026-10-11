"""Render actual imported DMI cells, without invented or generated artwork."""
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[2]
source = Image.open(root / "icons/obj/guns/flintlocks.dmi")
description = source.info["Description"]
states = [line.split('"')[1] for line in description.splitlines() if line.strip().startswith('state = ')]
canvas = Image.new("RGB", (640, 540), "#20242b")
draw = ImageDraw.Draw(canvas)
draw.text((16, 12), "Original upstream flintlock parts sprites (nearest-neighbor 4x)", fill="white")
for index, state in enumerate(states):
    x, y = index % 4 * 32, index // 4 * 32
    cell = source.crop((x, y, x + 32, y + 32)).convert("RGBA").resize((128, 128), Image.Resampling.NEAREST)
    col, row = index % 4, index // 4
    px, py = col * 160 + 16, row * 164 + 34
    canvas.paste(cell, (px, py), cell)
    draw.text((px, py + 130), state.replace("wood_frame", "stock"), fill="white")
output = root / "docs/images/flintlock-parts.png"
output.parent.mkdir(parents=True, exist_ok=True)
canvas.save(output)
print(output)
