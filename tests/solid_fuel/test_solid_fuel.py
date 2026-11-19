"""Solid fuel rates keep the values each device used to hard-code.

The oven, the bloomery and blast furnace, the factory furnace, the brazier and
the engine heat source each had their own istype() chain. They now read one
fuel-kind table and a rates table per device (code/modules/1713/solid_fuel.dm).
FROZEN is what each chain gave for an item of `amount` units; a deliberate
balance change updates it here.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/1713/solid_fuel.dm').read_text()
# device: kind -> (per unit, flat bonus)
FROZEN = {
    'hearth_fuel_rates': {'wood': (1, 0), 'bamboo': (1, 0), 'branch': (1, 0.5), 'leaf': (1, 0.5),
                          'dung': (1, 1), 'charcoal': (2.5, 0), 'coal': (3, 0)},
    'furnace_fuel_rates': {'wood': (1, 0), 'bamboo': (1, 0), 'plank': (1, 0), 'branch': (1, 0.5),
                           'leaf': (1, 0.5), 'dung': (1, 1), 'charcoal': (2.5, 0), 'coal': (3, 0), 'coke': (3, 0)},
    'factory_fuel_rates': {'wood': (1, 0), 'bamboo': (1, 0), 'plank': (1, 0), 'charcoal': (2.5, 0), 'coal': (3, 0), 'coke': (3, 0)},
    # Planks were meant to burn in braziers but a joined istype() skipped them (#5198).
    'brazier_fuel_rates': {'coal': (220, 0), 'charcoal': (180, 0), 'wood': (80, 0), 'plank': (80, 0),
                           'bamboo': (80, 0), 'dung': (90, 0), 'branch': (60, 0), 'leaf': (60, 0)},
    'heat_source_fuel_rates': {'coal': (240, 0), 'charcoal': (80, 0), 'wood': (60, 0), 'plank': (60, 0),
                               'branch': (60, 0), 'bamboo': (60, 0), 'dung': (60, 0), 'leaf': (30, 0)},
}
KINDS = {'/obj/item/stack/material/wood': 'wood', '/obj/item/stack/material/woodplank': 'plank',
         '/obj/item/stack/material/bamboo': 'bamboo', '/obj/item/weapon/branch': 'branch',
         '/obj/item/stack/material/leaf': 'leaf', '/obj/item/stack/dung': 'dung',
         '/obj/item/stack/ore/charcoal': 'charcoal', '/obj/item/stack/ore/coal': 'coal', '/obj/item/stack/ore/coke': 'coke'}


def table(name):
    body = re.search(r'var/global/list/' + name + r' = list\((.*?)\)\n', SOURCE, re.S)[1]
    rates = {}
    for kind, value in re.findall(r'"(\w+)" = (list\([^)]*\)|[\d.]+)', body):
        if value.startswith('list('):
            per, bonus = (float(v) for v in value[5:-1].split(','))
        else:
            per, bonus = float(value), 0
        rates[kind] = (per, bonus)
    return rates


class SolidFuelTest(unittest.TestCase):
    def test_kinds(self):
        body = re.search(r'solid_fuel_kinds = list\((.*?)\)\n', SOURCE, re.S)[1]
        self.assertEqual(dict(re.findall(r'(/[\w/]+) = "(\w+)"', body)), KINDS)

    def test_device_rates_match_the_old_chains(self):
        for name, rates in FROZEN.items():
            with self.subTest(name):
                self.assertEqual(table(name), {k: (float(a), float(b)) for k, (a, b) in rates.items()})

    def test_devices_read_their_table(self):
        uses = {
            'code/game/objects/structures/kitchen/oven.dm': 'solid_fuel_value(I, hearth_fuel_rates)',
            'code/game/objects/structures/blacksmithing/refining.dm': 'solid_fuel_value(I, furnace_fuel_rates)',
            'code/modules/1713/factory_machines.dm': 'solid_fuel_unit_value(I, factory_fuel_rates)',
            'code/modules/1713/siege/fire.dm': 'solid_fuel_value(W, brazier_fuel_rates)',
            'code/modules/1713/machinery/engines/heatsource.dm': 'solid_fuel_value(I, heat_source_fuel_rates)',
        }
        for path, call in uses.items():
            text = (ROOT / path).read_text()
            self.assertIn(call, text, path)
            self.assertNotIn('istype(I, /obj/item/stack/ore/charcoal)', text.replace('istype(W,', 'istype(I,'), path)


if __name__ == '__main__':
    unittest.main()
