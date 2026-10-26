from pathlib import Path
import ast,json,math,re,unittest
R=Path(__file__).parent
S=(R/'run_scene.py').read_text(encoding='utf-8');D=(R/'changed-source/filming/scene.dm').read_text(encoding='utf-8')
class MovementBurst(unittest.TestCase):
 def parser(self):
  node=next(n for n in ast.parse(S).body if isinstance(n,ast.FunctionDef) and n.name=='parse_movement')
  def require(ok,message):
   if not ok:raise RuntimeError(message)
  env={'json':json,'math':math,'require':require};exec(compile(ast.Module(body=[node],type_ignores=[]),'<offline>', 'exec'),env);return env['parse_movement']
 def evidence(self):return dict(schema=1,action='ordinary_soak_interruption',ready_world_time_ds=197,ack_world_time_ds=198,step_world_time_ds=199,original_deadline_world_time_ds=202,start=[6,7,1,0,0],end=[5,7,1,0,0],same_actor=1,same_bundle_in_water=1,soak_stage=1)
 def test_exact_existing_ordinary_action(self):
  e=self.evidence();self.assertEqual(self.parser()(json.dumps(e)),e)
  for field,value in [('end',[6,7,1,0,0]),('same_actor',True),('same_bundle_in_water',0),('soak_stage',2),('ack_world_time_ds',201),('step_world_time_ds',202),('ready_world_time_ds',float('nan'))]:
   e=self.evidence();e[field]=value
   with self.assertRaises(RuntimeError):self.parser()(json.dumps(e))
 def test_no_production_or_deadline_shortcut(self):
  block=D[D.index('/proc/flax_interrupt_after_first_stage'):D.index('// Wrappers observe')]
  self.assertEqual(block.count('step(worker, WEST)'),1)
  for token in ('deadline - 1','ready_time + 3','sleep(1)','world.time < deadline','bundle.soak_stage == 1','worker.loc == locate(5, 7, 1)'):self.assertIn(token,block)
  self.assertIsNone(re.search(r'bundle\.soak_stage\s*=(?!=)',block));self.assertIsNone(re.search(r'worker\.loc\s*=(?!=)',block))
  self.assertIn('var/deadline = take_start + 150',D);self.assertIn('world.time - take_start <= 195',D)
 def test_first_sample_release_and_post_step_sample_required(self):
  self.assertLess(S.index("wait_file('cadence-movement-ready.txt')"),S.index('burst = record_burst('))
  self.assertIn('on_first_sample=release_movement',S)
  self.assertIn("first_sample_path.write_bytes(b'first_owned_sample\\n')",S)
  self.assertIn("burst['perf_counter_origin_ns'] + burst['frames'][-1]['begin_ns']",S)
  self.assertIn('movement_seen_ns = time.perf_counter_ns()',S)
  self.assertIn("result['movement_burst']",S)
  self.assertIn("wait_file('filming-take.json')",S)
 def test_cross_clock_subtraction_forbidden_in_movement_binding(self):
  block=S[S.index('movement_seen_ns = None'):S.index('from cadence_schema import validate_manifest')]
  self.assertNotIn('time.monotonic()',block)
if __name__=='__main__':unittest.main()
