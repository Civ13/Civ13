"""The Bell UH-1 "Huey" seen from above, for the Vietnam air-assault scenes:
an olive-drab US Army slick with both cargo doors slid back and a door gunner
with an M60 on each side.

Every pixel is placed by this script from a fixed palette (Pillow only); no
external or generated artwork. The airframe is described once in its own
coordinates (u across, v along, the rotor mast at 0,0, the nose toward -v)
and painted once per direction, so the light always falls from the upper
left of the screen whichever way the helicopter is heading.

icons/obj/vehicles/huey.dmi, 288x288 frames like aircraft.dmi (the same -128
pixel offsets apply). The mast is the exact centre of the canvas in every
state and direction, so the states overlay one another with no offset:
  uh1                the airframe without rotors, 4 dirs
  uh1_rotor          the turning main rotor, 4 dirs x 4 frames, translucent
  uh1_tailrotor      the turning tail rotor, 4 dirs x 4 frames, translucent
  uh1_shadow         a black silhouette with the rotor disc, 4 dirs
  uh1_rotor_stopped  the main and tail rotor at rest, 4 dirs
  uh1_landed         uh1 with uh1_rotor_stopped already on it, 4 dirs
The nose points the way the object faces (dir NORTH = nose up), as the mi8
and the jets do in aircraft.dmi.

icons/obj/vehicles/huey_icon.dmi holds the 32x32 list icon "uh1_icon" (a DMI
has one frame size, so it cannot share the big sheet).

Run with Pillow to reproduce both files. `--preview <folder>` also writes
review sheets: every state and direction on jungle green at 1x and 2x, the
flying helicopter on a 32px tile grid beside the mi8 and a soldier, and a
looping GIF of the rotors. Released under Civ13 AGPL-3.0.
"""
import math
import re
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]

S = 288                 # frame size
C = S // 2              # the mast sits between pixels C-1 and C on both axes
ROTOR_R = 120           # main rotor radius
ROTOR_FRAMES = 4
ROTOR_DELAY = 0.6       # deciseconds per frame
STOPPED_ANGLE = 28      # degrees the parked blades sit off the centre line

DIRS = ('S', 'N', 'E', 'W')          # BYOND's order for dirs = 4
# how the nose-up painting is turned for each heading, and where the light
# (upper left of the screen) then lies in the airframe's own coordinates
TURN = {'N': None, 'S': Image.ROTATE_180, 'E': Image.ROTATE_270, 'W': Image.ROTATE_90}
LIGHT = {'N': (-1, -1), 'S': (1, 1), 'E': (-1, 1), 'W': (1, -1)}

OUT = (20, 22, 16)
# olive drab: highlight, light, base, shade, dark
OD = [(150, 150, 94), (122, 124, 74), (98, 101, 60), (72, 76, 46), (48, 52, 33)]
ANTIGLARE = (38, 40, 36)
# perspex: dark, mid, glint
GL = [(40, 60, 74), (78, 116, 138), (176, 212, 222)]
GREEN_PANE = (46, 104, 82)
GREEN_GLINT = (110, 170, 140)
INSIDE, FLOOR, SILL = (26, 26, 22), (92, 90, 76), (58, 60, 46)
SEAT, SEAT2 = (150, 62, 44), (104, 40, 32)
SKID, SKID_LIT = (44, 46, 42), (92, 96, 90)
MESH, MESH2 = (128, 130, 118), (70, 72, 64)
SOOT, PIPE = (22, 20, 18), (98, 94, 86)
HUB, HUB_RING, HUB_LIT = (30, 32, 30), (58, 60, 54), (130, 132, 124)
BEACON = (206, 44, 38)
YELLOW = (220, 186, 52)
HELMET, HELMET_LIT, VEST, SLEEVE = (82, 98, 56), (136, 148, 92), (46, 56, 36), (110, 118, 70)
SKIN = (198, 152, 114)
GUN, GUN_BODY, GUN_LIT, MOUNT = (20, 20, 22), (40, 40, 44), (96, 96, 102), (112, 114, 108)
BRASS, AMMO_CAN = (206, 168, 72), (60, 68, 40)
BLADE, BLADE_LIT, BLADE_DARK = (44, 48, 40), (84, 88, 74), (28, 30, 26)
BLUR, BLUR_GLINT = (24, 26, 22), (214, 220, 204)
# preview
JUNGLE, JUNGLE2, JUNGLE3 = (52, 92, 46), (44, 80, 40), (62, 104, 52)


