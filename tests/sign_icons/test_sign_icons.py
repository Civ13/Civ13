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

    def test_refastening_a_signpost_keeps_its_direction_boards(self):
        removal = proc('/obj/structure/sign/attackby(')
        replacement = proc('/obj/item/sign/attackby(')
        renderer = proc('/obj/structure/sign/signpost/update_icon()')
        self.assertIn('S.desc = desc', removal)
        self.assertRegex(
            replacement,
            r'if \(sign_state == "signpost_pole"\)\s+'
            r'S = new /obj/structure/sign/signpost\(user.loc\)\s+'
            r'else\s+S = new\(user.loc\)',
        )
        self.assertRegex(
            replacement,
            r'S.desc = desc\s+S.icon = icon\s+S.icon_state = sign_state\s+S.update_icon\(\)',
        )
        available = states('icons/obj/decals.dmi')
        for direction in ('North', 'East', 'South', 'West'):
            with self.subTest(direction=direction):
                board = f'signpost_{direction.lower()}'
                self.assertRegex(
                    renderer,
                    rf'if \(findtext\(desc, "<b>{direction}:</b>"\)\)\s+'
                    rf'overlays \+= icon\(icon, "{board}"\)',
                )
                self.assertIn(board, available)


class FlagMakerSteps(unittest.TestCase):
    """The flag maker is a table of steps (choice -> decals.dmi state) shared by
    hand design and design codes; the native check is tests/design_codes/probe.dm."""

    def steps(self):
        return source_adapter.extract(FLAGS, '/proc/flagmaker_steps')

    def test_each_color_step_keeps_its_position_and_sprites(self):
        available = states('icons/obj/decals.dmi')
        helper = source_adapter.extract(FLAGS, '/proc/flagmaker_colour_step')
        for choice, suffix in (('White', 'white'), ('Black', 'black'), ('Yellow', 'yellow'),
                               ('Blue', 'blue'), ('Red', 'red'), ('Green', 'green')):
            self.assertIn(f'"{choice}" = "[prefix]_{suffix}"', helper)
        self.assertIn('"No" = null', helper)
        body = self.steps()
        for label, prefix in (('left-half', 'fl'), ('right-half', 'fr'), ('left-third', 'f1'),
                              ('center-third', 'f2'), ('right-third', 'f3')):
            with self.subTest(position=label):
                self.assertIn(f'flagmaker_colour_step("Add a {label} color?", "{prefix}")', body)
                for suffix in ('white', 'black', 'yellow', 'blue', 'red', 'green'):
                    self.assertIn(f'{prefix}_{suffix}', available)

    def test_cross_saltire_and_symbol_keep_their_sprites_in_order(self):
        available = states('icons/obj/decals.dmi')
        body = self.steps()
        for shape, prefix in (('Cross', 'e_bigcross'), ('Saltire', 'e_saltire')):
            for color, suffix in (('White', '2'), ('Black', '0'), ('Blue', '3'), ('Red', '1'), ('Green', '4')):
                with self.subTest(shape=shape, color=color):
                    self.assertIn(f'"{color} {shape}" = "{prefix}{suffix}"', body)
                    self.assertIn(prefix + suffix, available)
        self.assertLess(body.index('"Add a cross?"'), body.index('"Add a saltire?"'))
        self.assertLess(body.index('"Add a saltire?"'), body.index('"Add a symbol?"'))
        self.assertIn('"White Cross" = "e_cross0"', body)
        for state in __import__('re').findall(r'= "(e_[a-z]+\d)"', body):
            self.assertIn(state, available)


if __name__ == '__main__':
    unittest.main()
