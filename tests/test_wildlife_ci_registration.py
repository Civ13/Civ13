"""Offline CI selection checks for the default-off wildlife source contracts."""
import importlib.util
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('wildlife_ci_baseline',ROOT/'scripts/ci_baseline.py')
ci=importlib.util.module_from_spec(spec)
spec.loader.exec_module(ci)

class WildlifeCIRegistration(unittest.TestCase):
 def test_explicit_test_files_and_no_wildcard(self):
  suite=ci.SUITES['wildlife_offline']
  self.assertGreaterEqual(len(suite['files']),18)
  self.assertEqual(len(set(suite['files'])),len(suite['files']))
  for path in suite['files']:
   self.assertTrue(path.endswith('.py'))
   self.assertNotIn('*',path)
   self.assertTrue((ROOT/path).is_file(),path)
  self.assertIn('tests/test_wildlife_ci_registration.py',suite['files'])
  self.assertEqual(suite['paths'],())
 def test_changed_source_and_existing_vendor_inputs_select_offline_suite(self):
  for path in ('code/game/mob/living/simple_animal/subtile_movement.dm',
               'code/game/mob/living/simple_animal/hostile/tactical_ai.dm',
               'code/game/mob/mob_movement.dm',
               'code/game/objects/structures/vending/npc_vendors.dm',
               'tests/save_movement/source_adapter.py'):
   self.assertTrue(ci.impact([path])['suites']['wildlife_offline']['selected'],path)
 def test_missing_shared_input_fails_selection_negative_control(self):
  path='code/game/mob/living/simple_animal/subtile_movement.dm'
  suite=ci.SUITES['wildlife_offline'];old=suite['shared_paths']
  try:
   suite['shared_paths']=tuple(x for x in old if x!='code/game/mob/living/simple_animal/')
   # Another suite still owns this path; the negative is specifically the
   # direct shared-input match, independent of conservative global fallback.
   self.assertFalse(any(ci.matches(path,x) for x in suite['shared_paths']))
  finally:suite['shared_paths']=old

if __name__=='__main__':unittest.main(verbosity=2)
