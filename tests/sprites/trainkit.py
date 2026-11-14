"""Shared pixel-placing helpers for tests/sprites/create_trains.py and
create_carriages.py. Pillow only; every pixel comes from a fixed palette and
a fixed hash, so the sheets never change between runs.

Art is authored once in "canonical" coordinates (a vehicle heading north, or
a tile edge on the west side) and placed into each BYOND direction through a
Canvas transform. Shading primitives (bands, bevel, disc) are resolved in
world space after the transform, so the light always comes from the upper
left whichever way the vehicle faces.
Released under Civ13 AGPL-3.0.
"""
import math
from PIL import Image, PngImagePlugin

# canonical (x, y) on a w x h canvas -> world (x, y); world size swaps for
# the quarter turns.
TRANSFORMS = {
    'id': (lambda x, y, w, h: (x, y), False),
    'vf': (lambda x, y, w, h: (x, h - 1 - y), False),
    'hf': (lambda x, y, w, h: (w - 1 - x, y), False),
    'cw': (lambda x, y, w, h: (h - 1 - y, x), True),
    'tp': (lambda x, y, w, h: (y, x), True),
    'ccw': (lambda x, y, w, h: (y, w - 1 - x), True),
}
# A vehicle drawn heading north, in BYOND dir order south, north, east, west.
HEADING = ('vf', 'id', 'cw', 'tp')
# A part drawn against the west edge of its tile, same order.
EDGE = ('ccw', 'tp', 'hf', 'id')


def noise(x, y, seed=0):
    """A fixed 0..1 hash, so speckle never changes between runs."""
    n = (int(x) * 374761393 + int(y) * 668265263 + seed * 1442695041) & 0xffffffff
    n = ((n ^ (n >> 13)) * 1274126177) & 0xffffffff
    return ((n ^ (n >> 16)) & 0xffff) / 65535.0


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def ramp_at(ramp, t):
    """Colour at 0..1 along a list of colours."""
    t = max(0.0, min(1.0, t)) * (len(ramp) - 1)
    i = min(int(t), len(ramp) - 2)
    return mix(ramp[i], ramp[i + 1], t - i)


