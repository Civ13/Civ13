"""Current source closure and unchanged capture/safety contract."""
import hashlib,json,re,unittest
from pathlib import Path
ROOT=Path(__file__).parent
class CurrentSourceClosure(unittest.TestCase):
 def test_current_closure_and_unchanged_guard_hashes(self):
  pins=json.loads((ROOT/'tree-source-contract.json').read_text(encoding='utf-8'))
  self.assertEqual(pins['revision'],'9683866a89d2bdc12f8dc7d25444e350583c5483')
  for n,h in pins['unchanged_guard_sha256'].items():self.assertEqual(hashlib.sha256((ROOT/n).read_bytes()).hexdigest(),h,n)
  self.assertEqual(hashlib.sha256((ROOT/'capture.py').read_bytes()).hexdigest(),pins['diagnostic_capture_delta']['current_sha256'])
  self.assertEqual(hashlib.sha256((ROOT/'recording.py').read_bytes()).hexdigest(),pins['reviewed_recording_delta']['current_sha256'])
  self.assertEqual(hashlib.sha256((ROOT/'viewport_border.py').read_bytes()).hexdigest(),pins['viewport_border_sha256'])
  activation=pins['activation_only_guard']
  normalized=(ROOT/activation['file']).read_text(encoding='utf-8').replace(activation['new_branch'],activation['old_branch'])
  self.assertEqual(hashlib.sha256(normalized.encode()).hexdigest(),activation['prior_sha256'])
  dme=(ROOT/'changed-source/civ13.dme').read_text(encoding='utf-8')
  paths={x['path'] for x in json.loads((ROOT/'v4-source-manifest.json').read_text(encoding='utf-8'))['materialization_allowlist']}
  derived=json.loads((ROOT/'derived-source.json').read_text(encoding='utf-8'))['changes']
  for n in re.findall(r'^#include "([^"]+)"',dme,re.M):self.assertIn(n.replace('\\','/'), paths|set(derived))
