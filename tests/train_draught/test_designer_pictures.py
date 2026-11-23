#!/usr/bin/env python3
"""The train designer window's pictures (code/modules/1713/train_designer.dm).

Offline: every picture in train_designer_sprites() is on disk, is the one
scripts/build_train_designer_icons.py cuts from the game's DMIs, and no two
names differ only by case (Windows serves the browser's cache without case).
The tables of train_draught.dm each have their pictures, and the page keeps
the rules of a raw DM string.

    python3 tests/train_draught/test_designer_pictures.py
"""
import re
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/1713/train_designer.dm').read_text(encoding='utf-8')
DRAUGHT = (ROOT / 'code/modules/1713/train_draught.dm').read_text(encoding='utf-8')
SCRIPT = ROOT / 'scripts/build_train_designer_icons.py'


def pictures():
    block = SOURCE.split('/proc/train_designer_sprites()', 1)[1].split('\treturn table', 1)[0]
    return re.findall(r'"(\w+)" = \'(icons/train_designer/(\w+)\.png)\'', block)


def table(name):
    return DRAUGHT.split('/proc/%s()' % name, 1)[1].split('\treturn table', 1)[0]


class TrainDesignerPictures(unittest.TestCase):
    def test_every_picture_exists_and_names_are_case_safe(self):
        pairs = pictures()
        self.assertGreater(len(pairs), 0)
        names = [name for name, _path, _stem in pairs]
        self.assertEqual(len({name.lower() for name in names}), len(names))
        for name, path, stem in pairs:
            with self.subTest(picture=name):
                self.assertEqual(name, stem)
                self.assertTrue((ROOT / path).is_file(), path)
                self.assertEqual((ROOT / path).read_bytes()[:8], b'\x89PNG\r\n\x1a\n')
        on_disk = sorted(path.stem for path in (ROOT / 'icons/train_designer').glob('*.png'))
        self.assertEqual(on_disk, sorted(names))

    def test_the_script_made_them(self):
        done = subprocess.run([sys.executable, str(SCRIPT), '--check'], capture_output=True, text=True)
        self.assertEqual(done.returncode, 0, done.stdout + done.stderr)

    def test_every_table_row_has_its_picture(self):
        names = {name for name, _path, _stem in pictures()}
        for centre, side in re.findall(r'"center" = "(\w+)", "side" = "(\w+)"', table('train_draught_floors')):
            self.assertIn('deck_%s_%s' % (centre, side), names)
        for state in re.findall(r'"state" = "(\w+)"', table('train_draught_roofs')):
            self.assertIn('roof_' + state, names)
        for style in re.findall(r'"style" = "(\w+)"', table('train_draught_edges')):
            self.assertIn('edge_' + style, names)
        keys = re.findall(r'^\t\t"(\w)" = list\(', table('train_draught_fittings'), re.M)
        self.assertGreater(len(keys), 0)
        for key in keys:
            self.assertIn('fit_' + key, names)

    def test_the_page_is_a_safe_raw_string(self):
        page = SOURCE.split('/proc/train_designer_page()\n\treturn @{"', 1)[1]
        self.assertTrue(page.rstrip().endswith('"}'))
        page = page.rstrip()[:-2]
        self.assertEqual(page.count('@@DATA@@'), 1)
        self.assertNotIn('"}', page)
        self.assertNotIn(chr(0x2014), SOURCE)
        for word in ('=>', '`'):  # plain ES5 for the embedded browser
            self.assertNotIn(word, page)


if __name__ == '__main__':
    unittest.main()
