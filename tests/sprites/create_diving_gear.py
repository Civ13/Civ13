"""Hand-placed 32px diving gear: diving dress, copper diving helmet, hard dive
suit and helmet, twin air bottles. Every pixel is placed by this script from a
fixed palette (Pillow only); no external or generated artwork. The steel, glass
and orange accent shades are the submarine hull palette, so the hard suit reads
as part of the same kit.

Run with Pillow to reproduce icons/obj/clothing/diving.dmi (item icons) and
icons/mob/diving.dmi (worn, four directions). `--preview <png>` also writes a
review sheet of the gear worn on the base body. Released under Civ13 AGPL-3.0.
"""
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]

OUT = (16, 20, 26)
# rubberised canvas
C = [(216, 198, 152), (184, 162, 114), (144, 124, 84), (104, 88, 58), (58, 48, 34)]
# brass
B = [(244, 212, 116), (204, 160, 70), (152, 110, 42), (100, 70, 26), (56, 38, 14)]
# copper
K = [(246, 182, 124), (210, 132, 78), (164, 92, 52), (110, 60, 36), (60, 32, 20)]
# black rubber
R = [(96, 98, 102), (66, 68, 74), (44, 46, 52), (30, 32, 38), (14, 16, 20)]
# lead and bare steel
L = [(186, 192, 200), (140, 148, 158), (98, 106, 118), (66, 74, 86), (30, 36, 44)]
# boot leather
T = [(134, 92, 56), (96, 64, 38), (66, 44, 26), (44, 30, 18), (24, 16, 10)]
# submarine hull steel (draw_sub.py H1-H4), accent and glass
H = [(112, 128, 140), (84, 99, 112), (60, 72, 84), (40, 49, 59), OUT]
RIV = (136, 150, 160)
ACC, ACC2 = (232, 150, 40), (178, 104, 24)
G = [(188, 240, 244), (110, 200, 214), (58, 146, 170), (34, 98, 124)]
YEL = (240, 208, 64)
LENS = (255, 244, 176)


class Frame:
    def __init__(self):
        self.px = {}

    def put(self, x, y, c):
        if 0 <= x < 32 and 0 <= y < 32:
            self.px[(x, y)] = c

    def pts(self, c, *points):
        for x, y in points:
            self.put(x, y, c)

    def h(self, y, x0, x1, c):
        for x in range(x0, x1 + 1):
            self.put(x, y, c)

    def v(self, x, y0, y1, c):
        for y in range(y0, y1 + 1):
            self.put(x, y, c)

    def part(self, rows, ramp, shade='lr'):
        """Fill a shape given as {y: (x0, x1)} (or a list of spans per row):
        dark outline, then banded left-lit shading across each row."""
        mask = set()
        for y, spans in rows.items():
            if isinstance(spans, tuple):
                spans = [spans]
            for x0, x1 in spans:
                for x in range(x0, x1 + 1):
                    mask.add((x, y))
        ys = sorted({y for _, y in mask})
        for y in ys:
            xs = sorted(x for x, yy in mask if yy == y)
            inner = [x for x in xs if all(n in mask for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))]
            for x in xs:
                if x not in inner:
                    self.put(x, y, ramp[4])
            runs, run = [], []
            for x in inner:
                if run and x != run[-1] + 1:
                    runs.append(run)
                    run = []
                run.append(x)
            if run:
                runs.append(run)
            for run in runs:
                n = len(run)
                for i, x in enumerate(run):
                    t = (i + 0.5) / n
                    if shade == 'flat':
                        k = 1
                    elif shade == 'rl':
                        k = 0 if t > 0.7 else 1 if t > 0.35 else 2 if t > 0.1 else 3
                    else:
                        k = 0 if t < 0.3 else 1 if t < 0.65 else 2 if t < 0.9 else 3
                    self.put(x, y, ramp[k])
        return mask

    def ball(self, rows, ramp, lx, ly, r=(2.2, 4.6, 7.2)):
        """A dome: outline, then shading by distance from the light spot."""
        mask = self.part(rows, ramp, 'flat')
        for (x, y) in mask:
            if self.px[(x, y)] == ramp[4]:
                continue
            d = ((x - lx) ** 2 + (y - ly) ** 2) ** 0.5
            self.put(x, y, ramp[0] if d < r[0] else ramp[1] if d < r[1] else ramp[2] if d < r[2] else ramp[3])
        return mask

    def mirror(self):
        f = Frame()
        f.px = {(31 - x, y): c for (x, y), c in self.px.items()}
        return f

    def shift(self, dx, dy):
        f = Frame()
        f.px = {(x + dx, y + dy): c for (x, y), c in self.px.items() if 0 <= x + dx < 32 and 0 <= y + dy < 32}
        return f

    def image(self):
        im = Image.new('RGBA', (32, 32))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c + (255,))
        return im


