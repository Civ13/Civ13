"""Check that the Berlin seal variants name real bureaucracy DMI states."""
from pathlib import Path
import re
import struct
import unittest
import zlib


ROOT = Path(__file__).resolve().parents[2]


def icon_states(path):
    with path.open('rb') as icon:
        if icon.read(8) != b'\x89PNG\r\n\x1a\n':
            raise ValueError('Not a PNG icon')
        while header := icon.read(8):
            size, kind = struct.unpack('>I4s', header)
            data = icon.read(size)
            icon.read(4)  # CRC
            if kind == b'zTXt' and data.startswith(b'Description\0'):
                compressed = data.split(b'\0', 1)[1]
                description = zlib.decompress(compressed[1:]).decode('utf-8')
                return set(re.findall(r'^state = "([^"]+)"', description, re.M))
    raise ValueError('Missing DMI description')


class BerlinStampIcons(unittest.TestCase):
    def test_variants_use_distinct_existing_states(self):
        source = (ROOT / 'code/game/objects/items/stamp.dm').read_text(encoding='utf-8-sig')
        available = icon_states(ROOT / 'icons/obj/bureaucracy.dmi')
        used = []
        for suffix in ('', '/censored'):
            path = '/obj/item/weapon/stamp/mail/berlin' + suffix
            block = re.search(r'^' + re.escape(path) + r'\s*\n((?:\t[^\n]*\n)+)', source, re.M)
            self.assertIsNotNone(block, path)
            state = re.search(r'^\ticon_state = "([^"]+)"', block.group(1), re.M)
            self.assertIsNotNone(state, path)
            used.append(state.group(1))
            with self.subTest(path=path):
                self.assertTrue(state.group(1) in available, f'{path}: missing {state.group(1)}')
        self.assertNotEqual(*used)


if __name__ == '__main__':
    unittest.main()
