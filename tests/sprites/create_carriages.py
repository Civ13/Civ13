"""Hand-placed art for horse-drawn carriages: the plank wagon and the coach
in icons/obj/vehicles/vehicles96x96.dmi (states "simple_carriage" and
"simple_carriage2", every other state in that sheet is left untouched), and
icons/obj/vehicles/carriage_fittings.dmi with the harness drawn ahead of the
carriage for each rank of the team (pole, swingletree, traces, yoke) and the
lap rug or seat back that makes a rider read as seated. Every pixel is
placed by this script from a fixed palette (Pillow only); no external or
generated artwork.

Both carriages share one chassis and one palette, are seen from straight
above in all four directions and are lit from the upper left (trainkit.py).
The body fills the 64 x 96 footprint centred in the 96 x 96 icon, so the
seat points of carriage.dm land on the benches.

    python3 tests/sprites/create_carriages.py [--check] [--preview PNG]

`--check` writes nothing and fails when a committed sheet differs from what
this script draws. `--preview <png>` writes a review sheet with riders'
places and a team in harness.
Released under Civ13 AGPL-3.0.
"""
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from trainkit import Canvas, HEADING, directions, mix, noise, read_dmi, sheet_image, write_dmi  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / 'icons/obj/vehicles/vehicles96x96.dmi'
FITTINGS = ROOT / 'icons/obj/vehicles/carriage_fittings.dmi'
ANIMALS = ROOT / 'icons/mob/animal_64.dmi'

# lit, face, shade, outline
OAK = ((206, 158, 96), (172, 124, 68), (134, 92, 48), (70, 44, 22))
OAK_TONES = ((196, 148, 88), (172, 124, 68), (160, 114, 62), (182, 134, 76), (150, 106, 56))
OAK_SEAM = (92, 60, 30)
LACQUER = ((92, 118, 96), (48, 78, 58), (30, 54, 40), (14, 26, 20))
LEATHER = ((204, 84, 66), (158, 46, 42), (112, 28, 30), (56, 12, 14))
HIDE = ((176, 132, 88), (134, 94, 58), (98, 66, 40), (52, 34, 20))
IRON = ((170, 176, 186), (112, 118, 128), (72, 76, 86), (28, 30, 36))
BRASS = ((252, 230, 146), (218, 180, 90), (160, 120, 50), (86, 60, 22))
RUG = ((86, 132, 96), (48, 92, 66), (30, 64, 46), (14, 34, 24))
WHITE = (255, 255, 255)
DARK = (16, 14, 14)


