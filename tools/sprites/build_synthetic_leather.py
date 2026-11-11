#!/usr/bin/env python3
"""Draws icons/obj/synthetic_leather.dmi from the leather sheet sprites.

Each "sheet-leather" stack state in icons/obj/materials.dmi is recoloured by
brightness to a glossy black vinyl palette, so synthetic leather keeps the
leather silhouette but reads as a different material. Run from the repository
root; needs Pillow. The output is deterministic.

    python3 tools/sprites/build_synthetic_leather.py
"""
import bisect
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from dmi import Dmi  # noqa: E402

SOURCE = ROOT / 'icons/obj/materials.dmi'
OUT = ROOT / 'icons/obj/synthetic_leather.dmi'
# Darkest to brightest: outline, body shades, a cool sheen on the highlights.
PALETTE = [(14, 14, 18), (28, 29, 35), (40, 42, 50), (54, 57, 68), (86, 92, 108), (140, 148, 166)]
# Share of pixels, darkest first, below which each palette shade applies.
# Most of the sheet stays near black; only the brightest few pixels shine.
CUTS = [0.12, 0.40, 0.72, 0.90, 0.97, 1.01]


def recolour(frame):
    out = Image.new('RGBA', frame.size, (0, 0, 0, 0))
    src = frame.load()
    dst = out.load()
    lums = sorted(sum(src[x, y][:3]) for x in range(frame.width) for y in range(frame.height) if src[x, y][3])
    for x in range(frame.width):
        for y in range(frame.height):
            r, g, b, a = src[x, y]
            if not a:
                continue
            # Percentile of this brightness among the sheet's pixels.
            rank = (bisect.bisect_left(lums, r + g + b) + bisect.bisect_right(lums, r + g + b)) / 2 / max(1, len(lums))
            shade = next(i for i, cut in enumerate(CUTS) if rank < cut)
            dst[x, y] = PALETTE[shade] + (a,)
    return out


def build():
    source = Dmi.from_file(SOURCE)
    dmi = Dmi(32, 32)
    for suffix in ('', '_2', '_3'):
        dmi.state(f'sheet-synthleather{suffix}').frame(recolour(source.get_state(f'sheet-leather{suffix}').frames[0]))
    dmi.to_file(OUT)


if __name__ == '__main__':
    build()
    print(f'wrote {OUT.relative_to(ROOT)}')
