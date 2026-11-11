"""Exercise premade constructor flow from DM source with fake engine effects."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
SOURCE = adapter.read('code/game/objects/structures/vending/fuel_pump.dm')
BASE = '/obj/structure/fuelpump/premade'


def projection(declaration, args, env):
    body = adapter.extract(SOURCE, declaration)
    body = body.replace('..()', 'parent()')
    body = body.replace('map.ID', 'game_map.ID')
    body = body.replace('"[brand] [fueltype] pump"', 'f"{pump.brand} {pump.fueltype} pump"')
    for expression in ('vol', 'fueltype', 'price/4', 'price'):
        body = body.replace('[' + expression + ']', '{pump.' + expression + '}')
    body = body.replace('"This pump has ', 'f"This pump has ')
    for field in ('fueltype', 'vol', 'name', 'price', 'desc'):
        body = body.replace('\t' + field + ' = ', '\tpump.' + field + ' = ')
    body = body.replace('pump.vol = maxvol', 'pump.vol = pump.maxvol')
    return adapter.project('/proc/projected()\n' + body + '\n', '/proc/projected', args, env)


class PremadePumpTests(unittest.TestCase):
    def test_variants_preserve_parent_order_and_descriptions(self):
        for brand, variant in (('UngOil', ''), ('Yamaha Gas', '/yamaha')):
            for fuel in ('gasoline', 'diesel'):
                for deal in (False, True):
                    with self.subTest(brand=brand, fuel=fuel, deal=deal):
                        pump = SimpleNamespace(brand=brand, maxvol=1000, vol=0, price=3,
                                               fueltype='none', name='fuel pump', desc='')
                        events = []
                        game_map = SimpleNamespace(ID='deal' if deal else 'other')
                        desc = projection('/obj/structure/fuelpump/proc/updatedesc', 'pump, game_map',
                                          {'MAP_THE_ART_OF_THE_DEAL': 'deal'})

                        def updatedesc():
                            desc(pump, game_map)
                            events.append(('description', pump.fueltype, pump.name, pump.desc))

                        def pick(*choices):
                            self.assertEqual(choices, ('gasoline', 'diesel', 'biodiesel', 'pethanol', 'petroleum'))
                            events.append(('pick',))
                            return 'petroleum'

                        def color():
                            events.append(('color', pump.fueltype, pump.name, pump.vol, pump.price))

                        helper = projection(BASE + '/proc/set_premade_fuel', 'pump, new_fuel, updatedesc', {})
                        parent = projection(BASE + '/New', 'pump, parent, pick, do_color, updatedesc', {})
                        child = projection(BASE + variant + '/' + fuel + '/New', 'parent, set_premade_fuel', {})
                        child(lambda: parent(pump, lambda: events.append(('ancestor',)), pick, color, updatedesc),
                              lambda chosen: helper(pump, chosen, updatedesc))

                        currency = '0.1 dollars' if deal else '0.4 silver coins'
                        suffix = '' if deal else ' Copper and Gold accepted too.'
                        def expected_desc(kind):
                            return f'This pump has 1000 units of {kind} available. Price: {currency} per unit.{suffix}'
                        self.assertEqual(events, [
                            ('ancestor',), ('pick',),
                            ('color', 'petroleum', f'{brand} petroleum pump', 1000, 0.4),
                            ('description', 'petroleum', f'{brand} petroleum pump', expected_desc('petroleum')),
                            ('description', fuel, f'{brand} {fuel} pump', expected_desc(fuel)),
                        ])
                        self.assertEqual((pump.fueltype, pump.name, pump.vol, pump.price),
                                         (fuel, f'{brand} {fuel} pump', 1000, 0.4))

    def test_brand_defaults_remain_distinct(self):
        self.assertIn('var/brand = "UngOil"\n\ticon_state = "oilpump3"\n\tcustomcolor = "#3cb44b"\n\tmaxvol = 1000', SOURCE)
        self.assertIn('/premade/yamaha\n\tbrand = "Yamaha Gas"\n\ticon_state = "oilpump1"\n\tcustomcolor = "#7F0000"', SOURCE)


if __name__ == '__main__':
    unittest.main()
