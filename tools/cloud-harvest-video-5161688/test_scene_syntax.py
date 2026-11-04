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

 def test_prepared_marker_precedes_arming_and_controller_waits(self):
  s=(HERE/'changed-source/filming/scene.dm').read_text()
  p=s.split('/proc/intro_prepare()\n',1)[1].split('/proc/intro_life_loop()',1)[0]
  ordered=['harvest_prepare()', 'sleep(10)', 'capable actor after native render settling', 'intro_prepared = TRUE', 'text2file("ready; prepared native harvest scene", "intro-ready.txt")']
  indices=[p.index(t) for t in ordered];self.assertEqual(indices,sorted(indices))
  self.assertEqual(s.count('"intro-ready.txt"'),1)
  self.assertIn('O.Prepare_harvest()\n\t\tO.Run_harvest()',s)
  self.assertIn('ack_deadline = world.time + 50',s)
  self.assertIn('!intro_prepared || intro_started || intro_stopping',s)
  controller=(HERE/'run_scene.py').read_text()
  self.assertLess(controller.index("wait_file('intro-ready.txt')"),controller.index("wait_file('intro-armed.txt', 'armed')"))
  self.assertLess(controller.index("wait_file('intro-armed.txt', 'armed')"),controller.index("result['recording'] = record_scene"))

 def test_visible_south_side_staging_only(self):
  a=(HERE/'changed-source/filming/actions.dm').read_text()
  s=(HERE/'changed-source/filming/scene.dm').read_text()
  self.assertIn('harvest_actor = new(locate(8,8,1))',a)
  self.assertIn('harvest_actor.dir = NORTH',a)
  self.assertIn('var/turf/actor_turf = locate(8,8,1)',s)

SEALS={'actions.dm': '2f6b2495a63c2182f16178250f0ead0c7b7b405f15d7b7daef65254e5138ea34', 'scene.dm': '8e561d89fa4e18bf2e0f27b633503cc12862d86ae7d2be594ce0e1795657899e', 'harvest.dmm': '55f245424868c71ef3838b4c66a1c042a2ab7a4336837ac996a113f4737dafea'}
