from pathlib import Path
import re
import unittest
ROOT=Path(__file__).resolve().parents[2]
class NodeLessons(unittest.TestCase):
 def setUp(self):
  self.s=(ROOT/'code/modules/research_tree/node_broadcast.dm').read_text()
 def test_bounded_duration_and_roster(self):
  for token in ('NODE_LESSON_DURATION 3000','NODE_LESSON_MAX_LISTENERS 32','NODE_LESSON_MAX_STATIONS 16','NODE_LESSON_COOLDOWN 600','audience[listener] = R'):
   self.assertIn(token,self.s)
 def test_live_eligibility(self):
  for token in ('client.inactivity < NODE_LESSON_AFK_LIMIT','!sleeping','H.can_learn_recipe_node(node_id)','H.knows_recipe_node(node_id)','node_receiver_available(R)','H in view(3, R)','has_antenna()'):
   self.assertIn(token,self.s)
 def test_progress_cannot_catch_up_or_join_late(self):
  tick=self.s.split('/obj/structure/telecom/station/proc/tick_node_lesson()')[1].split('/proc/civ_tick_node_lessons()')[0]
  self.assertIn('elapsed > 20',tick)
  self.assertIn('node_lesson_listeners.Remove(listener)',tick)
  self.assertNotIn('node_lesson_listeners[listener] =',tick)
  self.assertLess(tick.index('stop_node_lesson(FALSE)'),tick.index('listener.learn_recipe_node'))
 def test_state_is_transient(self):
  telecom=(ROOT/'code/modules/1713/modern_telecom.dm').read_text()
  for key in ('node_lesson_id','node_lesson_teacher','node_lesson_listeners','node_lesson_progress','node_lesson_last_tick','node_lesson_cooldown_until'):
   self.assertRegex(self.s,r'var/tmp/[^\n]*'+key)
   self.assertIn('"'+key+'"',telecom)
  self.assertIn('civ_tick_node_lessons()',telecom)
 def test_native_harness_is_opt_in_trusted(self):
  runner=(ROOT/'tests/node_broadcast/run.py').read_text()
  self.assertIn('if args.trusted:',runner)
  self.assertIn('if args.compile_only:',runner)
  fixture=(ROOT/'tests/node_broadcast/game.dm').read_text()
  for text in ('partial 299-second','late joiner','retuning','audience bounded at 32','research ceiling','unobserved scheduler gaps'):
   self.assertIn(text,fixture)
if __name__=='__main__': unittest.main()
