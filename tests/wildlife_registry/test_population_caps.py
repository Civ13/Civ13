"""Offline source contract: every breeding animal has a global population cap.

Reads production DM source text only; does not execute DM. See
docs/animal-population-bounds.md for the table this contract backs.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
ANIMALS = ROOT / 'code/game/mob/living/simple_animal'

# Source file -> (registry, cap) for each global conception/hatching gate.
CAPS = {
    'friendly/birds.dm': [('chicken_count', 50), ('turkey_count', 35)],
    'friendly/deer.dm': [('deer_count', 30), ('deer_count', 30)],
    'friendly/farm_animals.dm': [('cow_count', 30), ('pig_count', 30), ('boar_count', 30),
                                 ('goat_count', 35), ('sheep_count', 35)],
    'hostile/buffalo.dm': [('bison_count', 30)],
    'hostile/wolf.dm': [('wolf_count', 20)],
    'hostile/bear.dm': [('bear_count', 12)],
}
GATE = re.compile(r'\b([a-z]+_count)\.len < (\d+)')


def gates(text):
    return [(name, int(cap)) for name, cap in GATE.findall(text)]


def conception_lines(text):
    return [line for line in text.splitlines() if re.search(r'\bpregnant = TRUE\b', line)]


class PopulationCapTests(unittest.TestCase):
    def test_each_breeding_file_has_its_documented_caps(self):
        for name, expected in CAPS.items():
            with self.subTest(file=name):
                self.assertEqual(gates((ANIMALS / name).read_text()), expected)

    def test_every_file_that_conceives_is_capped(self):
        for path in sorted(ANIMALS.rglob('*.dm')):
            text = path.read_text(errors='replace')
            rel = path.relative_to(ANIMALS).as_posix()
            if conception_lines(text):
                with self.subTest(file=rel):
                    self.assertIn(rel, CAPS)
                    self.assertTrue(gates(text))

    def test_wolf_and_bear_conception_is_gated(self):
        for name, registry, cap in (('hostile/wolf.dm', 'wolf_count', 20),
                                    ('hostile/bear.dm', 'bear_count', 12)):
            with self.subTest(file=name):
                text = (ANIMALS / name).read_text()
                self.assertIn(f'if (src.female && !src.pregnant && {registry}.len < {cap})', text)

    def test_bear_registry_counts_every_bear(self):
        text = (ANIMALS / 'hostile/bear.dm').read_text()
        body = re.search(r'^/mob/living/simple_animal/hostile/bear/New\(\)[^\n]*\n(.*?)(?=^/|\Z)',
                         text, re.M | re.S)
        self.assertIsNotNone(body, 'base bear New() must register every bear')
        lines = [line.strip() for line in body.group(1).splitlines() if line.strip()]
        self.assertEqual(lines, ['bear_count |= src', '..()'])
        boar = re.search(r'^/mob/living/simple_animal/hostile/bear/boar/New\(\)\n(.*?)(?=^/|\Z)',
                         text, re.M | re.S)
        self.assertNotIn('bear_count', boar.group(1))

    def test_removing_a_cap_is_detected(self):
        text = (ANIMALS / 'hostile/wolf.dm').read_text()
        self.assertEqual(gates(text.replace(' && wolf_count.len < 20', '')), [])


if __name__ == '__main__':
    unittest.main()