def sym(rows):
    """Mirror left-hand spans about the body's centre column (x = 15)."""
    out = {}
    for y, (x0, x1) in rows.items():
        out[y] = [(x0, x1), (30 - x1, 30 - x0)]
    return out


def both(f, c, *points):
    for x, y in points:
        f.put(x, y, c)
        f.put(30 - x, y, c)


# ---------------------------------------------------------------- diving dress

def dress_front(back=False):
    f = Frame()
    # baggy canvas legs and crotch
    f.part({22: (10, 20), 23: (10, 20)}, C)
    f.part(sym({y: (10, 14) for y in range(23, 29)}), C)
    f.h(23, 11, 19, C[1]); f.pts(C[0], (11, 23), (12, 23)); f.pts(C[2], (18, 23), (19, 23))
    f.pts(C[4], (15, 24), (15, 23))
    # canvas folds at the knees and shins
    both(f, C[3], (12, 25), (13, 26))
    f.pts(C[3], (17, 25), (18, 26))
    # weighted boots: leather uppers, brass toe caps, lead soles
    f.part(sym({28: (9, 14), 29: (8, 14), 30: (8, 14), 31: (8, 14)}), T)
    for x0 in (9, 17):
        f.h(31, x0, x0 + 4, L[2])
    f.pts(L[1], (9, 31), (17, 31))
    if not back:
        f.h(30, 9, 11, B[1]); f.put(9, 30, B[0]); f.h(30, 19, 21, B[2]); f.put(19, 30, B[1])
        both(f, B[2], (12, 28))          # ankle strap buckles
    else:
        f.h(30, 9, 13, T[2]); f.h(30, 17, 21, T[3])
    # torso
    f.part({11: (10, 20), 12: (9, 21), 13: (9, 21), 14: (10, 20), 15: (10, 20), 16: (10, 20), 17: (10, 20),
            18: (10, 20), 19: (10, 20), 20: (10, 20), 21: (10, 20)}, C)
    # arms, rubber cuffs and gloves
    f.part(sym({12: (8, 9), 13: (7, 9), 14: (6, 9), 15: (6, 9), 16: (6, 9), 17: (6, 9), 18: (6, 9)}), C)
    f.part(sym({18: (6, 9), 19: (6, 9), 20: (6, 9), 21: (7, 9)}), R)
    f.h(18, 7, 8, R[0]); f.h(18, 22, 23, R[1])
    # weight belt
    f.h(20, 11, 19, T[2]); f.pts(T[1], (11, 20), (12, 20)); f.pts(T[3], (19, 20))
    f.pts(L[1], (12, 20), (18, 20)); f.pts(L[2], (13, 20), (17, 20))
    if not back:
        f.pts(B[1], (15, 20))
        # lead chest weight on its lanyards
        f.part({15: (13, 17), 16: (13, 17), 17: (13, 17), 18: (14, 16)}, L[:4] + [L[3]], 'flat')
        f.pts(L[0], (14, 16), (15, 16)); f.pts(L[1], (16, 16), (14, 17)); f.pts(L[2], (15, 17), (16, 17))
        f.pts(T[3], (13, 14), (17, 14))
    else:
        f.part({15: (13, 17), 16: (13, 17), 17: (13, 17)}, L, 'flat')
        f.pts(L[1], (14, 16), (15, 16)); f.pts(L[2], (16, 16))
        f.v(15, 18, 19, C[3])
    # brass breastplate (corselet) with its studs
    f.part({10: (11, 19), 11: (10, 20), 12: (9, 21), 13: (10, 20), 14: (12, 18)}, B)
    f.h(10, 12, 18, B[2]); f.pts(B[1], (12, 10), (13, 10))
    f.pts(B[0], (11, 12), (13, 12), (15, 13), (12, 11)); f.pts(B[3], (17, 13), (19, 12))
    if back:
        f.h(14, 12, 18, C[4]); f.h(14, 13, 17, B[3])
    return f


