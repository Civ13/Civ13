"""Hand-placed 32px art for the tachi, the older Japanese cavalry sword.

A tachi is longer and more deeply curved than a katana, the curve is
strongest just above the hilt (koshi-zori), and it is slung from the belt
edge down by two hangers instead of being thrust through the sash edge up.
The mounting is a tachi mounting: gilt pommel cap, guard, two hanger bands
and chape on a black lacquered scabbard, with a red cord.

Every pixel comes from the fixed palette and the character stamps in this
file (Pillow only); there is no external, traced or generated artwork. The
steel, gilt, wrap, lacquer and cord colours are the ones the "katana" state
uses in the same five sheets, plus two darker cord reds. Released under
Civ13's AGPL-3.0 licence. Run with Pillow from the repository root:

    python3 tests/sprites/create_tachi.py [--check] [--preview sheet.png]

It adds one state named "tachi" to five shared sheets, with the direction
and frame counts of "katana" in each, and leaves every other state alone:

- icons/obj/weapons.dmi: the drawn sword as an item, one direction. Hilt at
  the lower left and point at the upper right like the katana, but the
  blade bows towards the lower right and the short hilt leaves it longer.
- icons/mob/items/lefthand_weapons.dmi, righthand_weapons.dmi: held, four
  directions (SOUTH, NORTH, EAST, WEST). The grip sits on the katana's
  pixels; the blade leaves the hand flatter, bends up and ends higher. The
  right hand is the left hand mirrored, as it is for the katana.
- icons/mob/belt.dmi: worn, four directions. It hangs below the belt line
  (y 18-19 from the top) on the hip the katana uses, nearly level, hilt
  forward, with the hilt and the point both turned up - the opposite of the
  katana, which slants down and back. From the west the hips hide the
  middle and the hangers; from the north only the scabbard shows.
- icons/mob/back.dmi: worn, four directions, on the katana's diagonal from
  the right shoulder to the left hip, with an upright hilt and a longer,
  bending scabbard.

New tiles go after the last used tile of each sheet; a row is added when the
last row is full. The sheet's own metadata text is kept as it is, with the
new state appended. --check verifies the committed sheets without writing.
To change the look, edit this script and rerun it; do not hand-edit the
states.
"""
import re
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))

ROOT = Path(__file__).resolve().parents[2]
ITEM = 'icons/obj/weapons.dmi'
LEFT = 'icons/mob/items/lefthand_weapons.dmi'
RIGHT = 'icons/mob/items/righthand_weapons.dmi'
BELT = 'icons/mob/belt.dmi'
BACK = 'icons/mob/back.dmi'
SHEETS = (ITEM, LEFT, RIGHT, BELT, BACK)
STATE = 'tachi'
MODEL = 'katana'
S = 32

PAL = {
    # item: steel outline, face, lit edge (weapons.dmi "katana")
    'o': '#7a7c80', 's': '#a5acb4', 'e': '#c7cbcd',
    # item: hilt wrap, light to dark, and its highlight
    '7': '#494950', '8': '#2e2f34', '9': '#1e1e20', 'a': '#72777d',
    # gilt fittings, light to dark (the katana guard)
    'L': '#dab479', 'G': '#b4924e', 'D': '#8c6a2e', 'K': '#5e441b',
    # held: blade, grip shade, grip
    'W': '#efefef', 'h': '#565656', 'k': '#000000',
    # worn: lacquer, its sheen, the lit ridge
    'b': '#080808', 'g': '#494949', 'i': '#505050', 'm': '#565656',
    # cord, light to dark
    'R': '#ff0000', 'r': '#cc0000', 'c': '#660000',
}

# Each stamp is (left, top, rows); '.' is transparent.

# The drawn sword. Gilt pommel cap with the cord loop at the lower left, a
# level wrapped grip, the guard, then the blade: almost level at the guard,
# bending up within the first third and running nearly straight to the point.
ITEM_ART = (0, 0, (
    '..............................oo',
    '.............................oeo',
    '.............................oeo',
    '............................oseo',
    '............................oseo',
    '...........................oseo.',
    '...........................oseo.',
    '..........................oseo..',
    '..........................oseo..',
    '.........................oseo...',
    '.........................oseo...',
    '........................oseo....',
    '........................oseo....',
    '.......................oseo.....',
    '......................osseo.....',
    '.....................osseo......',
    '....................osseo.......',
    '...................osseo........',
    '..................osseo.........',
    '.................osseo..........',
    '..........L.....osseo...........',
    '..........LG..oosseo............',
    '..........LGoosseeo.............',
    'LG99999999GGssseeo..............',
    'GD7a87a87aGDeeeoo...............',
    'DK87D87a87GDooo.................',
    '.R99999999DD....................',
    'r.r........K....................',
    '.c..............................',
))

