"""Execute the berry harvest source control flow with fake engine boundaries.

This is an offline projection, not a native BYOND or gameplay test.
"""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
import source_adapter

SOURCE = ROOT / 'code/game/objects/structures/berries.dm'


def procedure(source, name):
    return source_adapter.extract(source, '/obj/structure/wild/berrybush/' + name)


def project_harvest(source, wait, messages, outputs):
    # Replace only the two DM construction expressions with an injected effect.
    creation = 'new btype(get_turf(src))'
    assert procedure(source, 'proc/harvest_berries').count(creation) == 2
    source = source.replace(creation, 'make_berry(src)', 2)
    old_fields = source_adapter.FIELDS
    try:
        source_adapter.FIELDS += ('berries', 'berryproc')
        return source_adapter.project(
            source, '/obj/structure/wild/berrybush/proc/harvest_berries',
            'src, user, gathering',
            {'do_after': wait, 'to_chat': lambda user, message: messages.append((user, message)),
             'make_berry': lambda bush: outputs.append(bush.btype)}, method=True)
    finally:
        source_adapter.FIELDS = old_fields


class Bush:
    def __init__(self, berries=1, btype='tinto'):
        self.berries = berries
        self.btype = btype
        self.regenerations = 0

    def berryproc(self):
        self.regenerations += 1


class BerryHarvestTests(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')

    def test_entry_guards_and_parent_fallback_remain_distinct(self):
        hand = procedure(self.source, 'attack_hand')
        tool = procedure(self.source, 'attackby')
        self.assertIn('user.a_intent == I_GRAB && ishuman(user) && berries > 0', hand)
        self.assertIn('harvest_berries(user, FALSE)', hand)
        self.assertIn('else\n\t\t..()', hand)
        self.assertIn('istype(W, /obj/item/weapon/berriesgatherer)', tool)
        self.assertIn('ishuman(user) && berries > 0', tool)
        self.assertIn('harvest_berries(user, TRUE)', tool)
        self.assertIn('else\n\t\t..()', tool)
        regen = procedure(self.source, 'proc/berryproc')
        self.assertIn('spawn(3000)', regen)
        self.assertIn('berries++', regen)

    def test_each_success_spends_one_stock_and_schedules_one_regeneration(self):
        for gathering, expected_count in ((False, 1), (True, 2)):
            with self.subTest(gathering=gathering):
                bush, messages, outputs, waits = Bush(btype='amar'), [], [], []
                def wait(user, delay, target):
                    waits.append((user, delay, target))
                    return True
                project_harvest(self.source, wait, messages, outputs)(bush, 'actor', gathering)
                self.assertEqual(waits, [('actor', 80, bush)])
                self.assertEqual(outputs, ['amar'] * expected_count)
                self.assertEqual((bush.berries, bush.regenerations), (0, 1))
                self.assertEqual(any('collect some berries' in m for _, m in messages), not gathering)

    def test_interruption_and_lost_stock_do_not_produce_or_regenerate(self):
        for gathering in (False, True):
            for completed in (False, True):
                with self.subTest(gathering=gathering, completed=completed):
                    bush, messages, outputs = Bush(), [], []
                    def wait(user, delay, target):
                        if completed:
                            target.berries = 0
                        return completed
                    project_harvest(self.source, wait, messages, outputs)(bush, 'actor', gathering)
                    self.assertEqual(outputs, [])
                    self.assertEqual(bush.regenerations, 0)
                    self.assertEqual(bush.berries, 0 if completed else 1)
                    self.assertIn('no berries' if completed else 'stop ', messages[-1][1])

    def test_competing_harvests_cannot_both_spend_last_stock(self):
        bush, messages, outputs = Bush(), [], []
        def wait(user, delay, target):
            if user == 'first':
                action(target, 'second', True)
            return True
        action = project_harvest(self.source, wait, messages, outputs)
        action(bush, 'first', False)
        self.assertEqual(outputs, ['tinto', 'tinto'])
        self.assertEqual((bush.berries, bush.regenerations), (0, 1))
        self.assertIn(('first', 'There are no berries to harvest here.'), messages)

    def test_competition_control_detects_missing_stock_recheck(self):
        guarded = 'if (src && berries >= 1)'
        self.assertEqual(self.source.count(guarded), 1)
        faulty = self.source.replace(guarded, 'if (src)', 1)
        bush, messages, outputs = Bush(), [], []
        def wait(user, delay, target):
            if user == 'first':
                action(target, 'second', True)
            return True
        action = project_harvest(faulty, wait, messages, outputs)
        action(bush, 'first', False)
        self.assertEqual((len(outputs), bush.berries, bush.regenerations), (3, -1, 2))


if __name__ == '__main__':
    unittest.main()
