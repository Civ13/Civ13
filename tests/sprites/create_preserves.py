"""Original hand-placed 32px art for the stoneware crock and the preserve jars.

Every pixel comes from the fixed palette and the stamps and coordinates in this
file; there is no external, traced or generated artwork. Released under Civ13's
AGPL-3.0 licence. Run with Pillow from the repository root:

    python3 tests/sprites/create_preserves.py [--preview sheet.png]

It appends (or replaces) these states in icons/obj/food/preserves.dmi (new) and
leaves every other state and every other DMI untouched:

- unfired_crock: raw grey clay crock, the greys of the unfired states in
  icons/obj/claystuff.dmi.
- crock: fired, glazed, open and empty.
- crock_closed: the fired crock with its wooden lid on.
- crock_fill: greyscale liquid surface covering exactly the mouth of "crock";
  the game tints it with the reagent colour and overlays it on "crock".
- preserve_jar: empty glass jar with a tied cloth cover.
- jam_jar: the same jar filled with dark red-purple jam.
- jam_jar_fill: greyscale jam only; the game tints it with the fruit colour
  and overlays it on "preserve_jar".

To change the look, edit this script and rerun it; do not hand-edit the DMI.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_herb_garden import ROOT, S, write_dmi  # noqa: E402  shared DMI plumbing

DMI = 'icons/obj/food/preserves.dmi'

PAL = {
    # fired stoneware: ochre salt glaze over a brown body
    'H': '#dcae62', 'F': '#c4904a', 'C': '#a9763c', 'D': '#855630', 'K': '#5e3b27',
    'B': '#6f4229', 'b': '#8a5631',          # brown glaze band and rim shadow
    'R': '#b98346', 'r': '#96643a',          # rolled rim
    'm': '#33201a', 'M': '#1e1210',          # empty mouth
    # raw clay, matched to the unfired states of icons/obj/claystuff.dmi
    '1': '#989090', '2': '#8d8382', '3': '#857b7b', '4': '#7d7475', '5': '#716a6b',
    '6': '#645e5f', '7': '#5a5455',
    # wooden lid
    'W': '#b08a58', 'w': '#96713f', 'x': '#75552f', 'X': '#54391f',
    # glass (see-through body and highlight) and its edges
    'g': '#c9dde0', 'G': '#8fa9ad', 'a': '#d6e8ea50', 'h': '#f4fbfbb0',
    # cloth cover and string
    'c': '#efe6cf', 'e': '#d6c8a6', 's': '#b3a37f', 't': '#8a5a2c', 'T': '#5f3c1c',
    # jam
    'p': '#a23358', 'J': '#7a1c40', 'j': '#5c1433', 'q': '#3f0d24',
    # greyscale fills, tinted in game
    'z': '#ffffff', 'y': '#e2e2e2', 'u': '#c4c4c4', 'v': '#a6a6a6',
}


def rgba(c):
    c = PAL[c]
    return tuple(int(c[i:i + 2], 16) for i in (1, 3, 5)) + (int(c[7:9], 16) if len(c) > 7 else 255,)


def art(x, y, *layers):
    """Stamp each (rows, remap, dy) layer at x, y + dy; '.' leaves the pixel alone."""
    im = Image.new('RGBA', (S, S))
    p = im.load()
    for rows, remap, dy in layers:
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch != '.':
                    p[x + i, y + dy + j] = rgba(remap.get(ch, ch) if remap else ch)
    return im


# -------------------------------------------------------------------- crock
# 14 x 16, placed at 9, 9. Rows 0-3 are the rolled rim around the mouth.
CROCK_X, CROCK_Y = 9, 9
CROCK = [
    '...rRRRRRRr...',
    '.rRmmmmmmmmRr.',
    'RRmMMMMMMMMmrb',
    'bRRmmmmmmmmrrb',
    '.bRRRRrrrrrbK.',
    '.KDDDDDDDDDKK.',
    'DFHFCCCCCCCDDK',
    'DFHFFCCCCCCCDK',
    'DFHFFCCCCCCCDK',
    'KBbBBBBBBBBBBK',
    'DFHFFCCCCCCCDK',
    'DFHFFCCCCCCCDK',
    'DFFFCCCCCCCDDK',
    'DFFCCCCCCCDDDK',
    '.DFCCCCCCDDDK.',
    '..KDDDDDDKKK..',
]
# the same pot before firing: flat grey clay, the band only a scored line
RAW = {'H': '2', 'F': '2', 'C': '3', 'D': '4', 'K': '5', 'B': '5', 'b': '4',
       'R': '1', 'r': '3', 'm': '6', 'M': '7'}
# liquid surface: exactly the m and M pixels of CROCK
CROCK_FILL = [
    '..............',
    '...uyyyyyyu...',
    '..uyzzyyyyyv..',
    '...vuuuuuuv...',
]
# wooden lid resting on the rim, with a knob; starts two rows above the crock
LID = [
    '.....xWWx.....',
    '.....wWwX.....',
    '...wWWWWWWw...',
    '.wWWWwWWWWWWx.',
    'wWWwWWWWwWWwxX',
    'XwwwwwwwwwxxXX',
]

# ---------------------------------------------------------------------- jar
# 10 x 13, placed at 11, 10.
JAR_X, JAR_Y = 11, 10
JAR = [
    '..cccccc..',
    '.cccececs.',
    'cccecccees',
    '.tTttttTt.',
    'cecsecsces',
    '.gaaaaaaG.',
    'gahaaaaaaG',
    'gahaaaaaaG',
    'gahaaaaaaG',
    'gaaaaaaaaG',
    'gaaaaaaaaG',
    'gaaaaaaaaG',
    '.GGGGGGGG.',
]
# the jam inside the glass, in greys; its first row is the lit surface
JAM_DY = 6
JAM = [
    '.yzyyyyyu.',
    '.yzuuuuuv.',
    '.yzuuuuuv.',
    '.yuuuuuuv.',
    '.uuuuuuvv.',
    '.uvvvvvvv.',
]
JAM_RED = {'z': 'p', 'y': 'J', 'u': 'j', 'v': 'q'}


def build():
    crock = (CROCK, None, 0)
    jar = (JAR, None, 0)
    return {DMI: [
        ('unfired_crock', art(CROCK_X, CROCK_Y, (CROCK, RAW, 0))),
        ('crock', art(CROCK_X, CROCK_Y, crock)),
        ('crock_closed', art(CROCK_X, CROCK_Y, crock, (LID, None, -2))),
        ('crock_fill', art(CROCK_X, CROCK_Y, (CROCK_FILL, None, 0))),
        ('preserve_jar', art(JAR_X, JAR_Y, jar)),
        ('jam_jar', art(JAR_X, JAR_Y, jar, (JAM, JAM_RED, JAM_DY))),
        ('jam_jar_fill', art(JAR_X, JAR_Y, (JAM, None, JAM_DY))),
    ]}


def preview(sheets, out):
    """Review sheet of the actual sprite pixels at 8x; not a gameplay screenshot."""
    z, pad = 8, 12
    states = list(sheets[DMI])
    by = dict(states)

    def tinted(base, fill, colour):
        rgb = [int(colour[i:i + 2], 16) for i in (1, 3, 5)]
        over = by[fill].copy()
        p = over.load()
        for yy in range(S):
            for xx in range(S):
                px = p[xx, yy]
                p[xx, yy] = tuple(px[k] * rgb[k] // 255 for k in range(3)) + (px[3],)
        tile = by[base].copy()
        tile.alpha_composite(over)
        return tile

    demos = [('crock + fill, blue', tinted('crock', 'crock_fill', '#5a8fc0')),
             ('crock + fill, green', tinted('crock', 'crock_fill', '#b7c27a')),
             ('crock + fill, brown', tinted('crock', 'crock_fill', '#9a5a2a')),
             ('jar + fill, purple', tinted('preserve_jar', 'jam_jar_fill', '#7a2a6a')),
             ('jar + fill, orange', tinted('preserve_jar', 'jam_jar_fill', '#e08a20')),
             ('jar + fill, red', tinted('preserve_jar', 'jam_jar_fill', '#c0203a')),
             ('all states at 1x', None)]
    cell_w, cell_h = S * z + pad, S * z + 18
    img = Image.new('RGBA', (cell_w * len(states) + pad, cell_h * 2 + 60), (74, 104, 58, 255))
    d = ImageDraw.Draw(img)
    y = 6
    for title, group in (('States in %s' % DMI, states),
                         ('Fill overlays multiplied by example colours, as the game tints them', demos)):
        d.text((8, y), title, fill='white')
        y += 20
        for i, (name, frame) in enumerate(group):
            x = 8 + i * cell_w
            d.text((x, y), name, fill=(235, 235, 220))
            if frame is None:
                for n, (_, f) in enumerate(states):
                    img.alpha_composite(f, (x + (n % 4) * (S + 4), y + 14 + (n // 4) * (S + 4)))
                continue
            d.rectangle((x, y + 12, x + S * z - 1, y + 12 + S * z - 1), fill=(96, 128, 72, 255))
            img.alpha_composite(frame.resize((S * z, S * z), Image.NEAREST), (x, y + 12))
        y += cell_h + 4
    img.save(out)


if __name__ == '__main__':
    sheets = build()
    for rel, new_states in sheets.items():
        write_dmi(ROOT / rel, new_states)
    if '--preview' in sys.argv:
        preview(sheets, sys.argv[sys.argv.index('--preview') + 1])