def dress_side():
    f = Frame()
    f.part({y: (12, 18) for y in range(21, 29)}, C)
    f.pts(C[3], (15, 25), (16, 25))
    f.part({28: (12, 18), 29: (12, 20), 30: (12, 21), 31: (12, 21)}, T)
    f.h(31, 13, 20, L[2]); f.put(13, 31, L[1])
    f.h(30, 18, 20, B[1]); f.put(18, 30, B[0]); f.put(15, 28, B[2])
    f.part({11: (11, 19), 12: (10, 20), 13: (10, 20), 14: (10, 20), 15: (10, 20), 16: (10, 20), 17: (10, 20),
            18: (10, 20), 19: (11, 20), 20: (11, 20), 21: (12, 18)}, C)
    # belt, chest and back weights
    f.h(20, 12, 18, T[2]); f.pts(L[1], (13, 20), (17, 20))
    f.part({14: (19, 21), 15: (19, 21), 16: (19, 21), 17: (19, 21), 18: (19, 21)}, L, 'flat')
    f.pts(L[0], (20, 15)); f.pts(L[1], (20, 16)); f.pts(L[2], (20, 17))
    f.part({14: (9, 11), 15: (9, 11), 16: (9, 11), 17: (9, 11)}, L, 'flat')
    f.pts(L[2], (10, 15), (10, 16))
    # breastplate
    f.part({10: (12, 19), 11: (11, 20), 12: (10, 21), 13: (11, 20)}, B)
    f.pts(B[0], (12, 11), (14, 12)); f.pts(B[3], (18, 12))
    # arm, cuff and glove
    f.part({12: (13, 17), 13: (13, 17), 14: (13, 17), 15: (13, 17), 16: (13, 17), 17: (13, 17), 18: (13, 17)}, C)
    f.part({18: (13, 17), 19: (13, 17), 20: (13, 17), 21: (14, 17)}, R)
    f.h(18, 14, 16, R[0])
    f.h(12, 14, 16, B[2]); f.put(14, 12, B[1])
    return f


# ---------------------------------------------------------------- copper helmet

DOME = {2: (12, 18), 3: (10, 20), 4: (10, 20), 5: (9, 21), 6: (9, 21), 7: (9, 21), 8: (10, 20), 9: (11, 19)}


def helmet_neck(f, x0=10, x1=20):
    f.part({10: (x0, x1), 11: (x0 - 1, x1 + 1), 12: (x0 - 1, x1 + 1)}, B)
    f.h(10, x0 + 1, x1 - 1, B[2]); f.pts(B[0], (x0 + 1, 10), (x0 + 2, 10)); f.put(x1 - 1, 10, B[3])
    for x in range(x0 + 1, x1 + 1, 2):       # collar studs
        f.put(x, 11, B[0] if x < x0 + 6 else B[2])
    f.h(12, x0 - 1, x1 + 1, B[4])


def helmet_front(back=False):
    f = Frame()
    f.ball({**DOME, 1: (13, 17)}, K, 12.5, 3.5)
    helmet_neck(f)
    # side ports
    for x, ring, glass in ((10, B[1], G[1]), (20, B[2], G[2])):
        f.v(x, 5, 7, ring); f.put(x, 6, glass)
    f.pts(B[2], (11, 6)); f.pts(B[3], (19, 6))
    # lamp on the crown
    f.part({0: (14, 16), 1: (13, 17)}, B, 'flat')
    f.h(1, 14, 16, B[2])
    if back:
        f.pts(B[3], (14, 1), (15, 1), (16, 1))
        # air inlet elbow and the seam of the bonnet
        f.h(9, 12, 18, K[3])
        f.pts(B[1], (14, 5)); f.pts(B[2], (15, 5)); f.pts(B[3], (16, 5)); f.h(4, 14, 16, B[4])
        f.v(15, 6, 9, R[1]); f.v(16, 6, 9, R[3])
        return f
    f.pts(LENS, (15, 1)); f.pts(YEL, (14, 1), (16, 1))
    # round front port: brass ring, dark glass with a glint
    f.h(3, 13, 17, B[1]); f.h(9, 13, 17, B[3])
    f.v(12, 4, 8, B[1]); f.v(18, 4, 8, B[3])
    f.pts(B[0], (12, 4), (13, 3), (14, 3)); f.pts(B[2], (18, 4), (12, 8)); f.pts(B[4], (18, 8), (17, 9))
    for y in range(4, 9):
        f.h(y, 13, 17, G[3])
    f.pts(G[2], (13, 5), (14, 4), (15, 4), (13, 6), (16, 8), (17, 7))
    f.pts(G[1], (13, 4), (14, 5))
    f.pts(G[0], (14, 4))
    f.pts((20, 60, 80), (16, 7), (17, 8), (15, 8), (17, 6))
    return f


