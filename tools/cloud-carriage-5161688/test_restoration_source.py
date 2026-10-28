"""Protect the native exact-restoration oracle; not native execution."""
from pathlib import Path
import unittest
class Restoration(unittest.TestCase):
 def test_actual_prior_values_are_read_before_first_inherited_step(self):
  s=(Path(__file__).parent/'changed-source/filming/lease_acceptance.dm').read_text()
  capture='intro_pre_drive_glide[A] = A.glide_size'
  self.assertEqual(s.count(capture),1)
  self.assertIn('if (!intro_lease_ticks.len)\n\t\tfor (var/atom/movable/A in list(src, intro_driver, intro_horse, intro_crate))',s)
  self.assertLess(s.index(capture),s.index('\t. = ..()'))
  self.assertIn('(A in intro_pre_drive_glide) && A.glide_size == intro_pre_drive_glide[A]',s)
  self.assertNotRegex(s,r'A\.glide_size\s*=(?!=)')
  self.assertEqual(s.count('"stopped member restored and unowned"'),1)
