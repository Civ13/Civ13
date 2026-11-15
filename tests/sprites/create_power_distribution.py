"""Original hand-placed 32px wall outlet, utility pole and overhead span sprites, no external or generated artwork.
Run with Pillow to reproduce icons/obj/power_distribution.dmi; released under Civ13 AGPL-3.0.

`--preview DIR` also renders review sheets (sprite-preview.png, span-preview.png) into DIR.
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
SIZE = 32

# Steel and timber follow icons/obj/renewable_power.dmi; cable greys follow cables.dmi.
IRON_EDGE = '#252b26'
IRON = '#4a4d52'
IRON_MID = '#6b6f75'
IRON_LIGHT = '#7d8188'
CABLE = '#7f7f7f'
CABLE_DARK = '#4d4d4d'
WOOD_EDGE = '#3f2a17'
WOOD_DARK = '#53371f'
WOOD = '#7a5531'
WOOD_LIGHT = '#b48854'
PORCELAIN = '#d9dde1'
PORCELAIN_SHADE = '#9aa1a8'
GLINT = '#fbfcfd'
LAMP = '#ffb43c'
LAMP_GLOW = '#ffe08a'
LAMP_OFF = '#5a3b1c'
WIRE = '#2b2b2b'

# The wire is drawn through this row of the pole (26 pixels up the tile).
INSULATOR_ROW = 6


def wall_outlet(facing, live):
    """Cast-iron outlet box hugging the tile edge the wall is on, with a cable stub.

    facing is 'S', 'N', 'E' or 'W': the side of the tile the wall stands on.
    """
    im = Image.new('RGBA', (SIZE, SIZE))
    d = ImageDraw.Draw(im)
    lamp = LAMP if live else LAMP_OFF
    if facing in ('N', 'S'):
        top = 1 if facing == 'N' else 24
        # Box face, lit along the top edge and left side.
        d.rectangle((12, top, 19, top + 6), fill=IRON, outline=IRON_EDGE)
        d.line([(13, top + 1), (18, top + 1)], fill=IRON_LIGHT)
        d.line([(13, top + 2), (13, top + 5)], fill=IRON_MID)
        # Two round-pin sockets and the indicator above them.
        d.point((14, top + 4), fill=IRON_EDGE)
        d.point((17, top + 4), fill=IRON_EDGE)
        d.point((16, top + 2), fill=lamp)
        if live:
            d.point((15, top + 2), fill=LAMP_GLOW)
        if facing == 'N':
            # Cable drops from the box toward the cable under the tile.
            d.line([(16, top + 7), (16, top + 10)], fill=CABLE)
            d.point((16, top + 11), fill=CABLE_DARK)
        else:
            # Seen from behind the south wall line: the cable enters from above.
            d.line([(16, top - 4), (16, top - 1)], fill=CABLE)
            d.point((16, top - 5), fill=CABLE_DARK)
            d.line([(12, top + 7), (19, top + 7)], fill=IRON_EDGE)
    else:
        # Side-on box: a narrow plate standing out from the east or west wall.
        d.rectangle((26, 12, 30, 19), fill=IRON, outline=IRON_EDGE)
        d.line([(27, 13), (29, 13)], fill=IRON_LIGHT)
        d.line([(27, 14), (27, 18)], fill=IRON_MID)
        d.point((28, 17), fill=IRON_EDGE)
        d.point((28, 15), fill=lamp)
        if live:
            d.point((28, 14), fill=LAMP_GLOW)
        d.line([(22, 16), (25, 16)], fill=CABLE)
        d.point((21, 16), fill=CABLE_DARK)
        if facing == 'W':
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
    return im


def wall_outlet_dirs(live):
    """DMI dir order south, north, east, west."""
    return [wall_outlet(f, live) for f in ('S', 'N', 'E', 'W')]


def utility_pole(live):
    """Tarred timber pole with a braced crossarm and five porcelain pin insulators."""
    im = Image.new('RGBA', (SIZE, SIZE))
    d = ImageDraw.Draw(im)
    # Packed earth at the foot.
    d.ellipse((11, 28, 21, 31), fill='#3a3a36')
    d.line([(13, 30), (19, 30)], fill='#4a4d52')
    # Shaft: dark edge, mid timber, one lit grain line.
    d.rectangle((14, 7, 18, 29), fill=WOOD, outline=WOOD_EDGE)
    d.line([(15, 8), (15, 28)], fill=WOOD_LIGHT)
    d.line([(17, 8), (17, 28)], fill=WOOD_DARK)
    for y in (14, 21, 26):
        d.point((16, y), fill=WOOD_DARK)
    # Tarred butt.
    d.rectangle((15, 26, 17, 28), fill=WOOD_DARK)
    # Diagonal braces under the crossarm.
    d.line([(9, 10), (13, 14)], fill=WOOD_EDGE)
    d.line([(23, 10), (19, 14)], fill=WOOD_EDGE)
    # Crossarm.
    d.rectangle((5, 8, 27, 10), fill=WOOD, outline=WOOD_EDGE)
    d.line([(6, 9), (26, 9)], fill=WOOD_LIGHT)
    d.point((16, 9), fill=IRON_EDGE)
    # Insulators: four on the arm, one on the pole top where the span meets.
    for x in (7, 11, 16, 21, 25):
        d.point((x, 7), fill=IRON_EDGE)
        d.rectangle((x - 1, INSULATOR_ROW - 1, x, INSULATOR_ROW), fill=PORCELAIN)
        d.point((x, INSULATOR_ROW), fill=PORCELAIN_SHADE)
        if live:
            d.point((x - 1, INSULATOR_ROW - 1), fill=GLINT)
            d.point((x, INSULATOR_ROW), fill='#c9d6f2')
    return im


def span():
    """One tile of overhead wire: a single dark row, stretched and turned in code."""
    im = Image.new('RGBA', (SIZE, SIZE))
    ImageDraw.Draw(im).line([(0, 16), (31, 16)], fill=WIRE)
    return im


def build_states():
    return [
        ('wall_outlet', [wall_outlet_dirs(False)]),
        ('wall_outlet_live', [wall_outlet_dirs(True)]),
        ('utility_pole', [utility_pole(False)]),
        ('utility_pole_live', [utility_pole(True)]),
        ('span', [span()]),
    ]


def main():
    states = build_states()
    # A group entry is one frame, or a list of four dir images for that frame.
    frames = [img for _, group in states for frame in group
              for img in (frame if isinstance(frame, list) else [frame])]
    sheet = Image.new('RGBA', (SIZE * len(frames), SIZE))
    for i, frame in enumerate(frames):
        sheet.paste(frame, (i * SIZE, 0))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, group in states:
        dirs = 4 if isinstance(group[0], list) else 1
        text += f'state = "{name}"\n\tdirs = {dirs}\n\tframes = {len(group)}\n'
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(ROOT / 'icons/obj/power_distribution.dmi', format='PNG', pnginfo=meta)
    if '--preview' in sys.argv:
        out = Path(sys.argv[sys.argv.index('--preview') + 1])
        out.mkdir(parents=True, exist_ok=True)
        sprite_preview(states).save(out / 'sprite-preview.png')
        span_preview().save(out / 'span-preview.png')


# ---------------------------------------------------------------- previews

def sprite_preview(states, scale=4):
    """Every frame at 4x on mid-grey and on grass green, labelled."""
    cells = []
    for name, group in states:
        frame = group[0]
        if isinstance(frame, list):
            cells += [(f'{name} {d}', img) for d, img in zip('SNEW', frame)]
        else:
            cells.append((name, frame))
    cell_w, cell_h = SIZE * scale + 24, SIZE * scale + 22
    sheet = Image.new('RGBA', (cell_w * len(cells), cell_h * 2), '#20242a')
    d = ImageDraw.Draw(sheet)
    for row, back in enumerate(('#808080', '#4f7a3a')):
        for i, (label, img) in enumerate(cells):
            x, y = i * cell_w + 12, row * cell_h + 4
            tile = Image.new('RGBA', (SIZE, SIZE), back)
            tile.alpha_composite(img)
            sheet.paste(tile.resize((SIZE * scale, SIZE * scale), Image.NEAREST), (x, y))
            d.text((x, y + SIZE * scale + 3), label, fill='#e6e9ec')
    return sheet


def span_matrix(dx, dy):
    """The matrix update_span_overlays() builds, for a partner dx, dy pixels away.

    Same steps as the DM: Scale(length / 32, 1), Turn(-arctan(dx, dy)),
    Translate(dx / 2, dy / 2 + 10). Returns BYOND's a, b, c, d, e, f with
    x' = a*x + b*y + c and y' = d*x + e*y + f, y pointing up.
    """
    length = math.hypot(dx, dy)
    sx = length / SIZE
    turn = -math.atan2(dy, dx)  # BYOND Turn() is clockwise, so counterclockwise is negative
    cos, sin = math.cos(turn), math.sin(turn)
    # Turn(t): x' = x cos t + y sin t, y' = -x sin t + y cos t
    return (sx * cos, sin, dx / 2, -sx * sin, cos, dy / 2 + 10)


def draw_span(scene, frame, tile_x, tile_y, dx, dy, rows):
    """Place the span frame as BYOND would: transform about the icon centre, nearest sample."""
    a, b, c, d, e, f = span_matrix(dx, dy)
    det = a * e - b * d
    # Icon centre of the owning pole in scene pixels, y up.
    cx, cy = tile_x * SIZE + 16, tile_y * SIZE + 16
    px, out = frame.load(), scene.load()
    height = rows * SIZE
    for oy in range(int(min(0, dy)) - 4, int(max(0, dy)) + 28):
        for ox in range(int(min(0, dx)) - 20, int(max(0, dx)) + 20):
            wx, wy = ox + 0.5 - c, oy + 0.5 - f
            sx, sy = (e * wx - b * wy) / det, (a * wy - d * wx) / det
            ix, iy = math.floor(sx + 16), math.floor(sy + 16)  # iy counts up from the bottom row
            if 0 <= ix < SIZE and 0 <= iy < SIZE and px[ix, SIZE - 1 - iy][3]:
                X, Y = cx + ox, height - 1 - (cy + oy)
                if 0 <= X < scene.width and 0 <= Y < scene.height:
                    out[X, Y] = px[ix, SIZE - 1 - iy]


def span_preview(scale=3, cols=8, rows=6):
    """Mock scene: three wired poles (east, north-east and north spans), an outlet and a transformer."""
    scene = Image.new('RGBA', (cols * SIZE, rows * SIZE), '#4f7a3a')
    d = ImageDraw.Draw(scene)
    for ty in range(rows):
        for tx in range(cols):
            if (tx + ty) % 2:
                d.rectangle((tx * SIZE, ty * SIZE, tx * SIZE + 31, ty * SIZE + 31), fill='#4a7436')

    def place(img, tx, ty):
        # ty counts up from the bottom row, as in game; taller icons rise from the tile's foot.
        scene.alpha_composite(img, (tx * SIZE, (rows - ty) * SIZE - img.height))

    # A stone wall along the top row; the outlet's tile is just south of it.
    for tx in range(cols):
        x, y = tx * SIZE, 0
        d.rectangle((x, y, x + 31, y + 31), fill='#6c6d68', outline='#3a3a36')
        d.line([(x + 1, y + 16), (x + 30, y + 16)], fill='#4a4d52')
        d.line([(x + 16, y + 1), (x + 16, y + 15)], fill='#4a4d52')
        d.line([(x + 8, y + 17), (x + 8, y + 30)], fill='#4a4d52')
    place(wall_outlet('N', True), 2, rows - 2)
    place(Image.open(ROOT / 'icons/obj/powertransformer.dmi').convert('RGBA'), 3, 2)
    poles = {'A': (1, 1), 'B': (5, 1), 'C': (5, 4)}
    for tx, ty in poles.values():
        place(utility_pole(True), tx, ty)
    # Each pair is drawn once, from one pole only, exactly as the DM proc does.
    frame = span()
    for owner, partner in (('A', 'B'), ('A', 'C'), ('B', 'C')):
        (x0, y0), (x1, y1) = poles[owner], poles[partner]
        draw_span(scene, frame, x0, y0, (x1 - x0) * SIZE, (y1 - y0) * SIZE, rows)
    big = scene.resize((scene.width * scale, scene.height * scale), Image.NEAREST)
    d = ImageDraw.Draw(big)
    for name, (tx, ty) in poles.items():
        d.text((tx * SIZE * scale + 4, (rows - ty) * SIZE * scale - 12), f'pole {name}', fill='#fbfcfd')
    d.text((4, rows * SIZE * scale - 12), 'spans: A-B east, A-C north-east, B-C north; outlet dir=NORTH on the wall; transformer keeps its sprite',
           fill='#fbfcfd')
    return big


if __name__ == '__main__':
    main()