def helmet_side():
    f = Frame()
    f.ball({1: (13, 18), 2: (12, 20), 3: (11, 21), 4: (11, 21), 5: (11, 21), 6: (11, 21), 7: (11, 21),
            8: (11, 21), 9: (12, 20)}, K, 14.5, 3.5)
    helmet_neck(f, 11, 21)
    # front port seen edge-on
    f.part({4: (21, 22), 5: (21, 23), 6: (21, 23), 7: (21, 23), 8: (21, 22)}, B, 'flat')
    f.v(21, 4, 8, B[2]); f.pts(B[0], (21, 4), (22, 5)); f.pts(G[1], (22, 6)); f.pts(G[2], (22, 7))
    # side port with its grille
    f.h(3, 14, 16, B[1]); f.h(9, 14, 16, B[3]); f.v(13, 4, 8, B[1]); f.v(17, 4, 8, B[3])
    f.pts(B[0], (13, 4), (14, 3))
    for y in range(4, 9):
        f.h(y, 14, 16, G[3])
    f.pts(G[1], (14, 4)); f.pts(G[2], (14, 5), (15, 4))
    f.v(15, 5, 8, B[2]); f.h(6, 14, 16, B[2]); f.put(15, 6, B[1])
    # lamp pointing ahead, air inlet behind
    f.h(0, 15, 19, B[4]); f.pts(B[4], (15, 1), (20, 1), (20, 2))
    f.pts(B[0], (16, 1)); f.pts(B[1], (17, 1), (18, 1)); f.h(2, 16, 18, B[3])
    f.pts(LENS, (19, 1)); f.pts(YEL, (19, 2))
    f.pts(B[2], (10, 6), (10, 7)); f.pts(B[4], (10, 5), (10, 8), (9, 6), (9, 7))
    return f


# ---------------------------------------------------------------- hard dive suit

def hard_front(back=False):
    f = Frame()
    # jointed legs
    f.part({22: (9, 21)}, H)
    f.part(sym({y: (9, 14) for y in range(22, 29)}), H)
    f.h(22, 10, 20, H[2]); f.pts(H[1], (10, 22), (11, 22))
    f.pts(H[4], (15, 23))
    for x0 in (10, 17):                      # knee rings in the accent colour
        f.h(25, x0, x0 + 3, ACC2); f.put(x0, 25, ACC); f.put(x0 + 1, 25, ACC)
        f.h(26, x0, x0 + 3, H[3])
    # boots
    f.part(sym({28: (8, 14), 29: (7, 14), 30: (7, 14), 31: (7, 14)}), H)
    f.h(31, 8, 13, H[3]); f.h(31, 17, 22, H[3])
    if not back:
        both(f, RIV, (9, 29))
    # barrel torso
    f.part({10: (11, 19), 11: (9, 21), 12: (8, 22), 13: (8, 22), 14: (8, 22), 15: (8, 22), 16: (8, 22),
            17: (8, 22), 18: (8, 22), 19: (8, 22), 20: (8, 22), 21: (9, 21)}, H)
    # shoulder joints and arms
    f.part(sym({11: (6, 8), 12: (5, 8), 13: (4, 8), 14: (4, 8), 15: (4, 7), 16: (4, 7), 17: (4, 7), 18: (4, 7),
                19: (4, 7), 20: (4, 7)}), H)
    f.pts(RIV, (6, 12)); f.pts(H[0], (5, 13), (6, 13))
    for x0 in (5, 24):                       # elbow rings
        f.h(16, x0, x0 + 1, ACC2)
    f.pts(ACC, (5, 16)); f.pts(H[3], (5, 17), (6, 17), (24, 17), (25, 17))
    # manipulator claws
    f.part(sym({20: (4, 8), 21: (4, 8), 22: (4, 8)}), R, 'flat')
    both(f, R[0], (5, 21)); both(f, R[4], (6, 22)); both(f, R[2], (6, 21), (7, 21))
    # waist joint
    f.h(20, 10, 20, H[3]); f.pts(RIV, (11, 20), (14, 20), (17, 20), (20, 20))
    # accent band across the chest
    f.h(17, 9, 21, ACC2); f.h(17, 9, 13, ACC); f.put(21, 17, (140, 80, 18))
    f.h(18, 9, 21, H[3])
    if not back:
        # chest gauge and lifting eyes
        f.part({12: (13, 17), 13: (13, 17), 14: (13, 17), 15: (13, 17)}, L, 'flat')
        f.pts(G[1], (14, 13)); f.pts(G[2], (15, 13), (14, 14)); f.pts(G[3], (15, 14), (16, 14), (16, 13))
        f.pts(RIV, (10, 12), (20, 12), (10, 15), (20, 15))
    else:
        # back hatch
        f.part({12: (12, 18), 13: (12, 18), 14: (12, 18), 15: (12, 18)}, H, 'flat')
        f.h(13, 13, 17, H[1]); f.h(14, 13, 17, H[2]); f.pts(RIV, (13, 13), (17, 13), (13, 14), (17, 14))
        f.pts(H[3], (15, 13), (15, 14))
    # neck ring
    f.h(10, 12, 18, H[2]); f.pts(H[0], (12, 10), (13, 10))
    return f


