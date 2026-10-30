import json, os, tempfile, unittest
from pathlib import Path
from unittest.mock import patch
import run_scene

class FirewallReview(unittest.TestCase):
    def test_live_verification_invocation_and_failures(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'PowerShell/7/pwsh.exe';p.parent.mkdir(parents=True);p.write_bytes(b'test-only')
            class Result: returncode=0
            with patch.dict(os.environ,{'ProgramFiles':d}),patch.object(run_scene.subprocess,'run',return_value=Result()) as invoked:
                run_scene.verify_live_firewall()
                args=invoked.call_args
                self.assertIn('-VerifyOnly',args.args[0]);self.assertEqual(args.kwargs['timeout'],10)
            Result.returncode=2
            with patch.dict(os.environ,{'ProgramFiles':d}),patch.object(run_scene.subprocess,'run',return_value=Result()):
                with self.assertRaisesRegex(RuntimeError,'firewall_verification_failed'):run_scene.verify_live_firewall()
    def test_script_has_inert_guards_and_no_broad_rules(self):
        s=(Path(__file__).parent/'firewall_supervisor.ps1').read_text(encoding='utf-8')
        admission=json.loads((Path(__file__).parent/'activation.json').read_text(encoding='utf-8'))['released']
        self.assertIn('$FirewallReviewReleased = $'+str(admission).lower(),s)
        self.assertIn("throw 'HELD_FIREWALL_REVIEW'",s)
        self.assertIn('AssertRule $r \'ActiveStore\'',s)
        self.assertIn('OverrideBlockRules $true',s)
        self.assertIn('native_cleanup_unverified_rules_retained',s)
        self.assertNotIn('Set-NetFirewallProfile',s)
        self.assertNotIn('Disable-NetFirewall',s)
        self.assertNotIn('-Action Allow',s)
        self.assertNotIn('DXSETUP.exe',s)
        self.assertIs(run_scene.NETWORK_RUNTIME_ADMITTED,admission)
    def test_directx_installer_is_not_in_workflow(self):
        w=(Path(__file__).parent/'workflow.reference.txt').read_text(encoding='utf-8')
        self.assertIn('installed_directx.py --output',w)
        self.assertNotIn('directx_setup.py --root',w)

if __name__=='__main__': unittest.main()
