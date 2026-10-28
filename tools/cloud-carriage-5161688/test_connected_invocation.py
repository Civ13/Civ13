"""Source contracts for the held connected invocation; no native execution."""
from pathlib import Path
import unittest,json,hashlib
R=Path(__file__).parent
class Invocation(unittest.TestCase):
 def test_disconnect_receipt_before_acceptance_not_job_fallback(self):
  s=(R/'run_scene.py').read_text()
  self.assertLess(s.index("source/'intro-disconnect-request.txt'"),s.index("result['connected'] = validate_connected"))
  self.assertLess(s.index("result['connected'] = validate_connected"),s.index("result['status'] = 'CAPTURED_CARRIAGE_REVIEW_REQUIRED'"))
  self.assertIn('min(started + 180, time.monotonic() + 5)',s)
  self.assertIn("require(not server.exited(serving), 'Owned server exited before post-Del receipt')",s)
  self.assertIn('Job cleanup is not disconnect proof',s)
 def test_readiness_after_native_login_not_forced_layout(self):
  s=(R/'run_scene.py').read_text()
  self.assertLess(s.index("wait_file('intro-ready.txt')"),s.index('wait_owned_ready(client,playing,connected_title,watch)'))
  d=(R/'changed-source/filming/connected_bootstrap.dm').read_text()
  for field in ('eye','perspective','glide_size','fps','dir'):self.assertNotRegex(d,rf'\.{field}\s*=(?!=)')
  self.assertIn('del(C)',d);self.assertIn('spawn(0)',d)
  self.assertIn('!(old_ckey in directory)',d)
 def test_five_releases_and_denied_sink(self):
  a=json.loads((R/'activation.json').read_text());d=json.loads((R/'derived-source.json').read_text())
  self.assertTrue(a['released']);self.assertTrue(d['native_released'])
  self.assertIn('NATIVE_RELEASED=True',(R/'deferred_recording.py').read_text())
  self.assertIn('INTRO_TRANSPORT_RELEASED TRUE',(R/'changed-source/filming/actions.dm').read_text())
  self.assertIn('INTRO_CONNECTED_RELEASED TRUE',(R/'changed-source/filming/connected_bootstrap.dm').read_text())
  w=(R/'changed-source/code/modules/webhooks/webhooks.dm').read_text();self.assertIn('if (!config || !config.webhook_can_fire)',w);self.assertIn('intro_denied_export(query)',w);self.assertNotIn('world.Export(',w)
