"""Project the large bathtub's wash order with inert engine boundaries."""
from pathlib import Path
from types import SimpleNamespace
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests' / 'save_movement'))
import source_adapter

SOURCE = (ROOT / 'code/game/objects/structures/watercloset.dm').read_text(encoding='utf-8')


class LargeBathtubWashing(unittest.TestCase):
    def test_processing_preserves_tile_order_and_type_gates(self):
        events = []
        # DM's istype() infers each declared variable's type; Python cannot.
        source = SOURCE.replace('istype(AM) && AM.simulated', 'is_movable(AM) && AM.simulated')
        source = source.replace('istype(L))\n\t\t\t\tprocess_heat(L)',
                                'is_living(L))\n\t\t\t\tprocess_heat(L)')
        helper = source_adapter.project(source, '/obj/structure/shower/bathtub/big/proc/wash_location',
            'location, wash, process_heat', {
                'is_movable': lambda obj: obj.movable,
                'is_living': lambda obj: obj.living,
            })
        tiles = {}
        for coords, name in (((1, 1, 1), 'base'), ((2, 1, 1), 'east'),
                             ((1, 2, 1), 'north'), ((2, 2, 1), 'northeast')):
            tiles[coords] = [SimpleNamespace(name=name + '-living', movable=True, living=True, simulated=True),
                             SimpleNamespace(name=name + '-item', movable=True, living=False, simulated=True),
                             SimpleNamespace(name=name + '-unsimulated', movable=True, living=True, simulated=False),
                             SimpleNamespace(name=name + '-other', movable=False, living=False, simulated=True)]
        def wash(obj):
            events.append(('wash', obj.name))
        def heat(obj):
            events.append(('heat', obj.name))
        def wash_location(location):
            helper(location, wash, heat)
        reagents = SimpleNamespace(get_free_space=lambda: 12,
            add_reagent=lambda kind, amount: events.append(('reagent', kind, amount)))
        run = source_adapter.project(source, '/obj/structure/shower/bathtub/big/process',
            'on, loc, x, y, z, wash_location, wash_floor, reagents',
            {'locate': lambda x, y, z: tiles[(x, y, z)]})
        floor = lambda: events.append(('floor',))
        run(False, tiles[(1, 1, 1)], 1, 1, 1, wash_location, floor, reagents)
        self.assertEqual(events, [])
        run(True, tiles[(1, 1, 1)], 1, 1, 1, wash_location, floor, reagents)
        expected = []
        for name in ('base', 'east', 'north', 'northeast'):
            expected.extend((('wash', name + '-living'), ('heat', name + '-living'),
                             ('wash', name + '-item')))
        expected.extend((('floor',), ('reagent', 'water', 12)))
        self.assertEqual(events, expected)


if __name__ == '__main__':
    unittest.main()
