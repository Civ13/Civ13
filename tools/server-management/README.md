# Server management P0 contracts

This package is an inert .NET 8 library for an observe-only instance catalog and
status projection. It has no launcher wiring, collector, host/config/save discovery,
process or network operations, installation, scheduler or lifecycle effects.
No package source or external dependency is required. The existing launcher can
consume a shared headless core later; this package does not replace its UI.

`ManifestJson.ReadManifest` accepts the bounded strict `instance.example.json`
format. `ReadCatalog` accepts `{ "schema": "civ13.catalog.v1", "instances": [...] }`.
Maximum decoded input is 16 KiB per manifest, 256 KiB per catalog, depth eight and
128 catalog entries. Unknown/missing fields, case aliases, duplicate keys/IDs,
wrong types, future schemas and unsupported registration modes reject. Parsing
and typed catalog construction validate before returning a detached read-only
list. Errors contain stable codes, not input values. No catalog file is written.

An instance is an OS process profile (`process`) or an explicitly grouped process
profile (`shard`). Both have canonical nonempty UUID instance IDs and separate
case-sensitive opaque host/profile IDs. Logical zone IDs, native areas, geographic layers and
save-generation IDs are not instance or shard IDs and are rejected as kinds.
Shards require a group ID; process entries require null. This is metadata, not
implemented shard coordination. `observe-only` grants no control or ownership.
Only Civ13 BYOND metadata is accepted. A syntactically valid runtime version or
profile hash establishes neither supported compatibility nor artifact trust.

Every observation carries the entire instance/host/profile/revision/digest/kind
binding and the exact requested process receipt identity, even for `Missing`,
`Denied` and `Unavailable`. Scope mismatch is unknown. Explicit absence without
a requested receipt also stays unknown; another instance's absence cannot mark
this instance stopped. PID/boot/start/run/executable changes hold instead of
adopting the process. Missing, denied and unavailable remain distinct reasons.
Desired state never rewrites observation. Presence alone is not backend readiness.

`ClockScope` is an opaque collector-incarnation identity for a single monotonic
millisecond clock domain. Never reuse it across collector restart or host reboot.
Age is checked without renewal; negative/future/stale samples and changed scope
become unknown. A future adapter must authenticate/validate receipt provenance,
canonical process identity, request binding and actual backend readiness before
constructing evidence. Caller-supplied DTO equality is not independent proof.
`MatchingReceipt` is a display comparison, not a lease or action authorization.
No DTO/status result enables mutations. Persisted/public status data must never
be deserialized into fresh authority or readiness evidence.

Run the synthetic tests with an existing .NET 8 targeting pack, after setting the
following variables in the child shell only:

```powershell
$env:DOTNET_GENERATE_ASPNET_CERTIFICATE = 'false'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:DOTNET_CLI_WORKLOAD_UPDATE_NOTIFY_DISABLE = 'true'
$env:DOTNET_ADD_GLOBAL_TOOLS_TO_PATH = 'false'
$env:DOTNET_CLI_HOME = Join-Path $env:TEMP 'civ13-management-cli'
dotnet restore tools/server-management/tests/Contracts.csproj --configfile tools/server-management/NuGet.Config -p:NuGetAudit=false
dotnet run --project tools/server-management/tests/Contracts.csproj --no-restore --configuration Release
```

The ordinary pull-request workflow runs only these offline contracts on Windows
and Linux. It invokes no game, launcher Main, native DLL, discovery or credentials.
Passing contracts do not establish native compatibility, save consistency, real
host ownership or live management readiness. Future stages are explicit adoption,
fenced process adapters, accepted lifecycle/save/restore, resource admission and
only then scheduling, shard custody and management UI. Private-world economies
must remain isolated from authoritative imports until trusted custody gates exist.
