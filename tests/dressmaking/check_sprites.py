"""Audit every reused tailoring DMI frame. Requires Pillow; no game is started."""
from pathlib import Path
import importlib.util
import re
import unittest
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
_spec = importlib.util.spec_from_file_location('tailoring_source', ROOT / 'tests/dressmaking/test_source.py')
source = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(source)


def frames(path):
    image = Image.open(ROOT / path)
    metadata = image.info['Description']
    width = int(re.search(r'\bwidth = (\d+)', metadata)[1])
    height = int(re.search(r'\bheight = (\d+)', metadata)[1])
    offset, found = 0, {}
    for block in metadata.split('state = ')[1:]:
        name = block.split('\n')[0].strip('"')
        dirs = int(re.search(r'dirs = (\d+)', block)[1])
        count = int(re.search(r'frames = (\d+)', block)[1])
        if name not in found:
            visible = 0
            for direction in range(dirs):
                index = offset + direction
                x, y = (index % (image.width // width)) * width, (index // (image.width // width)) * height
                visible += image.crop((x, y, x + width, y + height)).getbbox() is not None
            found[name] = (dirs, visible)
        offset += dirs * count
    return found


class TailoringSpriteTests(unittest.TestCase):
    def test_every_body_is_visible_from_all_sides_and_every_piece_somewhere(self):
        cache = {}
        for body_id, row in source.catalogue().items():
            worn_path, item_path = source.ART[row['slot']]
            worn = cache.setdefault(worn_path, frames(worn_path))
            item = cache.setdefault(item_path, frames(item_path))
            with self.subTest(body=body_id):
                dirs, visible = worn[row['base']]
                self.assertEqual(visible, dirs)
                self.assertGreater(item[row['item_base'] or row['base']][1], 0)
                # Some pieces (e.g. an underskirt) are hidden in side views.
                for state in row['panels'] + row['fixed']:
                    self.assertGreater(worn[state][1], 0, state)


if __name__ == '__main__':
    unittest.main()
