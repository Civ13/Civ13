# Inactive Windows process and pipe provider

This source continuation supplies the concrete parent-side Windows provider for
the private host contracts. It compiles with .NET 8 and is tested through an
injected platform. It does not start a helper or create OS pipes during tests.
Production Main, installed launcher files and normal BYOND joining are unchanged.

## Activation boundary

The public WindowsCompanionFactory constructor is always inactive. Its internal
enabled constructor exists for injected tests; the concrete Windows platform has
a second fixed-off source gate before filesystem inspection, pipe construction
or P/Invoke. There is no environment variable, CLI switch, config setting or
production startup path that enables either gate. These are development holds,
not security boundaries against code deliberately changing the implementation.
Removing them requires root review and separate activation authorization.

## Concrete implementation

The executable specification requires a local absolute Windows .exe path and a
SHA256 identity. Verification refuses reparse components, checks the hash and
x64 PE header, and retains a read handle that denies write/delete sharing through
process creation. This is an image lock/check, not a signature or complete proof
against malicious changes to the approved installation directory. Installation
directory integrity remains an activation prerequisite.

The provider creates two single-instance, current-user-only, asynchronous local
pipe pairs, connects both client ends in the parent, then verifies their client/
server process ownership against its own process. Names are per-attempt and never
passed to the child or logged. Server handles must be non-inheritable; only the
child input, output and stderr-discard handles enter an explicit inheritance list.
No network endpoint is configurable. Physical Windows pipe access/cancellation
and remote access refusal still require separately authorized OS acceptance;
the mock tests do not establish those properties.

The child is created suspended without a window. An unnamed owned job sets
kill-on-close and a one-process limit, without breakaway. The owned child enters
that job before the primary thread may resume, with cancellation checked on both
sides of containment. The parent releases duplicate child pipe ends afterward.
Stderr goes to NUL rather than collecting SDK logs or contaminating stdout frames.

CreateProcess receives an explicit application path and a fixed argument layout:
`--social-peer-v1 provider port application-id`. All values come from the existing
validated profile. The application ID is public host configuration; no default
identity, launch nonce or credential is placed in arguments. A strict environment
block contains only SystemRoot, TEMP, TMP and WINDIR. Parent PATH, bot/SDK tokens
and arbitrary environment variables are not inherited. A future native entry
point must implement this argument contract before activation.

The implementation uses the documented
[inherited handle list](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-updateprocthreadattribute)
and [owned job](https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects)
mechanisms. It does not enumerate processes, discover PIDs, attach to a game,
elevate, change global security/network settings or modify an existing job.
Exit/termination uses only the exact process handle returned by this attempt.

## Failure and lifetime

Image inspection and OS startup run through one bounded-admission worker request,
outside the SDK/UI pump. The host's existing three-second cancellation governs
startup; no additional automatic retry or overlapping request is admitted.
The concrete pipe implementation retains partial ownership even after cancelled
connection. No child is hidden by a post-creation containment/resume failure:
the factory returns its closed cleanup lease unless exit and cleanup are already
proven complete. Before-child faults release admission only after owned cleanup.

The lease closes pipes cooperatively, requests termination once, and retains the
factory claim until process exit, I/O settlement and handle close are confirmed.
Unknown image/pipe/process close or termination outcomes stay quarantined rather
than being retried. It uses BoundedStreamCompanionChannel and the existing host's
250ms write / 750ms soft-stop budgets. No cleanup wait gates gameplay.

## Test scope and remaining work

The injected suite compiles the actual Windows provider source and verifies
disabled entry points, x64 interop layouts, executable/argument/environment
bounds, startup stage order, repeated launch, cancellation around pipe creation
and resume, containment failure, owned-child retention, uncertain cleanup,
framing and reconnect. Every OS-stage double is in memory. No real process,
pipe, job, filesystem image verification or vendor DLL operation is exercised.
The ordinary companion CI uses installed .NET/MSVC tools without installers or
SDK downloads; managed tests keep both real activation gates off.

This is the concrete parent-side provider, not a runnable production companion.
The native Windows endpoint I/O adapter/entry point, vendor linking/loading,
actual OS identity/containment/cancellation acceptance, DLL search policy,
licensing/distribution, live presence and startup composition remain separate
gates. Account permissions, authentication, provisional accounts, chat/voice,
server state and ordinary BYOND access are untouched.
