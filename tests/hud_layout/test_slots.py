"""Offline checks that every HUD button has its own spot at 100%, in every
style: the right-hand column (the eye button is a whole tile standing on the
short Random label) and the combat stance button beside dodge / parry.

Places tiles the way apply_hud_layout() does: grid locs are anchored by thirds
on the 15x15 design grid, named locs are used as written, and a style's
wide_locs replace a tile's spot on a view at least two tiles wider.
"""
from pathlib import Path
import re
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_console_style import ROOT, SCREEN, GUN, read, state_frame  # noqa: E402

DESIGN = 480
# Buttons that share a tile on purpose (quarter-tile and half-tile drawings).
SHARED = [
    {'help', 'disarm', 'intent', 'harm', 'grab'},
    {'equip', 'swap hand', 'drop', 'throw', 'pull', 'resist'},
]
SIZES = {'needs': (64, 32), 'swap hand': (64, 32), 'damage zone': (32, 64)}
# Drawn smaller than their tile; measured from the sheet.
MEASURED = {'fixeye': 'fixeye', 'random damage zone': 'random'}
COLUMN = ('damage zone', 'random damage zone', 'fixeye', 'go down', 'go up', 'nutrition', 'health', 'mood',
          'body temperature', 'tap step', 'combat stance')


def styles():
    """-> [(name, sheet path, anchored, {tile: loc}, {tile: wide loc})]"""
    out = []
    for block in re.split(r'^(?=/datum/hud/human)', read('code/datums/hud.dm'), flags=re.M)[1:]:
        name = re.search(r'name = "(\w+)"', block)[1]
        sheet = ROOT / re.search(r"icon = '([^']+)'", block)[1]
        body = block[block.index('HUDneed = list('):]
        tiles = dict(re.findall(r'^\t\t"([^"]+)"\s*=\s*list\((?:"type" = [^,]+,\s*)?"loc" = "([^"]+)"', body, re.M))
        wide = {}
        found = re.search(r'^\twide_locs = list\((.*?)\)\n', block, re.M | re.S)
        if found:
            wide = dict(re.findall(r'"(?:need|inv):([^"]+)" = "([^"]+)"', found[1]))
        out.append((name, sheet, 'anchored_layout = TRUE' in block, tiles, wide))
    return out


def parse_axis(text, horizontal):
    px = 0
    if ':' in text:
        text, _, tail = text.partition(':')
        px = float(tail)
    low, high = ('WEST', 'EAST') if horizontal else ('SOUTH', 'NORTH')
    for anchor, base in ((low, 0), (high, -32), ('CENTER', -16)):
        if text.startswith(anchor):
            shift = text[len(anchor):].replace('+', '')
            return anchor, base + (float(shift) * 32 if shift else 0) + px
    return low, (float(text) - 1) * 32 + px


def origin(anchor, size):
    return size if anchor in ('EAST', 'NORTH') else size / 2 if anchor == 'CENTER' else 0


def third(centre):
    return 0 if centre < DESIGN / 3 else 2 if centre > DESIGN * 2 / 3 else 1


def spot(loc, infer, view_w, view_h=480):
    """Lower-left pixel of a tile on the view."""
    xs, ys = loc.split(',')
    ax, ox = parse_axis(xs, True)
    ay, oy = parse_axis(ys, False)
    if infer:
        x, y = origin(ax, DESIGN) + ox, origin(ay, DESIGN) + oy
        ax = ('WEST', 'CENTER', 'EAST')[third(x + 16)]
        ay = ('SOUTH', 'CENTER', 'NORTH')[third(y + 16)]
        ox, oy = x - origin(ax, DESIGN), y - origin(ay, DESIGN)
    return origin(ax, view_w) + ox, origin(ay, view_h) + oy


def art_box(sheet, state):
    """(left, bottom, width, height) of the drawn part of a state, from the tile's lower-left."""
    frame = state_frame(sheet, state)
    rows = [i for i, row in enumerate(frame) if any(p[3] for p in row)]
    cols = [i for i in range(len(frame[0])) if any(row[i][3] for row in frame)]
    return cols[0], len(frame) - 1 - rows[-1], cols[-1] - cols[0] + 1, rows[-1] - rows[0] + 1


def placed(style, columns):
    name, sheet, anchored, tiles, wide = style
    if columns * 32 < DESIGN + 64:
        wide = {}
    out = {}
    for tile, loc in tiles.items():
        if tile in GUN:
            continue
        x, y = spot(wide.get(tile, loc), not anchored and tile not in wide, columns * 32)
        left, bottom, w, h = art_box(sheet, MEASURED[tile]) if tile in MEASURED else (0, 0) + SIZES.get(tile, (32, 32))
        out[tile] = (x + left, y + bottom, w, h)
    return out


