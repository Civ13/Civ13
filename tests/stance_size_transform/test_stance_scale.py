"""Every stance transform on a human keeps the trait size scale.

Running, walking, proning and prone movement rebuild the mob's transform from
a fresh matrix. A rebuild that skips Scale(size_multiplier) draws Short or
Dwarfism characters at full size (and Tall or Gigantism ones too small) until
the next update_icons(). Standard library source check; no BYOND needed.
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
FILES = (
    'code/_onclick/hud/base_screen_objects.dm',
    'code/game/mob/mob_movement.dm',
    'code/game/mob/living/carbon/human/inventory.dm',
    'code/game/mob/living/carbon/human/update_icons.dm',
)
# A stance transform is a fresh matrix that ends up translated by the prone
# offset or the standing height offset.
BLOCK = re.compile(r'var/matrix/M = matrix\(\)(.*?)\btransform = M', re.S)
STANCE = re.compile(r'M\.Translate\(\s*(1,\s*-6|0,\s*16\*)')


def stance_blocks(text):
    return [m.group(1) for m in BLOCK.finditer(text) if STANCE.search(m.group(1))]


class StanceScaleTest(unittest.TestCase):
    def test_every_stance_transform_scales(self):
        total = 0
        for rel in FILES:
            text = (ROOT / rel).read_text(encoding='utf-8', errors='replace')
            for body in stance_blocks(text):
                total += 1
                self.assertRegex(body, r'M\.Scale\(\s*\w+\.size_multiplier\s*\)|M\.Scale\(\s*size_multiplier\s*\)',
                    f'{rel}: stance transform without the size scale:\n{body}')
        self.assertGreaterEqual(total, 15)

    def test_mutation_without_scale_is_caught(self):
        sample = 'var/matrix/M = matrix()\n\tM.Translate(0, 16*(C.size_multiplier-1))\n\tC.transform = M'
        body = stance_blocks(sample)[0]
        self.assertNotRegex(body, r'M\.Scale\(')


if __name__ == '__main__':
    unittest.main()
