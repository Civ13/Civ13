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
RIDE = (ROOT / 'code/modules/craft/vehicle_offset_ride.dm').read_text(encoding='utf-8')
FRAME = (ROOT / 'code/modules/craft/vehicle_offset_frame.dm').read_text(encoding='utf-8')


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
        for label in ('moto_stops_flush_at_wall', 'coasts_to_a_stop', 'turn_keeps_sideways_offset', 'save_snaps_ridden_vehicles', 'car_moves_as_one', 'wall_stops_flush', 'rider_stays_seated', 'carriage_crossed', 'snap_all_before_save'):
            self.assertIn(label, PROBE)

    def test_ride_included_after_core(self):
        core = DME.index('craft\\vehicle_offset.dm')
        self.assertLess(core, DME.index('craft\\vehicle_offset_ride.dm'))

    def test_ride_falls_back_to_tile_loop(self):
        loop = proc(RIDE, '/obj/structure/vehicle/movementloop(')
        self.assertIn('if (!axis || !vehicle_offset_drives())', loop)
        self.assertIn('return ..()', loop)
        drives = proc(RIDE, '/obj/structure/vehicle/proc/vehicle_offset_drives(')
        self.assertIn('persistence_save_in_progress', drives)
        self.assertIn('O.watched()', drives)
        self.assertIn('key == "offset_mover"', RIDE)
        self.assertNotIn('spawn(', RIDE)

    def test_carried_riders_make_no_footsteps(self):
        turf = (ROOT / 'code/game/turfs/turf.dm').read_text(encoding='utf-8')
        self.assertIn('!H.carried_by_vehicle()', turf)
        carried = proc(RIDE, '/mob/living/human/proc/carried_by_vehicle(')
        for needle in ('buckled', 'V.ontop', 'F.axis.moving', 'F.axis.transporting'):
            self.assertIn(needle, carried)
        for label in ('driver_makes_no_footsteps', 'walker_keeps_footsteps', 'moving_car_passenger_carried'):
            self.assertIn(label, PROBE)

    def test_bicycles_and_rafts_roll_by_pixels(self):
        self.assertIn('/obj/structure/vehicle/bicycle\n\toffset_drive = TRUE', RIDE)
        # Pedal airships fly; aircraft are a later phase.
        self.assertIn('/obj/structure/vehicle/bicycle/airship\n\toffset_drive = FALSE', RIDE)
        bike = proc(RIDE, '/obj/structure/vehicle/bicycle/movementloop(')
        self.assertIn('return ..()', bike)
        self.assertIn('pedal_next_move = world.time', bike)
        raft = proc(RIDE, '/obj/structure/vehicle/raft/processmove(')
        self.assertIn('if (!vehicle_offset_drives())', raft)
        self.assertIn('return ..()', raft)
        self.assertIn('key == "offset_paddling"', RIDE)
        for label in ('bike_pedals_by_pixels', 'bike_pays_stamina_per_tile', 'raft_paddles_its_speed', 'raft_drifts_to_a_stop', 'raft_stops_at_the_shore', 'unwatched_raft_paddles_by_tiles'):
            self.assertIn(label, PROBE)

    def test_carriages_roll_by_pixels(self):
        self.assertIn('/obj/structure/vehicle/carriage\n\toffset_drive = TRUE', RIDE)
        loop = proc(RIDE, '/obj/structure/vehicle/carriage/movementloop(')
        self.assertIn('return ..()', loop)
        self.assertIn('next_step = world.time', loop)
        self.assertIn('return facing', proc(RIDE, '/obj/structure/vehicle/carriage/vehicle_offset_heading('))
        self.assertIn('hitched_cart', proc(RIDE, '/obj/structure/vehicle/carriage/vehicle_offset_aboard('))
        self.assertIn('vehicle_offset_release()', proc(RIDE, '/obj/structure/vehicle/carriage/updatepassdir('))
        for label in ('coach_rolls_by_pixels', 'coach_stops_flush_before_a_wall', 'coach_turn_squares_first', 'coach_cart_hitched'):
            self.assertIn(label, PROBE)
    def test_frame_vehicles_roll_by_pixels(self):
        self.assertLess(DME.index('vehicle_offset_hull.dm'), DME.index('vehicle_offset_frame.dm'))
        loop = proc(FRAME, '/obj/structure/vehicleparts/axis/movementloop(')
        self.assertIn('return ..()', loop)
        self.assertIn('if (!vehicle_offset_drives())', loop)
        # Aircraft and the axes of one-object vehicles stay on whole tiles; frame ships sail by pixels.
        for kind in ('aircraft', 'boat', 'bike', 'carriage'):
            self.assertIn('/obj/structure/vehicleparts/axis/%s\n\toffset_drive = FALSE' % kind, FRAME)
        drives = proc(FRAME, '/obj/structure/vehicleparts/axis/proc/vehicle_offset_drives(')
        for guard in ('persistence_save_in_progress', 'tow_out', 'tow_in', 'vehicle_offset_has_trailer()'):
            self.assertIn(guard, drives)
        # Its own crash checks run once per tile, as it starts to overlap the tiles ahead.
        self.assertIn('A.do_vehicle_check()', proc(FRAME, '/datum/vehicle_offset/axis/can_cover('))
        self.assertIn('glide_give_back(glide_was, null)', proc(FRAME, '/obj/structure/vehicleparts/axis/glide_step('))
        self.assertIn('vehicle_offset_release()', proc(FRAME, '/obj/structure/vehicleparts/axis/do_matrix('))
        self.assertNotIn('spawn(', FRAME)
        for key in ('offset_mover', 'offset_coast', 'offset_last_tick', 'offset_committing', 'offset_quiet_stop'):
            self.assertIn('key == "%s"' % key, FRAME)
        self.assertIn('F.axis.offset_coast > 0', proc(RIDE, '/mob/living/human/proc/carried_by_vehicle('))
        for label in ('frame_car_rolls_by_pixels', 'frame_car_coasts_square', 'frame_car_turn_squares_first', 'frame_car_stops_flush_before_a_wall', 'frame_car_unwatched_tile_steps'):
            self.assertIn(label, PROBE)

    def test_frame_ships_sail_by_pixels(self):
        ship = (ROOT / 'code/modules/craft/vehicle_offset_ship.dm').read_text(encoding='utf-8')
        loop = (ROOT / 'code/modules/1713/machinery/modular_vehicles/ships/axis.dm').read_text(encoding='utf-8')
        self.assertLess(DME.index('vehicle_offset_frame.dm'), DME.index('vehicle_offset_ship.dm'))
        self.assertIn('/obj/structure/vehicleparts/axis/ship\n\toffset_drive = TRUE', ship)
        self.assertIn('if (ship_offset_movementloop())', proc(loop, '/obj/structure/vehicleparts/axis/ship/movementloop('))
        self.assertIn('return vehicle_offset_filter_transporting()', proc(loop, '/obj/structure/vehicleparts/axis/ship/add_transporting('))
        # The tile loop's checks run once per tile, before do_vehicle_check().
        cover = proc(FRAME, '/datum/vehicle_offset/axis/can_cover(')
        self.assertLess(cover.index('A.vehicle_offset_tile_ahead()'), cover.index('A.do_vehicle_check()'))
        self.assertIn('check_sails()', proc(ship, '/obj/structure/vehicleparts/axis/ship/vehicle_offset_tile_ahead('))
        self.assertIn('MC.check_naval_mines()', proc(ship, '/obj/structure/vehicleparts/axis/ship/vehicle_offset_stepped('))
        self.assertIn('offset_turn = tdir', proc(ship, '/obj/structure/vehicleparts/axis/ship/do_matrix('))
        self.assertIn('key == "offset_turn"', ship)
        self.assertNotIn('spawn(', ship)
        for label in ('ship_sails_her_pace', 'ship_turn_held', 'ship_comes_about_at_the_square', 'ship_stops_flush_at_the_shore'):
            self.assertIn(label, PROBE)

    def test_turns_swing_without_a_jump(self):
        glide = (ROOT / 'code/modules/craft/glide.dm').read_text(encoding='utf-8')
        axis = (ROOT / 'code/modules/1713/machinery/modular_vehicles/axis.dm').read_text(encoding='utf-8')
        matrix = proc(axis, '/obj/structure/vehicleparts/axis/proc/do_matrix(')
        # Glide is set before the moves (the engine draws a move at the glide it has then).
        self.assertLess(matrix.index('glide_turn_hold(was_at)'), matrix.index('transforming_vehicle = TRUE'))
        self.assertIn('craft_glide_holder = glide_was', matrix)
        self.assertIn('glide_slide(M, dx, dy, time, SINE_EASING)', proc(glide, '/obj/structure/vehicleparts/axis/proc/glide_turn('))


if __name__ == '__main__':
    unittest.main()
