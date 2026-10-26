# Native companion core and SDK adapter

This slice implements a C++20 peer for the existing version-one managed wire
contract and a concrete Discord Social SDK C-ABI backend. It is a library/core,
not a runnable production companion host. No process/pipe creation, vendor DLL
loader, application discovery, GUI or launcher startup composition is supplied.
The launcher remains optional and normal BYOND/DreamSeeker joining is unchanged.
There are no game/server changes, authentication, tokens, provisional accounts,
invites, voice, microphone calls, new OAuth scopes or application-setting changes.

## Native boundary

`Peer` requires an independently configured expected profile. Never derive that
profile from untrusted Hello bytes. It validates the same two catalog providers
and ports 1714/1715, a canonical nonzero uint64 application string, and an exact
Hello payload match before creating any SDK client. There is no default app ID;
each host must provide its own identity. It then echoes Ready. Publish is refused
until the host acknowledges delivery of Ready. All fields remain display data.

The parser retains one fixed 276-byte buffer and accepts at most 276 bytes per
feed, with a maximum 256-byte payload and strict role, version, reserved-byte,
length and increasing-ID checks. Details and State are each 1-96 bytes, strict
UTF-8, without C0/C1 controls. There is one pending SDK publication and one bounded
outgoing frame. The future host must copy/send that whole frame or close, then
acknowledge it exactly once. It must not retain output references across calls.
No unbounded receive/write queue, reconnect or partial-frame replay is provided.

The owner injects nonnegative monotonic milliseconds. Initial negotiation expires
at three seconds; after Hello, Pulse refreshes a five-second lease. Clock reversal,
EOF (host calls close), malformed input, output backpressure, Stop and lease expiry
terminate the session and discard output. Clear during an SDK publication or an
undelivered Result also terminates it, invalidating late results. A prepublication
Clear can retain negotiation without publishing discarded managed activity.

`DiscordBackend` calls only Client Init/SetApplicationId, Activity Init/SetType/
SetDetails/SetState, UpdateRichPresence, global RunCallbacks, ClearRichPresence
and the matching Drop functions. It does not call Connect or authorize. Activity
and callback-result ownership follow the supplied SDK's generated C++ wrapper.
SDK-owned callback userdata is deleted only by its free callback, never by Clear,
an ordinary completion or managed cancellation. A weak session/epoch fence drops
late results; callback state is mutex-protected, including off-owner free calls.
One shared runtime lease survives teardown until deferred userdata is freed, so
another native SDK client cannot claim the global pump early. There is no global
ResetCallbacks call and no automatic retry. Freed-without-result maps unavailable.

All API operations and Peer methods belong to the construction thread. Wrong
thread feed/tick/publish/pump throws before SDK work. Wrong-thread terminal cleanup
is a fail-fast programming error; the future host must destroy both objects on
their owner. Declare the backend before its Peer so it outlives Peer teardown.
Clear is best effort; neither its void SDK call nor Result success proves remote
Discord UI state. The host's pump must remain independent of console/game input.

## Bounded offline build

Use already installed x64 MSVC tools and PowerShell. Nothing is installed or
downloaded; each owned compiler/test process has a 45-second limit.

```powershell
./Build-Offline.ps1
./Build-Offline.ps1 -SdkInclude '<external official SDK include directory>'
```

The first command compiles/runs the original parser/lifecycle tests with a fake
Backend and requires no vendor files. The optional second command also compiles
the real `discord_backend.cpp` against external `cdiscord.h` and links **original
fake C functions** from sdk_tests.cpp. It never links an SDK import library or
loads the vendor DLL. It exercises the actual adapter's activity/result/userdata
ownership, duplicate/late completion, deferred free, single-runtime lease,
unavailable/failure mapping, cancellation and failure paths. Generated files stay
under ignored build/. CI runs only the vendor-free first command and retains logs,
not executables. Header-specific binding acceptance remains separately reported.

The inspected input is official SDK 1.10.19337, whose release is still listed in
the [official release notes](https://discord.com/developers/docs/social-sdk/release_notes.html).
The supplied archive SHA256 is
`d784097504685953849cc2842561d8a8013326fe0b8df65a1de63ddefde62045`;
the cdiscord.h SHA256 is
`86ef9280ab8432493952bb974bd18c5a25d7725011393b5dba05162bcfdb3371`.
No headers, libraries, samples, notices or other SDK contents are vendored here.

## Remaining gates

This is tested native source, not live Social SDK acceptance. Production linking,
DLL provenance/loading, real callback/free timing, process containment, private
inherited-pipe ownership and the managed channel/process adapter need review and
implementation before startup can be connected. A crashed/unavailable companion
must degrade only social features and must never prevent ordinary gameplay.

The ZIP's License-Notices.txt contains third-party notices, not a standalone
Discord license grant. The [Social SDK terms](https://support-dev.discord.com/hc/en-us/articles/30225844245271-Discord-Social-SDK-Terms)
govern SDK use/distribution. Existing owner acceptance, integration/distribution
rights and compatibility with this repository's license must be resolved before
shipping SDK-linked artifacts. No agreement was accepted by this source change;
no SDK binaries are copied, linked, uploaded or released by its build/CI. A later
live RPC check requires separate authorization even though this backend uses no
OAuth flow. Communications eligibility does not follow from presence capability.
