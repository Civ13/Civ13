"""Offline checks for player paintings (code/modules/paintings/)."""
from pathlib import Path
import re
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
MOD = ROOT / 'code/modules/paintings'


def states(dmi):
    text = Image.open(ROOT / dmi).info['Description']
    return dict(re.findall(r'state = "([^"]+)"\n\tdirs = (\d)', text))


def source():
    return '\n'.join(p.read_text(encoding='utf-8') for p in sorted(MOD.glob('*.dm')))


class PaintingsTest(unittest.TestCase):
    def test_files_are_in_the_dme_and_the_old_port_is_gone(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        for name in ('painting_codec', 'paintings', 'painting_editor', 'drawings', 'painting_admin'):
            self.assertIn(f'#include "code\\modules\\paintings\\{name}.dm"', dme)
        self.assertFalse((ROOT / 'code/game/objects/items/paper/artstuff.dm').exists())

    def test_every_icon_state_exists(self):
        obj = states('icons/obj/paintings.dmi')
        text = source()
        used = set(re.findall(r'icon_state = "([^"]+)"', text)) | set(re.findall(r'frame_state = "([^"]+)"', text))
        used |= {'easel_canvas'}
        gallery = {'gallery', 'gallery_wide'}
        self.assertTrue(gallery <= used)
        used -= gallery
        for state in used:
            self.assertIn(state, obj)
        self.assertEqual(states('icons/obj/paintings_gallery.dmi'), {'gallery': '1', 'gallery_wide': '1'})
        sheet = Image.open(ROOT / 'icons/obj/paintings_gallery.dmi').convert('RGBA')
        self.assertEqual(sheet.size[1] % 64, 0)
        for i, (left, top, w, h) in enumerate(((4, 4, 56, 56), (4, 36, 56, 24))):
            tile = sheet.crop((i * 64, 0, i * 64 + 64, 64))
            for x in range(left, left + w):
                for y in range(top, top + h):
                    self.assertEqual(tile.getpixel((x, y))[3], 0)
            self.assertGreater(tile.getpixel((left - 1, top + 3))[3], 0)
        self.assertEqual(states('icons/mob/paintings.dmi'), {'locket': '4'})

    def test_art_windows_match_the_sprites(self):
        # canvas windows are primed #e9dfc8 and frame windows are see-through.
        sheet = Image.open(ROOT / 'icons/obj/paintings.dmi').convert('RGBA')
        order = re.findall(r'state = "([^"]+)"', sheet.info.get('Description', '') or Image.open(ROOT / 'icons/obj/paintings.dmi').info['Description'])
        def tile(state):
            i = order.index(state)
            return sheet.crop((i * 32, 0, i * 32 + 32, 32))
        for canvas, frame, left, top, size in (('canvas_miniature', 'frame_miniature', 8, 8, 16), ('canvas_table', 'frame_table', 8, 6, 16)):
            c, f = tile(canvas), tile(frame)
            for x in range(left, left + size):
                for y in range(top, top + size):
                    self.assertEqual(c.getpixel((x, y))[:3], (0xe9, 0xdf, 0xc8), canvas)
                    self.assertEqual(f.getpixel((x, y))[3], 0, frame)
        text = (MOD / 'paintings.dm').read_text(encoding='utf-8')
        left = int(re.search(r'#define PAINT_LOCKET_LEFT (\d+)', text)[1])
        top = int(re.search(r'#define PAINT_LOCKET_TOP (\d+)', text)[1])
        locket = Image.open(ROOT / 'icons/mob/paintings.dmi').convert('RGBA').crop((0, 0, 32, 32))  # SOUTH
        for x in range(left, left + 8):
            for y in range(top, top + 8):
                self.assertEqual(locket.getpixel((x, y))[3], 0)
        self.assertGreater(locket.getpixel((left - 1, top + 3))[3], 0)

    def test_recipes_and_mortar(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        for path in ('/obj/structure/easel', '/obj/item/canvas/miniature', '/obj/item/canvas/table', '/obj/item/canvas'):
            self.assertRegex(recipes, rf'RECIPE: /material/wood/,[^,]+,{re.escape(path)},[^\n]*,paintings,0,')
        herbalism = (ROOT / 'code/modules/1713/herbalism.dm').read_text(encoding='utf-8')
        self.assertIn('if (mortar_pigment_result(W))', herbalism)

    def test_server_checks_uploads_and_logs(self):
        text = source()
        self.assertIn('painting_allowed_colours(user, src)', text)
        self.assertIn('painting_unpack(packed, canvas_w * canvas_h)', text)
        self.assertIn('sanitizeSafe(new_title, PAINT_TITLE_LENGTH)', text)
        self.assertIn('log_game("[key_name(user)] finished the', text)
        self.assertIn('log_admin("[key_name(user)] removed the painting', text)
        verbs = (ROOT / 'code/modules/admin/admin_verbs.dm').read_text(encoding='utf-8')
        self.assertIn('/datum/admins/proc/player_art,', verbs)

    def test_generated_icons_are_not_saved(self):
        text = (MOD / 'paintings.dm').read_text(encoding='utf-8')
        for owner in ('/obj/item/canvas/persistence_runtime_var', '/obj/structure/easel/persistence_runtime_var', '/obj/structure/painting_frame/persistence_runtime_var'):
            block = text[text.index(owner):].split('\n\n')[0]
            self.assertIn('"overlays"', block)

    def test_drawings_follow_paper_and_books(self):
        hooks = {
            'code/modules/paperwork/view.dm': 'drawings_html(src, reader)',
            'code/modules/paperwork/copy.dm': 'result.copy_drawings_from(snapshot["paper"])',
            'code/modules/1713/book.dm': 'drawing_set_list(NB, drawings_copy(NC.drawings))',
            'code/modules/research_tree/book_pages.dm': 'take_page_drawings(P)',
        }
        for path, hook in hooks.items():
            self.assertIn(hook, (ROOT / path).read_text(encoding='utf-8'), path)
        self.assertIn('show_drawings(user)', (ROOT / 'code/modules/1713/book.dm').read_text(encoding='utf-8'))


class FramedPlansTest(unittest.TestCase):
    def setUp(self):
        self.painting = (MOD / 'paintings.dm').read_text(encoding='utf-8')
        self.codec = (MOD / 'painting_codec.dm').read_text(encoding='utf-8')
        self.board = (ROOT / 'code/game/objects/structures/noticeboard.dm').read_text(encoding='utf-8')

    def test_mount_uses_one_actual_held_original_after_wall_and_occupancy_checks(self):
        mount = self.painting.split('/proc/wall_frame_mount(', 1)[1].split('/proc/painting_is_wall_turf(', 1)[0]
        boundaries = [
            'original.loc != user', '!user.item_is_in_hands(original)', '!painting_is_wall(wall)',
            'get_step(T, dir) != W', '!wall.Adjacent(user)', 'painting_frame_occupies(spot, dir)',
            'B.banner_mount_dir == dir', 'B.board_mount_dir == dir', 'new(T)',
            'if (!user.transfer_held_item_to(original, F))', 'F.place(V)',
        ]
        positions = [mount.index(mark) for mark in boundaries]
        self.assertEqual(positions, sorted(positions))
        self.assertNotIn('original.forceMove(', mount)
        self.assertNotIn('qdel(original)', mount)
        self.assertIn('F.dir == NORTH && C && C.wide_hang', self.painting)
        self.assertIn('if (painting_frame_occupies(T, facing))', self.board)

    def test_frame_rebuilds_view_and_drop_preserves_original(self):
        frame = self.painting.split('/obj/structure/painting_frame/after_load()', 1)[1].split('/// Lockets', 1)[0]
        self.assertIn('place()', frame)
        self.assertIn('V = P.framed_plan_diagram()', frame)
        self.assertIn('image(V.thumbnail())', frame)
        self.assertIn('holder.put_in_hands(original)', frame)
        self.assertIn('!Adjacent(holder)', frame)
        self.assertLess(frame.index('if (QDELETED(original) || original.loc == src)'), frame.index('qdel(src)'))
        self.assertIn('for (var/obj/item/O in contents)\n\t\t\tO.forceMove(T)', frame)
        self.assertIn('painting_show_full(user, C)', frame)
        self.assertLess(frame.index('painting_show_full(user, C)'), frame.index('if (!isobserver(user) && !Adjacent(user))'))
        self.assertLess(frame.index('if (!isobserver(user) && !Adjacent(user))'), frame.index('window=framed_plan'))
        self.assertIn('window=framed_plan', frame)
        self.assertNotIn('Topic(', frame)
        self.assertNotIn('onclose(', frame)
        self.assertIn('drawings_html(S, user)', frame)
        self.assertNotIn('document_classic_html(', frame)
        drawing = (MOD / 'drawings.dm').read_text(encoding='utf-8')
        self.assertIn('F.update_icon()', drawing)
        self.assertIn('painting_max_index(plain) >= palette.len', drawing)

    def test_visual_projection_reuses_canonical_readers_and_has_no_mutating_routes(self):
        diagram = self.codec.split('/datum/framed_plan_diagram/proc/html()', 1)[1]
        for value in (
            'draught_kind_row()', 'length(draught_code) > K["max"]', 'call(K["read"])(draught_code)',
            'ship_designer_layout(D)', 'sub_designer_sheet(D)', 'vehicle_designer_sheet(D)',
            'air_designer_sheet(D)', 'house_designer_sheet(D)', 'R.links(x, y)', 'train.cars',
            'station_designer_sheet(D)', 'tile_bounds()', 'html_encode(title)', 'html_encode(T[3])',
            'html_encode(T[4])', 'html_encode(note)',
        ):
            self.assertIn(value, diagram)
        self.assertNotRegex(diagram, r'byond://|href=|<script|Topic\(|draught_code\s*=')


if __name__ == '__main__':
    unittest.main()
