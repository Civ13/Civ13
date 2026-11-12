#!/usr/bin/env python3
"""Draws icons/obj/vehicles/submarine_hull.dmi: the roof, deck and fittings of
the Scout (3x5) and Explorer (3x7) submarines.

Every pixel is placed by the plain drawing code below from a fixed palette
(Pillow only; no image generation, no borrowed art). Each boat is drawn
whole with its bow up, then cut into 32x32 tiles. A tile's state is named
"<class>_<column>_<row>_roof" or "..._deck" after its place in the DM layout
table (submarine_layouts in ships/submarine.dm: column 1 is the west side of
a boat facing south, row 1 its bow) and holds the four directions the boat
can face. A roof tile the accent stripe crosses also gets a "..._stripe"
state: the stripe alone in white, which the game tints to the colour the crew
painted and lays over the roof.

Usage: python3 scripts/draw_submarine_hull.py [--preview out.png]
"""
import math, sys, os
from PIL import Image, ImageDraw, ImageFilter
from PIL.PngImagePlugin import PngInfo

T = 32
# ---- palette (few flat shades, pixel-art banding) ----
OUT = (16, 20, 26, 255)
H1 = (112, 128, 140, 255)   # hull top highlight
H2 = (84, 99, 112, 255)
H3 = (60, 72, 84, 255)
H4 = (40, 49, 59, 255)
SEAM = (48, 58, 68, 255)
RIV = (136, 150, 160, 255)
ACC = (232, 150, 40, 255)   # accent stripe: the factory colour, repainted in game
ACC2 = (178, 104, 24, 255)
G1 = (188, 240, 244, 255)   # glass
G2 = (110, 200, 214, 255)
G3 = (58, 146, 170, 255)
G4 = (34, 98, 124, 255)
YEL = (240, 208, 64, 255)
BRZ = (176, 132, 60, 255)
BRZ2 = (120, 86, 36, 255)
D1 = (150, 156, 160, 255)   # deck
D2 = (128, 134, 140, 255)
D3 = (100, 106, 114, 255)
W1 = (74, 86, 98, 255)      # interior hull wall
W2 = (46, 55, 66, 255)
W3 = (104, 118, 130, 255)


def half_width(y, W, L, bow=30, stern=52, tail=7, inset=0):
    """Half width of the hull at pixel row y: round bow, parallel body, tapered stern."""
    full = W * T / 2 - inset
    h = L * T
    if y < bow:
        t = (bow - y - 0.5) / bow
        return full * math.sqrt(max(0.0, 1 - t * t))
    if y >= h - stern:
        t = (y - (h - stern)) / stern
        s = t * t * (3 - 2 * t)  # smoothstep
        return full + (tail - full) * s
    return full


def hull_mask(W, L, **kw):
    im = Image.new('L', (W * T, L * T), 0)
    px = im.load()
    cx = W * T / 2
    for y in range(L * T - 3):
        hw = half_width(y, W, L, **kw)
        for x in range(W * T):
            if abs(x + 0.5 - cx) <= hw:
                px[x, y] = 255
    return im


def erode(mask, n):
    # pad first: the hull reaches the edge of the drawing, which must count as outside
    big = Image.new('L', (mask.width + 2 * n, mask.height + 2 * n), 0)
    big.paste(mask, (n, n))
    big = big.filter(ImageFilter.MinFilter(2 * n + 1))
    return big.crop((n, n, n + mask.width, n + mask.height))


