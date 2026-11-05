"""Manifest-backed static source diagram, never a native or gameplay render."""
from pathlib import Path
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_map import ROOT, WIDTH, LENGTH, DECKS, PALETTE, manifest, deck_levels

OUTPUT = ROOT / "docs/images/extraction-safehouse-preview.png"
BG, PANEL, TEXT, MUTED, TEAL = "#101b24", "#192934", "#edf4f4", "#a6b9c3", "#57c9ba"
FONT_DIRS = [Path("/usr/share/fonts/truetype/dejavu"), Path("C:/Windows/Fonts")]


def font(size, bold=False):
    for directory in FONT_DIRS:
        for name in (("DejaVuSans-Bold.ttf", "segoeuib.ttf") if bold else ("DejaVuSans.ttf", "segoeui.ttf")):
            path = directory / name
            if path.is_file():
                return ImageFont.truetype(str(path), size)
    return ImageFont.load_default(size=size)


def main(output=OUTPUT):
    layout, tiles = manifest(), deck_levels()
    cell, top, left = 14, 150, 60
    deck_width = WIDTH * cell + 80
    im = Image.new("RGB", (left * 2 + deck_width * DECKS + 420, top + LENGTH * cell + 120), BG)
    d = ImageDraw.Draw(im)
    d.text((left, 30), "EXTRACTION / SAFEHOUSE MAP STUDY", font=font(20, True), fill=TEAL)
    d.text((left, 60), "Party safehouse - inactive draft (static source diagram, north up)", font=font(34, True), fill=TEXT)
    for z in range(DECKS):
        start = left + z * deck_width
        d.text((start, top - 40), f"{z + 1:02}  {layout['levels'][z]['id'].upper()}", font=font(22, True), fill=TEXT)
        for (x, y, dz), kind in tiles.items():
            if dz != z:
                continue
            a, b = start + x * cell, top + (LENGTH - 1 - y) * cell
            d.rectangle((a, b, a + cell - 1, b + cell - 1), fill=PALETTE[kind][1])
        for room in layout["rooms"]:
            if room["local_z"] != z:
                continue
            x0, y0, x1, y1 = room["bounds"]
            a, b = start + x0 * cell, top + (LENGTH - 1 - y1) * cell
            d.text((a + 3, b + 2), room["name"], font=font(11), fill=TEXT)
    legend_x = left + DECKS * deck_width + 20
    d.rounded_rectangle((legend_x - 15, top - 50, legend_x + 380, top + 640), radius=16, fill=PANEL)
    d.text((legend_x, top - 40), "Legend", font=font(22, True), fill=TEXT)
    y = top
    for kind, (atoms, color, _) in PALETTE.items():
        if kind.startswith("stair_") and kind not in ("stair_a_up", "stair_a_down"):
            continue
        d.rectangle((legend_x, y, legend_x + 18, y + 18), fill=color)
        d.text((legend_x + 28, y), kind.replace("_", " "), font=font(15), fill=MUTED)
        y += 24
    notes = ["Whole footprint is party-protected (declared, not enforced)",
             "Single south airlock with two door placeholders",
             f"Footprint {WIDTH} x {LENGTH} x {DECKS}; no raid berths",
             "Account markers placed by room, binding is instance-owned"]
    for i, note in enumerate(notes):
        d.text((left, top + LENGTH * cell + 20 + i * 22), note, font=font(15), fill=MUTED)
    output.parent.mkdir(parents=True, exist_ok=True)
    im.save(output)
    print(f"Wrote {output}")


if __name__ == "__main__":
    main()
