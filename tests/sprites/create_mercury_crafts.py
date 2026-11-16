"""Hand-placed sprites for the mercury crafts.

icons/obj/mercury_crafts.dmi (items, one direction): the mercury thermometer
(a slim glass tube and bulb on a boxwood back-plate with tick marks, filled
and empty), the folded sheet of carroted beaver felt (warm grey-brown, its
edges tinged orange by the mercury nitrate that gives carroting its name), the
unsilvered wall mirror (the frame of the `mirror` state in
icons/obj/watercloset.dmi with bare glass in it, whole and cracked) and the
three beaver felt hats: tricorne, bicorne and top hat.

icons/mob/mercury_crafts.dmi (worn, four directions in BYOND order S, N, E,
W): the three felt hats on the head, pixel for pixel on the silhouettes of
`tricorne_black`, `tricorne_british_soldier` and `tophat` in
icons/mob/head.dmi so they sit on the head the same way.

Every pixel is placed by this script from a fixed palette (Pillow only); no
external or generated artwork. The boxwood is the timber of
create_clay_lime_fire.py and the quicksilver is that of create_mercury.py.

Run with Pillow to write both sheets. `--check` verifies the committed sheets,
that each worn hat and each hat item covers exactly the pixels of the hat it
is modelled on and that the unsilvered mirrors keep the frame of the silvered
ones, `--preview <png>` writes a labelled 4x review sheet on grass and on
dirt, with the felt hats worn beside the black ones and the unsilvered mirror
beside the silvered one.
Released under Civ13 AGPL-3.0.
"""
import re
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_clay_lime_fire import TIMBER, grain  # noqa: E402
from create_tatara import Sprite, GRASS, DIRT, ground  # noqa: E402
from create_mercury import QUICK  # noqa: E402
from create_diving_gear import base_body  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
ITEM_SHEET = ROOT / 'icons/obj/mercury_crafts.dmi'
WORN_SHEET = ROOT / 'icons/mob/mercury_crafts.dmi'
WATERCLOSET = ROOT / 'icons/obj/watercloset.dmi'
HATS = ROOT / 'icons/obj/clothing/hats.dmi'
HEAD = ROOT / 'icons/mob/head.dmi'

SIZE = 32

# beaver felt, a deep brown charcoal with a napped sheen:
# o edge, d deep, m mid, l lit, s sheen
FELT = {'o': (27, 22, 21), 'd': (45, 37, 34), 'm': (64, 53, 47),
        'l': (88, 74, 64), 's': (124, 107, 91)}
# t, T: the worn brim edge of the tricorne, where the nap catches the light
FELT_EDGE = {'t': (140, 122, 102), 'T': (182, 164, 136)}
# t: the cream wool tape that binds the bicorne
TAPE = {'t': (214, 202, 174), 'T': (236, 226, 202)}
# 0-3: the silk ribbon round the top hat, deep to lit
RIBBON = {'0': (58, 30, 26), '1': (94, 48, 36), '2': (136, 76, 50), '3': (178, 112, 72)}

TRICORNE = dict(FELT, **FELT_EDGE)
BICORNE = dict(FELT, **TAPE)
TOP_HAT = dict(FELT, **RIBBON)

# thermometer glass: glint, clear, shaded
GLASS = [(236, 246, 248), (188, 212, 218), (140, 170, 180)]
BORE = (214, 196, 160)             # the empty bore, the boxwood showing through
# the quicksilver in the tube and bulb, darker than the glass: glint, lit, mid, shade
COLUMN = [QUICK[0], QUICK[2], (104, 112, 130), (74, 80, 98)]
PLATE_EDGE = (44, 28, 18)
TICK = (62, 40, 24)

# carroted felt: lit, mid, shade, deep; then the orange tinge, bright and dull
CARROT = [(164, 140, 116), (140, 116, 96), (112, 90, 74), (82, 64, 54)]
TINGE = [(218, 160, 82), (190, 132, 72)]
CARROT_EDGE = (46, 34, 28)

