"""Offline source contracts for preserves. Gameplay behaviour is covered by the
native probe: python3 tests/ecology_spawning/run_linux.py . tests/preserves/probe.dm 300
"""
import importlib.util
import re
import struct
import unittest
import zlib
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/preserves.dm'
SNACKS = ROOT / 'code/modules/reagents/reagent_containers/food/snacks.dm'
spec = importlib.util.spec_from_file_location(
    'source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


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

    def test_spread_transfer_reserves_enough_space_before_moving_the_slice(self):
        source = SNACKS.read_text(encoding='utf-8')
        transfer = '/obj/item/weapon/reagent_containers/food/snacks/breadslice/proc/transfer_reagents_to_spread'
        for volume, topping, present, existing_capacity, expected_capacity in (
            (50, 2, 2, 50, 52),  # jam layer already present
            (50, 5, 0, 50, 55),  # butter added after the transfer
            (35, 5, 0, 60, 60),  # keep a larger holder
        ):
            with self.subTest(volume=volume, topping=topping, present=present):
                target = SimpleNamespace(maximum_volume=existing_capacity, total_volume=present)
                moved = []

                def move(destination, amount):
                    self.assertIs(destination, target)
                    moved.append((destination.maximum_volume, amount))

                reagents = SimpleNamespace(total_volume=volume, trans_to_holder=move)
                adapter.project(source, transfer, 'target, topping_volume', {'reagents': reagents})(target, topping)
                self.assertEqual(moved, [(expected_capacity, volume)])

        empty = SimpleNamespace(total_volume=0, trans_to_holder=Mock())
        for reagents in (None, empty):
            with self.subTest(reagents=reagents):
                target = SimpleNamespace(maximum_volume=50, total_volume=0)
                adapter.project(source, transfer, 'target, topping_volume', {'reagents': reagents})(target, 5)
                self.assertEqual(target.maximum_volume, 50)
        empty.trans_to_holder.assert_not_called()

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

    def test_lid_cancels_unfinished_work_and_reseals_with_a_stoppable_timer(self):
        def proc(suffix):
            marker = f'/obj/item/weapon/reagent_containers/glass/crock/{suffix}'
            return self.source.split(marker, 1)[1].split('\n/', 1)[0]

        self.assertRegex(proc('attack_self(mob/user)'),
                         r'if \(is_open_container\(\)\)\n\t\tcrock_cancel\(\)\n\telse\n\t\tcrock_schedule\(\)')
        self.assertIn('CROCK_WORK_TIME, TIMER_STOPPABLE)', proc('proc/crock_schedule()'))
        self.assertIn('deltimer(crock_timer)', proc('proc/crock_cancel()'))
        self.assertIn('crock_timer = null', proc('proc/crock_cancel()'))
        self.assertIn('crock_cancel()', proc('Destroy()'))
        self.assertIn('key == "crock_timer"', proc('persistence_runtime_var(key)'))
        self.assertIn('crock_schedule()', proc('after_load()'))


if __name__ == '__main__':
    unittest.main()
