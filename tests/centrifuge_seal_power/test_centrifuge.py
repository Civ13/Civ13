"""Centrifuge lids and grid reservations (issues 5514 and 5516).

Offline source check; does not execute BYOND. It replays attack_hand's
else-if chain with fake state to see which starts reserve grid capacity.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/reagents/Chemistry-Machinery.dm'


def proc(text, header):
    start = text.index(header + '\n') + len(header) + 1
    end = re.compile(r'^\S', re.M).search(text, start)
    return text[start:end.start()]


def chain(body):
    """Return (condition, rejects) for each top-level if/else-if of a proc."""
    steps, lines = [], body.splitlines()
    for index, line in enumerate(lines):
        match = re.match(r'\t(?:else )?if \((.*)\)$', line) or re.match(r'\t(else)$', line)
        if not match:
            continue
        block = []
        for follow in lines[index + 1:]:
            if follow.startswith('\t\t') or not follow.strip():
                block.append(follow.strip())
            else:
                break
        steps.append((match.group(1), 'return' in block and not any(b.startswith('return ..') for b in block)))
    return steps


def start(steps, state):
    """Walk the chain; return (started, power_was_checked)."""
    checked = False
    for condition, rejects in steps:
        if condition == 'else':
            return True, checked
        if 'check_power()' in condition:
            checked = True
            truth = not state['power']
        else:
            expr = (condition.replace('!anchored', 'not anchored').replace('istype(H) && ', '')
                    .replace('H.getStatCoeff("medical") < GET_MIN_STAT_COEFF(STAT_MEDIUM_HIGH)', 'unskilled')
                    .replace('reagents.total_volume <= 0', 'empty')
                    .replace('!collector.is_open_container()', 'sealed')
                    .replace('!collector', 'not collector'))
            truth = eval(expr, {}, dict(state))
        if truth:
            return False, checked
    return False, checked


READY = dict(anchored=True, unskilled=False, active=False, empty=False, collector=True, sealed=False, power=True)


class CentrifugeChecks(unittest.TestCase):
    def setUp(self):
        self.text = SOURCE.read_text(encoding='utf-8')
        self.hand = chain(proc(self.text, '/obj/structure/centrifuge/attack_hand(var/mob/living/human/H)'))

    def test_ready_centrifuge_starts_after_power_check(self):
        self.assertEqual(start(self.hand, READY), (True, True))

    def test_rejected_starts_reserve_no_power(self):
        for change in ({'empty': True}, {'collector': False}, {'sealed': True}, {'active': True}):
            with self.subTest(change=change):
                self.assertEqual(start(self.hand, {**READY, **change}), (False, False))

    def test_finished_cycle_releases_its_reservation(self):
        machine = proc(self.text, '/obj/structure/centrifuge/proc/process_machine()')
        tail = machine[machine.index('var/separated = separate_batch()'):]
        self.assertLess(tail.index('active = FALSE'), tail.index('release_power()'))
        release = proc(self.text, '/obj/structure/centrifuge/proc/release_power()')
        self.assertIn('powersource.update_power(-powerneeded, 1, src)', release)

    def test_sealed_glass_neither_pours_nor_collects(self):
        attack = proc(self.text, '/obj/structure/centrifuge/attackby(obj/item/W as obj, var/mob/living/human/user as mob)')
        guard = 'if (istype(B, /obj/item/weapon/reagent_containers/glass) && !B.is_open_container())'
        self.assertIn(guard, attack)
        self.assertLess(attack.index(guard), attack.index('trans_to_holder'))
        self.assertLess(attack.index(guard), attack.index('collector =  B'))
        batch = proc(self.text, '/obj/structure/centrifuge/proc/separate_batch()')
        self.assertIn('!collector.is_open_container()', batch.splitlines()[0])

    def test_old_order_is_caught(self):
        old = [(c, r) for c, r in self.hand if 'check_power' in c] + [(c, r) for c, r in self.hand if 'check_power' not in c]
        self.assertEqual(start(old, {**READY, 'empty': True})[1], True)


if __name__ == '__main__':
    unittest.main()
