"""Offline integration wiring contracts; native gameplay is a separate CI gate."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]

class MiningIntegrationContracts(unittest.TestCase):
    def test_default_disabled_and_both_authorities_require_native_moving_owner(self):
        movement = (ROOT / 'code/game/mob/living/carbon/human/subtile_movement.dm').read_text()
        mining = (ROOT / 'code/game/turfs/floor_attackby.dm').read_text()
        self.assertIn('human_subtile_enabled = FALSE', movement)
        self.assertIn('owner.mob == src && owner.canmove && owner.moving', movement)
        self.assertIn('client.mob == src && client.canmove && client.moving', mining)
        client = (ROOT / 'code/game/mob/mob_movement.dm').read_text()
        admission = client.index('\t\tmoving = TRUE')
        move = client.index('. = H.SelfMove(n, direct, subtile_deadline)', admission)
        cleanup = client.index('\n\t\tmoving = FALSE', move)
        self.assertLess(admission, move)
        self.assertLess(move, cleanup)

    def test_probe_enters_collision_through_movement_and_preserves_client_authority(self):
        source = (ROOT / 'tests/human_subtile/mining.dm').read_text()
        self.assertNotIn('H.Bump(', source)
        self.assertNotIn('H.try_bump_mining(', source)
        self.assertNotIn('T.start_pickaxe_mining(', source)
        self.assertNotRegex(source, r'H\.step_[xy]\s*=\s*\d')
        self.assertIn('if (client)\n\t\treturn ..()', source)
        self.assertIn('C.Move(get_step(H, direction), direction, FALSE)', source)
        for label in ('mining_native_collision_dispatch', 'mining_offset_snapshot_exact',
                      'mining_native_client_moving_owned_and_released',
                      'mining_repeat_cannot_replace_owner', 'mining_drift_is_physical',
                      'mining_drift_rejected', 'mining_drift_cleanup'):
            self.assertIn('"' + label + '"', source)
        wrapper = (ROOT / 'tests/human_subtile/probe.dm').read_text()
        self.assertIn('if (world.params["mining_integration"])\n\t\t\thuman_subtile_fixture_mining()', wrapper)
        self.assertIn('"mining_checks" = human_subtile_mining_checks', wrapper)

    def test_ci_executes_normal_and_specific_position_control(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text()
        self.assertIn('run.py --suite mining --byond-bin', workflow)
        self.assertIn('run.py --suite mining --control mining-position --byond-bin', workflow)

if __name__ == '__main__':
    unittest.main(verbosity=2)
