"""Offline source contracts for seeing down through open air.

Behaviour is covered natively by tests/open_air_view/run_native.py and in a
real client by tests/open_air_view/client_check.py (Windows).
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/multiz/open_air_view.dm').read_text(encoding='utf-8-sig')


def proc(name):
    return SOURCE.split(name + '\n', 1)[1].split('\n/', 1)[0]


class OpenAirView(unittest.TestCase):
    def test_included_in_build(self):
        dme = (ROOT / 'civ13.dme').read_text()
        self.assertIn('#include "code\\modules\\multiz\\open_air_view.dm"', dme)
        self.assertIn('#include "code\\processes\\open_air_view.dm"', dme)
        # After building_lighting.dm, whose building_wake it calls.
        self.assertLess(dme.index('multiz\\building_lighting.dm'), dme.index('multiz\\open_air_view.dm'))

    def test_view_is_shaded_unclickable_and_not_saved(self):
        view = SOURCE.split('/obj/effect/open_air_view\n', 1)[1].split('\n/', 1)[0]
        for line in ('mouse_opacity = 0', 'appearance_flags = KEEP_TOGETHER', 'color = OPEN_AIR_VIEW_SHADE'):
            self.assertIn(line, view)
        self.assertIn('/turf/sky/building/var/tmp/obj/effect/open_air_view/open_air_view', SOURCE)
        refresh = proc('/turf/sky/building/proc/open_air_view_refresh(depth = 1, wake = TRUE)')
        self.assertIn('V.loc = null', refresh)

    def test_clicks_and_lighting(self):
        self.assertIn('/atom/movable\n\tvis_flags = VIS_INHERIT_PLANE | VIS_INHERIT_ID', SOURCE)
        self.assertIn('/turf\n\tvis_flags = VIS_INHERIT_PLANE | VIS_INHERIT_ID | VIS_INHERIT_LAYER', SOURCE)
        # Under floors built over open air (layer 1.99), whose turf shows under them.
        self.assertIn('#define OPEN_AIR_VIEW_LAYER 1.95', SOURCE)
        self.assertIn('/atom/movable/lighting_overlay\n\tvis_flags = VIS_HIDE', SOURCE)
        self.assertIn('/atom/movable/lighting_fullbright\n\tvis_flags = VIS_HIDE', SOURCE)

    def test_floors_stop_the_view_and_replacement_drops_it(self):
        refresh = proc('/turf/sky/building/proc/open_air_view_refresh(depth = 1, wake = TRUE)')
        self.assertIn('(locate(/obj/covers) in src)', refresh)
        self.assertIn('istype(src, /turf/sky/building/unformed)', refresh)
        self.assertIn('multiz_level_below(z)', refresh)
        # Only the cell in sight is woken; the cells under it are drawn through it.
        self.assertIn('next.open_air_view_refresh(depth + 1, FALSE)', refresh)
        change = proc('/turf/sky/building/ChangeTurf(var/path, var/tell_universe = 1, var/force_lighting_update = FALSE, datum/durable_nomads_event/nomads_event = null)')
        self.assertLess(change.index('open_air_view_clear()'), change.index('..()'))

    def test_scan_skips_saves(self):
        process = (ROOT / 'code/processes/open_air_view.dm').read_text()
        self.assertLess(process.index('open_air_view_busy()'), process.index('C.open_air_view_scan()'))
        busy = proc('/proc/open_air_view_busy()')
        for guard in ('persistence_active_operation', 'persistence_save_in_progress', 'building_allocating_z'):
            self.assertIn(guard, busy)


if __name__ == '__main__':
    unittest.main()
