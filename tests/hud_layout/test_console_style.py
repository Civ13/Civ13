"""Offline checks for the ConsoleStyle HUD: its icon files, its anchored
default layout and the food / water / stamina bars.

The layout test mirrors hud_parse_axis()/hud_anchor_origin() from hud_layout.dm
and places every default tile on the widescreen and the square view.
"""
from pathlib import Path
import re
import struct
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[2]
SCREEN = ROOT / 'icons/mob/screen'
# Tiles that share a spot on purpose: quarter-tile buttons drawn in one corner
# of a 32px icon, the swap bar over the equip button, the label over the eye.
SHARED = [
    {'help', 'disarm', 'intent', 'harm', 'grab'},
    {'equip', 'swap hand', 'drop', 'throw', 'pull', 'resist'},
    {'random damage zone', 'fixeye'},
]
# Drawn sizes that are not one 32px tile. The hand buttons are 16px, drawn in
# the lower-left corner of their icon.
SIZES = {'needs': (64, 32), 'swap hand': (64, 32), 'damage zone': (32, 64),
         'drop': (16, 16), 'throw': (16, 16), 'pull': (16, 16), 'resist': (16, 16)}
# Shown only while aiming a gun, in the row above the action corner.
GUN = {'toggle gun mode', 'allow movement', 'allow item use'}


def read(path):
    return (ROOT / path).read_text(encoding='utf-8', errors='replace')


def dmi_states(path):
    data = Path(path).read_bytes()
    i = data.find(b'zTXt')
    length = struct.unpack('>I', data[i - 4:i])[0]
    chunk = data[i + 4:i + 4 + length]
    text = zlib.decompress(chunk[chunk.index(bytes(1)) + 2:]).decode()
    size = (int(re.search(r'width = (\d+)', text)[1]), int(re.search(r'height = (\d+)', text)[1]))
    return size, re.findall(r'state = "([^"]*)"\n((?:\t[^\n]*\n)*)', text)


