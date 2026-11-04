"""Offline source contracts for hand-feeding animals.

Feeding seeds refills a laying hen's eggs, and every grain feeds herbivores.

`eggsleft` reaches 0 after a hen lays her eggs, and 0 is FALSE in DM, so the
old `eggsleft != FALSE` check stopped refills for exactly the hens that needed
them. Egg layers are now marked with `lays_eggs`. Reads source text only.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
ANIMALS = ROOT / 'code/game/mob/living/simple_animal'


def type_block(text, path):
    match = re.search(r'^' + re.escape(path) + r'\n(.*?)(?=^/|\Z)', text, re.M | re.S)
    return match.group(1) if match else ''


class EggRefillTests(unittest.TestCase):
    def test_feed_refill_does_not_use_eggsleft_as_a_flag(self):
        text = (ANIMALS / 'simple_animal.dm').read_text()
        self.assertIn('\tvar/lays_eggs = FALSE', text)
        feed = type_block(text, '/mob/living/simple_animal/proc/feed(var/obj/item/O as obj, var/mob/user as mob)')
        self.assertIn('if (lays_eggs && eggsleft < maxeggs)', feed)
        self.assertNotIn('eggsleft != FALSE', feed)

    def test_both_laying_birds_are_marked(self):
        text = (ANIMALS / 'friendly/birds.dm').read_text()
        for path in ('/mob/living/simple_animal/chicken', '/mob/living/simple_animal/turkey_f'):
            with self.subTest(type=path):
                block = type_block(text, path)
                self.assertIn('\teggsleft = 5', block)
                self.assertIn('\tlays_eggs = TRUE', block)

    def test_every_type_with_eggs_is_marked(self):
        text = (ANIMALS / 'friendly/birds.dm').read_text()
        blocks = re.findall(r'^(/mob/living/simple_animal/\S+)\n(.*?)(?=^/|\Z)', text, re.M | re.S)
        for path, block in blocks:
            if re.search(r'^\teggsleft = [1-9]', block, re.M):
                with self.subTest(type=path):
                    self.assertIn('\tlays_eggs = TRUE', block)

    def test_every_grain_feeds_herbivores(self):
        text = (ANIMALS / 'simple_animal.dm').read_text()
        self.assertNotIn('#define GRAIN ', text)
        define = re.search(r'^#define IS_GRAIN\(O\) (.*)$', text, re.M).group(1)
        for grain in ('wheat', 'oat', 'barley', 'rice'):
            with self.subTest(grain=grain):
                self.assertIn(f'istype(O, /obj/item/weapon/reagent_containers/food/snacks/grown/{grain})', define)
        self.assertNotIn('||/obj', define)
        self.assertIn('if (herbivore && IS_GRAIN(O))', text)
        self.assertIn('else if (IS_GRAIN(O))', text)


if __name__ == '__main__':
    unittest.main()
