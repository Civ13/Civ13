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
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw

SCALE = 4
FRAME_DS = 0.5  # 50 ms frames
GRASS = (86, 112, 70, 255)
GRASS_DARK = (78, 102, 63, 255)
WATER = (52, 92, 140, 255)
WATER_DARK = (46, 82, 126, 255)
WOOD = (0x82, 0x4B, 0x28)  # wood icon_colour (materials.dm)


def sprite_file(folder, name):
    sheet = Image.open(folder / name).convert('RGBA')
    return sheet.crop((0, 0, 32, 32))


def pixels(img):
    # Pillow 12.1 renamed getdata(); work on either.
    return img.get_flattened_data() if hasattr(img, 'get_flattened_data') else img.getdata()


def chair_sprite():
    """The plain chair from icons/obj/bed_chair.dmi, south-facing, in wood colour."""
    path = Path(__file__).resolve().parents[2] / 'icons/obj/bed_chair.dmi'
    sheet = Image.open(path)
    desc = sheet.info['Description']
    index = 0
    for name, dirs, frames in re.findall(r'state = "([^"]*)"\n\tdirs = (\d+)\n\tframes = (\d+)', desc):
        if name == 'chair':
            break
        index += int(dirs) * int(frames)
    sheet = sheet.convert('RGBA')
    cols = sheet.width // 32
    img = sheet.crop(((index % cols) * 32, (index // cols) * 32, (index % cols) * 32 + 32, (index // cols) * 32 + 32))
    r, g, b = WOOD
    img.putdata([(p[0] * r // 255, p[1] * g // 255, p[2] * b // 255, p[3]) for p in pixels(img)])
    return img


def sprite(folder, direction):
    sheet = Image.open(folder / f'render_{direction}.png').convert('RGBA')
    return sheet.crop((0, 0, 32, 32))


def matrix(dx=0.0, dy=0.0, degrees=0.0, base=(1, 0, 0, 0, 1, 0), squash=1.0):
    """body_motion_matrix(): base, then a turn pivoting at the feet, then a shift."""
    a, b, c, d, e, f = base
    def then(m2, m1):
        a2, b2, c2, d2, e2, f2 = m2
        a1, b1, c1, d1, e1, f1 = m1
        return (a2 * a1 + b2 * d1, a2 * b1 + b2 * e1, a2 * c1 + b2 * f1 + c2,
                d2 * a1 + e2 * d1, d2 * b1 + e2 * e1, d2 * c1 + e2 * f1 + f2)
    m = (a, b, c, d, e, f)
    if degrees or squash != 1:
        r = math.radians(degrees)
        m = then((1, 0, 0, 0, 1, 16), m)
        if squash != 1:
            m = then((1, 0, 0, 0, squash, 0), m)
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
    'sine': lambda t: (1 - math.cos(t * math.pi)) / 2,
    'quad_out': lambda t: 1 - (1 - t) * (1 - t),
}


def keys_track(keys):
    """body_motion_play() keys: (dx, dy, degrees, squash, ds, easing) from rest."""
    return track((1, 0, 0, 0, 1, 0), [(matrix(dx, dy, deg, squash=sq), ds, ease) for dx, dy, deg, sq, ds, ease in keys])


def repeat(fn, every, length, start=0):
    def at(t):
        if t < start:
            return fn(0)
        k = (t - start) % every
        return fn(k) if k < length else fn(length)
    return at


def panels(columns, total_ds, tiles=(3, 3)):
    """columns: list of (label, bodies, props). bodies: (img, tx, ty, matrix_fn, shift_fn).
    props: (img, tx, ty, state_fn) with state_fn(t) -> (dx, dy, scale, alpha) or None.
    A fourth column item True draws deep water: water tiles, and the body's
    lower half under the water overlay, which moves with the body."""
    pw, ph = 32 * SCALE * tiles[0], 32 * SCALE * tiles[1]
    frames = []
    t = 0.0
    while t <= total_ds + 1e-6:
        sheet = Image.new('RGBA', ((pw + 8) * len(columns) - 8, ph + 28), (24, 24, 24, 255))
        d = ImageDraw.Draw(sheet)
        for i, (label, bodies, props, *extra) in enumerate(columns):
            water = bool(extra and extra[0])
            panel = ground(pw, ph, water)
            def centre(tx, ty):
                return ((tx + 0.5) * 32 * SCALE, ph - (ty + 0.5) * 32 * SCALE)
            for img, tx, ty, state in props:
                st = state(t) if callable(state) else state
                if st:
                    dx, dy, sc, al = st
                    draw_body(panel, img, centre(tx, ty), (sc, 0, 0, 0, sc, 0), (dx, dy), al)
            for img, tx, ty, fn, sh in bodies:
                draw_body(panel, img, centre(tx, ty), fn(t), sh(t) if sh else (0, 0), water=water)
            sheet.alpha_composite(panel, (i * (pw + 8), 28))
            d.text((i * (pw + 8) + 8, 8), label, fill=(230, 230, 230, 255))
        d.text((sheet.width - 60, 8), f'{t / 10:.2f} s', fill=(160, 160, 160, 255))
        frames.append(sheet.convert('RGB'))
        t += FRAME_DS
    return frames


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


def draw_body(canvas, img, centre, m, shift=(0, 0), alpha=1.0, water=False):
    """Inverse-map each display pixel through the transform, nearest sampling."""
    a, b, c, d, e, f = m
    det = a * e - b * d
    cx, cy = centre
    W, H = canvas.size
    src = img.load()
    out = canvas.load()
    # Scan around where the shifted body is drawn, not the tile it stands on.
    bx, by = cx + shift[0] * SCALE, cy - shift[1] * SCALE
    for py in range(max(0, int(by - 24 * SCALE)), min(H, int(by + 24 * SCALE))):
        for px in range(max(0, int(bx - 24 * SCALE)), min(W, int(bx + 24 * SCALE))):
            X = (px + 0.5 - cx) / SCALE - shift[0]
            Y = (cy - (py + 0.5)) / SCALE - shift[1]
            X, Y = X - c, Y - f
            x = (e * X - b * Y) / det
            y = (-d * X + a * Y) / det
            col, row = math.floor(x + 16), math.floor(16 - y)
            if 0 <= col < 32 and 0 <= row < 32:
                p = src[col, row]
                if p[3] and water and row >= 19:
                    # Sprite rows below the waterline, in body space like the game's mask.
                    p = tuple(int(p[i] * 0.3 + WATER[i] * 0.7) for i in range(3)) + (p[3],)
                if p[3]:
                    base = out[px, py]
                    al = p[3] / 255 * alpha
                    out[px, py] = tuple(int(p[i] * al + base[i] * (1 - al)) for i in range(3)) + (255,)


def ground(w, h, water=False):
    light, dark = (WATER, WATER_DARK) if water else (GRASS, GRASS_DARK)
    canvas = Image.new('RGBA', (w, h), light)
    draw = ImageDraw.Draw(canvas)
    tile = 32 * SCALE
    for i in range(0, w, tile):
        for j in range(0, h, tile):
            if (i // tile + j // tile) % 2:
                draw.rectangle((i, j, i + tile - 1, j + tile - 1), fill=dark)
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
        frames.append(sheet.convert('RGB'))
        t += FRAME_DS
    return frames


def save(frames, path):
    # One shared palette, so every frame keeps the same colours.
    strip = Image.new('RGB', (frames[0].width, frames[0].height * min(len(frames), 8)))
    for i, frame in enumerate(frames[::max(1, len(frames) // 8)][:8]):
        strip.paste(frame, (0, i * frames[0].height))
    palette = strip.quantize(colors=128, method=Image.Quantize.MEDIANCUT)
    frames = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
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


    # 4. Chopping or mining on the 5 ds tool tick: today only the tool image
    # flies 16px onto the rock; now the body winds up and leans in, and the
    # image travels 8px.
    tool = sprite_file(folder, 'render_tool.png')
    rock = sprite_file(folder, 'render_rock.png')
    work = keys_track([(-1, 0, -4, 1, 1, 'linear'), (2, 0, 6, 1, 2, 'quad_in'), (0, 0, 0, 1, 2, 'sine_out')])
    def strike(reach):
        def at(t):
            k = t % 5
            if k < 3:
                return (-reach * (1 - k / 3), 0, 0.75, 175 / 255)
            return (0, 0, 0.75, 175 / 255)
        return at
    save(panels([('Today: tool image only', [(east, 0, 1, hold(stand), None)], [(rock, 1, 1, (0, 0, 1, 1)), (tool, 1, 1, strike(16))]),
                 ('Body motion: wind-up and 6 deg lean, 5 ds', [(east, 0, 1, repeat(work, 5, 5), None)], [(rock, 1, 1, (0, 0, 1, 1)), (tool, 1, 1, strike(8))])],
                20, (2, 3)), out / 'work-strike.gif')

    # 5. Sitting down and lying down on purpose.
    chair = chair_sprite()
    settle = keys_track([(0, -2, 0, 0.9, 1, 'quad_in'), (0, 0, 0, 1, 2, 'sine_out')])
    def seat(t):
        return settle(t - 4) if t >= 4 else stand
    lie = track(stand, [(tuple(keys['fall_lean']), 3, 'sine'), (lying, 3, 'sine_out')])
    def lie_down(t):
        return lie(t - 4) if t >= 4 else stand
    save(panels([('Sitting: 2px drop and squash, 3 ds', [(south, 1, 1, seat, None)], [(chair, 1, 1, (0, 0, 1, 1))]),
                 ('Lying down to rest: slow 6 ds', [(east, 1, 1, lie_down, None)], []),
                 ('Falling (for comparison): 4 ds', [(east, 1, 1, lambda t: fall(t - 4) if t >= 4 else stand, None)], [])],
                16), out / 'sit-and-lie-down.gif')

    # 6. Emotes.
    def emote(keys):
        return repeat(keys_track(keys), 12, sum(k[4] for k in keys), start=2)
    emotes = [
        ('nod', south, [(0, -1, 0, 1, 1, 'sine'), (0, 0, 0, 1, 1, 'sine'), (0, -1, 0, 1, 1, 'sine'), (0, 0, 0, 1, 1, 'sine')]),
        ('shake', south, [(-1, 0, 0, 1, 1, 'sine'), (1, 0, 0, 1, 2, 'sine'), (0, 0, 0, 1, 1, 'sine')]),
        ('bow (facing east)', east, [(2, 0, 12, 1, 2, 'sine'), (2, 0, 12, 1, 2, 'linear'), (0, 0, 0, 1, 2, 'sine_out')]),
        ('bow (facing south)', south, [(0, -2, 0, 0.9, 2, 'sine'), (0, -2, 0, 0.9, 2, 'linear'), (0, 0, 0, 1, 2, 'sine_out')]),
        ('shrug', south, [(0, 2, 0, 1, 1, 'quad_out'), (0, 2, 0, 1, 1, 'linear'), (0, 0, 0, 1, 2, 'sine_in')]),
        ('wave', south, [(0, 1, 0, 1, 1, 'quad_out'), (0, 1, 0, 1, 3, 'linear'), (0, 0, 0, 1, 1, 'sine')]),
        ('salute', south, [(0, 1, 0, 1, 1, 'quad_out'), (0, 1, 0, 1, 4, 'linear'), (0, 0, 0, 1, 1, 'sine')]),
    ]
    save(panels([(name, [(img, 0.5, 0, emote(keys), None)], []) for name, img, keys in emotes], 24, (2, 1)),
         out / 'emotes.gif')


    # 7. Combat: edged slash and blunt overhead on top of the existing lunge,
    # a parry and a slip. Each exchange repeats every 10 ds.
    def every(fn, length):
        return repeat(fn, 10, length, start=2)
    lunge_every = every(lambda t: lunge(t), 4)
    def shift_every(t):
        return lunge_every(t)
    slash = keys_track([(0, 0, 8, 1, 1, 'quad_out'), (0, 0, 0, 1, 3, 'sine_in')])
    blunt = keys_track([(0, 0, -4, 1, 1, 'linear'), (0, 0, 8, 1, 1, 'quad_in'), (0, 0, 0, 1, 2, 'sine_out')])
    parry = keys_track([(2, 0, 0, 1, 1, 'linear'), (0, 0, 0, 1, 2, 'sine_in')])
    slip = keys_track([(0, 4, 0, 1, 1, 'quad_out'), (0, 0, 0, 1, 2, 'sine_in')])
    hit = every(recoil, 3)
    late_recoil = track(stand, [(stand, 1, 'linear'), (matrix(3, 0, 8), 1, 'linear'), (stand, 2, 'sine_in')])
    blunt_hit = every(late_recoil, 4)
    save(panels([
        ('Edged slash: 8 deg roll + lunge', [(east, 0, 1, every(slash, 4), shift_every), (west, 1, 1, hit, None)], []),
        ('Blunt: wind-up, 8 deg drop', [(east, 0, 1, every(blunt, 4), shift_every), (west, 1, 1, blunt_hit, None)], []),
        ('Parry: 2px back, no recoil', [(east, 0, 1, every(slash, 4), shift_every), (west, 1, 1, every(parry, 3), None)], []),
        ('Slip: 4px sidestep', [(east, 0, 1, hold(stand), shift_every), (west, 1, 1, every(slip, 3), None)], []),
    ], 22, (2, 3)), out / 'combat.gif')

    # 8. Swimming and climbing.
    for mine, name in ((matrix(0, -1), 'swim_dip'), (matrix(0, -3), 'sink'), (matrix(0, 1), 'climb_up')):
        assert all(abs(x - y) < 1e-3 for x, y in zip(mine, keys[name])), name
    stroke = keys_track([(0, -1, 0, 1, 2, 'sine'), (0, 0, 0, 1, 3, 'sine')])
    def swim_glide(t):
        # A skilled swimmer: one 8 ds step after another, a stroke every 12 ds at most.
        return ((t * 4) % 96 - 32, 0)
    sink = keys_track([(0, -3, 0, 1, 3, 'quad_in'), (0, -3, 0, 1, 3, 'linear'), (0, 0, 0, 1, 4, 'sine_out')])
    struggle = keys_track([(-2, 0, 0, 1, 2, 'linear'), (2, 0, 0, 1, 2, 'linear'), (0, 0, 0, 1, 2, 'linear')])
    pull_up = keys_track([(0, 1, 0, 1, 2, 'quad_out'), (0, 0, 0, 1, 4, 'sine'), (0, 0, 0, 1, 4, 'linear')])
    pull_down = keys_track([(0, -1, 0, 1, 2, 'quad_in'), (0, 0, 0, 1, 4, 'sine'), (0, 0, 0, 1, 4, 'linear')])
    save(panels([
        ('Swim stroke: 1px dip, 12 ds apart', [(east, 1, 1, repeat(stroke, 12, 5), swim_glide)], [], True),
        ('Spent: sink 3px and hold, 10 ds', [(south, 1, 1, repeat(sink, 16, 10, start=2), None)], [], True),
        ('Drowning: 2px struggle each second', [(south, 1, 1, repeat(struggle, 10, 6, start=2), None)], [], True),
        ('Climbing up: 1px pull every 10 ds', [(north, 1, 1, repeat(pull_up, 10, 10, start=2), None)], []),
        ('Climbing down: 1px dip every 10 ds', [(south, 1, 1, repeat(pull_down, 10, 10, start=2), None)], []),
    ], 24, (3, 3)), out / 'swim-and-climb.gif')

    # 9. Walking, running and sprinting, and the same gaits dragged by water.
    def glide(px_per_ds):
        return lambda t: ((t * px_per_ds) % 128 - 48, 0)
    def gait(keys):
        return repeat(keys_track(keys), sum(k[4] for k in keys), sum(k[4] for k in keys))
    walk = gait([(0, 1, 0, 1, 2, 'sine_out'), (0, 0, 0, 1, 2, 'sine_in')])
    run = gait([(0, 2, 0, 1, 1.5, 'quad_out'), (0, 0, 0, 1, 1.5, 'quad_in')])
    sprint = gait([(0, 1, 0, 1, 1, 'quad_out'), (0, 0, 0, 1, 1, 'quad_in')])
    wade_walk = gait([(0, -1, 0, 1, 3, 'sine_in'), (0, 0, 0, 1, 3, 'sine_out')])
    wade_run = gait([(0, -1, 0, 1, 2, 'quad_in'), (0, 0, 0, 1, 2, 'quad_out')])
    save(panels([
        ('Walk: 1px hop, 4 ds', [(east, 1, 1, walk, glide(7))], []),
        ('Run: 2px hop, 3 ds', [(east, 1, 1, run, glide(10))], []),
        ('Sprint: 1px hop, 2 ds', [(east, 1, 1, sprint, glide(14))], []),
        ('Wading walk: 1px sink, 6 ds', [(east, 1, 1, wade_walk, glide(4))], [], True),
        ('Wading run: 1px sink, 4 ds', [(east, 1, 1, wade_run, glide(6))], [], True),
    ], 36, (4, 3)), out / 'gaits.gif')

    # 10. Firing, throwing, shoves, stooping, kneeling and hauling.
    for mine, name in ((matrix(-2, 0, -5), 'fire_east'), (matrix(3, 0, 6), 'throw_east'),
                       (matrix(4, 0, 10), 'shove_east'), (matrix(1, 0, 0, squash=0.88), 'stoop_east'),
                       (matrix(1, 0, 0, squash=0.8), 'kneel_east'), (matrix(0, 0, 8), 'haul_east')):
        assert all(abs(x - y) < 1e-3 for x, y in zip(mine, keys[name])), name
    fire = keys_track([(-2, 0, -5, 1, 1, 'quad_out'), (0, 0, 0, 1, 2, 'quad_in')])
    fire_big = keys_track([(-3, 0, -5, 1, 1, 'quad_out'), (0, 0, 0, 1, 2, 'quad_in')])
    throw = keys_track([(-1, 0, 0, 1, 1, 'linear'), (3, 0, 6, 1, 1, 'quad_out'), (0, 0, 0, 1, 2, 'quad_in')])
    throw_s = keys_track([(0, 1, 0, 1, 1, 'linear'), (0, -3, 0, 0.96, 1, 'quad_out'), (0, 0, 0, 1, 2, 'quad_in')])
    shoved = keys_track([(4, 0, 10, 1, 2, 'quad_out'), (0, 0, 0, 1, 3, 'sine_in')])
    stoop = keys_track([(1, 0, 0, 0.88, 2, 'sine_out'), (0, 0, 0, 1, 2, 'sine_in')])
    kneel = keys_track([(1, 0, 0, 0.8, 3, 'sine_out'), (1, 0, 0, 0.8, 14, 'linear'), (0, 0, 0, 1, 3, 'sine_in')])
    heave = keys_track([(0, 0, 8, 1, 2, 'quad_out'), (0, 0, 8, 1, 3, 'linear'), (0, 0, 0, 1, 2, 'sine_in')])
    shove_push = offset_track([((6, 0), 1), ((0, 0), 2)])
    def shover(t):
        k = (t - 2) % 12
        return shove_push(k) if 0 <= t - 2 and k < 3 else (0, 0)
    def thrown(t):
        k = (t - 2) % 10
        if t < 4 or k < 2:
            return None
        return (min(k - 2, 6) * 14, 4, 0.5, 1.0)
    drag = lambda t: ((t * 3) % 96 - 40, 0)
    save(panels([
        ('Gun: 2px kick, 5 deg back, 3 ds', [(east, 1, 1, repeat(fire, 8, 3, start=2), None)], []),
        ('Large gun: 3px kick', [(east, 1, 1, repeat(fire_big, 8, 3, start=2), None)], []),
        ('Throw: wind-up, 6 deg drive, 4 ds', [(east, 0.5, 1, repeat(throw, 10, 4, start=2), None)], [(tool, 0.5, 1, thrown)]),
        ('Throw facing south: squash', [(south, 1, 1.5, repeat(throw_s, 10, 4, start=2), None)], []),
        ('Shoved: 4px, 10 deg away, 5 ds', [(east, 0, 1, hold(stand), shover), (east, 1, 1, repeat(shoved, 12, 5, start=3), None)], []),
        ('Pick up: stoop, 4 ds', [(east, 0.5, 1, repeat(stoop, 10, 4, start=2), None)], [(tool, 1.5, 1, lambda t: None if (t - 2) % 10 >= 2 and t >= 4 else (0, 0, 0.75, 1.0))]),
        ('Kneel to treat, held', [(east, 0.5, 1, repeat(kneel, 24, 20, start=2), None), (south, 1.5, 1, hold(lying), None)], []),
        ('Hauling a body: heave 8 deg', [(east, 1.5, 1, repeat(heave, 8, 7), drag), (east, 0.5, 1, hold(lying), drag)], []),
    ], 26, (3, 3)), out / 'actions.gif')

    # 11. Jumping, coughs and sneezes, drinking, casting and a mild shock.
    for mine, name in ((matrix(0, -1, 0, squash=0.86), 'jump_crouch'), (matrix(0, 4), 'jump_peak'),
                       (matrix(2, 0, 8, squash=0.94), 'sneeze_east')):
        assert all(abs(x - y) < 1e-3 for x, y in zip(mine, keys[name])), name
    jump = keys_track([(0, -1, 0, 0.86, 1, 'quad_out'), (0, 4, 0, 1, 2, 'quad_out'), (0, 0, 0, 1, 2, 'quad_in'),
                       (0, -1, 0, 0.92, 1, 'linear'), (0, 0, 0, 1, 1, 'sine_out')])
    leap = offset_track([((0, 0), 1), ((32, 0), 4), ((32, 0), 7)])
    def jump_shift(t):
        k = (t - 2) % 14
        if t < 2:
            return (-16, 0)
        return (leap(k)[0] - 16, 0) if k < 12 else (16, 0)
    cough = keys_track([(1, 0, 6, 0.96, 1, 'quad_out'), (0, 0, 0, 1, 1, 'sine'), (1, 0, 6, 0.96, 1, 'quad_out'), (0, 0, 0, 1, 2, 'sine_in')])
    sneeze = keys_track([(-1, 1, 0, 1, 2, 'sine'), (2, 0, 8, 0.94, 1, 'quad_in'), (0, 0, 0, 1, 2, 'sine_out')])
    drink = keys_track([(1, 0, 0, 0.8, 3, 'sine_out'), (1, 0, 0, 0.8, 14, 'linear'), (0, 0, 0, 1, 3, 'sine_in')])
    jolt = keys_track([(-1, 1, 0, 1, 0.5, 'linear'), (1, 1, 0, 1, 1, 'linear'), (-1, 1, 0, 1, 1, 'linear'),
                       (1, 0, 0, 1, 1, 'linear'), (0, 0, 0, 1, 0.5, 'linear')])
    save(panels([
        ('Jump: crouch, 4px rise, land, 7 ds', [(east, 1, 1, repeat(jump, 14, 7, start=2), jump_shift)], []),
        ('Cough: two hunches, 5 ds', [(east, 1, 1, repeat(cough, 10, 5, start=2), None)], []),
        ('Sneeze: breath, snap, 5 ds', [(east, 1, 1, repeat(sneeze, 10, 5, start=2), None)], []),
        ('Drinking from a river, held', [(east, 0.5, 1, repeat(drink, 24, 20, start=2), None)], [], False),
        ('Fishing cast: the throw', [(east, 0.5, 1, repeat(throw, 10, 4, start=2), None)], []),
        ('Mild shock: jitter, 4 ds', [(south, 1, 1, repeat(jolt, 8, 4, start=2), None)], []),
    ], 26, (3, 3)), out / 'everyday.gif')


if __name__ == '__main__':
    main()
