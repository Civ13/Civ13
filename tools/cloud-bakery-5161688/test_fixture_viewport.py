"""Fixture-only UI contracts and fail-closed border integration, not native proof."""
import json,hashlib,tempfile,unittest,sys
from pathlib import Path
from types import SimpleNamespace
ROOT=Path(__file__).parent
sys.path.insert(0,str(ROOT/'tests'))
from test_capture import Adapter,SyntheticScreen,capture,gradient
from viewport_border import viewport_border
import recording
from test_recording import FakeClock
S=(ROOT/'changed-source/filming/scene.dm').read_text(encoding='utf-8')
class FixtureViewport(unittest.TestCase):
 def test_only_fixture_hand_positions_override(self):
  block=S.split('/mob/living/human/filming_worker/find_inv_position(slot_id)')[1].split('var/filming_viewport_rows')[0]
  self.assertEqual(block.strip(),'if (slot_id == slot_l_hand)\n\t\treturn "1,5"\n\tif (slot_id == slot_r_hand)\n\t\treturn "5,5"\n\treturn ..()')
  for bad in ['/obj/item/proc/equipped','/mob/living/human/put_in_l_hand','/mob/living/human/put_in_r_hand','/obj/item/proc/dropped','/hide_worker_connected','/hide_preparation_wait']:self.assertNotIn(bad,S)
 def test_every_native_pickup_drop_is_bracketed(self):
  pickup=S.split('/proc/filming_pickup(')[1].split('var/mob/living/human/filming_worker/tan_worker')[0]
  self.assertLess(pickup.index('before normal pickup'),pickup.index('I.attack_hand(H)'));self.assertLess(pickup.index('I.attack_hand(H)'),pickup.index('after normal pickup'))
  drop=S.split('/proc/filming_drop_tanner(')[1].split('/mob/filming_observer')[0]
  self.assertIn('result = tan_worker.drop_item(target)',drop);self.assertIn('result = tan_worker.drop_item()',drop)
  self.assertLess(drop.index('before normal drop'),drop.index('tan_worker.drop_item('));self.assertGreater(drop.index('after normal drop'),drop.rindex('tan_worker.drop_item('))
  take=S.split('/proc/filming_take()')[1].split('/proc/filming_lighting_loop()')[0]
  self.assertNotIn('tan_worker.drop_item(',take)
  order=[take.index(x) for x in ('before rack transfer','tan_rack.attackby(wet, tan_worker)','after rack transfer')];self.assertEqual(order,sorted(order))
 def test_observation_does_not_reset_camera_or_relocate_item(self):
  block=S.split('/proc/filming_hand_view(')[1].split('/proc/filming_drop_tanner')[0]
  self.assertNotRegex(block,r'\.(?:eye|view|perspective|pixel_x|pixel_y|loc|screen_loc)\s*=(?!=)')
  self.assertNotIn('winset',block);self.assertNotIn('forceMove',block)
  for token in ['C.eye','C.view == 2','C.perspective == EYE_PERSPECTIVE','!C.pixel_x && !C.pixel_y','tan_worker.client == C && C.mob == tan_worker','C.screen.len == L[5] + R[5]','C.screen.len <= 2','!tan_worker.HUDinventory.len','I.screen_loc == expected_slot','I.plane == HUD_PLANE && I.layer == 20']:self.assertIn(token,block)
 def test_bounded_diagnostic_before_rejection(self):
  block=S.split('/proc/filming_viewport(phase)')[1].split('/proc/filming_viewport_loop')[0]
  for token in ['filming_viewport_rows >= 96','length(row) > 384','> 16000','copytext(phase, 1, 25)','filming-viewport.txt']:self.assertIn(token,block)
  self.assertLess(block.index('text2file(row'),block.index('if (!ok)'))
  self.assertNotIn('client.key',block);self.assertNotIn('for (',block)
 def test_monitor_during_waits_and_finished_inside_same_deadline(self):
  block=S.split('/proc/filming_viewport_loop()')[1].split('/proc/filming_drop_tanner')[0]
  self.assertIn('world.time - filming_viewport_started <= 195',block);self.assertIn('sleep(5)',block)
  take=S.split('/proc/filming_take()')[1].split('/proc/filming_lighting_loop()')[0]
  self.assertLess(take.index('filming_viewport_loop()'),take.index('tan_raw.attackby'))
  self.assertLess(take.index('filming_viewport("take complete")'),take.index('filming_viewport_done = TRUE'))
  self.assertIn('world.time - scrape_start >= 50',take);self.assertIn('sleep(35)',take)
 def test_border_after_native_cleanup_and_old_pixel_check(self):
  source=(ROOT/'capture.py').read_text()
  self.assertLess(source.index('timing_native_done ='),source.index('border = viewport_border'))
  self.assertLess(source.index('diagnostics = pixel_diagnostics'),source.index('border = viewport_border'))
  self.assertIn("error.args = ('Captured RGB failed scene-specific black-border guard',)",source)
 def test_shifted_border_rejected_after_guards_no_success_png(self):
  rgb=bytearray(gradient(480,480))
  # Diverse full image with the exact kind of large top/left black margin observed.
  rgb=rgb[:480*480*3]
  for y in range(480):
   for x in range(480):
    if y<32 or x<32:rgb[(y*480+x)*3:(y*480+x)*3+3]=b'\0\0\0'
  capture.pixel_diagnostics(bytes(rgb),480,480)
  a=Adapter();n=SyntheticScreen(a);n.rectangle=[30,40,510,520];n.result=bytes(rgb)
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'recording-007.png'
   with self.assertRaises(capture.PixelHeuristicFailure) as caught:capture._capture_with_backend(a,SimpleNamespace(pid=123),p,capture.DEFAULT_TITLE,(480,480),n)
   self.assertFalse(p.exists());self.assertTrue(n.cleaned);self.assertEqual(n.counters['bitblt'],1)
   self.assertFalse(caught.exception.facts['viewport_border']['accepted'])
 def test_recording_retains_failure_count_and_index(self):
  clock=FakeClock();clock.value=0
  facts=viewport_border(bytes(480*480*3))
  def fail(*args):raise recording.PixelHeuristicFailure({'viewport_border':facts})
  with tempfile.TemporaryDirectory() as d:
   with self.assertRaises(recording.PixelHeuristicFailure):recording.record_frames(None,None,Path(d),'title',lambda:None,lambda:None,fail,clock.now,clock.sleep)
   row=json.loads((Path(d)/'recording.json').read_text());self.assertEqual(row['failed_viewport_border'],facts);self.assertEqual(row['last_attempt_timing']['index'],0);self.assertEqual(row['frames'],[])
 def test_recording_rejects_missing_malformed_border(self):
  for counts in (None,[False,0,0,0],[-1,0,0,0],[14592,0,0,0],[0,0,0]):
   clock=FakeClock();clock.value=0
   def fake(a,p,path,title,size):
    data=b'native';path.write_bytes(data)
    b=viewport_border(b'\1\2\3'*(480*480))
    if counts is not None:
     for k,v in zip(('top','bottom','left','right'),counts):b[k+'_black_pixels']=v
     if len(counts)<4:b.pop('right_black_pixels')
    return dict(status='captured',viewport_border=b if counts is not None else None,identity=dict(pid=1,creation_filetime=2),window=dict(hwnd=3,client_rect=[0,0,480,480]),width=480,height=480,png_bytes=len(data),png_sha256=hashlib.sha256(data).hexdigest(),checkpoints=['immediately_before_bitblt','immediately_after_bitblt'])
   with tempfile.TemporaryDirectory() as d:
    with self.assertRaisesRegex(RuntimeError,'viewport border'):recording.record_frames(None,None,Path(d),'title',lambda:None,lambda:None,fake,clock.now,clock.sleep)
 def test_same_caps_and_new_artifact_only(self):
  run=(ROOT/'run_scene.py').read_text();workflow=(ROOT.parents[1]/'.github/workflows/cloud-bakery-5161688.yml').read_text()
  self.assertIn("16384 if name == 'filming-viewport.txt' else 65536",run)
  self.assertIn("'filming-viewport.txt'",workflow)
  self.assertIn('if len(raw) > 32768',(ROOT/'recording.py').read_text())
  self.assertIn('COUNT, FPS, SIZE = 80, 4, (480, 480)',(ROOT/'recording.py').read_text())
 def test_decoder_and_encoder_single_thread(self):
  s=(ROOT/'encode_local.py').read_text();self.assertIn("'-threads','1','-i','frames.ffconcat'",s);self.assertIn("'-c:v','libx264','-threads','1'",s)
