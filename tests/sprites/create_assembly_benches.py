"""Hand-placed sprites for the assembly benches in icons/obj/assembly_benches.dmi.
The tool, armor and weapon assembly workbenches, the fletcher's bench and the
toolsmith's bench all borrowed the plain `workbench` of icons/obj/structures.dmi
(three of them only tinted); here each gets a side-on bench that shows its trade:

  tool_bench        a leg vise, a hatchet being hafted and a mallet
  armor_bench       a leather cuirass on a stand, a bolt of cloth and shears
  weapon_bench      a rack of spears and a grindstone
  fletcher_bench    a pot of fletched arrows, an arrow in the jig and goose feathers
  toolsmith_bench   an iron-topped bench with ingots, a hammer and a pickaxe

Every pixel is placed by this script from a fixed palette (Pillow only); no
external or generated artwork. The timber, leather, iron and steel colours are
those of icons/obj/workshop_machines.dmi and icons/obj/wire_bench.dmi.

Run with Pillow to reproduce the sheet. `--check` verifies the committed sheet
matches and `--preview <png>` writes a before and after review sheet.
Released under Civ13 AGPL-3.0.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from create_clay_lime_fire import Frame, TIMBER, IRON, HIDE, STONE, CLAY, plank  # noqa: E402
from create_machine_shop import STEEL  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/assembly_benches.dmi'
OLD_SHEET = ROOT / 'icons/obj/structures.dmi'

# pale ash for handles and shafts: light, mid, shade
ASH = [(232, 204, 152), (204, 170, 116), (160, 126, 80)]
# undyed cloth: light, mid, shade
CLOTH = [(232, 222, 196), (202, 188, 158), (160, 146, 118)]
# goose feathers: light, mid, shade
FEATHER = [(246, 244, 236), (210, 210, 204), (160, 162, 164)]
# dyed cock feathers on a finished arrow
DYE = [(206, 64, 52), (146, 38, 34)]
# copper ingots: light, mid, shade
COPPER = [(240, 160, 104), (204, 116, 66), (150, 78, 42)]


def bench(f, top=None, shelf=False, drawer=False):
    """The shared carcass: a thick plank top on two legs, 1px clear at the
    left, right and bottom. `top` swaps the lit surface for another ramp."""
    plank(f, 2, 19, 29, 21, seed=3)
    if top:
        f.hline(2, 29, 19, top[0])
        f.hline(2, 29, 20, top[1])
    f.rect(3, 22, 28, 23, TIMBER[3])                      # apron
    f.hline(3, 28, 22, TIMBER[2])
    for x in (4, 25):
        f.rect(x, 22, x + 2, 29, TIMBER[3])
        f.vline(x, 22, 29, TIMBER[2])
        f.put(x + 2, 29, TIMBER[4])
    if shelf:
        f.hline(7, 24, 27, TIMBER[2])
        f.hline(7, 24, 28, TIMBER[4])
    else:
        f.hline(7, 24, 26, TIMBER[3])                     # stretcher
    if drawer:
        f.rect(11, 22, 20, 24, TIMBER[2])
        f.hline(11, 20, 24, TIMBER[4])
        f.hline(15, 16, 23, IRON[0])


def tool_bench():
    f = Frame()
    bench(f, shelf=True)
    # leg vise at the left end: a tall wooden jaw with an iron screw and bar
    f.rect(2, 12, 4, 18, TIMBER[2])
    f.vline(2, 12, 18, TIMBER[1])
    f.hline(2, 4, 12, TIMBER[0])
    f.rect(6, 13, 7, 18, TIMBER[3])
    f.put(5, 15, IRON[1])
    f.hline(1, 1, 15, IRON[0])
    f.vline(1, 13, 17, IRON[1])
    # a hatchet being hafted: the ash handle lies along the bench, head at the right
    f.hline(9, 19, 17, ASH[0])
    f.hline(9, 19, 18, ASH[2])
    f.rect(18, 15, 20, 18, STEEL[1])
    f.pts(STEEL[1], (17, 13), (18, 13), (17, 14), (18, 14), (19, 14))
    f.vline(17, 13, 16, STEEL[0])
    f.pts(STEEL[2], (20, 16), (20, 17), (20, 18), (19, 18))
    # mallet standing on its head at the right
    f.rect(23, 15, 28, 18, TIMBER[1])
    f.hline(23, 28, 15, TIMBER[0])
    f.hline(23, 28, 18, TIMBER[3])
    f.vline(28, 15, 18, TIMBER[3])
    f.vline(25, 8, 14, ASH[1])
    f.vline(26, 8, 14, ASH[2])
    f.put(25, 8, ASH[0])
    # a spare shovel blade and handle blanks on the shelf
    f.rect(9, 25, 12, 26, STEEL[2])
    f.hline(9, 12, 25, STEEL[1])
    f.hline(15, 22, 26, ASH[1])
    f.hline(16, 22, 25, ASH[2])
    f.outline()
    return f


def armor_bench():
    f = Frame()
    bench(f, drawer=True)
    # stand: a foot block and a post
    f.rect(13, 17, 18, 18, TIMBER[3])
    f.hline(13, 18, 17, TIMBER[2])
    f.rect(15, 2, 16, 16, TIMBER[2])
    f.hline(14, 17, 2, TIMBER[1])
    # leather cuirass hung on it: shoulders, arm holes, flared skirt
    for y in range(4, 16):
        half = 5 if y in (4, 5) else 3 if y in (6, 7) else 4 if y < 13 else 5
        for x in range(16 - half, 16 + half):
            c = HIDE[1]
            if x == 16 - half:
                c = HIDE[0]
            elif x >= 16 + half - 2:
                c = HIDE[2]
            if y == 15:
                c = HIDE[3]
            f.put(x, y, c)
    f.pts(TIMBER[2], (15, 4), (16, 4))                       # neck
    f.pts(HIDE[3], (15, 5), (16, 5))
    f.hline(12, 19, 12, HIDE[3])                            # belt
    f.pts(STEEL[0], (15, 12), (16, 12))                     # buckle
    for y in (7, 9):                                        # rivet rows
        f.pts(STEEL[0], (13, y), (15, y), (17, y))
    f.pts(STEEL[1], (12, 14), (14, 14), (16, 14), (18, 14))
    # bolt of cloth at the left
    f.rect(3, 15, 9, 18, CLOTH[1])
    f.hline(3, 9, 15, CLOTH[0])
    f.hline(3, 9, 18, CLOTH[2])
    f.pts(CLOTH[2], (3, 16), (3, 17), (4, 17))
    f.put(4, 16, CLOTH[0])
    f.hline(9, 11, 18, CLOTH[0])                            # loose end
    # shears and a tin of rivets at the right
    f.pts(STEEL[1], (22, 18), (23, 17), (24, 16), (23, 18), (24, 17), (25, 16))
    f.pts(IRON[1], (25, 18), (26, 17), (26, 18), (27, 18))
    f.rect(27, 15, 28, 16, IRON[1])
    f.hline(27, 28, 15, STEEL[0])
    f.outline()
    return f


def weapon_bench():
    f = Frame()
    bench(f)
    # rack at the back left: two uprights and a rail holding three spears
    for x in (3, 15):
        f.vline(x, 10, 18, TIMBER[3])
    f.hline(3, 15, 11, TIMBER[2])
    f.hline(3, 15, 12, TIMBER[4])
    for x, tip in ((6, 1), (9, 3), (12, 2)):
        f.vline(x, tip + 4, 18, ASH[1])
        f.pts(STEEL[0], (x, tip), (x, tip + 1), (x, tip + 2), (x, tip + 3))
        f.pts(STEEL[2], (x + 1, tip + 2), (x + 1, tip + 3))
        f.pts(STEEL[1], (x - 1, tip + 2), (x - 1, tip + 3))
        f.put(x, tip + 4, HIDE[2])                           # binding
        f.put(x, 11, ASH[0])
    # grindstone at the right: a stone wheel in a trestle with a crank
    f.vline(20, 13, 18, TIMBER[3])
    f.vline(28, 13, 18, TIMBER[3])

    def wheel(x, y, nx, ny):
        d = nx * nx + ny * ny
        if d < 0.07:
            return IRON[2]
        if nx + ny > 0.75:
            return STONE[3]
        if nx + ny < -0.75:
            return STONE[0]
        return STONE[2] if (x + y) % 5 == 0 else STONE[1]
    f.ellipse(24, 12, 4.4, 4.4, wheel)
    f.pts(IRON[0], (25, 12), (26, 13), (27, 14))            # crank
    f.put(28, 15, TIMBER[0])
    f.outline()
    return f


def fletcher_bench():
    f = Frame()
    bench(f, drawer=True)
    # a clay pot of finished arrows, fletched ends up
    f.rect(3, 13, 8, 18, CLAY[1])
    f.vline(3, 13, 18, CLAY[0])
    f.vline(8, 13, 18, CLAY[3])
    f.hline(3, 8, 18, CLAY[2])
    f.hline(2, 9, 12, CLAY[0])
    for x, top, dye in ((3, 3, 0), (5, 1, 1), (7, 2, 0), (9, 4, 1)):
        f.vline(x, top, 11, ASH[1])
        feather = DYE if dye else FEATHER
        for y in range(top, top + 4):
            f.put(x - 1, y + (1 if y == top else 0), feather[0])
            f.put(x + 1, y + (1 if y == top else 0), feather[1])
        f.put(x, top, ASH[2])                                # nock
    # an arrow in the fletching jig: shaft along the bench, steel head at the right
    f.rect(12, 17, 13, 18, TIMBER[3])                       # jig blocks
    f.rect(22, 17, 23, 18, TIMBER[3])
    f.hline(11, 27, 16, ASH[0])
    f.pts(STEEL[0], (28, 16), (29, 16), (27, 15), (28, 15))
    f.pts(STEEL[2], (27, 17), (28, 17))
    f.pts(DYE[0], (11, 15), (12, 15), (13, 15), (12, 14), (13, 14), (14, 15))
    f.pts(DYE[1], (11, 17), (12, 17))
    # loose goose feathers fanned behind it
    for i, (x, y) in enumerate(((15, 9), (19, 8), (23, 9))):
        for j in range(5):
            f.put(x + j // 2, y + j, FEATHER[0])
            f.put(x + j // 2 + 1, y + j, FEATHER[1 + (i + j) % 2])
        f.put(x + 3, y + 5, ASH[2])                          # quill
    f.outline()
    return f


def toolsmith_bench():
    f = Frame()
    bench(f, top=IRON, shelf=True)
    # ingots stacked three, two, one at the left
    for row, (x0, n) in enumerate(((2, 3), (4, 2), (6, 1))):
        y = 17 - row * 3
        for i in range(n):
            x = x0 + i * 4
            ramp = COPPER if (row + i) % 2 else STEEL
            f.rect(x, y, x + 2, y + 1, ramp[1])
            f.hline(x, x + 2, y, ramp[0])
            f.put(x + 2, y + 1, ramp[2])
    # smith's hammer lying across the middle, head up
    f.hline(14, 21, 18, ASH[1])
    f.rect(19, 15, 21, 18, IRON[1])
    f.vline(19, 15, 18, IRON[0])
    f.hline(19, 21, 14, IRON[0])
    f.put(21, 18, IRON[2])
    # a finished pickaxe leaning at the right
    f.vline(26, 5, 18, ASH[1])
    f.vline(27, 6, 18, ASH[2])
    f.hline(23, 29, 4, STEEL[0])
    f.hline(24, 28, 5, STEEL[1])
    f.pts(STEEL[1], (22, 5), (21, 6), (30, 5))
    f.pts(STEEL[2], (22, 6), (30, 6))
    # tongs hung from the apron, a bucket of handle blanks on the shelf
    f.pts(IRON[0], (12, 23), (12, 24), (13, 25), (14, 23), (14, 24), (13, 26))
    f.rect(17, 24, 21, 26, TIMBER[1])
    f.hline(17, 21, 25, IRON[1])
    f.pts(ASH[0], (18, 23), (20, 23))
    f.outline()
    return f


def states():
    """[(state, frame)] in sheet order."""
    return [
        ('tool_bench', tool_bench()),
        ('armor_bench', armor_bench()),
        ('weapon_bench', weapon_bench()),
        ('fletcher_bench', fletcher_bench()),
        ('toolsmith_bench', toolsmith_bench()),
    ]


def build():
    frames = [fr for _, fr in states()]
    cols = int(len(frames) ** 0.5 + 0.999)
    rows = (len(frames) + cols - 1) // cols
    im = Image.new('RGBA', (cols * 32, rows * 32))
    for i, fr in enumerate(frames):
        im.paste(fr.image(), ((i % cols) * 32, (i // cols) * 32))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name, _ in states():
        text += 'state = "%s"\n\tdirs = 1\n\tframes = 1\n' % name
    text += '# END DMI\n'
    return im, text


def write_dmi():
    im, text = build()
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    im.save(SHEET, 'PNG', pnginfo=meta, optimize=True)


def check():
    im, text = build()
    old = Image.open(SHEET)
    return old.info.get('Description') == text and old.convert('RGBA').tobytes() == im.tobytes()


def old_workbench(tint=None):
    """The shared `workbench` state the benches used, with a bench's old tint."""
    sheet = Image.open(OLD_SHEET)
    index = 0
    for line in sheet.info['Description'].split('\n'):
        if line.startswith('state = '):
            if line == 'state = "workbench"':
                break
            dirs = frames = 1
        elif line.startswith('\tdirs'):
            dirs = int(line.split('=')[1])
        elif line.startswith('\tframes'):
            frames = int(line.split('=')[1])
            index += dirs * frames
    cols = sheet.size[0] // 32
    x, y = (index % cols) * 32, (index // cols) * 32
    tile = sheet.convert('RGBA').crop((x, y, x + 32, y + 32))
    if tint:
        px = tile.load()
        for j in range(32):
            for i in range(32):
                r, g, b, a = px[i, j]
                px[i, j] = (r * tint[0] // 255, g * tint[1] // 255, b * tint[2] // 255, a)
    return tile


def preview(path, scale=6):
    """Each bench before and after on grass, a wooden floor and stone, then at
    the 1x and 2x sizes the Crafting window and the world show them."""
    names = ['tool assembly workbench', 'armor assembly workbench', 'weapon assembly workbench',
             "fletcher's bench", "toolsmith's bench"]
    tints = [None, None, (200, 162, 122), (167, 184, 138), (154, 163, 173)]
    grounds = ((98, 122, 78, 255), (132, 100, 66, 255), (120, 118, 112, 255))
    pad, label = 8, 16
    big = 32 * scale
    cell = big + pad
    width = pad + 150 + 2 * (len(grounds) * cell + 76) + pad
    out = Image.new('RGBA', (width, pad + label + len(names) * cell + pad), (24, 24, 24, 255))
    draw = ImageDraw.Draw(out)
    left = pad + 150
    span = len(grounds) * cell + 76
    draw.text((left, pad), 'BEFORE', fill=(230, 230, 230, 255))
    draw.text((left + span, pad), 'AFTER', fill=(230, 230, 230, 255))
    new = [fr.image() for _, fr in states()]
    for j, name in enumerate(names):
        y = pad + label + j * cell
        draw.text((pad, y + big // 2 - 4), name, fill=(230, 230, 230, 255))
        for side, art in enumerate((old_workbench(tints[j]), new[j])):
            x0 = left + side * span
            for g, bg in enumerate(grounds):
                tile = Image.new('RGBA', (big, big), bg)
                tile.alpha_composite(art.resize((big, big), Image.NEAREST))
                out.paste(tile, (x0 + g * cell, y))
            xs = x0 + len(grounds) * cell
            small = Image.new('RGBA', (32, 32), (50, 44, 38, 255))
            small.alpha_composite(art)
            out.paste(small, (xs, y))
            mid = Image.new('RGBA', (64, 64), grounds[0])
            mid.alpha_composite(art.resize((64, 64), Image.NEAREST))
            out.paste(mid, (xs, y + 40))
    out.save(path)


if __name__ == '__main__':
    if '--check' in sys.argv:
        if not check():
            sys.exit('stale sheet: ' + str(SHEET))
        print('assembly bench sheet matches')
    else:
        write_dmi()
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
