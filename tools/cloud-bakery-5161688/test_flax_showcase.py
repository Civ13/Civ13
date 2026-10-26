"""Offline contracts only; native stages, timing and visuals still require reviewed run."""
import hashlib,json,re,unittest
from pathlib import Path
ROOT=Path(__file__).parent
S=(ROOT/'changed-source/filming/scene.dm').read_text(encoding='utf-8')
TAKE=S.split('/proc/filming_take()')[1].split('/proc/filming_lighting_loop()')[0]
INTERRUPT=S.split('/proc/flax_interrupt_after_first_stage(')[1].split('/proc/filming_take()')[0]
class FlaxChapterA(unittest.TestCase):
 def test_actual_paid_handler_order(self):
  tokens=['sleep(20)','filming_pickup(flax_worker, flax_raw)','filming_bind_flax(flax_raw)','QDELETED(flax_raw)','bundle.soak_stage == 0','flax_interrupt_after_first_stage(bundle, flax_worker, flax_water, deadline)','filming_interact_flax(bundle)','world.time - soak_start >= 100','bundle.soak_stage == 1','sleep(40)','world.time - take_start <= 195']
  positions=[TAKE.index(t) for t in tokens];self.assertEqual(positions,sorted(positions))
 def test_full_production_wait_no_override(self):
  for bad in ['/flax_processing_wait(', '/soak(', '/finish_stage(', 'finish_stage(', 'flax_processing_wait(', '.soak(', '.soak_stage = ', '.stage = ', '.amount = ', 'forceMove(', '.loc = ', 'new /obj/item/flax_bundle', 'new /obj/item/stack/rotten_flax']:
   self.assertNotIn(bad,S)
  self.assertNotIn('new(',TAKE);self.assertNotIn('new ',TAKE)
 def test_exact_initial_paid_resources(self):
  self.assertIn('flax_raw = new(locate(7, 6, 1), 2)',S)
  self.assertIn('flax_raw.amount == 2',S)
  for n in ['flax_bundle','stack/rotten_flax','flax_work','stack/flax_tow','stack/textile_lint']:
   self.assertIn('!(locate(/obj/item/'+n+') in T)',S)
 def test_authored_water_and_no_mutation(self):
  for token in ['flax_water.type == /turf/floor/beach/water','flax_water == locate(7, 7, 1)','!flax_water.salty','flax_water.radiation <= 0']:self.assertIn(token,S)
  self.assertNotIn('ChangeTurf',S)
  self.assertIn('"b" = (/turf/floor/beach/water,',(ROOT/'changed-source/filming/tree.dmm').read_text())
 def test_bounded_observer_only_waits_for_actual_first_stage(self):
  for token in ['world.time < deadline','bundle.soak_stage >= 0 && bundle.soak_stage <= 1','bundle.loc == worker && bundle.soak_stage == 0 && !bundle.soaking','if (bundle.soak_stage == 1)','sleep(0.5)','filming_stop("chapter A timed out']:self.assertIn(token,INTERRUPT)
  self.assertEqual(INTERRUPT.count('step(worker, WEST)'),1)
  self.assertNotIn('filming_check(step_return',INTERRUPT)
 def test_actual_state_before_and_after_movement(self):
  for token in ['worker == flax_worker','worker.client == filming_observer_client','filming_observer_client.mob == worker','worker.loc == locate(6, 7, 1)','worker.loc == locate(5, 7, 1)','!worker.step_x && !worker.step_y','bundle.loc == site && bundle.soak_stage == 1']:
   self.assertIn(token,INTERRUPT)
  self.assertIn('"step_return_numeric" = isnum(step_return) ? step_return : null',INTERRUPT)
  self.assertLess(INTERRUPT.index('text2file(json_encode'),INTERRUPT.index('filming_check(worker == flax_worker && worker.loc == locate(5'))
 def test_post_cancellation_failclosed(self):
  for token in ['flax_interruption_done && world.time - soak_start >= 100 && world.time <= deadline','bundle.soak_stage == 1 && !bundle.soaking','!flax_worker_can_reach(flax_worker, bundle)','!(locate(/obj/item/stack/rotten_flax) in flax_water)']:self.assertIn(token,TAKE)
 def test_same_actual_guest_and_no_impersonation(self):
  new=S.split('/client/New()')[1].split('/client/Del()')[0]
  self.assertLess(new.index('istype(mob, /mob/filming_observer)'),new.index('mob = flax_worker'))
  self.assertIn('mob == flax_worker && flax_worker.client == src && flax_worker.key == key',new)
  self.assertNotRegex(S,r'\.(?:client|key|ckey)\s*=(?!=)')
 def test_honest_partial_stage_caption(self):
  enc=(ROOT/'encode_local.py').read_text(encoding='utf-8')
  for token in ['One of three ten-second stages','unfinished soak','independent genuinely produced batches','waiting omitted']:self.assertIn(token,enc)
  note=(ROOT/'FLAX-STORYBOARD.md').read_text(encoding='utf-8')
  self.assertIn('no dedicated stage-one sprite',note);self.assertIn('No native progress bar is promised',note)
 def test_unchanged_capture_interval(self):
  self.assertEqual(20+20+5+100+0.5+40,185.5)
  self.assertIn('world.time - take_start <= 195',TAKE)
  self.assertIn('var/deadline = take_start + 150',TAKE)
 def test_worker_login_isolation_and_input(self):
  login=S.split('/mob/living/human/filming_worker/Login()')[1].split('/mob/living/human/filming_worker/Logout()')[0]
  self.assertIn('src == flax_worker && client && client == filming_observer_client && client.mob == src',login)
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
 def test_world_definition_not_split_by_fixture_overrides(self):
  world=S.split('/world\n',1)[1].split('\n/world/OpenPort',1)[0]
  for line in ['\tmob = /mob/filming_observer','\tview = 2','\tfps = 20']:self.assertIn(line,world)
  self.assertNotRegex(world,r'(?m)^/')
  self.assertEqual(S.count('\n/mob/filming_observer\n'),1)

 def test_production_paths_match_source_closure_and_are_unmodified(self):
  pins=json.loads((ROOT/'flax-production-bindings.json').read_text(encoding='utf-8'))
  manifest=json.loads((ROOT/'v4-source-manifest.json').read_text(encoding='utf-8'))
  rows={x['path']:x for x in manifest['materialization_allowlist']}
  changes=json.loads((ROOT/'derived-source.json').read_text(encoding='utf-8'))['changes']
  self.assertEqual(pins['revision'],manifest['revision'])
  for item in pins['unchanged_production']:
   self.assertNotIn(item['path'],changes)
   self.assertEqual(item['git_blob'],rows[item['path']]['git_blob'])


