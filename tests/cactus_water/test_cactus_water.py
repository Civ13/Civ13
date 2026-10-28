"""Offline source contracts and accounting projections; not native DM execution."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
WILD = (ROOT / "code/game/objects/structures/wild.dm").read_text(encoding="utf-8")
HOLDER = (ROOT / "code/modules/reagents/Chemistry-Holder.dm").read_text(encoding="utf-8")
PERSISTENCE = (ROOT / "code/modules/persistence/functions.dm").read_text(encoding="utf-8")


def proc(source, path):
    match = re.search(rf"(?m)^{re.escape(path)}[^\n]*\n(?:(?:\t[^\n]*|)\n)*", source)
    if not match:
        raise AssertionError(f"missing {path}")
    return match.group()


def draw(stock, free, *, accepted=None, blocked=False):
    """Project the bounded debit and failed-add refund in the source."""
    if blocked or stock <= 0:
        return stock, 0
    amount = min(5, stock, free)
    if amount < 0.01:
        return stock, 0
    stock -= amount
    actual = amount if accepted is None else max(0, min(amount, accepted))
    return stock + amount - actual, actual


class CactusWater(unittest.TestCase):
    def test_source_contract(self):
        action = proc(WILD, "/obj/structure/wild/tree/cactus/attackby")
        saved = proc(WILD, "/obj/structure/wild/tree/cactus/get_saved_vars")
        runtime = proc(WILD, "/obj/structure/wild/tree/cactus/persistence_runtime_var")
        add = proc(HOLDER, "/datum/reagents/proc/add_reagent")
        self.assertIn('var/cactus_water_remaining = 20', WILD)
        self.assertIn('. |= "cactus_water_remaining"', saved)
        self.assertIn('key == "cactus_water_busy"', runtime)
        self.assertIn('istype(src, /obj/structure/wild)', PERSISTENCE)
        self.assertIn('amount = min(amount, get_free_space())', add)
        self.assertIn('return TRUE', add)
        for term in ('vessel.is_open_container()', 'user.get_active_hand() != vessel',
                     'user.Adjacent(src)', 'QDELETED(holder)', 'persistence_save_in_progress',
                     'persistence_active_operation', 'persistence_load_recovery_required',
                     'holder.update_total()', 'min(5, cactus_water_remaining, holder.get_free_space())',
                     'cactus_water_remaining += collected - accepted', 'safety = TRUE', 'holder.handle_reactions()'):
            self.assertIn(term, action)
        self.assertLess(action.index('cactus_water_busy = TRUE'), action.index('holder.update_total()'))
        self.assertLess(action.index('holder.update_total()'), action.rindex('persistence_active_operation'))
        self.assertLess(action.index('cactus_water_remaining -= collected'), action.index('holder.add_reagent('))
        self.assertIn('accepted_amount = accepted_amount', action)
        self.assertIn('accepted_amount["amount"] = amount', add)
        self.assertIn('if (accepted_amount && amount <= 0)', add)
        self.assertNotIn('do_after(', action)
        self.assertNotIn('sleep(', action)

    def test_finite_stock_partial_full_failure_and_restore(self):
        stock, received = 20, 0
        for free in (5, 2, 0, 5, 5, 5, 5):
            stock, amount = draw(stock, free)
            received += amount
            self.assertEqual(stock + received, 20)
        self.assertEqual((stock, received), (0, 20))
        # Model the explicit persisted scalar, including zero, and a legacy save.
        self.assertEqual(draw({'cactus_water_remaining': stock}['cactus_water_remaining'], 5), (0, 0))
        self.assertEqual({}.get('cactus_water_remaining', 20), 20)
        self.assertEqual(draw(5, 5, accepted=0), (5, 0))
        self.assertEqual(draw(5, 5, accepted=2), (3, 2))
        self.assertEqual(draw(5, 5, blocked=True), (5, 0))
        self.assertEqual(draw(5, 0.005), (5, 0))

    def test_busy_claim_prevents_reentrant_draw(self):
        stock, received = draw(20, 5)
        after_reentry, reentrant = draw(stock, 5, blocked=True)
        self.assertEqual((after_reentry, received, reentrant), (15, 5, 0))


if __name__ == '__main__':
    unittest.main()