def boards(c, x0, y0, x1, y1, seed=0, width=5):
    """Bed planks running the length of the carriage."""
    k, x = 0, x0
    while x <= x1:
        right = min(x + width - 1, x1)
        base = OAK_TONES[1 + int(noise(k, seed, 7) * 4) % 4]
        cols = [mix(base, OAK_TONES[0], 0.6)] + [base] * (right - x - 1) + [OAK_SEAM]
        c.bands(x, y0, right, y1, cols[:right - x + 1], along=True)
        for y in range(y0, y1 + 1):
            for xx in range(x + 1, right):
                n = noise(xx + k * 5, y // 3, seed + 3)
                if n < 0.12:
                    c.put(xx, y, mix(base, OAK_SEAM, 0.35))
                elif n > 0.94:
                    c.put(xx, y, mix(base, OAK_TONES[0], 0.45))
        if noise(k, seed, 12) < 0.5:
            jy = y0 + 6 + int(noise(k, seed, 11) * max(1, y1 - y0 - 12))
            for xx in range(x, right):
                c.put(xx, jy, OAK_SEAM)
        k += 1
        x += width


def wheel(c, x0, y0, left):
    """A spoked wheel seen from above: iron tyre, felloe and the hub cap."""
    c.shade(x0 + 1, y0 + 2, x0 + 6, y0 + 19, 60)
    c.rect(x0, y0, x0 + 4, y0 + 17, IRON[3])
    c.bands(x0 + 1, y0 + 1, x0 + 3, y0 + 16, [IRON[1], OAK[1], IRON[2]], along=True)
    c.rect(x0 + 1, y0, x0 + 3, y0, IRON[3])
    for y in (y0 + 3, y0 + 14):
        c.rect(x0 + 1, y, x0 + 3, y, OAK[2])
    # axle and hub between the wheel and the body
    hx0, hx1 = (x0 + 5, x0 + 7) if left else (x0 - 3, x0 - 1)
    c.rect(hx0, y0 + 7, hx1, y0 + 10, IRON[3])
    c.rect(hx0, y0 + 8, hx1, y0 + 8, IRON[0])
    c.rect(hx0, y0 + 9, hx1, y0 + 9, IRON[2])
    c.rect(x0 + 1, y0 + 7, x0 + 3, y0 + 10, IRON[3])
    c.put(x0 + 2, y0 + 8, BRASS[0])
    c.put(x0 + 2, y0 + 9, BRASS[2])


def chassis(c):
    for y0 in (10, 66):
        wheel(c, 13, y0, True)
        wheel(c, 78, y0, False)
    c.shade(23, 3, 76, 95, 70)


def bench(c, y0, ramp, back=True, x0=25, x1=70):
    c.shade(x0 + 1, y0 + 9, x1 + 1, y0 + 10, 70)
    c.bevel(x0, y0, x1, y0 + 8, ramp[0], ramp[1], ramp[2], outline=ramp[3])
    mid = (x0 + x1) // 2
    c.rect(mid, y0 + 1, mid, y0 + 7, ramp[2])
    c.rect(mid + 1, y0 + 1, mid + 1, y0 + 7, ramp[0])
    if back:
        c.bevel(x0, y0 + 9, x1, y0 + 11, mix(ramp[0], WHITE, 0.15), ramp[1], ramp[2], outline=ramp[3])


def corner_irons(c, x0, y0, x1, y1):
    for (x, y, dx, dy) in ((x0, y0, 1, 1), (x1, y0, -1, 1), (x0, y1, 1, -1), (x1, y1, -1, -1)):
        for i in range(4):
            c.put(x + dx * i, y, IRON[2])
            c.put(x, y + dy * i, IRON[2])
        c.put(x + dx, y + dy, IRON[0])


def wagon(c):
    """The open plank wagon: seats at y 17, 43 and 69."""
    chassis(c)
    # pole socket and footboard
    c.rect(45, 0, 50, 3, IRON[3])
    c.rect(46, 0, 49, 2, IRON[1])
    c.bevel(24, 2, 71, 8, OAK[0], OAK[1], OAK[2], outline=OAK[3])
    for x in (30, 40, 55, 65):
        c.put(x, 5, OAK[3])
    # the box: bed, then side, front and tail boards
    c.rect(21, 7, 74, 93, OAK[3])
    boards(c, 24, 10, 71, 90, seed=1)
    c.shade(24, 10, 71, 11, 70)
    c.shade(24, 10, 25, 90, 60)
    for x0 in (21, 72):
        c.bevel(x0, 7, x0 + 2, 93, OAK[0], OAK[1], OAK[2], outline=OAK[3])
        for y in (20, 36, 52, 68, 84):
            c.rect(x0, y, x0 + 2, y + 1, IRON[2])
            c.put(x0 + 1, y, IRON[0])
    c.bevel(21, 7, 74, 9, OAK[0], OAK[1], OAK[2], outline=OAK[3])
    c.bevel(21, 91, 74, 93, OAK[0], OAK[1], OAK[2], outline=OAK[3])
    for x in (36, 59):
        c.rect(x, 91, x + 1, 93, IRON[2])
        c.put(x, 92, IRON[0])
    corner_irons(c, 21, 7, 74, 93)
    bench(c, 13, HIDE, back=True)
    bench(c, 39, OAK, back=False)
    bench(c, 65, OAK, back=False)


def coach(c):
    """The coach: the same chassis under a lacquered body with leather seats."""
    chassis(c)
    c.rect(45, 0, 50, 3, IRON[3])
    c.rect(46, 0, 49, 2, IRON[1])
    # the driver's box
    c.bevel(26, 2, 69, 9, OAK[0], OAK[1], OAK[2], outline=OAK[3])
    c.rect(21, 9, 74, 28, LACQUER[3])
    boards(c, 24, 10, 71, 27, seed=2)
    for x0 in (21, 72):
        c.bevel(x0, 9, x0 + 2, 28, LACQUER[0], LACQUER[1], LACQUER[2], outline=LACQUER[3])
    bench(c, 13, HIDE, back=True)
    for x in (23, 72):
        c.disc(x + 0.5, 6.5, 2.6, [WHITE, BRASS[0], BRASS[1], BRASS[2]], outline=BRASS[3])
    # passenger body with a floor rug
    c.rect(20, 28, 75, 93, LACQUER[3])
    for y in range(32, 82):
        for x in range(24, 72):
            col = (112, 30, 36)
            if (x + y) % 6 == 0 or (x - y) % 6 == 0:
                col = (88, 20, 28)
            if (x % 6, y % 6) == (3, 3):
                col = BRASS[2]
            c.put(x, y, col)
    c.shade(24, 32, 71, 33, 80)
    c.shade(24, 32, 25, 81, 60)
    for x0 in (20, 72):
        c.rect(x0, 28, x0 + 3, 93, LACQUER[3])
        c.bands(x0 + 1, 29, x0 + 2, 92, [LACQUER[0], LACQUER[2]], along=True)
        c.rect(x0 + 1, 50, x0 + 2, 51, BRASS[1])
        c.rect(x0, 44, x0 + 3, 44, LACQUER[3])
        c.rect(x0, 58, x0 + 3, 58, LACQUER[3])
    c.rect(20, 28, 75, 31, LACQUER[3])
    c.bands(21, 29, 74, 30, [LACQUER[0], LACQUER[2]], along=False)
    for x in (22, 73):
        c.put(x, 29, BRASS[0])
    bench(c, 39, LEATHER, back=False)
    bench(c, 65, LEATHER, back=True)
    for y0 in (39, 65):
        for x in (30, 40, 55, 65):
            c.put(x, y0 + 4, LEATHER[3])
    # the folded hood behind the rear seat
    c.rect(20, 80, 75, 93, DARK)
    for i, y in enumerate(range(81, 93, 3)):
        c.bands(21, y, 74, y + 1, [(74, 70, 72), (40, 38, 42)], along=False)
    c.rect(21, 92, 74, 92, (28, 26, 30))
    for x in (21, 74):
        c.put(x, 81, BRASS[0])
        c.put(x, 92, BRASS[2])


def strap(c, x, y0, y1):
    c.rect(x, y0, x, y1, HIDE[2])
    for y in range(y0, y1 + 1, 4):
        c.put(x, y, HIDE[0])


def harness(length):
    """One rank of the team, 64 wide and `length` long, its rear at the bottom
    of a 64 x 64 canvas. Animals stand at x = 18 and x = 46."""
    def draw(c):
        top = 64 - length
        # pole down the middle, with its iron tip
        c.shade(33, top + 1, 34, 63, 60)
        c.rect(30, top, 33, 63, OAK[3])
        c.bands(31, top, 32, 63, [OAK[0], OAK[2]], along=True)
        for y in range(top + 6, 63, 12):
            c.rect(30, y, 33, y, IRON[2])
        # swingletree behind the animals
        c.shade(7, 62, 57, 62, 60)
        c.bevel(6, 58, 57, 61, OAK[0], OAK[1], OAK[2], outline=OAK[3])
        for x in (8, 28, 35, 55):
            c.rect(x, 58, x + 1, 61, IRON[2])
            c.put(x, 59, IRON[0])
        # traces either side of each animal, and the yoke at their shoulders
        yoke = top + max(4, length // 4)
        for cx in (18, 46):
            for x in (cx - 9, cx + 9):
                strap(c, x, yoke + 2, 57)
        c.shade(8, yoke + 3, 56, yoke + 3, 60)
        c.bevel(7, yoke, 56, yoke + 2, OAK[0], OAK[1], OAK[2], outline=OAK[3])
        for cx in (18, 46):
            c.rect(cx - 9, yoke, cx - 8, yoke + 2, IRON[2])
            c.rect(cx + 8, yoke, cx + 9, yoke + 2, IRON[2])
            c.put(cx - 9, yoke + 1, BRASS[0])
            c.put(cx + 9, yoke + 1, BRASS[0])
        c.rect(30, yoke - 1, 33, yoke + 3, IRON[3])
        c.put(31, yoke + 1, IRON[0])
    return directions(draw, w=64, h=64, order=HEADING)


def lap():
    """What hides a seated rider's legs, centred on the rider's 32 px sprite in
    the lower left of a 64 x 64 icon: a rug seen from the front and the sides,
    the seat back when the rider is seen from behind (facing north)."""
    frames = []
    for facing in 'SNEW':
        c = Canvas(64, 64)
        oy = 32
        if facing == 'N':
            c.shade(8, oy + 30, 24, oy + 30, 60)
            c.bevel(7, oy + 22, 24, oy + 29, OAK[0], OAK[2], OAK[3], outline=OAK[3])
            c.rect(8, oy + 23, 23, oy + 23, mix(OAK[0], WHITE, 0.2))
            for x in (12, 19):
                c.rect(x, oy + 24, x, oy + 28, OAK[3])
        else:
            x0, x1 = (8, 23) if facing == 'S' else ((9, 24) if facing == 'E' else (7, 22))
            c.rect(x0, oy + 19, x1, oy + 29, RUG[3])
            for y in range(oy + 20, oy + 29):
                for x in range(x0 + 1, x1):
                    col = RUG[1]
                    if (x - x0) % 5 == 2 or (y - oy) % 5 == 2:
                        col = RUG[2]
                    if (x - x0) % 5 == 2 and (y - oy) % 5 == 2:
                        col = BRASS[2]
                    c.put(x, y, col)
            c.rect(x0 + 1, oy + 20, x1 - 1, oy + 20, RUG[0])
            c.rect(x0 + 1, oy + 20, x0 + 1, oy + 28, RUG[0])
            for x in range(x0 + 1, x1, 2):
                c.put(x, oy + 30, RUG[1])
            c.clear(x0, oy + 29, x0, oy + 29)
            c.clear(x1, oy + 29, x1, oy + 29)
        frames.append(c.image())
    return frames


def carriage_states():
    return {'simple_carriage': directions(wagon, w=96, h=96, order=HEADING),
            'simple_carriage2': directions(coach, w=96, h=96, order=HEADING)}


def fitting_states():
    return {'harness_horse': harness(52), 'harness_ox': harness(30), 'lap': lap()}


def patched_sheet(states):
    """The committed 96 x 96 sheet with only our states' frames replaced."""
    old = Image.open(SHEET)
    text = old.info['Description']
    sheet = old.convert('RGBA')
    cols = sheet.width // 96
    import re
    i = 0
    for name, dirs, frames in re.findall(r'state = "([^"]*)"\n\tdirs = (\d+)\n\tframes = (\d+)', text):
        n = int(dirs) * int(frames)
        if name in states:
            assert n == 4, name
            for k, fr in enumerate(states[name]):
                j = i + k
                box = ((j % cols) * 96, (j // cols) * 96)
                sheet.paste(Image.new('RGBA', (96, 96), (0, 0, 0, 0)), box)
                sheet.paste(fr, box)
        i += n
    return sheet, text


def local_point(facing, along, across):
    """carriage_local_point() of carriage.dm, in pixels from the footprint's
    lower left corner (y up)."""
    return {'S': (64 - across, 96 - along), 'E': (along, 64 - across),
            'W': (96 - along, across), 'N': (across, along)}[facing]


SEATS = ((78, 22), (78, 44), (52, 18), (52, 46), (26, 18), (26, 46))
DIR_INDEX = {'S': 0, 'N': 1, 'E': 2, 'W': 3}


def figure(facing):
    """A plain stand-in for a rider, only for the review sheet."""
    c = Canvas(32, 32)
    c.rect(11, 12, 20, 22, (70, 96, 150))
    c.rect(12, 23, 14, 30, (60, 50, 44))
    c.rect(17, 23, 19, 30, (60, 50, 44))
    c.disc(15.5, 7.5, 4.2, [(240, 204, 170), (206, 160, 124)], outline=(90, 60, 40))
    if facing == 'N':
        c.disc(15.5, 7.0, 3.6, [(90, 60, 36), (60, 40, 24)])
    return c.image()


def scene(states, fittings, name, facing, riders=True, team='horse'):
    """A carriage with riders and one rank of a team, laid out as carriage.dm does."""
    rank = 52 if team == 'horse' else 30
    pad = 96
    w, h = ((64, 96) if facing in 'NS' else (96, 64))
    im = Image.new('RGBA', (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    for y in range(im.height):
        for x in range(im.width):
            n = noise(x, y, 300)
            base = mix((104, 128, 76), (92, 116, 68), noise(x // 6, y // 6, 301))
            im.putpixel((x, y), (mix(base, (70, 92, 52), 0.6) if n < 0.12 else base) + (255,))

    def put(img, px, py):
        """px, py: the image's lower left corner, from the footprint's (y up)."""
        im.alpha_composite(img, (int(pad + px), int(pad + h - py - img.height)))

    off = {'S': (-16, 0), 'N': (-16, 0), 'E': (0, -16), 'W': (0, -16)}[facing]
    ll = {'N': (0, 98), 'S': (0, 96 - 98 - 64), 'E': (98, 0), 'W': (96 - 98 - 64, 0)}[facing]
    put(fittings['harness_' + team][DIR_INDEX[facing]], *ll)
    put(states[name][DIR_INDEX[facing]], *off)
    if team == 'horse' and ANIMALS.exists():
        horse = read_dmi(ANIMALS).get('horse')
        if horse:
            for across in (18, 46):
                p = local_point(facing, 98 + rank / 2, across)
                put(horse[DIR_INDEX[facing]], p[0] - 30, p[1] - 28)
    if riders:
        for along, across in SEATS[:4]:
            p = local_point(facing, along, across)
            put(figure(facing), p[0] - 16, p[1] - 16)
            put(fittings['lap'][DIR_INDEX[facing]], p[0] - 16, p[1] - 16)
    return im


def write_preview(path, states, fittings):
    tiles = [scene(states, fittings, name, facing, team=team)
             for name, team in (('simple_carriage', 'horse'), ('simple_carriage2', 'horse'))
             for facing in 'SNEW']
    w = max(t.width for t in tiles)
    h = max(t.height for t in tiles)
    im = Image.new('RGBA', (w * 4, h * 2), (96, 120, 84, 255))
    for i, t in enumerate(tiles):
        im.paste(t, (i % 4 * w + (w - t.width) // 2, i // 4 * h + (h - t.height) // 2))
    im.resize((im.width * 3, im.height * 3), Image.NEAREST).save(path)


def main(argv):
    states = carriage_states()
    fittings = fitting_states()
    sheet, text = patched_sheet(states)
    if '--check' in argv:
        ok = Image.open(SHEET).convert('RGBA').tobytes() == sheet.tobytes()
        if FITTINGS.exists():
            ok = ok and Image.open(FITTINGS).convert('RGBA').tobytes() == sheet_image(fittings, size=(64, 64), cols=4).tobytes()
        else:
            ok = False
        print('carriage sheets match' if ok else 'carriage sheets are out of date')
        return 0 if ok else 1
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(SHEET, format='PNG', pnginfo=meta)
    write_dmi(FITTINGS, fittings, size=(64, 64), cols=4)
    print('wrote the carriages and %d fitting states' % len(fittings))
    if '--preview' in argv:
        write_preview(Path(argv[argv.index('--preview') + 1]), states, fittings)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