def smooth(t):
    return t * t * (3 - 2 * t)


def hull_half_width(v):
    """Half the width of the fuselage at floor level, nose (-68) to fin (142)."""
    if v < -68 or v > 142:
        return None
    if v < -34:
        t = (-34 - v) / 34.0
        return 26 * (1 - t ** 2.4) ** (1 / 2.4)
    if v <= 36:
        return 26.0
    if v <= 70:
        return 26 + (6.5 - 26) * smooth((v - 36) / 34.0)
    if v <= 134:
        return 6.5 + (3.5 - 6.5) * (v - 70) / 64.0
    return 3.5 + (2.0 - 3.5) * (v - 134) / 8.0


def roof_half_width(v):
    """The cabin roof is narrower than the floor (the sides lean in)."""
    if v < -44 or v > 36:
        return None
    if v < -38:
        return 19 - (-38 - v) * 0.6
    return 19.0


def cowl_half_width(v):
    """The transmission and engine cowling down the middle of the roof."""
    if v < -12 or v > 66:
        return None
    if v < -8:
        return 9 * math.sqrt(max(0.0, 1 - ((-8 - v) / 4.0) ** 2))
    if v <= 40:
        return 9.0
    return 9 + (4.5 - 9) * (v - 40) / 26.0


def tone(n, light, flat=2):
    """Olive shade for a surface leaning toward n: lighter when it faces the light."""
    d = (n[0] * light[0] + n[1] * light[1]) / math.sqrt(2)
    if d > 0.3:
        return OD[flat - 1]
    if d < -0.3:
        return OD[flat + 1]
    return OD[flat]


