"""Offline source contracts; no native timing/visual success claim."""
import json,re,unittest
from pathlib import Path
ROOT=Path(__file__).parent
S=(ROOT/'changed-source/filming/scene.dm').read_text(encoding='utf-8')
TAKE=S.split('/proc/filming_take()')[1].split('/proc/filming_lighting_loop()')[0]
class TanningShowcase(unittest.TestCase):
 def test_paid_stage_order(self):
  tokens=['sleep(15)','tan_raw.attackby(tan_knife, tan_worker)','world.time - scrape_start >= 50','prepared.attackby(tan_bucket, tan_worker)','tan_bark.attackby(tan_bucket, tan_worker)','tan_rack.attackby(wet, tan_worker)','sleep(35)','tan_rack.attack_hand(tan_worker)','dried.attackby(tan_bucket, tan_worker)','filming_pickup(tan_receiver, leather)']
  pos=[TAKE.index(t) for t in tokens];self.assertEqual(pos,sorted(pos))
 def test_paid_sources_and_quantities(self):
  for token in ['QDELETED(tan_raw)','QDELETED(prepared)','QDELETED(tan_bark)','QDELETED(wet)','QDELETED(dried)','prepared.amount == 1','wet.amount == 1','dried.amount == 1','leather.amount == 1','get_reagent_amount("water") == 10','get_reagent_amount("water") == 0','get_reagent_amount("tannin") == 10','get_reagent_amount("tannin") == 5']:
   self.assertIn(token,TAKE)
 def test_no_fabricated_outputs_or_gate_override(self):
  for bad in ['new ', 'new(', 'forceMove(', 'finish_hide_drying(', 'start_hide_drying(', 'add_reagent(', '/hide_worker_connected(', '/hide_preparation_wait(']:self.assertNotIn(bad,TAKE)
  self.assertNotRegex(TAKE,r'\.(?:loc|amount|client|key|ckey|delay|filled|drying_epoch)\s*=(?!=)')
  for bad in ['/hide_worker_connected(', '/hide_preparation_wait(', '/finish_hide_drying(']:self.assertNotIn(bad,S)
 def test_duration_is_only_fixture_rack(self):
  self.assertIn('tan_rack.delay == 300',S);self.assertEqual(S.count('tan_rack.delay = 30'),1)
  self.assertNotIn('delay = 30',TAKE)
  self.assertEqual(15+50+10+10+10+35+10+20+10+15,185)
  self.assertIn('world.time - take_start <= 195',TAKE)
 def test_actual_guest_binding_and_no_impersonation(self):
  new=S.split('/client/New()')[1].split('/client/Del()')[0]
  self.assertLess(new.index('istype(mob, /mob/filming_observer)'),new.index('mob = tan_worker'))
  self.assertIn('mob == tan_worker && tan_worker.client == src && tan_worker.key == key',new)
  self.assertNotRegex(S,r'\.(?:client|key|ckey)\s*=(?!=)')
  self.assertEqual(TAKE.count('tan_worker.client == filming_observer_client'),3)
 def test_worker_login_isolation_and_input(self):
  login=S.split('/mob/living/human/filming_worker/Login()')[1].split('/mob/living/human/filming_worker/Logout()')[0]
  self.assertIn('src == tan_worker && client && client == filming_observer_client && client.mob == src',login)
  self.assertNotIn('..()',login);self.assertIn('verbs.Copy()',login);self.assertIn('filming_check(!verbs.len',login)
  for proc in ['Click','DblClick','MouseDown','MouseUp','MouseDrop','MouseDrag','MouseMove','MouseEntered','MouseExited','Topic','North','South','East','West','Northeast','Northwest','Southeast','Southwest','Center']:self.assertIn('/client/'+proc+'()\n\treturn null',S)
  self.assertIn('/client/Move()\n\treturn FALSE',S)
  self.assertIn('filming_stop("guest worker disconnected or reassigned")',S)
 def test_exact_tight_native_camera(self):
  skin=(ROOT/'changed-source/filming/cloud.dmf').read_text(encoding='utf-8')
  for token in ['zoom = 3','zoom-mode = normal','letterbox = true','statusbar = false']:self.assertIn(token,skin)
  self.assertEqual(skin.count('size = 480x480'),2);self.assertEqual(S.count('\tview = 2'),2)
  self.assertIn('eye = locate(7, 7, 1)',S);self.assertIn('perspective = EYE_PERSPECTIVE',S)
  self.assertEqual(5*32*3,480)
 def test_staging_caption(self):
  enc=(ROOT/'encode_local.py').read_text(encoding='utf-8')
  for token in ['supplied raw hide','Full five-second scraping','thirty seconds to three seconds','same-leather handoff']:self.assertIn(token,enc)
 def test_initial_forbidden_outputs(self):
  initial=S.split('/proc/filming_assert_tanning_initial()')[1].split('/proc/tanning_beat')[0]
  for name in ['hairlesshide','wethide','dryhide','leather']:self.assertIn('!(locate(/obj/item/stack/material/'+name+') in T)',initial)
  self.assertIn('!tan_rack.contents.len',initial)

 def test_visible_stage_placement_uses_inventory_not_teleport(self):
  self.assertIn('tan_raw = new(locate(7, 6, 1), 1)',S)
  self.assertIn('tan_raw.Adjacent(tan_worker) && tan_worker.Adjacent(tan_raw)',S)
  tokens=['tan_rack.attack_hand(tan_worker)','filming_pickup(tan_worker, dried)','preparation_site.Adjacent(tan_worker)','filming_drop_tanner(preparation_site)','dried.loc == preparation_site','dried.attackby(tan_bucket, tan_worker)','leather = locate() in preparation_site']
  positions=[TAKE.index(t) for t in tokens];self.assertEqual(positions,sorted(positions))

 def test_world_definition_not_split_by_fixture_overrides(self):
  world=S.split('/world\n',1)[1].split('\n/world/OpenPort',1)[0]
  for line in ['\tmob = /mob/filming_observer','\tview = 2','\tfps = 20']:self.assertIn(line,world)
  self.assertNotRegex(world,r'(?m)^/')
  self.assertEqual(S.count('\n/mob/filming_observer\n'),1)

 def test_production_paths_match_source_closure_and_are_unmodified(self):
  pins=json.loads((ROOT/'tanning-production-bindings.json').read_text(encoding='utf-8'))
  manifest=json.loads((ROOT/'v4-source-manifest.json').read_text(encoding='utf-8'))
  rows={x['path']:x for x in manifest['materialization_allowlist']}
  changes=json.loads((ROOT/'derived-source.json').read_text(encoding='utf-8'))['changes']
  self.assertEqual(pins['revision'],manifest['revision'])
  for item in pins['unchanged_production']:
   self.assertNotIn(item['path'],changes)
   self.assertEqual(item['git_blob'],rows[item['path']]['git_blob'])
