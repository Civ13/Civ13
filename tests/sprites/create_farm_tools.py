"""Hand-placed 32px art for the metal sickle and the hoe.

Every pixel is placed by this script from a fixed palette (Pillow only); no
external or generated artwork. Both tools are drawn in the pale grey ramp of
create_machine_parts.py because the game tints each with its material's
colour; the haft is drawn two steps darker so it still reads as a haft under
any tint. Lit from the upper left.

    python3 tests/sprites/create_farm_tools.py [--preview sheet.png] [--check]

Run with Pillow to reproduce icons/obj/farm_tools.dmi (states `sickle` and
`hoe`). `--preview <png>` also writes a review sheet with each tool untinted
and in the colours of the materials it is made of. `--check` writes nothing
and fails when the committed sheet differs from what this script draws.
Released under Civ13 AGPL-3.0.
"""
import importlib.util
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DMI = ROOT / 'icons/obj/farm_tools.dmi'

spec = importlib.util.spec_from_file_location('create_machine_parts', ROOT / 'tests/sprites/create_machine_parts.py')
parts = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parts)
G = parts.G
SHOWN_IN = {'sickle': ('copper', 'bronze', 'iron', 'steel'), 'hoe': ('wood', 'copper', 'bronze', 'iron', 'steel')}


def haft(f, x0, y0, x1, y1, half=1.0):
    """A straight haft from one end to the other, darker than the head."""
    length = math.hypot(x1 - x0, y1 - y0)
    ux, uy = (x1 - x0) / length, (y1 - y0) / length
    for y in range(32):
        for x in range(32):
            along = (x - x0) * ux + (y - y0) * uy
            across = (x - x0) * -uy + (y - y0) * ux
            if 0 <= along <= length and abs(across) <= half:
                f.put(x, y, G[3] if across < 0 else G[4])


def sickle():
    f = parts.Frame()
    haft(f, 5.0, 28.0, 12.0, 19.0, 1.2)
    # the blade is a crescent: an outer disc with an inner disc cut away
    for y in range(32):
        for x in range(32):
            outer = math.hypot(x - 17.0, y - 13.0)
            inner = math.hypot(x - 18.6, y - 14.6)
            if outer <= 10.2 and inner > 8.6 and not (x > 17 and y > 15):
                edge = inner - 8.6
                f.put(x, y, G[0] if edge < 0.9 else G[1] if outer < 9.2 else G[2])
    return f.outline()


def hoe():
    f = parts.Frame()
    haft(f, 4.0, 28.0, 24.0, 8.0, 1.0)
    # the blade is set across the top of the haft and points back down at the ground
    for y in range(32):
        for x in range(32):
            along = (x - 23.0) * 0.7071 + (y - 7.0) * 0.7071
            across = (x - 23.0) * -0.7071 + (y - 7.0) * 0.7071
            # thin at the eye, flaring to the cutting edge
            if -1.5 <= along <= 9.0 and abs(across) <= 1.3 + max(0.0, along) * 0.2:
                f.put(x, y, G[0] if along > 7.6 else G[1] if across < 0 else G[2])
    return f.outline()


def build():
    return {'sickle': ([sickle()], None), 'hoe': ([hoe()], None)}


def main():
    states = build()
    if '--check' in sys.argv:
        problems = parts.check(DMI, states)
        for p in problems:
            print('farm_tools.dmi: ' + p)
        if problems:
            sys.exit(1)
        print('farm_tools.dmi matches (%d states)' % len(states))
    else:
        parts.write_dmi(DMI, states)
    if '--preview' in sys.argv[1:-1]:
        parts.SHOWN_IN = SHOWN_IN
        parts.write_preview(sys.argv[sys.argv.index('--preview') + 1], states)


if __name__ == '__main__':
    main()