def airframe_pixel(u, v, light):
    """Colour of the airframe at (u, v), or None where there is nothing."""
    a = abs(u)
    side = 1 if u >= 0 else -1
    c = None

    # landing skids and their cross tubes, under everything
    if 29 <= a < 31 and -38 <= v <= 44:
        c = SKID_LIT if (side * light[0] > 0 and a >= 30) else SKID
    if 24 <= a < 31 and (-22 <= v < -20 or 28 <= v < 30):
        c = SKID

    # horizontal stabiliser
    if 99 <= v <= 109 and a <= 25 and not (a > 23 and not 100.5 <= v <= 107.5):
        c = OD[2]
        if v < 100.5:
            c = tone((0, -1), light)
        elif v > 107.5:
            c = tone((0, 1), light)
        elif 104 <= v < 105:
            c = OD[3]

    w = hull_half_width(v)
    if w is not None and a <= w:
        w0, w1 = hull_half_width(v - 0.5), hull_half_width(v + 0.5)
        dw = (w1 if w1 is not None else w) - (w0 if w0 is not None else w)
        g = math.hypot(1, dw)
        n = (side / g, -dw / g)
        d = (w - a) / g
        if v > 70:                                   # tail boom and fin
            c = tone(n, light) if d < 1.8 else OD[2]
            if a < 1:
                c = OD[1] if int(v) % 13 else OD[3]  # drive shaft cover and its joints
            if v > 126:
                c = OD[4] if a < 1 else tone((side, 0), light)
            if 112 <= v < 114:
                c = YELLOW                           # tail rotor warning band
        else:
            c = tone(n, light) if d < 2.2 else OD[2]
            if 2.2 <= d < 5 and tone(n, light) == OD[3]:
                c = OD[3]

        rw = roof_half_width(v)
        if v < -44:                                  # nose cap and windshield
            glass = (u / 23.0) ** 2 + ((v + 34) / 27.0) ** 2
            if glass <= 1 and a < w - 2:
                c = GL[1]
                if v < -55 and a < 15:
                    c = GL[0]                        # the glare shield under the perspex
                for hx in (-11, 11):                 # the pilots
                    hd = math.hypot(u - hx, v + 48.5)
                    if hd < 3.6:
                        c = (58, 78, 62)
                        if hd < 1.6 and (u - hx) * light[0] + (v + 48.5) * light[1] > 0:
                            c = (96, 118, 92)
                k = int(math.floor(u - v * 0.7)) % 19
                if k == 0 and u * light[0] > 0:
                    c = GL[2]
                if glass > 0.9:
                    c = OD[4]                        # windshield frame
                if a < 1:
                    c = OD[3]                        # centre post
            elif d >= 2.2:
                c = ANTIGLARE
        elif rw is not None and a > rw:              # the leaning cabin sides
            if v < -27:
                if 20.5 < a < w - 1.6 and -42 < v < -29:
                    c = GL[1] if int(math.floor(v)) % 5 else GL[0]   # pilot's door window
                    if side * light[0] > 0 and int(math.floor(v)) in (-39, -38):
                        c = GL[2]
            elif -24 <= v < 22:                      # the open cargo doorway
                if a < rw + 2:
                    c = INSIDE
                elif a > w - 1.3:
                    c = SILL
                else:
                    c = FLOOR
                    if -19 <= v < -14 or -7 <= v < -2:
                        c = SEAT if a < w - 2.5 else SEAT2           # troop seat ends
            else:
                c = tone((side, 0), light, 2)
        elif rw is not None:                         # the roof
            c = OD[1]
            if rw - a < 1.5:
                c = tone((side, 0), light, 1)
            fv = int(math.floor(v))
            if fv in (-25, 22):
                c = OD[3]                            # panel lines over the door posts
            if -43 < v < -35 and 4 < a < 15:
                c = GREEN_PANE                       # tinted panes over the pilots
                if int(math.floor(a)) == 8 and fv in (-41, -40) and side * light[0] > 0:
                    c = GREEN_GLINT

        cw = cowl_half_width(v)
        if cw is not None and a <= cw:
            c = OD[1]
            edge = cw - a
            lit = side * light[0] > 0
            if edge < 1:
                c = OD[0] if lit else OD[4]
            elif edge < 2:
                c = OD[0] if lit else OD[3]
            if v < -10.5:
                c = tone((0, -1), light, 1)
            if 20 <= v <= 33 and 3 <= a <= 7:
                c = MESH if (int(math.floor(u)) + int(math.floor(v))) % 2 else MESH2
            if a < 1 and 46 <= v < 48:
                c = BEACON
        ex = math.hypot(u / 3.5, (v - 63.5) / 4.5)   # exhaust
        if ex <= 1.35:
            c = SOOT if ex <= 1 else PIPE
        r = math.hypot(u, v)                         # mast and swashplate
        if r <= 6.5:
            c = HUB_RING
        if r <= 4.5:
            c = HUB
        if r < 1.2:
            c = HUB_LIT

    # cargo doors slid back along the outside of the fuselage
    if 21 <= v <= 46 and a <= 28.5 and a > 26 - 0.01:
        c = tone((side, 0), light, 2)
        if 27 <= v <= 40:
            c = GL[0]
        if v < 22 or v > 45:
            c = OD[4]
    elif 36 < v <= 46 and w is not None and w < a <= 26:
        c = OD[3]                                    # the door's inner face over the taper

    # tail rotor gearbox on the left of the fin
    if -6 <= u < -3 and 126 <= v < 130:
        c = HUB_RING
    return c


