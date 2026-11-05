"""Manifest-backed static source diagram of the Hauler raid study, never a native render."""
from pathlib import Path
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_map as home  # noqa: E402
from build_raid_train import ROOT, PALETTE, SIZE, build  # noqa: E402

OUTPUT = ROOT / "docs/images/dagger-raid-train-preview.png"
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
    grid, layout = build()
    merged = dict(home.PALETTE)
    merged.update(PALETTE)
    cell, top, left = 4, 150, 60
    x0, y0, x1, y1 = 50, 8, 199, 249
    width, height = (x1 - x0 + 1) * cell, (y1 - y0 + 1) * cell
    im = Image.new("RGB", (left * 2 + width + 620, top + height + 60), BG)
    d = ImageDraw.Draw(im)
    d.text((left, 30), "DAGGER / RAID TARGET TRAIN STUDY", font=font(20, True), fill=TEAL)
    d.text((left, 60), "Hauler raid station - inactive draft (static diagram, z1, both Daggers docked)", font=font(28, True), fill=TEXT)
    composed = {p: kind for p, (kind, _) in grid.items() if p[2] == 1}
    for slot in layout["slots"]:
        ox, oy, _ = slot["origin"]
        for (dx, dy, dz), kind in home.train_levels().items():
            if dz == 0:
                composed[ox + dx, oy + dy, 1] = kind
    for (x, y, z), kind in composed.items():
        if x0 <= x <= x1 and y0 <= y <= y1:
            a, b = left + (x - x0) * cell, top + (y1 - y) * cell
            d.rectangle((a, b, a + cell - 1, b + cell - 1), fill=merged[kind][1])
    ox, oy, _ = layout["target_train"]["origin"]
    for section in layout["sections"]:
        sx0, sy0, sx1, sy1 = section["bounds"]
        b = top + (y1 - (oy + sy1)) * cell
        d.text((left + (ox + sx1 + 10 - x0) * cell, b), f"T{section['tier']} {section['name']} ({section['loot_anchor_count']} anchors)", font=font(13), fill=TEXT)
    legend_x = left + width + 20
    d.rounded_rectangle((legend_x - 15, top - 50, legend_x + 410, top + 560), radius=16, fill=PANEL)
    d.text((legend_x, top - 40), "Legend", font=font(22, True), fill=TEXT)
    y = top
    for kind in ("hull", "pillar", "cage", "floor", "deck", "cabin", "yard", "berth", "platform", "bridge",
                 "door", "breach", "engine_mount", "helm", "bed", "crate", "crate_deck", "rack", "table", "chair", "dirt", "safe"):
        d.rectangle((legend_x, y, legend_x + 18, y + 18), fill=merged[kind][1])
        d.text((legend_x + 28, y), kind.replace("_", " ") + (" (docked Dagger safe rooms)" if kind == "safe" else ""), font=font(15), fill=MUTED)
        y += 24
    notes = ["Rear (south) sections are cheap and sparse; the front (north) is dense",
             "Every compartment door is an ordinary breachable door; no locked doors",
             "Two Dagger berths with boarding bridges share the platforms",
             f"World {SIZE} x {SIZE} x 4; berths reserve z1..4 for a docked Dagger"]
    for i, note in enumerate(notes):
        d.text((legend_x, y + 10 + i * 22), note, font=font(14), fill=MUTED)
    output.parent.mkdir(parents=True, exist_ok=True)
    im.save(output)
    print(f"Wrote {output}")


if __name__ == "__main__":
    main()
