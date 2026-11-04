from pathlib import Path
import unittest
HERE=Path(__file__).resolve().parent
class ActorFixture(unittest.TestCase):
 def test_proven_headless_lifecycle(self):
  s=(HERE/'changed-source/filming/scene.dm').read_text()
  a=(HERE/'changed-source/filming/actions.dm').read_text()
  self.assertIn('/mob/living/human/intro_actor/ssd_check()\n\treturn FALSE',s)
  self.assertNotIn('/mob/living/human/ssd_check()',s)
  self.assertNotIn('/mob/living/human/intro_actor/Life()',s)
  self.assertIn('harvest_actor.Life()',s)
  self.assertIn('!harvest_actor.client && !harvest_actor.ckey && !harvest_actor.incapacitated()',a)
  self.assertIn('capable actor after native render settling',s)
