"""Hand-placed "tap to step" HUD toggle for the three drawn HUD sheets:
1713Style.dmi, litewebStyle.dmi and FoFStyle.dmi. It adds two states to each
sheet:

    tap_step_on, tap_step_off

The picture is one bare footprint (toes, ball, arch and heel) inside the four corner
marks of a tile: one tap, one tile. Each button reuses that sheet's own blank
button frame (the same tile and plate rules as `create_craft_button.py`) and
every pixel is placed by this script from that sheet's own picture colours
(Pillow only); no external or generated artwork. The `_off` state keeps the
frame and draws the picture flat, greyed and close to the plate colour, the
way the greyed up and down arrows are drawn, so the lit button reads as "on".

ConsoleStyle.dmi is rebuilt from 1713Style.dmi afterwards with
`python3 tools/hud-skin/build_console_style.py`.

Run with Pillow to add or redraw the states; a rerun replaces them in place.
Every other state keeps its pixels and its metadata, which the script asserts
before it writes. `--check` verifies the committed sheets match and
`--preview <dir>` writes `tap_step_4x.png` and `tap_step_1x.png` review sheets
with both states of every style (ConsoleStyle included, as committed) beside
two neighbouring buttons.
Released under Civ13 AGPL-3.0.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
sys.path.insert(0, str(Path(__file__).resolve().parent))
from dmi import Dmi  # noqa: E402
from create_craft_button import SHEETS  # noqa: E402  (frames, tones, plates)

SCREEN = ROOT / 'icons/mob/screen'
STATES = ('tap_step_on', 'tap_step_off')

# H highlight, M main, S shade. 18 columns, drawn from (7, 7), which centres
# it on the 24px plate. Light comes from the left.
PICTURE = (
    'SSSS..........SSSS',
    'S....HM.M.M.M....S',
    'S....MS.S.S.S....S',
    'S................S',
    '.....HMMMMMMMS....',
    '.....HMMMMMMMS....',
    '.....HMMMMMMS.....',
    '......HMMMMS......',
    '......HMMMS.......',
    '......HMMMS.......',
    '......HMMMMS......',
    '.....HMMMMMS......',
    '.....HMMMMMS......',
    '.....HMMMMMS......',
    'S.....HMMMS......S',
    'S......SSS.......S',
    'S................S',
    'SSSS..........SSSS',
)
ORIGIN = (7, 7)
assert len(PICTURE) == 18 and all(len(row) == 18 for row in PICTURE)
# How far the greyed picture of the "_off" button stands off the plate; the
# same values and reasons as the greyed arrows (create_updown_buttons.py).
OFF_MIX = {'1713Style.dmi': 0.24, 'litewebStyle.dmi': 0.42, 'FoFStyle.dmi': 0.42}

CONTEXT = {  # style sheet -> neighbouring buttons shown in the preview
    '1713Style.dmi': ('walking', 'craft'),
    'ConsoleStyle.dmi': ('walking', 'craft'),
    'litewebStyle.dmi': ('walking', 'craft'),
    'FoFStyle.dmi': ('walking', 'craft'),
}


def off_tone(sheet_name):
    """The one flat colour of that sheet's greyed picture."""
    spec = SHEETS[sheet_name]
    main = spec['tones']['M']
    grey = round(0.3 * main[0] + 0.59 * main[1] + 0.11 * main[2])
    plate = [(a + b) // 2 for a, b in zip(*spec['rows'])]
    return tuple(round(p + (grey - p) * OFF_MIX[sheet_name]) for p in plate)


def draw(sheet_name, dmi, state):
    spec = SHEETS[sheet_name]
    im = dmi.get_state(spec['frame']).get_frame(0).convert('RGBA').copy()
    # Clear the old picture inside the frame back to the plate.
    for y in range(4, 28):
        for x in range(4, 28):
            if not spec['is_plate'](im.getpixel((x, y))):
                im.putpixel((x, y), spec['rows'][y % 2] + (255,))
    for dy, line in enumerate(PICTURE):
        for dx, key in enumerate(line):
            if key == '.':
                continue
            tone = off_tone(sheet_name) if state.endswith('_off') else spec['tones'][key]
            im.putpixel((ORIGIN[0] + dx, ORIGIN[1] + dy), tone + (255,))
    return im


def metadata(dmi, skip=()):
    """The metadata block of every state but the skipped ones."""
    text = dmi._assemble_comment()
    blocks = text.split('\nstate = ')
    return [blocks[0]] + [b.replace('\n# END DMI', '') for b in blocks[1:]
                          if b.split('\n')[0].strip('"') not in skip]


def build(sheet_name):
    path = str(SCREEN / sheet_name)
    dmi = Dmi.from_file(path)
    before = metadata(dmi, STATES)
    pixels = [(s.name, [f.tobytes() for f in s.frames]) for s in dmi.states if s.name not in STATES]
    tiles = {}
    for name in STATES:
        tiles[name] = draw(sheet_name, dmi, name)
        for state in dmi.states:
            if state.name == name:
                state.frames[:] = [tiles[name]]
                state.delays[:] = [1]
                break
        else:
            dmi.state(name).frame(tiles[name])
    assert metadata(dmi, STATES) == before, sheet_name
    assert pixels == [(s.name, [f.tobytes() for f in s.frames]) for s in dmi.states if s.name not in STATES]
    assert [s.name for s in dmi.states].count(STATES[0]) == 1
    return dmi, tiles


def matches(sheet_name, tiles):
    current = Dmi.from_file(str(SCREEN / sheet_name))
    names = [s.name for s in current.states]
    if any(names.count(n) != 1 for n in STATES):
        return False
    return all(current.get_state(n).get_frame(0).convert('RGBA').tobytes() == tiles[n].tobytes() for n in STATES)


def preview(folder):
    folder = Path(folder)
    folder.mkdir(parents=True, exist_ok=True)
    ground = (60, 90, 60, 255)
    cell, label_w, label_h = 36, 84, 12
    names = list(STATES) + ['', '']
    strip = Image.new('RGBA', (len(names) * cell + 4, len(CONTEXT) * cell + 4), ground)
    big = Image.new('RGBA', (label_w + len(names) * cell * 4 + 8, len(CONTEXT) * (cell * 4 + label_h) + 8), ground)
    pen = ImageDraw.Draw(big)
    for row, (sheet_name, context) in enumerate(CONTEXT.items()):
        dmi = Dmi.from_file(str(SCREEN / sheet_name))
        top = 4 + row * (cell * 4 + label_h)
        pen.text((4, top + label_h + 60), sheet_name.replace('.dmi', ''), fill=(255, 255, 255, 255))
        for col, name in enumerate(list(STATES) + list(context)):
            tile = dmi.get_state(name).get_frame(0).convert('RGBA')
            strip.alpha_composite(tile, (4 + col * cell, 4 + row * cell))
            x = label_w + col * cell * 4 + (16 if col >= len(STATES) else 0)
            pen.text((x, top), name, fill=(255, 255, 255, 255))
            big.alpha_composite(tile.resize((128, 128), Image.NEAREST), (x, top + label_h))
    big.save(folder / 'tap_step_4x.png')
    strip.save(folder / 'tap_step_1x.png')


def main():
    check = '--check' in sys.argv
    bad = []
    for sheet_name in SHEETS:
        dmi, tiles = build(sheet_name)
        if check:
            if not matches(sheet_name, tiles):
                bad.append(sheet_name)
        else:
            dmi.to_file(str(SCREEN / sheet_name))
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
    if bad:
        print('tap to step buttons differ in: ' + ', '.join(bad))
        return 1
    print('tap to step buttons ' + ('match' if check else 'written') + ' in ' + ', '.join(SHEETS))
    return 0


if __name__ == '__main__':
    sys.exit(main())
