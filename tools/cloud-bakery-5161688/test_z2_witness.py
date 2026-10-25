"""Fixed secondary-level evidence only; z1 failure must remain fatal."""
from pathlib import Path
import unittest
ROOT=Path(__file__).parent
SCENE=(ROOT/'changed-source/filming/scene.dm').read_text()

class Z2Witness(unittest.TestCase):
    def test_only_fixed_six_witnesses_at_z2_before_failure(self):
        helper=SCENE.split('/proc/filming_assert_authored_map(phase)')[1].split('/client/New()')[0]
        diagnostic=helper.split('// Observe only the same six')[1].split('\tvar/evidence')[0]
        self.assertIn('if (phase == "world New before fixture initialization")',diagnostic)
        self.assertIn('for (var/list/row in witnesses)',diagnostic)
        self.assertIn('locate(row[1], row[2], 2)',diagnostic)
        self.assertNotIn(' in world',diagnostic)
        self.assertNotIn('ok =',diagnostic)
        self.assertNotIn('new /',diagnostic)
        self.assertIn('"z2_diagnostic" = z2_observed',helper)
        self.assertLess(helper.index('z2_observed +='),helper.index('filming_check(ok,'))

    def test_z1_dimensions_and_camera_remain_exact(self):
        self.assertIn('world.maxx == 15 && world.maxy == 13 && world.maxz == 1',SCENE)
        self.assertIn('var/turf/T = locate(row[1], row[2], 1)',SCENE)
        self.assertIn('eye = locate(7, 7, 1)',SCENE)
        self.assertIn('loc = locate(7, 7, 1)',SCENE)
        self.assertIn('filming_check(ok, "authored map witnesses [phase]")',SCENE)
        self.assertNotIn('eye = locate(7, 7, 2)',SCENE)

    def test_z2_metadata_is_bounded_and_contains_no_names(self):
        diagnostic=SCENE.split('// Observe only the same six')[1].split('\tvar/evidence')[0]
        for token in ('copytext(actual_turf, 1, 129)','copytext(actual_area, 1, 129)','O.loc == T'):
            self.assertIn(token,diagnostic)
        for forbidden in ('.name','.key','.ckey','.icon_state','text2file','sleep(','ChangeTurf','world.maxz ='):
            self.assertNotIn(forbidden,diagnostic)

if __name__=='__main__':unittest.main()
