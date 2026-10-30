"""Exercise the actual policy function with mocked NetSecurity cmdlets only."""
import re
import subprocess
import unittest
from pathlib import Path


class FirewallPolicyInventory(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = (Path(__file__).parent / 'firewall_supervisor.ps1').read_text(encoding='utf-8')
        match = re.search(r'(?ms)^function AssertPolicy\(\) \{.*?^\}(?=\r?\nfunction )', source)
        if not match:
            raise AssertionError('policy function not found')
        cls.policy = match.group()

    def invoke(self, scenario):
        # Function mocks shadow the real commands; no policy or network access occurs.
        script = "$scenario = '" + scenario + "'\n" + r'''
$ErrorActionPreference = 'Stop'
function Get-NetConnectionProfile { if ($scenario -eq 'profile_error') { throw 'profile_query_failed' }; [pscustomobject]@{NetworkCategory='Private'} }
function Get-NetFirewallProfile { param($PolicyStore) if ($scenario -eq 'disabled_profile') { [pscustomobject]@{Name='Private';Enabled=$false} } else { [pscustomobject]@{Name='Private';Enabled=$true} } }
function Get-NetFirewallSecurityFilter {
  param($PolicyStore)
  if ($scenario -eq 'query_error') { throw 'security_query_failed' }
  if ($scenario -eq 'empty_inventory') { return }
  if ($scenario -eq 'unknown_value') { [pscustomobject]@{OverrideBlockRules=$null}; return }
  if ($scenario -eq 'nonboolean_value') { [pscustomobject]@{OverrideBlockRules='unexpected'}; return }
  [pscustomobject]@{OverrideBlockRules=$false}
  if ($scenario -in @('override_allow','override_inbound','rule_error','empty_rules')) { [pscustomobject]@{OverrideBlockRules=$true} }
}
function Get-NetFirewallRule {
  [CmdletBinding()] param([Parameter(ValueFromPipeline=$true)]$InputObject)
  process {
    if ($scenario -eq 'rule_error') { throw 'rule_query_failed' }
    if ($scenario -eq 'empty_rules') { return }
    if ($scenario -eq 'override_inbound') { [pscustomobject]@{Enabled='True';Direction='Inbound';Action='Allow'} }
    else { [pscustomobject]@{Enabled='True';Direction='Outbound';Action='Allow'} }
  }
}
''' + self.policy + r'''
try { AssertPolicy; Write-Output 'PASS' }
catch { Write-Output ('FAIL:' + $_.Exception.Message) }
'''
        result = subprocess.run(['pwsh', '-NoLogo', '-NoProfile', '-NonInteractive', '-Command', script],
                                text=True, capture_output=True, timeout=15, check=True)
        return result.stdout.strip()

    def test_no_override_matches_in_nonempty_inventory(self):
        self.assertEqual(self.invoke('no_override'), 'PASS')

    def test_outbound_allow_override_rejected(self):
        self.assertIn('FAIL:outbound_allow_override_present', self.invoke('override_allow'))

    def test_inbound_override_does_not_trigger_outbound_guard(self):
        self.assertEqual(self.invoke('override_inbound'), 'PASS')

    def test_query_or_lookup_failure_is_closed(self):
        for scenario, message in [('profile_error', 'profile_query_failed'),
                                  ('query_error', 'security_query_failed'),
                                  ('rule_error', 'rule_query_failed'),
                                  ('empty_inventory', 'security_filter_inventory_empty'),
                                  ('empty_rules', 'override_rule_lookup_empty'),
                                  ('unknown_value', 'security_filter_override_unknown'),
                                  ('nonboolean_value', 'security_filter_override_unknown'),
                                  ('disabled_profile', 'active_firewall_profile_not_enabled')]:
            with self.subTest(scenario=scenario):
                self.assertIn('FAIL:' + message, self.invoke(scenario))


if __name__ == '__main__':
    unittest.main()
