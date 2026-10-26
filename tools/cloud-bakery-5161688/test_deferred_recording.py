import hashlib,json,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
from types import SimpleNamespace
import deferred_recording as R
import capture

RGB=bytes(x for y in range(480) for z in range(480) for x in ((z*9)%256,(y*7)%256,(z*5+y*3)%256))
OWNER=dict(pid=1,creation_filetime=2,hwnd=3)
class Deferred(unittest.TestCase):
 def setup_run(self,mode=None,real=False,fps=20):
  tmp=tempfile.TemporaryDirectory();self.addCleanup(tmp.cleanup);out=Path(tmp.name);t=[0.];events=[];configs=[0];refs=[]
  config=dict(world_fps=fps,world_tick_lag=10/fps,client_fps=0,client_tick_lag=0,same_admitted_client=True)
  def read():
   configs[0]+=1;c=dict(config)
   if mode=='ratechange' and configs[0]==2:c.update(client_fps=60,client_tick_lag=10/60)
   return c
  def watch():
   if mode=='watchfail' and len(refs)==2:raise RuntimeError('owned process watch failed')
  def acquire(*args):
   n=len(refs);events.append(('acquire',n));rb=5000000000000+round(t[0]*1000000000)+100000;t[0]+=.06 if mode=='slow' else .001
   c=dict(status='OWNED_RAW_UNVALIDATED',rgb=bytes(691200) if mode=='lateblack' and n==2 else RGB,width=480,height=480,
    identity=dict(pid=1,creation_filetime=2),window=dict(hwnd=4 if mode=='owner' and n==1 else 3,client_rect=[0,0,480,480]),desktop='d',activation={},checkpoints=R.CHECKPOINTS.copy(),native_counters={},timing_start=0,timing_native_done=0,cleanup=R.CLEANUP,readback_timing=dict(clock='perf_counter_ns',bitblt_begin_ns=rb,bgra_readback_end_ns=5000000000000+round(t[0]*1000000000)-100000))
   if mode=='postguard' and n==1:c['checkpoints']=c['checkpoints'][:1]
   if mode=='rawsize' and n==1:c['rgb']=b'x'
   if mode=='badreadback':c['readback_timing']['bitblt_begin_ns']=0
   refs.append(c);return c
  def validate(c,path):
   events.append(('validate',path.name))
   if mode=='deadline':t[0]=165
   if real:return capture._finalize_acquisition(c,path)
   data=b'bounded'+path.name.encode();path.write_bytes(data)
   return dict(c,status='captured',png_bytes=len(data),png_sha256=hashlib.sha256(data).hexdigest(),pixel_diagnostics={},viewport_border=dict(accepted=True))
  def first():
   events.append(('first_callback',0))
   if mode=='slowcallback':t[0]+=.2
   if mode=='callbackfail':raise RuntimeError('fixed acknowledgement failed')
  def metadata(name):
   return SimpleNamespace(implementation='QueryPerformanceCounter()' if name=='perf_counter' else 'GetTickCount64()',resolution=1e-7 if name=='perf_counter' else .015625,monotonic=True,adjustable=False)
  def safety():return 10000+(int(t[0]*64)/64 if mode=='coarse_monotonic' else t[0])
  samples=[0]
  def highres():
   samples[0]+=1
   if mode=='backwardclock' and samples[0]>1:return 4999999999999
   return 5000000000000+round(t[0]*1000000000)
  def go():return R._record_burst(None,None,out,'title',watch,read,config,OWNER,10000,acquire,validate,safety,lambda d:t.__setitem__(0,t[0]+d),sample_clock=highres,clock_info=metadata,on_first_sample=first)
  return go,out,events,refs
 def test20_samples_before_any_validation_no_native_acceptance(self):
  go,out,events,refs=self.setup_run();r=go();self.assertEqual(r['status'],'VALIDATED_PENDING_SCENE_CLEANUP');self.assertEqual(len(r['frames']),20)
  self.assertEqual([x[0] for x in events],['acquire','first_callback']+['acquire']*19+['validate']*20)
  self.assertEqual(r['raw_buffer_bytes'],13824000);self.assertTrue(all('rgb' not in c for c in refs));self.assertEqual(len(r['cadence_samples']),3)
  self.assertEqual(json.loads((out/'cadence-recording.json').read_text())['raw_buffers_released'],True)
 def test_existing_full_pixel_validator_used_on_every_real_frame(self):
  go,out,events,refs=self.setup_run(real=True,fps=3);r=go();self.assertEqual(len(r['frames']),3)
  for f in r['frames']:self.assertEqual(f['pixel_diagnostics']['pixel_count'],230400);self.assertTrue(f['viewport_border']['accepted'])
 def test_last_black_frame_rejects_entire_deferred_batch(self):
  go,out,events,refs=self.setup_run('lateblack',True,3)
  with self.assertRaises(capture.PixelHeuristicFailure):go()
  r=json.loads((out/'cadence-recording.json').read_text());self.assertTrue(r['rejected']);self.assertEqual(r['status'],'FAILED_DIAGNOSTIC_ONLY');self.assertTrue(r['failed_pixel_facts']['entirely_black'])
  self.assertEqual([x[0] for x in events if x[0]!='first_callback'][:3],['acquire']*3);self.assertTrue(all('rgb' not in c for c in refs))
 def test_native_safety_failures_never_validate(self):
  for mode in ('slow','owner','postguard','rawsize','watchfail','ratechange','badreadback','slowcallback','callbackfail','backwardclock'):
   with self.subTest(mode=mode):
    go,out,events,refs=self.setup_run(mode)
    with self.assertRaises(RuntimeError):go()
    self.assertFalse(any(e[0]=='validate' for e in events));self.assertEqual(json.loads((out/'cadence-recording.json').read_text())['status'],'FAILED_DIAGNOSTIC_ONLY')
 def test_validation_counts_against_original_work_deadline(self):
  go,out,events,refs=self.setup_run('deadline')
  with self.assertRaisesRegex(RuntimeError,'work deadline'):go()
  self.assertTrue(json.loads((out/'cadence-recording.json').read_text())['rejected'])
 def test_actual_raw_cap_overflow_releases_inflight(self):
  go,out,events,refs=self.setup_run()
  with patch.object(R,'MAX_RAW_BYTES',691200):
   with self.assertRaisesRegex(RuntimeError,'Raw batch byte cap'):go()
  self.assertTrue(all('rgb' not in c for c in refs));self.assertTrue(json.loads((out/'cadence-recording.json').read_text())['rejected'])
 def test_manifest_write_failure_never_returns_success(self):
  go,out,events,refs=self.setup_run()
  with patch.object(R,'atomic',side_effect=OSError('storage failure')):
   with self.assertRaises(OSError):go()
  self.assertTrue(all('rgb' not in c for c in refs))
 def test_late_border_failure_rejects_all_not_just_blank(self):
  go,out,events,refs=self.setup_run(real=True,fps=3)
  original=capture.viewport_border;calls=[0]
  def reject_last(rgb,w,h):
   calls[0]+=1;b=original(rgb,w,h)
   if calls[0]==3:b.update(accepted=False,top_black_pixels=15360)
   return b
  with patch.object(capture,'viewport_border',side_effect=reject_last):
   with self.assertRaises(capture.PixelHeuristicFailure):go()
  self.assertTrue(json.loads((out/'cadence-recording.json').read_text())['rejected'])
 def test_coarse_safety_clock_does_not_quantize_sample_timing(self):
  from cadence_schema import validate_manifest
  go,out,events,refs=self.setup_run('coarse_monotonic',True,3);r=go()
  validate_manifest(r,out,3)
  self.assertEqual(r['frames'][0]['end_ns']-r['frames'][0]['begin_ns'],1000000)
  self.assertEqual(r['frames'][1]['due_ns'],333333334)
 def test_integer_clock_domain_and_callback_order(self):
  go,out,events,refs=self.setup_run(real=True,fps=3);r=go()
  self.assertEqual(r['schema'],3);self.assertEqual(r['perf_counter_origin_ns'],5000000000000)
  self.assertEqual(r['safety_scene_started_seconds'],10000)
  self.assertEqual(r['clock_metadata']['perf_counter']['implementation'],'QueryPerformanceCounter()')
  self.assertEqual(r['first_sample_callback_count'],1)
  self.assertEqual(events[0:3],[('acquire',0),('first_callback',0),('acquire',1)])
  for f in r['frames']:
   self.assertLessEqual(f['begin_ns'],f['readback_begin_ns']);self.assertLessEqual(f['readback_end_ns'],f['end_ns'])
   self.assertEqual(f['end_seconds'],f['end_ns']/1000000000)
  self.assertLessEqual(r['first_sample_callback_end_ns'],r['frames'][1]['begin_ns'])
 def test_first_failed_sample_never_releases_movement(self):
  for mode in ('slow','badreadback'):
   go,out,events,refs=self.setup_run(mode)
   with self.assertRaises(RuntimeError):go()
   self.assertNotIn(('first_callback',0),events)
   self.assertEqual(json.loads((out/'cadence-recording.json').read_text())['first_sample_callback_count'],0)
 def test_full_twenty_real_validations_fit_existing_manifest_cap(self):
  from cadence_schema import validate_manifest
  go,out,events,refs=self.setup_run(real=True,fps=20);r=go()
  validate_manifest(r,out,20)
  self.assertLessEqual((out/'cadence-recording.json').stat().st_size,32768)
 def test_deferred_native_entry_held(self):
  self.assertIs(R.NATIVE_RELEASED,True)
  with patch.object(R,'NATIVE_RELEASED',False), patch.object(R,'_record_burst') as native:
   with self.assertRaisesRegex(RuntimeError,'SOURCE-ONLY HOLD'):R.record_burst()
   native.assert_not_called()
 def test_buffer_count_and_file_caps_unchanged(self):
  self.assertEqual(R.MAX_COUNT,20);self.assertEqual(R.MAX_RAW_BYTES,13824000);self.assertEqual(R.MAX_FRAME_BYTES,1048576);self.assertEqual(R.MAX_FRAME_TOTAL,15728640)
 def test_guarded_raw_has_no_platform_fallback(self):
  with patch.object(capture.os,'name','posix'):
   with self.assertRaises(capture.CaptureError):capture.acquire_owned(None,None)
if __name__=='__main__':unittest.main()
