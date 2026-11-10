"""Exercise body-bag label overlay changes projected from the DM source."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('bodybag_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
SOURCE = (ROOT / 'code/game/objects/items/bodybag.dm').read_text(encoding='utf-8-sig')


class Overlays(list):
    def __iadd__(self, item):
        self.append(item)
        return self

    def __isub__(self, item):
        while item in self:
            self.remove(item)
        return self


def apply_label(overlays, label):
    body = adapter.extract(SOURCE, '/obj/structure/closet/body_bag/attackby').splitlines()
    start = next(i for i, line in enumerate(body) if 't = sanitizeSafe' in line)
    end = next(i for i in range(start, len(body)) if body[i].strip() == 'return')
    lines = ['\t' + line[2:] for line in body[start:end]]
    proc = adapter.project('/test/proc/run()\n' + '\n'.join(lines) + '\n', '/test/proc/run', 't, overlays', {
        'sanitizeSafe': lambda value, _: value, 'MAX_NAME_LEN': 128,
        'image': lambda icon, state: (icon, state), 'icon': 'bodybag',
    })
    proc(label, overlays)


class BodyBagLabelTests(unittest.TestCase):
    def test_clearing_label_removes_tag_and_preserves_other_overlays(self):
        overlays = Overlays(['unrelated'])
        apply_label(overlays, 'Jane')
        self.assertIn(('bodybag', 'bodybag_label'), overlays)
        apply_label(overlays, '')
        self.assertEqual(overlays, ['unrelated'])


if __name__ == '__main__':
    unittest.main()
