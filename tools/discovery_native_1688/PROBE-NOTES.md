# Discovery probe integration notes

Inactive source preparation only. No compiler/runtime has been launched and no
native result is claimed. Exact target is published head
`9c54e1b57097035d51c35e4ea9cb755e7aa12a92` with its complete resource closure.

## Invocations and narrow adapters

`probe.dm` uses real berry constructors and real reagent registration, calls
production `smell_description`, `smell_for` and `secondary_attack_self`, and tests
actual learned records. It does not synthesize a smell descriptor or call the
berry-learning hook as its observation path. The isolated fixture disables
normal map/human startup, as in the retained winter fixture. Map randomized rows
are deliberately set to known fixture data; this is not live-map generation.

Production smell's exact `to_chat(user, ... html_encode(observation) ...)` call
must be replaced only at the sink with `discovery_capture_chat`. The capture
records the actor, exact output and pre-learning count. Other calls are untouched.
Production `show_memory` needs its exact three-line client-presence block omitted
and its final `recipient << browse(replacetext(...), options)` replaced with
`discovery_capture_notes(recipient, replacetext(...))`. Preserve the expression,
ownership guard and HTML construction. This makes wrong-owner and escaping
failures observable headlessly without claiming native browser behavior.

`GLOB.nanomanager = new /datum/nanomanager` permits actual `mind.transfer_to`
with an empty native manager. No open NanoUI or client is fabricated. The fixture creates an otherwise idle native ticker (no New hook is declared in
its controller/datum ancestors), never calls pregame, and uses actual
`H.mind_initialize()` both for new minds and existing-mind preservation. All living
fixture minds remain inactive, so key/client transfer is not exercised.

## Persistence scope

`discovery-save.dm` learns through the real berry action, preserves private notes,
then detaches current/original body references deliberately before exporting
actual `/datum/mind` instances through `BuildVarDirectory` and typed list graph
encoding. `Load_Entry` restores those graphs in the baseline same-process
round-trip and, separately, the controller's fresh writer/reader process phases.
The writer uses `discovery-mind.sav` and `discovery-mind-entries.json`; the reader
must consume exactly those retained artifacts from the matching writer phase.
No replacement serializer, rehydrated hardcoded knowledge or fixture-specific
save-variable allowlist is used.

This does not accept full-world metadata restoration, human physiology/body
reconstruction, authentication/account reclaim, live reconnect, lobby respawn,
real-client verb dispatch or actual Notes browser markup. Fresh-mind isolation is
an actual new mind versus transferred existing mind, not a faked client respawn.

## Ordered assertion inventory

All labels are static. `discovery_setup`: 2 checks. In roundtrip,
`discovery_fixture` is followed by its `discovery_limits` call, then
`discovery_mind_writer`, then `discovery_mind_reader`. Expected totals:
roundtrip 43, writer 4, reader 11. No checks live inside iteration bodies; loops
aggregate edge/count conditions into one static assertion afterward.
`expected-assertions.json` uses the winter schema and binds both probe sources.

## Causal controls

- `smell`: remove production `record_smell_discovery(user, observation)` call.
  Named failure: `actual smell creates one learned observation`.
- `escape`: replace only `html_encode(record["label"])` with
  `record["label"]` in production mind renderer.
  Named failure: `production Notes construction escapes the learned berry label`.
- `capacity`: remove only ` || learned_discoveries.len >= 256` from production
  learner's duplicate/overall-cap check. Named failure:
  `overall capacity rejects the next observation without eviction`.
- `persistence`: add `key == "learned_discoveries" ||` to production generic
  `persistence_runtime_var` expression immediately before the existing
  `key == "persistence_export_frame" || key == "weak_reference"` terms.
  Named failure: `reader preserves the production-saved learned discovery`.

Each control must fail at its precise label with all earlier assertions passing;
compiler error, runtime, timeout or unrelated assertion is not a valid control.
Wrapper ready/go/result protocol and zero-port enforcement match the retained
controller contract; only discovery names, fixed target tokens and phase calls
change. Real connected-client acceptance remains a separate, unopened scope.
