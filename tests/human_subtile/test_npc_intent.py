"""Offline evaluation of the source's cross-producer ownership predicate."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/mob/living/simple_animal/subtile_movement.dm'
SLOTS = ('npc_subtile_pursuit', 'npc_subtile_follow', 'npc_subtile_flee', 'npc_subtile_pet_walk', 'npc_subtile_recovery', 'npc_subtile_wild_walk')


def evaluate(expression, context):
    expression = expression.replace('&&', ' and ').replace('||', ' or ')
    expression = re.sub(r'!(?!=)', ' not ', expression).strip()
    return bool(eval(expression, {'__builtins__': {}}, context))


class IntentOwnership(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')
        body = self.source.split('/mob/living/simple_animal/proc/npc_subtile_intent_valid(datum/owner)\n', 1)[1].split('// The AI chooses', 1)[0]
        self.reject = next(line.strip()[3:] for line in body.splitlines() if line.strip().startswith('if ('))
        self.accept = next(line.strip()[len('return '):] for line in body.splitlines() if line.strip().startswith('return !owner'))
        self.context = {slot: None for slot in SLOTS}
        self.context['owner'] = None

    def allowed(self):
        return not evaluate(self.reject, self.context) and evaluate(self.accept, self.context)

    def test_matching_owner_has_exclusive_access(self):
        self.assertTrue(self.allowed())
        for slot in SLOTS:
            with self.subTest(slot=slot):
                self.setUp()
                owner = object()
                self.context[slot] = owner
                self.assertFalse(self.allowed())  # unrelated normal wandering
                self.context['owner'] = owner
                self.assertTrue(self.allowed())
                self.context['owner'] = object()
                self.assertFalse(self.allowed())
                self.context['owner'] = owner
                other = next(name for name in SLOTS if name != slot)
                self.context[other] = object()
                self.assertFalse(self.allowed())  # conflicting owners fail closed

    def test_stale_owner_and_pulse_are_rejected(self):
        self.context['owner'] = object()
        self.assertFalse(self.allowed())
        admit = self.source.split('/mob/living/simple_animal/proc/ai_step(', 1)[1].split('/mob/living/simple_animal/proc/ai_step_wait(', 1)[0]
        self.assertLess(admit.index('!npc_subtile_intent_valid(intent_owner)'), admit.index('return Move('))
        self.assertLess(admit.index('T.intent_owner = intent_owner'), admit.index('T.advance()'))
        transaction = self.source.split('/datum/npc_subtile_transaction/proc/valid()\n', 1)[1].split('/datum/npc_subtile_transaction/proc/advance()', 1)[0]
        self.assertIn('actor.npc_subtile_intent_valid(intent_owner)', transaction)
        finish = self.source.split('/datum/npc_subtile_transaction/proc/finish()\n', 1)[1].split('/mob/living/simple_animal/proc/npc_subtile_take_pulse', 1)[0]
        self.assertIn('actor.npc_subtile_intent_valid(intent_owner)', finish)


if __name__ == '__main__':
    unittest.main()
