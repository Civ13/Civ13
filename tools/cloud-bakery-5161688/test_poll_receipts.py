"""Source contracts: repeated poll predicates remain active; success text is bounded."""
from pathlib import Path
import unittest
S=(Path(__file__).parent/'changed-source/filming/scene.dm').read_text(encoding='utf-8')
class PollReceipts(unittest.TestCase):
 def test_all_original_predicates_evaluated(self):
  for expression,label,index in [
   ('worker == flax_worker && worker.client == filming_observer_client && filming_observer_client.mob == worker','same real guest during bounded soak-stage observation',1),
   ('!QDELETED(bundle) && site == flax_water && bundle.soak_stage >= 0 && bundle.soak_stage <= 1','same unfinished bundle and exact authored water during observation',2),
   ('bundle.loc == worker && bundle.soak_stage == 0 && !bundle.soaking && worker.loc == locate(6, 7, 1)','only original held bundle may await normal water placement',3)]:
   self.assertIn(f'flax_poll_assert({expression}, "{label}", passed, {index}, polls)',S)
 def test_failure_keeps_label_before_same_assertion(self):
  b=S.split('/proc/flax_poll_assert(')[1].split('/proc/flax_interrupt_after_first_stage(')[0]
  self.assertLess(b.index('"poll_failure" = label'),b.index('filming_check(ok, label)'));self.assertLess(b.index('filming_check(ok, label)'),b.index('counts[index]++'))
  self.assertNotIn('sleep(',b);self.assertEqual(b.count('text2file('),1)
 def test_bounded_transitions_and_no_stage_changes(self):
  b=S.split('/proc/flax_interrupt_after_first_stage(')[1].split('/proc/filming_bind_flax(')[0]
  self.assertIn('polls > 300',b);self.assertIn('var/list/passed = list(0, 0, 0)',b);self.assertEqual(b.count('"poll_transition"'),2)
  self.assertNotIn('.soak_stage = ',b);self.assertIn('sleep(0.5)',b);self.assertIn('world.time < deadline',b)
