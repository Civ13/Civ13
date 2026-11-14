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


if __name__ == '__main__':
    unittest.main()

    def test_drawings_follow_paper_and_books(self):
        hooks = {
            'code/modules/paperwork/view.dm': 'drawings_html(src)',
            'code/modules/paperwork/copy.dm': 'result.copy_drawings_from(snapshot["paper"])',
            'code/modules/1713/book.dm': 'drawing_set_list(NB, drawings_copy(NC.drawings))',
            'code/modules/research_tree/book_pages.dm': 'take_page_drawings(P)',
        }
        for path, hook in hooks.items():
            self.assertIn(hook, (ROOT / path).read_text(encoding='utf-8'), path)
        self.assertIn('show_drawings(user)', (ROOT / 'code/modules/1713/book.dm').read_text(encoding='utf-8'))
