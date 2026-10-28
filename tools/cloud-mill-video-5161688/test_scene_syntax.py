from pathlib import Path
import hashlib,re,unittest
HERE=Path(__file__).resolve().parent
class Scene(unittest.TestCase):
 def test_sealed_source(self):
  for n,h in SEALS.items():self.assertEqual(hashlib.sha256((HERE/'changed-source/filming'/n).read_bytes()).hexdigest(),h)
 def test_unchanged_scaffold_bounds(self):
  s=(HERE/'changed-source/filming/scene.dm').read_text()
  for t in ['maxx == 15 && maxy == 15 && maxz == 1','spawn(1200)','world.fps','first owned sample releases unchanged action']:
   self.assertIn(t,s)
  self.assertNotRegex(s,r'(?m)^\tmax[xyz]\s*=')
 def test_real_production_interactions(self):
  s=(HERE/'changed-source/filming/actions.dm').read_text()
  self.assertIn("film_mill.attackby(mill_input, mill_actor)",s)
  self.assertIn("world.time - work_started >= work_steps*10",s)
  self.assertIn("QDELETED(mill_input)",s)
  self.assertNotIn("film_mill.finish_work()",s)
  self.assertNotRegex(s,r"film_mill.complete_percent\s*=(?!=)")
  self.assertNotRegex(s,r"mill_actor.stats[^\n]*\]\s*=(?!=)")
  self.assertNotRegex(s,r"new\s+/obj/.+condiment/flour")

 def test_prepared_marker_precedes_arming_and_controller_waits(self):
  s=(HERE/'changed-source/filming/scene.dm').read_text()
  p=s.split('/proc/intro_prepare()\n',1)[1].split('/proc/intro_life_loop()',1)[0]
  ordered=['mill_prepare()', 'sleep(10)', 'capable actor after native render settling', 'intro_prepared = TRUE', 'text2file("ready; prepared native mill scene", "intro-ready.txt")']
  indices=[p.index(t) for t in ordered];self.assertEqual(indices,sorted(indices))
  self.assertEqual(s.count('"intro-ready.txt"'),1)
  self.assertIn('O.Prepare_mill()\n\t\tO.Run_mill()',s)
  self.assertIn('ack_deadline = world.time + 50',s)
  self.assertIn('!intro_prepared || intro_started || intro_stopping',s)
  controller=(HERE/'run_scene.py').read_text()
  self.assertLess(controller.index("wait_file('intro-ready.txt')"),controller.index("wait_file('intro-armed.txt', 'armed')"))
  self.assertLess(controller.index("wait_file('intro-armed.txt', 'armed')"),controller.index("result['recording'] = record_scene"))

 def test_read_only_progress_and_no_mood_override(self):
  a=(HERE/'changed-source/filming/actions.dm').read_text()
  for token in ['ceil(100/work_increment)', '6*strength + 6*stamina + 3*dexterity', 'mill_progress_observations.len == work_steps', 'row["time"] >= work_started + (i-1)*10', 'unchanged native raw stats and effective coefficients during work']:
   self.assertIn(token,a)
  self.assertNotRegex(a,r'mill_actor\.(?:mood|mood_modifier)\s*=(?!=)')
  self.assertNotRegex(a,r'mill_actor.stats[^\n]*\]\s*=(?!=)')
  self.assertNotIn('/intro_actor/Life()',a)

 def test_honest_clear_outdoor_prop_staging(self):
  a=(HERE/'changed-source/filming/actions.dm').read_text()
  for token in ['mill_tile = locate(10,6,1)', 'actor_tile = locate(10,5,1)', 'new /obj/structure/mill(mill_tile)', '!A.density && !A.opacity', '"mill_staged" = TRUE', '"original_mill_location_claim" = FALSE']:
   self.assertIn(token,a)
  self.assertNotRegex(a,r'(?m)^\s*\w+\.(?:sight|opacity|density|see_in_dark|see_invisible)\s*=')

SEALS={'actions.dm': '97dce068be4842b3af28e31738039694991fa5e56674e5f1ddf48a4e727e98e4', 'scene.dm': 'dfe56d32aa126fef408f0e17b6e4bfef7f16d3a7251410569d15695a66004614', 'mill.dmm': '55f245424868c71ef3838b4c66a1c042a2ab7a4336837ac996a113f4737dafea'}
