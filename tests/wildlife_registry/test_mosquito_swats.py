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
        self.assertEqual(item.count('qdel(src)'), 1)
        for attack in (hand, item):
            self.assertNotIn('mosquito_count', attack)
            self.assertNotIn('unregisterSpawner()', attack)

        animal = (ROOT / 'code/game/mob/living/simple_animal/simple_animal.dm').read_text()
        cleanup = proc(animal, '/mob/living/simple_animal/Destroy()')
        unregister = proc(animal, '/mob/living/simple_animal/proc/unregisterSpawner()')
        self.assertEqual(cleanup.count('unregisterSpawner()'), 1)
        self.assertIn('O.mosquito_count--', unregister)
        self.assertIn('origin = null', unregister)

    def test_item_swat_behavior(self):
        mosquito = (ROOT / 'code/game/mob/living/simple_animal/hostile/mosquitoes.dm').read_text()
        body = proc(mosquito, '/mob/living/simple_animal/mosquito/attackby(var/obj/item/O, var/mob/user)')
        # Project the selected DM statements with injected type, random and engine effects.
        # The modern subtype also satisfies the parent swatter check.
        translations = {
            'var/swat_chance': 'swat_chance = None',
            'if (istype(O, /obj/item/weapon/swatter/modern))': "if kind == 'modern':",
            'else if (istype(O, /obj/item/weapon/swatter))': "elif kind in ('modern', 'ordinary'):",
            'swat_chance = 75': 'swat_chance = 75',
            'swat_chance = 30': 'swat_chance = 30',
            'else': 'else:',
            'if (prob(swat_chance))': 'if prob(swat_chance):',
            r'visible_message("[user] swats \the [src] with \the [O]!")': "events.append('hit')",
            r'visible_message("[user] misses \the [src]!")': "events.append('miss')",
            'qdel(src)': "events.append('delete')",
            'return': 'return',
        }
        lines = ['def attack(kind, prob, events):']
        for line in body.splitlines():
            if not line.strip():
                continue
            statement = line.strip()
            self.assertIn(statement, translations, 'Unknown mosquito swat statement')
            depth = len(line) - len(line.lstrip('\t'))
            lines.append('    ' * depth + translations[statement])
        namespace = {}
        exec(compile('\n'.join(lines), '<mosquito swat projection>', 'exec'), namespace)
        for kind, chance in [('modern', 75), ('ordinary', 30), ('other', None)]:
            for hit in (False, True):
                with self.subTest(kind=kind, hit=hit):
                    rolls, events = [], []
                    def prob(value):
                        rolls.append(value)
                        return hit
                    namespace['attack'](kind, prob, events)
                    self.assertEqual(rolls, [] if chance is None else [chance])
                    self.assertEqual(events, [] if chance is None else
                                     (['hit', 'delete'] if hit else ['miss']))


if __name__ == '__main__':
    unittest.main()
