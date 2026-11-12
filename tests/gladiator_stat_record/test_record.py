"""Check the legacy gladiator record and the paths that produce it.

These source projections do not execute the BYOND runtime or a save/load cycle.
"""
from pathlib import Path
import re
import unittest


SOURCE = Path(__file__).resolve().parents[2] / 'code/game/objects/structures/gladiator_control.dm'
TEXT = SOURCE.read_text(encoding='utf-8')


def body(path):
    match = re.search(r'^' + re.escape(path) + r'\([^\n]*\)\n(.*?)(?=^/(?:obj|mob)/|\Z)', TEXT, re.M | re.S)
    if not match:
        raise AssertionError('Missing procedure: ' + path)
    return match.group(1)


def projected_record(procedure, stats):
    match = re.search(r'^\s*return "(.*)"$', procedure, re.M)
    if not match:
        raise AssertionError('Missing serialized record')
    return re.sub(r'\[stats\["([a-z]+)"\]\[1\]\]',
                  lambda item: str(stats[item.group(1)]), match.group(1))


class GladiatorStatRecordTests(unittest.TestCase):
    def test_legacy_field_order_and_delimiters(self):
        values = {'strength': -2, 'crafting': 7, 'rifle': 0, 'dexterity': 4,
                  'swords': 8, 'pistol': 6, 'bows': 9, 'medical': 2,
                  'philosophy': 3, 'machinegun': 5, 'stamina': 11}
        serializer = body('/mob/living/human/proc/gladiator_stat_record')
        expected = '-2,7,0,4,8,6,9,2,3,5,11'
        self.assertEqual(projected_record(serializer, values), expected)
        swapped = serializer.replace('[stats["strength"][1]],[stats["crafting"][1]]',
                                     '[stats["crafting"][1]],[stats["strength"][1]]')
        self.assertNotEqual(projected_record(swapped, values), expected)

    def test_each_record_producer_uses_the_actual_gladiator(self):
        paths = {
            '/obj/structure/gladiator_ledger/attack_hand': ['GLAD1'],
            '/obj/structure/gladiator_control/proc/check_combat': ['WINNER', 'k'],
            '/obj/structure/gladiator_control/ranged/check_combat': ['WINNER'],
            '/obj/structure/gladiator_control/wrestling/check_combat': ['WINNER'],
            '/obj/structure/bed/saving/attack_hand': ['user', 'user'],
            '/mob/living/human/proc/check_profiles': ['', ''],
        }
        for path, owners in paths.items():
            with self.subTest(path=path):
                calls = re.findall(r'(?:statlist\s*=\s*)(?:(\w+)\.)?gladiator_stat_record\(\)', body(path))
                self.assertEqual(calls, owners)

    def test_manual_victory_retains_ten_value_fallback(self):
        ledger = body('/obj/structure/gladiator_ledger/attack_hand')
        self.assertIn('var/statlist = "1,1,1,1,1,1,1,1,1,1"', ledger)
        self.assertLess(ledger.index('var/statlist = "1,1,1,1,1,1,1,1,1,1"'),
                        ledger.index('statlist = GLAD1.gladiator_stat_record()'))
        self.assertLess(ledger.index('statlist = GLAD1.gladiator_stat_record()'),
                        ledger.index('GD.gladiator_stats += list(list(splitdata[2]'))


if __name__ == '__main__':
    unittest.main()
