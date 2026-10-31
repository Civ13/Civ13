# Read-only local management presentation boundary

## Explicit operator view

`Civ13.exe --registered-instances <trusted-D-root> <registration-file> <local-host-id>`
performs one read and exits before the launcher's update, client setup and menu.
Both paths are explicitly supplied absolute D: paths, with the catalog strictly
under the selected root. The root must be operator-controlled and trusted. The
existing reader's attribute checks are not race-proof containment or identity
verification and must not be used with an untrusted directory. Its time budget
is measured after synchronous I/O returns; it is not a hard deadline. No paths
are printed by this command, but command lines can be visible to local processes
or shell history.

The catalog is the existing `civ13.catalog.v1` schema. Each bounded
`civ13.instance.v1` entry is declaration-only and binds an instance UUID, host,
profile/revision/hash and process-or-shard kind. Missing, denied, malformed,
slow, stale or clock-changed input remains unknown rather than an empty catalog.
An available empty catalog describes only the supplied file. Successful parsing
returns exit 0; unavailable/invalid input returns 1. Exit 0 never asserts current
process state, readiness, ownership or an actionable lease.

No process targets are inferred, so local entries say their facts are unknown;
remote entries are outside the local view. The future manager interface must
explicitly supply a target bound to the same full instance/host/profile revision,
hash and kind, plus a request-bound observation with PID, start ticks, evidence,
original monotonic clock scope and sample/completion times. Stale, changed-clock,
wrong-binding and invalid evidence remains unknown. Matching PID/start is only OS
evidence, not an ownership grant, backend readiness or permission to control.
Do not derive ownership from public status, cached display data or catalog fields.
Actual trusted provenance and ownership/lease contracts belong to the manager
owner; this command has no start, stop, update, discovery or refresh controls.

Normal BYOND play remains independent of this command and the launcher. The
command creates no registration, credentials, runtime configuration or services.

Private follow-on source slice based on public master
`c79792d002b9a15b7cebd7735a43f6ac960ad4b2` and the exact frozen process-facts
dependency from draft #3354 at `438b0c12cc9a949426d6d3db235fac29d963cc50`.
The source dependency is unchanged. This slice is not runtime activation.

## Actual launcher architecture and smallest delta

The current launcher is a .NET8 console application. `Program.WriteMainMenu`
and `ServerBrowser.WriteServers(TextWriter, ...)` own text presentation;
`ServerBrowser.Run` owns the existing interactive refresh/join loop. The native
project explicitly includes source files. Its active Main performs update/BYOND
checks and public discovery before the game menus. None of that path is invoked
by this fixture or changed here. Older PowerShell wrappers bootstrap the launcher;
they are not a Python GUI or an existing management IPC channel.

`LocalManagementPresentation.WriteInstances` reuses the TextWriter convention.
It consumes bounded typed manifests, explicit process targets and observations
compiled directly from the shared .NET8 core sources. No new wire schema, pipe,
HTTP endpoint, Python bridge, file watcher or collector interface is invented.
No process reader is an argument or constructed by the renderer. Clock scope and
current monotonic time are supplied explicitly; rendering cannot renew samples.

The complete cohort validates before any output. Unknown/unregistered/nonlocal,
missing, denied, unavailable, stale, wrong-profile and changed-start facts remain
distinct/conservative. Process details render only after the shared projection
admits a current, exactly bound observation. Desired state is separate; PID absence
does not assert server stopped, and matching start time does not imply ownership,
readiness or a lifecycle capability. Logical zones remain outside process/shard
profile kinds. The explicit command above invokes this renderer once; there is no
management menu, registration writer, refresh loop or action.

The isolated presentation executable references the ACTUAL launcher project and
renders supplied fake records into StringWriter. The parent test project excludes
that nested Program, matching its existing SocialContracts exclusion pattern.
No existing test is removed or replaced. Launcher CI runs this fixture and the
composition, file-reader and registration programs offline; no native
launcher/game acceptance or packaging is claimed.

