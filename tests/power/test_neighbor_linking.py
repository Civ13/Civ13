"""Offline source contracts + graph model, not native cable gameplay evidence."""
from pathlib import Path
import re
import unittest
ROOT = Path(__file__).resolve().parents[2]
CABLE = ROOT / 'code/modules/1713/machinery/cables.dm'
SHAPES = ROOT / 'code/modules/1713/machinery/cable_shapes.dm'
COIL = ROOT / 'code/modules/1713/machinery/cables_types.dm'
STRUCTURE = ROOT / 'code/game/objects/structures.dm'

def body(path, declaration):
    return path.read_text().split(declaration, 1)[1].split('\n/obj/', 1)[0]

class NeighborLinking(unittest.TestCase):
    def setUp(self):
        self.helper = body(SHAPES, '/obj/structure/cable/proc/link_end_neighbors')
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

    def test_ends_match_back_and_crossing_exclusion(self):
        # Each end joins only a neighbour whose end points back, so a straight
        # crossing on one tile stays insulated and corners join like straights.
        self.assertIn('for (var/dir in cable_ends())', self.helper)
        self.assertIn('var/back = cable_reverse_dir(dir)', self.helper)
        self.assertIn('neighbor == src || !(back in neighbor.cable_ends())', self.helper)
        self.assertIn('var/turf/T = get_step(src, dir)', self.helper)
        self.assertNotIn('tiledir', self.helper)

    def test_callers_delegate_instead_of_duplicate_scans(self):
        self.assertIn('C.link_end_neighbors(user)', self.placement)
        self.assertIn('powersource.link_end_neighbors(user, FALSE)', self.machine)
        for caller in (self.placement, self.machine):
            self.assertNotIn('opdir1', caller)
            self.assertNotIn('list_cmp(', caller)

    def test_feedback_is_optional(self):
        self.assertIn('notify = TRUE', self.helper)
        self.assertIn('user && notify && joined', self.helper)
        self.assertIn('You connect the two cables.', self.helper)

    def test_supply_rebuild_stays_after_secured_junction(self):
        self.assertNotIn('rebuild_supply()', self.helper)
        self.assertNotIn('rebuild_supply()', self.machine)
        self.assertLess(self.placement.index('link_end_neighbors'), self.placement.index('junction.connect_cables()'))
        self.assertLess(self.placement.index('junction.connect_cables()'), self.placement.index('C.rebuild_supply()'))
        self.assertIn('if (junction.anchored)', self.placement)

    def test_payment_and_machine_attachment_stay_in_callers(self):
        self.assertEqual(self.placement.count('amount -= 1'), 1)
        self.assertLess(self.placement.index('amount -= 1'), self.placement.index('link_end_neighbors'))
        self.assertLess(self.machine.index('if (!powersource)'), self.machine.index('powersource.connections += src'))
        self.assertLess(self.machine.index('powersource.connections += src'), self.machine.index('link_end_neighbors'))
        self.assertIn('return C', self.placement)

class AccountingFixturePreparation(unittest.TestCase):
    def test_accounting_boundary_excludes_crafting_not_power(self):
        source = CABLE.read_text()
        start = source.index('/obj/structure/cable/proc/get_connections()')
        end = source.index('/obj/item/stack/material/plastic/proc/make_insulated_cable(', start)
        selected = source[start:end]
        for proc in ('rebuild_supply(', 'draw_cable_power(', 'power_on(', 'power_off(', 'forceMove('):
            self.assertIn(proc, selected)
        self.assertNotIn('/obj/item/stack/material/plastic', selected)
        runner = (ROOT / 'scripts/test-power.ps1').read_text()
        self.assertIn('$source.Substring($start, $end - $start)', runner)
        self.assertIn("throw 'Production network end boundary not found.'", runner)

    def test_real_smart_predicates_and_cut_restore_assertions(self):
        source = (ROOT / 'code/modules/1713/smart_home.dm').read_text()
        start = source.index('/obj/proc/smart_power_cut()')
        end = source.index('/obj/structure/proc/smart_kind()', start)
        self.assertIn('return smart_off && smart_hub_id', source[start:end])
        runner = (ROOT / 'scripts/test-power.ps1').read_text()
        self.assertIn('$smartSource.Substring($smartStart, $smartEnd - $smartStart)', runner)
        fixture = (ROOT / 'tests/power/fixture.dm').read_text()
        for label in ('smart cut refuses draw', 'smart cut releases reservation',
                      'smart restore permits draw', 'smart restore reserves once'):
            self.assertIn('check("' + label, fixture)

if __name__ == '__main__':
    unittest.main()
