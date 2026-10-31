# Proposed client-driven scene and receipt for #3322

Source-only preparation. Fixture-scoped source wiring now exists in
`connected_scene.dm`, `prepare_connected_scene.py` and
`connected_notice_observer.js`. It is disabled in the production DME and CI,
uncompiled and unrun. No connected acceptance receipt exists. The direct calls in
`connected_entry_contract.dm` are useful proc/screen assertions with a client,
but cannot establish client input dispatch or rendered notices. Their result is
explicitly `direct_proc_only` and `connected_acceptance = FALSE`.

## Scene ownership and two independent hand cases

An admitted scene must name its exact reviewed commit, isolated process/client
identities, exact base `/mob/living/human` body, capture/observer owner, resources
and reserved scratch bounds. A real matching client must control that body.
Reserve two distinct adjacent fresh water sites, one for each hand, plus the
table/paddle targets and clean output sites. Create and record fresh owned water
per hand. Never clear/reuse the first hand's water/output to make the second pass.
Record both preconditions as zero rotten flax and each postcondition as exactly
two. Preserve those independent outputs as evidence until authorized cleanup.

Use actual paid two-flax input per hand. The user performs normal client actions
to pick up and tie it, click the fresh water while holding the bundle, drag a
held weapon onto the adjacent table (success and nodrop refusal), and activate
the normal defibrillator UI/interaction to return held linked paddles. Preserve
all three original 100-ds waits. No scene controller may invoke afterattack,
MouseDrop_T, reattach_paddles or soak to satisfy a client-driven case. A scripted
server proc, direct connected-proc helper, placed bundle click, synthetic input
receipt, mocked transport or substituted success result is not that action.

## Minimal receipt, produced only from actual observations

The prepared scene records the documented native `/client/Click` and
`/client/MouseDrop` callbacks and forwards their original arguments with `..()`.
Generated copies instrument production bundle creation, afterattack, actual
do_after entry/exit, table MouseDrop_T, paddle return and the real chat wrapper.
No scene procedure invokes a target's gameplay handler to satisfy an input.
The scoped browser observer watches newly added production chat DOM nodes after
two animation frames and sends a matching, visible, token-bound notice report.
It does not inject a message, create an expected notice or verify pixels.
Those reports remain client-reported evidence requiring independent source,
log and actual capture review. Callback signatures follow the
[BYOND client mouse-event reference](https://www.byond.com/docs/ref/skinparams.html).

The preparer only writes owned source and a manifest; it has no compiler, daemon
or client launch path. Its DME adds the fixture compile flag, retains production
include order, removes maps/startup and supplies bootstrap-only adapters for
preferences, connection/login and nomads spawn. It constructs an exact base
human with the real constructor/organs; inventory, drop, hand/HUD, click and wait
bodies remain production code. Native activation additionally checks explicit
scene parameters and the reviewed commit. These flags are not execution authority.

The scene identifies fresh per-hand water, paid raw/bundled flax, table tools and
linked paddles by names/refs. It waits for a real pinned loopback client and then
requires ordinary user clicks/drags. Append-only `connected-events.jsonl` and
`connected-state.jsonl` correlate inputs, dispatch, actual hand/screen snapshots,
three original waits, output and the DOM report. The terminal observation state
is `observations_complete_pending_capture_review`; `acceptance_complete` and
`rendered_pixels_verified` never become TRUE. Without a real client it remains
waiting. Every scene/renderer behavior is still unvalidated natively.

Every receipt contains:

| Field | Required evidence |
| --- | --- |
| Identity | Exact commit and input hashes; scene ID; process/client/body identities; exact body type and client ownership; reviewed observer/capture version. |
| Hand and water | Hand, fresh owned turf reference/coordinates, creation/ownership receipt, distinct site ID, zero pre-output and exactly two post-output. |
| Client input | Actual client input kind and target, unique input event ID, monotonic timestamp and client/body identity from the native input observer. |
| Dispatch | Correlated production handler entry with the same scene/client/body/target and input event ID, or a documented unambiguous correlation spanning timestamps/frames. Direct proc invocation must be false. |
| HUD and wait | Before/after hand slots, actual client.screen membership, bundle identity/location, wait entry after removal, original delay and three completions. Correlate HUD observations and capture frames to the input/dispatch record. |
| Table | Separate correlated client drag/dispatch/HUD records for success and refusal, proving destination or retained hand ownership. |
| Paddle notice | Correlated actual client activation/dispatch, linked paddle/base identity, hand/screen cleanup, and a real rendered notice in a capture frame/time range. Record observed notice text from that capture; no placeholder or synthetic chat transport. |
| Files | Relative artifact paths, byte sizes and SHA-256 hashes for observer logs and genuine capture; timing/frame mapping, result, errors, limits, exit/cleanup receipts and any gaps. |

Input, dispatch, HUD and rendered notice must belong to the same action and
body/client; nearby unrelated messages or uncorrelated frames are insufficient.
Both hand cases and both table outcomes need independent event correlations.
Keep aborted and partial cases with their actual state instead of filling absent
observations with TRUE, expected text, placeholders or a prior capture.

Receipt validation can check structure, hashes and correlations. It cannot prove
that a file depicts a genuine client action or that an observation is truthful.
Independent review must inspect the source observer and actual capture/logs.
Missing input delivery, notice rendering, source identity or correlation keeps
connected acceptance incomplete. Direct-proc and headless receipts remain
separate evidence even if their underlying state assertions pass.
