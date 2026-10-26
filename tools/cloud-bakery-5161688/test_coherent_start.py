from pathlib import Path
import ast,json,tempfile,textwrap,unittest
R=Path(__file__).parent;S=(R/'run_scene.py').read_text(encoding='utf-8');D=(R/'changed-source/filming/scene.dm').read_text(encoding='utf-8')
class NoClock:
 def __getattr__(self,name):raise AssertionError('Start snapshot must not poll or wait: '+name)
class CoherentStart(unittest.TestCase):
 def reader(self,source):
  nodes={n.name:n for n in ast.walk(ast.parse(S)) if isinstance(n,ast.FunctionDef)}
  def require(ok,why):
   if not ok:raise RuntimeError(why)
  def bounded(path,cap):
   if not path.exists():return None
   require(path.is_file() and not path.is_symlink() and path.stat().st_size<=cap,'bounded file');return path.read_text(encoding='utf-8').strip()
  env=dict(json=json,require=require,bounded_text=bounded,watch=lambda:None,time=NoClock())
  exec(compile(ast.Module(body=[nodes['parse_cadence']],type_ignores=[]),'<offline>', 'exec'),env)
  wrapper='def make_reader(source):\n    cadence_calls = 0\n'+textwrap.indent(ast.unparse(nodes['read_cadence']),'    ')+'\n    return read_cadence\n'
  exec(wrapper,env);return env['make_reader'](source)
 def test_preexisting_coherent_snapshot_needs_no_clock_or_request(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d);(p/'cadence-movement-ready.txt').write_bytes(b'ready\n');(p/'cadence-start.json').write_text(json.dumps(dict(phase='start',world_fps=20,world_tick_lag=.5,client_fps=0,client_tick_lag=0,same_admitted_client=1)),encoding='utf-8')
   self.assertIs(self.reader(p)()['same_admitted_client'],True)
   self.assertFalse((p/'cadence-start-request.txt').exists())
 def test_missing_snapshot_or_readiness_fails_without_waiting(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)
   with self.assertRaises(RuntimeError):self.reader(p)()
   (p/'cadence-movement-ready.txt').write_bytes(b'ready\n')
   with self.assertRaises(RuntimeError):self.reader(p)()
 def test_fixture_emits_configuration_then_ready_without_yield(self):
  start=D.index('filming_cadence_write("start", "cadence-start.json")');ready=D.index('text2file("ready\\n", "cadence-movement-ready.txt")',start)
  self.assertNotIn('sleep(',D[start:ready]);self.assertNotIn('spawn(',D[start:ready])
  handler=D[D.index('/proc/filming_cadence_requests()'):D.index('/proc/filming_lighting_loop()')]
  self.assertNotIn('cadence-start-request',handler);self.assertIn('cadence-end-request',handler)
  self.assertIn('ready_time + 3',D);self.assertIn('deadline - 1',D);self.assertIn('var/deadline = take_start + 150',D)
if __name__=='__main__':unittest.main()
