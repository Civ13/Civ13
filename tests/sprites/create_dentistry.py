"""Original hand-placed 32px art for the dentistry tools and prostheses.

Every pixel comes from the fixed palette and the stamps and coordinates in this
file; there is no external, traced or generated artwork. Released under Civ13's
AGPL-3.0 licence. Run with Pillow from the repository root:

    python3 tests/sprites/create_dentistry.py [--preview sheet.png]

It appends (or replaces) these states in icons/obj/dentistry.dmi (new) and
leaves every other state and every other DMI untouched:

- forceps: iron extraction forceps in the steel greys of the "hemostat" in
  icons/obj/surgery.dmi: two stout beaks curving in over a gap the width of a
  tooth, a pivot, and long bowed handles.
- forceps_bronze: the same forceps in warm golden-brown bronze.
- dental_pick: a slim iron scaler lying on the diagonal, a banded grip below a
  thin shank that ends in a small hooked point.
- chewing_stick: a short brown-barked twig (miswak) on the diagonal with its
  upper end chewed into a fan of pale fibres.
- toothbrush: an 18th-century brush seen from the side: a carved pale bone
  handle with a waist and a hanging hole, and a small head of short off-white
  bristles.
- bridge_gold: an Etruscan band bridge: a gold band that loops round a
  neighbouring tooth at each end and holds a row of three ivory teeth.
- dentures_bone: a full set carved from one piece of slightly yellowed bone,
  upper and lower arches seen from the front and a little above, so the
  horseshoe sweeps back at both sides; blocky teeth in the same bone.
- dentures_human: the same set on a bone base with real human teeth set into
  it, uneven in length and varied in ivory and yellowish shades.
- porcelain_unfired: the same set modelled in dull grey-buff clay before
  firing: low contrast, no highlights.
- dentures_porcelain: the fired set: glossy bright white teeth, pale pinkish
  porcelain gums and a small specular highlight.
- dentures_vulcanite: a dark reddish-brown hard rubber base with white
  porcelain teeth.
- dentures_acrylic: bright pink acrylic gums with clean white teeth.

The six denture states share one stamp (DENTURE) and differ only in their
palette remap and a small detail layer. To change the look, edit this script
and rerun it; do not hand-edit the DMI.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_herb_garden import ROOT, S, write_dmi  # noqa: E402  shared DMI plumbing

DMI = 'icons/obj/dentistry.dmi'

PAL = {
    # iron, the greys of "hemostat" and "retractor" in icons/obj/surgery.dmi
    'o': '#373a4b', 'd': '#5c5f71', 'm': '#9497ab', 'l': '#bfc4d1', 'h': '#ffffff',
    # bronze
    'bz_o': '#3d2812', 'bz_d': '#8c5726', 'bz_m': '#c98a3c', 'bz_l': '#e6b565', 'bz_h': '#fbe3a4',
    # twig bark and its frayed fibres
    'K': '#2c190b', 'B': '#a87745', 'b': '#7f5224', 'n': '#5a3718',
    'F': '#f4e9c4', 'f': '#d8c592', 'e': '#a8905a',
    # toothbrush: bone handle and bristles
    'O': '#4a4132', 'C': '#f1e8cf', 'c': '#d6c9a4', 's': '#a89a74', 'i': '#fffdf2',
    'w': '#e9e4d2', 'x': '#b9b29b', 'z': '#857e69',
    # gold band and ivory teeth of the bridge
    'k': '#4a3208', 'Y': '#ffe680', 'G': '#e8b830', 'g': '#b07d14',
    'J': '#3f3a2c', 'W': '#fbf6e2', 'I': '#e8dfc0', 'j': '#bfb38c',
    # dentures, carved bone (the defaults of the DENTURE stamp)
    'E': '#3e3523',                                            # outline
    'P': '#f0e6c4', 'Q': '#dccd9f', 'q': '#b8a672', 'r': '#8a7a4e',   # base, light to dark
    'T': '#f4ecd0', 't': '#d9cba0', 'u': '#a69563',            # tooth, its shade, the gaps
    'X': '#2a2015',                                            # the dark of the open mouth
    # real human teeth set in the bone base
    'hu_1': '#fbf3d6', 'hu_2': '#ecdca6', 'hu_3': '#d9c078', 'hu_4': '#c4a95e', 'hu_g': '#6e5c30',
    # unfired clay
    'cl_o': '#4b463c', 'cl_1': '#b3aa96', 'cl_2': '#a39a86', 'cl_3': '#8f8674', 'cl_4': '#777062',
    'cl_T': '#b9b09c', 'cl_t': '#a59c88', 'cl_u': '#857d6c', 'cl_X': '#3a362f',
    # fired porcelain
    'po_o': '#4d3338', 'po_1': '#fbdcd8', 'po_2': '#f0bdb8', 'po_3': '#d99a98', 'po_4': '#b27478',
    'po_T': '#ffffff', 'po_t': '#dfe6ee', 'po_u': '#a9b4c4', 'po_X': '#2c1a1e',
    # vulcanite
    'vu_o': '#22100c', 'vu_1': '#9a4a38', 'vu_2': '#7a3324', 'vu_3': '#5c2418', 'vu_4': '#41180f',
    'vu_T': '#fbfbf6', 'vu_t': '#d9dcdc', 'vu_u': '#9da3a8', 'vu_X': '#170a07',
    # acrylic
    'ac_o': '#5a1f33', 'ac_1': '#ffb3c0', 'ac_2': '#f58aa0', 'ac_3': '#d9627e', 'ac_4': '#ad4462',
    'ac_T': '#ffffff', 'ac_t': '#e4e9f0', 'ac_u': '#aab3c2', 'ac_X': '#33101c',
}


def rgba(c):
    c = PAL[c]
    return tuple(int(c[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


def art(x, y, *layers):
    """Stamp each (rows, remap, dx, dy) layer at x + dx, y + dy; '.' is skipped."""
    im = Image.new('RGBA', (S, S))
    p = im.load()
    for rows, remap, dx, dy in layers:
        assert len({len(row) for row in rows}) == 1, rows
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch != '.':
                    p[x + dx + i, y + dy + j] = rgba(remap.get(ch, ch) if remap else ch)
    return im


# ------------------------------------------------------------------ forceps
# 17 x 24, placed at 8, 4. Beaks up, handles down, lit from the top left.
FORCEPS_X, FORCEPS_Y = 8, 4
FORCEPS = [
    '.....ooo.ooo.....',
    '....ohlo.oldo....',
    '...ohlmo.olmdo...',
    '...olmo...olmo...',
    '...olmo...olmo...',
    '...olmdo.olmdo...',
    '....olmdolmdo....',
    '.....olmhmdo.....',
    '......olhdo......',
    '......olmdo......',
    '.....olmomdo.....',
    '.....olo.omo.....',
    '....ohlo.oldo....',
    '....olo...omo....',
    '...ohlo...oldo...',
    '...olo.....omo...',
    '...olo.....omo...',
    '...olo.....omo...',
    '...olo.....omo...',
    '...olo.....omo...',
    '...olmo...omdo...',
    '....olo...omo....',
    '....omo...odo....',
    '.....o.....o.....',
]
BRONZE = {'o': 'bz_o', 'd': 'bz_d', 'm': 'bz_m', 'l': 'bz_l', 'h': 'bz_h'}

# -------------------------------------------------------------- dental pick
# 20 x 20, placed at 6, 6: grip at the bottom left, hooked point at the top right.
PICK_X, PICK_Y = 6, 6
PICK = [
    '..............ooo...',
    '.............olmmo..',
    '.............oo.omo.',
    '................omo.',
    '...............olo..',
    '..............olo...',
    '.............olo....',
    '............olmo....',
    '...........ohmo.....',
    '..........oldmo.....',
    '.........ohmdo......',
    '........oldmo.......',
    '.......ohmdo........',
    '......oldmo.........',
    '.....ohmdo..........',
    '....oldmo...........',
    '...ohmdo............',
    '..olmmo.............',
    '..omdo..............',
    '...oo...............',
]

# ------------------------------------------------------------ chewing stick
# 19 x 19, placed at 6, 7: bark at the bottom left, frayed fibres at the top right.
STICK_X, STICK_Y = 6, 7
STICK = [
    '.............K.K.K.',
    '............KFKFKFK',
    '...........KFfFfFK.',
    '..........KfFfFeFK.',
    '..........KFfFfFK..',
    '.........KBfFfeKK..',
    '........KBbefFK....',
    '.......KBbnKKK.....',
    '......KBbnK........',
    '.....KBbnK.........',
    '....KBbnK..........',
    '...KBBnK...........',
    '..KBbnK............',
    '.KBbnK.............',
    'KBbnK..............',
    'KbnK...............',
    '.KK................',
]

# --------------------------------------------------------------- toothbrush
# 26 x 10, placed at 3, 12: side view, bristles standing up at the right end.
BRUSH_X, BRUSH_Y = 3, 12
BRUSH = [
    '.................OOOOOOO..',
    '................OiwiwiwxO.',
    '................OiwxwxwxO.',
    '................OwxwxwxzO.',
    '.OOOOOOO........OxzxzxzzO.',
    'OiCCCCCCOOOOOOOOOCCCCCCCCO',
    'OCCOCcCCCCCCCCCCCCcccccccO',
    'OccccccsOOOOOOOOOsssssssO.',
    '.OOOOOOO.........OOOOOOO..',
]

# -------------------------------------------------------------- gold bridge
# 28 x 9, placed at 2, 11: a band looped at both ends holding three teeth.
BRIDGE_X, BRIDGE_Y = 2, 11
BRIDGE = [
    '.......JJJJ.JJJJ.JJJJ.......',
    '.kkkk.JWWIIJWWIIJWWIIJ.kkkk.',
    'kYGGgkJWIIIJWIIIJWIIjJkYGGgk',
    'kGkkgYYYYYYYYYYYYYYYYYYGkkgk',
    'kG..gGGGGGGGGGGGGGGGGGGG..gk',
    'kGkkgkggggggggggggggggkGkkgk',
    'kGgggkJWIIjJWIIjJWIIjJkGgggk',
    '.kkkk.JIIjjJIIjjJIjjjJ.kkkk.',
    '.......JJJJ.JJJJ.JJJJ.......',
]

# ----------------------------------------------------------------- dentures
# 22 x 15, placed at 5, 9. Upper arch over lower arch, mouth a little open,
# the horseshoe sweeping back at both sides. E outline, P Q q r base from
# light to dark, T t tooth and its shade, u the gaps between teeth, X the mouth.
DENT_X, DENT_Y = 5, 9
DENTURE = [
    '......EEEEEEEEEE......',
    '....EEPPPPPPPPQQEE....',
    '..EEPPQQQQQQQQQQQqEE..',
    '.EPQQQqqqqqqqqqqqqqrE.',
    'EPQqETTuTTuTTuTTuTEqrE',
    'EQqrETTuTTuTTuTTutEqrE',
    'EqrEEttuTtuTtuTtutEErE',
    '.EEXXEEEEEEEEEEEEEXXE.',
    'EQqEETTuTTuTTuTTuTEErE',
    'EQqrETTuTTuTTuTTutEqrE',
    'EQqrEttuttuttuttutEqrE',
    '.EQqqqqqqqqqqqqqqqqrE.',
    '..EEqrrrrrrrrrrrrrEE..',
    '....EEEEEEEEEEEEEE....',
]
# real teeth: uneven lengths (a gap pixel pulled up or down) and mixed shades
HUMAN = {'T': 'hu_1', 't': 'hu_3', 'u': 'hu_g'}
HUMAN_TEETH = [
    '......................',
    '......................',
    '......................',
    '......................',
    '.....21.32.11.24.3....',
    '.....22.33.12.24.3....',
    '.....3E.43.23.E4.4....',
    '......................',
    '.....E2.13.E1.22.3....',
    '.....12.13.21.32.3....',
    '.....33.24.32.33.4....',
]
HUMAN_KEYS = {'1': 'hu_1', '2': 'hu_2', '3': 'hu_3', '4': 'hu_4'}
CLAY = {'E': 'cl_o', 'P': 'cl_1', 'Q': 'cl_2', 'q': 'cl_3', 'r': 'cl_4',
        'T': 'cl_T', 't': 'cl_t', 'u': 'cl_u', 'X': 'cl_X'}
PORCELAIN = {'E': 'po_o', 'P': 'po_1', 'Q': 'po_2', 'q': 'po_3', 'r': 'po_4',
             'T': 'po_T', 't': 'po_t', 'u': 'po_u', 'X': 'po_X'}
VULCANITE = {'E': 'vu_o', 'P': 'vu_1', 'Q': 'vu_2', 'q': 'vu_3', 'r': 'vu_4',
             'T': 'vu_T', 't': 'vu_t', 'u': 'vu_u', 'X': 'vu_X'}
ACRYLIC = {'E': 'ac_o', 'P': 'ac_1', 'Q': 'ac_2', 'q': 'ac_3', 'r': 'ac_4',
           'T': 'ac_T', 't': 'ac_t', 'u': 'ac_u', 'X': 'ac_X'}
# glaze: a specular glint on the upper gum and one on the lower
GLINT = [
    '......................',
    '......hhh.............',
    '....hh................',
    '......................',
    '......................',
    '......................',
    '......................',
    '......................',
    '......................',
    '.h....................',
]
# vulcanite and acrylic take a softer sheen in their own lightest base colour
SHEEN = [
    '......................',
    '......................',
    '.....PPP..............',
]


def build():
    def denture(remap, *extra):
        return art(DENT_X, DENT_Y, (DENTURE, remap, 0, 0), *extra)
    return {DMI: [
        ('forceps', art(FORCEPS_X, FORCEPS_Y, (FORCEPS, None, 0, 0))),
        ('forceps_bronze', art(FORCEPS_X, FORCEPS_Y, (FORCEPS, BRONZE, 0, 0))),
        ('dental_pick', art(PICK_X, PICK_Y, (PICK, None, 0, 0))),
        ('chewing_stick', art(STICK_X, STICK_Y, (STICK, None, 0, 0))),
        ('toothbrush', art(BRUSH_X, BRUSH_Y, (BRUSH, None, 0, 0))),
        ('bridge_gold', art(BRIDGE_X, BRIDGE_Y, (BRIDGE, None, 0, 0))),
        ('dentures_bone', denture(None)),
        ('dentures_human', denture(HUMAN, (HUMAN_TEETH, HUMAN_KEYS, 0, 0))),
        ('porcelain_unfired', denture(CLAY)),
        ('dentures_porcelain', denture(PORCELAIN, (GLINT, None, 0, 0))),
        ('dentures_vulcanite', denture(VULCANITE, (SHEEN, VULCANITE, 0, 0))),
        ('dentures_acrylic', denture(ACRYLIC, (SHEEN, ACRYLIC, 0, 0))),
    ]}


def preview(sheets, out):
    """Review sheet of the actual sprite pixels at 4x; not a gameplay screenshot."""
    z, pad, per_row = 4, 14, 6
    states = list(sheets[DMI])
    cell_w, cell_h = S * z + pad, S * z + S + 36
    rows = -(-len(states) // per_row)
    img = Image.new('RGBA', (cell_w * per_row + pad, 30 + cell_h * rows), (74, 104, 58, 255))
    d = ImageDraw.Draw(img)
    d.text((pad, 6), 'States in %s at 4x, then at 1x' % DMI, fill='white')
    for i, (name, frame) in enumerate(states):
        x, y = pad + (i % per_row) * cell_w, 26 + (i // per_row) * cell_h
        d.text((x, y), name, fill=(235, 235, 220))
        d.rectangle((x, y + 14, x + S * z - 1, y + 14 + S * z - 1), fill=(96, 128, 72, 255))
        img.alpha_composite(frame.resize((S * z, S * z), Image.NEAREST), (x, y + 14))
        img.alpha_composite(frame, (x, y + 20 + S * z))
    img.save(out)


if __name__ == '__main__':
    sheets = build()
    for rel, new_states in sheets.items():
        write_dmi(ROOT / rel, new_states)
    if '--preview' in sys.argv:
        preview(sheets, sys.argv[sys.argv.index('--preview') + 1])
