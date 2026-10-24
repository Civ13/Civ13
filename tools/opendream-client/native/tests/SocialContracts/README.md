# Offline social contracts

This runner compiles the .NET launcher and exercises only injected social,
discovery, clock, command-preparation and dispatch fixtures. It never calls the
launcher Main method, Process.Start, real DNS/Topic, Discord or BYOND. No external
test packages, SDK binaries, credentials, installer or updater-replacement runner
are involved. No production startup path instantiates the social types.

Use an already installed .NET 8 SDK. global.json selects an installed stable 8.0
feature band; it does not install one. NuGet.Config clears package sources.
Run from this directory, using the verified absolute dotnet.exe path on Windows:

```powershell
$env:DOTNET_CLI_HOME = Join-Path (Get-Location) '.cli-home'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:DOTNET_CLI_WORKLOAD_UPDATE_NOTIFY_DISABLE = 'true'
$env:DOTNET_GENERATE_ASPNET_CERTIFICATE = 'false'
$env:DOTNET_ADD_GLOBAL_TOOLS_TO_PATH = 'false'
& 'C:\Program Files\dotnet\dotnet.exe' restore SocialContracts.csproj --configfile NuGet.Config -p:NuGetAudit=false --disable-parallel
if ($LASTEXITCODE -ne 0) { throw 'Offline restore failed' }
& 'C:\Program Files\dotnet\dotnet.exe' build SocialContracts.csproj --no-restore --disable-build-servers -p:UseSharedCompilation=false -nodeReuse:false
if ($LASTEXITCODE -ne 0) { throw 'Build failed' }
& 'C:\Program Files\dotnet\dotnet.exe' ./bin/Debug/net8.0/Civ13.Launcher.SocialContracts.dll
if ($LASTEXITCODE -ne 0) { throw 'Contracts failed' }
```

On another OS, use its existing dotnet executable and the same restore/build/run
arguments. Do not install a missing toolchain as part of this test. The explicit
certificate-generation setting prevents an isolated CLI home's first-use SDK
initialization from installing a development certificate.

The fixture assembly is the only new friend assembly. It constructs the existing
GameServer, PublicEndpoint and RecentGameStatus types with deterministic clocks;
their real validation methods and NativeStart remain unchanged. The fake adapter
deliberately completes work after cancellation and out of order. Passing tests
establish the application contracts, not native SDK conformance or live joins.

Join identity text uses letters/digits, space, underscore and hyphen, with no
leading/trailing spaces or leading hyphen, <=96 UTF-8 bytes. Whole strict JSON is
<=512 bytes. Duplicate fields (including escaped aliases), unknown fields/types,
non-v1 versions and invalid UTF-8 fail. These bounded expectations are compared
as data and never copied into process arguments.

ISocialClient.AdvanceGeneration synchronously fences old work. Each frame also
has a revision, so an older update within the same generation cannot overwrite a
newer one. Clear is terminal for its generation. A real adapter must enforce
these fences and monotonic expiry on asynchronous completion and arrange live
expiry cleanup. This timer-free slice only supplies contracts, no-op behavior,
and a test fake; it does not publish presence.

IServerDiscovery has no cancellation parameter. The controller invalidates a
cancelled intent immediately but awaits already-started discovery settlement
before admitting another attempt, rather than overlapping abandoned work. The
controller requires explicit discovery/preparation/dispatch injection; future
composition must prepare through ServerCatalog.NativeStart. It reuses the
existing proof validators again immediately before the injected dispatch. A
throwing dispatcher is treated as possibly acted, consumed and never retried.

Manual ServerBrowser joining is tested independently after a social adapter
failure. Authentication, application selection, SDK access/licensing, native
adapters, deep-link registration and actual joining remain future review gates.
