"""Run source-extracted functions against mocked NetSecurity; never dot-source entry."""
import json
import re
import subprocess
import unittest
from pathlib import Path

SOURCE = Path(__file__).parent / 'firewall_supervisor.ps1'


class OwnedFirewallCleanup(unittest.TestCase):
    def invoke(self, scenario):
        source = SOURCE.read_text(encoding='utf-8')
        functions = []
        for name in ('BoundedRuleFacts', 'SaveRuleReadback', 'AssertRule', 'RememberCreatedRule', 'RemoveOwnedRule'):
            found = re.search(r'(?ms)^function ' + name + r'\([^\n]*\) \{.*?^\}', source)
            self.assertIsNotNone(found, name)
            functions.append(found.group())
        cleanup = source[source.index('    if (-not $nativeStarted -or $nativeCleanupVerified) {'):
                         source.index('    try { WriteNewJson (Join-Path $evidence \'cleanup.json\')')]
        script = "$scenario = '" + scenario + "'\n" + r'''
$ErrorActionPreference='Stop'
$evidence='TEST-ONLY-NOT-WRITTEN'
$script:diags=[Collections.Generic.List[object]]::new()
$script:removed=[Collections.Generic.List[string]]::new()
$script:present=$true
$entry=@{name='test-owned-rule';program='C:\test-only\dm.exe';addresses=@('::/128','::2-ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff')}
$script:rule=[pscustomobject]@{Name=$entry.name;DisplayName=$entry.name;InstanceID='owned-instance';CimClass=[pscustomobject]@{CimClassName='MSFT_NetFirewallRule'};Enabled='True';Direction='Outbound';Action='Block';Profile='Any'}
$script:app=[pscustomobject]@{Program=$entry.program;Package='Any'}
$script:address=[pscustomobject]@{RemoteAddress=$entry.addresses;LocalAddress='Any'}
$script:port=[pscustomobject]@{Protocol='Any';LocalPort='Any';RemotePort='Any'}
$script:security=[pscustomobject]@{OverrideBlockRules=$false;Authentication='NotRequired';Encryption='NotRequired'}
$script:interface=[pscustomobject]@{InterfaceType='Any'}
function WriteNewJson($path,$value) { if ($scenario -eq 'readback_error') { throw 'test_write_failed' }; [void]$script:diags.Add($value) }
function Get-NetFirewallRule {
 [CmdletBinding()] param($PolicyStore)
 if ($scenario -eq 'query_error') { throw 'query_failed' }
 if ($script:present) { $script:rule; if ($scenario -eq 'duplicate') { $script:rule } }
}
function Get-NetFirewallApplicationFilter { [CmdletBinding()] param([Parameter(ValueFromPipeline=$true)]$InputObject) process { if ($scenario -ne 'missing_app') { $script:app } } }
function Get-NetFirewallAddressFilter { [CmdletBinding()] param([Parameter(ValueFromPipeline=$true)]$InputObject) process { $script:address } }
function Get-NetFirewallPortFilter { [CmdletBinding()] param([Parameter(ValueFromPipeline=$true)]$InputObject) process { $script:port } }
function Get-NetFirewallSecurityFilter { [CmdletBinding()] param([Parameter(ValueFromPipeline=$true)]$InputObject) process { $script:security } }
function Get-NetFirewallInterfaceTypeFilter { [CmdletBinding()] param([Parameter(ValueFromPipeline=$true)]$InputObject) process { $script:interface } }
function Remove-NetFirewallRule {
 [CmdletBinding()] param($InputObject)
 if ($scenario -eq 'delete_error') { throw 'delete_failed' }
 if (-not [object]::ReferenceEquals($InputObject,$script:rule)) { throw 'wrong_delete_object' }
 [void]$script:removed.Add($InputObject.InstanceID)
 if ($scenario -ne 'still_present') { $script:present=$false }
}
$owned=@{}
''' + '\n'.join(functions) + r'''
$status='PASS'
try {
 if ($scenario -in @('valid','address_mismatch','query_error','duplicate','missing_app','override')) {
   if ($scenario -eq 'address_mismatch') { $script:address.RemoteAddress=@('::','::2-ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff') }
   if ($scenario -eq 'override') { $script:security.OverrideBlockRules=$true }
   AssertRule $entry 'PersistentStore'
 } elseif ($scenario -eq 'bounded') {
   $facts=BoundedRuleFacts (@(1..20 | ForEach-Object { [pscustomobject]@{Value=('x'*500)} })) @('Value')
   [void]$script:diags.Add($facts)
 } else {
   if ($scenario -ne 'no_token') { RememberCreatedRule $entry @($script:rule) }
   if ($scenario -eq 'changed_instance') { $script:rule.InstanceID='not-ours' }
   if ($scenario -eq 'changed_program') { $script:app.Program='C:\unrelated.exe' }
   if ($scenario -eq 'changed_class') { $script:rule.CimClass.CimClassName='NotOurClass' }
   if ($scenario -eq 'policy_mismatch') { $script:rule.Action='Allow'; $script:address.RemoteAddress=@('wrong') }
   if ($scenario -eq 'native_cleanup_unknown') {
     $nativeStarted=$true; $nativeCleanupVerified=$false; $created=@($entry)
     $removed=@(); $errors=@(); $cleanupFailures=@()
''' + cleanup + r'''
     if ($errors -notcontains 'native_cleanup_unverified_rules_retained') { throw 'lost_native_hold' }
   } else {
     $readbackError=RemoveOwnedRule $entry
     if ($null -ne $readbackError) { $status='REMOVED_WITH_READBACK_ERROR:'+$readbackError }
   }
 }
} catch { $status='FAIL:'+$_.Exception.Message }
@{status=$status;deleted=@($script:removed);diags=@($script:diags.ToArray())} | ConvertTo-Json -Depth 20 -Compress
'''
        result = subprocess.run(['pwsh','-NoLogo','-NoProfile','-NonInteractive','-Command',script],
                                text=True,capture_output=True,check=True,timeout=15)
        return json.loads(result.stdout)

    def test_policy_pass_and_actual_failed_readback(self):
        # Artificial mismatch exercises readback retention, not a claim about r4.
        self.assertEqual(self.invoke('valid')['status'], 'PASS')
        row=self.invoke('address_mismatch')
        self.assertEqual(row['status'],'FAIL:rule_filter_mismatch')
        self.assertEqual(row['deleted'],[])
        actual=row['diags'][0]['actual']['address']['rows'][0]['RemoteAddress']
        self.assertEqual(actual['values'][0]['prefix'],'::')
        self.assertEqual(row['diags'][0]['expected']['addresses'][0],'::/128')

    def test_policy_queries_cardinality_and_overrides_remain_closed(self):
        for scenario,reason in [('query_error','query_failed'),('duplicate','rule_missing_or_duplicate'),
                                ('missing_app','rule_filter_mismatch'),('override','rule_filter_mismatch')]:
            with self.subTest(scenario=scenario):
                row=self.invoke(scenario)
                self.assertEqual(row['status'],'FAIL:'+reason)
                self.assertEqual(row['deleted'],[])
                self.assertEqual(len(row['diags']),1)

    def test_owned_cleanup_ignores_policy_mismatch_but_checks_identity(self):
        row=self.invoke('policy_mismatch')
        self.assertEqual(row['status'],'PASS')
        self.assertEqual(row['deleted'],['owned-instance'])
        self.assertEqual(row['diags'][0]['reason'],'OWNED_IDENTITY_VERIFIED')

    def test_unknown_ownership_is_never_deleted(self):
        for scenario in ('no_token','changed_instance','changed_program','changed_class'):
            with self.subTest(scenario=scenario):
                row=self.invoke(scenario)
                self.assertEqual(row['status'],'FAIL:cleanup_ownership_unknown')
                self.assertEqual(row['deleted'],[])

    def test_removal_failure_and_failed_absence_readback_are_not_clean(self):
        for scenario,reason in [('delete_error','delete_failed'),('still_present','rule_still_present')]:
            with self.subTest(scenario=scenario):
                self.assertEqual(self.invoke(scenario)['status'],'FAIL:'+reason)

    def test_unverified_native_cleanup_keeps_rules(self):
        row=self.invoke('native_cleanup_unknown')
        self.assertEqual(row['status'],'PASS')
        self.assertEqual(row['deleted'],[])

    def test_diagnostic_write_failure_does_not_prevent_known_owned_cleanup(self):
        row=self.invoke('readback_error')
        self.assertEqual(row['status'],'REMOVED_WITH_READBACK_ERROR:test_write_failed')
        self.assertEqual(row['deleted'],['owned-instance'])

    def test_readbacks_are_bounded_with_explicit_original_lengths(self):
        row=self.invoke('bounded')['diags'][0]
        self.assertEqual(row['count'],20)
        self.assertTrue(row['truncated'])
        self.assertEqual(len(row['rows']),4)
        value=row['rows'][0]['Value']['values'][0]
        self.assertEqual(value['length'],500)
        self.assertEqual(len(value['prefix']),128)


if __name__=='__main__': unittest.main()
