"""Hand mill credit stays with each worker (issue #4830)."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/production.dm'


def proc_body(text, header):
    start = text.index(header + '\n') + len(header) + 1
    lines = []
    for line in text[start:].splitlines():
        if line and not line.startswith('\t'):
            break
        lines.append(line)
    return '\n'.join(lines)


class HandMillWorkersTest(unittest.TestCase):
    def setUp(self):
        text = SOURCE.read_text(encoding='utf-8')
        self.finish = proc_body(text, '/obj/structure/mill/proc/finish_work()')
        self.produce = proc_body(text, '/obj/structure/mill/proc/produce(var/obj/item/weapon/reagent_containers/W, var/mob/living/human/H, var/obj/item/weapon/reagent_containers/P)')

    def test_credit_is_keyed_by_worker(self):
        # Positional slots shift when an earlier worker leaves; keys do not.
        self.assertNotIn('work_index', self.finish + self.produce)
        self.assertIn('workers_work[H]', self.finish)
        self.assertIn('workers_work[H] = 0', self.produce)
        self.assertIn('workers_work[H] = total_work', self.produce)
        self.assertNotIn('.Cut(', self.produce)
        self.assertIn('workers_list -= H', self.produce)
        self.assertIn('workers_work -= H', self.produce)

    def test_finished_batch_stops_waiting_workers(self):
        self.assertIn('batch_id++', self.finish)
        self.assertLess(self.finish.index('batch_id++'), self.finish.index('workers_work.Cut()'))
        wait = self.produce.index('do_after(H, 10')
        check = self.produce.index('if (batch_id != my_batch)')
        credit = self.produce.index('complete_percent +=')
        self.assertLess(self.produce.index('var/my_batch = batch_id'), wait)
        self.assertTrue(wait < check < credit)
        after_check = self.produce[check:].splitlines()[1].strip()
        self.assertTrue(after_check.startswith('return'), after_check)

    def test_worker_cannot_join_twice(self):
        guard = self.produce.index('if (H in workers_list)')
        self.assertLess(guard, self.produce.index('workers_list += H'))
        self.assertIn('return', self.produce[guard:].splitlines()[2])


if __name__ == '__main__':
    unittest.main()
