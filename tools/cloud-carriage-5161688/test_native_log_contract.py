import tempfile,unittest
from pathlib import Path
from native_log_contract import check_server_logs
class NativeLogs(unittest.TestCase):
 def test_missing_before_launch_and_clean_owned_logs(self):
  with tempfile.TemporaryDirectory() as d:
   self.assertEqual(check_server_logs(d),[])
   (Path(d)/'server.stdout.log').write_text('DreamDaemon 516.1688\n')
   self.assertEqual(check_server_logs(d),['server.stdout.log'])
 def test_observer_and_native_error_omission_controls(self):
  with tempfile.TemporaryDirectory() as d:
   for text in ('## ERROR: null owner','runtime error: bad callback','Runtime error: failed'):
    (Path(d)/'server.stderr.log').write_text(text)
    with self.assertRaises(ValueError):check_server_logs(d)
 def test_oversize_is_not_silently_ignored(self):
  with tempfile.TemporaryDirectory() as d:
   (Path(d)/'server.stdout.log').write_bytes(b'x'*(1024**2+1))
   with self.assertRaises(ValueError):check_server_logs(d)

 def test_native_routing_sentinel_is_required_after_cleanup(self):
  with tempfile.TemporaryDirectory() as d:
   with self.assertRaises(ValueError):check_server_logs(d,True)
   (Path(d)/'server.stdout.log').write_text('CARRIAGE_LEASE_LOG_SOURCE=5260b60f0efef2c0af70fae204b1180106ef50b3')
   self.assertEqual(check_server_logs(d,True),['server.stdout.log'])
