"""Offline wiring checks for the customizable HUD layout.

run.py is the native fixture for the helper procs and the text save; it is
manual and not imported here except for its inert prepare step.
"""
import importlib.util
from pathlib import Path
import re
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
LAYOUT = 'code/_onclick/hud/hud_layout.dm'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8', errors='replace')


def proc_body(source, header):
    start = source.index(header)
    rest = source[source.index('\n', start) + 1:]
    end = re.search(r'^\S', rest, re.M)
    return rest[:end.start()] if end else rest


class HudLayoutWiring(unittest.TestCase):
    def test_preferences_save_scale_and_layout(self):
        save = read('code/modules/client/preferencesSQLite/preferences_saving&loading&del.dm')
        line = re.search(r'var/list/vars_to_save = list\(([^\n]*)\)', save)[1]
        self.assertIn('"hud_scale"', line)
        self.assertIn('"hud_layout"', line)
        self.assertIn('"hover_text_scale"', line)

    def test_included_after_base_hud(self):
        dme = read('civ13.dme').splitlines()
        base = dme.index('#include "code\\_onclick\\hud\\hud.dm"')
        self.assertEqual(dme[base + 1], '#include "code\\_onclick\\hud\\hud_layout.dm"')

    def test_layout_applies_when_hud_is_built(self):
        body = proc_body(read('code/game/mob/living/carbon/human/human_hud.dm'), '/mob/living/human/create_HUD()')
        self.assertLess(body.index('recolor_HUD('), body.index('apply_hud_layout()'))
        sync = proc_body(read('code/game/mob/living/carbon/human/human_hud.dm'),
                         '/mob/living/human/proc/sync_inventory_screen_locs()')
        self.assertIn('hud_scale_item(I, HUDinv)', sync)

    def test_items_follow_slot_scale_and_reset_when_dropped(self):
        find = proc_body(read('code/game/mob/living/carbon/human/update_icons.dm'),
                         '/mob/living/human/proc/find_inv_position(var/slot_id)')
        self.assertIn('hud_scale_item(get_equipped_item(slot_id), HUDinv)', find)
        inventory = read('code/game/mob/inventory.dm')
        for header in ('/mob/proc/remove_from_mob(var/obj/O)',):
            self.assertIn('hud_unscale_item(I)', proc_body(inventory, header))
        self.assertEqual(inventory.count('hud_unscale_item(I)'), 2)

    def test_mouse_hooks_fall_through_outside_edit_mode(self):
        source = read(LAYOUT)
        for hook in ('MouseDown', 'MouseDrop', 'Click', 'MouseWheel'):
            body = proc_body(source, f'/client/{hook}(')
            self.assertIn('hud_edit_human()', body, hook)
            self.assertTrue(body.rstrip().endswith('return ..()'), hook)

    def test_tiles_are_kept_on_screen(self):
        body = proc_body(read(LAYOUT), '/mob/living/human/proc/apply_hud_layout()')
        self.assertIn('getviewsize(client.view)', body)
        self.assertIn('clamp(x0 + D[2] * g, 0, max(0, view_w - edge_w)) - x0', body)
        self.assertIn('clamp(y0 + D[4] * g, 0, max(0, view_h - edge_h)) - y0', body)

    def test_tiles_scale_by_their_real_size(self):
        source = read(LAYOUT)
        body = proc_body(source, '/mob/living/human/proc/apply_hud_layout()')
        # The body part selector is 32x64; a 32x32 matrix shifted it up and hid its head.
        self.assertIn('S.transform = hud_scale_matrix(g * size, px[1], px[2])', body)
        self.assertIn('hud_pixel_scale(S, g * size)', body)
        sharp = proc_body(source, '/proc/hud_pixel_scale(atom/A, k)')
        self.assertIn('if (k > 1)', sharp)
        self.assertIn('&= ~PIXEL_SCALE', sharp)
        self.assertLess(body.index('S.transform ='), body.index('S.hud_rescaled(g * size)'))
        self.assertIn('foot[1], foot[2]))', body)
        # The swap button's right half is an offset overlay that must follow the scale.
        swap = proc_body(source, '/obj/screen/swap/hud_rescaled(k)')
        self.assertIn('pixel_x = 32 * k', swap)
        self.assertIn('list(64, 32)', proc_body(source, '/obj/screen/swap/hud_footprint()'))
        self.assertIn('pixel_x = 32)', read('code/_onclick/hud/base_screen_objects.dm'))

    def test_hover_label_has_its_own_size(self):
        hover = read('code/_onclick/hud/hover_name.dm')
        px = proc_body(hover, '/obj/screen/hover_name/proc/hover_label_px()')
        self.assertIn('C.prefs?.hover_text_scale', px)
        self.assertNotIn('hud_scale', px)
        self.assertIn('clamp(round(11 * g), 6, 22)', px)
        verb = proc_body(read(LAYOUT), '/client/verb/set_hover_text_size()')
        self.assertIn('set name = "Hover Text Size"', verb)
        self.assertIn('set category = "OOC"', verb)
        self.assertIn('prefs.hover_text_scale = hud_scale_choices[choice]', verb)
        self.assertIn('prefs.save_preferences()', verb)
        show = proc_body(hover, '/obj/screen/hover_name/proc/show_label(text)')
        self.assertIn('px == hover_font_px', show)
        self.assertIn('hover_name_span(text, px)', show)
        self.assertIn('font-size:[px]px;', hover)
        # The text is centred in a maptext box that is exactly the panel fill.
        self.assertIn('text-align:center;vertical-align:middle;', hover)
        backdrop = proc_body(hover, '/obj/screen/hover_name/proc/update_backdrop()')
        self.assertIn('hover_name_rect(maptext_width, maptext_height, 0, 0,', backdrop)
        self.assertIn('hover_name_rect(maptext_width + 2, maptext_height + 2, -1, -1,', backdrop)
        # No width argument: given one, the client answers with the box width.
        self.assertIn('C.MeasureText(hover_name_span(text, px))\n', hover)

    def test_large_scales_reflow_only_default_tiles(self):
        body = proc_body(read(LAYOUT), '/mob/living/human/proc/apply_hud_layout()')
        self.assertIn('D = hud_infer_anchor(D, design_w, design_h)', body)
        self.assertIn('if (g > 1 && size == 1 && (findtext(S.hud_layout_key, "need:") == 1 || findtext(S.hud_layout_key, "inv:") == 1))', body)
        self.assertLess(body.index('if (!custom)'), body.index('flow += list('))
        self.assertIn('if (flow.len)\n\t\thud_reflow(flow, g, view_w, view_h)', body)
        self.assertLess(body.index('hud_reflow('), body.index('sync_inventory_screen_locs()'))

    def test_reflow_procs_are_in_the_native_fixture_half(self):
        helpers = read(LAYOUT).split('////////////////////////// applying the layout')[0]
        for proc in ('hud_infer_anchor(', 'hud_flow_groups(', 'hud_flow_place(', 'hud_reflow('):
            self.assertIn('/proc/' + proc, helpers)
        self.assertIn('check_reflow(g)', read(ROOT / 'tests/hud_layout/fixture.dm'))

    def test_storage_window_follows_the_layout(self):
        storage = read('code/game/objects/items/weapons/storage/storage.dm')
        orient = proc_body(storage, '/obj/item/weapon/storage/proc/orient2hud(mob/user as mob)')
        self.assertLess(orient.index('hud_place_window(user, Xcor, Ycor'), orient.index('space_orient_objs('))
        self.assertLess(orient.index('hud_place_window(user, Xslot, Yslot'), orient.index('slot_orient_objs('))
        for header in ('/obj/item/weapon/storage/proc/slot_orient_objs(', '/obj/item/weapon/storage/proc/space_orient_objs(',
                '/obj/item/weapon/storage/proc/orient_objs('):
            start = storage.index(header)
            self.assertIn('hud_shift_x', storage[start:start + 400], header)
        # The slot grid's bottom edge follows the window instead of a fixed row.
        self.assertIn('boxes.screen_loc = "[Xcord]:16,[Ycord]:16 to', storage)
        self.assertIn('"hud_shift_x", "hud_shift_y"', storage)
        bags = read('code/game/objects/items/weapons/storage/bags.dm')
        self.assertLess(bags.index('hud_place_window(user, 4, 2'), bags.index('slot_orient_objs(row_num, col_count, numbered_contents)'))
        layout = read(LAYOUT)
        apply = proc_body(layout, '/mob/living/human/proc/apply_hud_layout()')
        self.assertIn('open_storage.orient2hud(src)', apply)
        target = proc_body(layout, '/mob/living/human/proc/hud_layout_target(object)')
        self.assertIn('return hud_storage_tile()', target)
        self.assertIn('/proc/hud_storage_shift_for(', layout.split('////////////////////////// applying the layout')[0])

    def test_vehicle_controls_and_action_bar_are_editable(self):
        source = read(LAYOUT)
        elements = proc_body(source, '/mob/living/human/proc/hud_layout_elements()')
        self.assertIn('hud_used.vehicle_hud', elements)
        self.assertIn('"veh:[S.type]"', elements)
        self.assertIn('H.apply_hud_layout()', proc_body(read('code/_onclick/hud/hud.dm'),
                                                        '/datum/hud/proc/add_vehicle_hud(var/mob/living/human/H)'))
        override = proc_body(source, '/mob/living/human/update_action_buttons()')
        self.assertLess(override.index('..()'), override.index('apply_action_bar_layout()'))
        bar = proc_body(source, '/mob/living/human/proc/apply_action_bar_layout()')
        self.assertIn('if (!B || B.moved)', bar)
        self.assertIn('B.hud_rel_x = (Dn[2] - D1[2]) * k', bar)
        move = proc_body(source, '/mob/living/human/proc/hud_move_tile(obj/screen/S, list/mouse)')
        self.assertIn('- S.hud_rel_x', move)
        self.assertIn('update_action_buttons()', proc_body(source, '/mob/living/human/proc/end_hud_edit()'))

    def test_ranges_and_hover_label_are_not_editable(self):
        source = read(LAYOUT)
        self.assertIn('findtext(loc, " to ")', source)
        self.assertIn('if (name == "hover name")', source)

    def test_fixture_prepares_without_native_launch(self):
        spec = importlib.util.spec_from_file_location('hud_layout_run', ROOT / 'tests/hud_layout/run.py')
        run = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(run)
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / 'stage'
            run.prepare(out)
            production = (out / 'production.dm').read_text(encoding='utf-8')
            self.assertIn('/proc/hud_parse_screen_loc(loc)', production)
            self.assertNotIn('/client/MouseDrop', production)
            self.assertNotIn('\n/client\n', production)
            self.assertIn('/datum/preferences/proc/save_preferences', production)


if __name__ == '__main__':
    unittest.main()
