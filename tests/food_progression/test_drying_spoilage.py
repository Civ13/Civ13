"""Offline source contracts and a model of rack conversion admission."""
from dataclasses import dataclass, replace
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
RACK = (ROOT / "code/modules/1713/production.dm").read_text(encoding="utf-8")
FOOD = (ROOT / "code/modules/reagents/reagent_containers/food.dm").read_text(encoding="utf-8")
SAVER = (ROOT / "code/modules/persistence/functions.dm").read_text(encoding="utf-8")
LOADER = (ROOT / "code/modules/persistence/loading.dm").read_text(encoding="utf-8")


@dataclass(frozen=True)
class Input:
    limit: int | None = 9000  # Encoded in the rack's item name, not live decay.
    age: int = 0
    rots: bool = True
    rotten: bool = False
    salted: bool = False
    protein: int = 1
    progress: int = 150


def conversion_tick(item):
    # Model of the guard and one attempted conversion; input stays owned on refusal.
    if (item.rotten or item.limit is None or item.limit < 0 or
            (item.limit > 0 and (item.age >= item.limit or
                                 (item.rots and item.age >= item.limit / 2)))):
        return item, None
    return None, {"salted": item.salted, "age_fraction": item.age / item.limit if item.limit else None,
                  "protein": item.protein}


class DryingSpoilageTests(unittest.TestCase):
    def test_source_guards_before_progress_and_product_creation(self):
        guard = RACK.split('/proc/drying_input_is_safe(', 1)[1].split('\n/obj/', 1)[0]
        for required in ('F.rotten || !isnum(F.decaytimer)', 'findtext(F.name, "DECAY_")',
                         '!isnum(original_decay) || original_decay < 0',
                         'F.decaytimer >= original_decay',
                         'F.rots && F.decaytimer >= original_decay / 2'):
            self.assertIn(required, guard)
        worker = RACK.split('/proc/dry_process(', 1)[1].split('\n/obj/', 1)[0]
        refusal = worker.index('if (!drying_input_is_safe(I))')
        self.assertLess(refusal, worker.index('set_dry_timer(I, dry_timer)'))
        self.assertLess(refusal, worker.index('P = new I.dried_type(null)'))
        self.assertIn('if (!drying_input_is_safe(I))\n\t\t\t\t\t\tcontinue', worker)
        refill = RACK.split('/proc/refill()', 1)[1].split('\n/obj/', 1)[0]
        self.assertIn('put_in_place(S, pos, sizeHV, is_rotated, TRUE)', refill)
        self.assertIn('var/rotten = FALSE', FOOD)
        self.assertIn('var/decaytimer = 0', FOOD)
        self.assertIn('src.vars[key] != initial(src.vars[key])', SAVER)
        self.assertIn('object.vars[v] = decode_saved_value(savefile, savefile[v])', LOADER)

    def test_salted_and_unsalted_rot_and_expiry_thresholds(self):
        for limit, salted in ((9000, False), (18000, True)):
            for age, allowed in ((limit // 2 - 1, True), (limit // 2, False),
                                 (limit - 1, False), (limit, False), (limit + 1, False)):
                with self.subTest(limit=limit, age=age):
                    item = Input(limit=limit, age=age, salted=salted, protein=0)
                    remaining, product = conversion_tick(item)
                    if allowed:
                        self.assertIsNone(remaining)
                        self.assertEqual(product['salted'], salted)
                        self.assertEqual(product['protein'], 0)
                        self.assertAlmostEqual(product['age_fraction'], age / limit)
                    else:
                        self.assertEqual(remaining, item)
                        self.assertIsNone(product)

    def test_refill_spoiled_flag_expiry_and_missing_legacy_fields(self):
        # Missing old fields reconstruct to rawcutlet defaults, while present
        # spoiled state remains authoritative even with zero saved age.
        legacy = Input()
        self.assertIsNotNone(conversion_tick(legacy)[1])
        for item in (replace(legacy, rotten=True), replace(legacy, rotten=True, salted=True, limit=18000),
                     replace(legacy, rots=False, age=9000), replace(legacy, limit=None),
                     replace(legacy, limit=-1)):
            with self.subTest(item=item):
                remaining, product = conversion_tick(item)
                self.assertEqual(remaining, item)
                self.assertIsNone(product)
                # Refusal neither consumes nor advances the paid input.
                self.assertEqual((remaining.protein, remaining.progress), (item.protein, item.progress))
        self.assertIsNotNone(conversion_tick(replace(legacy, limit=0))[1])
        self.assertIsNone(conversion_tick(replace(legacy, limit=0, rotten=True))[1])


if __name__ == '__main__':
    unittest.main()