class Canvas:
    def __init__(self, w, h, tf='id'):
        self.w, self.h, self.tf = w, h, tf
        self.fn, swap = TRANSFORMS[tf]
        self.W, self.H = (h, w) if swap else (w, h)
        self.px = {}

    # -- world space ------------------------------------------------------
    def wput(self, X, Y, c, a=255):
        X, Y = int(X), int(Y)
        if not (0 <= X < self.W and 0 <= Y < self.H):
            return
        if a >= 255:
            self.px[(X, Y)] = (c[0], c[1], c[2], 255)
            return
        if a <= 0:
            return
        old = self.px.get((X, Y))
        if not old:
            self.px[(X, Y)] = (c[0], c[1], c[2], a)
            return
        t = a / 255.0
        oa = old[3] / 255.0
        na = t + oa * (1 - t)
        rgb = tuple(int(round((c[i] * t + old[i] * oa * (1 - t)) / na)) for i in range(3))
        self.px[(X, Y)] = rgb + (int(round(na * 255)),)

    def wpt(self, x, y):
        return self.fn(x, y, self.w, self.h)

    def wrect(self, x0, y0, x1, y1):
        ax, ay = self.wpt(x0, y0)
        bx, by = self.wpt(x1, y1)
        return (int(round(min(ax, bx))), int(round(min(ay, by))),
                int(round(max(ax, bx))), int(round(max(ay, by))))

    def vertical(self, along=True):
        """Whether a canonical north-south (along) run is vertical in the world."""
        swapped = TRANSFORMS[self.tf][1]
        return along != swapped

    # -- canonical primitives ---------------------------------------------
    def put(self, x, y, c, a=255):
        X, Y = self.wpt(x, y)
        self.wput(X, Y, c, a)

    def clear(self, x0, y0, x1, y1):
        X0, Y0, X1, Y1 = self.wrect(x0, y0, x1, y1)
        for Y in range(Y0, Y1 + 1):
            for X in range(X0, X1 + 1):
                self.px.pop((X, Y), None)

    def rect(self, x0, y0, x1, y1, c, a=255):
        X0, Y0, X1, Y1 = self.wrect(x0, y0, x1, y1)
        for Y in range(Y0, Y1 + 1):
            for X in range(X0, X1 + 1):
                self.wput(X, Y, c, a)

    def frame(self, x0, y0, x1, y1, c, a=255):
        X0, Y0, X1, Y1 = self.wrect(x0, y0, x1, y1)
        for X in range(X0, X1 + 1):
            self.wput(X, Y0, c, a)
            self.wput(X, Y1, c, a)
        for Y in range(Y0 + 1, Y1):
            self.wput(X0, Y, c, a)
            self.wput(X1, Y, c, a)

    def bevel(self, x0, y0, x1, y1, lit, face, shade, outline=None):
        """A raised plate: lit on the world's top and left, shaded bottom and right."""
        X0, Y0, X1, Y1 = self.wrect(x0, y0, x1, y1)
        if outline:
            for Y in range(Y0, Y1 + 1):
                for X in range(X0, X1 + 1):
                    self.wput(X, Y, outline)
            X0, Y0, X1, Y1 = X0 + 1, Y0 + 1, X1 - 1, Y1 - 1
        for Y in range(Y0, Y1 + 1):
            for X in range(X0, X1 + 1):
                c = face
                if X == X1 or Y == Y1:
                    c = shade
                if (X == X0 and Y != Y1) or (Y == Y0 and X != X1):
                    c = lit
                self.wput(X, Y, c)

    def sunk(self, x0, y0, x1, y1, lit, face, shade):
        """A recess: shaded on top and left, lit bottom and right."""
        self.bevel(x0, y0, x1, y1, shade, face, lit)

    def bands(self, x0, y0, x1, y1, cols, along=True, a=255):
        """Stripes across a run. `cols` goes from the lit side (world left or
        top) to the far side and is stretched to the run's width."""
        X0, Y0, X1, Y1 = self.wrect(x0, y0, x1, y1)
        vert = self.vertical(along)
        n = (X1 - X0 + 1) if vert else (Y1 - Y0 + 1)
        for Y in range(Y0, Y1 + 1):
            for X in range(X0, X1 + 1):
                i = (X - X0) if vert else (Y - Y0)
                k = i if n == len(cols) else min(len(cols) - 1, int(i * len(cols) / n))
                self.wput(X, Y, cols[k], a)

    def cyl(self, x0, y0, x1, y1, ramp, along=True):
        """A round barrel seen from above. ramp = glint, lit, face, shade, dark."""
        X0, Y0, X1, Y1 = self.wrect(x0, y0, x1, y1)
        vert = self.vertical(along)
        n = (X1 - X0 + 1) if vert else (Y1 - Y0 + 1)
        for Y in range(Y0, Y1 + 1):
            for X in range(X0, X1 + 1):
                i = (X - X0) if vert else (Y - Y0)
                t = (i + 0.5) / n
                if i == 0 or i == n - 1:
                    c = ramp[4]
                elif t < 0.16:
                    c = ramp[3]
                elif t < 0.24:
                    c = ramp[2]
                elif t < 0.34:
                    c = ramp[1]
                elif t < 0.40:
                    c = ramp[0]
                elif t < 0.50:
                    c = ramp[1]
                elif t < 0.72:
                    c = ramp[2]
                elif t < 0.88:
                    c = ramp[3]
                else:
                    c = ramp[4]
                self.wput(X, Y, c)

    def disc(self, cx, cy, r, ramp, outline=None, flat=False):
        """A dome (or a flat disc) lit from the upper left. ramp light -> dark."""
        X, Y = self.wpt(cx, cy)
        for py in range(int(Y - r - 1), int(Y + r + 2)):
            for pxx in range(int(X - r - 1), int(X + r + 2)):
                dx, dy = pxx - X, py - Y
                d = math.hypot(dx, dy)
                if d > r + 0.25:
                    continue
                if outline and d > r - 0.85:
                    self.wput(pxx, py, outline)
                    continue
                if flat:
                    t = 0.5 + (dx + dy) / (r * 4.0)
                else:
                    t = 0.5 + (dx + dy) / (r * 2.2) + (d / r) ** 2 * 0.18 - 0.12
                self.wput(pxx, py, ramp_at(ramp, t))

    def ring(self, cx, cy, r, c, a=255, width=1.0):
        X, Y = self.wpt(cx, cy)
        for py in range(int(Y - r - 1), int(Y + r + 2)):
            for pxx in range(int(X - r - 1), int(X + r + 2)):
                d = math.hypot(pxx - X, py - Y)
                if r - width + 0.25 < d <= r + 0.25:
                    self.wput(pxx, py, c, a)

    def line(self, x0, y0, x1, y1, c, a=255):
        X0, Y0 = self.wpt(x0, y0)
        X1, Y1 = self.wpt(x1, y1)
        n = int(max(abs(X1 - X0), abs(Y1 - Y0)))
        for i in range(n + 1):
            t = i / n if n else 0
            self.wput(round(X0 + (X1 - X0) * t), round(Y0 + (Y1 - Y0) * t), c, a)

    def rivet(self, x, y, lit, dark):
        """A rivet head: bright pixel with its shadow to the world's lower right."""
        X, Y = self.wpt(x, y)
        self.wput(X, Y, lit)
        self.wput(X + 1, Y + 1, dark, 150)

    def shade(self, x0, y0, x1, y1, a):
        self.rect(x0, y0, x1, y1, (0, 0, 0), a)

    def speckle(self, x0, y0, x1, y1, c, chance, seed=0, a=255):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if noise(x, y, seed) < chance:
                    self.put(x, y, c, a)

    def stamp(self, other, ox=0, oy=0):
        """Draws another world image (a Canvas or a PIL image) at a world offset."""
        im = other.image() if isinstance(other, Canvas) else other
        src = im.load()
        for Y in range(im.height):
            for X in range(im.width):
                p = src[X, Y]
                if p[3]:
                    self.wput(X + ox, Y + oy, p[:3], p[3])

    def image(self):
        im = Image.new('RGBA', (self.W, self.H), (0, 0, 0, 0))
        for (X, Y), c in self.px.items():
            im.putpixel((X, Y), c)
        return im


