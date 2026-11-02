# Startup game-ready observation

This feature is disabled by default. The example configuration keeps
`webhook_game_ready 0`; it contains no endpoint or credential. Activation,
credential placement, bot forwarding and a live update require their existing
separate authorization. The existing authenticated `webhook_address` and
`webhook_key` bridge is reused.

`game_ready` means required startup initialization and the selected fresh or
restored startup have completed. An initialized lobby is included. It does not
mean a round is PLAYING, a client can connect, or an external webhook was delivered.

## Wire contract

The existing bridge receives `method=game_ready` and JSON with exactly seven
string fields, in this order:

```json
{
  "schema": "game_ready.v1",
  "event": "game_ready",
  "server": "nomads",
  "boot": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "round": "A1b-2_C",
  "generation_kind": "fresh",
  "generation": "fresh:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
}
```

The configured server key must match the receiver's currently enabled route.
This producer accepts ASCII letters, digits, underscore and hyphen, length 1-64
for server and 1-128 for round. Boot is exactly 32 lowercase hexadecimal digits
from the existing lifecycle boot session. A restored generation is exactly
`round-v2:` plus 32 lowercase hexadecimal digits; a fresh generation is
`fresh:<boot>`. Unsupported legacy/v1 identities are suppressed without rewriting
the game or save identity.

The ACK is HTTP 202 for accepted observation or 200 for an accepted duplicate,
with `X-Civ13-Game-Ready` equal to MD5 of the seven values joined by one LF,
in the order above, without a trailing LF. Header names are case-insensitive;
multiple matching header names or a different hash are rejected. The ACK means
in-memory observation only. It does not prove durable storage or external
delivery. No response body is read. The receiver owns deduplication and forwarding;
this patch contains no bot implementation.

## Startup barrier

The initial area token binds the one startup context. Required initialization is
positive only after scheduler setup returns TRUE, setup_everything returns
normally and area_startup.close completes. An exception or negative scheduler
result cannot release that latch.

A fresh decision is accepted only from the existing no-pending-startup branch,
with a canonical current game_id and no already restored world. Automatic startup
restore reserves one opaque ticket before its existing asynchronous import.
Later manual Load Map calls have no ticket. A pending restart retry can retrieve
only its original reserved ticket.

The import claims that ticket for the exact admitted load operation and storage.
It copies game_id and generation from the validated saved_round before mutation
or restore callbacks. The existing load wrapper now returns failure unless the
exact operation's finish(TRUE) returns TRUE; it does not clear another owner's
admission. The observer publishes only after that affirmative release, normal
metadata/transient/player restoration and cleared recovery/operation/dimension
holds. A restart additionally requires consumed intent and a successful
finish_player_restoration return, not its prematurely set readiness flag.
Consumption-only retries may finish the same startup without recapturing a later
save marker. Partial import failures cannot emit. Observer cleanup clears only
its own transient references; it never authorizes recovery.

Initialization and restore may complete in either order. Both latches, current
boot/server/storage/round identity and all holds are checked before queueing and
again around asynchronous delivery. Duplicate completion cannot create a second
startup payload. This code never rereads save_complete.txt.

Hooks use one fixed internal procedure lookup. Full civ13.dme explicitly includes
the producer, checked by tests. Minimal isolated persistence probes may omit this
notification module; absent observer means no notification and does not waive any
save/load admission or provide native readiness evidence.

## Delivery limits and evidence

The payload is encoded once, at most 1,024 characters. There is one outstanding
attempt, at most three attempts and a 120-second admission window, with 5- then
15-second retry delays after settled failures. Pending ownership remains held
while Export is unresolved; expiry never starts an overlapping retry. A late
settlement cannot start another attempt or count as timely local acceptance.

These are application admission limits. BYOND Export sleeps its caller and has no
documented timeout/cancellation argument. The underlying transfer and response
allocation can outlive the window; no hard transport/process/socket/memory
containment claim is made. Source-only tests inject clocks, objects and transport.
No native world, actual HTTP receiver, player, save import or live service is
launched by them.

The production barrier's complete method bodies, validation loops, ACK parser,
export helper and literal dispatcher are projected. The private model supplies
DM null/one-based associative-list behavior, numeric loops, source ternaries,
SECONDS units, typed allocation, string/list construction and timer scheduling.
The Export wait becomes a generator boundary so unresolved ownership can be
tested without a network call. This is a restricted source model, not a general
DM parser or engine proof. The shared source adapter is unchanged. Failed model
preparation and source findings are preserved in the review evidence.

Run the explicit offline suite with
`py -3 -B scripts/ci_baseline.py unit --suite game_ready --output <counts.json>`.
Compilation, native hook semantics, actual header handling and end-to-end bot
receipt remain separate acceptance items.

Official API reference:
https://www.byond.com/docs/ref/#/world/proc/Export