# Held in the left hand. South: the blade leaves the fist to the viewer's
# right; the gilt guard flanks its base and the pommel shows under the fist.
HELD_SOUTH = (20, 4, (
    '...........W',
    '...........W',
    '..........WW',
    '..........W.',
    '.........WW.',
    '.........W..',
    '........WW..',
    '........W...',
    '.......WW...',
    '.......W....',
    '......WW....',
    '.....WW.....',
    '....WW......',
    '..WWW.......',
    '.GWW........',
    '.kWG........',
    '.hh.........',
    'k...........',
    'G...........',
))
# North: the body hides the blade between the fist and the far shoulder.
HELD_NORTH = (8, 4, (
    '.................W',
    '.................W',
    '................WW',
    '................W.',
    '...............WW.',
    '..............WW..',
    '.............WW...',
    '.............W....',
    '..................',
    '..................',
    '..................',
    '..................',
    '..................',
    '...W..............',
    '..GW..............',
    '.kkk..............',
    'kkk...............',
    'Gk................',
))
HELD_EAST = (19, 2, (
    '...........W',
    '...........W',
    '..........WW',
    '..........W.',
    '.........WW.',
    '.........W..',
    '........WW..',
    '........W...',
    '.......WW...',
    '.......W....',
    '......WW....',
    '.....WW.....',
    '....WW......',
    '..WWW.......',
    '.GWW........',
    '.kk.........',
    'G...........',
))
# West: the fist covers the grip between the guard and the pommel.
HELD_WEST = (3, 3, (
    'W.................',
    'W.................',
    'WW................',
    '.W................',
    '.WW...............',
    '..W...............',
    '..WW..............',
    '...W..............',
    '...WW.............',
    '....W.............',
    '....WW............',
    '.....WW...........',
    '......WW..........',
    '.......WWW........',
    '.........WWW......',
    '...........WWG....',
    '..................',
    '..................',
    '................k.',
    '................kk',
    '.................G',
))

# Slung from the belt. East shows the whole sword on the near hip: pommel
# and guard forward, two gilt hanger bands with their cords up to the belt,
# the scabbard sagging between hilt and point and ending in a gilt chape.
BELT_EAST = (3, 16, (
    '......................L',
    'L....................kG',
    'DGii................kk.',
    '.kkbiii...R...R....L...',
    '....kkbiiiL...R.iiiGkk.',
    '.......kkkDiiiLibbkD...',
    '..............Dkkk.....',
))
# South: seen from in front the sword swings out past the right hip, guard
# and short hilt towards the viewer, the point turned up beside the arm.
BELT_SOUTH = (4, 18, (
    'L..........',
    'DGi..R.R...',
    '.kbi.R.R..L',
    '..kbiLiL.kG',
    '...kkDbDGk.',
    '.....kkkD..',
))
# North: only the scabbard and its hangers, on the same hip.
BELT_NORTH = (19, 18, (
    '........L',
    '.R.R..iGD',
    '.R.R.ibk.',
    'iLiLibk..',
    'bDbDkk...',
    'kkk......',
))

