"""Offline source-contract checks; gameplay behavior still requires BYOND tests."""
from pathlib import Path
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "code/modules/1713/siege/fire.dm"
TEXT = SOURCE.read_text(encoding="utf-8")


def proc(path):
    start = TEXT.index(path + "\n")
    end = TEXT.find("\n/obj/", start + len(path))
    return TEXT[start:end if end >= 0 else None]


class StoneBrazierSourceContract(unittest.TestCase):
    def setUp(self):
        self.allowed = proc("/obj/structure/brazier/stone/proc/is_disposable_organic(obj/item/I)")
        self.action = proc("/obj/structure/brazier/stone/attackby(obj/item/W, mob/user)")
        self.base = proc("/obj/structure/brazier/attackby(obj/item/weapon/W as obj, mob/user as mob)")

    def test_narrow_food_and_butchery_type_roots(self):
        for path in ("food/snacks", "chicken_carcass", "pigleg", "stack/sinew",
                     "material/bone", "material/rawhide", "material/pelt"):
            self.assertIn(path, self.allowed)
        for path in ("/mob/", "/obj/item/weapon/storage", "/food/drinks"):
            self.assertNotIn(path, self.allowed)

    def test_unlit_refuses_before_consumption(self):
        self.assertLess(self.action.index("if (!on)"), self.action.index("stack.use(1)"))
        self.assertLess(self.action.index("if (!on)"), self.action.index("qdel(W)"))
        self.assertIn("before disposing", self.action)

    def test_held_removable_and_empty(self):
        for guard in ("W.loc != user", "user.get_active_hand() != W", "length(W.contents)",
                      "!user.canUnEquip(W)", "W.nodrop", "W.nodrop_special_check()"):
            self.assertIn(guard, self.action)
        self.assertLess(self.action.index("!user.unEquip(W)"), self.action.index("qdel(W)"))

    def test_one_stack_unit_and_small_fixed_credit(self):
        self.assertIn("stack.use(1)", self.action)
        self.assertLess(self.action.index("stack.use(1)"), self.action.index("fuel += 5"))
        self.assertLess(self.action.index("qdel(W)"), self.action.index("fuel += 5"))
        self.assertIn("fuel += (80)*W.amount", self.base)

    def test_other_stone_items_avoid_inherited_catch_all(self):
        guard = self.base.index("if (istype(src, /obj/structure/brazier/stone))")
        self.assertLess(guard, self.base.index("if (W.flammable)", guard))
        self.assertIn("return ..()", self.base[guard:self.base.index("if (W.flammable)", guard)])

    def test_existing_fuel_and_projectiles_precede_catch_all(self):
        guard = self.base.index("if (istype(src, /obj/structure/brazier/stone))")
        for path in ("ore/coal", "ore/charcoal", "material/wood", "material/bamboo",
                     "stack/dung", "weapon/branch", "material/leaf", "ammo_casing/arrow",
                     "ammo_casing/bolt"):
            self.assertLess(self.base.index(path), guard)


if __name__ == "__main__":
    unittest.main()
