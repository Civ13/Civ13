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

    def test_other_items_keep_inherited_generic_fuel_behavior(self):
        self.assertIn("if (W.flammable)", self.base)
        self.assertNotIn("istype(src, /obj/structure/brazier/stone)", self.base)
        self.assertIn("if (!is_disposable_organic(W))\n\t\treturn ..()", self.action)

    def test_existing_fuel_and_projectiles_precede_catch_all(self):
        guard = self.base.index("if (W.flammable)")
        for path in ("ore/coal", "ore/charcoal", "material/wood", "material/bamboo",
                     "stack/dung", "weapon/branch", "material/leaf", "ammo_casing/arrow",
                     "ammo_casing/bolt"):
            self.assertLess(self.base.index(path), guard)


class PostDropProjection(unittest.TestCase):
    """Project the actual post-drop disjuncts; does not execute BYOND callbacks."""
    def refuses(self, source=TEXT, **state):
        start = source.index("// Drop callbacks may move or fill the item")
        guard = source[start:].splitlines()[1].strip()
        assert guard.startswith("if (") and guard.endswith(")"), guard
        expressions = guard[4:-1].split(" || ")
        values = {
            "QDELETED(src)": state.get("brazier_deleted", False),
            "!on": state.get("extinguished", False),
            "loc != brazier_loc": state.get("brazier_moved", False),
            "QDELETED(user)": state.get("user_deleted", False),
            "user.loc != drop_site": state.get("user_moved", False),
            "QDELETED(W)": state.get("item_deleted", False),
            "W.loc != drop_site": state.get("item_moved", False),
            "length(W.contents)": state.get("item_filled", False),
        }
        assert set(expressions) == set(values), expressions
        return any(values[item] for item in expressions)

    def test_each_callback_change_refuses_without_payment_or_deletion(self):
        # Rejection returns before qdel and before fuel credit in the source.
        action = proc("/obj/structure/brazier/stone/attackby(obj/item/W, mob/user)")
        guard = action.index("// Drop callbacks may move or fill the item")
        self.assertEqual(action[guard:].splitlines()[2], "\t\t\treturn")
        self.assertLess(guard, action.index("qdel(W)"))
        self.assertLess(action.index("qdel(W)"), action.index("fuel += 5"))
        for key in ("brazier_deleted", "extinguished", "brazier_moved", "user_deleted",
                    "user_moved", "item_deleted", "item_moved", "item_filled"):
            with self.subTest(callback_effect=key):
                self.assertTrue(self.refuses(**{key: True}))
        self.assertFalse(self.refuses())

    def test_omitted_post_drop_check_is_detected(self):
        for check in (" || W.loc != drop_site", " || length(W.contents)", " || !on"):
            with self.subTest(check=check):
                start = TEXT.index("// Drop callbacks may move or fill the item")
                altered = TEXT[:start] + TEXT[start:].replace(check, "", 1)
                self.assertNotEqual(altered, TEXT)
                with self.assertRaises(AssertionError):
                    self.refuses(source=altered)

    def test_original_ground_site_is_snapshotted_before_unequip(self):
        action = proc("/obj/structure/brazier/stone/attackby(obj/item/W, mob/user)")
        self.assertLess(action.index("var/turf/drop_site = get_turf(user)"), action.index("!user.unEquip(W)"))
        self.assertIn("!drop_site || user.loc != drop_site", action)


if __name__ == "__main__":
    unittest.main()
