"""Check locket opening against the actual icon-state inventory."""
from pathlib import Path
import re
import struct
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/objects/items/clothing/under/accessories/lockets.dm'
ICON = ROOT / 'icons/obj/clothing/ties.dmi'


def icon_states():
    data = ICON.read_bytes()
    offset = 8
    while offset < len(data):
        size = struct.unpack('>I', data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        payload = data[offset + 8:offset + 8 + size]
        offset += size + 12
        if kind == b'zTXt' and payload.startswith(b'Description\0'):
            metadata = zlib.decompress(payload.split(b'\0', 1)[1][1:]).decode()
            return set(re.findall(r'^state = "([^"]+)"', metadata, re.M))
    raise AssertionError('DMI description is missing')


class LocketStorageTests(unittest.TestCase):
    def test_missing_open_sprite_does_not_prevent_opening(self):
        self.assertIn('locket', icon_states())
        self.assertNotIn('locket_open', icon_states())
        body = SOURCE.read_text(encoding='utf-8-sig').split('/locket/attack_self', 1)[1].split('/obj/item/', 1)[0]
        before_toggle = body.split('open = !open', 1)[0]
        self.assertNotIn('return', before_toggle)
        self.assertRegex(body, r'if \("\[base_icon\]_open" in icon_states\(icon\)\)\s+icon_state = "\[base_icon\]_open"')

    def test_close_restores_base_sprite(self):
        body = SOURCE.read_text(encoding='utf-8-sig').split('/locket/attack_self', 1)[1].split('/obj/item/', 1)[0]
        self.assertRegex(body, r'else\s+icon_state = "\[base_icon\]"')


if __name__ == '__main__':
    unittest.main()