class Canvas:
    """One nose-up frame. i counts pixels out from the centre line (mirrored
    by side), j counts pixels aft of the mast (negative toward the nose)."""

    def __init__(self):
        self.px = {}

    def put(self, i, j, c, side=1, a=255):
        x = C + i if side > 0 else C - 1 - i
        y = C + j
        if 0 <= x < S and 0 <= y < S:
            self.px[(x, y)] = (c[0], c[1], c[2], a)

    def pts(self, c, side, *points):
        for i, j in points:
            self.put(i, j, c, side)

    def line(self, i0, j0, i1, j1, c, side):
        n = max(abs(i1 - i0), abs(j1 - j0), 1)
        for k in range(n + 1):
            self.put(int(round(i0 + (i1 - i0) * k / n)), int(round(j0 + (j1 - j0) * k / n)), c, side)

    def outline(self, c=OUT):
        edge = set()
        for (x, y) in self.px:
            for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if n not in self.px and 0 <= n[0] < S and 0 <= n[1] < S:
                    edge.add(n)
        for p in edge:
            self.px[p] = c + (255,)
        return self

    def image(self):
        im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        for p, c in self.px.items():
            im.putpixel(p, c)
        return im


def door_gunner(cv, side, light):
    """A gunner sitting in the aft corner of the doorway behind a pintle M60."""
    lit_side = side * light[0] > 0
    # flak vest and shoulders, then the helmet over them
    for j in range(9, 18):
        for i in range(19, 24):
            if (i, j) not in ((19, 9), (19, 17), (23, 9), (23, 17)):
                cv.put(i, j, VEST, side)
    cv.pts(SLEEVE, side, (22, 9), (23, 10), (22, 17), (23, 16))
    for j in range(10, 17):
        for i in range(18, 25):
            if math.hypot(i - 21, j - 13) <= 3.3:
                cv.put(i, j, HELMET, side)
    hl = 20 if (side > 0) == (light[0] < 0) else 22
    cv.pts(HELMET_LIT, side, (hl, 12 if light[1] < 0 else 14), (21, 12 if light[1] < 0 else 14))
    # arms out to the spade grips
    cv.line(24, 11, 25, 12, SLEEVE, side)
    cv.line(24, 15, 25, 14, SLEEVE, side)
    cv.pts(SKIN, side, (26, 12), (26, 14))
    # ammunition can and the belt up to the feed tray
    for j in range(15, 19):
        for i in range(28, 31):
            cv.put(i, j, AMMO_CAN, side)
    cv.pts(OD[1] if lit_side else OD[3], side, (28, 15), (29, 15), (30, 15))
    cv.pts(BRASS, side, (29, 14), (30, 13), (29, 16))
    # the M60: receiver, pintle, barrel angled a little forward
    cv.line(27, 13, 33, 11, GUN_BODY, side)
    cv.line(27, 12, 33, 10, GUN_BODY, side)
    cv.pts(MOUNT, side, (29, 13), (30, 13), (29, 12))
    cv.pts(GUN_LIT, side, (31, 11) if light[1] < 0 else (31, 12))
    cv.line(34, 10, 41, 8, GUN, side)
    cv.pts(GUN, side, (37, 10), (38, 10), (42, 8), (42, 7))     # gas cylinder, flash hider


def airframe(light):
    cv = Canvas()
    for y in range(S):
        for x in range(S):
            c = airframe_pixel(x - C + 0.5, y - C + 0.5, light)
            if c is not None:
                cv.px[(x, y)] = c + (255,)
    for side in (1, -1):
        door_gunner(cv, side, light)
    return cv.outline()


def step(alpha, size=16):
    """Opacity in a few flat steps rather than a smooth gradient."""
    return int(max(0, min(255, round(alpha / float(size)) * size)))


