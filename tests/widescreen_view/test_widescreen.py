"""Widescreen game view: the 21x15 default, the square fallback and the HUD
anchoring that keeps default tiles on the edges of a wider view.

Offline checks. The anchoring test mirrors hud_infer_anchor()/hud_anchor_origin()
from hud_layout.dm and asserts where default tiles land on a 21x15 view.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8', errors='replace')


def origin(anchor, size):
    return size if anchor in ('EAST', 'NORTH') else size / 2 if anchor == 'CENTER' else 0


def infer(x, y, w, h):
    cx, cy = x + 16, y + 16
    ax = 'WEST' if cx < w / 3 else 'EAST' if cx > w * 2 / 3 else 'CENTER'
    ay = 'SOUTH' if cy < h / 3 else 'NORTH' if cy > h * 2 / 3 else 'CENTER'
    return ax, x - origin(ax, w), ay, y - origin(ay, h)


def place(tile_x, view_w, design_w=15 * 32):
    """Pixel x of a default tile at column tile_x (1-based) on a view_w-wide view."""
    ax, ox, _, _ = infer((tile_x - 1) * 32, 0, design_w, 15 * 32)
    return origin(ax, view_w) + ox


class WidescreenDefaults(unittest.TestCase):
    def test_view_sizes(self):
        game = read('code/__defines/__game.dm')
        self.assertIn('#define WORLD_VIEW "21x15"', game)
        self.assertIn('#define SQUARE_VIEW "15x15"', game)
        self.assertIn('#define HUD_DESIGN_VIEW "15x15"', game)
        # world.view stays a numeric radius for range checks.
        self.assertRegex(read('code/world.dm'), r'\n\tview = 7\n')

    def test_square_preference_is_opt_in(self):
        prefs = read('code/modules/client/preferencesSQLite/preference_setup/global/setting_datums.dm')
        block = prefs[prefs.index('/datum/client_preference/square_view'):]
        self.assertIn('enabled_by_default = FALSE', block[:400])
        self.assertIn('apply_default_view()', block)
        view = read('code/game/mob/mob_view.dm')
        self.assertIn('/datum/client_preference/square_view) ? SQUARE_VIEW : WORLD_VIEW', view)

    def test_login_sets_the_view_before_the_hud(self):
        login = read('code/game/mob/login.dm')
        self.assertLess(login.index('client.view = client.default_view()'), login.index('hud_used = new /datum/hud(src)'))

    def test_no_numeric_maths_on_text_view(self):
        # client.view is now "21x15"; adding to it or doubling it is a runtime error.
        bad = re.compile(r'client\.view\s*[+*]|client\.view\s*\+=|get_dist\([^)]*\)\s*>\s*client\.view\b|view = world\.view')
        for path in ('code/_onclick/hud/movable_screen_objects.dm',
                     'code/game/mob/living/carbon/human/human_helpers.dm',
                     'code/game/mob/living/carbon/human/human.dm',
                     'code/modules/nano/interaction/default.dm',
                     'code/modules/1713/football.dm'):
            self.assertIsNone(bad.search(read(path)), path)


class WidescreenHud(unittest.TestCase):
    def test_defaults_anchor_on_the_design_grid(self):
        layout = read('code/_onclick/hud/hud_layout.dm')
        self.assertIn('var/list/design = getviewsize(HUD_DESIGN_VIEW)', layout)
        self.assertIn('D = hud_infer_anchor(D, design_w, design_h)', layout)

    def test_default_tiles_follow_the_edges(self):
        wide = 21 * 32
        # Right-hand column (1713Style "15,y") ends at the right edge.
        self.assertEqual(place(15, wide), wide - 32)
        # Inventory column stays at the left edge.
        self.assertEqual(place(1, wide), 0)
        # Hands (columns 7-8) move to the middle with the view's centre.
        self.assertEqual(place(8, wide) - place(8, 15 * 32), (wide - 15 * 32) / 2)
        # On the square view nothing moves.
        for col in range(1, 16):
            self.assertEqual(place(col, 15 * 32), (col - 1) * 32)

    def test_fullscreen_overlays_are_centred_and_scaled(self):
        layout = read('code/_onclick/hud/hud_layout.dm')
        body = layout[layout.index('/mob/living/human/proc/fit_fullscreen_overlays'):]
        body = body[:body.index('\n/mob/proc/')]
        for name in ('"damageoverlay"', '"fov"', '"gasmask"'):
            self.assertIn(name, body)
        self.assertIn('S.screen_loc = "CENTER-7,CENTER-7"', body)
        self.assertIn('max(V[1], V[2]) / 15', body)
        self.assertIn('fit_fullscreen_overlays(V)', layout)
        lobby = read('code/game/mob/new_player/lobby_image.dm')
        self.assertIn('screen_loc = "CENTER-7,CENTER-7"', lobby)



# Frozen before-change comparison order for the vehicle image filter.
VEHICLE_ROOF_ICONS = (
    'icons/obj/vehicles/vehicleparts.dmi',
    'icons/obj/vehicles/lightplane.dmi',
    'icons/obj/vehicles/vehicles96x96.dmi',
    'icons/obj/vehicles/vehicles128x128.dmi',
    'icons/obj/vehicles/apcparts.dmi',
    'icons/obj/vehicles/tankparts.dmi',
    'icons/obj/vehicles/tankparts96x96.dmi',
    'icons/obj/vehicles/apcparts96x96.dmi',
    'icons/obj/vehicles/tankparts96x96_damaged.dmi',
    'icons/obj/vehicles/apcparts96x96_damaged.dmi',
)


def vehicle_roof_filter(source):
    """Extract the tested comparisons and guard from production source."""
    body = source.split('/mob/living/human/proc/process_vehicle_roofs()', 1)[1]
    body = body.split('/mob/living/human/proc/process_static_roofs()', 1)[0]
    image_loop = body.split('for (var/image/tmpimg in client.images)', 1)[1]
    image_loop = image_loop.split('for (var/obj/structure/vehicleparts/frame/FRL in loc)', 1)[0]
    match = re.search(r'\bif\s*\(([^\n]*)\)', image_loop)
    if not match:
        raise AssertionError('vehicle roof image comparison missing')
    condition = match.group(1)
    terms = re.findall(r"(tmpimg\.icon|image_icon)\s*==\s*'([^']+)'", condition)
    if not terms or ' || '.join(f"{name} == '{icon}'" for name, icon in terms) != ' '.join(condition.split()):
        raise AssertionError('unsupported vehicle roof image comparison')
    cached = 'var/image_icon = tmpimg.icon' in image_loop
    if cached and any(name != 'image_icon' for name, _ in terms):
        raise AssertionError('cached comparison uses unexpected source')
    if not cached and any(name != 'tmpimg.icon' for name, _ in terms):
        raise AssertionError('uncached comparison uses unexpected source')
    if 'if(get_dist(tmpimg, view_loc) < view_dist)' not in image_loop:
        raise AssertionError('vehicle roof distance guard changed')
    if 'client.images.Remove(tmpimg)' not in image_loop:
        raise AssertionError('vehicle roof image removal changed')
    return tuple(icon for _, icon in terms), cached


def model_vehicle_roof_filter(icon, distance, view_dist, choices, cached):
    """Model short-circuit order and removal; this is not native BYOND."""
    comparisons = []
    field_reads = int(cached)
    for choice in choices:
        if not cached:
            field_reads += 1
        comparisons.append(choice)
        if icon == choice:
            return distance < view_dist, comparisons, field_reads
    return False, comparisons, field_reads


class VehicleRoofImageFilter(unittest.TestCase):
    def setUp(self):
        self.choices, self.cached = vehicle_roof_filter(
            read('code/game/mob/living/carbon/human/human_helpers.dm'))

    def test_original_order_and_removal_decisions(self):
        self.assertEqual(self.choices, VEHICLE_ROOF_ICONS)
        for icon in (*VEHICLE_ROOF_ICONS, 'icons/unrelated.dmi', None):
            for distance in (4, 5, 6):
                with self.subTest(icon=icon, distance=distance):
                    original = model_vehicle_roof_filter(icon, distance, 5, VEHICLE_ROOF_ICONS, False)
                    actual = model_vehicle_roof_filter(icon, distance, 5, self.choices, self.cached)
                    self.assertEqual(actual[:2], original[:2])
        # A final-match image exercises every comparison in its original order.
        before = model_vehicle_roof_filter(VEHICLE_ROOF_ICONS[-1], 4, 5, VEHICLE_ROOF_ICONS, False)
        after = model_vehicle_roof_filter(VEHICLE_ROOF_ICONS[-1], 4, 5, self.choices, self.cached)
        self.assertEqual(before[2], 10)
        self.assertEqual(after[2], 1 if self.cached else 10)

    def test_missing_icon_negative_control_is_detected(self):
        mutant = self.choices[:-1]
        original = model_vehicle_roof_filter(VEHICLE_ROOF_ICONS[-1], 4, 5, VEHICLE_ROOF_ICONS, False)
        changed = model_vehicle_roof_filter(VEHICLE_ROOF_ICONS[-1], 4, 5, mutant, self.cached)
        self.assertNotEqual(changed[:2], original[:2])


if __name__ == '__main__':
    unittest.main()