## Remaining integration gates

`LocalManagementComposition` is a pure join over an explicitly bound
registration snapshot and caller-supplied process targets and observations. It
checks registration source, clock scope, age and full target binding; a missing,
denied, stale or otherwise unusable registration stays a status with no entries.
For registration-backed displays, `WriteRegisteredInstances` recomposes the
snapshot at every display using an injected monotonic clock, checks the status,
and renders entries only for an available registration. Failed or expired
registration remains unknown rather than an empty catalog. The lower-level
`WriteInstances` is for already supplied standalone entries and does not retain
registration freshness; it must not be used directly with cached batch entries.
The clock scope and monotonic time are trusted inputs, and freshness is measured
at the display sample rather than continuously during output.
It cannot supply missing targets or establish process ownership. The existing
process projection separately handles stale or mismatched observation evidence.
These inputs must come from a future reviewed adapter, not inferred discovery.

`RegistrationProvider` is a declaration-only contract. It accepts one
explicit D: absolute file path, an injected bounded reader and an injected clock;
it never opens a file itself. Results bind the exact requested path and clock scope,
distinguish missing/denied/unavailable/invalid data, and do not manufacture process
targets or observations. Paths can contain private operator information; never log
or publish them. Lexical D: validation is not filesystem containment or ownership:
a reader must independently handle junctions/reparse points, bounded reads and
access decisions. `ReadOnlyRegistrationFileReader` takes an explicit
lexically canonical D: root and requires a fixed drive, a target strictly beneath
that root, no reparse points along the path, and a byte limit. It checks attributes
before and after reading, reports missing, denied, unavailable and invalid separately,
and does not turn declarations into ownership. These checks cannot prove filesystem
identity or race-proof containment against a concurrent replacement. It must not be
activated for untrusted directories without a separately reviewed native containment
contract. The fake filesystem tests do not establish Windows containment or drive
identity; no actual D: configuration was read. Case-insensitive lexical matching
does not establish path identity in Windows case-sensitive directories. Its synchronous time budget is checked
after return, not an interruptible deadline. The explicit command uses this reader
only for an operator-selected trusted root. Real Windows containment and operation
remain unaccepted; no D: path is created or read by the fake tests.

- The manager owner must define how scoped observations and a trusted registration
  source reach this view. No automatic host/PID discovery
  or receipt adoption. Do not pass public status/cache data as fresh local facts.
- Runtime configuration stays on D:. This delta introduces no configuration
  path, file, migration or write. A later approved provider must inject the
  D:-owned registration/configuration explicitly. Existing Main `--root` and its
  LocalAppData fallback are unchanged; do not silently use that fallback for
  management registration. Resolving the launcher's broader root policy belongs
  to its owner, not this presentation-only delta.
- Existing Python lifecycle supervisor receipts use a separate Windows-specific
  PID/FILETIME/revision/session contract. They are not consumed here and are not
  interchangeable with the process-facts display target. A cross-language owner
  adapter requires an accepted versioned ownership/lease contract; none is chosen.
- Menu wiring, observation scheduling, real process acceptance,
  packaged dependency checks and management interaction acceptance remain later
  work. Keep launcher optional for ordinary BYOND gameplay. This view introduces
  no player login/Social SDK gate and no server authority or inventory path.
- `Civ13.Launcher.csproj` gets additive source/reference entries only; coordinate
  those entries with the launcher owners' private patches before integration.
  No private source was read or overwritten. Frozen #3354 is not amended/rebased.

## Focused offline check

Use the existing SDK/targeting pack with child-only certificate auto-generation,
telemetry, global-tools PATH updates and workload notifications disabled. Restore
with this fixture's cleared NuGet.Config, then run only
`tests/ManagementPresentation/ManagementPresentation.csproj`. Do not invoke the
launcher Main or the broader native updater test runner as a substitute.
