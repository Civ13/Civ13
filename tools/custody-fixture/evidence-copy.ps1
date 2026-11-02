function Copy-BoundedEvidence([string] $Source,[string] $Destination,[int] $Limit) {
    if ($Limit -lt 1 -or $Limit -gt 16384) { throw 'invalid_receipt_limit' }
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) { return $false }
    $item=Get-Item -LiteralPath $Source
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'receipt_reparse' }
    $buffer=[byte[]]::new($Limit+1);$used=0
    $stream=[IO.File]::Open($Source,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
    try { while($used -lt $buffer.Length) { $n=$stream.Read($buffer,$used,$buffer.Length-$used);if($n -eq 0){break};$used+=$n } } finally { $stream.Dispose() }
    if($used -gt $Limit){throw 'receipt_oversized'}
    $out=[IO.File]::Open($Destination,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try{$out.Write($buffer,0,$used);$out.Flush($true)}finally{$out.Dispose()}
    return $true
}
