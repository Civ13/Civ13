"""Hand-placed sprites for the charcoal clamp in
icons/obj/charcoal_clamp.dmi: the empty hearth with its centre stake, the
hearth stacked with split logs, and the earth-covered clamp smouldering (a
four-frame loop of drifting smoke and pulsing vent glow). Every pixel is
placed by this script from a fixed palette (Pillow only); no external or
generated artwork. It reuses the frame helpers and the timber, stone and fire
colours of create_clay_lime_fire.py so the clamp sits beside the lime kiln.

Run with Pillow to add or replace the three clamp states in place; every
other state in the sheet keeps its pixels, frame count and delays. `--check`
verifies the committed sheet, `--preview <png>` writes a 4x review sheet on
grass and on a dark ground, `--gif <path>` writes the burning loop.
Released under Civ13 AGPL-3.0.
"""
import math
import re
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_clay_lime_fire import Frame, TIMBER, STONE, FIRE, SOOT, OUT, grain  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/charcoal_clamp.dmi'

SIZE = 32
DELAY = 3              # deciseconds per frame of the burning loop
FRAMES = 4

# dug earth: highlight, light, mid, dark, deep
SOIL = [(158, 120, 80), (130, 96, 62), (102, 74, 48), (76, 54, 36), (52, 38, 28)]
# cut turf: lit grass, grass, shaded grass, dry thatch
TURF = [(124, 146, 76), (92, 116, 60), (66, 88, 48), (140, 128, 72)]
# bark: light, mid, dark, deep
BARK = [(132, 96, 62), (104, 72, 46), (78, 52, 34), (54, 36, 26)]
# old ash and char on the hearth floor: light, mid, dark
ASH = [(104, 98, 92), (74, 68, 64), (50, 44, 42)]
# smoke, nearest the vent first: (r, g, b, alpha)
SMOKE = [(214, 212, 206, 235), (196, 194, 190, 210), (178, 176, 174, 170),
         (164, 162, 162, 130), (150, 150, 152, 90)]

CX = 15.5              # the stake stands on the tile centre line


class Sprite(Frame):
    """A Frame whose pixels may also carry their own alpha (the smoke)."""

    def image(self):
        im = Image.new('RGBA', (self.w, self.h))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c if len(c) == 4 else c + (255,))
        return im


def hearth(f):
    """A shallow round pit: a raised ring of spoil round a charred floor."""
    def ring(x, y, nx, ny):
        c = SOIL[2]
        if ny < -0.55:
            c = SOIL[1]
        if ny > 0.6:
            c = SOIL[3]
        g = grain(x, y, 41)
        if g == 0:
            c = SOIL[0] if ny < 0.2 else SOIL[1]
        elif g == 1:
            c = SOIL[3]
        return c
    f.ellipse(CX, 23.5, 13, 5, ring)

    def floor(x, y, nx, ny):
        if ny < -0.45:
            return SOIL[4]             # the far wall of the pit, in shadow
        g = grain(x, y, 43)
        if g == 0:
            return ASH[0]
        return ASH[1] if g < 5 else ASH[2]
    f.ellipse(CX, 23.5, 9.5, 3, floor)


def rim_dressing(f):
    """Field stones and cut turves left round the rim."""
    for x, y in ((4, 24), (25, 21), (21, 27)):
        f.pts(STONE[1], (x, y), (x + 1, y))
        f.pts(STONE[3], (x, y + 1), (x + 1, y + 1))
        f.put(x, y, STONE[0])
    for x, y in ((8, 20), (26, 25), (10, 27)):
        f.pts(TURF[1], (x, y), (x + 1, y), (x + 2, y))
        f.put(x, y, TURF[0])
        f.pts(TURF[2], (x + 1, y + 1), (x + 2, y + 1))


def stake(f, top, foot):
    """The centre stake the logs lean on; drawn out, it leaves the flue."""
    f.vline(15, top, foot, TIMBER[1])
    f.vline(16, top, foot, TIMBER[3])
    f.put(15, top, TIMBER[0])
    f.put(16, top, TIMBER[1])
    for y in range(top + 3, foot, 4):
        f.put(15, y, TIMBER[2])


def log(f, bx, foot, tx, top, seed):
    """One split log, three pixels wide, leaning from its foot to its top,
    with the pale cut end showing at the top."""
    for y in range(top, foot + 1):
        t = (foot - y) / max(1, foot - top)
        x = int(round(bx + (tx - bx) * t))
        left, mid, right = BARK[0], BARK[1], BARK[3]
        if grain(seed, y, 47) < 2:
            mid = BARK[2]                  # a furrow in the bark
        if y == top:
            left, mid, right = TIMBER[0], TIMBER[0], TIMBER[1]    # cut end
        elif y == top + 1:
            left, mid, right = TIMBER[0], TIMBER[2], TIMBER[3]    # its heart
        f.put(x - 1, y, left)
        f.put(x, y, mid)
        f.put(x + 1, y, right)
        if y == foot:
            f.put(x - 1, y, BARK[2])
            f.put(x, y, BARK[3])
            f.put(x + 1, y, BARK[3])


