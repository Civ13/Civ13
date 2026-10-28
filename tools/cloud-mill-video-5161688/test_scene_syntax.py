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

SEALS={'actions.dm': '86f6184f5b1dbc044c6f065c00d15eb58457aaeedf7bbb1a634ff3636f01816a', 'scene.dm': '72f79a72ea8d2c58f6b53f5b8e40e2a722921696f8ca5404b645a0e800634e65', 'mill.dmm': 'bf6c99352d4db0cb1c2c85b0441d10d425665fe6038d324cede8b411c434ded2'}