# the wall mirror's frame, as watercloset.dmi draws it
FRAME = {'a': (102, 102, 102), 'b': (145, 145, 145)}
# bare glass with the wall showing through: 'c' the pane, 'd' its faint sheen
BARE = {'c': (120, 132, 136), 'd': (142, 156, 160)}
# a crack in bare glass: 'b' its bright lip, 'a' its dark root
CRACK = {'b': (196, 210, 214), 'a': (72, 80, 84)}
WALL = (104, 104, 106)             # the plain wall behind the mirrors in the review


def placed(rows, key):
    """A sprite from rows of (y, first column, one letter per pixel)."""
    f = Sprite()
    for y, x0, line in rows:
        for i, ch in enumerate(line):
            if ch != '.':
                f.put(x0 + i, y, key[ch])
    return f


def flipped(f):
    """Mirror left to right, as head.dmi mirrors its east hats for west."""
    g = Sprite()
    g.px = {(SIZE - 1 - x, y): c for (x, y), c in f.px.items()}
    return g


# ---------------------------------------------------------- thermometer --

def thermometer(filled=True):
    """A boxwood back-plate six wide with a hanging hole, the tube up its
    middle (a lit glass wall and the bore beside it), ticks down the right
    and longer marks on the left, and the bulb at the foot."""
    f = Sprite()
    for y in range(5, 26):
        for x in range(13, 19):
            rim = x in (13, 18) or y in (5, 25)
            if rim and x in (13, 18) and y in (5, 25):
                continue                              # rounded corners
            if rim:
                f.put(x, y, PLATE_EDGE)
            else:
                f.put(x, y, TIMBER[0] if x < 16 else TIMBER[1])
    f.hline(14, 17, 24, TIMBER[2])                    # the shaded foot of the plate
    f.pts(PLATE_EDGE, (15, 7), (16, 7))               # the hole it hangs by
    for y in range(10, 21, 2):                        # degree ticks
        f.put(17, y, TICK)
    for y in (10, 14, 18):                            # the long marks
        f.put(14, y, TICK)
    f.pts(GLASS[1], (15, 9), (16, 9))                 # the sealed top of the tube
    level = 14                                        # the column stands this high
    for y in range(10, 21):
        f.put(15, y, GLASS[0])
        if filled and y >= level:
            f.put(16, y, COLUMN[2] if y > level else COLUMN[1])
        else:
            f.put(16, y, BORE)
    body = COLUMN if filled else GLASS + [GLASS[2]]
    f.pts(body[1], (15, 21), (14, 22), (16, 22), (14, 23), (15, 23))
    f.pts(body[2], (16, 21), (15, 24), (16, 23))
    f.pts(body[0], (15, 22))                          # the glint on the bulb
    f.pts(body[3], (17, 22), (17, 23), (16, 24))
    return f


# -------------------------------------------------------- carroted felt --

FELT_TOP = range(13, 20)           # rows of the top face of the folded sheet
FELT_FRONT = range(20, 25)         # rows of its folded front edge


def felt_left(y):
    """First column of the top face on row y: it leans back to the right."""
    return 7 + (19 - y) // 2


