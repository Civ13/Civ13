"""Sign removal and replacement preserve the icon file as well as its state."""
from pathlib import Path
import re
import struct
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/game/objects/structures/signs.dm').read_text(encoding='utf-8')


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


if __name__ == '__main__':
    unittest.main()