# On the back, seen from behind (north): upright hilt over the right
# shoulder, the scabbard bending down to the left hip, flattening to the
# chape. Black edges with a lit ridge, as on the katana.
BACK_NORTH = (3, 2, (
    '....................LG.',
    '...................kbk.',
    '...................kbk.',
    '..................kbk..',
    '..................kbk..',
    '.................DLGGD.',
    '.................kmk...',
    '................DLDR...',
    '...............kmk.r...',
    '..............kmk..R...',
    '.............DLD..r....',
    '............kmk.rR.....',
    '...........kmk.........',
    '..........kmk..........',
    '.........kmk...........',
    '........kmk............',
    '.......kmk.............',
    '.....kkmmk.............',
    '...kkmmkk..............',
    '.DLGmkk................',
    'DLGkk..................',
    '.DD....................',
))
# From in front (south) the hilt stands over the same shoulder and the
# chape shows past the opposite hip.
BACK_SOUTH_HILT = (6, 2, (
    '.GL..',
    '.kbk.',
    '.kbk.',
    '..kbk',
    '..kbk',
    'DGGLD',
    '..kmk',
))
BACK_SOUTH_TIP = (23, 19, (
    'k....',
    'mmk..',
    'kkGLD',
    '...DD',
))
# East: the hilt behind the right shoulder with the cord hanging from the
# upper hanger band.
BACK_EAST = (5, 3, (
    '.GL....',
    '.kik...',
    '.kik...',
    '..kik..',
    '..kik..',
    '.DGLGD.',
    '...kik.',
    '...DLDc',
    '....kR.',
    '....r..',
    '...R...',
    '...r...',
))
# West: the lower scabbard and chape behind the left hip.
BACK_WEST = (20, 19, (
    'k.......',
    'kgk.....',
    '.kgk....',
    '..kggk..',
    '...kkGLD',
    '.....DD.',
))


def rgba(ch):
    c = PAL[ch]
    return (int(c[1:3], 16), int(c[3:5], 16), int(c[5:7], 16), 255)


def stamp(*stamps):
    img = Image.new('RGBA', (S, S))
    for left, top, rows in stamps:
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch != '.':
                    img.putpixel((left + x, top + y), rgba(ch))
    return img


def mirrored(img):
    return img.transpose(Image.FLIP_LEFT_RIGHT)


def behind_hips(img, x0=12, x1=19):
    """The far-hip view: the hips hide the sword between x0 and x1."""
    out = img.copy()
    out.paste((0, 0, 0, 0), (x0, 0, x1 + 1, S))
    return out


def tachi():
    """{sheet: [tile, ...]} in BYOND direction order (SOUTH, NORTH, EAST, WEST)."""
    held = [stamp(HELD_SOUTH), stamp(HELD_NORTH), stamp(HELD_EAST), stamp(HELD_WEST)]
    belt_east = stamp(BELT_EAST)
    return {
        ITEM: [stamp(ITEM_ART)],
        LEFT: held,
        # the right hand is the left hand mirrored, so east and west trade places
        RIGHT: [mirrored(held[0]), mirrored(held[1]), mirrored(held[3]), mirrored(held[2])],
        BELT: [stamp(BELT_SOUTH), stamp(BELT_NORTH), belt_east, behind_hips(mirrored(belt_east))],
        BACK: [stamp(BACK_SOUTH_HILT, BACK_SOUTH_TIP), stamp(BACK_NORTH), stamp(BACK_EAST),
               stamp(BACK_WEST)],
    }


# -------------------------------------------------------------------- sheets

def read_sheet(path):
    """(metadata text, [(name, dirs, frames, first tile)], RGBA sheet)."""
    src = Image.open(path)
    text = src.info['Description']
    sheet = src.convert('RGBA')
    states, at = [], 0
    for block in re.split(r'(?m)^state = ', text)[1:]:
        name = re.match(r'"(.*)"', block).group(1)
        dirs = int(re.search(r'\tdirs = (\d+)', block).group(1))
        frames = int(re.search(r'\tframes = (\d+)', block).group(1))
        states.append((name, dirs, frames, at))
        at += dirs * frames
    return text, states, sheet


def find(states, name):
    found = [s for s in states if s[0] == name]
    if len(found) > 1:
        raise SystemExit('more than one "%s" state' % name)
    return found[0] if found else None