class FlaxViewportTransitions(unittest.TestCase):
 def test_paid_binding_observed_without_manual_cleanup(self):
  b=S.split('/proc/filming_bind_flax(')[1].split('/proc/filming_place_flax(')[0]
  self.assertLess(b.index('before normal binding'),b.index('raw.tie_bundle(flax_worker)'));self.assertLess(b.index('raw.tie_bundle(flax_worker)'),b.index('after normal binding'))
  for bad in ['screen -=','screen.Cut','screen_loc =','l_hand =','r_hand =']:self.assertNotIn(bad,b)
 def test_normal_water_transfer_and_exact_state(self):
  b=S.split('/proc/filming_place_flax(')[1].split('/proc/filming_take()')[0]
  self.assertLess(b.index('before water placement'),b.index('bundle.afterattack(flax_water, flax_worker, TRUE)'));self.assertLess(b.index('bundle.afterattack'),b.index('after water placement'))
  for token in ['!worker.l_hand && !worker.r_hand','!(bundle in filming_observer_client.screen)','isnull(bundle.screen_loc)','bundle.plane == GAME_PLANE','bundle.layer == initial(bundle.layer)']:self.assertIn(token,INTERRUPT)
 def test_actual_movement_observed_no_camera_fix(self):
  self.assertLess(INTERRUPT.index('before ordinary step'),INTERRUPT.index('step(worker, WEST)'));self.assertLess(INTERRUPT.index('step(worker, WEST)'),INTERRUPT.index('after ordinary step'))
  self.assertNotIn('forceMove',INTERRUPT);self.assertNotIn('.loc = ',INTERRUPT)
 def test_final_zero_verbs_and_viewport_done(self):
  self.assertIn('!flax_worker.verbs.len && !filming_observer_client.verbs.len',TAKE)
  self.assertLess(TAKE.index('filming_viewport("take complete")'),TAKE.index('filming_viewport_done = TRUE'))

class OrdinaryWaterInteraction(unittest.TestCase):
 def test_actual_drop_then_normal_interaction(self):
  tokens=['filming_place_flax(bundle)','bundle placed in fresh water; interact next','sleep(5)','var/soak_start = world.time','flax_interrupt_after_first_stage(bundle, flax_worker, flax_water, deadline)','filming_interact_flax(bundle)','world.time - soak_start >= 100']
  indexes=[TAKE.index(t) for t in tokens];self.assertEqual(indexes,sorted(indexes))
  placed=S.split('/proc/filming_place_flax(')[1].split('/proc/filming_interact_flax(')[0]
  self.assertIn('bundle.afterattack(flax_water, flax_worker, TRUE)',placed)
  for token in ['bundle.loc == flax_water && bundle.soak_stage == 0 && !bundle.soaking','!flax_worker.l_hand && !flax_worker.r_hand','!(bundle in filming_observer_client.screen)','bundle.layer == initial(bundle.layer)']:self.assertIn(token,placed)
  interact=S.split('/proc/filming_interact_flax(')[1].split('/proc/filming_take()')[0]
  self.assertIn('bundle.attack_hand(flax_worker)',interact);self.assertNotIn('.soak(',interact);self.assertIn('!flax_worker.get_active_hand()',interact)
 def test_no_production_return_or_handler_override(self):
  for token in ['/drop_from_inventory(', '/obj/item/flax_bundle/afterattack', '/obj/item/flax_bundle/attack_hand', '/obj/item/flax_bundle/proc/soak']:self.assertNotIn(token,S)