def hard_side():
    f = Frame()
    f.part({y: (12, 18) for y in range(21, 29)}, H)
    f.h(25, 13, 17, ACC2); f.pts(ACC, (13, 25), (14, 25)); f.h(26, 13, 17, H[3])
    f.part({28: (12, 19), 29: (12, 21), 30: (12, 22), 31: (12, 22)}, H)
    f.h(31, 13, 21, H[3]); f.put(20, 29, RIV)
    f.part({10: (12, 18), 11: (10, 20), 12: (9, 21), 13: (9, 21), 14: (9, 21), 15: (9, 21), 16: (9, 21),
            17: (9, 21), 18: (9, 21), 19: (9, 21), 20: (10, 20), 21: (11, 19)}, H)
    f.h(20, 11, 19, H[3]); f.pts(RIV, (12, 20), (15, 20), (18, 20))
    f.h(17, 10, 20, ACC2); f.h(17, 10, 12, ACC); f.h(18, 10, 20, H[3])
    f.pts(L[1], (20, 13), (20, 14)); f.pts(G[2], (21, 13)); f.pts(G[3], (21, 14))
    # shoulder joint, arm, claw
    f.part({11: (13, 17), 12: (12, 18), 13: (12, 18), 14: (12, 18), 15: (13, 17), 16: (13, 17), 17: (13, 17),
            18: (13, 17), 19: (13, 17), 20: (13, 17)}, H)
    f.pts(RIV, (15, 12)); f.pts(H[0], (13, 13), (14, 13))
    f.h(16, 14, 16, ACC2); f.put(14, 16, ACC); f.h(17, 14, 16, H[3])
    f.part({20: (13, 17), 21: (13, 17), 22: (13, 17)}, R, 'flat')
    f.pts(R[0], (14, 21)); f.pts(R[4], (15, 22), (15, 21)); f.pts(R[2], (16, 21))
    return f