def rotor_frame(f):
    """The turning main rotor: a faint disc, the two blades and the smear
    each drags behind it. Blades turn anticlockwise seen from above."""
    theta = 20 + f * (180.0 / ROTOR_FRAMES)
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    for y in range(S):
        for x in range(S):
            dx, dy = x - C + 0.5, y - C + 0.5
            r = math.hypot(dx, dy)
            if r > ROTOR_R:
                continue
            phi = math.degrees(math.atan2(-dy, dx))
            behind = (theta - phi) % 180.0              # degrees behind the nearer blade
            col, alpha = BLUR, 30
            if 50 < r < ROTOR_R - 4 and 124 < phi < 142:
                col, alpha = BLUR_GLINT, 24             # sunlight on the disc
            if r > ROTOR_R - 1.5:
                alpha = 52                              # the tip path
            tip = r > ROTOR_R - 8
            if behind < 64:
                smear = 150 * (1 - behind / 64.0) ** 1.4
                if smear > alpha:
                    alpha = smear
                    col = YELLOW if tip else BLUR
            ahead = 180.0 - behind                      # a little glow ahead of the blade too
            if ahead < 10:
                glow = 110 * (1 - ahead / 10.0)
                if glow > alpha:
                    alpha = glow
                    col = YELLOW if tip else BLUR
            across = r * math.sin(math.radians(min(behind, 90.0)))
            if across < 4.2 and behind < 60:
                col, alpha = (YELLOW if tip else BLADE_DARK), 204
            if r < 21:                                  # stabiliser bar
                alpha = max(alpha, 60)
            if r < 5.2:
                col, alpha = HUB, 255
            if r < 1.6:
                col = HUB_LIT
            alpha = alpha if alpha == 255 else step(alpha, 12)
            if alpha:
                im.putpixel((x, y), col + (alpha,))
    return im


TAIL_U, TAIL_V, TAIL_HALF = -8.5, 127.0, 15.0


def tail_rotor_frame(f):
    """The tail rotor, edge on from above: the blade's shadow on the page
    lengthens and shortens as it turns, over a faint full-length ghost."""
    reach = (1.0, 0.72, 0.36, 0.72)[f % 4] * TAIL_HALF
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    for y in range(S):
        for x in range(S):
            u, v = x - C + 0.5, y - C + 0.5
            du, dv = abs(u - TAIL_U), abs(v - TAIL_V)
            if dv > TAIL_HALF or du > 1.6:
                continue
            col, alpha = BLUR, 44
            if du < 1.1 and dv <= reach:
                alpha = 150
                if dv > reach - 2:
                    col = YELLOW
            if du < 1.1 and dv < 1.6:
                col, alpha = HUB, 255
            im.putpixel((x, y), col + (alpha,))
    return im


def stopped_rotor(light):
    """Both rotors at rest: two plain blades, the stabiliser bar across them."""
    cv = Canvas()
    ang = math.radians(STOPPED_ANGLE)
    bx, by = math.sin(ang), -math.cos(ang)              # along the blades
    for y in range(S):
        for x in range(S):
            u, v = x - C + 0.5, y - C + 0.5
            along = u * bx + v * by
            across = -u * by + v * bx
            r = math.hypot(u, v)
            c = None
            if abs(along) <= ROTOR_R and abs(across) <= (4.6 if abs(along) < 16 else 3.6):
                lit = across * (-by * light[0] + bx * light[1])
                c = BLADE
                if abs(across) > 2.2:
                    c = BLADE_LIT if lit > 0 else BLADE_DARK
                if abs(along) > ROTOR_R - 7:
                    c = YELLOW
            if abs(across) <= 21 and abs(along) <= 1.1:
                c = HUB_RING                            # stabiliser bar
            if 18 <= abs(across) <= 22 and abs(along) <= 2.2:
                c = HUB                                 # and its weights
            if r <= 6.2:
                c = HUB
            if r < 1.6:
                c = HUB_LIT
            if abs(u - TAIL_U) < 1.1 and abs(v - TAIL_V) <= TAIL_HALF:
                c = YELLOW if abs(v - TAIL_V) > TAIL_HALF - 2 else BLADE
                if abs(v - TAIL_V) < 1.6:
                    c = HUB
            if c is not None:
                cv.px[(x, y)] = c + (255,)
    return cv.outline()


