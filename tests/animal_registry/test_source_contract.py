"""Offline source contracts only. Does not execute or emulate DM list semantics."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = 'code/game/mob/living/simple_animal/friendly/farm_animals.dm'
HOOKS = {
    **{f'cattle/{sex}/{hook}': 'cow_count'
       for sex in ('cow', 'bull') for hook in ('death', 'Destroy')},
    **{f'pig_{sex}/{hook}': 'pig_count'
       for sex in ('gilt', 'boar') for hook in ('death', 'Destroy')},
    'boar_gilt/death': 'boar_count',
    'boar_boar/death': 'boar_count',
    'boar_gilt/Destroy': 'boar_count',
    **{f'{species}/{hook}': f'{species}_count'
       for species in ('goat', 'sheep') for hook in ('death', 'Destroy')},
}


def violations(source):
    errors = []
    for hook, registry in HOOKS.items():
        header = f'/mob/living/simple_animal/{hook}()'
        matches = re.findall(r'^' + re.escape(header) + r'\n(.*?)(?=^/|\Z)',
                             source, re.M | re.S)
        expected = [f'{registry} -= src', '..()']
        if len(matches) != 1 or [s.strip() for s in matches[0].splitlines() if s.strip()] != expected:
            errors.append(hook)
    return errors


class RegistrySourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = (ROOT / SOURCE).read_text()

    def test_all_fifteen_hooks_remove_only_the_owner_before_parent(self):
        self.assertEqual(len(HOOKS), 15)
        self.assertEqual(violations(self.source), [])

    def test_unrelated_source_edits_do_not_change_hook_contracts(self):
        self.assertEqual(violations(self.source + '\n// Unrelated future source note.\n'), [])

    def test_all_intersection_negative_control_rejects_fifteen_hooks(self):
        original_operators = self.source.replace('_count -= src', '_count &= src')
        self.assertEqual(set(violations(original_operators)), set(HOOKS))

    def test_each_single_reversion_is_detected(self):
        for hook, registry in HOOKS.items():
            with self.subTest(hook=hook):
                header = f'/mob/living/simple_animal/{hook}()'
                start = self.source.index(header)
                prefix, rest = self.source[:start], self.source[start:]
                mutated = prefix + rest.replace(f'{registry} -= src', f'{registry} &= src', 1)
                self.assertEqual(violations(mutated), [hook])

    def test_missing_parent_wrong_registry_and_clear_are_detected(self):
        for hook, registry in HOOKS.items():
            start = self.source.index(f'/mob/living/simple_animal/{hook}()')
            end = self.source.find('\n/', start + 1)
            if end == -1:
                end = len(self.source)
            body = self.source[start:end]
            for before, after in ((f'{registry} -= src', 'cow_count.Cut()'),
                                  (f'{registry} -= src', 'wrong_count -= src'),
                                  ('\t..()', '\treturn')):
                with self.subTest(hook=hook, mutation=after):
                    mutated = self.source[:start] + body.replace(before, after, 1) + self.source[end:]
                    self.assertEqual(violations(mutated), [hook])


if __name__ == '__main__':
    unittest.main()