def clamp_empty():
    """The built hearth, waiting for wood."""
    f = Sprite()
    hearth(f)
    rim_dressing(f)
    stake(f, 7, 24)
    f.pts(ASH[2], (14, 25), (15, 25), (16, 25), (17, 25))     # its shadow
    f.outline()
    return f


def clamp_loaded():
    """Split logs stood on end round the stake in two leaning tiers."""
    f = Sprite()
    hearth(f)
    rim_dressing(f)
    stake(f, 4, 12)
    # upper tier, behind: outer logs first so the middle ones overlap them
    # (tops are uneven, as split wood is, so the pale cut ends show)
    for bx, tx, cut in ((10, 13, 1), (21, 18, 0), (13, 14, 0), (18, 17, 2), (15.5, 15.5, 0)):
        log(f, bx, 17, tx, 7 + cut + int(abs(bx - CX) / 3), seed=int(bx))
    # lower tier, in front
    for bx, tx, cut in ((5, 9, 0), (26, 22, 1), (8, 11, 2), (23, 20, 0), (11, 13, 0), (20, 18, 2),
                        (14, 14.6, 2), (17, 16.6, 0)):
        log(f, bx, 26 - int(abs(bx - CX) / 5), tx, 14 + cut + int(abs(bx - CX) / 3), seed=int(bx) + 20)
    f.outline()
    return f


def dome_half(y):
    """Half width of the covered clamp at row y (rows 9 to 27)."""
    t = (y - 9) / 18.0
    return 3.0 + 10.0 * math.sqrt(max(0.0, 1.0 - (1.0 - t) ** 2.0))