def turned(im, d):
    return im if TURN[d] is None else im.transpose(TURN[d])


def shadow(body, disc):
    """A black silhouette of the airframe with the rotor disc around it."""
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    bp, dp, out = body.load(), disc.load(), im.load()
    for y in range(S):
        for x in range(S):
            if bp[x, y][3]:
                out[x, y] = (0, 0, 0, 176)
            elif dp[x, y][3]:
                out[x, y] = (0, 0, 0, 48)
    return im


def build():
    """state -> (frames, delay); a frame is the four directions in DIRS order."""
    body = {d: turned(airframe(LIGHT[d]).image(), d) for d in DIRS}
    spin = [rotor_frame(f) for f in range(ROTOR_FRAMES)]
    tail = [tail_rotor_frame(f) for f in range(ROTOR_FRAMES)]
    rest = {d: turned(stopped_rotor(LIGHT[d]).image(), d) for d in DIRS}
    landed = {}
    for d in DIRS:
        landed[d] = body[d].copy()
        landed[d].alpha_composite(rest[d])
    disc = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    for y in range(S):
        for x in range(S):
            if math.hypot(x - C + 0.5, y - C + 0.5) <= ROTOR_R:
                disc.putpixel((x, y), (0, 0, 0, 255))
    return [
        ('uh1', [[body[d] for d in DIRS]], None),
        ('uh1_rotor', [[im for d in DIRS] for im in spin], ROTOR_DELAY),
        ('uh1_tailrotor', [[turned(im, d) for d in DIRS] for im in tail], ROTOR_DELAY),
        ('uh1_shadow', [[shadow(body[d], disc) for d in DIRS]], None),
        ('uh1_rotor_stopped', [[rest[d] for d in DIRS]], None),
        ('uh1_landed', [[landed[d] for d in DIRS]], None),
    ]


