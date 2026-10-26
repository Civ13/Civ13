# Private host/channel preparation

This unpublished slice adds concrete bounded stream handling, an injected
process-lifecycle owner and a native pipe-loop owner on top of the reviewed
version-one transport/native core. Production Main and all game/server code stay
unchanged. No process, stream, OS pipe, listener, DLL, credentials or account flow
is opened by constructing these components. Tests use fake streams/process leases
and in-memory native I/O. Concrete OS spawning and pipe adapters are not supplied.

## Managed lifecycle

`CompanionProcessHost` starts disabled. Enabling does not launch anything; Begin
is an explicit request through the injected factory. Only one startup/child may
exist at a time. Repeated Begin calls coalesce by refusing another request. A
fresh nonempty launch ticket is required and matched against the returned lease;
wire version must be one. The ticket fences factory results, not authentication.
Exclusive private-pipe/child ownership must be established by the OS provider;
the existing exact Ready/profile validation remains mandatory.

An accepted lease exposes its channel to a separately owned transport/pump. It
does not mean that SDK negotiation or presence succeeded. The host itself never
sends Hello or publishes anything. Host methods belong to one construction thread.
The provider's asynchronous completion may occur elsewhere; adoption/cleanup is
performed only by explicit Pump calls. No timer, background worker or global
process enumeration is created by the controller.

Startup times out at three monotonic seconds. Cancellation, timeout and opt-out
invalidate the request but retain its task until it settles. A late child is
closed, never exposed. Once a provider creates a child, it must return the owned
lease even after cancellation, or complete all partial cleanup before faulting.
It must never throw away a live child and leave the controller without its lease.

Stop requests cooperative cleanup once. After 750ms, it may request termination
once through the exact owned lease, never a caller-selected PID. A child already
known exited is not terminated again. Reconnect is an explicit new Begin and is
refused until both child exit and all I/O settlement are confirmed and the old
lease is disposed. An uncertain/throwing dispose is attempted once and retains
quarantine instead of replaying it. Clock reversal immediately quarantines work.
No automatic relaunch, shared channel reuse or overlapping abandoned startup is
allowed. Exceptions become bounded failure enums; raw exceptions/peer data are
not placed in snapshots or logs.

The application must retain and independently pump the host until IsSettled,
including after opt-out. Stop is prompt and is not a cleanup acknowledgement.
Optional cleanup must never be awaited as a game admission/exit prerequisite.
Actual worker lifetime/OS provider integration requires review before wiring.

## Managed stream channel

`BoundedStreamCompanionChannel` owns two already-created, exclusive, vetted
asynchronous streams. It cannot turn a synchronous/blocking Stream implementation
into asynchronous I/O, prove pipe provenance, or bound a blocking Dispose. The
future provider must guarantee prompt asynchronous admission/cancellation/close
and must not supply a buffered or network stream. No source here opens one.

There is one fixed 276-byte input buffer, one output buffer, at most one pending
read and one pending write. Polling an idle read does not create additional reads
or continuations. Input fragments drain before the next read; EOF, invalid counts
and faults close the channel. Outgoing frames are validated through the existing
CompanionWire header/schema bounds before any write. Caller mutations cannot
change an admitted frame. Backpressure returns false before attempting any I/O.

True means full-frame local admission, not delivery. An I/O attempt that fails
synchronously still returns true and closes, preventing ambiguous partial writes
from being retried. Asynchronous errors, clock reversal or a write observed at
or after 250ms close without replay. Even an already completed write is refused
if first observed after that budget; this conservative deadline can degrade
optional presence when pumping stalls. It cannot gate manual joining.

Closed and settled are distinct. Cancellation/disposal does not assert that
pending I/O stopped. A late operation retains its old buffer and its fault is
observed; a new channel never reuses those buffers. IsSettled is required in the
process lease's resource proof before reconnect. A throwing stream close or
cancellation keeps quiescence unproven and is not
retried automatically. Providers must not start untracked operations before
throwing; IsSettled covers returned tasks and is not independent OS-handle proof.
Native Clear/Stop remain best effort: closing during asynchronous Clear may
cancel it, so EOF/lease cleanup
and actual SDK runtime acceptance remain separate obligations.

## Native loop

`Host` owns an existing Peer over an injected `PrivatePipeIo`. Each step first
checks peer deadlines, then performs at most 16 reads and one bounded write
admission/poll. Wrong role/version/profile, malformed counts, EOF, cancellation,
exceptions and backpressure close the same peer and I/O once. No received Pulse
can revive a lease already expired at the start of a step.

Output remains owned by Peer while I/O is pending. Ready is acknowledged only
when write_state reports written; a proactive Publish before then is rejected.
A pending write observed at 250ms closes even if pulses keep arriving or the
write is reported complete late. Clear can discard an undelivered Result, and
late callbacks/output cannot revive the closed host. The native I/O provider
must copy at admission, retain bounded storage until cancellation/completion,
and keep SDK pumping independent of physical I/O. No OS implementation or
production executable entry point is supplied by this loop.

## Evidence and remaining gates

The managed runner retains all existing discovery/status/DNS/preparation/manual
fallback tests, then covers disabled startup, repeated launch, wrong tickets and
wire versions/profiles, late starts, cancellation/timeout, exceptional shutdown,
child/channel failure, clock reversal and reconnect after I/O quiescence. Native
host tests cover fragmented input, read budgets, Ready delivery, stuck/failed
writes, expiry before input, Clear/Stop/EOF and late results with fake backends.

These are executable contracts, not physical process/pipe isolation or vendor
SDK acceptance. Root must review the factory/lease obligations and the explicit
250ms/750ms/3s budgets before concrete OS adapters/startup composition. Vendor
loading/linking, live authentication/presence, licensing/distribution, installed
launcher changes and server/game actions remain disabled or outside this slice.
