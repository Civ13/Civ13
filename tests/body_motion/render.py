"""Preview whole-body motion as before/after GIFs from the probe's export.

run.py --render-dir DIR exports a dressed body (render_<dir>.png) and the
motion keys the game's own procs build (keys.json). This script plays those
keys with the same timings and easings as body_motion.dm, interpolating each
matrix as scale, rotation and translation the way the client tweens a
transform, and samples the sprite at display scale like the client does.
It is a preview, not a Dream Seeker capture.

    python3 tests/body_motion/render.py DIR OUT_DIR
"""
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

SCALE = 4
FRAME_DS = 0.5  # 50 ms frames
GRASS = (86, 112, 70, 255)
GRASS_DARK = (78, 102, 63, 255)


def sprite(folder, direction):
    sheet = Image.open(folder / f'render_{direction}.png').convert('RGBA')
    return sheet.crop((0, 0, 32, 32))


def matrix(dx=0.0, dy=0.0, degrees=0.0, base=(1, 0, 0, 0, 1, 0)):
    """body_motion_matrix(): base, then a turn pivoting at the feet, then a shift."""
    a, b, c, d, e, f = base
    def then(m2, m1):
        a2, b2, c2, d2, e2, f2 = m2
        a1, b1, c1, d1, e1, f1 = m1
        return (a2 * a1 + b2 * d1, a2 * b1 + b2 * e1, a2 * c1 + b2 * f1 + c2,
                d2 * a1 + e2 * d1, d2 * b1 + e2 * e1, d2 * c1 + e2 * f1 + f2)
    m = (a, b, c, d, e, f)
    if degrees:
        r = math.radians(degrees)
        m = then((1, 0, 0, 0, 1, 16), m)
        m = then((math.cos(r), math.sin(r), 0, -math.sin(r), math.cos(r), 0), m)
        m = then((1, 0, 0, 0, 1, -16), m)
    return then((1, 0, dx, 0, 1, dy), m)


def decompose(m):
    a, b, c, d, e, f = m
    angle = math.degrees(math.atan2(b, a))  # clockwise
    sx = math.hypot(a, b)
    sy = (a * e - b * d) / sx
    return sx, sy, angle, c, f


def compose(sx, sy, angle, tx, ty):
    r = math.radians(angle)
    return (sx * math.cos(r), sy * math.sin(r), tx, -sx * math.sin(r), sy * math.cos(r), ty)


EASE = {
    'linear': lambda t: t,
    'quad_in': lambda t: t * t,
    'sine_in': lambda t: 1 - math.cos(t * math.pi / 2),
    'sine_out': lambda t: math.sin(t * math.pi / 2),
}


def track(start, keys):
    """keys: list of (matrix, ds, easing). Returns f(t) -> matrix."""
    def at(t):
        prev = start
        clock = 0.0
        for target, ds, ease in keys:
            if t <= clock + ds:
                k = EASE[ease]((t - clock) / ds) if ds else 1.0
                p, q = decompose(prev), decompose(target)
                return compose(*[p[i] + (q[i] - p[i]) * k for i in range(5)])
            clock += ds
            prev = target
        return prev
    return at


def offset_track(keys):
    """Pixel lunge keys: list of ((x, y), ds) linear, from (0, 0)."""
    def at(t):
        prev = (0, 0)
        clock = 0.0
        for target, ds in keys:
            if t <= clock + ds:
                k = (t - clock) / ds
                return (prev[0] + (target[0] - prev[0]) * k, prev[1] + (target[1] - prev[1]) * k)
            clock += ds
            prev = target
        return prev
    return at


def draw_body(canvas, img, centre, m, shift=(0, 0)):
    """Inverse-map each display pixel through the transform, nearest sampling."""
    a, b, c, d, e, f = m
    det = a * e - b * d
    cx, cy = centre
    W, H = canvas.size
    src = img.load()
    out = canvas.load()
    for py in range(max(0, int(cy - 24 * SCALE)), min(H, int(cy + 24 * SCALE))):
        for px in range(max(0, int(cx - 24 * SCALE)), min(W, int(cx + 24 * SCALE))):
            X = (px + 0.5 - cx) / SCALE - shift[0]
            Y = (cy - (py + 0.5)) / SCALE - shift[1]
            X, Y = X - c, Y - f
            x = (e * X - b * Y) / det
            y = (-d * X + a * Y) / det
            col, row = math.floor(x + 16), math.floor(16 - y)
            if 0 <= col < 32 and 0 <= row < 32:
                p = src[col, row]
                if p[3]:
                    base = out[px, py]
                    al = p[3] / 255
                    out[px, py] = tuple(int(p[i] * al + base[i] * (1 - al)) for i in range(3)) + (255,)