def box(sheet, i):
    cols = sheet.width // S
    return ((i % cols) * S, (i // cols) * S, (i % cols) * S + S, (i // cols) * S + S)


def tiles(sheet, state):
    _, dirs, frames, at = state
    return [sheet.crop(box(sheet, at + i)) for i in range(dirs * frames)]


def shape(state):
    return state[1], state[2]


def with_tachi(path, drawn):
    """The sheet with the tachi tiles in place, and its metadata text."""
    text, states, sheet = read_sheet(path)
    model, mine = find(states, MODEL), find(states, STATE)
    if model is None or shape(model) != (len(drawn), 1):
        raise SystemExit('%s: "%s" is not the %d-direction state this script follows' % (
            path, MODEL, len(drawn)))
    if mine is None:
        at = sum(s[1] * s[2] for s in states)
        text = text.replace('# END DMI', 'state = "%s"\n\tdirs = %d\n\tframes = 1\n# END DMI' % (
            STATE, len(drawn)))
    elif shape(mine) != shape(model):
        raise SystemExit('%s: "%s" has other directions or frames than "%s"' % (path, STATE, MODEL))
    else:
        at = mine[3]
    cols = sheet.width // S
    rows = max(sheet.height // S, (at + len(drawn) + cols - 1) // cols)
    out = Image.new('RGBA', (sheet.width, rows * S))
    out.paste(sheet, (0, 0))
    for i, tile in enumerate(drawn):
        out.paste(tile, box(out, at + i))
    return out, text


def write_sheet(path, sheet, text):
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta, optimize=True)


def check():
    """The committed sheets hold exactly the tachi this script draws."""
    problems = []
    for rel, drawn in tachi().items():
        _, states, sheet = read_sheet(ROOT / rel)
        model, mine = find(states, MODEL), find(states, STATE)
        if mine is None:
            problems.append('%s: no "%s" state' % (rel, STATE))
        elif model is None or shape(mine) != shape(model) or shape(mine) != (len(drawn), 1):
            problems.append('%s: "%s" does not have the directions and frames of "%s"' % (
                rel, STATE, MODEL))
        elif [t.tobytes() for t in tiles(sheet, mine)] != [t.tobytes() for t in drawn]:
            problems.append('%s: "%s" differs from the drawn sword' % (rel, STATE))
    return problems


# ------------------------------------------------------------------- preview

DIRS = ('south', 'north', 'east', 'west')
TEXT = (235, 235, 235, 255)
GROUND = (86, 122, 66, 255)
DARK = (34, 34, 40, 255)
PANEL = (58, 60, 68, 255)


def preview(drawn, out, scale=4):
    """Katana beside tachi for every sheet and direction, bare and on a body."""
    from create_belt_pouches import figure
    cell, label, gap = S * scale, 14, 8
    pair = 2 * cell + gap
    rows = [(ITEM, False, GROUND), (ITEM, False, DARK)]
    for rel in (LEFT, RIGHT, BELT, BACK):
        rows += [(rel, False, PANEL), (rel, True, PANEL)]
    img = Image.new('RGBA', (gap + 4 * (pair + gap), label + len(rows) * (cell + 2 * label + gap)), DARK)
    d = ImageDraw.Draw(img)
    d.text((gap, 1), 'katana (existing) beside tachi (new), %dx' % scale, fill=TEXT)
    y = label
    for rel, on_body, ground in rows:
        _, states, sheet = read_sheet(ROOT / rel)
        old = tiles(sheet, find(states, MODEL))
        kind = 'item on grass' if ground == GROUND else 'item' if rel == ITEM else (
            'on a body in a plain tunic' if on_body else 'overlay alone')
        d.text((gap, y + 1), '%s - %s' % (rel, kind), fill=TEXT)
        for i in range(len(old)):
            x = gap + i * (pair + gap)
            for n, (name, tile) in enumerate(((MODEL, old[i]), (STATE, drawn[rel][i]))):
                pic = Image.new('RGBA', (S, S), ground)
                if on_body:
                    pic.alpha_composite(figure(i, 'white_tunic'))
                pic.alpha_composite(tile)
                img.paste(pic.resize((cell, cell), Image.NEAREST), (x + n * (cell + gap // 2), y + 2 * label))
                d.text((x + n * (cell + gap // 2) + 2, y + label + 1),
                       name if rel == ITEM else '%s %s' % (name, DIRS[i]), fill=TEXT)
        y += cell + 2 * label + gap
    img.convert('RGB').save(out)


def option(name):
    args = sys.argv[1:]
    return args[args.index(name) + 1] if name in args[:-1] else None


def main():
    if '--check' in sys.argv:
        problems = check()
        for line in problems:
            print(line)
        print('tachi: %s' % ('FAILED' if problems else 'ok'))
        return 1 if problems else 0
    drawn = tachi()
    if '--no-write' not in sys.argv:
        for rel, frames in drawn.items():
            sheet, text = with_tachi(ROOT / rel, frames)
            write_sheet(ROOT / rel, sheet, text)
            print('wrote "%s" (%d direction%s) into %s' % (
                STATE, len(frames), '' if len(frames) == 1 else 's', rel))
    if option('--preview'):
        preview(drawn, option('--preview'))
    return 0


if __name__ == '__main__':
    sys.exit(main())
