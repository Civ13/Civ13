"""Offline source contracts + graph model, not native cable gameplay evidence."""
from pathlib import Path
import re
import unittest
ROOT = Path(__file__).resolve().parents[2]
CABLE = ROOT / 'code/modules/1713/machinery/cables.dm'
COIL = ROOT / 'code/modules/1713/machinery/cables_types.dm'
STRUCTURE = ROOT / 'code/game/objects/structures.dm'

def body(path, declaration):
    return path.read_text().split(declaration, 1)[1].split('\n/obj/', 1)[0]

class NeighborLinking(unittest.TestCase):
    def setUp(self):
        self.helper = body(CABLE, '/obj/structure/cable/proc/link_straight_neighbors')
        self.placement = body(COIL, '/obj/item/stack/cable_coil/proc/place_turf')
        self.machine = body(STRUCTURE, '/obj/structure/proc/connect_cable')

    def test_shared_helper_symmetric_and_idempotent(self):
        self.assertIn('neighbor.connections |= src', self.helper)
        self.assertIn('connections |= neighbor', self.helper)
        self.assertNotIn('connections +=', self.helper)
        # Model union invariants, independent of native list behavior.
        a, b = set(), set()
        for _ in range(3):
            a.add('b'); b.add('a')
        self.assertEqual((a, b), ({'b'}, {'a'}))

    def test_axis_order_and_crossing_exclusion(self):
        self.assertIn('directions = list(EAST, WEST)', self.helper)
        self.assertIn('directions = list(NORTH, SOUTH)', self.helper)
        self.assertIn('neighbor == src || neighbor.tiledir != tiledir', self.helper)
        self.assertIn('get_turf(get_step(src, directions[i]))', self.helper)
        self.assertRegex(self.helper, r'else\n\t\treturn\n\tfor')

    def test_callers_delegate_instead_of_duplicate_scans(self):
        self.assertIn('C.link_straight_neighbors(user)', self.placement)
        self.assertIn('powersource.link_straight_neighbors(user, FALSE)', self.machine)
        for caller in (self.placement, self.machine):
            self.assertNotIn('opdir1', caller)
            self.assertNotIn('list_cmp(', caller)

    def test_existing_message_asymmetry_is_explicit(self):
        self.assertIn('notify_second = TRUE', self.helper)
        self.assertIn('user && (i == 1 || notify_second)', self.helper)
        self.assertIn('You connect the two cables.', self.helper)

    def test_supply_rebuild_stays_after_secured_junction(self):
        self.assertNotIn('rebuild_supply()', self.helper)
        self.assertNotIn('rebuild_supply()', self.machine)
        self.assertLess(self.placement.index('link_straight_neighbors'), self.placement.index('junction.connect_cables()'))
        self.assertLess(self.placement.index('junction.connect_cables()'), self.placement.index('C.rebuild_supply()'))
        self.assertIn('if (junction.anchored)', self.placement)

    def test_payment_and_machine_attachment_stay_in_callers(self):
        self.assertEqual(self.placement.count('amount -= 1'), 1)
        self.assertLess(self.placement.index('amount -= 1'), self.placement.index('link_straight_neighbors'))
        self.assertLess(self.machine.index('if (!powersource)'), self.machine.index('powersource.connections += src'))
        self.assertLess(self.machine.index('powersource.connections += src'), self.machine.index('link_straight_neighbors'))
        self.assertIn('return C', self.placement)

if __name__ == '__main__':
    unittest.main()
