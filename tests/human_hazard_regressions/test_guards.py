"""Offline production-expression and wiring checks, not native DM execution."""
from pathlib import Path
import re
from types import SimpleNamespace
import unittest
ROOT = Path(__file__).resolve().parents[2]

def read(path):
    return (ROOT / path).read_text()

DAMAGE = 'code/game/mob/living/carbon/human/human_damage.dm'
AREA = 'code/game/area/areas.dm'
MUTATIONS = 'code/game/mob/living/carbon/human/human_mutations.dm'
EXPLOSION = 'code/processes/explosion.dm'

def damage_guard(source, stat, damagetype):
    body = source.split('//Handle other types of damage', 1)[1]
    expr = body.split('if (', 1)[1].split(')')[0]
    expr = expr.replace('&&', ' and ').replace('!stat', 'not stat')
    return eval(expr, {'__builtins__': {}}, dict(stat=stat, damagetype=damagetype, BRUTE='brute', BURN='burn'))

class HazardTests(unittest.TestCase):
    def test_nonphysical_dispatch_for_each_state(self):
        for state in (0, 1, 2):
            for kind in ('tox', 'oxy', 'clone', 'halloss'):
                self.assertTrue(damage_guard(read(DAMAGE), state, kind))
            for kind in ('brute', 'burn'):
                self.assertFalse(damage_guard(read(DAMAGE), state, kind))

    def test_consciousness_only_gates_pain_scream(self):
        source = read(DAMAGE).split('//Handle other types of damage', 1)[1].split('//Handle BRUTE', 1)[0]
        self.assertIn('if (!stat && damagetype == HALLOSS', source)
        self.assertIn('..(damage, damagetype, def_zone, blocked)', source)

    def test_old_dispatch_negative_control(self):
        old = read(DAMAGE).replace('if (damagetype != BRUTE', 'if (!stat && damagetype != BRUTE', 1)
        self.assertFalse(damage_guard(old, 1, 'oxy'))

    def test_void_requires_both_worn_slots(self):
        source = read(AREA).split('/area/proc/no_air(mob)', 1)[1]
        slots = re.findall(r'istype\(H\.(\w+), /obj/item/clothing/(head|suit)/astronaut\)', source)
        self.assertEqual(slots, [('head', 'head'), ('wear_suit', 'suit')])
        for head, suit in ((True, False), (False, True), (False, False), (True, True)):
            equipped = dict(head=head, wear_suit=suit, shoes=False)
            self.assertEqual(all(equipped[slot] for slot, _ in slots), head and suit)

    def test_zombie_drops_snapshot_with_item_api(self):
        source = read(MUTATIONS).split('if(radiation >= 350)', 1)[1]
        self.assertIn('for(var/obj/item/I in contents.Copy())', source)
        self.assertIn('drop_from_inventory(I, loc)', source)
        self.assertNotIn('drop_item(', source)
        # Models mutation-safe traversal only, not inventory hooks or BYOND.
        items = list(range(5))
        for item in items.copy():
            items.remove(item)
        self.assertEqual(items, [])

    def test_camera_zero_and_nonzero_distance(self):
        source = read(EXPLOSION).split('for (var/mob/living/human/M in range(10, epicenter))', 1)[1]
        expr = source.split('var/dist = ', 1)[1].splitlines()[0]
        for distance in range(11):
            value = eval(expr, {'__builtins__': {}}, dict(max=max, get_dist=lambda *args: distance, get_turf=lambda x:x, M=None, epicenter=None))
            self.assertEqual(value, max(1, distance))
            self.assertGreater(18 / value, 0)
        old = 'get_dist(get_turf(M), epicenter)'
        self.assertNotEqual(expr, old)

if __name__ == '__main__':
    unittest.main()
