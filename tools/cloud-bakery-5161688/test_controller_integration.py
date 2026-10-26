from pathlib import Path
import ast,hashlib,json,unittest
ROOT=Path(__file__).parent
S=(ROOT/'run_scene.py').read_text(encoding='utf-8')
D=(ROOT/'changed-source/filming/scene.dm').read_text(encoding='utf-8')
class Integration(unittest.TestCase):
 def test_exact_three_release_flags_and_entry_guards(self):
  self.assertEqual(S.count('CADENCE_NATIVE_RELEASED = True'),1)
  self.assertNotIn('CADENCE_NATIVE_RELEASED = False',S)
  self.assertIn("require(CADENCE_NATIVE_RELEASED, 'SOURCE-ONLY HOLD",S)
  self.assertEqual(D.count('#define FILMING_NATIVE_RELEASED TRUE'),1)
  self.assertNotIn('#define FILMING_NATIVE_RELEASED FALSE',D)
  import deferred_recording as r
  self.assertIs(r.NATIVE_RELEASED,True)
  self.assertIn('require(NATIVE_RELEASED', (ROOT/'deferred_recording.py').read_text(encoding='utf-8'))
 def test_exact_fixed_handshake_and_three_client_bound_reports(self):
  self.assertIn('cadence_calls <= 2',S);self.assertIn('began < .5',S)
  for n in ('cadence-admission.json','cadence-start.json','cadence-end.json'):self.assertIn(n,D)
  self.assertIn('flax_worker.client == filming_observer_client && filming_observer_client.mob == flax_worker',D)
  self.assertNotIn('client.fps =',D);self.assertNotIn('world.fps =',D)
 def test_dm_numeric_boolean_normalization_is_exact(self):
  module=ast.parse(S);node=next(n for n in ast.walk(module) if isinstance(n,ast.FunctionDef) and n.name=='parse_cadence')
  env={'json':json,'require':lambda ok,why: None if ok else (_ for _ in ()).throw(RuntimeError(why))}
  exec(compile(ast.Module(body=[node],type_ignores=[]),'<offline-test>','exec'),env)
  self.assertIs(env['parse_cadence']('{"phase":"start","same_admitted_client":1}','start')['same_admitted_client'],True)
  for value in (0,2,True,'1',None):
   with self.assertRaises(RuntimeError):env['parse_cadence'](json.dumps(dict(phase='start',same_admitted_client=value)),'start')
 def test_complete_scene_and_terminal_proof_not_dropped(self):
  self.assertIn("wait_file('filming-take.json')",S);self.assertIn("result['cadence_manifest_sha256'] = digest(output/'cadence-recording.json')",S)
  self.assertIn('terminal = checkpoint(result, output)',S)
  self.assertIn("'PASS_NATIVE_CADENCE_DIAGNOSTIC', started=started)",S)
 def test_artifact_caps_unchanged_and_short_count_exact(self):
  w=(ROOT/'workflow-artifact-admission-fragment.txt').read_text()
  self.assertIn('0..19',w);self.assertNotIn('0..79',w)
  for t in ('-gt 100','-gt 16777216','-gt 1048576'):self.assertIn(t,w)
 def test_derivative_scene_hash_exact(self):
  j=json.loads((ROOT/'derived-source.json').read_text());self.assertEqual(j['changes']['filming/scene.dm'],hashlib.sha256(D.encode()).hexdigest())
if __name__=='__main__':unittest.main()