def ground(w, h):
    canvas = Image.new('RGBA', (w, h), GRASS)
    draw = ImageDraw.Draw(canvas)
    tile = 32 * SCALE
    for i in range(0, w, tile):
        for j in range(0, h, tile):
            if (i // tile + j // tile) % 2:
                draw.rectangle((i, j, i + tile - 1, j + tile - 1), fill=GRASS_DARK)
    return canvas


def scene(bodies, total_ds, label_left, label_right):
    """bodies: list of (img, tile_x, tile_y, before_fn, after_fn, before_shift, after_shift)."""
    tiles_w, tiles_h = 3, 3
    pw, ph = 32 * SCALE * tiles_w, 32 * SCALE * tiles_h
    frames = []
    t = 0.0
    while t <= total_ds + 1e-6:
        sheet = Image.new('RGBA', (pw * 2 + 8, ph + 28), (24, 24, 24, 255))
        for side in (0, 1):
            panel = ground(pw, ph)
            for img, tx, ty, before, after, bshift, ashift in bodies:
                fn = after if side else before
                sh = ashift if side else bshift
                centre = ((tx + 0.5) * 32 * SCALE, ph - (ty + 0.5) * 32 * SCALE)
                draw_body(panel, img, centre, fn(t), sh(t) if sh else (0, 0))
            sheet.alpha_composite(panel, (side * (pw + 8), 28))
        d = ImageDraw.Draw(sheet)
        d.text((8, 8), label_left, fill=(230, 230, 230, 255))
        d.text((pw + 16, 8), label_right, fill=(230, 230, 230, 255))
        d.text((pw * 2 - 60, 8), f'{t / 10:.2f} s', fill=(160, 160, 160, 255))
        frames.append(sheet.convert('P', palette=Image.ADAPTIVE, colors=128))
        t += FRAME_DS
    return frames


def save(frames, path):
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=50, loop=0, disposal=1)


def main():
    folder, out = Path(sys.argv[1]), Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    keys = json.loads((folder / 'keys.json').read_text())
    stand = tuple(keys['stand'])
    lying = tuple(keys['lying'])
    settle = tuple(keys['fall_settle'])
    # The Python keys must match the game's own.
    for mine, game in ((matrix(3, 0, 8), keys['recoil_east']), (matrix(0, -3), keys['recoil_south']),
                       (matrix(0, -1, base=lying), settle), (matrix(0, 0, 45), keys['fall_lean'])):
        assert all(abs(x - y) < 1e-3 for x, y in zip(mine, game)), (mine, game)

    east, west, south, north = (sprite(folder, d) for d in (4, 8, 2, 1))
    hold = lambda m: (lambda t: m)

    # 1. Falling and standing up: snap today, eased with motion.
    fall_at, stand_at = 4, 18
    def before_fall(t):
        return lying if fall_at <= t < stand_at else stand
    fall = track(stand, [(tuple(keys['fall_lean']), 2, 'quad_in'), (settle, 1, 'linear'), (lying, 1, 'linear')])
    rise = track(lying, [(tuple(keys['stand_lean']), 3, 'linear'), (stand, 3, 'sine_out')])
    def after_fall(t):
        if t < fall_at:
            return stand
        if t < stand_at:
            return fall(t - fall_at)
        return rise(t - stand_at)
    save(scene([(east, 1, 1, before_fall, after_fall, None, None)], 30,
               'Today: instant turn', 'Body motion: topple 4 ds, rise 6 ds'), out / 'fall-and-stand.gif')

    # 2. Hit from the west: the attacker's existing 8px lunge, the victim recoils.
    hits = (3, 13)
    lunge = offset_track([((8, 0), 2), ((0, 0), 2)])
    recoil = track(stand, [(matrix(3, 0, 8), 1, 'linear'), (stand, 2, 'sine_in')])
    def attacker_shift(t):
        for h in hits:
            if h <= t < h + 4:
                return lunge(t - h)
        return (0, 0)
    def victim_after(t):
        for h in hits:
            if h <= t < h + 3:
                return recoil(t - h)
        return stand
    save(scene([(east, 0, 1, hold(stand), hold(stand), attacker_shift, attacker_shift),
                (west, 1, 1, hold(stand), victim_after, None, None)], 20,
               'Today: only the attacker lunges', 'Body motion: 3 ds recoil, 8 deg'), out / 'recoil-side.gif')

    # 3. Hit from the north: no roll, a 3px push straight back.
    lunge_s = offset_track([((0, -8), 2), ((0, 0), 2)])
    recoil_s = track(stand, [(matrix(0, -3, 0), 1, 'linear'), (stand, 2, 'sine_in')])
    def attacker_s(t):
        for h in hits:
            if h <= t < h + 4:
                return lunge_s(t - h)
        return (0, 0)
    def victim_s(t):
        for h in hits:
            if h <= t < h + 3:
                return recoil_s(t - h)
        return stand
    save(scene([(south, 1, 2, hold(stand), hold(stand), attacker_s, attacker_s),
                (north, 1, 1, hold(stand), victim_s, None, None)], 20,
               'Today', 'Body motion: 3px push, no roll'), out / 'recoil-front.gif')


if __name__ == '__main__':
    main()
