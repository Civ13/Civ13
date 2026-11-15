"""Tintable style masks for bags, quivers, bandoliers and shoulder belts.

A tailor can restyle a finished bag (code/modules/1713/bag_styling.dm): dye
its fabric, dye its straps and add a trim. Each of those is one greyscale
state drawn over the unchanged sprite and coloured in game, so storage,
pouches and every other state of the bag stay exactly as they are.

Nothing here is traced, generated or imported: the masks are cut from the
game's own sprites by the fixed rules below. Released under Civ13's AGPL-3.0
licence. Run with Pillow from the repository root:

    python3 tests/sprites/create_bag_styles.py [--check] [--preview sheet.png]

It writes two files with matching state names "<bag>_<zone>":

- icons/obj/clothing/bag_styles.dmi: the loose item, one direction.
- icons/mob/bag_styles.dmi: the worn overlay, four directions (SOUTH, NORTH,
  EAST, WEST).

Rules, per sprite:

- fabric: every pixel that survives a 3x3 opening of the sprite's shape - the
  solid bag, without thin straps.
- straps: every other pixel of the sprite.
- fittings: pixels far brighter than the rest of their zone (a brass clasp, a
  bone toggle, stitches) belong to neither and stay undyed.
- trim: a one-pixel band across the fabric at the flap line (bags), or evenly
  spaced studs along the strap (bandolier, shoulder belt). Trim pixels are
  new; with no trim chosen the bag shows none.

Fabric and strap pixels keep the sprite's own shading, stretched to the
tintable range 96..250 so a dye reads at full strength. To add a bag, add a
row to BAGS (and to bag_style_kinds in the DM file) and rerun; do not
hand-edit the DMIs.
"""
import sys
from pathlib import Path
from PIL import Image, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
OBJ = ROOT / 'icons/obj/clothing/bag_styles.dmi'
MOB = ROOT / 'icons/mob/bag_styles.dmi'
S = 32
LOW, HIGH, TRIM = 96, 250, 236

# id: (loose file, loose state, worn file, worn state, zones, trim rule)
BAGS = {
    'backpack': ('icons/obj/storage.dmi', 'backpack', 'icons/mob/back.dmi', 'backpack', ('fabric', 'straps', 'trim'), 'band'),
    'satchel': ('icons/obj/storage.dmi', 'satchel', 'icons/mob/back.dmi', 'satchel', ('fabric', 'straps', 'trim'), 'band'),
    'duffel': ('icons/obj/storage.dmi', 'duffel', 'icons/mob/back.dmi', 'duffel', ('fabric', 'straps', 'trim'), 'band'),
    'rucksack': ('icons/obj/storage.dmi', 'rucksack', 'icons/mob/back.dmi', 'rucksack', ('fabric', 'straps', 'trim'), 'band'),
    'quiver': ('icons/obj/storage.dmi', 'quiver', 'icons/mob/back.dmi', 'quiver', ('fabric', 'straps', 'trim'), 'band'),
    'sling_bag': ('icons/obj/primitive_carrying.dmi', 'sling_bag', 'icons/mob/primitive_carrying.dmi', 'sling_bag', ('fabric', 'straps', 'trim'), 'band'),
    'bandolier': ('icons/obj/clothing/ties.dmi', 'bandolier', 'icons/mob/ties.dmi', 'bandolier', ('straps', 'trim'), 'studs'),
    'baldric': ('icons/obj/belt_pouches.dmi', 'baldric', 'icons/mob/belt_pouches.dmi', 'baldric', ('straps', 'trim'), 'studs'),
}

_sheets = {}