def clamp_burning(step):
    """The clamp covered in earth and turf, smouldering: two vents near the
    foot glow and the flue at the crown smokes."""
    f = Sprite()
    k = step % FRAMES
    for y in range(9, 28):
        half = dome_half(y)
        for x in range(int(math.ceil(CX - half)), int(CX + half) + 1):
            nx = (x - CX) / half
            ny = (y - 9) / 18.0
            light = nx * 0.75 + ny * 0.55          # lit from the upper left
            if light < -0.25:
                c = SOIL[1]
            elif light < 0.55:
                c = SOIL[2]
            elif light < 0.95:
                c = SOIL[3]
            else:
                c = SOIL[4]
            g = grain(x, y, 51)
            if g == 0 and light < 0.55:
                c = SOIL[0]
            elif g == 1:
                c = SOIL[3] if light < 0.55 else SOIL[4]
            # turves laid like tiles: broken green bands across the dome
            band = (y + int(2 * nx * nx)) % 5
            if abs(nx) > 0.8:
                pass                               # bare earth at the skirts
            elif band == 0 and grain(x // 3, y // 5, 53) < 6:
                c = TURF[0] if light < -0.1 else (TURF[1] if light < 0.6 else TURF[2])
            elif band == 1 and grain(x // 3, (y - 1) // 5, 53) < 6 and grain(x, y, 55) < 4:
                c = TURF[3] if light < 0.4 else TURF[2]
            f.put(x, y, c)
    # loose spoil banked round the foot
    for x in range(2, 30):
        if grain(x, 28, 57) < 8:
            f.put(x, 28, SOIL[3] if x > 16 else SOIL[2])
    f.pts(SOIL[1], (3, 27), (4, 27), (27, 27))
    f.pts(STONE[1], (5, 28), (25, 28))
    # the flue where the stake was drawn out
    f.hline(14, 17, 9, SOIL[1])
    f.hline(15, 16, 9, SOOT)
    f.hline(15, 16, 10, SOOT)
    f.put(14, 10, SOIL[3])
    f.put(17, 10, SOIL[4])
    # two vents poked through the cover near the foot; the glow breathes
    pulse = (0, 1, 2, 1)[k]
    for vx, vy, flip in ((9, 23, 0), (20, 24, 1)):
        f.hline(vx - 1, vx + 2, vy - 1, SOIL[4])
        f.put(vx - 1, vy, SOOT)
        f.put(vx + 2, vy, SOOT)
        f.hline(vx - 1, vx + 2, vy + 1, SOIL[4])
        hot = (FIRE[3], FIRE[2], FIRE[1])[pulse]
        dim = (FIRE[3], FIRE[3], FIRE[2])[pulse]
        f.put(vx + flip, vy, hot)
        f.put(vx + 1 - flip, vy, dim)
        if pulse == 2:
            f.put(vx + flip, vy + 1, FIRE[3])      # a little light on the lip
    f.outline()
    # a thin wisp from the flue, drawn over the outline: each puff climbs one
    # step a frame along a curl that repeats every four steps, so frame 4
    # runs straight back into frame 0
    for i in range(8):
        y = 8 - i
        sway = math.sin((i - k) * math.pi / 2.0)
        x = 15 + int(round(i * 0.45 + sway * min(1.5, 0.4 + i * 0.25)))
        tone = SMOKE[min(len(SMOKE) - 1, i * len(SMOKE) // 8 + (1 if (i + k) % 4 == 3 else 0))]
        f.put(x, y, tone)
        if (i + k) % 2 == 0 and 0 < i < 7:
            f.put(x + 1, y, SMOKE[min(len(SMOKE) - 1, tone and SMOKE.index(tone) + 1)])
    return f


def states():
    """[(state, frames, delay)] this script owns, in sheet order."""
    return [
        ('charcoal_clamp', [clamp_empty()], 0),
        ('charcoal_clamp_loaded', [clamp_loaded()], 0),
        ('charcoal_clamp_on', [clamp_burning(i) for i in range(FRAMES)], DELAY),
    ]


# --------------------------------------------------------- sheet in/out --

def read_sheet(path=SHEET):
    """[(name, block, [frame images])] for every state in the sheet; block
    is the state's metadata lines exactly as they stand."""
    if not path.exists():
        return []
    im = Image.open(path)
    text = im.info['Description']
    im = im.convert('RGBA')
    assert '\twidth = 32\n\theight = 32\n' in text, 'not a 32x32 sheet'
    cols = im.width // SIZE
    out, at = [], 0
    for block in re.split(r'(?m)^(?=state = )', text.split('# END DMI')[0])[1:]:
        name = re.match(r'state = "([^"]*)"', block).group(1)
        dirs = int(re.search(r'\tdirs = (\d+)', block).group(1))
        count = int(re.search(r'\tframes = (\d+)', block).group(1)) * dirs
        frames = []
        for i in range(at, at + count):
            x, y = (i % cols) * SIZE, (i // cols) * SIZE
            frames.append(im.crop((x, y, x + SIZE, y + SIZE)))
        at += count
        out.append((name, block, frames))
    return out


def build():
    """The whole sheet with the clamp states replaced or appended."""
    mine = {}
    for name, frs, delay in states():
        block = 'state = "%s"\n\tdirs = 1\n\tframes = %d\n' % (name, len(frs))
        if len(frs) > 1:
            block += '\tdelay = %s\n' % ','.join([str(delay)] * len(frs))
        mine[name] = (name, block, [fr.image() for fr in frs])
    sheet = [mine.pop(name, entry) if name in mine else entry
             for entry in read_sheet() for name in (entry[0],)]
    sheet += list(mine.values())
    frames = [fr for _, _, frs in sheet for fr in frs]
    cols = int(len(frames) ** 0.5 + 0.999)
    rows = (len(frames) + cols - 1) // cols
    im = Image.new('RGBA', (cols * SIZE, rows * SIZE))
    for i, fr in enumerate(frames):
        im.paste(fr, ((i % cols) * SIZE, (i // cols) * SIZE))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    text += ''.join(block for _, block, _ in sheet) + '# END DMI\n'
    return im, text


def write_dmi():
    im, text = build()
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    im.save(SHEET, 'PNG', pnginfo=meta, optimize=True)


def check():
    im, text = build()
    old = Image.open(SHEET)
    return old.info.get('Description') == text and old.convert('RGBA').tobytes() == im.tobytes()


# -------------------------------------------------------------- review --

GRASS = (98, 122, 78, 255)
DARK = (30, 34, 44, 255)


def preview(path, scale=4):
    """Every frame of the three states on grass (left) and dark (right)."""
    frames = [fr.image() for _, frs, _ in states() for fr in frs]
    pad = 6
    cell = SIZE * scale + pad
    out = Image.new('RGBA', (pad + len(frames) * cell, pad + 2 * cell), (24, 24, 24, 255))
    for j, bg in enumerate((GRASS, DARK)):
        for i, fr in enumerate(frames):
            tile = Image.new('RGBA', (SIZE * scale, SIZE * scale), bg)
            tile.alpha_composite(fr.resize((SIZE * scale, SIZE * scale), Image.NEAREST))
            out.paste(tile, (pad + i * cell, pad + j * cell))
    out.save(path)


def gif(path, scale=6):
    """The burning loop on grass and dark, side by side, at game speed."""
    shots = []
    for fr in dict((n, f) for n, f, _ in states())['charcoal_clamp_on']:
        shot = Image.new('RGBA', (2 * SIZE * scale, SIZE * scale))
        for j, bg in enumerate((GRASS, DARK)):
            tile = Image.new('RGBA', (SIZE * scale, SIZE * scale), bg)
            tile.alpha_composite(fr.image().resize((SIZE * scale, SIZE * scale), Image.NEAREST))
            shot.paste(tile, (j * SIZE * scale, 0))
        shots.append(shot.convert('RGB'))
    shots[0].save(path, save_all=True, append_images=shots[1:], duration=DELAY * 100, loop=0)


if __name__ == '__main__':
    if '--check' in sys.argv:
        if not check():
            sys.exit('stale sheet: ' + str(SHEET))
        print('charcoal clamp states match')
    else:
        write_dmi()
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
    if '--gif' in sys.argv:
        gif(sys.argv[sys.argv.index('--gif') + 1])
