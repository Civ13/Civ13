"""Offline stock/initial capacity contract for the two combat kit editions."""
from collections import Counter
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
STORAGE = ROOT / 'code/game/objects/items/weapons/storage'
KIT = '/obj/item/weapon/storage/firstaid/combat'
SYRINGE = '/obj/item/weapon/reagent_containers/syringe/'
PILLS = '/obj/item/weapon/storage/pill_bottle/'
DRESSING = '/obj/item/stack/medical/advanced/sulfa'


def body(source, path):
    match = re.search(r'^' + re.escape(path) + r'\(\)\n((?:\t[^\n]*\n)+)', source, re.M)
    return match[1] if match else ''


def spawned(code):
    return re.findall(r'\bnew\s+(/\S+)\(src\)', code)


def constructor_stock(source, modern=False, empty=False):
    base = body(source, KIT + '/New')
    concrete = body(source, KIT + '/modern/New') if modern else base
    if concrete and not empty:
        inherited = spawned(base) if modern and '..()' in concrete else []
        if spawned(concrete):
            return inherited + spawned(concrete)
    if empty:
        if ('if (!empty)\n\t\tstock_combat_kit()' not in base and
                'if (empty) return' not in concrete):
            raise AssertionError('Unexpected empty kit admission')
        return []
    if 'if (!empty)\n\t\tstock_combat_kit()' not in base or body(source, KIT + '/modern/New'):
        raise AssertionError('Both editions must use the same guarded constructor')
    return spawned(body(source, KIT + ('/modern/stock_combat_kit' if modern else '/proc/stock_combat_kit')))


class CombatKitTests(unittest.TestCase):
    def setUp(self):
        self.source = (STORAGE / 'medkit.dm').read_text(encoding='utf-8')
        self.storage = (STORAGE / 'storage.dm').read_text(encoding='utf-8')

    def initial_capacity(self, contents):
        # Stock-cost fixtures taken from the current item classes. The shared
        # storage constructor remains responsible for fitting any prefill.
        costs = {DRESSING: 2}
        self.assertIn('max_storage_space = max(total_storage_space,max_storage_space)', self.storage)
        standard = int(re.search(r'var/max_storage_space = (\d+)', self.storage)[1])
        return max(standard, sum(costs.get(item, 2 if item.startswith(PILLS) else 1) for item in contents))

    def test_modern_has_only_modern_stock_and_normal_capacity(self):
        contents = constructor_stock(self.source, modern=True)
        self.assertEqual(Counter(contents), Counter({
            SYRINGE + 'adrenaline': 1, SYRINGE + 'autoinjector/adrenaline': 1,
            SYRINGE + 'autoinjector/morphine': 1, SYRINGE + 'autoinjector/clotting': 1,
            PILLS + 'antitox': 1, PILLS + 'penicillin': 1,
        }))
        self.assertEqual(self.initial_capacity(contents), 8)

    def test_legacy_stock_and_prefill_capacity_are_preserved(self):
        contents = constructor_stock(self.source)
        self.assertEqual(Counter(contents), Counter({
            SYRINGE + 'adrenaline': 2, SYRINGE + 'morphine': 2,
            SYRINGE + 'sulfanomides': 1, DRESSING: 1, PILLS + 'tramadol': 1,
        }))
        self.assertEqual(self.initial_capacity(contents), 9)

    def test_empty_stays_empty_for_each_edition(self):
        for modern in (False, True):
            with self.subTest(modern=modern):
                self.assertEqual(constructor_stock(self.source, modern=modern, empty=True), [])


if __name__ == '__main__':
    unittest.main()
