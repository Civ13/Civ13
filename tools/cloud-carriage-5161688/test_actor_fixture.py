"""Source-only lifecycle contracts; not a native gameplay proof."""
from pathlib import Path
import hashlib, unittest
HERE=Path(__file__).resolve().parent
class ActorFixture(unittest.TestCase):
    def test_only_fixture_subtype_adapts_disconnected_sleep(self):
        s=(HERE/'changed-source/filming/scene.dm').read_bytes()
        self.assertIn(b'var/mob/living/human/intro_actor/intro_driver',s)
        self.assertIn(b'/mob/living/human/intro_actor/ssd_check()\n\treturn FALSE',s)
        self.assertNotIn(b'/mob/living/human/ssd_check()',s)
        self.assertNotIn(b'/mob/living/human/intro_actor/Life()',s)
        self.assertIn(b'intro_driver.Life()',s)
        self.assertIn(b'intro_horse.Life()',s)
        self.assertIn(b'!intro_driver.client && !intro_driver.ckey && !intro_driver.incapacitated()',s)
    def test_actions_byte_exact_except_bounded_scalar_diagnostic(self):
        s=(HERE/'changed-source/filming/actions.dm').read_bytes()
        self.assertEqual(s.count(DIAGNOSTIC+GUARD),1)
        self.assertLess(len(DIAGNOSTIC),1024)
        self.assertEqual(hashlib.sha256(s.replace(DIAGNOSTIC,b'').replace(b'\tintro_lease_stopping()\n',b'').replace(b'INTRO_TRANSPORT_RELEASED FALSE',b'INTRO_TRANSPORT_RELEASED TRUE')).hexdigest(),BEFORE)
        for field in (b'"driver_bound"',b'"vehicle_bound"',b'"south_facing"',b'"incapacitated"',b'"has_client"',b'"held_reins"'):
            self.assertIn(field,DIAGNOSTIC)

DIAGNOSTIC=b'\ttext2file(json_encode(list("phase" = "before_driver_guard", "carriage" = "\\ref[C]", "driver" = "\\ref[H]", "driver_bound" = C.driver == H, "vehicle_bound" = H.driver_vehicle == C, "driver_dir" = H.dir, "south_facing" = H.dir == SOUTH, "incapacitated" = H.incapacitated(), "stat" = H.stat, "sleeping" = H.sleeping, "paralysis" = H.paralysis, "ssd" = H.ssd_check(), "has_client" = !!H.client, "held_reins" = H.get_active_hand() == C.dwheel)), "intro-checks.txt")\n'
GUARD=b'\tcheck(C.driver == H && H.driver_vehicle == C && H.dir == SOUTH && !H.incapacitated(), "native driver and facing")\n'
BEFORE='8cb34993b22624457d67ce99b9bd1398ae61f7d90e04950f81c8f16b64348ade'