def carroted_felt():
    f = Sprite()
    for y in FELT_TOP:                                # the napped top face
        x0 = felt_left(y)
        for x in range(x0, x0 + 16):
            g = grain(x, y, 211)
            c = CARROT[0] if g < 4 else (CARROT[1] if g < 9 else CARROT[2])
            rim = y in (FELT_TOP[0], FELT_TOP[-1]) or x in (x0, x0 + 15)
            if rim:                                   # the carroted fur tips
                c = TINGE[0] if grain(x, y, 213) < 7 else TINGE[1]
            elif (y == FELT_TOP[0] + 1 or x == x0 + 1) and g < 3:
                c = TINGE[1]                          # the tinge creeping inward
            f.put(x, y, c)
    for n, y in enumerate(FELT_FRONT):                # three folds, edge on
        for x in range(7, 23):
            if n in (0, 2):
                c = TINGE[1] if grain(x, y, 215) < 4 else CARROT[1]
            elif n == 4:
                c = CARROT[3]
            else:
                c = CARROT[2] if grain(x, y, 217) < 8 else CARROT[3]
            f.put(x, y, c)
    for x in range(23, 26):                           # the folded end, in shade
        top = FELT_TOP[-1] - 2 * (x - 22) + 1
        for n in range(5):
            f.put(x, top + n, CARROT[2] if n in (0, 2) else CARROT[3])
    f.outline(CARROT_EDGE)
    return f


# --------------------------------------------------------------- mirror --

# the `mirror` state: frame letters a, b; glass c with the sheen d across it
MIRROR = (
    (4, 13, 'abbbba'),
    (5, 12, 'bbccccbb'),
    (6, 11, 'bccccccddb'),
    (7, 10, 'abcccccdddba'),
    (8, 10, 'bcccccdddccb'),
    (9, 9, 'abccccdddccdba'),
    (10, 9, 'bccccdddccdddb'),
    (11, 9, 'bcccdddccdddcb'),
    (12, 9, 'bccdddccdddccb'),
    (13, 9, 'bcdddccdddcccb'),
    (14, 9, 'bdddccdddccccb'),
    (15, 9, 'bddccdddcccccb'),
    (16, 9, 'bdccdddccccccb'),
    (17, 9, 'abcdddccccccba'),
    (18, 10, 'bdddcccccccb'),
    (19, 10, 'abdcccccccba'),
    (20, 11, 'bccccccccb'),
    (21, 12, 'bbccccbb'),
    (22, 13, 'abbbba'),
)
# the `mirror_broke` state: inside the frame a and b are the cracks
MIRROR_BROKE = (
    (4, 13, 'abbbba'),
    (5, 12, 'bbccddbb'),
    (6, 11, 'bcdbdddccb'),
    (7, 10, 'abddbddccbba'),
    (8, 10, 'bcbcabbbbccb'),
    (9, 9, 'abccbcdcbcbcba'),
    (10, 9, 'bccbadbbddbcdb'),
    (11, 9, 'bdbcdbcdbcbddb'),
    (12, 9, 'bdbdbcbcabcbdb'),
    (13, 9, 'bdbcbdcbdbdbcb'),
    (14, 9, 'bdcbcbadabcbcb'),
    (15, 9, 'bdccbdbbbdbccb'),
    (16, 9, 'bdbbcbdccbcbcb'),
    (17, 9, 'abccccbabcddba'),
    (18, 10, 'bdddccbcddcb'),
    (19, 10, 'abddddcbdcba'),
    (20, 11, 'bccddddbcb'),
    (21, 12, 'bbccddbb'),
    (22, 13, 'abbbba'),
)


def frame_cells():
    """The pixels of the mirror's frame: every a or b that is not glass in
    the whole mirror."""
    return set((x0 + i, y) for y, x0, line in MIRROR for i, ch in enumerate(line) if ch in 'ab')


def mirror_unsilvered(rows=MIRROR):
    rim = frame_cells()
    f = Sprite()
    for y, x0, line in rows:
        for i, ch in enumerate(line):
            x = x0 + i
            if (x, y) in rim:
                f.put(x, y, FRAME[ch])
            elif ch in 'ab':
                f.put(x, y, CRACK[ch])
            else:
                f.put(x, y, BARE[ch])
    return f


# ----------------------------------------------------------- hat items --

def felt_tricorne():
    return placed((
        (12, 11, 'odmmmmmdo'),
        (13, 10, 'omTdmmmddTo'),
        (14, 9, 'omlmTdmmdTmdo'),
        (15, 9, 'omlmmTTmTmmdo'),
        (16, 9, 'ooommlmmmdooo'),
        (17, 11, 'doooooood'),
    ), TRICORNE)


