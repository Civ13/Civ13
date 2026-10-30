# HELD REVIEW CANDIDATE. This entry point deliberately cannot change policy.
param([switch]$VerifyOnly)
$ErrorActionPreference = 'Stop'
$FirewallReviewReleased = $true
if (-not $FirewallReviewReleased) { throw 'HELD_FIREWALL_REVIEW' }

if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted' -or
    $env:GITHUB_REPOSITORY -ne 'Civ13/Civ13' -or $env:GITHUB_RUN_ATTEMPT -ne '1' -or
    $env:GITHUB_REF -ne 'refs/heads/ci/cloud-city-route-official-toolchain-5161688-20261030-r5' -or
    $env:GITHUB_RUN_ID -notmatch '^[1-9][0-9]{0,19}$') { throw 'wrong_hosted_admission' }
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$py = Join-Path $env:pythonLocation 'python.exe'
& $py -B (Join-Path $here 'activation.py')
if ($LASTEXITCODE -ne 0) { throw 'held_activation' }
$principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'administrator_unavailable' }
$temp = (Resolve-Path -LiteralPath $env:RUNNER_TEMP -ErrorAction Stop).Path
$engine = Join-Path $temp 'bakery-engine'
$bin = Join-Path $engine 'byond/bin'
$source = Join-Path $temp 'bakery-source'
$output = Join-Path $temp 'bakery-evidence'
$evidence = Join-Path $temp 'firewall-evidence'
$expected = [ordered]@{
    'dm.exe' = 'f29b3041c46df453b3f999583bef0bb0ff79fe2b53ee1b8686bb46ce18c7df77'
    'dd.exe' = 'abb21de26047724bf64411e17da5e17cacc74221817c3e049a79626156b44866'
    'dreamseeker.exe' = 'dde2893d7d6721eb8cb73d9e6b9f8cb28d86d1e432b42edaad10b066800a97e4'
}
$addresses = @{
    v4 = @('0.0.0.0-126.255.255.255','128.0.0.0-255.255.255.255')
    v6 = @('::/128','::2-ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff')
}
$programs = [ordered]@{}
foreach ($name in $expected.Keys) {
    $path = Join-Path $bin $name
    $item = Get-Item -LiteralPath $path -Force -ErrorAction Stop
    $parent = $item.Directory
    while ($null -ne $parent) {
        if ($parent.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'program_ancestor_reparse_point' }
        if ($parent.FullName -ieq $temp) { break }
        $parent = $parent.Parent
    }
    if ($null -eq $parent) { throw 'program_outside_runner_temp' }
    if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
        $item.FullName -ne $path -or
        (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant() -ne $expected[$name]) {
        throw 'program_identity_mismatch'
    }
    $programs[$name] = $item.FullName
}
function WriteNewJson([string]$path, $value) {
    $raw = [Text.Encoding]::UTF8.GetBytes(($value | ConvertTo-Json -Depth 12 -Compress) + "`n")
    if ($raw.Length -ge 65536) { throw 'firewall_receipt_oversize' }
    $stream = [IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try { $stream.Write($raw,0,$raw.Length); $stream.Flush($true) } finally { $stream.Dispose() }
}
function AssertPolicy() {
    $profiles = @(Get-NetConnectionProfile -ErrorAction Stop)
    if ($profiles.Count -eq 0) { throw 'no_active_network_profile' }
    $effective = @(Get-NetFirewallProfile -PolicyStore ActiveStore -ErrorAction Stop)
    foreach ($p in $profiles) {
        $name = if ($p.NetworkCategory -eq 'DomainAuthenticated') { 'Domain' } else { [string]$p.NetworkCategory }
        $match = @($effective | Where-Object { $_.Name -eq $name })
        if ($match.Count -ne 1 -or $match[0].Enabled -ne $true) { throw 'active_firewall_profile_not_enabled' }
    }
    # Query the full inventory: NetSecurity reports an empty *filtered* query
    # as ObjectNotFound, indistinguishable from a provider error at that call.
    $filters = @(Get-NetFirewallSecurityFilter -PolicyStore ActiveStore -ErrorAction Stop)
    if ($filters.Count -eq 0) { throw 'security_filter_inventory_empty' }
    foreach ($filter in $filters) {
        if ($filter.OverrideBlockRules -isnot [bool]) { throw 'security_filter_override_unknown' }
        if ($filter.OverrideBlockRules -eq $true) {
            $rules = @($filter | Get-NetFirewallRule -ErrorAction Stop)
            if ($rules.Count -eq 0) { throw 'override_rule_lookup_empty' }
            if (@($rules | Where-Object { $_.Enabled -eq 'True' -and $_.Direction -eq 'Outbound' -and $_.Action -eq 'Allow' }).Count -ne 0) {
                throw 'outbound_allow_override_present'
            }
        }
    }
}
function BoundedRuleFacts($items, [string[]]$fields) {
    $all = @($items)
    $rows = @($all | Select-Object -First 4 | ForEach-Object {
        $row = [ordered]@{}
        foreach ($field in $fields) {
            $values = @($_.$field)
            $row[$field] = @{ count=$values.Count; values=@($values | Select-Object -First 4 | ForEach-Object {
                $text = [string]$_
                @{ is_null=($null -eq $_); length=$text.Length; prefix=$text.Substring(0,[Math]::Min(128,$text.Length)) }
            }) }
        }
        $row
    })
    return @{ count=$all.Count; rows=$rows; truncated=($all.Count -gt 4) }
}
function SaveRuleReadback($entry, [string]$store, [string]$phase, $facts, [string]$reason) {
    if ($store -notin @('PersistentStore','ActiveStore') -or $phase -notin @('validation','cleanup')) { throw 'invalid_readback_label' }
    WriteNewJson (Join-Path $evidence ($entry.name + '.' + $store + '.' + $phase + '.json')) @{
        run_id=$env:GITHUB_RUN_ID; head=$env:GITHUB_SHA; attempt=1
        name=$entry.name; store=$store; phase=$phase; reason=$reason
        expected=@{program=$entry.program; addresses=$entry.addresses}; actual=$facts
    }
}
function AssertRule($entry, [string]$store) {
    $facts = [ordered]@{}
    try {
    $matches = @(Get-NetFirewallRule -PolicyStore $store -ErrorAction Stop | Where-Object { $_.Name -ceq $entry.name })
    $facts.rule = BoundedRuleFacts $matches @('Name','InstanceID','DisplayName','Enabled','Direction','Action','Profile','PolicyStoreSource','PolicyStoreSourceType')
    if ($matches.Count -ne 1) { throw 'rule_missing_or_duplicate' }
    $rule = $matches[0]
    if ($rule.Enabled -ne 'True' -or $rule.Direction -ne 'Outbound' -or $rule.Action -ne 'Block' -or $rule.Profile -ne 'Any') { throw 'rule_core_mismatch' }
    $app = @($rule | Get-NetFirewallApplicationFilter -ErrorAction Stop)
    $addr = @($rule | Get-NetFirewallAddressFilter -ErrorAction Stop)
    $ports = @($rule | Get-NetFirewallPortFilter -ErrorAction Stop)
    $security = @($rule | Get-NetFirewallSecurityFilter -ErrorAction Stop)
    $interfaces = @($rule | Get-NetFirewallInterfaceTypeFilter -ErrorAction Stop)
    $facts.application = BoundedRuleFacts $app @('Program','Package')
    $facts.address = BoundedRuleFacts $addr @('LocalAddress','RemoteAddress')
    $facts.port = BoundedRuleFacts $ports @('Protocol','LocalPort','RemotePort')
    $facts.security = BoundedRuleFacts $security @('Authentication','Encryption','OverrideBlockRules','LocalUser','RemoteUser','RemoteMachine')
    $facts.interface = BoundedRuleFacts $interfaces @('InterfaceType')
    if ($app.Count -ne 1 -or $addr.Count -ne 1 -or $ports.Count -ne 1 -or $security.Count -ne 1 -or $interfaces.Count -ne 1 -or
        $security[0].OverrideBlockRules -eq $true -or $interfaces[0].InterfaceType -ne 'Any' -or $app[0].Program -ine $entry.program -or
        ([string]$ports[0].Protocol -notin @('Any','256')) -or
        (Compare-Object @($addr[0].RemoteAddress | Sort-Object) @($entry.addresses | Sort-Object))) { throw 'rule_filter_mismatch' }
    } catch {
        $reason = $_.Exception.Message
        SaveRuleReadback $entry $store 'validation' $facts $reason
        throw
    }
}
function RememberCreatedRule($entry, $returned) {
    $items = @($returned)
    if ($items.Count -ne 1 -or $items[0].Name -cne $entry.name -or
        $items[0].DisplayName -cne $entry.name -or
        $items[0].CimClass.CimClassName -cne 'MSFT_NetFirewallRule' -or
        [string]::IsNullOrEmpty([string]$items[0].InstanceID) -or ([string]$items[0].InstanceID).Length -gt 512) {
        throw 'created_rule_identity_unknown'
    }
    $owned[$entry.name] = @{ instance_id=[string]$items[0].InstanceID; program=$entry.program }
}
function RemoveOwnedRule($entry) {
    if (-not $owned.ContainsKey($entry.name)) { throw 'cleanup_ownership_unknown' }
    $token = $owned[$entry.name]
    $matches = @(Get-NetFirewallRule -PolicyStore PersistentStore -ErrorAction Stop | Where-Object { $_.Name -ceq $entry.name })
    if ($matches.Count -ne 1) { throw 'cleanup_identity_missing_or_duplicate' }
    $rule = $matches[0]
    $app = @($rule | Get-NetFirewallApplicationFilter -ErrorAction Stop)
    $facts = @{
        rule=(BoundedRuleFacts $matches @('Name','InstanceID','DisplayName','Enabled','Direction','Action','Profile'))
        application=(BoundedRuleFacts $app @('Program','Package'))
    }
    # Policy correctness is deliberately separate: only this run's returned
    # rule identity and unchanged exact program binding authorize deletion.
    $known = $rule.Name -ceq $entry.name -and $rule.DisplayName -ceq $entry.name -and
        $rule.CimClass.CimClassName -ceq 'MSFT_NetFirewallRule' -and
        $rule.InstanceID -ceq $token.instance_id -and $app.Count -eq 1 -and
        $app[0].Program -ieq $token.program -and $token.program -ieq $entry.program
    $readbackError = $null
    try { SaveRuleReadback $entry 'PersistentStore' 'cleanup' $facts $(if ($known) {'OWNED_IDENTITY_VERIFIED'} else {'OWNERSHIP_UNKNOWN'}) }
    catch { $readbackError = $_.Exception.Message }
    if (-not $known) { throw 'cleanup_ownership_unknown' }
    Remove-NetFirewallRule -InputObject $rule -ErrorAction Stop
    foreach ($store in @('PersistentStore','ActiveStore')) {
        if (@(Get-NetFirewallRule -PolicyStore $store -ErrorAction Stop | Where-Object { $_.Name -ceq $entry.name }).Count -ne 0) { throw 'rule_still_present' }
    }
    return $readbackError
}
AssertPolicy
if ($VerifyOnly) {
    $activePath = Join-Path $evidence 'active.json'
    $item = Get-Item -LiteralPath $activePath -Force -ErrorAction Stop
    if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $item.Length -ge 65536) { throw 'unsafe_active_receipt' }
    $active = Get-Content -Raw -LiteralPath $activePath | ConvertFrom-Json
    if ($active.state -ne 'ACTIVE_POLICY_CHECKED' -or $active.run_id -cne $env:GITHUB_RUN_ID -or $active.head -cne $env:GITHUB_SHA -or $active.attempt -ne 1 -or @($active.rules).Count -ne 6) { throw 'wrong_active_receipt_binding' }
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $pairs = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($r in $active.rules) {
        if ($r.name -notmatch ('^civ13-preflight-' + $env:GITHUB_RUN_ID + '-1-[0-9a-f]{32}-(dm-exe|dd-exe|dreamseeker-exe)-(v4|v6)$') -or -not $seen.Add([string]$r.name)) { throw 'wrong_active_rule_name' }
        $role = $Matches[1]
        $family = $Matches[2]
        $exe = switch ($role) { 'dm-exe' {'dm.exe'} 'dd-exe' {'dd.exe'} 'dreamseeker-exe' {'dreamseeker.exe'} }
        if (-not $pairs.Add($exe + '|' + $family)) { throw 'duplicate_active_rule_pair' }
        if ($r.program -ine $programs[$exe] -or (Compare-Object @($r.addresses | Sort-Object) @($addresses[$family] | Sort-Object))) { throw 'wrong_active_rule_spec' }
        AssertRule $r 'ActiveStore'
    }
    if ($seen.Count -ne 6) { throw 'incomplete_active_rule_set' }
    exit 0
}
if (Test-Path -LiteralPath $evidence) { throw 'firewall_evidence_not_fresh' }
$nonce = [guid]::NewGuid().ToString('N')
$rules = @()
foreach ($name in $expected.Keys) {
    foreach ($family in @('v4','v6')) {
        $id = 'civ13-preflight-' + $env:GITHUB_RUN_ID + '-1-' + $nonce + '-' + $name.Replace('.','-') + '-' + $family
        if ($id -notmatch '^[a-z0-9-]{1,120}$') { throw 'invalid_rule_identity' }
        $rules += @{ name=$id; program=$programs[$name]; addresses=$addresses[$family] }
    }
}
foreach ($store in @('PersistentStore','ActiveStore')) {
    $existing = @(Get-NetFirewallRule -PolicyStore $store -ErrorAction Stop)
    foreach ($r in $rules) { if (@($existing | Where-Object { $_.Name -ceq $r.name }).Count -ne 0) { throw 'rule_name_already_exists' } }
}
New-Item -ItemType Directory -Path $evidence -ErrorAction Stop | Out-Null
WriteNewJson (Join-Path $evidence 'planned.json') @{ run_id=$env:GITHUB_RUN_ID; attempt=1; head=$env:GITHUB_SHA; rules=$rules; state='PLANNED_NOT_CREATED' }
$created = [Collections.Generic.List[object]]::new()
$owned = @{}
$nativeStarted = $false
$nativeCleanupVerified = $false
$failure = $null
try {
    foreach ($r in $rules) {
        $returned = @(New-NetFirewallRule -Name $r.name -DisplayName $r.name -Direction Outbound -Action Block -Enabled True -Profile Any -Protocol Any -Program $r.program -RemoteAddress $r.addresses -PolicyStore PersistentStore -ErrorAction Stop)
        $created.Add($r)
        RememberCreatedRule $r $returned
        WriteNewJson (Join-Path $evidence ($r.name + '.created.json')) @{name=$r.name; program=$r.program; instance_id=$owned[$r.name].instance_id; state='CREATED'}
        AssertRule $r 'PersistentStore'
        AssertRule $r 'ActiveStore'
    }
    AssertPolicy
    foreach ($r in $rules) { AssertRule $r 'ActiveStore' }
    WriteNewJson (Join-Path $evidence 'active.json') @{run_id=$env:GITHUB_RUN_ID; attempt=1; head=$env:GITHUB_SHA; state='ACTIVE_POLICY_CHECKED'; rules=$rules; packet_enforcement_tested=$false}
    # Existing supervisor still has its independent NETWORK_RUNTIME_ADMITTED hold.
    # No publication/release occurs here. A later reviewed integration must bind
    # that hold to this active receipt and recheck policy before each launch.
    $nativeStarted = $true
    & $py -B (Join-Path $here 'run_scene.py') --binary $bin --source $source --output $output --execute-reviewed-scene
    $nativeExit = $LASTEXITCODE
    $cleanup = Join-Path $output 'cleanup-receipt.json'
    if (-not (Test-Path -LiteralPath $cleanup)) { throw 'native_cleanup_receipt_missing' }
    $record = Get-Content -Raw -LiteralPath $cleanup | ConvertFrom-Json
    if (@($record.cleanup).Count -eq 0 -or @($record.cleanup | Where-Object { $_.all_exited -ne $true }).Count -ne 0) { throw 'native_cleanup_unverified' }
    $nativeCleanupVerified = $true
    if ($nativeExit -ne 0) { throw 'native_preflight_failed' }
} catch { $failure = $_.Exception.Message } finally {
    $removed = @(); $errors = @(); $cleanupFailures = @()
    if (-not $nativeStarted -or $nativeCleanupVerified) {
        foreach ($r in $created) {
            try {
                $readbackError = RemoveOwnedRule $r
                $removed += $r.name
                if ($null -ne $readbackError) { throw ('cleanup_readback_failed_after_verified_removal:' + $readbackError) }
            } catch {
                $errors += $r.name
                $message = $_.Exception.Message
                $cleanupFailures += @{name=$r.name; error=$message.Substring(0,[Math]::Min(256,$message.Length))}
            }
        }
    } else { $errors += 'native_cleanup_unverified_rules_retained' }
    try { WriteNewJson (Join-Path $evidence 'cleanup.json') @{created=@($created | ForEach-Object { $_.name }); removed=$removed; errors=$errors; cleanup_failures=$cleanupFailures; native_started=$nativeStarted; native_cleanup_verified=$nativeCleanupVerified; failure=$failure} }
    catch { throw 'firewall_cleanup_receipt_failed' }
}
if ($failure -or $errors.Count -gt 0) { throw 'firewall_preflight_failed_or_cleanup_unverified' }
