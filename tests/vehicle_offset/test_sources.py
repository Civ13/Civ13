"""Vehicle offsets: offline seam checks.

The native probe (probe.dm, run.py) drives a crate, a motorcycle with its
rider, a frame car and a carriage by pixels in a real build and times the
pixel writes of a pulse. These checks keep the rules the probe relies on.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
CORE = (ROOT / 'code/modules/craft/vehicle_offset.dm').read_text(encoding='utf-8')
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
PROBE = (ROOT / 'tests/vehicle_offset/probe.dm').read_text(encoding='utf-8')


def proc(text, name):
    start = text.index(name)
    end = re.search(r'\n(?=/|#define|#undef|\Z)', text[start + 1:])
    return text[start:start + 1 + end.start()] if end else text[start:]


class VehicleOffsetSources(unittest.TestCase):
    def test_included(self):
        self.assertIn('#include "code\\modules\\craft\\vehicle_offset.dm"', DME)

    def test_half_tile_wrap(self):
        advance = proc(CORE, '/datum/vehicle_offset/proc/advance(')
        self.assertIn('next >= VEHICLE_OFFSET_HALF || next < -VEHICLE_OFFSET_HALF', advance)
        self.assertIn('if (commit(way))', advance)
        self.assertIn('if (!can_cover(way))', advance)

    def test_pulses_write_directly(self):
        # Pixel pulses never call Move(); only the tile step moves things between turfs.
        draw = proc(CORE, '/datum/vehicle_offset/proc/draw(')
        self.assertIn('A.step_x = ox + own[1]', draw)
        self.assertNotIn('Move(', draw)
        self.assertNotIn('spawn(', CORE)
        self.assertNotIn('sleep(', CORE)

    def test_nothing_saved(self):
        # A datum, never a var on a saved atom: saves keep tiles only.
        self.assertIn('/proc/vehicle_offset_snap_all()', CORE)
        self.assertNotIn('persistence', CORE.lower().replace('nothing here is saved', ''))

    def test_probe_is_pinned(self):
        self.assertIn('world.byond_version == 516 && world.byond_build == 1688', PROBE)
        for label in ('car_moves_as_one', 'wall_stops_flush', 'rider_stays_seated', 'carriage_crossed', 'snap_all_before_save'):
            self.assertIn(label, PROBE)


if __name__ == '__main__':
    unittest.main()
