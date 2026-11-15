"""Leader orders: a weaker order must not extend a stronger one (#5488).

Offline source check; no compiler, game or network. The replacement rule is
evaluated from the DM source expression, and the receive proc is checked to
route Move, Hold and Focus through it.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/leader_orders.dm'
ORDERS = ('move', 'hold', 'focus')


def source():
    return SOURCE.read_text(encoding='utf-8-sig')


def replaces_rule(text):
    match = re.search(r'^/proc/leader_order_replaces\(now, old_strength, old_until, strength, until\)\n\treturn ([^\n]+)\n',
                      text, re.M)
    if not match:
        raise AssertionError('leader_order_replaces not found')
    expr = match.group(1).replace('||', ' or ').replace('&&', ' and ')
    return lambda now, old_strength, old_until, strength, until: eval(expr, {}, dict(
        now=now, old_strength=old_strength, old_until=old_until, strength=strength, until=until))


def receive(rule, state, now, strength, until):
    old_strength, old_until = state
    if rule(now, old_strength, old_until, strength, until):
        return strength, until
    return state


def bonus_strength(state, now):
    return state[0] if now < state[1] else 0


def legacy_receive(state, now, strength, until):
    # Frozen pre-fix logic: keep the stronger strength, take the later expiry.
    old_strength, old_until = state
    if now >= old_until or strength >= old_strength:
        old_strength = strength
    return old_strength, max(old_until, until)


class LeaderOrderExpiryTests(unittest.TestCase):
    def setUp(self):
        self.text = source()
        self.rule = replaces_rule(self.text)

    def scenario(self, apply):
        # Commander (strength 3, 40 s) at t=0, squad leader (strength 1, 20 s) at t=35 s.
        state = (0, 0)
        state = apply(state, 0, 3, 400)
        state = apply(state, 350, 1, 550)
        return state

    def test_weaker_order_does_not_extend_stronger_bonus(self):
        state = self.scenario(lambda s, now, st, u: receive(self.rule, s, now, st, u))
        self.assertEqual(bonus_strength(state, 390), 3)
        self.assertNotEqual(bonus_strength(state, 450), 3)

    def test_negative_control_legacy_logic_extends_bonus(self):
        state = self.scenario(legacy_receive)
        self.assertEqual(bonus_strength(state, 450), 3)

    def test_replacement_cases(self):
        rule = self.rule
        self.assertTrue(rule(500, 3, 400, 1, 700))   # expired: any order applies
        self.assertTrue(rule(100, 1, 400, 3, 300))   # stronger replaces
        self.assertTrue(rule(100, 2, 300, 2, 400))   # equal strength refreshes
        self.assertFalse(rule(100, 2, 400, 2, 300))  # equal but shorter keeps current
        self.assertFalse(rule(100, 3, 400, 1, 600))  # weaker never extends

    def test_every_order_uses_the_rule(self):
        body = re.search(r'^/mob/living/human/proc/receive_leader_order\(.*?(?=^\S)', self.text, re.M | re.S).group(0)
        self.assertNotIn('max(order_', body)
        for order in ORDERS:
            self.assertIn(f'if (leader_order_replaces(world.time, order_{order}_strength, order_{order}_until, strength, until))\n'
                          f'\t\t\t\torder_{order}_strength = strength\n'
                          f'\t\t\t\torder_{order}_until = until\n', body)


if __name__ == '__main__':
    unittest.main()
