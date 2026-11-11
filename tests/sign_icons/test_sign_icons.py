"""Sign removal and replacement preserve the icon file as well as its state."""
from pathlib import Path
import re
import struct
import sys
import unittest
import zlib
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
import source_adapter

SOURCE = (ROOT / 'code/game/objects/structures/signs.dm').read_text(encoding='utf-8')
FLAGS = (ROOT / 'code/game/objects/structures/sign_flags.dm').read_text(encoding='utf-8')


def proc(header):
    start = SOURCE.index(header)
    end = re.search(r'\n(?=/)', SOURCE[start + len(header):])
    return SOURCE[start:] if end is None else SOURCE[start:start + len(header) + end.start()]


def states(path):
    data = (ROOT / path).read_bytes()
    offset, metadata = 8, ''
    while offset < len(data):
        size = struct.unpack('>I', data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        chunk = data[offset + 8:offset + 8 + size]
        offset += 12 + size
        if kind == b'zTXt':
            metadata += zlib.decompress(chunk.split(b'\0', 1)[1][1:]).decode('latin1')
        elif kind == b'tEXt':
            metadata += chunk.decode('latin1')
    return set(re.findall(r'^state = "(.*)"', metadata, re.MULTILINE))


class SignIcons(unittest.TestCase):
    def test_courthouse_sign_survives_removal_and_replacement(self):
        self.assertIn('court', states('icons/obj/decals_wide.dmi'))
        self.assertNotIn('court', states('icons/obj/decals.dmi'))
        removal = proc('/obj/structure/sign/attackby(')
        replacement = proc('/obj/item/sign/attackby(')
        self.assertRegex(removal, r'S\.icon\s*=\s*icon\b')
        self.assertRegex(replacement, r'S\.icon\s*=\s*icon\b')
        self.assertIn('S.sign_state = icon_state', removal)
        self.assertIn('S.icon_state = sign_state', replacement)


class FlagColorOverlays(unittest.TestCase):
    def setUp(self):
        image_call = 'image("icon" = \'icons/obj/decals.dmi\', "icon_state" = "[prefix]_[suffix]")'
        self.assertEqual(FLAGS.count(image_call), 1)
        # Model only DM's image constructor and interpolation at the engine boundary.
        projected = FLAGS.replace(image_call, 'image(prefix, suffix)')
        old_fields = source_adapter.FIELDS
        try:
            source_adapter.FIELDS += ('overlays', 'new_icon_state')
            self.apply = source_adapter.project(
                projected, '/obj/item/flagmaker/proc/apply_color_overlay',
                'src, choice, prefix', {'image': lambda prefix, suffix: prefix + '_' + suffix}, method=True)
        finally:
            source_adapter.FIELDS = old_fields

    def test_each_color_uses_the_original_sprite_for_each_position(self):
        class Overlays(list):
            def __iadd__(self, image):
                self.append(image)
                return self

        available = states('icons/obj/decals.dmi')
        for prefix in ('fl', 'fr', 'f1', 'f2', 'f3'):
            for choice, suffix in (('White', 'white'), ('Black', 'black'), ('Yellow', 'yellow'),
                                   ('Blue', 'blue'), ('Red', 'red'), ('Green', 'green')):
                with self.subTest(prefix=prefix, choice=choice):
                    flag = SimpleNamespace(icon_state='before', new_icon_state='base', overlays=Overlays())
                    self.apply(flag, choice, prefix)
                    expected = prefix + '_' + suffix
                    self.assertIn(expected, available)
                    self.assertEqual(flag.overlays, [expected])
                    self.assertEqual(flag.icon_state, 'before')

    def test_no_resets_the_icon_but_unknown_choices_do_nothing(self):
        for choice, expected in (('No', 'base'), (None, 'before'), ('Unknown', 'before')):
            with self.subTest(choice=choice):
                flag = SimpleNamespace(icon_state='before', new_icon_state='base', overlays=[])
                self.apply(flag, choice, 'fl')
                self.assertEqual(flag.icon_state, expected)
                self.assertEqual(flag.overlays, [])

    def test_each_prompt_keeps_its_position_and_color_choices(self):
        body = source_adapter.extract(FLAGS, '/obj/item/flagmaker/attack_self')
        options = 'list("White", "Black", "Yellow", "Blue", "Red", "Green", "No")'
        for number, label, prefix in ((2, 'left-half', 'fl'), (3, 'right-half', 'fr'),
                                      (4, 'left-third', 'f1'), (5, 'center-third', 'f2'),
                                      (6, 'right-third', 'f3')):
            with self.subTest(position=label):
                self.assertIn(f'var/list/display{number} = {options}\n'
                              f'\tvar/choice{number} = WWinput(user, "Add a {label} color?", '
                              f'"Flag Maker", "No", display{number})\n'
                              f'\tapply_color_overlay(choice{number}, "{prefix}")', body)


if __name__ == '__main__':
    unittest.main()
