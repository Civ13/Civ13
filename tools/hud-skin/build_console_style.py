#!/usr/bin/env python3
"""Builds the ConsoleStyle HUD icons from the 1713Style ones.

The new style keeps every 1713Style pictogram and swaps the heavy wooden bevel
for a slim dark plate, so the two files always carry the same icon states.
Run from the repository root after changing 1713Style.dmi, healthdoll.dmi or
zone_sel.dmi:

    python3 tools/hud-skin/build_console_style.py

Needs Pillow. Writes icons/mob/screen/ConsoleStyle.dmi, healthdoll_console.dmi,
zone_sel_console.dmi and needs.dmi; the output is deterministic.
"""
import math
import re
import struct
import zlib
from collections import Counter
from pathlib import Path

from PIL import Image, ImageDraw
from PIL.PngImagePlugin import PngInfo

ROOT = Path(__file__).resolve().parents[2]
SCREEN = ROOT / 'icons/mob/screen'

# The old bevel, outermost ring first; each ring alternates two scanline shades.
NEUTRAL = [[(38, 24, 14, 255), (48, 32, 21, 255)], [(70, 51, 36, 255), (76, 57, 42, 255)],
           [(151, 133, 116, 255), (153, 135, 118, 255)], [(109, 89, 72, 255), (113, 93, 76, 255)],
           [(100, 80, 63, 255), (95, 75, 58, 255)], [(89, 69, 53, 255)]]
BROWN = [(85, 65, 49, 255), (91, 71, 54, 255), (89, 69, 53, 255), (95, 75, 58, 255), (100, 80, 63, 255)]
PLATE = (20, 17, 14, 150)
EDGE = (176, 148, 104, 235)
GOLD = (255, 204, 92, 255)
# Art with no tile behind it stays as drawn.
LOOSE = ('x', 'grabbed', 'grabbed1', 'grabbed+1', 'blank', '')
# Small buttons that sit in one corner of a 32px icon. ConsoleStyle lines them
# up in a strip, so their art moves to the lower-left corner.
STRIP = ('act_drop', 'act_throw_off', 'act_throw_on', 'pull0', 'pull1', 'act_resist')
NEEDS_BARS = (('food', (226, 150, 62)), ('water', (86, 164, 232)), ('stamina', (176, 212, 84)))
NEEDS_BAR_PX = 42
NEEDS_LOW = (226, 60, 48)
PICTOGRAMS = {
    'food': ["..##...", ".####..", "#####..", "#####..", ".###.#.", "...###.", "....##."],
    'water': ["...#...", "..###..", "..###..", ".#####.", ".#####.", ".#####.", "..###.."],
    'stamina': ["....##.", "...##..", "..##...", ".#####.", "...##..", "..##...", ".##...."],
}