def dmi_pixels(path):
    """-> (sheet width, rows of RGBA tuples) for an 8-bit RGBA or palette PNG."""
    data = Path(path).read_bytes()
    pos, idat, palette, alpha = 8, b'', b'', b''
    while pos < len(data):
        length, kind = struct.unpack('>I4s', data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        if kind == b'IHDR':
            width, height, bits, colour = struct.unpack('>IIBB', body[:10])
        elif kind == b'PLTE':
            palette = body
        elif kind == b'tRNS':
            alpha = body
        elif kind == b'IDAT':
            idat += body
        pos += length + 12
    assert bits == 8 and colour in (2, 3, 6), (bits, colour)
    bpp = {2: 3, 3: 1, 6: 4}[colour]
    raw = zlib.decompress(idat)
    stride = width * bpp
    rows, prev = [], bytes(stride)
    for y in range(height):
        kind = raw[y * (stride + 1)]
        line = bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        for i in range(stride):
            a = line[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            if kind == 1:
                line[i] = (line[i] + a) & 255
            elif kind == 2:
                line[i] = (line[i] + b) & 255
            elif kind == 3:
                line[i] = (line[i] + (a + b) // 2) & 255
            elif kind == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        prev = bytes(line)
        if colour == 6:
            rows.append([tuple(line[x * 4:x * 4 + 4]) for x in range(width)])
        elif colour == 2:
            rows.append([tuple(line[x * 3:x * 3 + 3]) + (255,) for x in range(width)])
        else:
            rows.append([tuple(palette[v * 3:v * 3 + 3]) + (alpha[v] if v < len(alpha) else 255,) for v in line])
    return width, rows


def state_frame(path, wanted):
    """The first frame of one icon state as 32 rows of RGBA tuples."""
    (w, h), states = dmi_states(path)
    width, rows = dmi_pixels(path)
    index = 0
    for name, meta in states:
        if name == wanted:
            x, y = (index % (width // w)) * w, (index // (width // w)) * h
            return [row[x:x + w] for row in rows[y:y + h]]
        index += int(re.search(r'dirs = (\d+)', meta)[1]) * int(re.search(r'frames = (\d+)', meta)[1])
    raise AssertionError(wanted)


def style_block():
    source = read('code/datums/hud.dm')
    start = source.index('/datum/hud/human/consolestyle')
    return source[start:source.index('/datum/hud/human/litewebstyle')]


def parse_axis(text, horizontal):
    """hud_parse_axis(): -> (anchor, pixel offset of the tile's lower-left)."""
    px = 0
    if ':' in text:
        text, _, tail = text.partition(':')
        px = float(tail)
    low, high = ('WEST', 'EAST') if horizontal else ('SOUTH', 'NORTH')
    if text.startswith(low):
        anchor, base, shift = low, 0, text[len(low):]
    elif text.startswith(high):
        anchor, base, shift = high, -32, text[len(high):]
    elif text.startswith('CENTER'):
        anchor, base, shift = 'CENTER', -16, text[6:]
    else:
        raise AssertionError('no edge named in ' + text)
    if shift:
        base += float(shift.replace('+', '')) * 32
    return anchor, base + px


def origin(anchor, size):
    return size if anchor in ('EAST', 'NORTH') else size / 2 if anchor == 'CENTER' else 0


def default_tiles():
    """name -> (x anchor, x offset, y anchor, y offset)"""
    block = style_block()
    tiles = {}
    body = block[block.index('HUDneed = list('):]
    for name, loc in re.findall(r'^\t\t"([^"]+)"\s*=\s*list\((?:"type" = [^,]+,\s*)?"loc" = "([^"]+)"', body, re.M):
        x, y = loc.split(',')
        tiles[name] = parse_axis(x, True) + parse_axis(y, False)
    return tiles


def rects(tiles, view_w, view_h=480, scale=1):
    out = {}
    for name, (ax, ox, ay, oy) in tiles.items():
        w, h = SIZES.get(name, (32, 32))
        out[name] = (origin(ax, view_w) + ox * scale, origin(ay, view_h) + oy * scale, w * scale, h * scale)
    return out


def overlaps(a, b):
    return a[0] < b[0] + b[2] - 0.5 and b[0] < a[0] + a[2] - 0.5 and a[1] < b[1] + b[3] - 0.5 and b[1] < a[1] + a[3] - 0.5


def collisions(placed):
    names = sorted(placed)
    bad = []
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            if any(a in group and b in group for group in SHARED):
                continue
            if overlaps(placed[a], placed[b]):
                bad.append((a, b))
    return bad


class ConsoleStyleIcons(unittest.TestCase):
    def test_same_states_as_1713style(self):
        size, old = dmi_states(SCREEN / '1713Style.dmi')
        new_size, new = dmi_states(SCREEN / 'ConsoleStyle.dmi')
        self.assertEqual(size, new_size)
        # Names, order, directions, frame counts and delays all carry over.
        self.assertEqual(old, new)

    def test_mood_faces_keep_their_own_colours(self):
        # The yellow face has dull shading pixels; redrawing them as cream line
        # art left white dots around the eyes, mouth and jaw.
        for level in range(1, 6):
            old = state_frame(SCREEN / '1713Style.dmi', f'mood{level}')
            new = state_frame(SCREEN / 'ConsoleStyle.dmi', f'mood{level}')
            face = 0
            for y in range(4, 28):
                for x in range(4, 28):
                    pixel = new[y][x]
                    if pixel[3] == 255 and max(pixel[:3]) > 90:
                        self.assertEqual(pixel, old[y][x], (level, x, y))
                        face += 1
            self.assertGreater(face, 200, level)

    def test_doll_and_zone_copies_keep_their_states(self):
        for source, copy in (('healthdoll.dmi', 'healthdoll_console.dmi'), ('zone_sel.dmi', 'zone_sel_console.dmi')):
            self.assertEqual(dmi_states(SCREEN / source), dmi_states(SCREEN / copy), copy)

    def test_needs_bars_cover_every_length(self):
        size, states = dmi_states(SCREEN / 'needs.dmi')
        self.assertEqual(size, (64, 32))
        names = {name for name, _ in states}
        bar = int(re.search(r'#define NEEDS_BAR_PX (\d+)', read('code/_onclick/hud/base_screen_objects.dm'))[1])
        tool = int(re.search(r'^NEEDS_BAR_PX = (\d+)', read('tools/hud-skin/build_console_style.py'), re.M)[1])
        self.assertEqual(bar, tool)
        self.assertIn('needs', names)
        for key in ('food', 'water', 'stamina'):
            for px in range(bar + 1):
                self.assertIn(f'{key}{px}', names)


class ConsoleStyleWiring(unittest.TestCase):
    def test_style_is_the_default_and_the_old_one_stays_selectable(self):
        styles = read('code/modules/client/ui_style.dm')
        listed = re.findall(r'^\t"(\w+)",', styles[:styles.index(')')], re.M)
        self.assertEqual(listed[:2], ['ConsoleStyle', '1713Style'])
        prefs = read('code/modules/client/preferencesSQLite/preferences.dm')
        self.assertIn('var/UI_style = "ConsoleStyle"', prefs)
        self.assertIn("var/UI_file = 'icons/mob/screen/ConsoleStyle.dmi'", prefs)
        # Saving skips values equal to the default and loading resets absent ones,
        # which is what moves players who never picked a style onto the new default.
        save = read('code/modules/client/preferencesSQLite/preferences_saving&loading&del.dm')
        self.assertIn('if (vars[key] == initial(vars[key]))\n\t\t\tcontinue', save)
        self.assertIn('vars[varname] = initial(vars[varname])', save)
        # A style missing from the registry still falls back to one that exists.
        self.assertIn('H.defaultHUD = "1713Style"', read('code/game/mob/living/carbon/human/human_hud.dm'))
        block = style_block()
        self.assertIn('name = "ConsoleStyle"', block)
        self.assertIn('anchored_layout = TRUE', block)

    def test_every_species_control_has_a_place(self):
        species = read('code/game/mob/living/carbon/human/species/species_hud.dm')
        process = re.search(r'var/list/ProcessHUD = list\((.*?)\)\n', species, re.S)[1]
        wanted = set(re.findall(r'(?<!\*)"([^"]+)"', re.sub(r'/\*.*?\*/', '', process)))
        self.assertIn('needs', wanted)
        tiles = default_tiles()
        # The bars replace the single nutrition icon; toxin and fire have no tile in any style.
        self.assertEqual(wanted - set(tiles), {'nutrition', 'toxin', 'fire', 'toggle gun mode', 'allow movement',
                                               'allow item use', 'allow radio use'} - set(tiles))
        self.assertNotIn('nutrition', tiles)
        gear = re.search(r'var/list/gear = list\((.*?)\n\t\t\)', species, re.S)[1]
        for slot in re.findall(r'"(\w+)" =', gear):
            self.assertIn(slot, tiles, slot)

    def test_layout_uses_the_named_edges(self):
        layout = read('code/_onclick/hud/hud_layout.dm')
        self.assertIn('var/anchored = style && style.anchored_layout', layout)
        self.assertRegex(layout, r'if \(!anchored\)\n\t+D = hud_infer_anchor\(D, design_w, design_h\)')
        self.assertIn('if (anchored && !hud_flow_collides(flow, scaled, g))\n\t\tflow = list()\n\tif (flow.len)', layout)

    def test_needs_bars_read_food_water_and_stamina(self):
        source = read('code/_onclick/hud/base_screen_objects.dm')
        body = source[source.index('/obj/screen/needs/update_icon()'):source.index('/obj/screen/needs/Click()')]
        self.assertIn('hud_need_bar_px(H.nutrition, H.max_nutrition)', body)
        self.assertIn('hud_need_bar_px(H.water, H.max_water)', body)
        self.assertIn('stamina_pair()', body)
        self.assertIn('if (now == shown)', body)


class ConsoleStyleLayout(unittest.TestCase):
    def setUp(self):
        self.tiles = {k: v for k, v in default_tiles().items() if k not in GUN}

    def test_groups_sit_on_their_edges(self):
        t = self.tiles
        for name in ('shoulder', 'back', 'belt', 'r_hand', 'l_hand', 'storage1', 'storage2', 'health', 'needs', 'mood'):
            self.assertEqual(t[name][0], 'CENTER', name)
        for name in ('intent', 'm_intent', 'tactic', 'mode', 'secondary attack', 'damage zone', 'fixeye'):
            self.assertEqual(t[name][0], 'EAST', name)
        for name in ('toggle inventory', 'shoes', 'head', 'i_clothing', 'o_clothing', 'gloves'):
            self.assertEqual(t[name][0], 'WEST', name)
        self.assertTrue(all(v[2] == 'SOUTH' for v in t.values()))
        # The console is centred: seven slots, 112px either side of the middle.
        xs = sorted(t[n][1] for n in ('shoulder', 'back', 'belt', 'r_hand', 'l_hand', 'storage1', 'storage2'))
        self.assertEqual(xs, [-112, -80, -48, -16, 16, 48, 80])

    def test_nothing_overlaps_at_100_percent(self):
        for columns in (21, 15):
            placed = rects(self.tiles, columns * 32)
            self.assertEqual(collisions(placed), [], columns)
            for name, (x, y, w, h) in placed.items():
                self.assertTrue(0 <= x and x + w <= columns * 32 and 0 <= y, (columns, name))

    def test_gun_buttons_clear_the_action_corner(self):
        tiles = default_tiles()
        placed = rects({k: v for k, v in tiles.items() if k in GUN or k in ('tactic', 'mode', 'secondary attack', 'random damage zone', 'fixeye')}, 480)
        self.assertEqual(collisions(placed), [])

    def test_groups_stay_together_while_they_fit(self):
        # Widescreen at 125% still fits side by side; the square view does not
        # and falls back to the wrapping reflow.
        self.assertEqual(collisions(rects(self.tiles, 21 * 32, scale=1.25)), [])
        self.assertNotEqual(collisions(rects(self.tiles, 15 * 32, scale=1.25)), [])

    def test_storage_window_opens_above_the_console(self):
        block = style_block()
        for key in ('Yspace', 'Yslot'):
            row = int(re.search(rf'"{key}" = (\d+)', block)[1])
            # hud_place_window(): the window's lower edge is (row - 1) * 32 + 16.
            self.assertGreaterEqual((row - 1) * 32 + 16, 66)


if __name__ == '__main__':
    unittest.main()