def write_dmi(path, states, size, columns):
    cells = [im for _, frames, _ in states for fr in frames for im in fr]
    rows = (len(cells) + columns - 1) // columns
    sheet = Image.new('RGBA', (size * columns, size * rows), (0, 0, 0, 0))
    for n, im in enumerate(cells):
        sheet.paste(im, ((n % columns) * size, (n // columns) * size))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = %d\n\theight = %d\n' % (size, size)
    for name, frames, delay in states:
        text += 'state = "%s"\n\tdirs = %d\n\tframes = %d\n' % (name, len(frames[0]), len(frames))
        if delay is not None and len(frames) > 1:
            text += '\tdelay = %s\n' % ','.join('%g' % delay for _ in frames)
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta, optimize=True)


# ---------------------------------------------------------------- list icon

def list_icon():
    """32x32 "uh1_icon": the same helicopter, nose up, redrawn by hand."""
    im = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
    px = {}

    def box(x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                px[(x, y)] = c

    box(12, 5, 19, 15, OD[2])                # cabin
    box(13, 4, 18, 4, OD[2])
    box(14, 3, 17, 3, OD[2])
    box(13, 16, 18, 17, OD[2])               # engine deck tapering to the boom
    box(14, 18, 17, 19, OD[2])
    box(15, 20, 16, 29, OD[2])               # tail boom
    box(12, 25, 19, 26, OD[2])               # stabiliser
    box(13, 5, 18, 6, GL[1])                 # windshield
    box(14, 4, 17, 4, GL[1])
    px[(14, 5)] = GL[2]
    box(13, 7, 18, 14, OD[1])                # roof
    box(12, 9, 12, 13, INSIDE)               # open doors
    box(19, 9, 19, 13, INSIDE)
    box(15, 10, 16, 18, OD[0])               # cowling
    px[(15, 19)] = SOOT
    px[(16, 19)] = SOOT
    for y in range(7, 15):
        px[(18, y)] = OD[2]                  # shaded side of the roof
    for y in range(20, 30):
        px[(16, y)] = OD[3]
    px[(14, 28)] = BLADE                     # tail rotor
    px[(14, 27)] = BLADE
    px[(14, 29)] = BLADE
    for x in (10, 9):                        # door guns
        px[(x, 12)] = GUN
        px[(31 - x, 12)] = GUN
    px[(11, 12)] = HELMET
    px[(20, 12)] = HELMET
    edge = set()
    for (x, y) in px:
        for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if n not in px and 0 <= n[0] < 32 and 0 <= n[1] < 32:
                edge.add(n)
    for p in edge:
        px[p] = OUT
    for p, c in px.items():
        im.putpixel(p, c + (255,))
    # the rotor over it: two blades and a faint disc
    top = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
    for y in range(32):
        for x in range(32):
            dx, dy = x - 15.5, y - 11.5
            r = math.hypot(dx, dy)
            if r <= 11.6:
                top.putpixel((x, y), BLUR + (40,))
            if r <= 11.6 and abs(dx * 0.80 + dy * 0.60) < 0.75:
                top.putpixel((x, y), (YELLOW if r > 10 else BLADE_DARK) + (255,))
            if r < 1.5:
                top.putpixel((x, y), HUB + (255,))
    im.alpha_composite(top)
    return im


# ------------------------------------------------------------------ preview

def jungle(w, h):
    im = Image.new('RGBA', (w, h), JUNGLE + (255,))
    for n in range(w * h // 40):
        x, y = (n * 7919 + 13) % w, (n * 104729 + 7) % h
        im.putpixel((x, y), (JUNGLE2 if n % 3 else JUNGLE3) + (255,))
    return im


def grid(im, colour=(30, 56, 28, 255)):
    for x in range(0, im.width, 32):
        for y in range(im.height):
            im.putpixel((x, y), colour)
    for y in range(0, im.height, 32):
        for x in range(im.width):
            im.putpixel((x, y), colour)
    return im


def dmi_cell(path, state, d=0, size=32):
    """One direction of the first frame of a state in an existing sheet."""
    im = Image.open(path)
    text = im.info['Description']
    im = im.convert('RGBA')
    index = 0
    for name, dirs, count in re.findall(r'state = "(.*)"\n\tdirs = (\d+)\n\tframes = (\d+)', text):
        if name == state:
            n = index + d
            x, y = (n % (im.width // size)) * size, (n // (im.width // size)) * size
            return im.crop((x, y, x + size, y + size))
        index += int(dirs) * int(count)
    raise KeyError(state)


def flying(states, d, f=0):
    s = dict((name, frames) for name, frames, _ in states)
    im = s['uh1'][0][d].copy()
    im.alpha_composite(s['uh1_tailrotor'][f][d])
    im.alpha_composite(s['uh1_rotor'][f][d])
    return im


def preview(folder, states, icon):
    folder = Path(folder)
    folder.mkdir(parents=True, exist_ok=True)
    s = dict((name, frames) for name, frames, _ in states)
    gap = 6

    def sheet(cells, columns, scale, name):
        rows = (len(cells) + columns - 1) // columns
        out = Image.new('RGBA', (columns * (S + gap) + gap, rows * (S + gap) + gap), (24, 28, 24, 255))
        for n, cell in enumerate(cells):
            tile = jungle(S, S)
            tile.alpha_composite(cell)
            out.paste(tile, (gap + (n % columns) * (S + gap), gap + (n // columns) * (S + gap)))
        if scale != 1:
            out = out.resize((out.width * scale, out.height * scale), Image.NEAREST)
        out.save(folder / name)

    for scale in (1, 2):
        tag = '%dx' % scale
        # the flying helicopter: airframe + rotor + tail rotor, S N E W
        sheet([flying(states, d) for d in range(4)], 4, scale, 'huey_flying_%s.png' % tag)
        # every state, one row each (first frame), S N E W
        cells = []
        for name in ('uh1', 'uh1_rotor', 'uh1_tailrotor', 'uh1_shadow', 'uh1_rotor_stopped', 'uh1_landed'):
            cells += s[name][0]
        sheet(cells, 4, scale, 'huey_states_%s.png' % tag)
        # the animated states frame by frame (north), and the composite
        cells = [s['uh1_rotor'][f][1] for f in range(ROTOR_FRAMES)]
        cells += [s['uh1_tailrotor'][f][1] for f in range(ROTOR_FRAMES)]
        cells += [flying(states, 1, f) for f in range(ROTOR_FRAMES)]
        sheet(cells, 4, scale, 'huey_rotor_frames_%s.png' % tag)
    for d, name in enumerate(DIRS):
        for scale in (1, 2):
            tile = jungle(S, S)
            tile.alpha_composite(flying(states, d))
            tile.resize((S * scale, S * scale), Image.NEAREST).save(
                folder / ('huey_flying_%s_%dx.png' % (name, scale)))
            tile = jungle(S, S)
            tile.alpha_composite(s['uh1_landed'][0][d])
            tile.resize((S * scale, S * scale), Image.NEAREST).save(
                folder / ('huey_landed_%s_%dx.png' % (name, scale)))

    # scale check: 1x on a 32px tile grid with the mi8 and a soldier
    aircraft = ROOT / 'icons/obj/vehicles/aircraft.dmi'
    man = dmi_cell(ROOT / 'icons/mob/human.dmi', 'human_m_s')
    out = grid(jungle(S * 3 + 64, S + 64 + S))
    out.alpha_composite(s['uh1'][0][1], (32, 32))
    out.alpha_composite(flying(states, 1), (32 + S, 32))
    out.alpha_composite(dmi_cell(aircraft, 'mi8', 1, S), (32 + 2 * S, 32))
    out.alpha_composite(s['uh1_landed'][0][2], (32, 32 + S))
    out.alpha_composite(flying(states, 3), (32 + S, 32 + S))
    out.alpha_composite(dmi_cell(aircraft, 'mi8', 2, S), (32 + 2 * S, 32 + S))
    for x, y in ((32 + C + 48, 32 + C), (32 + C - 80, 32 + C - 16), (32 + S + C + 64, 32 + S + C + 64),
                 (32 + C, 32 + S + C + 48), (32 + C + 32, 32 + S + C + 48)):
        out.alpha_composite(man, (x // 32 * 32, y // 32 * 32))
    out.alpha_composite(icon, (0, 0))
    out.save(folder / 'huey_scale_grid_1x.png')
    out.resize((out.width * 2, out.height * 2), Image.NEAREST).save(folder / 'huey_scale_grid_2x.png')

    big = jungle(32, 32)
    big.alpha_composite(icon)
    big.resize((256, 256), Image.NEAREST).save(folder / 'huey_icon_8x.png')

    # the rotors turning, north and east
    frames = []
    for f in range(ROTOR_FRAMES):
        tile = jungle(S * 2, S)
        tile.alpha_composite(flying(states, 1, f), (0, 0))
        tile.alpha_composite(flying(states, 2, f), (S, 0))
        frames.append(tile.convert('RGB'))
    frames[0].save(folder / 'huey_flying.gif', save_all=True, append_images=frames[1:],
                   duration=int(ROTOR_DELAY * 100), loop=0)


if __name__ == '__main__':
    states = build()
    icon = list_icon()
    write_dmi(ROOT / 'icons/obj/vehicles/huey.dmi', states, S, 8)
    write_dmi(ROOT / 'icons/obj/vehicles/huey_icon.dmi', [('uh1_icon', [[icon]], None)], 32, 1)
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1], states, icon)
