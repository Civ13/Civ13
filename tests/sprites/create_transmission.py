"""Hand-placed 32px power transmission parts for icons/obj/transmission.dmi:
the wooden line shaft and the wrought-iron line shaft on their bearings, the
timber gear box (pit wheel, lantern pinion and upright shaft), the dog clutch
drawn apart (`clutch`) and closed (`clutch_engaged`), and the rope drive
pulley. The shafts and clutches have four directions: south and north run
the shaft down the tile, east and west run it across, and the shaft always
reaches both tile edges so neighbouring pieces join up.

Palette, outline and light (from the upper left) follow the prime movers in
create_mechanical_power.py: the same seasoned timber, wrought iron, field
stone and hemp rope. Shafts are kept low and thin so a person standing on the
tile still reads.

Every pixel is placed by this script from a fixed palette (Pillow only); no
external or generated artwork. Run it to reproduce the sheet; `--check`
verifies the committed sheet instead of writing it, `--preview <png>` writes
a 4x review sheet on grass. Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageChops, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/transmission.dmi'

OUT = (30, 22, 16, 255)
SHADOW = (20, 16, 12, 80)
# seasoned timber: highlight, light, mid, dark, deep
TIMBER = [(186, 140, 90, 255), (156, 110, 66, 255), (124, 84, 48, 255), (92, 60, 34, 255), (62, 40, 24, 255)]
# field stone: highlight, light, mid, dark, deep
STONE = [(190, 188, 180, 255), (156, 154, 146, 255), (122, 120, 114, 255), (90, 88, 86, 255), (60, 58, 60, 255)]
# wrought iron: highlight, mid, dark
IRON = [(128, 132, 144, 255), (84, 88, 100, 255), (50, 52, 64, 255)]
# the wet glint of grease on a turning iron shaft
GREASE = (176, 182, 196, 255)
# hemp rope: light, mid, shade
ROPE = [(226, 208, 160, 255), (186, 164, 112, 255), (132, 112, 72, 255)]
# the dark inside of the gear box
PIT = (40, 28, 20, 255)

# BYOND direction order inside a 4-dir state; True = the shaft runs down the tile
DIRS4 = (True, True, False, False)       # south, north, east, west


class Frame:
    def __init__(self):
        self.px = {}

    def put(self, x, y, c):
        if 0 <= x < 32 and 0 <= y < 32:
            self.px[(x, y)] = c

    def pts(self, c, *points):
        for x, y in points:
            self.put(x, y, c)

    def hline(self, x0, x1, y, c):
        for x in range(x0, x1 + 1):
            self.put(x, y, c)

    def vline(self, x, y0, y1, c):
        for y in range(y0, y1 + 1):
            self.put(x, y, c)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            self.hline(x0, x1, y, c)

    def line(self, x0, y0, x1, y1, c):
        """A straight run of pixels; returns the points it set."""
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        out = []
        for i in range(n + 1):
            p = (round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n))
            self.put(p[0], p[1], c)
            out.append(p)
        return out

    def outline(self, c=OUT):
        """A 1px dark edge on every clear pixel that touches a drawn one.
        Pixels off the tile are dropped, so a shaft stays open at the edge."""
        edge = set()
        for (x, y) in self.px:
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if (nx, ny) not in self.px:
                    edge.add((nx, ny))
        for x, y in edge:
            self.put(x, y, c)
        return self

    def shadow(self, x0, y0, x1, y1):
        """A soft ground shadow, only where nothing is drawn yet."""
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if (x, y) not in self.px:
                    self.put(x, y, SHADOW)
        return self

    def image(self):
        im = Image.new('RGBA', (32, 32))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c)
        return im


def grain(a, b, seed=0):
    """A fixed pseudo-random speckle, the same on every run."""
    v = (a * 73856093) ^ (b * 19349663) ^ (seed * 83492791)
    return (v >> 3) % 11


def axis(f, vert):
    """put(along, across, colour): `along` runs down the tile for a vertical
    shaft and across it for a horizontal one. Swapping the two keeps the lit
    side toward the upper left either way."""
    if vert:
        return lambda a, t, c: f.put(t, a, c)
    return lambda a, t, c: f.put(a, t, c)


# where the shafts lie: across-axis start for the vertical and horizontal runs
WOOD_T = {True: 14, False: 18}      # 4px squared timber
IRON_T = {True: 15, False: 19}      # 3px round iron


def wood_shaft(f, vert, a0=0, a1=31):
    """A squared timber axle: lit arris, two face rows, shaded underside."""
    put = axis(f, vert)
    t = WOOD_T[vert]
    for a in range(a0, a1 + 1):
        put(a, t, TIMBER[0] if grain(a // 3, 1, 5) < 4 else TIMBER[1])
        put(a, t + 1, TIMBER[3] if grain(a // 4, 2, 7) == 0 else TIMBER[2])
        put(a, t + 2, TIMBER[2])
        put(a, t + 3, TIMBER[3] if grain(a // 5, 3, 9) else TIMBER[4])


def iron_shaft(f, vert, a0=0, a1=31):
    """A round wrought-iron shaft with a broken greasy glint along it."""
    put = axis(f, vert)
    t = IRON_T[vert]
    for a in range(a0, a1 + 1):
        put(a, t, GREASE if grain(a // 2, 4, 3) < 3 else IRON[0])
        put(a, t + 1, IRON[1])
        put(a, t + 2, IRON[2])


# ----------------------------------------------------------- line shafts

def line_shaft(vert):
    """The timber shaft on a trestle. Seen end-on to the trestle (shaft down
    the tile) it is a sill beam on two feet with a pegged cap over the shaft;
    seen side-on it is a bearing block on a splayed foot."""
    f = Frame()
    if vert:
        # sill beam: top face, then the front face below it
        f.rect(8, 13, 23, 17, TIMBER[2])
        f.hline(8, 23, 13, TIMBER[1])
        f.vline(8, 13, 17, TIMBER[1])
        f.rect(8, 18, 23, 20, TIMBER[3])
        f.hline(8, 23, 20, TIMBER[4])
        f.rect(8, 21, 10, 22, TIMBER[4])         # the feet
        f.rect(21, 21, 23, 22, TIMBER[4])
        wood_shaft(f, True)
        # the cap pegged down over the shaft
        f.rect(12, 13, 19, 16, TIMBER[1])
        f.hline(12, 19, 13, TIMBER[0])
        f.vline(12, 13, 16, TIMBER[0])
        f.hline(12, 19, 16, TIMBER[3])
        f.vline(19, 14, 16, TIMBER[3])
        f.pts(TIMBER[4], (13, 14), (18, 14))
        f.outline()
        f.shadow(19, 0, 20, 31)
        f.shadow(9, 24, 24, 24)
    else:
        wood_shaft(f, False)
        # bearing block the shaft passes through
        f.rect(12, 15, 19, 24, TIMBER[2])
        f.hline(12, 19, 15, TIMBER[0])
        f.vline(12, 16, 24, TIMBER[1])
        f.vline(19, 16, 24, TIMBER[3])
        f.hline(12, 19, 17, TIMBER[3])           # the joint of cap and block
        f.pts(TIMBER[4], (13, 16), (18, 16))     # peg heads
        # the shaft end showing in its bore
        f.rect(14, 19, 17, 21, TIMBER[4])
        f.pts(TIMBER[1], (14, 19), (15, 19))
        f.pts(TIMBER[3], (15, 20), (16, 20))
        # splayed foot
        f.rect(9, 25, 22, 27, TIMBER[3])
        f.hline(9, 22, 25, TIMBER[1])
        f.hline(9, 22, 27, TIMBER[4])
        f.outline()
        f.shadow(0, 26, 31, 27)
        f.shadow(9, 29, 23, 29)
    return f


def line_shaft_iron(vert):
    """The iron shaft in a plummer block bolted to a stone footing."""
    f = Frame()
    if vert:
        # footing: top face and front face
        f.rect(9, 12, 22, 18, STONE[1])
        f.hline(9, 22, 12, STONE[0])
        f.vline(9, 12, 18, STONE[0])
        f.pts(STONE[2], (11, 16), (20, 14), (21, 17), (10, 14))
        f.rect(9, 19, 22, 21, STONE[3])
        f.hline(9, 22, 21, STONE[4])
        f.pts(STONE[2], (12, 19), (18, 20))
        iron_shaft(f, True)
        # plummer block: flanges and the cap humped over the shaft
        f.rect(11, 14, 21, 16, IRON[1])
        f.hline(11, 21, 14, IRON[0])
        f.hline(11, 21, 16, IRON[2])
        f.rect(13, 12, 19, 17, IRON[1])
        f.hline(13, 19, 12, IRON[0])
        f.vline(13, 12, 17, IRON[0])
        f.hline(14, 19, 17, IRON[2])
        f.vline(19, 13, 17, IRON[2])
        f.pts(GREASE, (14, 13), (15, 13), (12, 15), (20, 15))
        f.pts(IRON[2], (16, 15), (17, 15))       # the oil hole
        f.outline()
        f.shadow(19, 0, 20, 31)
        f.shadow(10, 23, 23, 23)
    else:
        iron_shaft(f, False)
        # footing
        f.rect(10, 25, 21, 28, STONE[2])
        f.hline(10, 21, 25, STONE[0])
        f.vline(10, 26, 28, STONE[1])
        f.hline(11, 21, 28, STONE[3])
        f.pts(STONE[3], (14, 26), (19, 27))
        f.pts(STONE[1], (17, 26), (12, 27))
        # plummer block: bolted flange, housing with a rounded cap
        f.rect(11, 23, 20, 24, IRON[1])
        f.hline(11, 20, 23, IRON[0])
        f.hline(11, 20, 24, IRON[2])
        f.pts(GREASE, (12, 23), (19, 23))
        f.rect(13, 17, 18, 22, IRON[1])
        f.hline(14, 17, 16, IRON[1])
        f.pts(IRON[0], (14, 16), (15, 16), (13, 17), (13, 18), (13, 19), (14, 17))
        f.pts(GREASE, (14, 17), (15, 16))
        f.vline(18, 18, 22, IRON[2])
        f.put(17, 16, IRON[2])
        # the journal turning in the housing
        f.rect(14, 19, 17, 21, IRON[2])
        f.pts(GREASE, (14, 19), (15, 19))
        f.pts(IRON[0], (16, 19), (14, 20))
        f.outline()
        f.shadow(0, 26, 31, 27)
        f.shadow(10, 30, 22, 30)
    return f


# -------------------------------------------------------------- gear box

def cog_wheel(f, cx, cy, r, cogs, spokes=4, phase=0.0):
    """A wooden cog wheel seen face-on: felloe, spokes, iron hub, pegs."""
    for a in range(0, 360, 2):
        ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        lit = (ca + sa) < -0.2                    # the upper left of the rim
        f.put(round(cx + r * ca), round(cy + r * sa), TIMBER[1] if lit else TIMBER[3])
        f.put(round(cx + (r - 1) * ca), round(cy + (r - 1) * sa), TIMBER[2])
    for k in range(spokes):
        a = math.radians(phase + k * 360 / spokes)
        f.line(cx, cy, round(cx + (r - 2) * math.cos(a)), round(cy + (r - 2) * math.sin(a)),
               TIMBER[1] if k % 2 else TIMBER[2])
    for k in range(cogs):
        a = math.radians(phase + k * 360 / cogs)
        f.put(round(cx + (r + 1) * math.cos(a)), round(cy + (r + 1) * math.sin(a)), TIMBER[0])
    f.rect(cx - 1, cy - 1, cx + 1, cy + 1, IRON[1])
    f.put(cx, cy, IRON[0])
    f.put(cx - 1, cy - 1, IRON[0])


def gear_box():
    """A heavy open timber frame. Inside, the cogged pit wheel on the lying
    shaft meshes with a lantern pinion on the upright shaft, whose stub comes
    up through the head beam."""
    f = Frame()
    f.rect(4, 9, 27, 27, PIT)
    cog_wheel(f, 12, 18, 7, 12, spokes=4, phase=45)
    # lantern pinion: two discs joined by round staves
    for y in range(13, 25):
        for i, x in enumerate((21, 23, 25)):
            f.put(x, y, (TIMBER[0], TIMBER[1], TIMBER[3])[i])
    f.rect(20, 11, 26, 12, TIMBER[1])
    f.hline(20, 26, 11, TIMBER[0])
    f.put(26, 12, TIMBER[3])
    f.rect(20, 24, 26, 25, TIMBER[2])
    f.hline(20, 26, 25, TIMBER[3])
    f.rect(22, 26, 24, 27, IRON[2])               # the foot bearing
    # frame: sill, posts, head beam
    f.rect(1, 28, 30, 30, TIMBER[3])
    f.hline(1, 30, 28, TIMBER[1])
    f.hline(1, 30, 30, TIMBER[4])
    for x0 in (2, 27):
        f.rect(x0, 9, x0 + 2, 27, TIMBER[2])
        f.vline(x0, 9, 27, TIMBER[1])
        f.vline(x0 + 2, 9, 27, TIMBER[3])
    f.rect(1, 5, 30, 8, TIMBER[2])
    f.hline(1, 30, 5, TIMBER[0])
    f.hline(1, 30, 8, TIMBER[4])
    for x in range(2, 30):
        if grain(x // 3, 6, 2) == 0:
            f.put(x, 6, TIMBER[3])
    f.pts(TIMBER[4], (3, 7), (28, 7), (3, 29), (28, 29))      # trenails
    # upright shaft stub through the head beam, with its iron collar
    f.rect(22, 0, 24, 5, TIMBER[2])
    f.vline(22, 0, 5, TIMBER[0])
    f.vline(24, 0, 5, TIMBER[3])
    f.rect(21, 4, 25, 5, IRON[1])
    f.hline(21, 25, 4, IRON[0])
    f.put(25, 5, IRON[2])
    f.rect(22, 9, 24, 10, TIMBER[3])
    f.outline()
    f.shadow(2, 31, 30, 31)
    return f


# ---------------------------------------------------------------- clutch

def collar(f, vert, a0, t0, t1):
    """A turned wooden collar, 4px along the shaft, iron-bound at its rim."""
    put = axis(f, vert)
    for a in range(a0, a0 + 4):
        for t in range(t0, t1 + 1):
            c = TIMBER[2]
            if t == t0:
                c = TIMBER[0]
            elif t == t0 + 1 or a == a0:
                c = TIMBER[1]
            elif t >= t1 - 1:
                c = TIMBER[3]
            put(a, t, c)
    for a in range(a0, a0 + 4):
        put(a, t1, TIMBER[4])


def dogs(f, vert, a0, t0, t1, odd):
    """Iron dogs standing 2px proud of a collar face, on alternate rows."""
    put = axis(f, vert)
    for t in range(t0 + 1, t1):
        if ((t - t0) // 2) % 2 == odd:
            put(a0, t, IRON[0] if t < (t0 + t1) // 2 else IRON[1])
            put(a0 + 1, t, IRON[1] if t < (t0 + t1) // 2 else IRON[2])


def clutch(vert, engaged):
    """A wooden shaft cut in two. The fixed collar sits on the first half;
    the sliding collar on the second is drawn back, leaving a gap between the
    dogs, or pushed home so they lock. The throw-out lever leans with it."""
    f = Frame()
    t = WOOD_T[vert]
    t0, t1 = t - 4, t + 7
    slide = 17 if engaged else 21         # near face of the sliding collar
    wood_shaft(f, vert, 0, 10)
    wood_shaft(f, vert, slide, 31)
    collar(f, vert, 9, t0, t1)
    collar(f, vert, slide, t0, t1)
    dogs(f, vert, 13, t0, t1, 0)
    dogs(f, vert, slide - 2, t0, t1, 0 if not engaged else 1)
    if engaged:
        # the dogs of both collars mesh into one iron band
        dogs(f, vert, 15, t0, t1, 1)
        dogs(f, vert, 13, t0, t1, 0)
        dogs(f, vert, 15, t0, t1, 0)
        dogs(f, vert, 13, t0, t1, 1)
    mid = slide + 1
    if vert:
        # lever lying across to the right: forked on the collar, pinned to a
        # post, the handle swinging the other way
        py = 19
        hy = py - 3 * (mid - py) - (2 if engaged else 0)
        f.rect(24, py - 1, 26, py + 3, TIMBER[3])
        f.hline(24, 26, py - 1, TIMBER[1])
        for x, y in f.line(t1 + 1, mid, 30, hy, TIMBER[1]):
            f.put(x, y + 1, TIMBER[3])
        f.rect(29, hy - 1, 30, hy + 1, TIMBER[0])
        f.put(30, hy + 1, TIMBER[2])
        f.put(25, py, IRON[0])
        f.outline()
        f.shadow(t + 5, 0, t + 6, 31)
        f.shadow(24, py + 5, 27, py + 5)
    else:
        # lever standing in front: pivoted on a foot block behind the
        # sliding collar, the handle thrown back (apart) or over it (home)
        px = slide + 4
        tip = px - 8 if engaged else px + 4
        f.rect(px - 2, 28, px + 2, 29, TIMBER[3])
        f.hline(px - 2, px + 2, 28, TIMBER[1])
        for x, y in f.line(px, 28, tip, 9, TIMBER[1]):
            f.put(x + 1, y, TIMBER[3])
        f.rect(tip - 1, 7, tip + 1, 9, TIMBER[0])
        f.pts(TIMBER[2], (tip + 1, 8), (tip + 1, 9))
        f.put(px, 28, IRON[0])
        f.outline()
        f.shadow(0, 27, 31, 28)
        f.shadow(px - 2, 31, px + 3, 31)
    return f


# ------------------------------------------------------------ rope drive

def rope_drive():
    """A big rope pulley on an A-frame: iron flanges either side of a groove
    full of hemp rope, timber felloe and spokes. One turn of rope leaves the
    top of the wheel toward the upper right."""
    f = Frame()
    cx, cy, r = 14, 16, 10
    # sole plate
    f.rect(2, 28, 27, 29, TIMBER[3])
    f.hline(2, 27, 28, TIMBER[1])
    f.hline(2, 27, 30, TIMBER[4])
    # the far leg of the frame, behind the wheel
    f.line(cx + 1, cy, 25, 27, TIMBER[4])
    f.line(cx + 2, cy, 26, 27, TIMBER[4])
    # rim rings from the outside in: flange, rope in the groove, flange, felloe
    for a in range(0, 360, 2):
        ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        lit = (ca + sa) < -0.2
        f.put(round(cx + (r + 1) * ca), round(cy + (r + 1) * sa), IRON[0] if lit else IRON[2])
        f.put(round(cx + r * ca), round(cy + r * sa), ROPE[(a // 20) % 2] if lit else ROPE[1 + (a // 20) % 2])
        f.put(round(cx + (r - 1) * ca), round(cy + (r - 1) * sa), IRON[1])
        f.put(round(cx + (r - 2) * ca), round(cy + (r - 2) * sa), TIMBER[1] if lit else TIMBER[3])
        f.put(round(cx + (r - 3) * ca), round(cy + (r - 3) * sa), TIMBER[2])
    for k in range(6):
        a = math.radians(30 + k * 60)
        f.line(cx, cy, round(cx + (r - 4) * math.cos(a)), round(cy + (r - 4) * math.sin(a)),
               TIMBER[1] if k in (3, 4, 5) else TIMBER[2])
    # the near leg, in front of the wheel, and the hub on its bearing
    for x, y in f.line(cx - 1, cy, 3, 27, TIMBER[1]):
        f.put(x + 1, y, TIMBER[3])
    f.rect(cx - 2, cy - 2, cx + 2, cy + 2, IRON[1])
    f.hline(cx - 2, cx + 2, cy - 2, IRON[0])
    f.vline(cx - 2, cy - 2, cy + 2, IRON[0])
    f.hline(cx - 1, cx + 2, cy + 2, IRON[2])
    f.put(cx, cy, GREASE)
    # the rope leaving the groove at the top, up and to the right
    run = f.line(11, 6, 27, 0, ROPE[0])
    for i, (x, y) in enumerate(run):
        f.put(x, y, ROPE[0] if i % 3 else ROPE[1])
        if y + 1 < cy - r - 1 or x > cx + 4:
            f.put(x, y + 1, ROPE[2] if i % 3 else ROPE[1])
    f.outline()
    f.shadow(3, 31, 28, 31)
    return f


def states():
    return {
        'line_shaft': [line_shaft(v) for v in DIRS4],
        'line_shaft_iron': [line_shaft_iron(v) for v in DIRS4],
        'gear_box': [gear_box()],
        'clutch': [clutch(v, False) for v in DIRS4],
        'clutch_engaged': [clutch(v, True) for v in DIRS4],
        'rope_drive': [rope_drive()],
    }


def build_sheet(st):
    frames = [fr for group in st.values() for fr in group]
    sheet = Image.new('RGBA', (32 * len(frames), 32), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(fr.image(), (i * 32, 0))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, group in st.items():
        text += 'state = "%s"\n\tdirs = %d\n\tframes = 1\n' % (name, len(group))
    text += '# END DMI\n'
    return sheet, text


def write_dmi(path, st):
    sheet, text = build_sheet(st)
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta)


def check(path, st):
    sheet, text = build_sheet(st)
    old = Image.open(path)
    if old.info.get('Description') != text:
        sys.exit('%s: state list differs from the generator' % path)
    if old.size != sheet.size or ImageChops.difference(old.convert('RGBA'), sheet).getbbox():
        sys.exit('%s: pixels differ from the generator' % path)
    print('%s matches the generator' % path)


def preview(path, st, scale=4):
    """Every state at 4x on grass, a row per direction (south, north, east,
    west), a true-size row beneath, then two shafts side by side each way to
    show the tile joins."""
    grass = (94, 132, 62, 255)
    pad = 6
    cell = 32 * scale
    rows = max(len(group) for group in st.values())
    join_y = pad + rows * (cell + pad) + 32 + pad
    sheet = Image.new('RGBA', (pad + len(st) * (cell + pad), join_y + cell * 2 + pad), grass)
    for i, group in enumerate(st.values()):
        x = pad + i * (cell + pad)
        for j, fr in enumerate(group):
            tile = Image.new('RGBA', (32, 32), grass)
            tile.alpha_composite(fr.image())
            sheet.paste(tile.resize((cell, cell), Image.NEAREST), (x, pad + j * (cell + pad)))
        tile = Image.new('RGBA', (32, 32), grass)
        tile.alpha_composite(group[-1].image())
        sheet.paste(tile, (x + (cell - 32) // 2, pad + rows * (cell + pad)))
    # joins: line shaft into clutch across, iron shaft into iron shaft down
    pairs = (
        (st['line_shaft'][2], st['clutch'][2], (1, 0)),
        (st['line_shaft'][0], st['clutch_engaged'][0], (0, 1)),
        (st['line_shaft_iron'][2], st['line_shaft_iron'][3], (1, 0)),
        (st['line_shaft_iron'][0], st['line_shaft_iron'][1], (0, 1)),
    )
    x = pad
    for a, b, (dx, dy) in pairs:
        strip = Image.new('RGBA', (32 * (1 + dx), 32 * (1 + dy)), grass)
        strip.alpha_composite(a.image(), (0, 0))
        strip.alpha_composite(b.image(), (32 * dx, 32 * dy))
        strip = strip.resize((strip.width * scale, strip.height * scale), Image.NEAREST)
        sheet.paste(strip, (x, join_y))
        x += strip.width + pad
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)


if __name__ == '__main__':
    st = states()
    if '--check' in sys.argv:
        check(SHEET, st)
    else:
        write_dmi(SHEET, st)
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1], st)
