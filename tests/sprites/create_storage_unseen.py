"""Hand-placed "not seen yet" tiles for the classic HUD storage strip.

The storage strip (the row of 32px slots drawn when a bag is opened) hides
the things the player has not searched yet behind a grey "?" box, the same
box the storage window draws (`Unknown` and `.stor-q-1` .. `.stor-q-5` in
tgui). The box grows with the hidden item's size class, so a searcher can
tell a coin from a rifle before knowing which it is.

It owns icons/mob/screen/storage_unseen.dmi, five 32x32 states:

    unseen1 (tiny), unseen2 (small), unseen3 (normal),
    unseen4 (large / bulky), unseen5 (huge)

Each is a centred, rounded grey box (14, 18, 22, 26 and 30px wide, even so it
centres on the tile) with a 1px dark outline, a lit top-left and shaded
bottom-right rim, and a "?" placed pixel by pixel from the glyphs below.
Everything outside the box is transparent and every drawn pixel is opaque,
so the tile reads the same on the slot background of every HUD style. The
colours are the storage window's (#57524a box, #7d766b rim, #cfc6b8 mark).
Every pixel comes from this file (Pillow only); there is no external, traced
or generated artwork. Released under Civ13's AGPL-3.0 licence. Run from the
repository root:

    python3 tests/sprites/create_storage_unseen.py [--check] [--preview sheet.png]

--check verifies the committed sheet matches this script. --preview writes a
review sheet: the five states at 4x, then a mock strip row on the storage
slot background ("block") of each HUD style with real item sprites beside
the "?" tiles. To change the look, edit this script and rerun it; do not
hand-edit the DMI.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from dmi import Dmi  # noqa: E402

SCREEN = ROOT / 'icons/mob/screen'
OUT = SCREEN / 'storage_unseen.dmi'
S = 32

OUTLINE = (31, 28, 25, 255)
RIM_LIT = (125, 118, 107, 255)   # #7d766b, the window's box border
RIM_DARK = (66, 62, 56, 255)
FILL = (87, 82, 74, 255)         # #57524a, the window's box
FILL_LOW = (79, 74, 67, 255)     # lower half, one step down
MARK = (207, 198, 184, 255)      # #cfc6b8, the window's "?"
MARK_SHADE = (52, 48, 43, 255)   # the mark's drop shade, one pixel down

# size class -> (box width including the outline, corner cut, glyph)
GLYPHS = {
    1: (14, 1, (
        '.###.',
        '#...#',
        '....#',
        '..##.',
        '..#..',
        '.....',
        '..#..',
    )),
    2: (18, 1, (
        '.####.',
        '##..##',
        '....##',
        '...##.',
        '..##..',
        '..##..',
        '......',
        '..##..',
        '..##..',
    )),
    3: (22, 2, (
        '.#####.',
        '##...##',
        '##...##',
        '.....##',
        '....##.',
        '...##..',
        '...##..',
        '...##..',
        '.......',
        '...##..',
        '...##..',
    )),
    4: (26, 2, (
        '..####..',
        '.######.',
        '##....##',
        '##....##',
        '......##',
        '.....##.',
        '....##..',
        '...##...',
        '...##...',
        '...##...',
        '........',
        '........',
        '...##...',
        '...##...',
    )),
    5: (30, 2, (
        '..######..',
        '.########.',
        '###....###',
        '###....###',
        '.......###',
        '......###.',
        '.....###..',
        '....###...',
        '....###...',
        '....###...',
        '....###...',
        '..........',
        '..........',
        '....###...',
        '....###...',
        '....###...',
    )),
}
STATES = tuple('unseen%d' % n for n in GLYPHS)


def inside(x, y, size, cut):
    """Whether (x, y) of a size x size box survives the corner cut."""
    if not (0 <= x < size and 0 <= y < size):
        return False
    dx = min(x, size - 1 - x)
    dy = min(y, size - 1 - y)
    return dx + dy >= cut


def draw(n):
    size, cut, glyph = GLYPHS[n]
    tile = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    px = tile.load()
    off = (S - size) // 2
    for y in range(size):
        for x in range(size):
            if not inside(x, y, size, cut):
                continue
            edge = any(not inside(x + ax, y + ay, size, cut) for ax, ay in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if edge:
                tone = OUTLINE
            else:
                # The rim is the ring just inside the outline.
                x2, y2, s2 = x - 1, y - 1, size - 2
                rim = any(not inside(x2 + ax, y2 + ay, s2, cut) for ax, ay in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if rim:
                    tone = RIM_LIT if (x2 + y2) < s2 - 1 else RIM_DARK
                else:
                    tone = FILL if y < size // 2 else FILL_LOW
            px[off + x, off + y] = tone
    gw, gh = len(glyph[0]), len(glyph)
    gx, gy = (S - gw) // 2, (S - gh) // 2
    cells = {(gx + x, gy + y) for y, row in enumerate(glyph) for x, ch in enumerate(row) if ch == '#'}
    for x, y in cells:
        if (x, y + 1) not in cells:
            px[x, y + 1] = MARK_SHADE
    for x, y in cells:
        px[x, y] = MARK
    # The whole glyph and its shade must sit inside the box fill.
    assert gx - 2 >= off + 2 and gy - 1 >= off + 2 and gy + gh + 1 < off + size - 2, n
    assert set(tile.getchannel('A').tobytes()) <= {0, 255}
    return tile


def build():
    dmi = Dmi(S, S)
    tiles = {}
    for n in GLYPHS:
        name = 'unseen%d' % n
        tiles[name] = draw(n)
        dmi.state(name).frame(tiles[name])
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


# HUD style name (code/datums/hud.dm) -> its sheet. NewStyle draws from the
# 1713Style sheet. The strip tiles each sheet's "block" state behind the row.
HUD_STYLES = (
    ('ConsoleStyle', 'ConsoleStyle.dmi'),
    ('1713Style', '1713Style.dmi'),
    ('NewStyle', '1713Style.dmi'),
    ('LiteWebStyle', 'litewebStyle.dmi'),
    ('FoFStyle', 'FoFStyle.dmi'),
)
# The mock row: real item sprites between the hidden ones.
ROW = (('icons/obj/weapons.dmi', 'hatchet'), 'unseen1', ('icons/obj/food/food.dmi', 'baguette'), 'unseen2',
       'unseen3', ('icons/obj/items.dmi', 'zippo'), 'unseen4', 'unseen5')


def preview(path, tiles):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    scale, pad, label_w, label_h = 4, 8, 96, 14
    big = S * scale
    ground = (60, 90, 60, 255)
    width = pad + label_w + len(ROW) * big + pad
    height = pad + label_h + big + pad + len(HUD_STYLES) * (big + pad) + pad + S + pad
    sheet = Image.new('RGBA', (width, height), ground)
    pen = ImageDraw.Draw(sheet)
    white = (255, 255, 255, 255)
    pen.text((pad, pad + label_h + 56), 'states, 4x', fill=white)
    for i, name in enumerate(STATES):
        x = pad + label_w + i * (big + pad)
        pen.text((x, pad), name, fill=white)
        sheet.alpha_composite(tiles[name].resize((big, big), Image.NEAREST), (x, pad + label_h))
    items = {}
    for cell in ROW:
        if not isinstance(cell, str):
            items[cell] = Dmi.from_file(str(ROOT / cell[0])).get_state(cell[1]).get_frame(0).convert('RGBA')
    top = pad + label_h + big + pad
    small = Image.new('RGBA', (len(ROW) * S, S), (0, 0, 0, 0))
    for row, (style, sheet_name) in enumerate(HUD_STYLES):
        block = Dmi.from_file(str(SCREEN / sheet_name)).get_state('block').get_frame(0).convert('RGBA')
        y = top + row * (big + pad)
        pen.text((pad, y + 52), style, fill=white)
        pen.text((pad, y + 66), sheet_name.replace('.dmi', ''), fill=(200, 215, 200, 255))
        strip = Image.new('RGBA', (len(ROW) * S, S), (0, 0, 0, 0))
        for col, cell in enumerate(ROW):
            strip.alpha_composite(block, (col * S, 0))
            strip.alpha_composite(tiles[cell] if isinstance(cell, str) else items[cell], (col * S, 0))
        sheet.alpha_composite(strip.resize((strip.width * scale, big), Image.NEAREST), (pad + label_w, y))
        if style == 'ConsoleStyle':
            small = strip
    y = top + len(HUD_STYLES) * (big + pad) + pad
    pen.text((pad, y + 10), 'ConsoleStyle, 1x', fill=white)
    sheet.alpha_composite(small, (pad + label_w, y))
    sheet.save(path)


def main(argv):
    check = '--check' in argv
    dmi, tiles = build()
    same = matches(tiles)
    if check:
        print('storage_unseen.dmi: %s' % ('matches' if same else 'DIFFERS'))
    elif same:
        print('storage_unseen.dmi: unchanged')
    else:
        dmi.to_file(str(OUT))
        print('storage_unseen.dmi: written (%s)' % ', '.join(STATES))
    if '--preview' in argv:
        preview(argv[argv.index('--preview') + 1], tiles)
    return 1 if check and not same else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
