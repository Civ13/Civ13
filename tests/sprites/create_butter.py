"""Original hand-placed 32px art for the butter churn, butter and buttered bread.

Every pixel comes from the fixed palette and the stamps and coordinates in this
file; there is no external, traced or generated artwork. Released under Civ13's
AGPL-3.0 licence. Run with Pillow from the repository root:

    python3 tests/sprites/create_butter.py [--preview sheet.png]

It appends (or replaces) these states in icons/obj/food/butter.dmi (new) and
leaves every other state and every other DMI untouched:

- butter_churn: upright staved plunger churn with iron hoops, lid off, the
  cream showing in the open mouth and the dasher handle leaning out.
- butter_churn_closed: the same churn with its wooden lid on and the dasher
  handle standing straight up through it.
- butter: a pat of fresh pale yellow butter with a stamped top.
- butter_salted: the same pat, deeper yellow, with white salt flecks.
- butter_rancid: the same pat gone grey-green with darker mottling.
- buttered_bread: the slice shape and crust colours of "breadslice" in
  icons/obj/food/food.dmi with butter spread over the crumb.

To change the look, edit this script and rerun it; do not hand-edit the DMI.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_herb_garden import ROOT, S, write_dmi  # noqa: E402  shared DMI plumbing

DMI = 'icons/obj/food/butter.dmi'

PAL = {
    # churn staves, close to the wooden barrels of icons/obj/barrel.dmi
    'L': '#b98445', 'W': '#9c6a30', 'w': '#7f5224', 'D': '#5f3a18', 'o': '#2c190b',
    'R': '#c2924f', 'r': '#8a5c2a',          # rim of the open mouth
    'q': '#f3ecd2', 'Q': '#d9cfae',          # cream in the mouth
    # iron hoops
    'I': '#a3a5a8', 'u': '#74767a', 'v': '#47484c',
    # dasher handle and lid, a paler turned wood
    'H': '#dab77c', 'y': '#b08a52', 'x': '#7d5c30',
    'E': '#c9a468', 'e': '#a67f47', 'X': '#6b4a25',
    # fresh butter
    'T': '#fbeea0', 'p': '#e6cb5e', 'F': '#f0d564', 'S': '#cfa838', 'G': '#b08a2a',
    'O': '#6e5216',
    # salted butter and its salt
    '1': '#f9e37c', '2': '#e3c350', '3': '#eac646', '4': '#c4962a', '5': '#a17a1e',
    '6': '#634510', 's': '#ffffff', 'z': '#e6e2d0',
    # rancid butter
    '7': '#c2c285', '8': '#a3a868', '9': '#a9aa66', '0': '#7f8648', '!': '#666d38',
    '@': '#3b4020', '#': '#6f7a3e', '$': '#555c2c',
    # bread slice, the colours of "breadslice" in icons/obj/food/food.dmi
    'a': '#ab5012', 'b': '#b45f2a', 'c': '#eb7c28', 'd': '#f0cb5b', 'f': '#faedae',
    'g': '#fcf6be', 'h': '#c47342', 'i': '#ffffff', 'j': '#fefecc', 'k': '#e4c565',
    'l': '#833715', 'm': '#431608', 'n': '#762b09', 'C': '#f6dc90',
    # butter spread on the slice
    'Y': '#fff4a6', 'B': '#f7d94e', 'Z': '#dcae30',
}


def rgba(c):
    c = PAL[c]
    return tuple(int(c[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


def art(x, y, *layers):
    """Stamp each (rows, remap, dx, dy) layer at x + dx, y + dy; '.' is skipped."""
    im = Image.new('RGBA', (S, S))
    p = im.load()
    for rows, remap, dx, dy in layers:
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch != '.':
                    p[x + dx + i, y + dy + j] = rgba(remap.get(ch, ch) if remap else ch)
    return im


# -------------------------------------------------------------------- churn
# 14 x 18, placed at 9, 13. Narrow at the mouth, wider at the foot, three hoops.
CHURN_X, CHURN_Y = 9, 13
CHURN = [
    '....oRRRRo....',
    '...oRqqQQro...',
    '...oRRqQrro...',
    '...oLWRrwDo...',
    '...ouIIuvvo...',
    '..oLWWwWwwDo..',
    '..oLWWwWwwDo..',
    '..oLWWwWWwDo..',
    '..oLWWwWWwDo..',
    '.oLLWWwWWwwDo.',
    '.ouIIIIIuuvvo.',
    '.oLWWWwWWWwDo.',
    '.oLWWWwWWWwDo.',
    '.oLWWWwWWWwDo.',
    '.ouIIIIIuuvvo.',
    '.oLWWWwWWWwDo.',
    '..oDwwwwwwDo..',
    '...oooooooo...',
]
# dasher handle leaning out to the right; its foot sits in the cream
LEAN = [
    '.......oo.',
    '......oHyo',
    '......oHyo',
    '.....oHyo.',
    '.....oHyo.',
    '....oHyo..',
    '....oHyo..',
    '...oHyo...',
    '...oHyo...',
    '..oHyo....',
    '..oHyo....',
    '...Hyx....',
]
LEAN_DX, LEAN_DY = 3, -10
# lid over the mouth, then the handle straight up through its middle
LID = [
    '...oooooooo...',
    '..oEEEEEEEeo..',
    '.oEEEEEEEEeeo.',
    '.oXeeeeeeeXXo.',
    '..ooLWRrwDoo..',
]
LID_DY = -1
POLE = [
    '.oo.',
    'oHyo',
    'oHyo',
    'oHyo',
    'oHyo',
    'oHyo',
    'oHyo',
    'oHyo',
    'oHyo',
    'oHyo',
    'XHyX',
]
POLE_DX, POLE_DY = 5, -11

# ------------------------------------------------------------------- butter
# 14 x 9 block seen from above and in front, placed at 9, 16.
PAT_X, PAT_Y = 9, 16
PAT = [
    '...OOOOOOOOOO.',
    '..OTTTTTTTTTSO',
    '.OTTpTpTpTpTSO',
    '.OTpTpTpTpTSSO',
    'OTTTTTTTTTTSSO',
    'OFFFFFFFFFFGSO',
    'OFFFFFFFFFFGSO',
    'OSSSSSSSSSSGO.',
    '.OOOOOOOOOOO..',
]
SALTED = {'T': '1', 'p': '2', 'F': '3', 'S': '4', 'G': '5', 'O': '6'}
SALT = [
    '..............',
    '.....s....s...',
    '...s....z.....',
    '......s....z..',
    '..z......s....',
]
RANCID = {'T': '7', 'p': '8', 'F': '9', 'S': '0', 'G': '!', 'O': '@'}
MOULD = [
    '..............',
    '....##....$...',
    '...#$#.....#..',
    '........##....',
    '..#....#$#....',
    '.....#......#.',
    '.#$......##...',
    '....$.........',
]

# ----------------------------------------------------------- buttered bread
# 22 x 13, placed at 5, 11: the same footprint as "breadslice".
SLICE_X, SLICE_Y = 5, 11
SLICE = [
    '........aaaabcc.......',
    '.......adCfgfCdcc.....',
    '.....hhcCfifgjjCkcc...',
    '...bhdCgjjjijijjgCdh..',
    '.bbdCgfjjijjijjjjfjda.',
    'akCfgfjfgjijjjjjjgffkl',
    'makgfgfgjgjjjjjgjfjkal',
    'mlakCCggfjjjjjjjCdkaan',
    '.mlbbdCgggjjjgCCamlal.',
    '...nabbcCCjgCCbbnmmn..',
    '.....nbbalkkabban.....',
    '.......nnnmnlal.......',
    '.........mmnm.........',
]
SPREAD = [
    '......................',
    '......................',
    '......................',
    '.........BYYBB........',
    '.......BYYBBBBBZ......',
    '......BYBBBYYBBBZ.....',
    '.......BBBYBBBBZZ.....',
    '........ZZBBBZZ.......',
]


def build():
    churn = (CHURN, None, 0, 0)
    pat = (PAT, None, 0, 0)
    return {DMI: [
        ('butter_churn', art(CHURN_X, CHURN_Y, churn, (LEAN, None, LEAN_DX, LEAN_DY))),
        ('butter_churn_closed', art(CHURN_X, CHURN_Y, churn, (LID, None, 0, LID_DY),
                                    (POLE, None, POLE_DX, POLE_DY))),
        ('butter', art(PAT_X, PAT_Y, pat)),
        ('butter_salted', art(PAT_X, PAT_Y, (PAT, SALTED, 0, 0), (SALT, None, 0, 0))),
        ('butter_rancid', art(PAT_X, PAT_Y, (PAT, RANCID, 0, 0), (MOULD, None, 0, 0))),
        ('buttered_bread', art(SLICE_X, SLICE_Y, (SLICE, None, 0, 0), (SPREAD, None, 0, 0))),
    ]}


def preview(sheets, out):
    """Review sheet of the actual sprite pixels at 4x; not a gameplay screenshot."""
    z, pad = 4, 14
    states = list(sheets[DMI])
    cell_w = S * z + pad
    img = Image.new('RGBA', (cell_w * len(states) + pad, S * z + S + 80), (74, 104, 58, 255))
    d = ImageDraw.Draw(img)
    d.text((pad, 6), 'States in %s at 4x, then at 1x' % DMI, fill='white')
    for i, (name, frame) in enumerate(states):
        x = pad + i * cell_w
        d.text((x, 26), name, fill=(235, 235, 220))
        d.rectangle((x, 40, x + S * z - 1, 40 + S * z - 1), fill=(96, 128, 72, 255))
        img.alpha_composite(frame.resize((S * z, S * z), Image.NEAREST), (x, 40))
        img.alpha_composite(frame, (x, 48 + S * z))
    img.save(out)


if __name__ == '__main__':
    sheets = build()
    for rel, new_states in sheets.items():
        write_dmi(ROOT / rel, new_states)
    if '--preview' in sys.argv:
        preview(sheets, sys.argv[sys.argv.index('--preview') + 1])
