"""The commonly spawned remains decals must select drawable blood and flesh layers."""
import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.dmi import Dmi

GIB_TYPE = '/obj/effect/decal/cleanable/blood/gibs'
SOURCE = (ROOT / 'code/game/objects/effects/decals/Cleanable/humans.dm').read_text(encoding='utf-8')


def declaration(path):
    return re.search(rf'^{re.escape(path)}\n((?:\t[^\n]*\n)+)', SOURCE, re.MULTILINE)[1]


class GibIcons(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        icon = re.search(r"^\ticon = '([^']+)'$", declaration(GIB_TYPE), re.MULTILINE)[1]
        cls.sheet = Dmi.from_file(ROOT / icon)
        cls.states = {state.name for state in cls.sheet.states}

    def assert_drawable(self, name):
        self.assertTrue({name, f'{name}_flesh'} <= self.states, f'Missing art for {name}')
        for frame in self.sheet.get_state(name).frames:
            self.assertIsNotNone(frame.getchannel('A').getbbox(), f'{name} is transparent')

    def test_default_has_blood_and_flesh_art(self):
        name = re.search(r'^\ticon_state = "([^"]+)"$', declaration(GIB_TYPE), re.MULTILINE)[1]
        self.assert_drawable(name)

    def test_generic_and_directional_selections_are_drawable(self):
        for suffix in ('', '/up', '/down'):
            pool = re.search(r'^\trandom_icon_states = list\((.*)\)$',
                             declaration(GIB_TYPE + suffix), re.MULTILINE)[1]
            names = re.findall(r'"([^"]+)"', pool)
            self.assertTrue(names, f'Empty icon pool for {GIB_TYPE}{suffix}')
            for name in dict.fromkeys(names):
                with self.subTest(type_path=GIB_TYPE + suffix, state=name):
                    self.assert_drawable(name)


if __name__ == '__main__':
    unittest.main()
