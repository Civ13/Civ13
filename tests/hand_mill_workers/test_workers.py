"""Hand mill credit stays with each worker (issue #4830)."""
from pathlib import Path
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

    def test_work_interval_targets_and_revalidates_mill(self):
        self.assertIn('do_after(H, 10, src, TRUE, FALSE)', self.produce)
        wait = self.produce.index('do_after(H, 10')
        credit = self.produce.index('complete_percent +=')
        guard = self.produce[wait:credit]
        for check in ('QDELETED(src)', 'interval_epoch == work_epoch', 'anchored',
                      'isturf(loc)', 'in_range(H, src)', 'has_hand_mill_input()'):
            self.assertIn(check, guard)
        self.assertLess(self.produce.index('var/interval_epoch = work_epoch'), wait)

    def test_move_away_and_back_or_quick_refasten_invalidates_old_wait(self):
        text = SOURCE.read_text(encoding='utf-8')
        for header in ('/obj/structure/mill/Move()',
                       '/obj/structure/mill/forceMove(atom/destination, special_event, list/throw_hop_token = null)',
                       '/obj/structure/mill/wrench_action(mob/living/human/H)'):
            hook = proc_body(text, header)
            self.assertLess(hook.index('. = ..()'), hook.index('work_epoch++'))
            self.assertNotIn('complete_percent', hook)
            self.assertNotIn('batch_id', hook)

    def test_paid_grain_is_a_direct_child_before_staging_output(self):
        transfer = self.produce.index('H.transfer_held_item_to(W, src)')
        self.assertLess(transfer, self.produce.index('current_material = W'))
        self.assertLess(transfer, self.produce.index('current_work = new P(null)'))
        text = SOURCE.read_text(encoding='utf-8')
        custody = proc_body(text, '/obj/structure/mill/proc/has_hand_mill_input()')
        self.assertIn('current_material.loc == src', custody)
        self.assertLess(self.finish.index('!has_hand_mill_input()'), self.finish.index('qdel(current_material)'))
        hammer = proc_body(text, '/obj/structure/proc/hammer_action(var/mob/living/human/H, var/obj/item/weapon/W, var/work_amount = 50, var/list/components = list(), var/list/quantities = list())')
        self.assertLess(hammer.index('P.loc = src.loc'), hammer.index('qdel(src)'))

    def test_dismantling_cancels_staged_output_and_does_not_consume_grain(self):
        text = SOURCE.read_text(encoding='utf-8')
        cancel = proc_body(text, '/obj/structure/mill/proc/cancel_hand_mill_batch()')
        destroy = proc_body(text, '/obj/structure/mill/Destroy()')
        self.assertIn('cancel_hand_mill_batch()', destroy)
        self.assertIn('qdel(current_work)', cancel)
        self.assertNotIn('qdel(current_material)', cancel)
        self.assertNotIn('new ', cancel)
        self.assertIn('batch_id++', cancel)
        self.assertIn('workers_work[worker]', cancel)
        self.assertIn('workers_work.Cut()', cancel)

    def test_worker_cannot_join_twice(self):
        guard = self.produce.index('if (H in workers_list)')
        self.assertLess(guard, self.produce.index('workers_list += H'))
        self.assertIn('return', self.produce[guard:].splitlines()[2])


if __name__ == '__main__':
    unittest.main()