def source(path, name, direction=0):
    """One 32px frame of a state in one of the game's own DMIs."""
    if path not in _sheets:
        sheet = Image.open(ROOT / path)
        states = []
        for line in sheet.info['Description'].split('\n'):
            line = line.strip()
            if line.startswith('state = '):
                states.append([line[9:-1], 1, 1])
            elif line.startswith('dirs = '):
                states[-1][1] = int(line[7:])
            elif line.startswith('frames = '):
                states[-1][2] = int(line[9:])
        _sheets[path] = (sheet.convert('RGBA'), states)
    sheet, states = _sheets[path]
    index = 0
    for state, dirs, count in states:
        if state == name:
            index += direction if dirs > 1 else 0
            cols = sheet.width // S
            x, y = (index % cols) * S, (index // cols) * S
            return sheet.crop((x, y, x + S, y + S))
        index += dirs * count
    raise KeyError('%s has no state %s' % (path, name))


def shape(frame):
    return {(x, y) for y in range(S) for x in range(S) if frame.getpixel((x, y))[3] > 0}


def near(point):
    x, y = point
    return [(x + dx, y + dy) for dy in (-1, 0, 1) for dx in (-1, 0, 1)]


def solid(pixels):
    """A 3x3 opening: the pixels of any fully filled 3x3 block."""
    cores = {p for p in pixels if all(q in pixels for q in near(p))}
    return {q for p in cores for q in near(p)} & pixels


def luminance(pixel):
    return (pixel[0] * 299 + pixel[1] * 587 + pixel[2] * 114) // 1000


def fittings(frame, pixels):
    """Buckles, toggles and stitches: pixels far brighter than the material.

    They stay undyed, so a restyled bag keeps its clasp."""
    if len(pixels) < 8:
        return set()
    lums = sorted(luminance(frame.getpixel(p)) for p in pixels)
    usual = lums[len(lums) * 3 // 4]
    return {p for p in pixels if luminance(frame.getpixel(p)) > usual * 3 // 2 and luminance(frame.getpixel(p)) - usual > 30}


def shaded(frame, pixels):
    """The zone's own shading stretched to the tintable range."""
    out = Image.new('RGBA', (S, S))
    if not pixels:
        return out
    lums = {p: luminance(frame.getpixel(p)) for p in pixels}
    low, high = min(lums.values()), max(lums.values())
    for p, lum in lums.items():
        grey = 224 if high == low else LOW + (lum - low) * (HIGH - LOW) // (high - low)
        out.putpixel(p, (grey, grey, grey, 255))
    return out


def flat(pixels):
    out = Image.new('RGBA', (S, S))
    for p in pixels:
        out.putpixel(p, (TRIM, TRIM, TRIM, 255))
    return out


def band(fabric):
    """One row across the fabric, two fifths of the way down: the flap edge."""
    if not fabric:
        return set()
    top = min(y for _, y in fabric)
    bottom = max(y for _, y in fabric)
    row = top + (bottom - top) * 2 // 5
    return {(x, y) for x, y in fabric if y == row}


def studs(straps):
    """Every third pixel of the strap's lighter half, walking down it."""
    return {(x, y) for x, y in straps if (x + 2 * y) % 5 == 0}


def zones(frame, bag):
    zone_names, rule = BAGS[bag][4], BAGS[bag][5]
    pixels = shape(frame)
    fabric = solid(pixels) if 'fabric' in zone_names else set()
    straps = pixels - fabric
    fabric -= fittings(frame, fabric)
    straps -= fittings(frame, straps)
    trim = band(fabric) if rule == 'band' else studs(straps)
    made = {'fabric': shaded(frame, fabric), 'straps': shaded(frame, straps), 'trim': flat(trim)}
    return {zone: made[zone] for zone in zone_names}


def build():
    loose, worn = {}, {}
    for bag, row in BAGS.items():
        item = zones(source(row[0], row[1]), bag)
        sides = [zones(source(row[2], row[3], d), bag) for d in range(4)]
        for zone in row[4]:
            loose['%s_%s' % (bag, zone)] = item[zone]
            worn['%s_%s' % (bag, zone)] = [side[zone] for side in sides]
    return loose, worn


def sheet_of(states, dirs):
    frames = [fr for name in states for fr in (states[name] if dirs > 1 else [states[name]])]
    cols = 4 if dirs > 1 else 8
    sheet = Image.new('RGBA', (cols * S, ((len(frames) + cols - 1) // cols) * S))
    for i, fr in enumerate(frames):
        sheet.paste(fr, ((i % cols) * S, (i // cols) * S))
    text = '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    for name in states:
        text += 'state = "%s"\n\tdirs = %d\n\tframes = 1\n' % (name, dirs)
    text += '# END DMI\n'
    return sheet, text


def write_dmi(path, states, dirs):
    sheet, text = sheet_of(states, dirs)
    meta = PngImagePlugin.PngInfo()
    meta.add_text('Description', text, zip=True)
    sheet.save(path, format='PNG', pnginfo=meta)


def same(path, states, dirs):
    if not path.exists():
        return False
    sheet, text = sheet_of(states, dirs)
    old = Image.open(path)
    return old.info.get('Description') == text and old.convert('RGBA').tobytes() == sheet.tobytes() and old.size == sheet.size


def tinted(mask, color):
    rgb = tuple(int(color[i:i + 2], 16) for i in (1, 3, 5))
    out = Image.new('RGBA', (S, S))
    for y in range(S):
        for x in range(S):
            g, _, _, a = mask.getpixel((x, y))
            if a:
                out.putpixel((x, y), (rgb[0] * g // 255, rgb[1] * g // 255, rgb[2] * g // 255, 255))
    return out


# Review styles: (fabric, straps, trim); None leaves that part as it was.
STYLES = (
    (None, None, None),
    ('#3e5a86', None, '#d6c050'),
    ('#a8342c', '#2a2826', '#e0b030'),
    ('#3e6a3a', '#6e4c30', None),
    ('#d8ccb0', '#7a3e6e', '#b01c30'),
)


def write_preview(path, loose, worn, scale=5):
    """Each bag in each review style: the loose item, then worn from four sides."""
    cell = S * scale
    out = Image.new('RGBA', (len(STYLES) * 5 * cell, len(BAGS) * cell), (92, 110, 92, 255))
    for r, (bag, row) in enumerate(BAGS.items()):
        for s, style in enumerate(STYLES):
            colors = dict(zip(('fabric', 'straps', 'trim'), style))
            for v in range(5):
                frame = source(row[0], row[1]) if v == 0 else source(row[2], row[3], v - 1)
                frame = frame.copy()
                for zone in row[4]:
                    if colors[zone]:
                        mask = loose['%s_%s' % (bag, zone)] if v == 0 else worn['%s_%s' % (bag, zone)][v - 1]
                        frame.alpha_composite(tinted(mask, colors[zone]))
                out.alpha_composite(frame.resize((cell, cell), Image.NEAREST), ((s * 5 + v) * cell, r * cell))
    out.save(path)


def main(argv):
    loose, worn = build()
    if '--check' in argv:
        ok = same(OBJ, loose, 1) and same(MOB, worn, 4)
        print('bag style sprites are current' if ok else 'bag style sprites are stale: rerun tests/sprites/create_bag_styles.py')
        return 0 if ok else 1
    write_dmi(OBJ, loose, 1)
    write_dmi(MOB, worn, 4)
    if '--preview' in argv:
        write_preview(argv[argv.index('--preview') + 1], loose, worn)
    print('wrote %d loose and %d worn states' % (len(loose), len(worn)))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
