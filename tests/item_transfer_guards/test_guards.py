"""Offline production-source contracts, not execution of BYOND inventory behavior."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def vending_contract(source):
    stored = source.split('if (product_item.len)', 1)[1].split('\n\t\t\telse', 1)[0]
    return (stored.index('if (!product_item.len)') < stored.index('pick(product_item)')
            < stored.index('product_item -= product') < stored.index('product.forceMove'))


def bag_contract(source):
    proc = source.split('/MouseDrop', 1)[1].split('/obj/item/weapon/evidencebag/attack_self', 1)[0]
    first_move = min(proc.index('U.contents.Remove(I)'), proc.index('user.drop_from_inventory(I)'))
    return all(proc.index(guard) < first_move for guard in
               ('if(istype(I, /obj/item/weapon/evidencebag))', 'if(I.w_class > 3)', 'if(contents.len)'))


def exchange_contract(source):
    proc = source.split('/proc/trader_exchange(', 1)[1].split('/proc/choose_currency(', 1)[0]
    commit = proc.index('if (!trader_commit')
    change = proc.index('if (!change_notes) return FALSE')
    output = proc.index('if (!out_notes)')
    cleanup = proc.index('for (var/obj/item/I in given) qdel(I)')
    refusal = proc.index('return FALSE', output)
    return change < commit and output < cleanup < refusal < proc.index('given += out_notes') < commit


class Guards(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.vend = (ROOT / 'code/game/objects/structures/vending/vending_product.dm').read_text()
        cls.bag = (ROOT / 'code/modules/1713/forensics.dm').read_text()
        cls.fx = (ROOT / 'code/modules/1713/extraction/currency_traders.dm').read_text()

    def test_stock_reference_retired_before_delivery(self):
        self.assertTrue(vending_contract(self.vend))

    def test_vending_original_mutation_detected(self):
        with self.assertRaises(ValueError):
            vending_contract(self.vend.replace('product_item -= product', ''))

    def test_bag_refuses_before_detaching_item(self):
        self.assertTrue(bag_contract(self.bag))

    def test_bag_late_guard_mutation_detected(self):
        guard = 'if(I.w_class > 3)'
        mutated = self.bag.replace(guard, 'if(FALSE)', 1).replace('U.contents.Remove(I)', 'U.contents.Remove(I)\n\t\t\t' + guard)
        self.assertFalse(bag_contract(mutated))

    def test_exchange_materializes_both_outputs_before_commit(self):
        self.assertTrue(exchange_contract(self.fx))

    def test_exchange_missing_output_guard_detected(self):
        with self.assertRaises(ValueError):
            exchange_contract(self.fx.replace('if (!out_notes)', 'if(FALSE)', 1))

    def test_exchange_missing_change_guard_detected(self):
        with self.assertRaises(ValueError):
            exchange_contract(self.fx.replace('if (!change_notes) return FALSE', '', 1))


if __name__ == '__main__':
    unittest.main()
