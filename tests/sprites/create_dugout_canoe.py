"""Hand-placed 32px Stone Age dugout canoe: the trimmed log, its two stages of
burning and adzing out (each plain and charred), the finished canoe in four
directions and a leaf-bladed paddle. Every pixel is placed by this script from
a fixed palette (Pillow only); no external or generated artwork.
The outline and wood tones are the ones create_stone_age_arms.py and
create_stone_age_traps.py use, lit from the upper left. The canoe is a single
hollowed log with thick blunt ends, after the Pesse canoe: bark-brown outside,
paler adzed wood and fire scars inside. It is drawn without a tile background
and with an open hold, so the water shows around it and the paddlers are
drawn over it.

Run with Pillow to reproduce icons/obj/vehicles/dugout_canoe.dmi.
`--preview <png>` also writes a labelled review sheet (4x and 1x, on water
and on grass).
Released under Civ13 AGPL-3.0.
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]

OUT = (62, 49, 34)
# worked wood, light to dark
WD = [(198, 151, 106), (168, 122, 76), (122, 84, 50), (92, 61, 34)]
# pale freshly adzed wood
PW = [(214, 180, 132), (184, 146, 98), (140, 104, 64)]
# bark, light to dark
BK = [(134, 100, 68), (108, 78, 51), (84, 59, 38), (66, 47, 31)]
# charred wood, ash to black
CH = [(118, 110, 102), (72, 64, 58), (46, 40, 37), (28, 24, 23)]
# preview backgrounds
GRASS = (86, 128, 62)
WATER = (62, 112, 152)
DARK = (30, 32, 36)

SOUTH, NORTH, EAST, WEST = 'south', 'north', 'east', 'west'


def noise(x, y, seed=0):
    """A fixed 0..1 value per pixel, so the sheet is reproducible."""
    n = (x * 374761393 + y * 668265263 + seed * 2147483647) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


class Frame:
    def __init__(self):
        self.px = {}

    def put(self, x, y, c):
        if 0 <= x < 32 and 0 <= y < 32:
            self.px[(x, y)] = (c[0], c[1], c[2], 255)

    def outline(self, c=OUT):
        """Ring every drawn shape with the dark outline colour."""
        edge = set()
        for (x, y) in self.px:
            for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if n not in self.px:
                    edge.add(n)
        for x, y in edge:
            self.put(x, y, c)

    def image(self):
        im = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c)
        return im


def blunt(t, n):
    """Half-width (0..1) of a blunt-ended lozenge at t (-1..1) along it."""
    t = abs(t)
    return (1 - t ** n) ** (1.0 / n) if t < 1 else -1.0


def char(x, y, seed):
    n = noise(x, y, seed)
    return CH[3] if n < 0.45 else CH[2] if n < 0.82 else CH[1] if n < 0.95 else CH[0]


def adzed(x, y, seed):
    """Pale wood with short adze scallops."""
    n = noise(x // 2, y, seed)
    return PW[0] if n > 0.7 else PW[2] if n < 0.14 else PW[1]


# ---------------------------------------------------------------- the log

LOG_CY = 15.5
LOG_R = 7.0


def log_body(stage):
    """Pixels of the lying log -> (kind, v). Stages 0 and 1 are a trimmed
    trunk with a sawn-looking (stone-chopped) end face on the right; stage 2
    has had both ends rounded off into the blunt canoe ends."""
    cells = {}
    for y in range(32):
        v = (y - LOG_CY) / LOG_R
        if abs(v) >= 1:
            continue
        for x in range(32):
            if stage < 2:
                bulge = 2.5 * math.sqrt(1 - v * v)
                if 3.5 - bulge <= x <= 27.5 + bulge:
                    face = ((x - 27.5) / 2.5) ** 2 + v * v <= 1
                    cells[(x, y)] = ('face' if face else 'bark', v)
            else:
                t = (x - 15.5) / 15.0
                if abs(t) < 1 and abs(v) <= blunt(t, 3.6):
                    cells[(x, y)] = ('bark', v)
    return cells


def bark(x, y, v, seed=3):
    i = 1 if v < -0.72 else 0 if v < -0.2 else 1 if v < 0.38 else 2 if v < 0.74 else 3
    if noise(x // 3, y, seed) > 0.74:  # long furrows
        i = min(3, i + 1)
    elif noise(x // 2, y, seed + 1) > 0.9 and i:
        i -= 1
    return BK[i]


def hollow_shape(stage):
    """The opening worked into the top of the log: (cx, cy, rx, ry, power)."""
    return {0: (14.5, 12.0, 10.5, 1.6, 2.0),
            1: (14.5, 12.5, 10.0, 2.6, 2.6),
            2: (15.5, 13.0, 12.0, 4.1, 3.2)}[stage]


def in_hollow(x, y, stage):
    cx, cy, rx, ry, n = hollow_shape(stage)
    t = (x - cx) / rx
    return abs(t) < 1 and abs(y - cy) <= ry * blunt(t, n)


def log(stage, charred=False):
    f = Frame()
    for (x, y), (kind, v) in log_body(stage).items():
        if kind == 'face':
            # heartwood rings on the chopped end
            r = math.hypot((x - 27.5) / 2.5, v)
            f.put(x, y, WD[1] if r > 0.8 else WD[0] if r > 0.42 else WD[2] if r < 0.2 else WD[1])
        else:
            f.put(x, y, bark(x, y, v))
    # two trimmed branch stubs
    if stage < 2:
        for kx, ky in ((8, 17), (20, 19)):
            f.put(kx, ky, WD[1])
            f.put(kx + 1, ky, WD[2])
            f.put(kx, ky + 1, BK[3])
            f.put(kx + 1, ky + 1, BK[3])
    else:
        # hewn facets where the ends were rounded off
        for x, y in ((2, 14), (2, 15), (3, 17), (28, 16), (29, 15), (29, 14), (27, 18), (4, 18)):
            f.put(x, y, WD[2])
    hole = set()
    if stage or charred:
        hole = {(x, y) for x in range(32) for y in range(32) if in_hollow(x, y, stage)}
    for x, y in sorted(hole):
        up1 = (x, y - 1) not in hole
        up2 = (x, y - 2) not in hole
        left = (x - 1, y) not in hole
        if stage == 0:
            # only reached when charred: fire laid along the top of the bark
            c = char(x, y, 11)
        elif charred:
            c = CH[3] if up1 else char(x, y, 12 + stage)
            if stage == 2 and not up1 and (x, y + 1) not in hole and noise(x, y, 5) > 0.5:
                c = CH[1]
        else:
            c = adzed(x, y, 20 + stage)
            if up1:
                c = WD[3] if stage == 2 else WD[2]
            elif up2 and stage == 2:
                c = WD[2]
            elif left:
                c = PW[2]
            elif noise(x // 2, y // 2, 40 + stage) > 0.8 and noise(x, y, 41) > 0.35:
                c = CH[2] if noise(x, y, 42) > 0.4 else CH[1]  # charcoal left by the fire
        f.put(x, y, c)
    if stage:
        # the chipped lip round the opening
        for x, y in sorted(hole):
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y + 1), (x, y - 1)):
                if (nx, ny) not in hole and (nx, ny) in f.px:
                    if charred:
                        if noise(nx, ny, 9) > 0.45:
                            f.put(nx, ny, CH[2] if noise(nx, ny, 8) > 0.5 else BK[3])
                    elif ny > y or stage == 2:
                        f.put(nx, ny, WD[0] if ny > y else WD[1])
    elif charred:
        # scorch creeping onto the bark beside the strip
        for x, y in sorted(hole):
            for ny in (y - 1, y + 1):
                if (x, ny) not in hole and (x, ny) in f.px and noise(x, ny, 7) > 0.6:
                    f.put(x, ny, CH[2])
    f.outline()
    return f


# ------------------------------------------------------- the finished canoe

def canoe(facing):
    """The dugout from above and a little from the south, bow towards
    `facing`. The bow is slightly more rounded than the squarer stern; the
    south side of the hull (or the southern end, when it lies north-south)
    shows as a band of bark below the gunwale."""
    flat = facing in (EAST, WEST)
    half_len = 15.0 if flat else 13.5
    half_wid = 6.0
    sign = 1 if facing in (EAST, SOUTH) else -1

    def local(x, y):
        u, v = (x - 15.5, y - 14.5) if flat else (y - 14.5, x - 15.5)
        return u * sign, v

    def top(x, y):
        u, v = local(x, y)
        t = u / half_len
        if abs(t) >= 1:
            return False
        return abs(v) <= half_wid * blunt(t, 2.7 if t > 0 else 4.6)

    def hold(x, y):
        u, v = local(x, y)
        # thick solid ends, thin sides
        t = (u + 0.4) / (half_len - 3.6)
        if abs(t) >= 1:
            return False
        return abs(v) <= (half_wid - 1.6) * blunt(t, 2.7 if t > 0 else 4.2)

    f = Frame()
    grid = [(x, y) for y in range(32) for x in range(32)]
    # the outside of the hull, seen below the gunwale
    for x, y in grid:
        for drop in (3, 2, 1):
            if top(x, y - drop) and not top(x, y):
                i = drop if noise(x // 3 if flat else x, y, 61) < 0.8 else min(3, drop + 1)
                f.put(x, y, BK[min(3, i)])
    for x, y in grid:
        if not top(x, y):
            continue
        if not hold(x, y):
            # gunwale and end blocks: weathered worked wood
            u, v = local(x, y)
            lit = (v < 0) if flat else (x < 15.5)
            c = WD[2] if lit else BK[1]
            if not top(x, y - 1) or not top(x - 1, y):
                c = WD[1]
            elif not top(x, y + 1):
                c = BK[1]
            elif abs(u) > half_len - 3.6 and noise(x, y, 62) > 0.7:
                c = BK[0]  # adze facets on the end blocks
            f.put(x, y, c)
            continue
        up1, up2 = not hold(x, y - 1), not hold(x, y - 2)
        u, v = local(x, y)
        c = adzed(x, y, 63)
        # fire scars: densest along the keel line, thinning to the sides
        ux, uy = (int(u + 20) // 3, int(v + 20) // 2)
        scar = noise(ux, uy, 64) + 0.2 * (1 - abs(v) / (half_wid - 1.6))
        if scar > 0.92 and noise(x, y, 66) > 0.3:
            c = CH[2] if noise(x, y, 65) > 0.5 else WD[3]
        elif scar > 0.8 and noise(x, y, 66) > 0.5:
            c = WD[2]
        if up1:
            c = WD[3]  # the inner wall under the far gunwale, in shade
        elif up2:
            c = WD[2]
        elif not hold(x - 1, y):
            c = PW[2]
        elif not hold(x, y + 1):
            c = PW[0]
        f.put(x, y, c)
    f.outline()
    return f


# ---------------------------------------------------------------- the paddle

def paddle():
    """One piece of carved wood: a knobbed grip at the lower left, a round
    shaft and a leaf-shaped blade with a faint midrib at the upper right."""
    f = Frame()
    x0, y0, x1, y1 = 4.5, 27.5, 27.0, 5.0
    dx, dy = x1 - x0, y1 - y0
    length = math.hypot(dx, dy)
    for y in range(32):
        for x in range(32):
            t = ((x - x0) * dx + (y - y0) * dy) / (length * length)
            s = ((x - x0) * -dy + (y - y0) * dx) / length  # across; negative = upper left
            if t < -0.03 or t > 1:
                continue
            if t < 0.05:
                half = 1.5                       # grip knob
            elif t < 0.56:
                half = 0.85                      # shaft
            else:
                b = (t - 0.56) / 0.44
                half = 0.85 + 3.0 * math.sin(math.pi * b ** 0.75) if b < 1 else 0
            if abs(s) > half:
                continue
            if t >= 0.56:
                c = WD[0] if s < -0.9 else WD[1] if s < 1.2 else WD[2]
                if abs(s) < 0.5 and t < 0.93:
                    c = WD[2] if s >= 0 else WD[0]  # midrib
            else:
                c = WD[1] if s < 0 else WD[2]
                if t < 0.05 and s < -0.4:
                    c = WD[0]
            f.put(x, y, c)
    f.outline()
    return f


# ---------------------------------------------------------------- the sheet

# state name -> list of frames (one per direction, in BYOND order S, N, E, W)
STATES = {
    'dugout_log0': [log(0)],
    'dugout_log0_charred': [log(0, True)],
    'dugout_log1': [log(1)],
    'dugout_log1_charred': [log(1, True)],
    'dugout_log2': [log(2)],
    'dugout_log2_charred': [log(2, True)],
    'dugout': [canoe(SOUTH), canoe(NORTH), canoe(EAST), canoe(WEST)],
    'paddle': [paddle()],
}
COLUMNS = 4
DIR_NAMES = (SOUTH, NORTH, EAST, WEST)


def write_dmi(path, states):
    frames = [fr for group in states.values() for fr in group]
    rows = -(-len(frames) // COLUMNS)
    sheet = Image.new('RGBA', (32 * COLUMNS, 32 * rows), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(fr.image(), (i % COLUMNS * 32, i // COLUMNS * 32))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, group in states.items():
        text += 'state = "%s"\n\tdirs = %d\n\tframes = 1\n' % (name, len(group))
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta)


def ground(colour, seed):
    """A flat preview floor with a little fixed speckle."""
    tile = Image.new('RGBA', (32, 32), colour + (255,))
    for y in range(32):
        for x in range(32):
            n = noise(x, y, seed)
            if n > 0.86 or n < 0.1:
                d = 9 if n > 0.5 else -9
                tile.putpixel((x, y), tuple(max(0, min(255, v + d)) for v in colour) + (255,))
    return tile


def write_preview(path, scale=4, per_row=4):
    """Each frame at 4x on water and on grass, labelled, with the 1x sprite
    on both floors underneath."""
    cell = 32 * scale
    pad, label = 10, 16
    box_w, box_h = cell * 2 + 6 + pad * 2, label + cell + 44 + pad * 2
    shots = []
    for name, group in STATES.items():
        for i, fr in enumerate(group):
            shots.append((name if len(group) == 1 else '%s (%s)' % (name, DIR_NAMES[i]), fr))
    rows = -(-len(shots) // per_row)
    sheet = Image.new('RGBA', (box_w * per_row, box_h * rows), DARK + (255,))
    draw = ImageDraw.Draw(sheet)
    floors = {'water': ground(WATER, 33), 'grass': ground(GRASS, 31)}
    for i, (name, fr) in enumerate(shots):
        ox, oy = i % per_row * box_w + pad, i // per_row * box_h + pad
        draw.text((ox, oy), name, fill=(232, 228, 214))
        for j, kind in enumerate(floors):
            tile = floors[kind].copy()
            tile.alpha_composite(fr.image())
            x = ox + j * (cell + 6)
            sheet.alpha_composite(tile.resize((cell, cell), Image.NEAREST), (x, oy + label))
            sheet.alpha_composite(tile, (x, oy + label + cell + 6))
            draw.text((x + 38, oy + label + cell + 14), kind, fill=(150, 150, 140))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    sheet.convert('RGB').save(path)


def main():
    write_dmi(ROOT / 'icons/obj/vehicles/dugout_canoe.dmi', STATES)
    if '--preview' in sys.argv[1:-1]:
        write_preview(sys.argv[sys.argv.index('--preview') + 1])


if __name__ == '__main__':
    main()