def overlap(a, b):
    return a[0] < b[0] + b[2] and b[0] < a[0] + a[2] and a[1] < b[1] + b[3] and b[1] < a[1] + a[3]


class OwnSpot(unittest.TestCase):
    def test_right_column_buttons_do_not_cover_each_other(self):
        for style in styles():
            for columns in (21, 15):
                tiles = placed(style, columns)
                names = [n for n in COLUMN if n in tiles]
                for i, a in enumerate(names):
                    for b in names[i + 1:]:
                        self.assertFalse(overlap(tiles[a], tiles[b]), (style[0], columns, a, b, tiles[a], tiles[b]))

    def test_eye_button_is_drawn_clear_of_the_down_arrow(self):
        # The exact report: a whole-tile eye button raised onto the Random
        # label reached into the tile above it.
        for style in styles():
            tiles = placed(style, 21)
            eye, down = tiles['fixeye'], tiles['go down']
            self.assertFalse(overlap(eye, down), style[0])
            self.assertFalse(overlap(eye, tiles['random damage zone']), style[0])

    def test_stance_button_has_a_free_spot_on_both_views(self):
        for style in styles():
            for columns in (21, 15):
                tiles = placed(style, columns)
                for other, box in tiles.items():
                    if other == 'combat stance' or any(other in g for g in SHARED):
                        continue
                    self.assertFalse(overlap(tiles['combat stance'], box), (style[0], columns, other))

    def test_stance_sits_beside_dodge_on_the_widescreen_view(self):
        for style in styles():
            if not style[4]:
                continue  # NewStyle keeps its side columns; ConsoleStyle has its own test
            tiles = placed(style, 21)
            stance, mode = tiles['combat stance'], tiles['mode']
            self.assertEqual(stance[1], mode[1], style[0])
            self.assertEqual(stance[0], mode[0] + 32, style[0])
        self.assertEqual(sorted(s[0] for s in styles() if s[4]), ['1713Style', 'FoFStyle', 'LiteWebStyle'])

    def test_wide_spots_keep_the_action_row_clear(self):
        for style in styles():
            tiles = placed(style, 21)
            for moved in style[4]:
                for other, box in tiles.items():
                    if other != moved:
                        self.assertFalse(overlap(tiles[moved], box), (style[0], moved, other))

    def test_console_stance_is_next_to_the_body_part_selector(self):
        style = next(s for s in styles() if s[0] == 'ConsoleStyle')
        # Fighting around the selector on both views: stance beside it, kick
        # above the stance, dodge / parry and the tactic along that row.
        for columns in (21, 15):
            tiles = placed(style, columns)
            stance, doll = tiles['combat stance'], tiles['damage zone']
            self.assertEqual((stance[0] + 32, stance[1]), (doll[0], doll[1]), columns)
            kick, mode, tactic = tiles['secondary attack'], tiles['mode'], tiles['tactic']
            self.assertEqual((kick[0], kick[1]), (stance[0], stance[1] + 32), columns)
            self.assertEqual([tactic[0], mode[0]], [kick[0] - 64, kick[0] - 32], columns)

    def test_console_movement_buttons_form_one_stack(self):
        style = next(s for s in styles() if s[0] == 'ConsoleStyle')
        for columns in (21, 15):
            tiles = placed(style, columns)
            stack = [tiles[n] for n in ('m_intent', 'tap step', 'go down', 'go up')]
            # One column on the right edge, tile on tile, a gap above the eye.
            self.assertEqual({box[0] for box in stack}, {columns * 32 - 32}, columns)
            self.assertEqual([b[1] - a[1] for a, b in zip(stack, stack[1:])], [32, 32, 32], columns)
            eye = tiles['fixeye']
            self.assertGreaterEqual(stack[0][1] - (eye[1] + eye[3]), 4, columns)

    def test_tiles_are_filed_under_the_style_key(self):
        # The stance button renames itself for its hover text; filed under its
        # name it could not be found again, so a click never redrew it.
        source = read('code/game/mob/living/carbon/human/human_hud.dm')
        self.assertIn('H.HUDneed[HUDname] = HUD', source)
        self.assertNotIn('H.HUDneed[HUD.name]', source)
        button = read('code/_onclick/hud/base_screen_objects.dm')
        self.assertIn('name = "combat stance: [combat_stance_names[stance]]"', button)
        self.assertIn('HUDneed[key]', read('code/game/mob/combat_stance.dm'))

    def test_layout_reads_the_wide_spots(self):
        source = read('code/_onclick/hud/hud_layout.dm')
        self.assertIn('V[1] >= design[1] + 2) ? style.wide_locs : null', source)
        self.assertIn('hud_parse_screen_loc(wide[S.hud_layout_key])', source)
        self.assertIn('var/list/wide_locs = null', read('code/datums/hud.dm'))


if __name__ == '__main__':
    unittest.main()
