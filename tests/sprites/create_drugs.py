"""Original hand-placed 32px art for the traditional drug preparations.

Every pixel comes from the fixed palette and the hand-authored pixel maps in
this file; there is no external, traced or generated artwork. Released under
Civ13's AGPL-3.0 licence. Run with Pillow from the repository root:

    python3 tests/sprites/create_drugs.py [--check] [--preview sheet.png]

It appends (or replaces) only the states below and leaves every other state in
both sheets untouched:

- icons/farming/plants.dmi: khat-grow1 .. khat-grow6, khat-harvest, khat-dead.
  A woody shrub in the coca/coffee shrub colours and scale, with glossy oval
  leaves and reddish young shoots at the tips.
- icons/obj/drugs.dmi: khat (a tied bundle of fresh shoots), cannabis_fresh
  (sticky green flower tops), cannabis (the same tops dried), hashish (a
  pressed resin slab) and opium_latex (a ball of raw latex on a leaf).

It reuses the DMI reader and writer of create_herb_garden.py. `--check`
verifies the committed sheets without writing; `--preview <png>` writes a 4x
review sheet on mid-grey. To change the look, edit this script and rerun it;
do not hand-edit the DMI.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_herb_garden import read_dmi, write_dmi  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
PLANTS = 'icons/farming/plants.dmi'
DRUGS = 'icons/obj/drugs.dmi'
S = 32

PAL = {
    # woody stems: the coca/coffee shrub browns
    's': '#794700', 'S': '#996600', 'T': '#bb8000',
    # khat leaves, dark to glossy highlight
    'd': '#2c5206', 'g': '#416401', 'G': '#4f7901', 'h': '#86b82e',
    # young khat shoots
    'r': '#7a1c12', 'R': '#b5301e', 'p': '#e0664a',
    # dead bush
    'b': '#402805', 'B': '#794700', 'n': '#956939', 'y': '#c2a400',
    # item outline
    'o': '#1a1408',
    # twine
    't': '#8a6a34', 'U': '#c9a868',
    # cannabis buds: dark, mid, light, frost; pistil hairs
    'a': '#2f5a1e', 'c': '#4c8a2c', 'C': '#74b548', 'w': '#cfeeb0', 'i': '#d98a2a',
    # dried cannabis
    'e': '#43401a', 'j': '#6b6226', 'J': '#8f8238', 'W': '#b9ad6a', 'I': '#8a4a1a',
    # resin and latex browns, darkest to gloss
    'k': '#1e1108', 'm': '#33200f', 'l': '#4b3018', 'L': '#6a4826', 'H': '#a9825a',
    # poppy leaf (grey-green)
    'x': '#33552c', 'f': '#4f7a3e', 'F': '#6c9a55', 'v': '#9cc084',
}
DRY = {'a': 'e', 'c': 'j', 'C': 'J', 'w': 'W', 'i': 'I', 'S': 's'}


def rgba(c):
    c = PAL[c]
    return (int(c[1:3], 16), int(c[3:5], 16), int(c[5:7], 16), 255)


def stamp(im, x, y, rows, remap=None):
    px = im.load()
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch != '.' and 0 <= x + i < S and 0 <= y + j < S:
                px[x + i, y + j] = rgba(remap.get(ch, ch) if remap else ch)


def outline(im, c='o'):
    """The usual dark item outline: every empty pixel touching the drawing."""
    src = im.copy().load()
    px = im.load()
    for y in range(S):
        for x in range(S):
            if src[x, y][3]:
                continue
            if any(0 <= x + dx < S and 0 <= y + dy < S and src[x + dx, y + dy][3]
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px[x, y] = rgba(c)
    return im


# ------------------------------------------------------------------ khat shrub
# (x, bottom row is y = 23 like the coca and coffee shrubs)
KHAT = {
    'grow1': (15, [
        '.g.',
        '.gd',
        'dg.',
    ]),
    'grow2': (14, [
        '..R..',
        '.dg..',
        '.gGd.',
        'dgS..',
        '..Sg.',
        '..S..',
        '.sS..',
    ]),
    'grow3': (11, [
        '....R...R..',
        '..R.gd.dg..',
        '.dgdGGgGgd.',
        'dGhgdgSgGhg',
        '.dgdS.sdgd.',
        '..d.sS.S...',
        '.....SsS...',
        '.....Ss....',
        '.....Ss....',
        '....sSs....',
    ]),
    'grow4': (10, [
        '.....R..R....',
        '..R..gd.gg.R.',
        '.dgGgGGgdGgg.',
        'dGhGdgGhGgGGd',
        'dgGgdGgSdgGhg',
        '.dgdgGdSsgGgd',
        '..dGgdsS.sdd.',
        '...dd.sSSs...',
        '......sSs....',
        '......sS.....',
        '......sSs....',
        '.....sSSs....',
    ]),
    'grow5': (9, [
        '.....R...R.....',
        '...R.gg.dgG.R..',
        '..dgGGhGgGhGgd.',
        '.dGhGgdgGGgdGGd',
        'RgGGgdGGhgdGhGg',
        'dgdgGhGgdGGgGgd',
        'dGGgdgGdSdgGGhd',
        '.dgGGgdsSsdgGd.',
        '..ddgd.sS.Sgd..',
        '....d.S.Ss.d...',
        '.......SSs.....',
        '.......sS......',
        '.......sSs.....',
        '......sSSs.....',
    ]),
    'grow6': (8, [
        '......R...R.......',
        '....R.gd.dgR..R...',
        '...dgGGgdGGgdgg...',
        '..dGhGgGhGgGGhGd.R',
        '.RgGGgdgGGgdGGgdg.',
        '.ggdgGhgdgGhGGgGd.',
        'dgGhgGGGdgGGgdgGhd',
        'dGGgdgGgSdgGhGgdGd',
        '.dgGhgdSsgGGgdgGd.',
        '..dgdgdSdsdgGgdd..',
        '...dd.sS.sSddd....',
        '.....s.SS.s.......',
        '........Ss........',
        '........Ss........',
        '.......sSs........',
        '.......sSSs.......',
    ]),
    'dead': (9, [
        '....b.....b....',
        '.b..B..b..B..y.',
        '..B.b.B..Bb.B..',
        '.y.Bb.B.B..B..b',
        'b.B.BnB.BnB..B.',
        '.B..bSBsB.nSB..',
        '..BS.sSs.Ss.y..',
        '.y..SsSSs......',
        '.....sSs.......',
        '......Ss.......',
        '.....sSs..y....',
        '....sSSs.y.....',
    ]),
}
SHOOT = [   # a bright young shoot cluster for the harvest stage
    '.p.',
    'pRr',
    '.r.',
]
HARVEST_SHOOTS = [(13, 6), (9, 8), (17, 7), (21, 9), (7, 11), (11, 12), (15, 11), (19, 13), (23, 12), (13, 15)]


def khat_stage(stage):
    im = Image.new('RGBA', (S, S))
    x, rows = KHAT['grow6' if stage == 'harvest' else stage]
    stamp(im, x, 24 - len(rows), rows)
    if stage == 'harvest':
        for sx, sy in HARVEST_SHOOTS:
            stamp(im, sx, sy, SHOOT)
    return im


# ----------------------------------------------------------------- khat bundle
KHAT_BUNDLE = [
    '.........dg...dg..',
    '....dg..dGhg.dGhg.',
    '...dGhg.gGGd.gGgd.',
    '...gGgd.dgR.dgdR..',
    '.dg.dgRdgGhgRdgg..',
    'dGhg.RrgGGgdrgGhg.',
    'gGGdRdgdggdRrdGGd.',
    '.dgRr.dGhRRr.Rdg..',
    '..dgRRgGgRrRRr....',
    '...dgdRgdRRr......',
    '.....RrRRRr.......',
    '.....tUtUtt.......',
    '....tUtUtt........',
    '....rRRrRr........',
    '...rRrRRr.........',
    '...RrRrr..........',
    '..rR.Rr...........',
]


def khat():
    im = Image.new('RGBA', (S, S))
    stamp(im, 7, 8, KHAT_BUNDLE)
    return outline(im)


# -------------------------------------------------------------- cannabis tops
BUD = [   # a dense frosty flower top on its cut stem
    '...C...',
    '..cwc..',
    '.cCiCc.',
    '.CwCwca',
    'cCCwCia',
    'ciCCwca',
    'cCwCCca',
    '.cCiCa.',
    '.caCca.',
    '..cca..',
    '...S...',
    '...S...',
]
BUD_SMALL = [
    '..C..',
    '.cwc.',
    'cCiCa',
    'cwCca',
    'cCwia',
    '.cCa.',
    '.aca.',
    '..S..',
]
BUD_DRY = [   # shrunk, with a withered tip
    '..c...',
    '.cCc..',
    'cCicc.',
    'cwCCia',
    'ciCwca',
    'cCCcca',
    '.cica.',
    '.acca.',
    '..S...',
    '..S...',
]
BUD_DRY_SMALL = [
    '.cC..',
    'cCic.',
    'cwCca',
    '.cia.',
    '.aca.',
    '..S..',
]
SUGAR_L = [   # small serrated leaf, pointing left and up
    'a....',
    'ca.a.',
    'aCca.',
    '.acCa',
    '..aa.',
]
SUGAR_R = [row[::-1] for row in SUGAR_L]


def layered(parts, remap=None):
    """Paint parts back to front, each with its own outline so the tops stay separate."""
    im = Image.new('RGBA', (S, S))
    for x, y, rows in parts:
        part = Image.new('RGBA', (S, S))
        stamp(part, x, y, rows, remap)
        im.alpha_composite(outline(part))
    return im


def cannabis_fresh():
    return layered([(6, 16, SUGAR_L), (21, 16, SUGAR_R), (8, 13, BUD_SMALL), (19, 12, BUD_SMALL),
                    (13, 9, BUD), (11, 19, SUGAR_L)])


def cannabis():
    return layered([(8, 17, SUGAR_L), (9, 14, BUD_DRY_SMALL), (18, 13, BUD_DRY_SMALL), (13, 11, BUD_DRY)], DRY)


# --------------------------------------------------------------------- hashish
HASH = [   # a pressed slab: lit top face, darker cut front
    '....lllllllll..',
    '...lLLHHLLLlll.',
    '..lLHLLLLLlllmm',
    '.lLLLLLlLlllmmm',
    'lllllllllllmmmk',
    'mmmmmmmmmmmmmkk',
    'mkmmlmmkmmmkmkk',
    'mmmkmmmmmkmmkk.',
    'kkkkkkkkkkkkk..',
]


def hashish():
    im = Image.new('RGBA', (S, S))
    stamp(im, 8, 12, HASH)
    return outline(im)


# ----------------------------------------------------------------- opium latex
LEAF = [
    '......ffffff......',
    '...ffFFFFFFFFff...',
    '.ffFFFFFFFFFFFFff.',
    'fFvvvvFFFFFFvvvvFf',
    'xfFFFFvvvvvvFFFFfx',
    '.xffFFFFFFFFFFffx.',
    '...xxffffffffxx...',
    '......xxxxxx......',
]
BALL = [
    '..lll..',
    '.lLHLl.',
    'lLHLlmm',
    'lLllmmk',
    'llmmmkk',
    '.mmkkk.',
    '..kkk..',
]


def opium_latex():
    im = Image.new('RGBA', (S, S))
    stamp(im, 7, 15, LEAF)
    outline(im)
    ball = Image.new('RGBA', (S, S))
    stamp(ball, 13, 11, BALL)
    im.alpha_composite(outline(ball))
    return im


STAGES = ['grow%d' % i for i in range(1, 7)] + ['harvest', 'dead']


def build():
    return {
        PLANTS: [('khat-%s' % st, khat_stage(st)) for st in STAGES],
        DRUGS: [('khat', khat()), ('cannabis_fresh', cannabis_fresh()), ('cannabis', cannabis()),
                ('hashish', hashish()), ('opium_latex', opium_latex())],
    }


def check(sheets):
    for rel, new_states in sheets.items():
        states = {name: frames for name, _, frames in read_dmi(ROOT / rel)[1]}
        bad = [name for name, frame in new_states
               if name not in states or len(states[name]) != 1 or states[name][0].tobytes() != frame.tobytes()]
        if bad:
            sys.exit('%s is stale for: %s; rerun create_drugs.py' % (rel, ', '.join(bad)))
        print('%s matches create_drugs.py (%s)' % (rel, ', '.join(n for n, _ in new_states)))


def preview(sheets, out):
    """Review sheet of the actual sprite pixels at 4x on mid-grey; not a gameplay screenshot."""
    existing = {name: frames[0] for name, _, frames in read_dmi(ROOT / PLANTS)[1]}
    refs = [('ref: ' + n, existing[n]) for n in ('coca-grow3', 'coca-grow6', 'coca-harvest', 'coca-dead',
                                                'coffee-grow6', 'coffee-harvest') if n in existing]
    rows = [(PLANTS, sheets[PLANTS]), (DRUGS, sheets[DRUGS]), ('existing shrubs, for scale', refs)]
    z, pad, label, per_row = 4, 12, 16, 8
    cw, chh = S * z + pad, S * z + label + 34 + pad
    img = Image.new('RGBA', (cw * per_row + pad, sum(22 + chh for _ in rows) + pad), (128, 128, 128, 255))
    d = ImageDraw.Draw(img)
    y = pad
    for title, cells in rows:
        d.text((pad, y), title, fill=(255, 255, 255))
        y += 22
        for col, (name, frame) in enumerate(cells):
            x = pad + col * cw
            d.text((x, y), name, fill=(20, 20, 20))
            d.rectangle((x, y + label, x + S * z - 1, y + label + S * z - 1), outline=(110, 110, 110))
            img.alpha_composite(frame.resize((S * z, S * z), Image.NEAREST), (x, y + label))
            img.alpha_composite(frame, (x, y + label + S * z + 2))  # actual size
        y += chh
    Path(out).parent.mkdir(parents=True, exist_ok=True)
    img.save(out)


if __name__ == '__main__':
    new = build()
    if '--check' in sys.argv:
        check(new)
    else:
        for rel, states in new.items():
            write_dmi(ROOT / rel, states)
    if '--preview' in sys.argv:
        preview(new, sys.argv[sys.argv.index('--preview') + 1])
