"""Hand-placed digits for the count shown on a stacked item in an inventory slot.

A stack of more than one thing held in a hand, worn in a slot or lying in an
open bag shows how many it holds in the top-right corner of its slot
(code/modules/storage_window/stack_count.dm). The number is built from the glyphs in
icons/mob/screen/stack_count.dmi, one 32x32 state per glyph:

    n0 .. n9, nk, nm   the usual count, warm white
    f0 .. f9, fk, fm   the same glyphs in amber, used when the stack is full

Every state holds its glyph in the same place, the ones column: a 3x5 figure
on columns 26-28 and rows 3-7 (counted from the top), inside a one pixel dark
outline with a soft two-tone shade under it. The game shifts each further
figure 4px to the left, so neighbouring outlines share a column and a number
reads as one small plate that needs no box behind it. Up to four figures are
shown; larger counts are written short (12k, 1m).

The figures keep 2px clear of the top and right edges of the tile so they sit
inside the slot frame of every HUD style, and they never reach the top-left
corner where the hand slots carry their L and R marks. The dark outline is
what makes them read over any item and any slot background, so the colours
do not depend on the HUD style. Every pixel comes from this file (Pillow
only); there is no external, traced or generated artwork. Released under
Civ13's AGPL-3.0 licence. Run from the repository root:

    python3 tests/sprites/create_stack_count.py [--check] [--preview sheet.png]

--check verifies the committed sheet matches this script. --preview writes a
review sheet: the glyphs at 8x, then hand, bag strip and pocket slots of each
HUD style with real stacks and their counts, at 4x, 2x and 1x. To change the
look, edit this script and rerun it; do not hand-edit the DMI.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from dmi import Dmi  # noqa: E402

SCREEN = ROOT / 'icons/mob/screen'
OUT = SCREEN / 'stack_count.dmi'
S = 32

# The ones column: left edge and top row of the 3x5 figure. PITCH is how far
# the game shifts each further figure left (STACK_COUNT_PITCH in the DM file).
GX, GY = 26, 3
PITCH = 4
MAX_FIGURES = 4

OUTLINE = (24, 20, 17, 255)
SHADE = (24, 20, 17, 150)        # the soft pixel row under the outline
NORMAL = ((247, 240, 222, 255), (214, 203, 178, 255))   # figure, its bottom row
FULL = ((255, 203, 92, 255), (226, 158, 52, 255))

GLYPHS = {
    '0': ('###', '#.#', '#.#', '#.#', '###'),
    '1': ('.#.', '##.', '.#.', '.#.', '###'),
    '2': ('###', '..#', '###', '#..', '###'),
    '3': ('###', '..#', '.##', '..#', '###'),
    '4': ('#.#', '#.#', '###', '..#', '..#'),
    '5': ('###', '#..', '###', '..#', '###'),
    '6': ('###', '#..', '###', '#.#', '###'),
    '7': ('###', '..#', '..#', '.#.', '.#.'),
    '8': ('###', '#.#', '###', '#.#', '###'),
    '9': ('###', '#.#', '###', '..#', '###'),
    'k': ('#..', '#.#', '##.', '#.#', '#.#'),
    'm': ('...', '###', '###', '#.#', '#.#'),
}
SETS = (('n', NORMAL), ('f', FULL))
STATES = tuple(prefix + ch for prefix, _ in SETS for ch in GLYPHS)


def draw(ch, tones):
    tile = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    px = tile.load()
    glyph = GLYPHS[ch]
    cells = {(GX + x, GY + y) for y, row in enumerate(glyph) for x, c in enumerate(row) if c == '#'}
    # The plate: the full 3x5 cell plus its one pixel border, so every figure
    # has the same outline and a row of them joins into one shape.
    plate = {(x, y) for x in range(GX - 1, GX + 4) for y in range(GY - 1, GY + 6)}
    for x, y in plate:
        px[x, y] = OUTLINE
    for x in range(GX - 1, GX + 4):
        px[x, GY + 6] = SHADE
    for x, y in cells:
        px[x, y] = tones[1] if y == GY + 4 else tones[0]
    assert GX + 3 <= S - 3 and GY - 1 >= 2, 'keep 2px clear of the slot frame'
    return tile


def build():
    dmi = Dmi(S, S)
    tiles = {}
    for prefix, tones in SETS:
        for ch in GLYPHS:
            tiles[prefix + ch] = draw(ch, tones)
            dmi.state(prefix + ch).frame(tiles[prefix + ch])
    return dmi, tiles


def matches(tiles):
    if not OUT.exists():
        return False
    current = Dmi.from_file(str(OUT))
    if tuple(s.name for s in current.states) != STATES or (current.width, current.height) != (S, S):
        return False
    return all(len(current.get_state(n).frames) == 1
               and current.get_state(n).get_frame(0).convert('RGBA').tobytes() == tiles[n].tobytes()
               for n in STATES)


def count_text(count):
    """The figures the game shows for a count (stack_count_text in the DM file)."""
    if count >= 1000000:
        return '%dm' % min(count // 1000000, 999)
    if count >= 10000:
        return '%dk' % (count // 1000)
    return str(count)


def badge(tiles, count, full=False):
    """The count as the game lays it out: right aligned, PITCH apart."""
    text = count_text(count)
    assert len(text) <= MAX_FIGURES
    out = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    prefix = 'f' if full else 'n'
    for i, ch in enumerate(reversed(text)):
        shifted = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        shifted.paste(tiles[prefix + ch], (-PITCH * i, 0))
        out.alpha_composite(shifted)
    return out


# HUD style name (code/datums/hud.dm) -> its sheet. NewStyle draws from the
# 1713Style sheet.
HUD_STYLES = (
    ('ConsoleStyle', 'ConsoleStyle.dmi'),
    ('1713Style', '1713Style.dmi'),
    ('NewStyle', '1713Style.dmi'),
    ('LiteWebStyle', 'litewebStyle.dmi'),
    ('FoFStyle', 'FoFStyle.dmi'),
)
MATERIALS = 'icons/obj/materials.dmi'
# The mock row: slot state, item sprite, count, full stack.
ROW = (
    ('act_hand-r', (MATERIALS, 'sheet-stone'), 50, True),
    ('hand-l', (MATERIALS, 'sheet-stone'), 12, False),
    ('pocket_l', (MATERIALS, 'rope'), 3, False),
    ('pocket_r', ('icons/obj/items.dmi', 'zippo'), 1, False),
    ('block', (MATERIALS, 'sheet-wood'), 7, False),
    ('block', (MATERIALS, 'sheet-iron_4'), 48, False),
    ('block', (MATERIALS, 'sheet-leather'), 150, False),
    ('block', (MATERIALS, 'sheet-cloth_4'), 500, True),
    ('block', (MATERIALS, 'sheet-gold'), 2500, False),
    ('block', ('icons/obj/items.dmi', 'coin'), 12000, False),
)


def frame(sheet, name):
    try:
        return sheet.get_state(name).get_frame(0).convert('RGBA')
    except Exception:
        return None


def preview(path, tiles):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    scale, pad, label_w, label_h = 4, 8, 100, 14
    big = S * scale
    ground = (60, 90, 60, 255)
    white = (255, 255, 255, 255)
    width = pad + label_w + len(ROW) * big + pad
    glyph_h = 9 * 8
    height = (pad + label_h + glyph_h + pad + len(HUD_STYLES) * (big + pad)
              + pad + 2 * S + pad + S + pad)
    out = Image.new('RGBA', (width, height), ground)
    pen = ImageDraw.Draw(out)

    # The glyphs at 8x, cropped to the plate, on a mid grey.
    pen.text((pad, pad), 'glyphs, 8x (usual, then full stack)', fill=white)
    box = (GX - 2, GY - 2, GX + 5, GY + 7)
    x = pad
    for name in STATES:
        cell = Image.new('RGBA', (box[2] - box[0], box[3] - box[1]), (110, 110, 110, 255))
        cell.alpha_composite(tiles[name].crop(box))
        out.alpha_composite(cell.resize((cell.width * 8, cell.height * 8), Image.NEAREST), (x, pad + label_h))
        x += cell.width * 8 + 2
        if name == 'nm':
            x += 10

    items = {}
    for _, cell, _, _ in ROW:
        items[cell] = Dmi.from_file(str(ROOT / cell[0])).get_state(cell[1]).get_frame(0).convert('RGBA')
    top = pad + label_h + glyph_h + pad
    strips = {}
    for row, (style, sheet_name) in enumerate(HUD_STYLES):
        sheet = Dmi.from_file(str(SCREEN / sheet_name))
        y = top + row * (big + pad)
        pen.text((pad, y + 52), style, fill=white)
        pen.text((pad, y + 66), sheet_name.replace('.dmi', ''), fill=(200, 215, 200, 255))
        strip = Image.new('RGBA', (len(ROW) * S, S), (0, 0, 0, 0))
        for col, (slot, cell, count, full) in enumerate(ROW):
            tile = frame(sheet, slot) or frame(sheet, slot.replace('act_', '')) or frame(sheet, 'block')
            strip.alpha_composite(tile, (col * S, 0))
            strip.alpha_composite(items[cell], (col * S, 0))
            if count > 1:
                strip.alpha_composite(badge(tiles, count, full), (col * S, 0))
        out.alpha_composite(strip.resize((strip.width * scale, big), Image.NEAREST), (pad + label_w, y))
        strips[style] = strip
    y = top + len(HUD_STYLES) * (big + pad) + pad
    pen.text((pad, y + 26), 'ConsoleStyle, 2x', fill=white)
    small = strips['ConsoleStyle']
    out.alpha_composite(small.resize((small.width * 2, S * 2), Image.NEAREST), (pad + label_w, y))
    y += 2 * S + pad
    pen.text((pad, y + 10), 'ConsoleStyle, 1x', fill=white)
    out.alpha_composite(small, (pad + label_w, y))
    out.save(path)


def main(argv):
    check = '--check' in argv
    dmi, tiles = build()
    same = matches(tiles)
    if check:
        print('stack_count.dmi: %s' % ('matches' if same else 'DIFFERS'))
    elif same:
        print('stack_count.dmi: unchanged')
    else:
        dmi.to_file(str(OUT))
        print('stack_count.dmi: written (%d states)' % len(STATES))
    if '--preview' in argv:
        preview(argv[argv.index('--preview') + 1], tiles)
    return 1 if check and not same else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
