"""Offline only: importing the deployment launcher is deliberately avoided."""
import importlib.util
from pathlib import Path
import unittest
import re
from collections import deque

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('map_environment', ROOT / 'scripts/map_environment.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class MapEnvironmentTests(unittest.TestCase):
    def test_city_map_is_separate_and_reproducible(self):
        spec = importlib.util.spec_from_file_location('extraction_build_map', ROOT / 'tests/extraction/build_map.py')
        generator = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(generator)
        city = (ROOT / 'maps/extraction/modern_city_extraction.dmm').read_text()
        self.assertEqual(city, generator.build(city=True))
        self.assertNotEqual(city, generator.build())
        definitions = dict(re.findall(r'^"([a-z]{2})" = (.+)$', city, re.M))
        grids = re.findall(r'\(1,1,(\d+)\) = \{"\n(.*?)\n"\}', city, re.S)
        self.assertEqual([int(z) for z, _ in grids], [1, 2, 3])
        for _, body in grids:
            self.assertEqual(len(body.splitlines()), 96)
            self.assertTrue(all(len(row) == 192 for row in body.splitlines()))
        raid = {key: definitions[key] for row in grids[0][1].splitlines() for key in (row[i:i+2] for i in range(0, len(row), 2))}
        self.assertEqual(sum('/obj/effect/extraction_exit/scheduled' in value for value in raid.values()), 2)
        self.assertFalse(any('/obj/effect/extraction_exit,' in value or '/obj/effect/extraction_exit/locked_room' in value for value in raid.values()))
        self.assertTrue(any('/obj/structure/wild/berrybush/tinto' in value for value in raid.values()))
        self.assertTrue(any('/obj/structure/sink' in value for value in raid.values()))

    def test_original_hub_navigation_and_private_workspaces(self):
        source = (ROOT / 'maps/extraction/industrial_district.dmm').read_text()
        definitions = dict(re.findall(r'^"([a-z]{2})" = (.+)$', source, re.M))
        grids = re.findall(r'\(1,1,(\d+)\) = \{"\n(.*?)\n"\}', source, re.S)
        self.assertEqual([int(z) for z, _ in grids], [1, 2, 3])
        layers = []
        for _, body in grids:
            rows = body.splitlines()
            self.assertEqual(len(rows), 96)
            self.assertTrue(all(len(row) == 192 for row in rows))
            layers.append({(x + 1, 96 - y): definitions[row[x * 2:x * 2 + 2]]
                           for y, row in enumerate(rows) for x in range(96)})
        hub = layers[2]
        reached = {(48, 48)}
        pending = deque(reached)
        while pending:
            x, y = pending.popleft()
            for point in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                atoms = hub.get(point, '')
                if point in reached or not atoms or '/obj/covers/generic_wall' in atoms or '/obj/structure/bed/chair' in atoms:
                    continue
                reached.add(point)
                pending.append(point)
        desks = [point for point, atoms in hub.items() if '/obj/effect/extraction_hub_guide/' in atoms]
        self.assertEqual(len(desks), 3)
        self.assertTrue(all(point in reached for point in desks))
        houses = layers[1]
        benches = [point for point, atoms in houses.items() if '/component_workbench/extraction_private' in atoms]
        self.assertEqual(len(benches), 16)
        for room in range(16):
            center = (12 + room % 4 * 22, 12 + room // 4 * 22)
            self.assertIn(f'room = {room + 1}', houses[(center[0] + 3, center[1] + 3)])
            # The paid Piccolino's bay and routes to crate/terminal remain clear.
            self.assertNotIn('/component_workbench', houses[(center[0] - 2, center[1] - 2)])
        self.assertEqual(sum('/obj/structure/component_workbench,' in atoms for atoms in layers[0].values()), 9)

    def test_actual_catalog_rewrites_one_unconditional_map(self):
        original = (ROOT / 'civ13.dme').read_text()
        for path in ('maps/extraction/industrial_district.dmm', 'maps/extraction/modern_city_extraction.dmm', 'maps/2013/alleyway.dmm', 'maps/1969/bank_robbery.dmm'):
            self.assertTrue((ROOT / path).is_file())
            changed = MODULE.select_map(original, path)
            block = changed.split(MODULE.BEGIN)[1].split(MODULE.END)[0]
            self.assertEqual(block, f'\n#include "{path}"\n')
            self.assertEqual(changed.split(MODULE.BEGIN)[0], original.split(MODULE.BEGIN)[0])
            self.assertEqual(changed.split(MODULE.END)[1], original.split(MODULE.END)[1])
            self.assertEqual(MODULE.select_map(changed, path), changed)

    def test_flat_historical_environment_and_comments(self):
        original = '// example.dmm\n#include "code.dm"\n#include "maps/old.dmm"\n'
        self.assertEqual(MODULE.select_map(original, 'maps/new.dmm'), '// example.dmm\n#include "code.dm"\n#include "maps/new.dmm"\n')

    def test_conditional_or_ambiguous_sources_fail_before_writing(self):
        for source in ('#ifdef MAP\n#include "old.dmm"\n#endif\n', MODULE.BEGIN + MODULE.BEGIN + MODULE.END, MODULE.END + MODULE.BEGIN, '#include "code.dm"\n'):
            with self.assertRaises(ValueError):
                MODULE.select_map(source, 'new.dmm')

    def test_include_injection_rejected(self):
        for path in ('', 'new.dm', 'bad".dmm', 'bad\n.dmm', 'bad\r.dmm'):
            with self.assertRaises(ValueError):
                MODULE.select_map('#include "old.dmm"\n', path)


if __name__ == '__main__':
    unittest.main()