def directions(draw, w=32, h=32, order=HEADING):
    """The four world images of one canonical drawing, in BYOND dir order."""
    out = []
    for tf in order:
        c = Canvas(w, h, tf)
        draw(c)
        out.append(c.image())
    return out


def slice_car(images, rows, seg, col, tile=32):
    """One tile of a car drawn 3 tiles wide and `rows` long (canonical north),
    for each heading in `images` (south, north, east, west). seg counts from
    the front, col is -1 (left of the heading), 0 or 1."""
    s, n, e, w = images
    out = [
        s.crop(((1 - col) * tile, (rows - 1 - seg) * tile, (2 - col) * tile, (rows - seg) * tile)),
        n.crop(((col + 1) * tile, seg * tile, (col + 2) * tile, (seg + 1) * tile)),
        e.crop(((rows - 1 - seg) * tile, (col + 1) * tile, (rows - seg) * tile, (col + 2) * tile)),
        w.crop((seg * tile, (1 - col) * tile, (seg + 1) * tile, (2 - col) * tile)),
    ]
    return out


def write_dmi(path, states, size=(32, 32), cols=8):
    """states: name -> list of frames (1 or 4 directions)."""
    frames = [fr for group in states.values() for fr in group]
    rows = -(-len(frames) // cols)
    sheet = Image.new('RGBA', (size[0] * cols, size[1] * rows), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(fr, (i % cols * size[0], i // cols * size[1]))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = %d\n\theight = %d\n' % size
    for name, group in states.items():
        text += 'state = "%s"\n\tdirs = %d\n\tframes = 1\n' % (name, len(group))
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta)


def sheet_image(states, size=(32, 32), cols=8):
    frames = [fr for group in states.values() for fr in group]
    rows = -(-len(frames) // cols)
    sheet = Image.new('RGBA', (size[0] * cols, size[1] * rows), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(fr, (i % cols * size[0], i // cols * size[1]))
    return sheet


def read_dmi(path):
    """name -> list of frames, for a single-frame-per-direction sheet."""
    import re
    im = Image.open(path)
    text = im.info.get('Description', '')
    w = int(re.search(r'width = (\d+)', text).group(1))
    h = int(re.search(r'height = (\d+)', text).group(1))
    im = im.convert('RGBA')
    cols = im.width // w
    out, i = {}, 0
    for name, dirs, frames in re.findall(r'state = "([^"]*)"\n\tdirs = (\d+)\n\tframes = (\d+)', text):
        n = int(dirs) * int(frames)
        out[name] = [im.crop(((j % cols) * w, (j // cols) * h, (j % cols) * w + w, (j // cols) * h + h))
                     for j in range(i, i + n)]
        i += n
    return out
