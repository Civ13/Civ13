"""Exercise directional overlay initialization and its use at both entry points."""
import importlib.util
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('tape_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
SOURCE = (ROOT / 'code/game/objects/items/weapons/policetape.dm').read_text(encoding='utf-8-sig')


def init(cache):
    body = adapter.extract(SOURCE, '/proc/initialize_hazard_overlays')
    for name in ('NORTH', 'EAST', 'SOUTH', 'WEST'):
        body = body.replace(f'"[{name}]"', repr(name))
    body = re.sub(r"new/image\('icons/effects/warning_stripes.dmi', icon_state = \"([NESW])\"\)",
                  r"make_image('\1')", body)
    body += '\n\treturn hazard_overlays'
    proc = adapter.project('/test/proc/run()\n' + body + '\n', '/test/proc/run',
                           'hazard_overlays', {'list': dict, 'make_image': lambda state: state})
    return proc(cache)


class TapeMarkingTest(unittest.TestCase):
    def test_cache_initializes_for_fresh_world_and_is_reused(self):
        cache = init(None)
        self.assertEqual(cache, {'NORTH': 'N', 'EAST': 'E', 'SOUTH': 'S', 'WEST': 'W'})
        self.assertIs(init(cache), cache)

    def test_floor_and_placed_tape_initialize_before_use(self):
        placement = adapter.extract(SOURCE, '/obj/item/taperoll/afterattack')
        floor = placement[placement.index('if (isfloor(A))'):]
        self.assertLess(floor.index('initialize_hazard_overlays()'), floor.index('hazard_overlays['))
        created = adapter.extract(SOURCE, '/obj/item/tape/New')
        self.assertIn('initialize_hazard_overlays()', created)


if __name__ == '__main__':
    unittest.main()