def hard_helmet_front(back=False):
    f = Frame()
    f.ball({0: (13, 17), 1: (11, 19), 2: (10, 20), 3: (9, 21), 4: (9, 21), 5: (9, 21), 6: (9, 21), 7: (9, 21),
            8: (9, 21), 9: (10, 20)}, H, 12.5, 2.5, (2.4, 5.0, 7.6))
    # locking collar in the accent colour
    f.part({10: (9, 21), 11: (9, 21), 12: (9, 21)}, H, 'flat')
    f.h(10, 10, 20, ACC2); f.h(10, 10, 14, ACC); f.put(20, 10, (140, 80, 18))
    f.h(11, 10, 20, H[2]); f.pts(RIV, (11, 11), (14, 11), (17, 11), (20, 11)); f.h(12, 9, 21, H[4])
    # twin lamps
    for x in (9, 21):
        f.part({1: (x - 1, x + 1), 2: (x - 1, x + 1), 3: (x - 1, x + 1)}, L, 'flat')
        f.put(x, 2, YEL if back is False else L[2])
    if back:
        f.h(5, 11, 19, H[3]); f.v(15, 1, 4, H[3])
        f.pts(RIV, (11, 7), (13, 7), (15, 7), (17, 7), (19, 7))
        f.pts(L[1], (14, 8), (15, 8), (16, 8)); f.pts(L[2], (15, 9))
        return f
    f.pts(LENS, (9, 2), (21, 2))
    # wide glass port in a bolted frame
    frame_rows = {2: (12, 18), 3: (11, 19), 4: (10, 20), 5: (10, 20), 6: (10, 20), 7: (10, 20), 8: (11, 19), 9: (12, 18)}
    for y, (x0, x1) in frame_rows.items():
        f.h(y, x0, x1, RIV if y < 5 else H[1] if y < 8 else H[3])
    glass = {3: (12, 18), 4: (11, 19), 5: (11, 19), 6: (11, 19), 7: (11, 19), 8: (12, 18)}
    for y, (x0, x1) in glass.items():
        for x in range(x0, x1 + 1):
            d = (x - 11) + (y - 3) * 1.4
            f.put(x, y, G[1] if d < 3 else G[2] if d < 7 else G[3] if d < 10.5 else (26, 76, 100))
    f.pts(G[0], (12, 4), (13, 3), (13, 4), (12, 5))
    f.pts(H[3], (10, 6), (20, 6))
    return f


def hard_helmet_side():
    f = Frame()
    f.ball({0: (13, 18), 1: (11, 20), 2: (10, 21), 3: (10, 22), 4: (10, 22), 5: (10, 22), 6: (10, 22), 7: (10, 22),
            8: (10, 22), 9: (11, 21)}, H, 13.5, 2.5, (2.4, 5.0, 7.6))
    f.part({10: (10, 22), 11: (10, 22), 12: (10, 22)}, H, 'flat')
    f.h(10, 11, 21, ACC2); f.h(10, 11, 14, ACC); f.h(11, 11, 21, H[2]); f.pts(RIV, (12, 11), (15, 11), (18, 11), (21, 11))
    f.h(12, 10, 22, H[4])
    # the port wraps round the front
    for y, x0 in {2: 18, 3: 17, 4: 16, 5: 16, 6: 16, 7: 16, 8: 17, 9: 18}.items():
        f.h(y, x0, 21, RIV if y < 5 else H[1] if y < 8 else H[3])
    for y, x0 in {3: 18, 4: 17, 5: 17, 6: 17, 7: 17, 8: 18}.items():
        for x in range(x0, 22):
            d = (x - 17) + (y - 3) * 1.2
            f.put(x, y, G[1] if d < 2 else G[2] if d < 5 else G[3] if d < 8 else (26, 76, 100))
    f.pts(G[0], (18, 4)); f.v(22, 4, 7, G[3]); f.pts(OUT, (23, 4), (23, 5), (23, 6), (23, 7)); f.pts(G[2], (22, 4))
    # lamp
    f.h(0, 17, 21, L[4]); f.pts(L[4], (17, 1), (22, 1), (22, 2))
    f.pts(L[0], (18, 1)); f.pts(L[1], (19, 1), (20, 1)); f.h(2, 18, 20, L[3])
    f.pts(LENS, (21, 1)); f.pts(YEL, (21, 2))
    f.v(13, 2, 8, H[3]); f.pts(RIV, (12, 4), (12, 7))
    return f


# ---------------------------------------------------------------- air bottles

def bottles_back():
    f = Frame()
    for x0 in (11, 16):
        rows = {11: (x0 + 1, x0 + 2)}
        rows.update({y: (x0, x0 + 3) for y in range(12, 21)})
        rows[21] = (x0 + 1, x0 + 2)
        f.part(rows, L)
        f.h(14, x0 + 1, x0 + 2, ACC2); f.put(x0 + 1, 14, ACC)
    f.h(17, 11, 19, T[3]); f.pts(B[2], (15, 17))
    # manifold and valve
    f.part({9: (14, 16), 10: (12, 18)}, B, 'flat')
    f.h(10, 13, 17, B[2]); f.pts(B[0], (13, 10), (15, 9))
    return f