def exterior(W, L, sail_row=None, lock_row=None, canopy=1.0, tanks=None, planes=True, pods=False, **kw):
    """Roof art: what people outside the boat see."""
    w, h = W * T, L * T
    cx = w / 2
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    px = im.load()
    mask = hull_mask(W, L, **kw)
    mp = mask.load()
    inner = erode(mask, 1).load()
    for y in range(h):
        hw = half_width(y, W, L, **kw)
        for x in range(w):
            if not mp[x, y]:
                continue
            if not inner[x, y]:
                px[x, y] = OUT
                continue
            u = abs(x + 0.5 - cx) / max(hw, 1)
            # light comes from the port bow: shift the highlight a little left
            v = (x + 0.5 - cx) / max(hw, 1) + 0.18
            c = H1 if abs(v) < 0.22 else H2 if abs(v) < 0.55 else H3 if u < 0.86 else H4
            px[x, y] = c
    d = ImageDraw.Draw(im)
    # plate seams with rivets
    for y in range(30, h - 40, 32):
        for x in range(w):
            if inner[x, y] and px[x, y] != OUT:
                px[x, y] = SEAM
                if x % 4 == 1 and inner[x, y + 1]:
                    px[x, y + 1] = RIV
    # saddle ballast tanks along the sides
    if tanks:
        y0, y1 = tanks
        for y in range(y0, y1):
            hw = half_width(y, W, L, **kw)
            for side in (-1, 1):
                for k in range(2, 9):
                    x = int(cx + side * (hw - k) - (0 if side > 0 else 1))
                    if 0 <= x < w and inner[x, y]:
                        px[x, y] = H4 if k < 7 else SEAM
                if (y - y0) % 8 in (3, 4) and y0 + 4 < y < y1 - 4:   # flood slots
                    for k in (4, 5):
                        x = int(cx + side * (hw - k) - (0 if side > 0 else 1))
                        px[x, y] = OUT
    # accent stripes
    for ys in ((int(34 * canopy) + 6, h - 62) if L > 2 else (h - 34,)):
        for y in range(ys, ys + 3):
            for x in range(w):
                if inner[x, y]:
                    px[x, y] = ACC if y < ys + 2 else ACC2
    # glass canopy on the bow
    ry = 19 * canopy
    cyy = 5 + ry
    rx = (W * T / 2 - 2) * 0.72
    for y in range(h):
        for x in range(w):
            if not inner[x, y]:
                continue
            ex = (x + 0.5 - cx) / rx
            ey = (y + 0.5 - cyy) / ry
            r = ex * ex + ey * ey
            if r <= 1:
                if r > 0.80:
                    px[x, y] = OUT
                else:
                    q = ex * 0.6 + ey * 0.8          # shade toward the stern-right
                    px[x, y] = G1 if q < -0.45 else G2 if q < -0.05 else G3 if q < 0.4 else G4
    # canopy ribs
    for x in (int(cx - rx * 0.33), int(cx + rx * 0.33) - 1):
        for y in range(int(cyy - ry), int(cyy + ry)):
            if px[x, y] in (G1, G2, G3, G4):
                px[x, y] = H4
    for dx in range(-2, 4):       # glint
        xx, yy = int(cx - rx * 0.52) + dx, int(cyy - ry * 0.30) - dx
        if px[xx, yy] in (G1, G2, G3):
            px[xx, yy] = (255, 255, 255, 255)
    # floodlights on the bow shoulders
    yl = int(cyy + ry) - 2
    for side in (-1, 1):
        xl = int(cx + side * (half_width(yl, W, L, **kw) - 6))
        d.rectangle([xl - 2, yl - 2, xl + 2, yl + 2], fill=OUT)
        d.rectangle([xl - 1, yl - 1, xl + 1, yl + 1], fill=YEL)
        px[xl, yl - 1] = (255, 250, 200, 255)
    # sail (conning tower) with its hatch and periscope
    if sail_row is not None:
        sy = int(sail_row * T)
        sw, sh = 13, 22
        d.rounded_rectangle([cx - sw + 2, sy - sh + 3, cx + sw + 1, sy + sh + 3], 9, fill=H4)       # shadow
        d.rounded_rectangle([cx - sw, sy - sh, cx + sw - 1, sy + sh], 9, fill=H2, outline=OUT)
        d.rounded_rectangle([cx - sw + 2, sy - sh + 2, cx + sw - 6, sy + sh - 6], 7, fill=H1)
        d.ellipse([cx - 7, sy - 4, cx + 6, sy + 9], fill=H3, outline=OUT)        # hatch
        d.line([cx - 4, sy + 2, cx + 3, sy + 2], fill=RIV)
        d.line([cx - 1, sy - 1, cx - 1, sy + 6], fill=RIV)
        d.ellipse([cx - 3, sy - 15, cx + 2, sy - 10], fill=OUT)                  # periscope
        d.point([cx - 1, sy - 13], fill=G2)
        d.rectangle([cx + 5, sy - 16, cx + 6, sy - 9], fill=OUT)                 # snorkel / mast
    # lock-out hatches on both sides of the hull, ringed in yellow
    if lock_row is not None:
        ly = int(lock_row * T)
        for lock_side in (-1, 1):
            lx = int(cx + lock_side * (W * T / 2 - 13)) - (1 if lock_side > 0 else 0)
            d.ellipse([lx - 7, ly - 7, lx + 7, ly + 7], fill=YEL, outline=OUT)
            d.ellipse([lx - 5, ly - 5, lx + 5, ly + 5], fill=H3, outline=OUT)
            d.line([lx - 2, ly, lx + 2, ly], fill=RIV)
            d.line([lx, ly - 2, lx, ly + 2], fill=RIV)
    # stern planes, rudder and screw
    ty = h - 22
    if planes:
        for side in (-1, 1):
            pts = [(cx + side * 6, ty - 8), (cx + side * (w / 2 - 6), ty - 2), (cx + side * (w / 2 - 6), ty + 6), (cx + side * 6, ty + 5)]
            d.polygon(pts, fill=H3, outline=OUT)
            d.line([cx + side * 9, ty - 4, cx + side * (w / 2 - 9), ty + 1], fill=H2)
        d.rectangle([cx - 1, h - 46, cx, h - 12], fill=OUT)                         # rudder ridge
    if pods:                                                                        # twin thruster pods
        for side in (-1, 1):
            x0 = cx + side * (w / 2 - 9)
            d.rounded_rectangle([x0 - 4, h - 30, x0 + 3, h - 8], 3, fill=H3, outline=OUT)
            d.line([x0 - 2, h - 27, x0 - 2, h - 12], fill=H1)
            d.rectangle([x0 - 3, h - 8, x0 + 2, h - 6], fill=BRZ, outline=OUT)
            d.rectangle([x0 - 4, h - 20, x0 + 3, h - 19], fill=ACC)
    d.ellipse([cx - 9, h - 13, cx + 8, h - 1], fill=OUT)                         # screw guard
    d.ellipse([cx - 7, h - 11, cx + 6, h - 3], fill=BRZ2)
    d.line([cx - 6, h - 7, cx + 5, h - 7], fill=BRZ)
    d.line([cx - 1, h - 10, cx - 1, h - 4], fill=BRZ)
    return im


