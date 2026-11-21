"""Offline source checks for casing ejection; tests/casing_ejection/run.py is the native probe."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(rel):
    return (ROOT / rel).read_text(encoding='utf-8')


def body(source, signature):
    start = source.index(signature)
    end = re.search(r'\n(?=[^\t\n])', source[start + len(signature):])
    return source[start:start + len(signature) + (end.start() if end else len(source))]


class CasingEjectionSources(unittest.TestCase):
    def test_self_loading_guns_drop_their_casing(self):
        source = read('code/modules/projectiles/guns/projectile.dm')
        self.assertNotIn('DISABLE_CASINGS', source)
        proc = body(source, '/obj/item/weapon/gun/projectile/proc/process_chambered(')
        eject = proc.index('if (EJECT_CASINGS)')
        self.assertLess(eject, proc.index('drop_casing(chambered)', eject))

    def test_spent_brass_joins_a_capped_heap(self):
        proc = body(read('code/modules/projectiles/guns/projectile.dm'),
                    '/obj/item/weapon/gun/projectile/proc/drop_casing(')
        spent = proc.index('if (!C.BB)')
        self.assertLess(spent, proc.index('C.heap_find(T)', spent))
        self.assertIn('if (H.heap_count < CASINGS_PER_TILE)', proc)
        self.assertRegex(read('code/__defines/gun.dm'), r'#define CASINGS_PER_TILE \d+')

    def test_heaps_split_on_pickup_and_rebuild_on_load(self):
        items = read('code/game/objects/items.dm')
        self.assertIn('heap_split_one()', body(items, '/obj/item/proc/pickup('))
        ammo = read('code/modules/projectiles/ammunition.dm')
        self.assertIn('key == "overlays"', body(ammo, '/obj/item/ammo_casing/persistence_runtime_var('))
        self.assertIn('heap_update_overlays()', body(ammo, '/obj/item/ammo_casing/persistence_import_fields('))

    def test_no_casing_registry(self):
        self.assertNotIn('bullet_casings', read('code/modules/projectiles/ammunition.dm'))
        self.assertFalse((ROOT / 'code/processes/casings.dm').exists())

    def test_tank_gun_ejects_and_frees_its_shell(self):
        proc = body(read('code/modules/1713/siege/piece.dm'),
                    '/obj/structure/cannon/modern/tank/proc/do_tank_fire(')
        self.assertIn('eject_shell_casing(fired_shell)', proc)
        self.assertIn('qdel(fired_shell)', proc)


if __name__ == '__main__':
    unittest.main()
