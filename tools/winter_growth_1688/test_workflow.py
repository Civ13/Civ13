"""Text policy checks only, never hosted activation."""
import unittest
from pathlib import Path
from prepare import HEAD,TREE,canonical,digest
from backend_proposal import controller_hashes,ARCHIVE
class Workflow(unittest.TestCase):
 def test_one_shot_exact_activation(self):
  s=Path(__file__).parents[2].joinpath('.github/workflows/winter-growth-1688-once.yml').read_text()
  for value in ('codex/winter-growth-1688-ae99e2b-attempt3','github.event.created == true','github.run_attempt == 1','cancel-in-progress: false','contents: read',HEAD,TREE,ARCHIVE,'phases=3, compiler_phases=1, daemon_phases=2, aggregate_wall_seconds=600','--reviewed-native','--grant','timeout-minutes: 11','persist-credentials: false'):
   self.assertIn(value,s)
  self.assertLess(s.index('check_checkout.py'),s.index('Install reviewed Ubuntu'))
  self.assertNotIn('workflow_dispatch',s);self.assertNotIn('PENDING_',s)
  self.assertIn(digest(canonical(controller_hashes())),s)