def bottles_front():
    f = Frame()
    # harness straps over the shoulders
    f.v(12, 13, 16, T[3]); f.v(18, 13, 16, T[3])
    f.pts(T[2], (12, 13), (18, 13)); f.pts(B[2], (12, 16), (18, 16))
    return f


def bottles_side():
    f = Frame()
    rows = {11: (8, 9)}
    rows.update({y: (7, 10) for y in range(12, 21)})
    rows[21] = (8, 9)
    f.part(rows, L)
    f.h(14, 8, 9, ACC2); f.put(8, 14, ACC)
    f.part({9: (8, 10), 10: (8, 11)}, B, 'flat')
    f.pts(B[1], (9, 10)); f.pts(B[0], (9, 9))
    f.h(13, 11, 12, T[3]); f.h(18, 11, 12, T[3]); f.h(13, 18, 20, T[3]); f.h(18, 18, 19, T[3])
    return f


# ---------------------------------------------------------------- item icons

def bottles_item():
    f = Frame()
    for x0, ramp in ((9, L), (16, L)):
        rows = {8: (x0 + 2, x0 + 4), 9: (x0 + 1, x0 + 5)}
        rows.update({y: (x0, x0 + 6) for y in range(10, 27)})
        rows[27] = (x0 + 1, x0 + 5)
        f.part(rows, ramp)
        f.h(13, x0 + 1, x0 + 5, ACC2); f.h(13, x0 + 1, x0 + 2, ACC); f.h(14, x0 + 1, x0 + 5, ACC2)
        f.h(14, x0 + 1, x0 + 2, ACC)
        f.part({5: (x0 + 2, x0 + 4), 6: (x0 + 2, x0 + 4), 7: (x0 + 2, x0 + 4)}, B, 'flat')
        f.put(x0 + 3, 6, B[1])
    f.part({5: (11, 20), 6: (11, 20)}, B, 'flat'); f.h(5, 12, 19, B[2]); f.h(6, 12, 19, B[3]); f.pts(B[0], (12, 5), (13, 5))
    f.part({2: (14, 17), 3: (15, 16), 4: (15, 16)}, B, 'flat'); f.h(2, 15, 16, B[1])
    f.h(19, 9, 22, T[4]); f.h(20, 10, 21, T[2]); f.h(21, 9, 22, T[4]); f.pts(B[1], (15, 20), (16, 20))
    return f


def folded(suit):
    """Item icon for a suit: the front view with an open collar."""
    f = suit.shift(0, -4)
    return f


WORN = {
    'diving_dress': [dress_front(), dress_front(True), dress_side(), dress_side().mirror()],
    'diving_helmet': [helmet_front(), helmet_front(True), helmet_side(), helmet_side().mirror()],
    'hard_dive_suit': [hard_front(), hard_front(True), hard_side(), hard_side().mirror()],
    'hard_dive_helmet': [hard_helmet_front(), hard_helmet_front(True), hard_helmet_side(), hard_helmet_side().mirror()],
    'diving_bottles': [bottles_front(), bottles_back(), bottles_side(), bottles_side().mirror()],
}
ITEMS = {
    'diving_dress': folded(WORN['diving_dress'][0]),
    'diving_helmet': WORN['diving_helmet'][0].shift(0, 9),
    'hard_dive_suit': folded(WORN['hard_dive_suit'][0]),
    'hard_dive_helmet': WORN['hard_dive_helmet'][0].shift(0, 9),
    'diving_bottles': bottles_item(),
}


def write_dmi(path, states, dirs):
    frames = [fr for name in states for fr in (states[name] if dirs > 1 else [states[name]])]
    cols = 4 if dirs > 1 else len(frames)
    rows = (len(frames) + cols - 1) // cols
    sheet = Image.new('RGBA', (cols * 32, rows * 32))
    for i, fr in enumerate(frames):
        sheet.paste(fr.image(), ((i % cols) * 32, (i // cols) * 32))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name in states:
        text += 'state = "%s"\n\tdirs = %d\n\tframes = 1\n' % (name, dirs)
    text += '# END DMI\n'
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta)


def main():
    write_dmi(ROOT / 'icons/obj/clothing/diving.dmi', ITEMS, 1)
    write_dmi(ROOT / 'icons/mob/diving.dmi', WORN, 4)


if __name__ == '__main__':
    main()
