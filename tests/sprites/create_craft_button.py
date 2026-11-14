"""Hand-placed "craft" HUD button (hammer over an anvil) for the three drawn
HUD sheets: 1713Style.dmi, litewebStyle.dmi and FoFStyle.dmi. Each button
reuses that sheet's own blank button frame (an existing tile with its
picture cleared back to the plate) and every picture pixel is placed by this
script from that sheet's own picture colours (Pillow only); no external or
generated artwork.

ConsoleStyle.dmi is rebuilt from 1713Style.dmi afterwards with
`python3 tools/hud-skin/build_console_style.py`.

Run with Pillow to add or redraw the state. `--check` verifies the committed
sheets match and `--preview <png>` writes an enlarged review sheet.
Released under Civ13 AGPL-3.0.
"""
import sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from dmi import Dmi  # noqa: E402

SCREEN = ROOT / 'icons/mob/screen'
STATE = 'craft'

# H highlight, M main, S shade. 20 columns, drawn from (6, 7).
PICTURE = (
    '...........HM.......',
    '..........HMMM......',
    '.........HMMMMM.....',
    '........HMMMMMS.....',
    '.........MMMMS.S....',
    '..........MMS.SMS...',
    '...........S...SMS..',
    '................SMS.',
    '.................SS.',
    '....................',
    'HHHHHHHHHHHHHHHHH...',
    '.SMMMMMMMMMMMMMMM...',
    '...SSMMMMMMMMMMMS...',
    '.......SMMMMMS......',
    '.......SMMMMMS......',
    '......SMMMMMMMS.....',
    '....HHHHHHHHHHHHH...',
    '....SSSSSSSSSSSSS...',
)
ORIGIN = (6, 7)

# sheet -> (tile whose frame is reused, picture colours, plate rows)
# A plate row colour is chosen by (y % 2); pixels of the old picture are
# painted back to it. is_plate() says which pixels already belong to the frame.
SHEETS = {
    '1713Style.dmi': {
        'frame': 'fixeye',
        'tones': {'H': (172, 157, 144), 'M': (151, 133, 116), 'S': (123, 103, 85)},
        'rows': ((91, 71, 54), (85, 65, 49)),
        'is_plate': lambda p: max(p[:3]) <= 100,
    },
    'litewebStyle.dmi': {
        'frame': 'equip',
        'tones': {'H': (67, 111, 44), 'M': (34, 109, 22), 'S': (9, 78, 11)},
        'rows': ((27, 29, 26), (39, 41, 37)),
        'is_plate': lambda p: p[1] - p[0] < 8,
    },
    'FoFStyle.dmi': {
        'frame': 'kick',
        'tones': {'H': (174, 153, 65), 'M': (149, 130, 56), 'S': (105, 71, 39)},
        'rows': ((34, 30, 28), (34, 30, 28)),
        'is_plate': lambda p: p[:3] == (34, 30, 28),
    },
}


def draw(sheet_name, dmi):
    spec = SHEETS[sheet_name]
    im = dmi.get_state(spec['frame']).get_frame(0).convert('RGBA').copy()
    # Clear the old picture inside the frame back to the plate.
    for y in range(4, 28):
        for x in range(4, 28):
            if not spec['is_plate'](im.getpixel((x, y))):
                im.putpixel((x, y), spec['rows'][y % 2] + (255,))
    for dy, line in enumerate(PICTURE):
        for dx, key in enumerate(line):
            if key != '.':
                im.putpixel((ORIGIN[0] + dx, ORIGIN[1] + dy), spec['tones'][key] + (255,))
    return im


def build(sheet_name):
    dmi = Dmi.from_file(str(SCREEN / sheet_name))
    im = draw(sheet_name, dmi)
    for state in dmi.states:
        if state.name == STATE:
            state.frames[0] = im
            return dmi, im
    dmi.state(STATE).frame(im)
    return dmi, im


def main():
    check = '--check' in sys.argv
    preview = sys.argv[sys.argv.index('--preview') + 1] if '--preview' in sys.argv else None
    tiles, bad = [], []
    for sheet_name in SHEETS:
        dmi, im = build(sheet_name)
        tiles.append(im)
        if check:
            current = Dmi.from_file(str(SCREEN / sheet_name))
            names = [s.name for s in current.states]
            if STATE not in names or current.get_state(STATE).get_frame(0).convert("RGBA").tobytes() != im.tobytes():
                bad.append(sheet_name)
        else:
            dmi.to_file(str(SCREEN / sheet_name))
    if preview:
        sheet = Image.new('RGBA', (len(tiles) * 272 + 8, 272 + 8), (60, 90, 60, 255))
        for i, im in enumerate(tiles):
            big = im.resize((256, 256), Image.NEAREST)
            sheet.paste(big, (i * 272 + 8, 8), big)
        sheet.save(preview)
    if bad:
        print('craft button differs in: ' + ', '.join(bad))
        return 1
    print('craft button ' + ('matches' if check else 'written') + ' in ' + ', '.join(SHEETS))
    return 0


if __name__ == '__main__':
    sys.exit(main())