def felt_bicorne():
    return placed((
        (13, 13, 'odtttdo'),
        (14, 12, 'ottmlmtto'),
        (15, 11, 'otmlslmmdto'),
        (16, 10, 'otmlsllmmmdto'),
        (17, 10, 'tdmllmmmmddot'),
        (18, 10, 'oooddddddd' + 'ooo'),
    ), BICORNE)


def felt_top_hat():
    return placed((
        (11, 11, 'odmllllmdo'),
        (12, 11, 'odmlsslmdo'),
        (13, 11, 'odmlsslmdo'),
        (14, 11, 'odmlslmmdo'),
        (15, 11, 'odmlsslmdo'),
        (16, 11, 'odmllsmmdo'),
        (17, 11, 'odmlsslmdo'),
        (18, 11, 'odmmllmmdo'),
        (19, 11, '0012332100'),
        (20, 9, 'oddmmllllmmddo'),
    ), TOP_HAT)


# ------------------------------------------------------------ worn hats --

def worn_tricorne():
    south = placed((
        (0, 12, 'odmmmdo'),
        (1, 11, 'omTdmmdTo'),
        (2, 10, 'omlmTddTmdo'),
        (3, 10, 'omlmmTTmmdo'),
        (4, 10, 'ooomlmmdooo'),
        (5, 12, 'dooooo' + 'd'),
    ), TRICORNE)
    north = placed((
        (0, 11, 'omllsllmo'),
        (1, 11, 'odmlllmdo'),
        (2, 10, 'oddmllmmddo'),
        (3, 10, 'odmmmlmmmdo'),
        (4, 10, 'ooddmmmddoo'),
        (5, 12, 'dooooo' + 'd'),
    ), TRICORNE)
    east = placed((
        (0, 13, 'odmlmdo'),
        (1, 12, 'odmlslmdo'),
        (2, 11, 'odmlmtTtTtt'),
        (3, 11, 'ttTtTmlmmdo'),
        (4, 11, 'odmlmmooood'),
        (5, 12, 'dmoooo'),
        (6, 13, 'oo'),
    ), TRICORNE)
    return [south, north, east, flipped(east)]


def worn_bicorne():
    foot = (5, 9, 'ood.......doo')
    south = placed((
        (0, 12, 'odtttdo'),
        (1, 11, 'ottmlmtto'),
        (2, 10, 'otmlslmmdto'),
        (3, 9, 'otmlsllmmmdto'),
        (4, 9, 'tdmllmmmmddot'),
        foot,
    ), BICORNE)
    north = placed((
        (0, 12, 'odtttdo'),
        (1, 11, 'ottmmmtto'),
        (2, 10, 'otmmlmmmdto'),
        (3, 9, 'otmmllmmmmdto'),
        (4, 9, 'tdmmmmmmmddot'),
        foot,
    ), BICORNE)
    east = placed((
        (0, 12, 'otmlmdto'),
        (1, 11, 'otmlsmtddo'),
        (2, 11, 'otmlsmtmddo'),
        (3, 10, 'otmllmtmmddo'),
        (4, 10, 'ottttttdddoo'),
    ), BICORNE)
    return [south, north, east, flipped(east)]


def worn_top_hat():
    front = (
        (0, 12, 'dmlslmd'),
        (1, 12, 'dmlslmd'),
        (2, 12, 'dmlllmd'),
        (3, 12, 'dmlslmd'),
        (4, 12, '0123210'),
        (5, 10, 'oddmllmmddo'),
    )
    south = placed(front, TOP_HAT)
    north = placed(front[:4] + ((4, 12, '0112110'), (5, 10, 'oddmmmmmddo')), TOP_HAT)
    east = placed((
        (0, 13, 'odmlls'),
        (1, 13, 'odmlls'),
        (2, 13, 'odmmls'),
        (3, 13, 'odmlls'),
        (4, 13, '001233'),
        (5, 11, 'oddmmllmdo'),
    ), TOP_HAT)
    return [south, north, east, flipped(east)]


