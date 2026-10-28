"""Offline model of the source contracts, not a DM execution or savefile test."""
from dataclasses import dataclass, replace
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
MEAT = (ROOT / "code/modules/reagents/reagent_containers/food/snacks/meat.dm").read_text(encoding="utf-8")
SNACKS = (ROOT / "code/modules/reagents/reagent_containers/food/snacks.dm").read_text(encoding="utf-8")
FOOD = (ROOT / "code/modules/reagents/reagent_containers/food.dm").read_text(encoding="utf-8")
SAVER = (ROOT / "code/modules/persistence/functions.dm").read_text(encoding="utf-8")
LOADER = (ROOT / "code/modules/persistence/loading.dm").read_text(encoding="utf-8")
SAVING = (ROOT / "code/modules/persistence/saving.dm").read_text(encoding="utf-8")
HOLDER = (ROOT / "code/modules/reagents/Chemistry-Holder.dm").read_text(encoding="utf-8")


def section(source, start, end):
    return source.split(start, 1)[1].split(end, 1)[0]


@dataclass
class Food:
    decay: float = 9000
    age: float = 0
    rots: bool = True
    rotten: bool = False
    salted: bool = False


def cut(source, count):
    # Projection of can_cut_preserved_meat and prepare_meat_cutlet below.
    if source.rotten or source.decay <= 0 or source.age >= source.decay or (source.rots and source.age >= source.decay / 2):
        return []
    limit = 18000 if source.salted else 9000
    age = source.age * limit / source.decay
    return [Food(decay=limit, age=age, rotten=age >= limit / 2, salted=source.salted) for _ in range(count)]


def salt(food):
    if food.salted or food.rotten or food.decay <= 0 or food.age >= food.decay or (food.rots and food.age >= food.decay / 2):
        return food
    return replace(food, decay=food.decay * 2, age=food.age * 2, salted=True)


def restore(defaults, saved):
    # Load_Entry constructs a default object, then assigns only present fields.
    return replace(defaults, **saved)


def floor_tick(food):
    # One existing food_decay callback after restoration, not wall-clock simulation.
    if food.decay == 0:
        return food
    age = food.age + 600
    return replace(food, age=age, rotten=food.rotten or (food.rots and age >= food.decay / 2))


class MeatCuttingModelTests(unittest.TestCase):
    def test_source_contracts_bind_both_routes_and_worker(self):
        guard = section(MEAT, "/proc/can_cut_preserved_meat()", "\n/obj/")
        self.assertIn("return !rotten && decay > 0 && decaytimer < decay && (!rots || decaytimer < decay / 2)", guard)
        prepare = section(MEAT, "/proc/prepare_meat_cutlet(", "\n/obj/")
        self.assertRegex(prepare, r"if \(salted_meat\)\s+cutlet\.mark_salted_meat\(\)\s+//[^\n]*\n\s*cutlet\.decaytimer = decaytimer \* cutlet\.decay / decay")
        self.assertIn("if (cutlet.rots && cutlet.decaytimer >= cutlet.decay / 2)", prepare)
        self.assertIn("cutlet.rot()", prepare)
        for source, marker, count in ((MEAT, "/snacks/meat/attackby(", 2), (SNACKS, "/snacks/bearmeat/attackby(", 3)):
            handler = section(source, marker, "\n/obj/")
            self.assertLess(handler.index("if (!can_cut_preserved_meat())"), handler.index("new(src)"))
            self.assertIn(f"for (var/i = 1 to {count})", handler)
            self.assertIn("prepare_meat_cutlet(cutlet)", handler)
        self.assertIn('istype(src, /obj/item/weapon/reagent_containers/food/snacks/bearmeat)', MEAT.split('/proc/can_salt_meat()', 1)[1].split('\n/obj/', 1)[0])
        self.assertIn('if (decay == 0)\n\t\t\treturn', FOOD)
        self.assertIn('decaytimer += 600', FOOD)
        self.assertIn('src.vars[key] != initial(src.vars[key])', SAVER)
        self.assertIn('object.vars[v] = decode_saved_value(savefile, savefile[v])', LOADER)
        self.assertIn('changing_vars += "reagents"', SAVING)
        self.assertIn('var/list/datum/reagent/reagent_list = list()', HOLDER)
        self.assertIn('var/total_volume = 0', HOLDER)

    def test_unsalted_and_salted_slabs_keep_spent_fraction(self):
        for slab, count in ((Food(age=3600), 2), (Food(decay=6000, age=2400, rots=False), 3)):
            with self.subTest(count=count):
                for paid in (False, True):
                    source = salt(slab) if paid else slab
                    pieces = cut(source, count)
                    self.assertEqual(len(pieces), count)
                    for piece in pieces:
                        self.assertAlmostEqual(piece.age / piece.decay, 0.4)
                        self.assertEqual(piece.salted, paid)
                        after_salt = salt(piece)
                        self.assertAlmostEqual(after_salt.age / after_salt.decay, 0.4)
                        if paid:
                            self.assertEqual(after_salt, piece)

    def test_spoilage_and_expiry_boundaries(self):
        self.assertEqual(len(cut(Food(age=4499), 2)), 2)
        for source in (Food(age=4500), Food(age=9000), Food(rotten=True), Food(decay=0), Food(decay=6000, age=6000, rots=False), Food(decay=6000, age=100, rots=False, rotten=True)):
            self.assertEqual(cut(source, 2), [])
        # Bear meat does not rot, but a cutlet at its rot threshold does.
        for age, expected_rotten in ((2999, False), (3000, True), (5999, True)):
            pieces = cut(Food(decay=6000, age=age, rots=False), 3)
            self.assertEqual([p.rotten for p in pieces], [expected_rotten] * 3)
            if expected_rotten:
                self.assertFalse(salt(pieces[0]).salted)

    def test_missing_and_explicit_zero_fields_and_elapsed_age_after_reload(self):
        defaults = Food()
        legacy = restore(defaults, {})
        self.assertEqual((legacy.age, legacy.salted, legacy.decay), (0, False, 9000))
        self.assertEqual(cut(legacy, 2)[0].age, 0)
        explicit_zero_age = restore(defaults, {"age": 0, "salted": False})
        self.assertEqual(cut(explicit_zero_age, 2)[0].age, 0)
        zero_limit = restore(defaults, {"decay": 0, "age": 2400})
        self.assertEqual(floor_tick(zero_limit), zero_limit)
        self.assertEqual(cut(zero_limit, 2), [])
        restored = restore(defaults, {"decay": 18000, "age": 7200, "salted": True})
        later = floor_tick(restored)
        self.assertEqual(later.age, 7800)
        for piece in cut(later, 2):
            self.assertAlmostEqual(piece.age / piece.decay, 7800 / 18000)
            self.assertTrue(piece.salted)
        self.assertEqual(cut(floor_tick(replace(restored, age=8700)), 2), [])

if __name__ == "__main__":
    unittest.main()
