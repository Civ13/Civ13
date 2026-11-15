"""Offline source contracts for preserves. Gameplay behaviour is covered by the
native probe: python3 tests/ecology_spawning/run_linux.py . tests/preserves/probe.dm 300
"""
from pathlib import Path
import re
import struct
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/preserves.dm'


def dmi_states(path):
    data = path.read_bytes()
    pos = 8
    while pos < len(data):
        length, kind = struct.unpack('>I4s', data[pos:pos + 8])
        chunk = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b'zTXt' and chunk.startswith(b'Description\0'):
            text = zlib.decompress(chunk[len(b'Description\0') + 1:]).decode('utf-8')
            return set(re.findall(r'state = "([^"]*)"', text))
    return set()


class PreservesSourceTests(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')

    def test_included(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertIn('#include "code\\modules\\1713\\preserves.dm"', dme)

    def test_sprites(self):
        states = dmi_states(ROOT / 'icons/obj/food/preserves.dmi')
        used = set(re.findall(r'"(crock|crock_closed|crock_fill|unfired_crock|preserve_jar|jam_jar|jam_jar_fill)"', self.source))
        self.assertTrue(used)
        self.assertLessEqual(used, states)

    def test_recipes_and_research(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        nodes = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        for path in ('/obj/item/weapon/clay/crock', '/obj/item/weapon/reagent_containers/glass/preserve_jar'):
            self.assertIn(f',{path},', recipes)
            self.assertIn(f'"{path}" = "pottery_storage"', nodes)

    def test_reagents_unique(self):
        for rid in ('vinegar', 'jam'):
            hits = 0
            for path in (ROOT / 'code').rglob('*.dm'):
                hits += len(re.findall(rf'(?m)^\tid = "{rid}"$', path.read_text(encoding='utf-8', errors='replace')))
            self.assertEqual(hits, 2 if rid == 'jam' else 1, rid)  # jam: reagent and reaction

    def test_no_spawn(self):
        self.assertNotIn('spawn(', self.source)


if __name__ == '__main__':
    unittest.main()
