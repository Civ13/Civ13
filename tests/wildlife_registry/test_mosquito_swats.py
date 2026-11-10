"""Source contracts for releasing mosquito spawn slots when swatted."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def proc(source, header):
    match = re.search(r'^' + re.escape(header) + r'\n(.*?)(?=^/|\Z)', source, re.M | re.S)
    if not match:
        raise AssertionError(f'missing {header}')
    return match.group(1)


class MosquitoSwatTests(unittest.TestCase):
    def test_swat_deletions_leave_spawn_count_to_the_common_cleanup(self):
        mosquito = (ROOT / 'code/game/mob/living/simple_animal/hostile/mosquitoes.dm').read_text()
        hand = proc(mosquito, '/mob/living/simple_animal/mosquito/attack_hand(mob/living/human/M as mob)')
        item = proc(mosquito, '/mob/living/simple_animal/mosquito/attackby(var/obj/item/O, var/mob/user)')
        self.assertEqual(hand.count('qdel(src)'), 1)
        self.assertEqual(item.count('qdel(src)'), 2)
        for attack in (hand, item):
            self.assertNotIn('mosquito_count', attack)
            self.assertNotIn('unregisterSpawner()', attack)

        animal = (ROOT / 'code/game/mob/living/simple_animal/simple_animal.dm').read_text()
        cleanup = proc(animal, '/mob/living/simple_animal/Destroy()')
        unregister = proc(animal, '/mob/living/simple_animal/proc/unregisterSpawner()')
        self.assertEqual(cleanup.count('unregisterSpawner()'), 1)
        self.assertIn('O.mosquito_count--', unregister)
        self.assertIn('origin = null', unregister)


if __name__ == '__main__':
    unittest.main()
