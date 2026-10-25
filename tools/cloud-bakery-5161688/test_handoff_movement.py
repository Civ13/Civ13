"""Source contracts only; native return/location observations remain unproven."""
import unittest
from pathlib import Path
S=(Path(__file__).parent/'changed-source/filming/scene.dm').read_text(encoding='utf-8')
class HandoffMovement(unittest.TestCase):
 def block(self,who):
  return S.split(f'var/mob/living/human/{who}_identity =')[1].split('tree_grower.drop_item()' if who=='grower' else '\n\tfilming_check(logs.loc == tree_receiver')[0]
 def test_exact_starts(self):
  for who,tile in [('grower','6, 7, 1'),('receiver','7, 5, 1')]:
   b=self.block(who);self.assertIn(f'{who}_identity.loc == locate({tile})',b);self.assertLess(b.index('filming_check('),b.index('step(tree_'))
 def test_exact_destinations(self):
  for who,tile in [('grower','6, 6, 1'),('receiver','8, 5, 1')]:
   self.assertIn(f'{who}_identity.loc == locate({tile})',self.block(who))
 def test_identity_and_paid_item_before_after(self):
  for who in ['grower','receiver']:
   b=self.block(who)
   for token in [f'tree_{who} == {who}_identity',f'logs == {who}_timber']:self.assertIn(token,b)
   self.assertEqual(b.count(f'logs.loc == {who}_identity'),3)
   self.assertEqual(b.count('logs.amount == 7'),2)
 def test_no_offsets_or_teleport(self):
  for who in ['grower','receiver']:
   b=self.block(who)
   self.assertEqual(b.count(f'!{who}_identity.step_x && !{who}_identity.step_y'),2)
   self.assertNotRegex(b,r'\.loc\s*=(?!=)');self.assertNotIn('forceMove',b);self.assertNotIn('sleep(',b)
 def test_return_observed_not_acceptance(self):
  for who in ['grower','receiver']:
   b=self.block(who)
   self.assertEqual(b.count(f'step(tree_{who},'),1)
   self.assertIn(f'"step_return_numeric" = isnum({who}_step_return) ? {who}_step_return : null',b)
   self.assertIn(f'"step_return_null" = isnull({who}_step_return)',b)
   self.assertNotIn(f'filming_check({who}_step_return',b)
   self.assertNotIn('filming_check(step(',b)
 def test_bounded_diagnostics_precede_rejection(self):
  for who in ['grower','receiver']:
   b=self.block(who)
   self.assertIn(f'"start" = {who}_start',b)
   self.assertLess(b.index('text2file(json_encode'),b.index(f'filming_check(tree_{who} =='))
   self.assertIn('"filming-checks.txt")',b)
 def test_unchanged_final_deadline(self):
  self.assertIn('world.time - take_start <= 195',S)
  self.assertIn('logs.loc == tree_receiver && logs.amount == 7',S)
