"""Offline source contracts for the reconstructed, not-yet-approved lane."""
import unittest
from pathlib import Path
import guard_config
import directx_setup
ROOT=Path(__file__).parent
class Integration(unittest.TestCase):
 def test_only_setup_added(self):
  expected={Path(r['path']).name.lower():r['sha256'] for r in guard_config.VENDOR['files'] if '/bin/' in r['path']}
  expected['dxsetup.exe']=directx_setup.SETUP_SHA256
  self.assertEqual(expected,guard_config.BINARIES)
 def test_workflow_limits_and_order(self):
  s=(ROOT.parents[1]/'.github/workflows/cloud-bakery-5161688.yml').read_text()
  self.assertIn('timeout-minutes: 15',s)
  self.assertLess(s.index('acquire.py --root'),s.index('directx_setup.py --root'))
  self.assertLess(s.index('directx_setup.py --root'),s.index('run_scene.py --binary'))
  self.assertIn('--accept-bundled-microsoft-directx-terms',s)
  setup=s[s.index('      - name: Install exact'):s.index('      - name: Compile and render')]
  self.assertIn('timeout-minutes: 2',setup)
  self.assertIn('$files.Count -gt 19',s)
  self.assertIn('directx-setup-receipt.json',s)
 def test_scene_requires_setup_and_no_manual_cab_fallback(self):
  s=(ROOT/'run_scene.py').read_text()
  self.assertLess(s.index('verify_setup_receipt(binary.parent.parent'),s.index("compiler, compiled = launch"))
  self.assertIn('check_dependencies(binary, allow_cab_extraction=False)',s)
  self.assertIn(directx_setup.BRANCH,s)
if __name__=='__main__':unittest.main()
