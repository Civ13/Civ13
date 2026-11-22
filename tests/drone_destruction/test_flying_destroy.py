"""Flying drones break and are wrecked when damage empties their health (#6656)."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / "code/game/objects/items/devices/drone.dm").read_text(encoding="utf-8-sig")


def block(header):
    start = SOURCE.index(header)
    nxt = re.search(r"\n(?=\S)", SOURCE[start + len(header):])
    return SOURCE[start:start + len(header) + nxt.start()] if nxt else SOURCE[start:]


class FlyingDroneDestructionTest(unittest.TestCase):
    def test_airborne_hits_run_the_damage_logic(self):
        bullet = block("/obj/structure/drone/bullet_act(var/obj/item/projectile/proj)")
        airborne = bullet[bullet.index("if (flying)"):bullet.index("\telse\n")]
        hit = airborne.index("health -= proj.damage * 0.1")
        self.assertIn("try_destroy()", airborne[hit:airborne.index("else if (prob(10))")])

    def test_wrecked_flying_drone_is_deleted_after_its_payload(self):
        destroy = block("/obj/structure/drone/flying/try_destroy()")
        self.assertLess(destroy.index("..()"), destroy.index("qdel(src)"))
        self.assertIn("if (health <= 0 && !QDELETED(src))", destroy)
        # The manual payload release must not delete the drone.
        self.assertNotIn("qdel(src)", block("/obj/structure/drone/flying/do_special()"))

    def test_explosion_crash_skips_a_deleted_drone(self):
        ex_act = block("/obj/structure/drone/ex_act(severity)")
        self.assertIn("if (crash && !QDELETED(src))", ex_act)


if __name__ == "__main__":
    unittest.main()
