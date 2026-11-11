#!/usr/bin/env python3
"""Draws icons/obj/tanning_drum.dmi, the powered tanning drum.

A wooden tanning drum on a steel frame with a small motor. States:
"tanning_drum" (idle), "tanning_drum_on" (one full turn in 8 frames, lamp lit) and
"tanning_drum_off" (stopped but loaded, lamp amber). Run from the repository
root; needs Pillow. The output is deterministic.

    python3 tools/sprites/build_tanning_drum.py
"""
import math
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from dmi import Dmi  # noqa: E402

OUT = ROOT / 'icons/obj/tanning_drum.dmi'

STEEL_DARK = (52, 56, 62, 255)
STEEL = (92, 98, 106, 255)
STEEL_LIGHT = (140, 147, 156, 255)
OUTLINE = (28, 22, 18, 255)
WOOD = [(122, 78, 44, 255), (104, 64, 34, 255)]
WOOD_LIGHT = (150, 100, 60, 255)
HOOP = (70, 66, 64, 255)
HOOP_LIGHT = (120, 114, 108, 255)
HATCH = (168, 120, 74, 255)
MOTOR = (58, 84, 70, 255)
MOTOR_LIGHT = (86, 118, 98, 255)
LAMP = {'idle': (70, 40, 36, 255), 'on': (120, 230, 110, 255), 'off': (230, 170, 60, 255)}

CX, CY, R = 15.5, 13.5, 10.5  # drum centre and radius, pixel centres


def put(img, x, y, c):
    if 0 <= x < 32 and 0 <= y < 32:
        img.putpixel((x, y), c)


def rect(img, x0, y0, x1, y1, c):
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            put(img, x, y, c)


def frame_base(img):
    # Two legs and a cross bar, drawn behind the drum.
    for x0 in (4, 25):
        rect(img, x0, 14, x0 + 2, 29, STEEL)
        rect(img, x0, 14, x0, 29, STEEL_LIGHT)
        rect(img, x0 + 2, 14, x0 + 2, 29, STEEL_DARK)
        rect(img, x0 - 1, 29, x0 + 3, 30, STEEL_DARK)
    rect(img, 4, 26, 27, 27, STEEL)
    rect(img, 4, 26, 27, 26, STEEL_LIGHT)


def drum(img, angle):
    hatch_a = angle
    # Snap the hatch to a pixel centre so it keeps its shape as it turns.
    hx = math.floor(CX + math.cos(hatch_a) * 5.6) + 0.5
    hy = math.floor(CY + math.sin(hatch_a) * 5.6) + 0.5
    for y in range(32):
        for x in range(32):
            dx, dy = x - CX, y - CY
            d = math.hypot(dx, dy)
            if d > R + 0.5:
                continue
            if d > R - 0.7:
                put(img, x, y, OUTLINE)
                continue
            if d > R - 2.0:
                # Iron rim, lit from the upper left.
                put(img, x, y, HOOP_LIGHT if dx + dy < -4 else HOOP)
                continue
            if d < 2.2:
                put(img, x, y, STEEL_LIGHT if d < 1.2 else STEEL_DARK)
                continue
            # Staves: eight wedges that turn with the drum.
            a = (math.atan2(dy, dx) - angle) % (2 * math.pi)
            sector = int(a / (math.pi / 4))
            edge = (a % (math.pi / 4)) < 0.16
            c = OUTLINE if edge and d > 3 else WOOD[sector % 2]
            if not edge and dx + dy < -6:
                c = WOOD_LIGHT
            # The loading hatch rides on one stave.
            if abs(x - hx) <= 2 and abs(y - hy) <= 2:
                border = abs(x - hx) > 1 or abs(y - hy) > 1
                c = HOOP if border else HATCH
            put(img, x, y, c)


def motor(img, lamp):
    rect(img, 20, 22, 29, 29, OUTLINE)
    rect(img, 21, 23, 28, 28, MOTOR)
    rect(img, 21, 23, 28, 23, MOTOR_LIGHT)
    for y in (25, 27):
        rect(img, 22, y, 25, y, STEEL_DARK)  # cooling fins
    rect(img, 27, 25, 28, 26, lamp)


def sprite(angle, lamp):
    img = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
    frame_base(img)
    drum(img, angle)
    motor(img, LAMP[lamp])
    return img


def build():
    dmi = Dmi(32, 32)
    dmi.state('tanning_drum').frame(sprite(0.3, 'idle'))
    on = dmi.state('tanning_drum_on')
    for i in range(8):
        on.frame(sprite(0.3 + i * math.pi / 4, 'on'), delay=1)
    dmi.state('tanning_drum_off').frame(sprite(0.3, 'off'))
    dmi.to_file(OUT)
    return dmi


if __name__ == '__main__':
    build()
    print(f'wrote {OUT.relative_to(ROOT)}')
