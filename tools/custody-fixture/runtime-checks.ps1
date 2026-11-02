# Pure certificate-subject parser and read-only Authenticode inspection.
function Get-PublisherIdentity([System.Security.Cryptography.X509Certificates.X500DistinguishedName] $Name) {
    $memory=[System.ReadOnlyMemory[byte]]::new($Name.RawData)
    $reader=[System.Formats.Asn1.AsnReader]::new($memory,[System.Formats.Asn1.AsnEncodingRules]::DER)
    $sequence=$reader.ReadSequence(); $cn=$null; $organization=$null; $count=0
    while($sequence.HasData) {
        $set=$sequence.ReadSetOf()
        while($set.HasData) {
            $count++; if($count -gt 32) { throw 'subject_too_many_fields' }
            $item=$set.ReadSequence(); $oid=$item.ReadObjectIdentifier()
            if ($oid -ceq '2.5.4.3' -or $oid -ceq '2.5.4.10') {
                $tag=$item.PeekTag()
                if ($tag.TagClass -ne [System.Formats.Asn1.TagClass]::Universal -or $tag.TagValue -notin @(12,19,20,30)) { throw 'unsupported_subject_field' }
                $value=$item.ReadCharacterString([System.Formats.Asn1.UniversalTagNumber]$tag.TagValue)
                if ($value.Length -gt 128) { throw 'subject_field_too_long' }
                if($oid -ceq '2.5.4.3') { if($null -ne $cn) { throw 'duplicate_common_name' }; $cn=$value }
                else { if($null -ne $organization) { throw 'duplicate_organization' }; $organization=$value }
            } else { [void]$item.ReadEncodedValue() }
            $item.ThrowIfNotEmpty()
        }
        $set.ThrowIfNotEmpty()
    }
    $sequence.ThrowIfNotEmpty(); $reader.ThrowIfNotEmpty()
    if($null -eq $cn -or $null -eq $organization) { throw 'missing_publisher_identity' }
    return [pscustomobject]@{common_name=$cn;organization=$organization}
}
function Assert-PublisherIdentity($Identity,[string] $Publisher) {
    switch -CaseSensitive ($Publisher) {
        'python' { if ($Identity.common_name -cne 'Python Software Foundation' -or $Identity.organization -cne 'Python Software Foundation') { throw 'python_publisher_mismatch' } }
        'dotnet' { if ($Identity.common_name -cne '.NET' -or $Identity.organization -cne 'Microsoft Corporation') { throw 'dotnet_publisher_mismatch' } }
        default { throw 'unknown_expected_publisher' }
    }
}
function Get-VerifiedRuntimeFile([string] $Path,[string] $Publisher) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw 'supported_runtime_unavailable' }
    $item=Get-Item -LiteralPath $Path
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'runtime_reparse_refused' }
    $sig=Get-AuthenticodeSignature -LiteralPath $Path
    if ($sig.Status -ne 'Valid' -or $null -eq $sig.SignerCertificate) { throw 'runtime_signature_invalid' }
    $identity=Get-PublisherIdentity $sig.SignerCertificate.SubjectName
    Assert-PublisherIdentity $identity $Publisher
    return [pscustomobject]@{
        path=$Path;publisher=$Publisher;sha256=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
        file_version=$item.VersionInfo.FileVersion;signer_cn=$identity.common_name;signer_organization=$identity.organization
        signer_subject=$sig.SignerCertificate.SubjectName.Name;signer_issuer=$sig.SignerCertificate.IssuerName.Name
        signer_thumbprint=$sig.SignerCertificate.Thumbprint
    }
}
function Assert-RuntimeMatches($Expected) {
    $actual=Get-VerifiedRuntimeFile $Expected.path $Expected.publisher
    foreach($field in @('path','publisher','sha256','file_version','signer_cn','signer_organization','signer_subject','signer_issuer','signer_thumbprint')) {
        if ($actual.$field -cne $Expected.$field) { throw 'runtime_identity_changed' }
    }
}
