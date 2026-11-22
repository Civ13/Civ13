"""List-walking reagent transfers debit the entry they credit (#6870).

remove_reagent("ethanol") drains every alcohol in list order, so a caller that
walks reagent_list and credits current.id must ask for the exact entry, or a
beer earlier in the list is spent while pure ethanol is delivered.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SITES = {
    'code/modules/1713/factory_pipes.dm': 'R.remove_reagent(id, amount, exact = TRUE)',
    'code/modules/reagents/Chemistry-Holder.dm': 'remove_reagent(current.id, amount_to_transfer, TRUE, exact = TRUE)',
    'code/modules/reagents/reagent_containers/glass.dm': 'reagents.remove_reagent(current.id, amount_to_transfer, TRUE, exact = TRUE)',
    'code/modules/1713/light_fuel.dm': 'C.reagents.remove_reagent(R.id, units, exact = TRUE)',
}


def read(path):
    return (ROOT / path).read_text(encoding='utf-8-sig').replace('\r\n', '\n')


class ExactReagentTransferTests(unittest.TestCase):
    def test_holder_offers_exact_removal(self):
        holder = read('code/modules/reagents/Chemistry-Holder.dm')
        self.assertIn('/datum/reagents/proc/remove_reagent(var/id, var/amount, var/safety = FALSE, var/exact = FALSE)', holder)
        self.assertIn('if (id == "ethanol" && !exact)', holder)
        self.assertIn('remove_reagent(current.id, amount_to_remove, TRUE, exact = TRUE)', holder)

    def test_list_walking_transfers_use_it(self):
        for path, call in SITES.items():
            with self.subTest(path=path):
                self.assertIn(call, read(path))


if __name__ == '__main__':
    unittest.main()