def item_states():
    """[(state, sprite)] in sheet order."""
    return [
        ('thermometer', thermometer(True)),
        ('thermometer_empty', thermometer(False)),
        ('carroted_felt', carroted_felt()),
        ('mirror_unsilvered', mirror_unsilvered(MIRROR)),
        ('mirror_unsilvered_broke', mirror_unsilvered(MIRROR_BROKE)),
        ('felt_tricorne', felt_tricorne()),
        ('felt_bicorne', felt_bicorne()),
        ('felt_top_hat', felt_top_hat()),
    ]


def worn_states():
    """[(state, [S, N, E, W])] in sheet order."""
    return [
        ('felt_tricorne', worn_tricorne()),
        ('felt_bicorne', worn_bicorne()),
        ('felt_top_hat', worn_top_hat()),
    ]


# the existing hat each felt hat is modelled on: (hats.dmi, head.dmi)
MODELS = {
    'felt_tricorne': 'tricorne_black',
    'felt_bicorne': 'tricorne_british_soldier',
    'felt_top_hat': 'tophat',
}


# --------------------------------------------------------- sheet in/out --

def build(states, dirs):
    """(image, Description) for [(state, sprite or [sprites])]."""
    frames, text = [], '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, art in states:
        text += 'state = "%s"\n\tdirs = %d\n\tframes = 1\n' % (name, dirs)
        frames += [fr.image() for fr in (art if dirs > 1 else [art])]
    text += '# END DMI\n'
    cols = 4 if dirs > 1 else int(len(frames) ** 0.5 + 0.999)
    rows = (len(frames) + cols - 1) // cols
    im = Image.new('RGBA', (cols * SIZE, rows * SIZE))
    for i, fr in enumerate(frames):
        im.paste(fr, ((i % cols) * SIZE, (i // cols) * SIZE))
    return im, text


def sheets():
    return ((ITEM_SHEET, build(item_states(), 1)), (WORN_SHEET, build(worn_states(), 4)))


def write_dmi():
    for path, (im, text) in sheets():
        meta = PngImagePlugin.PngInfo()
        meta.add_text('Description', text, zip=True)
        im.save(path, 'PNG', pnginfo=meta, optimize=True)


def cells(path, state):
    """Every 32x32 cell of `state` in another sheet, in sheet order."""
    sheet = Image.open(path)
    text = sheet.info.get('Description', '')
    index = 0
    for name, dirs, frames in re.findall(r'state = "(.*?)"\n\tdirs = (\d+)\n\tframes = (\d+)', text):
        count = int(dirs) * int(frames)
        if name == state:
            cols = sheet.size[0] // SIZE
            im = sheet.convert('RGBA')
            return [im.crop(((i % cols) * SIZE, (i // cols) * SIZE,
                             (i % cols) * SIZE + SIZE, (i // cols) * SIZE + SIZE))
                    for i in range(index, index + count)]
        index += count
    return []


def mask(im):
    return set((x, y) for y in range(SIZE) for x in range(SIZE) if im.getpixel((x, y))[3])


def check():
    """A list of what is wrong; empty when everything matches."""
    wrong = []
    for path, (im, text) in sheets():
        if not path.exists():
            wrong.append('missing sheet: %s' % path)
            continue
        old = Image.open(path)
        if old.info.get('Description') != text or old.convert('RGBA').tobytes() != im.tobytes():
            wrong.append('stale sheet: %s' % path)
    items = dict(item_states())
    for state, model in MODELS.items():               # the hats keep their silhouettes
        ref = cells(HATS, model)
        if not ref or mask(ref[0]) != set(items[state].px):
            wrong.append('%s item leaves the silhouette of %s' % (state, model))
    for state, frs in worn_states():
        ref = cells(HEAD, MODELS[state])
        if len(ref) != 4 or any(mask(r) != set(fr.px) for r, fr in zip(ref, frs)):
            wrong.append('worn %s leaves the silhouette of %s' % (state, MODELS[state]))
    rim = frame_cells()
    for state, model in (('mirror_unsilvered', 'mirror'), ('mirror_unsilvered_broke', 'mirror_broke')):
        ref = cells(WATERCLOSET, model)
        mine = items[state].image()
        if not ref or mask(ref[0]) != mask(mine) or any(
                ref[0].getpixel(p) != mine.getpixel(p) for p in rim):
            wrong.append('%s leaves the frame of %s' % (state, model))
    return wrong


# -------------------------------------------------------------- review --

def flat(colour, scale):
    return Image.new('RGBA', (SIZE * scale, SIZE * scale), colour + (255,))


def preview(path, scale=4):
    """Every state, labelled, on grass (upper block) and dirt (lower): the
    items, the hat items beside the hats they are modelled on, each felt hat
    worn in four directions beside the black one, and the mirrors on a plain
    wall."""
    items = dict((name, fr.image()) for name, fr in item_states())

    def other(sheet, state):
        found = cells(sheet, state)
        return found[0] if found else Image.new('RGBA', (SIZE, SIZE))

    first = [(name, items[name], None) for name in ('thermometer', 'thermometer_empty', 'carroted_felt')]
    hats = []
    for state, model in MODELS.items():
        hats.append((state, items[state], None))
        hats.append(('was ' + model[:19], other(HATS, model), None))
    lines = [first + [('mirror (silvered)', other(WATERCLOSET, 'mirror'), None),
                      ('mirror_unsilvered', items['mirror_unsilvered'], None),
                      ('mirror_broke (silv.)', other(WATERCLOSET, 'mirror_broke'), None),
                      ('mirror_unsilv._broke', items['mirror_unsilvered_broke'], None)],
             hats]
    for state, frs in worn_states():                  # worn: felt S N E W, then black S N E W
        line = []
        ref = cells(HEAD, MODELS[state])
        for d, way in enumerate('SNEW'):
            figure = base_body(d)
            figure.alpha_composite(frs[d].image())
            line.append(('%s %s' % (state, way), figure, None))
        for d, way in enumerate('SNEW'):
            figure = base_body(d)
            if len(ref) == 4:
                figure.alpha_composite(ref[d])
            line.append(('was %s %s' % (MODELS[state][:13], way), figure, None))
        lines.append(line)
    lines.append([(label, im, WALL) for label, im, _ in lines[0][3:]])   # the mirrors on a wall
    cols = max(len(line) for line in lines)
    pad, label = 8, 14
    cw = SIZE * scale + pad + 24                      # room for the long names
    high = SIZE * scale + label + pad
    block = high * len(lines)
    out = Image.new('RGBA', (pad + cols * cw, pad + 2 * block), (24, 24, 24, 255))
    pen = ImageDraw.Draw(out)
    for j, tones in enumerate((GRASS, DIRT)):
        y = pad + j * block
        for line in lines:
            for i, (name, im, back) in enumerate(line):
                x = pad + i * cw
                tile = flat(back, scale) if back else ground(tones, scale)
                tile.alpha_composite(im.resize((SIZE * scale, SIZE * scale), Image.NEAREST))
                out.paste(tile, (x, y))
                pen.text((x + 1, y + SIZE * scale + 1), name, fill=(230, 230, 230, 255))
            y += high
    out.save(path)


if __name__ == '__main__':
    if '--check' in sys.argv:
        problems = check()
        if problems:
            sys.exit('\n'.join(problems))
        print('mercury crafts states match')
    else:
        write_dmi()
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
