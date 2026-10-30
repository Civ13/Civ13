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
    def test_script_state_matches_activation_and_has_no_broad_rules(self):
        released=json.loads((Path(__file__).parent/'activation.json').read_text(encoding='utf-8'))['released']
        s=(Path(__file__).parent/'firewall_supervisor.ps1').read_text(encoding='utf-8')
        self.assertIn('$FirewallReviewReleased = $'+('true' if released else 'false'),s)
        self.assertIn("throw 'HELD_FIREWALL_REVIEW'",s)
        self.assertIn('AssertRule $r \'ActiveStore\'',s)
        self.assertIn('Get-NetFirewallSecurityFilter -PolicyStore ActiveStore -ErrorAction Stop',s)
        self.assertIn("throw 'security_filter_inventory_empty'",s)
        self.assertIn("throw 'outbound_allow_override_present'",s)
        self.assertIn('native_cleanup_unverified_rules_retained',s)
        self.assertNotIn('Set-NetFirewallProfile',s)
        self.assertNotIn('Disable-NetFirewall',s)
        self.assertNotIn('-Action Allow',s)
        self.assertNotIn('DXSETUP.exe',s)
        self.assertIs(run_scene.NETWORK_RUNTIME_ADMITTED,released)
    def test_toolchain_precedes_firewall_and_legacy_setup_is_not_invoked(self):
        w=(Path(__file__).parent/'workflow.reference.txt').read_text(encoding='utf-8')
        markers=['prepare_nuget_toolchain.py --root','verify_nuget_signatures.ps1',
                 'nuget_local_runtime.py --root','run_encoder_proof.py --root','firewall_supervisor.ps1']
        indices=[w.index(marker) for marker in markers]
        self.assertEqual(indices,sorted(indices))
        self.assertNotIn('directx_setup.py --root',w)
        self.assertNotIn('directx_official_setup.py --root',w)
        self.assertNotIn('prepare_official_toolchain.py --root',w)
        self.assertNotIn('toolchain_workflow.py --root',w)
        self.assertIn('check_dependencies(binary, allow_cab_extraction=False)',
                      (Path(__file__).parent/'run_scene.py').read_text(encoding='utf-8'))

if __name__=='__main__': unittest.main()
