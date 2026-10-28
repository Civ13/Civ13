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
  self.assertIn("P.stage = P.readyStageMin",s)
  self.assertIn("P.sprite_plant ? P.sprite_plant : P.plant",s)
  self.assertIn("P.attackby(harvest_tool, harvest_actor)",s)
  self.assertIn("harvest_targets.Copy()",s)
  for t in ["P.growth()","P.spawn_produce()","P.spawn_seeds()"]:self.assertNotIn(t,s)
  self.assertNotRegex(s,r"new\s+/obj/.+(?:grown/wheat|seeds/wheat)")

SEALS={'actions.dm': '606e289004e53e8ed9cef0b4b485abd454bb33a0ce602b14bcf2a4a2bd715790', 'scene.dm': 'bf81f6d97b37ff544a536ac3c361855353b7509ff1f325e546bb089b2b2ece1f', 'harvest.dmm': '55f245424868c71ef3838b4c66a1c042a2ab7a4336837ac996a113f4737dafea'}
