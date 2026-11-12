"""Offline source checks for belts joining a running line (native probe: probe.dm)."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
CONVEYOR = ROOT / 'code/modules/1713/machinery/conveyor2.dm'
HYDRO = ROOT / 'code/modules/1713/hydroponics.dm'

# Pre-fix placement, frozen as a negative control.
OLD_PLACE = '''/obj/item/conveyor_construct/afterattack(atom/A, mob/user, proximity)
	var/obj/machinery/conveyor/C = new/obj/machinery/conveyor(T,cdir)
	C.id = id
	transfer_fingerprints_to(C)
	qdel(src)
'''


def block(source, header):
    start = source.index(header)
    end = source.find('\n/', start + 1)
    return source[start:end if end != -1 else None]


def placed_state(source, switch_position):
    """Run state of a newly placed linked belt while its switch sits at switch_position."""
    place = block(source, '/obj/item/conveyor_construct/afterattack(')
    after_id = place[place.index('C.id = id'):]
    if 'C.sync_with_switch()' not in after_id:
        return 0
    sync = block(source, '/obj/machinery/conveyor/proc/sync_with_switch()')
    assert re.search(r'if\(S\.id == id\)\n\t+operating = S\.position\n\t+setmove\(\)', sync), sync
    return switch_position


class ConveyorSyncTest(unittest.TestCase):
    def setUp(self):
        self.source = CONVEYOR.read_text(encoding='utf-8')

    def test_new_belt_follows_switch(self):
        for position in (1, -1, 0):
            self.assertEqual(placed_state(self.source, position), position)

    def test_unlinked_belt_is_left_alone(self):
        sync = block(self.source, '/obj/machinery/conveyor/proc/sync_with_switch()')
        self.assertIn('if(!id)\n\t\treturn', sync)

    def test_negative_control_old_belt_stays_off(self):
        self.assertEqual(placed_state(OLD_PLACE + '\n', 1), 0)


class HydroponicsDrainTest(unittest.TestCase):
    def setUp(self):
        self.source = HYDRO.read_text(encoding='utf-8')

    def test_drain_verb_waits_then_empties(self):
        verb = block(self.source, '/obj/structure/hydroponics_tray/verb/drain_reservoir_verb()')
        self.assertIn('set name = "Drain Reservoir"', verb)
        self.assertLess(verb.index('do_after(user, 30, src)'), verb.rindex('drain_reservoir(user)'))
        drain = block(self.source, '/obj/structure/hydroponics_tray/proc/drain_reservoir(mob/user)')
        self.assertIn('water_units = 0', drain)
        self.assertIn('nutrient_units = 0', drain)

    def test_examine_points_to_drain_when_stuck(self):
        examine = block(self.source, '/obj/structure/hydroponics_tray/examine(')
        self.assertIn('Drain Reservoir', examine)


if __name__ == '__main__':
    unittest.main()
