"""Original hand-placed 32px art for six lanyards, from a rawhide thong to a coiled nylon cord.

Every pixel comes from the fixed palette, the character stamps and the
coordinate lists in this file; there is no external, traced or generated
artwork. Released under Civ13's AGPL-3.0 licence. Run with Pillow from the
repository root:

    python3 tests/sprites/create_lanyards.py [--preview sheet.png]

It writes two files:

- icons/obj/lanyards.dmi: wrist_thong, sword_knot, neck_cord, fob_chain,
  pistol_lanyard, retention_lanyard - inventory icons, one direction, one
  frame.
- icons/mob/lanyards.dmi: neck_cord, fob_chain, pistol_lanyard,
  retention_lanyard - worn overlays, four directions (SOUTH, NORTH, EAST,
  WEST), one frame. neck_cord follows the necklace V one pixel lower with a
  knotted end under it; fob_chain is a small swag under the belt line (y 18)
  at the wearer's right hip; pistol_lanyard is a one-pixel line from the left
  shoulder to the right hip, as the baldric runs; retention_lanyard is a short
  zigzag coil hanging from the belt at the right hip. Seen from the west the
  right hip is behind the body, so the hip states show only their front edge.
  wrist_thong and sword_knot are tied to a tool or hilt and have no worn state.

To change the look, edit this script and rerun it; do not hand-edit the DMIs.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_belt_pouches import figure, write_dmi  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OBJ = ROOT / 'icons/obj/lanyards.dmi'
MOB = ROOT / 'icons/mob/lanyards.dmi'
S = 32

PAL = {
    # rawhide, light to dark, and its outline
    'A': '#bd8650', 'B': '#94602f', 'C': '#643c1b', 'o': '#2e1a0c',
    # buff leather, light to dark, and its outline
    'p': '#ecd09a', 'q': '#d2ac6c', 'r': '#ab844a', 's': '#7c5a2e', 'O': '#3e2c14',
    # hemp cord, light to dark
    'h': '#d6ba80', 'i': '#ad8d50', 'j': '#7e6432', 'k': '#4c3a1a',
    # brass, light to dark
    'g': '#f8e08a', 'G': '#d2a43a', 'y': '#94691e', 'Y': '#553a0e',
    # off-white cotton, light to dark
    'w': '#f6f2e4', 'W': '#d8d2be', 'x': '#aaa48e', 'X': '#6e6a58',
    # olive-drab nylon, light to dark
    'v': '#98a260', 'V': '#6c763c', 'u': '#474f26', 'U': '#2a3016',
    # black clip, highlight to dark
    'n': '#6a6e74', 'N': '#3a3c40', 'm': '#18191c',
    # steel spring clip
    'e': '#e0e4e8', 'E': '#8e949a', 'f': '#565b60',
}

# name: (left, top, rows). '.' is transparent.
ITEMS = {
    # A loop for the wrist, an overhand knot, and two ends to tie round a haft.
    'wrist_thong': (8, 6, (
        '.....oooooo.....',
        '...ooAAAAABoo...',
        '..oAABooooBBCo..',
        '.oAAoo....ooBCo.',
        '.oABo......oBCo.',
        'oAAo........oBCo',
        'oABo........oBCo',
        'oABo........oBCo',
        '.oABo......oBCo.',
        '.oABBo....oBCCo.',
        '..oABBo..oBCCo..',
        '...oABBooBCCo...',
        '....ooABBCoo....',
        '.....oACBCo.....',
        '....oABooBCo....',
        '...oABo..oBCo...',
        '...oAo....oCo...',
        '....o......o....',
    )),
    # Flat strap loop, a sliding keeper, and a short fringed tassel.
    'sword_knot': (9, 4, (
        '....OOOOOO....',
        '...OpppqqrO...',
        '..OppOOOOrrO..',
        '..OpO....OrO..',
        '.OppO....OrrO.',
        '.OpqO....OrsO.',
        '.OpqO....OrsO.',
        '.OpqO....OrsO.',
        '.OpqO....OrsO.',
        '..OpqO..OrsO..',
        '..OpqO..OrsO..',
        '...OpqOOrsO...',
        '...OsrqqrsO...',
        '....OpqrsO....',
        '....OpqrsO....',
        '.....OqrO.....',
        '....OppqrO....',
        '....OpqrsO....',
        '...OppqrrsO...',
        '...OpqprqsO...',
        '...OpqprqsO...',
        '...OpqprqsO...',
        '...OpOqOsrO...',
        '....O.O.OO....',
    )),
    # Two-ply twisted cord: a long neck loop closed by a knot, with a small end loop below it.
    'neck_cord': (7, 3, (
        '......hihihi......',
        '....hijjjjjjih....',
        '...ijj......iik...',
        '..hj..........jk..',
        '.ij............ik.',
        '.hj............jk.',
        'hj..............ik',
        'ij..............jk',
        'hj..............ik',
        'ij..............jk',
        '.hj............ik.',
        '.ij............jk.',
        '..hj..........ik..',
        '..ijj........jjk..',
        '...hij......iik...',
        '....hijj..jjik....',
        '.....ihijjiik.....',
        '.......hikk.......',
        '.......ijkk.......',
        '......hj..ik......',
        '......ij..jk......',
        '......hj..ik......',
        '.......ihjk.......',
    )),
    # Upright T-bar, a swag of links, and a spring ring with its lever.
    'fob_chain': (5, 9, (
        '.YY...................',
        'YgGY..............YYY.',
        'YgGY.............YggGY',
        'YgGY............YgY.YG',
        'YgGY............YGY.Yy',
        'YgGgY...........YGy.Yy',
        'YgGYGy...........YGyyY',
        'YgGY.gY.........gYYYY.',
        'YgGY.YGy.......GY.....',
        'YgGY..YgY.....gY......',
        '.YY....YGygYGygY......',
        '........YYGyYGY.......',
        '..........YY.Y........',
    )),
    # Braided neck loop, a brass slide to draw it close, and a spring clip for the pistol's ring.
    'pistol_lanyard': (8, 2, (
        '.....XXXXXX.....',
        '...XXwWwWwWXX...',
        '..XwWxXXXXxWwX..',
        '.XWxX......XwxX.',
        '.XwxX......XWxX.',
        'XWxX........XwxX',
        'XwxX........XWxX',
        'XWxX........XwxX',
        'XwxX........XWxX',
        '.XWxX......XwxX.',
        '.XwxX......XWxX.',
        '..XWxX....XwxX..',
        '...XwxX..XWxX...',
        '....XWxXXwxX....',
        '....YgGGGGyY....',
        '....YgGGGGyY....',
        '.....XwWxxX.....',
        '......XWxX......',
        '......XwxX......',
        '......XWxX......',
        '......XwxX......',
        '......fEEf......',
        '.....fEeeEf.....',
        '....fEf..fEf....',
        '....fef...f.....',
        '....fEf..fEf....',
        '.....fEeeEf.....',
        '......ffff......',
    )),
    # Sprung coil between two snap clips.
    'retention_lanyard': (1, 10, (
        '.........UU..UU..UU..UU.......',
        '........UvvU.vvU.vvU.vvU......',
        '.mmmm..UvVuUvVuUvVuUvVuU.mmmm.',
        'mnnNNm.UvVuUvVuUvVuUvVuUmnnNNm',
        'mn..NmvvVuUvVuUvVuUvVuUvmn..Nm',
        'mn..NmUVuUvVuUvVuUvVuUVVmN..Nm',
        'mN.mNmUvVuUvVuUvVuUvVuU.mNm.Nm',
        'mNNNNm.UVuUUVuUUVuUUVuU.mNNNNm',
        '.mmmm...UU..UU..UU..UU...mmmm.',
    )),
}

# Worn overlays: (x, y, palette key) lists per direction, hand-placed on the
# standard body (neck y 9-10, torso x 11-19, belt line y 18). Light tones are
# swapped for mid ones so the lines still show on skin and on a pale tunic.
NECK_SOUTH = (
    (12, 10, 'i'), (13, 11, 'j'), (14, 12, 'i'), (14, 13, 'j'), (15, 14, 'i'),
    (16, 13, 'j'), (16, 12, 'i'), (17, 11, 'j'), (18, 10, 'i'),
    (15, 15, 'k'), (15, 16, 'j'),
)
NECK_NORTH = ((13, 10, 'i'), (14, 10, 'j'), (15, 10, 'i'), (16, 10, 'j'), (17, 10, 'i'))
NECK_EAST = (
    (14, 9, 'i'), (15, 10, 'j'), (16, 10, 'i'), (17, 11, 'j'), (18, 11, 'i'), (19, 12, 'j'),
    (19, 13, 'i'), (19, 14, 'k'), (19, 15, 'j'),
)

FOB_SOUTH = ((11, 19, 'G'), (11, 20, 'y'), (12, 21, 'G'), (13, 21, 'y'), (14, 20, 'G'), (14, 19, 'y'))
FOB_EAST = ((14, 19, 'G'), (14, 20, 'y'), (15, 21, 'G'), (16, 21, 'y'), (17, 20, 'G'), (17, 19, 'y'))
FOB_WEST = ((12, 19, 'y'), (12, 20, 'G'))

# Left shoulder (viewer's right from the front) down to the right hip, one
# step per pixel, with the brass slide on the chest and the clip at the hip.
PISTOL_SOUTH = (
    (19, 10, 'X'), (18, 11, 'W'), (17, 12, 'X'), (16, 13, 'W'), (15, 14, 'G'),
    (14, 15, 'W'), (13, 16, 'X'), (12, 17, 'W'), (11, 18, 'X'), (11, 19, 'E'), (11, 20, 'f'),
)
PISTOL_NORTH = (
    (11, 10, 'X'), (12, 11, 'W'), (13, 12, 'X'), (14, 13, 'W'), (15, 14, 'X'),
    (16, 15, 'W'), (17, 16, 'X'), (18, 17, 'W'), (19, 18, 'X'),
)
# East shows the right hip: the cord rises from it to the chest and to the back.
PISTOL_EAST = (
    (11, 14, 'X'), (12, 15, 'W'), (13, 16, 'X'), (14, 17, 'W'), (15, 18, 'X'),
    (16, 17, 'W'), (17, 16, 'X'), (18, 15, 'G'), (19, 14, 'X'), (15, 19, 'E'), (15, 20, 'f'),
)
# West shows the left shoulder: the cord falls from it to the chest and to the back.
PISTOL_WEST = (
    (12, 13, 'X'), (13, 12, 'G'), (14, 11, 'X'), (15, 10, 'W'), (16, 10, 'X'),
    (17, 11, 'W'), (18, 12, 'X'), (19, 13, 'W'), (20, 14, 'X'),
)

RETENTION_SOUTH = (
    (11, 18, 'm'), (11, 19, 'V'), (12, 20, 'u'), (11, 21, 'V'), (12, 22, 'u'), (11, 23, 'V'), (11, 24, 'm'),
)
RETENTION_EAST = (
    (15, 18, 'm'), (15, 19, 'V'), (16, 20, 'u'), (15, 21, 'V'), (16, 22, 'u'), (15, 23, 'V'), (15, 24, 'm'),
)
RETENTION_WEST = ((12, 19, 'V'), (13, 21, 'u'), (14, 23, 'm'))

ORDER_MOB = ('neck_cord', 'fob_chain', 'pistol_lanyard', 'retention_lanyard')


def rgba(ch):
    c = PAL[ch]
    return (int(c[1:3], 16), int(c[3:5], 16), int(c[5:7], 16), 255)


def stamp(rows, left, top):
    assert len({len(r) for r in rows}) == 1, 'ragged stamp'
    img = Image.new('RGBA', (S, S))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != '.':
                img.putpixel((left + x, top + y), rgba(ch))
    return img


def plot(pixels):
    img = Image.new('RGBA', (S, S))
    for x, y, ch in pixels:
        img.putpixel((x, y), rgba(ch))
    return img


def mirrored(img):
    return img.transpose(Image.FLIP_LEFT_RIGHT)


def behind(img):
    """The same hip item seen from the back: mirrored about the torso centre, x 15."""
    out = Image.new('RGBA', (S, S))
    out.paste(mirrored(img).crop((1, 0, S, S)), (0, 0))
    return out


def worn():
    neck_east = plot(NECK_EAST)
    fob, ret = plot(FOB_SOUTH), plot(RETENTION_SOUTH)
    return {
        'neck_cord': [plot(NECK_SOUTH), plot(NECK_NORTH), neck_east, mirrored(neck_east)],
        'fob_chain': [fob, behind(fob), plot(FOB_EAST), plot(FOB_WEST)],
        'pistol_lanyard': [plot(PISTOL_SOUTH), plot(PISTOL_NORTH), plot(PISTOL_EAST), plot(PISTOL_WEST)],
        'retention_lanyard': [ret, behind(ret), plot(RETENTION_EAST), plot(RETENTION_WEST)],
    }


def preview(items, mobs, out, scale=4):
    cell, label = S * scale, 14
    white = (235, 235, 235, 255)
    img = Image.new('RGBA', (cell * 8 + 100, (cell + label) * (1 + len(mobs)) + 40), (34, 34, 40, 255))
    d = ImageDraw.Draw(img)
    for i, (name, im) in enumerate(items.items()):
        d.text((i * cell + 4, 1), name, fill=white)
        img.alpha_composite(im.resize((cell, cell), Image.NEAREST), (i * cell, label))
        # 1x on the dark sheet and on a light inventory-slot grey
        img.alpha_composite(im, (i * cell + 20, label + cell + 4))
        d.rectangle((i * cell + 60, label + cell + 4, i * cell + 91, label + cell + 35), fill=(150, 150, 150, 255))
        img.alpha_composite(im, (i * cell + 60, label + cell + 4))
    y = cell + label + 40
    for name, frames in mobs.items():
        d.text((4, y + 1), '%s worn: S N E W over a plain tunic, S N E W on the bare body, then 1x' % name, fill=white)
        for half, uniform in enumerate(('white_tunic', None)):
            for direction in range(4):
                fig = figure(direction, uniform)
                fig.alpha_composite(frames[direction])
                img.alpha_composite(fig.resize((cell, cell), Image.NEAREST), ((half * 4 + direction) * cell, y + label))
                img.alpha_composite(fig, (8 * cell + 4 + direction * 22, y + label + 20 + half * 44))
        y += cell + label
    img.save(out)


def main(argv):
    items = {name: stamp(rows, left, top) for name, (left, top, rows) in ITEMS.items()}
    mobs = worn()
    write_dmi(OBJ, items, 1)
    write_dmi(MOB, mobs, 4)
    print('wrote', OBJ.relative_to(ROOT), 'and', MOB.relative_to(ROOT))
    if '--preview' in argv:
        preview(items, mobs, argv[argv.index('--preview') + 1])


if __name__ == '__main__':
    main(sys.argv[1:])
