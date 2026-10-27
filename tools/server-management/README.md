# Server management P0 contracts

This package is a .NET 8 library for an observe-only instance catalog, status
projection and explicitly invoked local process facts. It has no launcher wiring,
host/config/save discovery, network operations, installation, scheduler or lifecycle effects.
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

## Explicit local process facts

`LocalProcessObserver` binds a single operator-selected `ProcessTarget` to the
complete instance/host/profile/revision/digest/kind and expected PID/start time.
It refuses a different local host or request binding before inspection. There is
no process-name/table enumeration, hostname resolution, automatic registration,
receipt adoption or polling loop. The caller supplies its configured local host
ID and a process-local monotonic clock scope; neither is discovered from a peer.
All evidence kinds retain that complete request, including initial PID absence.

`ProcessFactsReader` uses an injected read session. `SystemProcessAccessor` is the
read-only Windows/Linux implementation using `Process.GetProcessById`, refresh,
exit state and UTC start-time ticks. It samples twice and releases its query
object; it never starts, stops, signals, kills or configures a process. Only an
initial missing-PID lookup is `Missing`; exit/change during reading, unsupported
platform and query failure are `Unavailable`, while permission failure is
`Denied`. Errors expose fixed codes, not OS messages, paths or command lines.
No executable file, credentials, environment, memory or module list is read.

The elapsed read budget is an admission check after the synchronous read returns,
not a hard cancellation/deadline for OS calls. Samples keep their original start
time. A clock change/regression, slow read, malformed evidence, stale sample or
different request fails closed. `ProcessFactProjection` displays PID absence or
start-time match/mismatch separately from `StatusProjection`: absence alone does
not assert an instance stopped, and matching OS facts do not establish ownership,
an executable hash, boot/run identity, a lease, health or backend readiness.
Two reads cannot eliminate TOCTOU or justify later lifecycle actions. Start-time
precision/platform semantics and actual Windows/Linux behavior need separate
acceptance before operational use. No conversion to an authoritative `Observation`
is supplied; in particular, expected boot/run IDs are never copied into observed
identity. The existing Windows lifecycle supervisor's FILETIME/receipt contract
is separate and has not been adopted or changed by this adapter.

Tests inject both process sessions and clocks, exercising the real reader and
observer algorithms without calling `SystemProcessAccessor` or inspecting any
live process. The adapter remains unwired to the launcher and game entrypoints.

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
