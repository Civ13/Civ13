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
  self.assertIn("world.time - work_started >= 70",s)
  self.assertIn("QDELETED(mill_input)",s)
  self.assertNotIn("film_mill.finish_work()",s)
  self.assertNotRegex(s,r"film_mill.complete_percent\s*=(?!=)")
  self.assertNotRegex(s,r"mill_actor.stats.*=(?!=)")
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

SEALS={'actions.dm': '86f6184f5b1dbc044c6f065c00d15eb58457aaeedf7bbb1a634ff3636f01816a', 'scene.dm': '1a41893f410949f310d3f0aa182b547d236207d7e830a27dc1b259abe9b9e778', 'mill.dmm': 'bf6c99352d4db0cb1c2c85b0441d10d425665fe6038d324cede8b411c434ded2'}
