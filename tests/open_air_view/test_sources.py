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
        self.assertIn('open_air_view_floored()', refresh)
        # Floors with gaps in their sprite keep the view; solid floors drop it.
        floored = proc('/turf/sky/building/proc/open_air_view_floored()')
        self.assertIn('if (!C.gaps_show_below)', floored)
        self.assertIn('/obj/covers/var/gaps_show_below = FALSE', SOURCE)
        for gapped in ('/obj/covers/repairedfloor', '/obj/covers/catwalk'):
            self.assertIn(gapped + '\n\tgaps_show_below = TRUE', SOURCE)
        self.assertIn('istype(src, /turf/sky/building/unformed)', refresh)
        self.assertIn('multiz_level_below(z)', refresh)
        # Only the cell in sight is woken; the cells under it are drawn through it.
        self.assertIn('next.open_air_view_refresh(depth + 1, FALSE)', refresh)
        change = proc('/turf/sky/building/ChangeTurf(var/path, var/tell_universe = 1, var/force_lighting_update = FALSE, datum/durable_nomads_event/nomads_event = null)')
        self.assertLess(change.index('open_air_view_clear()'), change.index('..()'))

    def test_no_turf_is_shown_through_vis_contents(self):
        # A turf in vis_contents is re-sent to the client constantly: a real
        # client measured about 2.7 Mbps one level up (bandwidth_check.py).
        self.assertNotIn('vis_contents += below', SOURCE)
        castle = (ROOT / 'code/modules/1713/siege/siege_engines.dm').read_text(encoding='utf-8-sig')
        self.assertNotIn('vis_contents += below', castle)
        self.assertIn('V.open_air_show(below)', castle)
        sync = proc('/obj/effect/open_air_view/proc/open_air_view_sync()')
        self.assertIn('var/mutable_appearance/look = new(below)', sync)
        self.assertIn('for (var/atom/movable/A in below)', sync)
        # Movers update the views at once.
        moved = (ROOT / 'code/datums/observation/moved.dm').read_text(encoding='utf-8-sig')
        self.assertEqual(moved.count('open_air_view_moved(src, old_loc)'), 2)
        movable = (ROOT / 'code/game/atoms_movable.dm').read_text(encoding='utf-8-sig')
        self.assertIn('open_air_view_moved(src, origin)', movable)

    def test_scan_skips_saves(self):
        process = (ROOT / 'code/processes/open_air_view.dm').read_text()
        self.assertLess(process.index('open_air_view_busy()'), process.index('C.open_air_view_scan()'))
        busy = proc('/proc/open_air_view_busy()')
        for guard in ('persistence_active_operation', 'persistence_save_in_progress', 'lighting_startup_in_progress'):
            self.assertIn(guard, busy)
        # A level being added pauses only its own scan and the scan above it.
        self.assertNotIn('building_allocating_z', busy)
        link = proc('/proc/open_air_view_link_around(z, cx, cy, rx, ry, lead_x = 0, lead_y = 0)')
        self.assertIn('z == building_allocating_z || multiz_level_below(z) == building_allocating_z', link)

    def test_moving_viewer_is_linked_ahead(self):
        scan = proc('/client/proc/open_air_view_scan()')
        self.assertIn('clamp(centre.x - last.x, -OPEN_AIR_VIEW_LEAD, OPEN_AIR_VIEW_LEAD)', scan)
        self.assertLess(scan.index('var/turf/last = open_air_view_centre'), scan.index('open_air_view_centre = centre'))
        self.assertIn('open_air_view_link_around(centre.z, cx, cy, rx, ry, lead_x, lead_y)', scan)

    def test_one_failure_does_not_stop_the_scan(self):
        process = (ROOT / 'code/processes/open_air_view.dm').read_text()
        self.assertIn('try\n\t\t\tC.open_air_view_scan()\n\t\tcatch (var/exception/scan_error)', process)
        link = proc('/proc/open_air_view_link_around(z, cx, cy, rx, ry, lead_x = 0, lead_y = 0)')
        self.assertIn('try\n\t\t\tT.open_air_view_refresh()\n\t\tcatch (var/exception/cell_error)', link)
        self.assertIn('if (text == open_air_view_last_error)\n\t\treturn', SOURCE)

    def test_existing_views_repair_and_wake(self):
        refresh = proc('/turf/sky/building/proc/open_air_view_refresh(depth = 1, wake = TRUE)')
        # A cell first linked from above is woken by a viewer on its own level.
        self.assertLess(refresh.index('if (wake && !lighting_overlay)'), refresh.index('if (!open_air_view)'))
        for line in ('if (icon)\n\t\t\ticon = null', 'if (!(open_air_view in vis_contents))'):
            self.assertIn(line, refresh)
        wake = (ROOT / 'code/modules/multiz/building_lighting.dm').read_text(encoding='utf-8-sig')
        self.assertIn('else if (lighting_overlay || !created_lighting_corners_and_overlays)\n\t\treturn', wake)

class LookUp(unittest.TestCase):
    def setUp(self):
        self.source = (ROOT / 'code/modules/multiz/look_up.dm').read_text(encoding='utf-8-sig')

    def test_included_after_open_air_view(self):
        dme = (ROOT / 'civ13.dme').read_text()
        self.assertLess(dme.index('multiz\\open_air_view.dm'), dme.index('multiz\\look_up.dm'))
        self.assertLess(dme.index('human\\human_life.dm'), dme.index('multiz\\look_up.dm'))

    def test_blockers(self):
        target = self.source.split('/mob/living/human/proc/look_up_target(list/why)\n', 1)[1].split('\n/', 1)[0]
        for guard in ('multiz_level_above(here.z)', 'los_turf_roofed(here)', '(locate(/obj/roof) in here)',
                      'building_open_turf(above)', '(locate(/obj/covers) in above)'):
            self.assertIn(guard, target)

    def test_stops_on_move_and_each_vision_update(self):
        movement = (ROOT / 'code/game/mob/mob_movement.dm').read_text()
        self.assertIn('H.update_laddervision(null)\n\t\tH.stop_looking_up()', movement)
        self.assertIn('/mob/living/human/handle_vision()\n\t. = ..()\n\tlook_up_vision()', self.source)
        vision = self.source.split('/mob/living/human/proc/look_up_vision()\n', 1)[1].split('\n/', 1)[0]
        self.assertIn('look_up_target() != looking_up_at', vision)
        self.assertIn('return key == "looking_up_at" || key == "look_up_label" || ..()', self.source)

    def test_alt_click_up_arrow(self):
        hud = (ROOT / 'code/_onclick/hud/updown_buttons.dm').read_text()
        click = hud.split('/obj/screen/updown/Click(location, control, params)\n', 1)[1].split('\n/', 1)[0]
        self.assertLess(click.index('H.toggle_look_up()'), click.index('H.press_updown(direction)'))
        self.assertIn('direction == UP && params && params2list(params)["alt"]', click)


if __name__ == '__main__':
    unittest.main()
