"""Source-only scene contracts, not native timing or visual acceptance."""
import hashlib,json,re,unittest
from unittest.mock import patch
from pathlib import Path
ROOT=Path(__file__).parent
SCENE=(ROOT/'changed-source/filming/scene.dm').read_text(encoding='utf-8')
class TreeShowcase(unittest.TestCase):
 def test_paid_production_sequence(self):
  take=SCENE.split('/proc/filming_take()')[1].split('/proc/filming_lighting_loop()')[0]
  tokens=['sleep(15)','tree_plot.attackby(tree_seeds, tree_grower)','tree_seeds.amount == 1','pulse <= 6','P.growth_time_left = 10','P.process_interval(1)','soil_before - 3','tree_bucket.secondary_attack_self(tree_grower)','P.water == 80','soil_nutrition == 132','mature.attackby(tree_hatchet, tree_grower)','world.time - chop_start >= 46.5','tool_health - 0.25','logs.amount == 7','filming_pickup(tree_receiver, logs)','logs.loc == tree_receiver']
  for t in tokens:self.assertIn(t,take)
  self.assertLess(take.index('tree_plot.attackby'),take.index('P.process_interval'))
  self.assertLess(take.index('P.process_interval'),take.index('mature.attackby'))
  self.assertLess(take.index('mature.attackby'),take.index('filming_pickup(tree_receiver, logs)'))
 def test_only_duration_compressed_not_results(self):
  take=SCENE.split('/proc/filming_take()')[1].split('/proc/filming_lighting_loop()')[0]
  for bad in ['new ', 'new(', '.stageGrowth(', '.try_destroy(', 'forceMove(']:self.assertNotIn(bad,take)
  for field in ['stage','icon','icon_state','health','water','plant_nutrition','last_growth_tick','loc']:
   self.assertNotRegex(take,r'\.'+field+r'\s*=(?!=)')
  self.assertEqual(take.count('P.growth_time_left = 10'),1)
  self.assertIn('sleep(10)\n\t\tvar/soil_before',take)
 def test_initial_state_and_same_item_handoff(self):
  for t in ['tree_seeds.amount == 2','tree_bucket.reagents.total_volume == 15','initial plot has no fabricated plant or tree','initial plot has no finished timber','logs.loc == locate(6, 6, 1)','logs.loc == tree_receiver && logs.amount == 7','step(tree_receiver, EAST)']:
   self.assertIn(t,SCENE)
 def test_framing_and_capture_bounds(self):
  skin=(ROOT/'changed-source/filming/cloud.dmf').read_text(encoding='utf-8')
  self.assertEqual(skin.count('size = 480x480'),2)
  for t in ['zoom = 2','zoom-mode = normal','letterbox = true','statusbar = false']:self.assertIn(t,skin)
  self.assertEqual(SCENE.count('\tview = 3'),2)
  recording=(ROOT/'recording.py').read_text(encoding='utf-8')
  for t in ['COUNT, FPS, SIZE = 80, 4, (480, 480)','MAX_LATE = 0.20']:self.assertIn(t,recording)
 def test_all_stages_and_hold_budget(self):
  self.assertIn('P.stage == pulse',SCENE);self.assertIn('P.stage == pulse + 1',SCENE)
  self.assertIn('P.icon_state == "tree-grow[pulse + 1]"',SCENE)
  self.assertEqual(15+15+6*10+10+20+46.5+10+5+5,186.5)
  self.assertIn('world.time - take_start <= 195',SCENE)
 def test_art_disclosure_and_no_appearance_claim(self):
  notes=(ROOT/'TREE-STORYBOARD.md').read_text(encoding='utf-8')
  self.assertIn('pixel-identical',notes);self.assertIn('not measured hosted timings',notes)
  self.assertIn('sixty-second tree growth stages compressed to one second', (ROOT/'encode_local.py').read_text(encoding='utf-8'))
 def test_storyboard_read_ignores_windows_legacy_locale(self):
  notes=ROOT/'TREE-STORYBOARD.md'
  # Exact retained UTF-8 input reproduces the hosted cp1252 failure.
  with self.assertRaises(UnicodeDecodeError): notes.read_bytes().decode('cp1252')
  original_open=Path.open
  def legacy_open(path, mode='r', buffering=-1, encoding=None, errors=None, newline=None):
   if 'b' not in mode and encoding is None: encoding='cp1252'
   return original_open(path,mode,buffering,encoding,errors,newline)
  with patch.object(Path,'open',legacy_open):
   self.test_art_disclosure_and_no_appearance_claim()
  self.assertIn('pixel-identical',notes.read_text(encoding='utf-8'))
 def test_current_closure_and_unchanged_guard_hashes(self):
  pins=json.loads((ROOT/'tree-source-contract.json').read_text(encoding='utf-8'))
  self.assertEqual(pins['revision'],'9683866a89d2bdc12f8dc7d25444e350583c5483')
  for n,h in pins['unchanged_guard_sha256'].items():self.assertEqual(hashlib.sha256((ROOT/n).read_bytes()).hexdigest(),h,n)
  self.assertEqual(hashlib.sha256((ROOT/'capture.py').read_bytes()).hexdigest(),pins['diagnostic_capture_delta']['current_sha256'])
  activation=pins['activation_only_guard']
  normalized=(ROOT/activation['file']).read_text(encoding='utf-8').replace(activation['new_branch'],activation['old_branch'])
  self.assertEqual(hashlib.sha256(normalized.encode()).hexdigest(),activation['prior_sha256'])
  dme=(ROOT/'changed-source/civ13.dme').read_text(encoding='utf-8')
  paths={x['path'] for x in json.loads((ROOT/'v4-source-manifest.json').read_text(encoding='utf-8'))['materialization_allowlist']}
  derived=json.loads((ROOT/'derived-source.json').read_text(encoding='utf-8'))['changes']
  for n in re.findall(r'^#include "([^"]+)"',dme,re.M):self.assertIn(n.replace('\\','/'), paths|set(derived))
if __name__=='__main__':unittest.main()
