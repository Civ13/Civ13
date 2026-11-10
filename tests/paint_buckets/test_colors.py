"""Exercise bucket initialization and paint's turf callback with fake reagent boundaries."""
import importlib.util
from pathlib import Path
import re
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('paint_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


class PaintBucketTest(unittest.TestCase):
    def test_all_bucket_variants_initialize_colored_paint(self):
        source = (ROOT / 'code/game/objects/items/weapons/paint.dm').read_text()
        default = re.search(r'var/paint_color = "(#[0-9A-Fa-f]{6})"', source).group(1)
        body = adapter.extract(source, 'New')
        tail = body.split('\t..()\n', 1)[1]
        initialize = adapter.project('/test/proc/fill()\n' + tail + '\n',
                                     '/test/proc/fill', 'reagents, volume, paint_color', {})
        reagent_source = (ROOT / 'code/modules/reagents/Chemistry-Reagents/Chemistry-Reagents-Other.dm').read_text()
        touch = adapter.project(reagent_source, '/datum/reagent/paint/touch_turf', 'T, color',
                                {'istype': lambda target: True})
        expected = {'red': '#FE191A', 'yellow': '#FDFE7D', 'green': '#18A31A',
                    'blue': '#247CFF', 'purple': '#CC0099', 'black': '#000000', 'white': '#FFFFFF'}
        for name, color in expected.items():
            with self.subTest(bucket=name):
                block = re.search(r'^\t' + name + r'\n((?:\t\t[^\n]*\n)*)', source, re.M).group(1)
                match = re.search(r'paint_color = "(#[0-9A-Fa-f]{6})"', block)
                chosen = match.group(1) if match else default
                contents = []
                holder = SimpleNamespace(add_reagent=lambda *args: contents.append(args))
                initialize(holder, 60, chosen)
                self.assertEqual(contents, [('paint', 60, color)])
                turf = SimpleNamespace(color=None)
                touch(turf, contents[0][2])
                self.assertEqual(turf.color, color)


if __name__ == '__main__':
    unittest.main()