def read_dmi(path):
    """-> (width, height, [(state, dirs, frames, [images], metadata block)])"""
    data = Path(path).read_bytes()
    i = data.find(b'zTXt')
    length = struct.unpack('>I', data[i - 4:i])[0]
    chunk = data[i + 4:i + 4 + length]
    text = zlib.decompress(chunk[chunk.index(bytes(1)) + 2:]).decode()
    sheet = Image.open(path).convert('RGBA')
    w = int(re.search(r'width = (\d+)', text)[1])
    h = int(re.search(r'height = (\d+)', text)[1])
    cols = sheet.width // w
    states = []
    idx = 0
    for m in re.finditer(r'state = "([^"]*)"\n((?:\t[^\n]*\n)*)', text):
        dirs = int(re.search(r'dirs = (\d+)', m[2])[1])
        count = int(re.search(r'frames = (\d+)', m[2])[1])
        frames = []
        for k in range(idx, idx + dirs * count):
            frames.append(sheet.crop(((k % cols) * w, (k // cols) * h, (k % cols) * w + w, (k // cols) * h + h)))
        states.append((m[1], dirs, count, frames, m[2]))
        idx += dirs * count
    return w, h, states


def write_dmi(path, w, h, states):
    """states: [(name, metadata block, [images])]"""
    total = sum(len(frames) for _, _, frames in states)
    cols = max(1, math.ceil(math.sqrt(total)))
    sheet = Image.new('RGBA', (cols * w, math.ceil(total / cols) * h), (0, 0, 0, 0))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = %d\n\theight = %d\n' % (w, h)
    i = 0
    for name, meta, frames in states:
        text += 'state = "%s"\n%s' % (name, meta)
        for frame in frames:
            sheet.paste(frame, ((i % cols) * w, (i // cols) * h))
            i += 1
    info = PngInfo()
    info.add_text('Description', text + '# END DMI\n', zip=True)
    sheet.save(path, format='PNG', pnginfo=info, optimize=True)


def lum(p):
    return 0.3 * p[0] + 0.59 * p[1] + 0.11 * p[2]


def sat(p):
    return max(p[:3]) - min(p[:3])


def dark(tint):
    return (tint[0] // 6 + 8, tint[1] // 6 + 8, tint[2] // 6 + 6, 190)


def plate(im, bb, edge=EDGE, fill=PLATE, thick=1):
    d = ImageDraw.Draw(im)
    w, h = bb[2] - bb[0], bb[3] - bb[1]
    big = min(w, h) > 20
    inset = 1 if big else 0
    a, b, c, e = bb[0] + inset, bb[1] + inset, bb[2] - 1 - inset, bb[3] - 1 - inset
    d.rounded_rectangle((a, b, c, e), radius=3 if big else 2, fill=edge)
    d.rounded_rectangle((a + thick, b + thick, c - thick, e - thick), radius=2 if big else 1, fill=fill)
    if big:
        shine = tuple(min(255, fill[i] + 20) for i in range(3)) + (fill[3],)
        d.line((a + thick + 1, b + thick, c - thick - 1, b + thick), fill=shine)


def depth(p, bb):
    return min(p[0] - bb[0], p[1] - bb[1], bb[2] - 1 - p[0], bb[3] - 1 - p[1])


def peel(im, bb):
    """The old bevel as a pixel set. Rings are followed inward in colour order,
    so a notched frame is caught while a pictogram that reuses a ring colour is not."""
    px = im.load()
    h = bb[3] - bb[1]
    cols = []
    for r in range(6):
        seen = Counter()
        for t in range(h // 3, 2 * h // 3 + 1):
            seen[px[bb[0] + r, bb[1] + t]] += 1
            seen[px[bb[2] - 1 - r, bb[1] + t]] += 1
        cols.append({c for c, _ in seen.most_common(2)})
    if sat(max(cols[2], key=lum)) <= 60:
        cols = [set(ring) for ring in NEUTRAL]

    def inside(q):
        return bb[0] <= q[0] < bb[2] and bb[1] <= q[1] < bb[3]

    frame = set()
    prev = None
    for r in range(6):
        layer = set()
        for y in range(bb[1], bb[3]):
            for x in range(bb[0], bb[2]):
                if (x, y) in frame or px[x, y] not in cols[r]:
                    continue
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        q = (x + dx, y + dy)
                        if prev is None:
                            if not inside(q) or px[q][3] == 0:
                                layer.add((x, y))
                        elif q in prev:
                            layer.add((x, y))
        todo = sorted(layer)
        while todo:
            x, y = todo.pop()
            for q in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if inside(q) and q not in layer and q not in frame and px[q] in cols[r] and depth(q, bb) <= r + 3:
                    layer.add(q)
                    todo.append(q)
        frame |= layer
        prev = layer
    return frame, cols


# The 16px intent buttons carry one letter; the old 4x5 letters are too small
# to survive on a plate, so they are drawn again at 5x7.
LETTERS = {
    'H': ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    'D': ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
    'G': [".####", "#....", "#....", "#.###", "#...#", "#...#", ".###."],
}
INTENT_LETTER = {'intent_help': 'H', 'intent_disarm': 'D', 'intent_grab': 'G', 'intent_harm': 'H'}


def intent_button(name, im, bb):
    px = im.load()
    tint = px[bb[0] + 2, bb[1] + 8] if lum(px[bb[0] + 2, bb[1] + 8]) > lum(px[bb[0] + 3, bb[1] + 8]) else px[bb[0] + 3, bb[1] + 8]
    out = Image.new('RGBA', im.size, (0, 0, 0, 0))
    plate(out, bb, edge=tint, fill=dark(tint))
    bright = tuple(min(255, int(c * 0.55 + 115)) for c in tint[:3]) + (255,)
    for y, row in enumerate(LETTERS[INTENT_LETTER[name]]):
        for x, ch in enumerate(row):
            if ch == '#':
                out.putpixel((bb[0] + 5 + x, bb[1] + 4 + y), bright)
    return out


def small(name, im, bb):
    """Quarter-tile buttons and labels: a plate under the brightest pixels."""
    if name in INTENT_LETTER:
        return intent_button(name, im, bb)
    px = im.load()
    out = Image.new('RGBA', im.size, (0, 0, 0, 0))
    solid = [px[x, y] for y in range(bb[1], bb[3]) for x in range(bb[0], bb[2]) if px[x, y][3] == 255]
    hot = [c for c in solid if sat(c) > 90]
    tint = None
    if len(hot) > len(solid) * 0.12 and name != 'act_resist':
        tint = Counter(hot).most_common(1)[0][0]
    plate(out, bb, edge=tint or EDGE, fill=dark(tint) if tint else PLATE)
    op = out.load()
    top = max(lum(c) for c in solid)
    for y in range(bb[1] + 2, bb[3] - 2):
        for x in range(bb[0] + 2, bb[2] - 2):
            c = px[x, y]
            if c[3] < 255:
                continue
            if sat(c) > 90:
                # On a tinted button only the bright strokes well inside the old bevel are art.
                if not tint or (lum(c) > lum(tint) * 0.72 and depth((x, y), bb) >= 4):
                    op[x, y] = c
            elif depth((x, y), bb) < 3 and name != 'swap':
                continue
            elif lum(c) > top - 28:
                op[x, y] = (246, 234, 206, 255)
            elif lum(c) > top - 48:
                op[x, y] = (200, 188, 160, 200)
    return out


def convert(name, im, keep=False):
    """One icon frame in the new style. keep: copy the pictogram's colours untouched."""
    bb = im.getbbox()
    if not bb or name in LOOSE:
        return im.copy()
    px = im.load()
    if name.startswith(('storage_', 'stored_')):
        # Storage window strips: dark plate, brass where the old edge was.
        out = Image.new('RGBA', im.size, (0, 0, 0, 0))
        op = out.load()
        for y in range(bb[1], bb[3]):
            for x in range(bb[0], bb[2]):
                if px[x, y][3]:
                    edge = depth((x, y), bb) == 0 and (y in (bb[1], bb[3] - 1) or not name.endswith('continue'))
                    op[x, y] = EDGE if edge else (20, 17, 14, 185)
        return out
    w, h = bb[2] - bb[0], bb[3] - bb[1]
    if min(w, h) <= 20 or name in ('swap', 'random', 'random_on'):
        return small(name, im, bb)
    frame, cols = peel(im, bb)
    rest = [(x, y) for y in range(bb[1], bb[3]) for x in range(bb[0], bb[2]) if (x, y) not in frame and px[x, y][3] == 255]
    ring = max(cols[2], key=lum)
    tint = ring if sat(ring) > 60 else None
    if tint:
        fill = {c for c, _ in Counter(px[p] for p in rest).most_common(2)}
        fill_max = max(lum(c) for c in fill)
    else:
        fill = set(BROWN)
    fill_lum = sum(lum(c) for c in fill) / len(fill)
    top = max([lum(px[p]) for p in rest if px[p] not in fill and sat(px[p]) < 50] + [fill_lum + 40])
    # A coloured picture (the mood face) keeps its own dull shading pixels;
    # line art drawn in greys, even under a red cross, is redrawn in cream.
    art = [px[p] for p in rest if px[p] not in fill]
    if not tint and sum(1 for c in art if sat(c) >= 50) > len(art) * 0.8:
        keep = True
    out = Image.new('RGBA', im.size, (0, 0, 0, 0))
    plate(out, bb, edge=tint or EDGE, fill=dark(tint) if tint else PLATE, thick=2 if tint else 1)
    op = out.load()
    for p in rest:
        c = px[p]
        if c in fill:
            continue
        if keep:
            op[p] = c
        elif sat(c) < 50 and not tint:
            if lum(c) <= fill_lum + 4:
                continue
            k = min(1.0, (lum(c) - fill_lum) / max(30.0, top - fill_lum))
            v = int(150 + 100 * k)
            op[p] = (v, int(v * 0.95), int(v * 0.84), int(90 + 165 * k))
        else:
            same_hue = abs(c[0] - tint[0]) + abs(c[2] - tint[2]) < 200 if tint else False
            if tint and lum(c) < fill_max + 10 and sat(c) > 40 and same_hue and lum(c) < lum(tint) * 0.8:
                continue
            op[p] = c
    return out


def active_hand(neutral):
    """The hand in use: the same pictogram on a gold-edged plate."""
    out = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
    plate(out, (0, 0, 32, 32), edge=GOLD, fill=(58, 44, 14, 185), thick=2)
    src = neutral.load()
    glyph = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
    gp = glyph.load()
    for y in range(4, 28):
        for x in range(4, 28):
            c = src[x, y]
            if c[0] > 140:
                gp[x, y] = (255, int(c[1] * 0.93), int(c[2] * 0.62), c[3])
    out.alpha_composite(glyph)
    return out


def to_corner(im):
    bb = im.getbbox()
    out = Image.new('RGBA', im.size, (0, 0, 0, 0))
    if bb:
        art = im.crop(bb)
        out.paste(art, (0, im.height - art.height))
    return out


def build_style():
    w, h, states = read_dmi(SCREEN / '1713Style.dmi')
    frames = {name: [convert(name, f) for f in fr] for name, _, _, fr, _ in states}
    old = {name: fr for name, _, _, fr, _ in states}
    # The swap bar is one 64px button drawn as two halves.
    both = Image.new('RGBA', (64, 32), (0, 0, 0, 0))
    both.paste(old['swap-l'][0], (0, 0))
    both.alpha_composite(old['swap-r'][0], (32, 0))
    bar = convert('swap', both)
    frames['swap-l'] = [bar.crop((0, 0, 32, 32))]
    frames['swap-r'] = [bar.crop((32, 0, 64, 32))]
    for side in ('l', 'r'):
        frames['act_hand-' + side] = [active_hand(frames['hand-' + side][0])]
    for name in STRIP:
        frames[name] = [to_corner(f) for f in frames[name]]
    write_dmi(SCREEN / 'ConsoleStyle.dmi', w, h, [(name, meta, frames[name]) for name, _, _, _, meta in states])


def build_copy(source, target, wanted, keep):
    w, h, states = read_dmi(SCREEN / source)
    out = []
    for name, _, _, frames, meta in states:
        if wanted(name):
            frames = [convert(name, f, keep=keep) for f in frames]
        out.append((name, meta, frames))
    write_dmi(SCREEN / target, w, h, out)


def needs_base():
    im = Image.new('RGBA', (64, 32), (0, 0, 0, 0))
    plate(im, (0, 0, 64, 32))
    d = ImageDraw.Draw(im)
    for i, (key, colour) in enumerate(NEEDS_BARS):
        y = 4 + i * 8
        for yy, row in enumerate(PICTOGRAMS[key]):
            for xx, ch in enumerate(row):
                if ch == '#':
                    im.putpixel((5 + xx, y + yy), colour + (255,))
        d.rectangle((15, y + 1, 16 + NEEDS_BAR_PX, y + 5), fill=(0, 0, 0, 150), outline=(120, 100, 72, 255))
    return im


def needs_fill(row, colour, px):
    im = Image.new('RGBA', (64, 32), (0, 0, 0, 0))
    if px > 0:
        if px < NEEDS_BAR_PX * 0.25:
            colour = NEEDS_LOW
        y = 4 + row * 8
        d = ImageDraw.Draw(im)
        d.rectangle((16, y + 2, 15 + px, y + 4), fill=colour + (255,))
        d.line((16, y + 2, 15 + px, y + 2), fill=tuple(min(255, c + 45) for c in colour) + (255,))
    return im


def build_needs():
    meta = '\tdirs = 1\n\tframes = 1\n'
    states = [('needs', meta, [needs_base()])]
    for row, (key, colour) in enumerate(NEEDS_BARS):
        for px in range(NEEDS_BAR_PX + 1):
            states.append(('%s%d' % (key, px), meta, [needs_fill(row, colour, px)]))
    write_dmi(SCREEN / 'needs.dmi', 64, 32, states)


def main():
    build_style()
    build_copy('healthdoll.dmi', 'healthdoll_console.dmi', lambda n: n.startswith('healthdoll_BASE'), keep=True)
    build_copy('zone_sel.dmi', 'zone_sel_console.dmi', lambda n: n == 'zone_sel', keep=False)
    build_needs()


if __name__ == '__main__':
    main()
