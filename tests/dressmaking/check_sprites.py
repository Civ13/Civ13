"""Audit every reused dress DMI frame. Requires Pillow; no game is started."""
from pathlib import Path
import re
import unittest
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/1713/dressmaking.dm').read_text()

class DressSpriteTests(unittest.TestCase):
    def test_every_reused_dress_layer_has_pixels_in_item_and_four_worn_directions(self):
        cut = SOURCE.split('/proc/dressmaking_color_valid', 1)[0]
        states = set(re.findall(r'"((?:customdress|custombuttonup|crinoline_dress)[a-z_]*)"', cut))
        self.assertEqual(len(states), 11)
        for path, required_dirs in [('icons/obj/clothing/uniforms.dmi', 1), ('icons/mob/uniform.dmi', 4)]:
            image = Image.open(ROOT / path)
            metadata = image.info['Description']
            width = int(re.search(r'\bwidth = (\d+)', metadata)[1])
            height = int(re.search(r'\bheight = (\d+)', metadata)[1])
            offset = 0
            found = set()
            for block in metadata.split('state = ')[1:]:
                name = block.split('\n')[0].strip('"')
                dirs = int(re.search(r'dirs = (\d+)', block)[1])
                frames = int(re.search(r'frames = (\d+)', block)[1])
                if name in states:
                    found.add(name)
                    self.assertGreaterEqual(dirs, required_dirs)
                    visible_directions = 0
                    for direction in range(dirs):
                        index = offset + direction
                        x, y = (index % (image.width // width)) * width, (index // (image.width // width)) * height
                        visible_directions += image.crop((x, y, x+width, y+height)).getbbox() is not None
                    # Some panels (e.g. an underskirt) are intentionally hidden
                    # in side views. Each full silhouette must remain visible.
                    self.assertGreater(visible_directions, 0, (path, name))
                    if name in ('customdress', 'custombuttonup_full', 'crinoline_dress'):
                        self.assertEqual(visible_directions, dirs, (path, name))
                offset += dirs * frames
            self.assertEqual(found, states)


if __name__ == '__main__':
    unittest.main()