def deck_fill(im, mask_inner):
    px = im.load()
    w, h = im.size
    mi = mask_inner.load()
    for y in range(h):
        for x in range(w):
            if mi[x, y]:
                c = D1
                if x % 16 == 0 or y % 16 == 0:
                    c = D3
                elif x % 16 == 1 or y % 16 == 1:
                    c = D2
                px[x, y] = c


def interior(W, L, spec, **kw):
    """Deck plan with the roof off: what the crew see. spec describes the rooms."""
    w, h = W * T, L * T
    cx = w / 2
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    px = im.load()
    mask = hull_mask(W, L, **kw)
    wall_in = erode(mask, 5)
    mp, wi = mask.load(), wall_in.load()
    edge = erode(mask, 1).load()
    deck_fill(im, wall_in)
    for y in range(h):
        for x in range(w):
            if mp[x, y] and not wi[x, y]:
                px[x, y] = OUT if not edge[x, y] else W1
    # inner lip of the hull wall
    lip = erode(mask, 4).load()
    for y in range(h):
        for x in range(w):
            if lip[x, y] and not wi[x, y]:
                px[x, y] = W2
    d = ImageDraw.Draw(im)
    # centre walkway grating
    for (r0, r1) in spec.get('walk', []):
        for y in range(int(r0 * T), int(r1 * T)):
            for x in range(int(cx) - 6, int(cx) + 6):
                if wi[x, y]:
                    px[x, y] = D3 if (x + y) % 2 else D2
    # glass nose: the bow wall becomes window panes
    gy = int(spec.get('glass', 0) * T)
    for y in range(gy):
        for x in range(w):
            if mp[x, y] and not wi[x, y] and edge[x, y]:
                px[x, y] = G2 if (x // 8) % 2 == 0 else G3
            if mp[x, y] and not wi[x, y] and edge[x, y] and x % 12 == 5:
                px[x, y] = H4
    # lock-out chambers: a flooded-floor grate and a yellow outer hatch in the hull
    for (col, row) in spec.get('locks', []):
        x0, y0 = col * T, row * T
        for y in range(y0, y0 + T):
            for x in range(x0, x0 + T):
                if wi[x, y]:
                    px[x, y] = G4 if (x + y) % 4 == 0 else (70, 92, 108, 255)
        for y in range(y0 + 8, y0 + 24):
            for x in (range(x0, x0 + 7) if col == 0 else range(x0 + T - 7, x0 + T)):
                if mp[x, y] and not wi[x, y] and edge[x, y]:
                    px[x, y] = YEL if (y // 3) % 2 == 0 else OUT
    # sealed tank spaces in the stern quarters: dark plating nobody walks on
    for (col, row) in spec.get('sealed', []):
        x0, y0 = col * T, row * T
        for y in range(y0, y0 + T):
            for x in range(x0, x0 + T):
                if wi[x, y]:
                    px[x, y] = W2 if (x + y) % 6 == 0 else H4
    return im


def stripe_layer(roof):
    """The accent stripes of a roof drawing on their own, in white for tinting."""
    im = Image.new('RGBA', roof.size, (0, 0, 0, 0))
    src, dst = roof.load(), im.load()
    for y in range(roof.height):
        for x in range(roof.width):
            if src[x, y] == ACC:
                dst[x, y] = (255, 255, 255, 255)
            elif src[x, y] == ACC2:
                dst[x, y] = (196, 196, 196, 255)
    return im


# ---- fittings ----
def prop_battery():
    im = Image.new('RGBA', (T, T), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.rectangle([3, 6, 28, 27], fill=(52, 58, 66, 255), outline=OUT)
    for i in range(3):
        x = 5 + i * 8
        d.rectangle([x, 9, x + 5, 24], fill=(34, 110, 70, 255), outline=OUT)
        d.rectangle([x + 1, 10, x + 4, 12], fill=(120, 230, 140, 255))
        d.rectangle([x + 2, 7, x + 3, 8], fill=BRZ)
    return im


def prop_airbank():
    im = Image.new('RGBA', (T, T), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    for i in range(3):
        x = 3 + i * 9
        d.rounded_rectangle([x, 5, x + 7, 28], 3, fill=(170, 176, 182, 255), outline=OUT)
        d.line([x + 2, 8, x + 2, 25], fill=(230, 236, 240, 255))
        d.rectangle([x + 2, 3, x + 5, 5], fill=BRZ, outline=OUT)
        d.line([x + 1, 16, x + 6, 16], fill=(60, 150, 210, 255))
    return im



def edge_strip(kind):
    """A bulkhead along the top (north) edge of a tile, or its watertight door."""
    im = Image.new('RGBA', (T, T), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.rectangle([0, 0, T - 1, 3], fill=W1)
    d.line([0, 0, T - 1, 0], fill=W2); d.line([0, 3, T - 1, 3], fill=W2)
    if kind == 'door_closed':
        d.rectangle([8, 0, 23, 5], fill=OUT)
        d.rectangle([9, 1, 22, 4], fill=ACC)
        d.line([9, 4, 22, 4], fill=ACC2)
        d.rectangle([15, 2, 16, 3], fill=OUT)            # locking wheel
    elif kind == 'door_open':
        d.rectangle([8, 0, 23, 3], fill=(0, 0, 0, 0))   # the doorway
        d.rectangle([7, 0, 8, 4], fill=OUT); d.rectangle([23, 0, 24, 4], fill=OUT)
        d.rectangle([9, 4, 10, 16], fill=ACC, outline=None)   # the door swung into the room
        d.line([11, 4, 11, 16], fill=ACC2)
        d.point([10, 16], fill=OUT)
    return im


def plain(kind):
    im = Image.new('RGBA', (T, T), (0, 0, 0, 0)); px = im.load()
    for y in range(T):
        for x in range(T):
            if kind == 'deck':
                px[x, y] = D3 if (x % 16 == 0 or y % 16 == 0) else D1
            else:
                px[x, y] = SEAM if y == 30 else H2 if (x + y) % 16 else H3
    return im


BIG = dict(stern=42, tail=13)
BOATS = {
    'scout': dict(W=3, L=5,
                  ext=dict(sail_row=2.1, lock_row=2.5, tanks=(60, 104)),
                  deck=dict(glass=1.0, locks=[(0, 2), (2, 2)], sealed=[(0, 4), (2, 4)], walk=[(1, 4.0)])),
    'explorer': dict(W=3, L=7,
                     ext=dict(sail_row=2.3, lock_row=3.5, tanks=(70, 150)),
                     deck=dict(glass=1.0, locks=[(0, 3), (2, 3)], sealed=[(0, 6), (2, 6)], walk=[(1, 6.0)])),
}


def boat_art(name):
    b = BOATS[name]
    return exterior(b['W'], b['L'], **b['ext'], **BIG), interior(b['W'], b['L'], b['deck'], **BIG)


def four_dirs(north):
    """BYOND direction order: south, north, east, west. The art is drawn facing north."""
    return [north.rotate(180), north, north.rotate(-90), north.rotate(90)]


def build_states():
    states = []   # (name, [frames])
    for kind in ('deck', 'roof'):
        states.append((f'plain_{kind}', [plain(kind)]))
    for name, b in BOATS.items():
        roof, deck = boat_art(name)
        stripe = stripe_layer(roof)
        for r in range(1, b['L'] + 1):
            for c in range(1, b['W'] + 1):
                box = ((b['W'] - c) * T, (r - 1) * T, (b['W'] - c + 1) * T, r * T)
                states.append((f'{name}_{c}_{r}_deck', four_dirs(deck.crop(box))))
                states.append((f'{name}_{c}_{r}_roof', four_dirs(roof.crop(box))))
                if stripe.crop(box).getbbox():
                    states.append((f'{name}_{c}_{r}_stripe', four_dirs(stripe.crop(box))))
    for kind in ('bulkhead', 'door_closed', 'door_open'):
        north = edge_strip(kind)
        # the direction of these states is the tile edge the wall stands on
        states.append((f'sub_{kind}', four_dirs(north)))
    states.append(('battery_bank', [prop_battery()]))
    states.append(('air_bank', [prop_airbank()]))
    return states


def write_dmi(states, path, cols=16):
    n = sum(len(f) for _, f in states)
    rows = (n + cols - 1) // cols
    sheet = Image.new('RGBA', (cols * T, rows * T), (0, 0, 0, 0))
    desc = ['# BEGIN DMI', 'version = 4.0', f'\twidth = {T}', f'\theight = {T}']
    i = 0
    for name, frames in states:
        desc += [f'state = "{name}"', f'\tdirs = {len(frames)}', '\tframes = 1']
        for f in frames:
            sheet.paste(f, ((i % cols) * T, (i // cols) * T)); i += 1
    desc.append('# END DMI')
    info = PngInfo(); info.add_text('Description', '\n'.join(desc) + '\n', zip=True)
    sheet.save(path, format='PNG', pnginfo=info, optimize=True)


if __name__ == '__main__':
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    states = build_states()
    if '--preview' in sys.argv:
        out = sys.argv[sys.argv.index('--preview') + 1]
        arts = [a for n in BOATS for a in boat_art(n)]
        w = sum(a.width for a in arts) + 16 * (len(arts) + 1)
        h = max(a.height for a in arts) + 32
        bg = Image.new('RGBA', (w, h), (0, 104, 140, 255)); x = 16
        for a in arts:
            bg.alpha_composite(a, (x, 16)); x += a.width + 16
        bg.resize((w * 4, h * 4), Image.NEAREST).convert('RGB').save(out)
    else:
        write_dmi(states, os.path.join(root, 'icons', 'obj', 'vehicles', 'submarine_hull.dmi'))
        print(f'wrote {len(states)} states')
