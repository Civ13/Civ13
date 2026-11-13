"""The smoke-signal plume that rises over a campfire: one looping 32x96 state,
"signal_plume", of separate rounded puffs climbing a column. Every pixel is
placed by this script from a fixed grey palette (Pillow only); no external or
generated artwork.

The icon's bottom edge is the fire's tile, so the object needs no pixel
offset: the puffs start just above the flames and fade out near the top.
Each frame lifts every puff by RISE pixels and a puff is SPACING pixels below
the next, so FRAMES * RISE == SPACING closes the loop exactly.

Run with Pillow to reproduce icons/effects/signal_smoke.dmi. `--preview <png>`
also writes an enlarged review sheet (every frame on grass, snow and sand, and
the plume over the lit campfire). Released under Civ13 AGPL-3.0.
"""
import math
import re
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]

W, H = 32, 96
FRAMES = 12
DELAY = 1.2            # deciseconds per frame
RISE = 2               # pixels a puff climbs per frame
SPACING = FRAMES * RISE
BASE = 19              # height above the tile's bottom edge where smoke leaves the flames
TOP = 93               # puff centres never climb past this
FADE_IN = 8.0          # climb over which a new puff thickens
FADE_OUT = 30.0        # climb over which an old puff thins away

# smoke: highlight, light, mid, shade, rim. The rim is dark enough to hold the
# shape on snow and sand, the highlight light enough to show on grass.
SMOKE = [(244, 244, 240), (214, 215, 214), (176, 178, 181), (136, 139, 145), (92, 95, 103)]
# opacity steps a puff passes through, thinnest first
ALPHAS = [0, 56, 96, 136, 176, 208]

# A puff is a clump of round lobes: (dx, dy, radius) around its centre, as
# fractions of the puff's size. dy is upward.
LOBES = [(0.0, -0.10, 0.74), (-0.52, -0.02, 0.50), (0.54, 0.02, 0.48),
         (-0.22, 0.42, 0.52), (0.30, 0.40, 0.46)]


def puff_strength(climb, span):
    """0..1: thin when it leaves the fire, full in the middle, gone at the top."""
    return max(0.0, min(1.0, climb / FADE_IN, (span - climb) / FADE_OUT))


def draw_puff(px, climb, span):
    """Stamp one puff that has climbed `climb` pixels above the flames."""
    strength = puff_strength(climb, span)
    alpha = ALPHAS[int(round(strength * (len(ALPHAS) - 1)))]
    if not alpha:
        return
    size = 4.5 + 5.0 * min(1.0, climb / 46.0)                 # puffs swell as they rise
    cx = 15.5 + 2.6 * math.sin(climb / 15.0) + climb * 0.02   # and wander a little
    cy = BASE + climb                                         # height above the bottom edge
    inside = {}
    reach = int(size * 1.4) + 2
    for y in range(int(cy) - reach, int(cy) + reach + 1):
        for x in range(int(cx) - reach, int(cx) + reach + 1):
            if not (0 <= x < W and 0 <= y < H):
                continue
            best = None
            for lx, ly, lr in LOBES:
                ox, oy, r = cx + lx * size, cy + ly * size, lr * size
                d = math.hypot(x + 0.5 - ox, y + 0.5 - oy) / r
                if d <= 1.0:
                    # light falls from the upper left of each lobe
                    lit = ((ox - x - 0.5) * 0.55 + (y + 0.5 - oy) * 0.85) / r
                    if best is None or lit > best:
                        best = lit
            if best is not None:
                inside[(x, y)] = best
    for (x, y), lit in inside.items():
        edge = any(n not in inside for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))
        if edge:
            c = SMOKE[4] if lit < 0.35 else SMOKE[3]
        elif lit > 0.55:
            c = SMOKE[0]
        elif lit > 0.15:
            c = SMOKE[1]
        elif lit > -0.30:
            c = SMOKE[2]
        else:
            c = SMOKE[3]
        px[(x, y)] = c + (alpha,)


def frame(i):
    """Frame i of the loop, as an RGBA image."""
    px = {}
    span = TOP - BASE
    climb = (i * RISE) % SPACING
    climbs = []
    while climb <= span:
        climbs.append(climb)
        climb += SPACING
    for climb in reversed(climbs):        # lower, denser puffs are drawn over the thin ones
        draw_puff(px, climb, span)
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    for (x, y), c in px.items():
        im.putpixel((x, H - 1 - y), c)
    return im


def frames():
    return [frame(i) for i in range(FRAMES)]


def write_dmi(path, fr):
    sheet = Image.new('RGBA', (W * len(fr), H), (0, 0, 0, 0))
    for i, im in enumerate(fr):
        sheet.paste(im, (i * W, 0))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = %d\n\theight = %d\n' % (W, H)
    text += 'state = "signal_plume"\n\tdirs = 1\n\tframes = %d\n\tdelay = %s\n' % (
        len(fr), ','.join('%g' % DELAY for _ in fr))
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta)


def dmi_frames(path, state):
    """The frames of one state of an existing 32px sheet (first direction)."""
    im = Image.open(path).convert('RGBA')
    text = im.info.get('Description') or Image.open(path).info['Description']
    index = 0
    for name, dirs, count in re.findall(r'state = "(.*)"\n\tdirs = (\d+)\n\tframes = (\d+)', text):
        dirs, count = int(dirs), int(count)
        if name == state:
            out = []
            for f in range(count):
                n = index + f * dirs
                x, y = (n % (im.width // 32)) * 32, (n // (im.width // 32)) * 32
                out.append(im.crop((x, y, x + 32, y + 32)))
            return out
        index += dirs * count
    raise KeyError(state)


def ground(colour, speck):
    """A plain three-tile-high strip of ground with a few darker specks."""
    tile = Image.new('RGBA', (W, H), colour + (255,))
    for n in range(40):
        tile.putpixel(((n * 37 + 5) % W, (n * 53 + 11) % H), speck + (255,))
    return tile


def preview(path, fr, scale=4):
    grounds = [((94, 132, 62), (78, 114, 52)),        # grass
               ((236, 240, 246), (214, 222, 234)),    # snow
               ((218, 196, 140), (198, 174, 120))]    # sand
    fire = dmi_frames(ROOT / 'icons/obj/kitchen.dmi', 'fireplace_on')
    cols = len(fr) + 1
    gap = 2
    sheet = Image.new('RGBA', ((W + gap) * cols * scale, (H + gap) * len(grounds) * scale), (40, 40, 44, 255))
    for r, (colour, speck) in enumerate(grounds):
        for c in range(cols):
            tile = ground(colour, speck)
            if c:                                     # in context: over the lit campfire
                tile.alpha_composite(fire[(c - 1) % len(fire)], (0, H - 32))
            tile.alpha_composite(fr[(c - 1) % len(fr)] if c else fr[0])
            big = tile.resize((W * scale, H * scale), Image.NEAREST)
            sheet.paste(big, (c * (W + gap) * scale, r * (H + gap) * scale))
    sheet.save(path)


if __name__ == '__main__':
    fr = frames()
    write_dmi(ROOT / 'icons/effects/signal_smoke.dmi', fr)
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1], fr)
