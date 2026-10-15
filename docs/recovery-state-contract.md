# Recovery metadata contract

The current tested recovery baseline is PR #3159 at
`9d8b33305be95396912402dc1a4d0a4962d4eaa4`. Its Gaia save/restart cycle
preserved character control, HUD, game ID, active phase and the advancing round
clock. It did not preserve the season: Summer became Spring. This document
describes the next source implementation, not accepted whole-world recovery.

## Explicit state inventory

`code/modules/persistence/durable_contract.dm` defines 131 map fields with
explicit value policies. These include epoch/research gates, partial faction
research and forge payments, director/leader identities, factions, companies,
religions, registrations, warrants, marketplace records, randomized berry
effects, mode flags and victory state. No blanket `map.vars` export is used.
Field access is restricted to this inventory. Runtime worker flags, process
objects, generated symbol icons and editor sessions are excluded.

Map clock values have distinct policies. Victory deadlines store a remaining
delay with a separate disabled sentinel. Artillery cooldowns store elapsed
time since their origin. Realtime deadlines store remaining delays. Restoring
these values must rebase them against the new runtime's corresponding clock.
Era research thresholds are durations; their caller must use recovered elapsed
round time instead of the new process's `world.time`.

The graph codec preserves nested associative lists, aliases, cycles, literal
marker strings, paths, turf/area references and existing saved atoms. A faction
leader or director resolves to the original generation's `(level, entry, type)`
identity after all levels import. Metadata decoding constructs no atoms and
cannot make another copy of that leader. Unsupported values and references to
unsaved/session objects fail export rather than disappearing silently.

Preflight checks graph shape, bounded node/edge counts, supported value kinds,
coordinates, entry types and generation. The integration must also validate the
root field inventory and world-entry reachability before `ClearMap`. A decoded
field inventory check after destructive loading is insufficient.

## Callback lifecycle

`durable_timers.dm` supplies named callbacks with portable remaining delays.
Repeated restoration invalidates old sleepers before scheduling replacements.
Only registered callback names can be resumed; one name has at most one pending
callback. The queue defers callbacks while persistence owns the save/load lock.
Timer cancellation identities are runtime state and do not represent historical
season progress.

Integration must replace hidden season, terrain-phase, wind, religion,
autoresearch and weather-event sleepers. Season capture must reject an active
terrain transition instead of combining partially transformed terrain with a
completed-transition claim. Time-of-day restoration must restore phase progress
and rebuild lighting without advancing to another phase. Save/restart must not
execute fresh round setup, equipment grants or constructor world generation.

## Outstanding domains and supported maps

The explicit map-field inventory does not by itself cover global season,
historical season changes, day/night phase/progress, pollution/radiation, mutable
area climate, weather scheduler policy, pending event stages, active banner
pixels or subtype-specific calendars and progression. These need explicit root
records and validation as part of integration. Banner draft pixels and displayed
pixels can differ and must be kept separately.

Gaia and Europe declare no additional subtype data fields, but still need all
shared domains and callback acceptance. Other maps have extra state and timers,
including wet/dry seasons, fixed winter, eruptions, supply drops, calendars,
diplomacy and campaign/match progress. They remain explicitly unaccepted. A
successful Gaia or Europe run cannot establish all-map correctness.

Legacy map-only and round-v1 saves remain readable. Missing legacy facts cannot
be reconstructed from defaults or relabeled as historical state. New metadata
must be versioned, generation-bound and fully preflighted; existing protected
save generations remain unchanged during development.

## Verification

Run the source inventory check with a verified Python interpreter:

```
tests/world_save/check-durable-inventory.py
```

`run-durable-graph.py --prepare-only` stages the actual production codec and
native fixture without launching BYOND. With a native lease, use
`--byond-bin <516.1681-bin>` and repeat with `--negative-control generation`,
`alias` and `binding`. Add `--contracts` for field/timer checks, or use its
`clock`, `omission` and `timer` negative controls. Native compilation,
successful positive execution and
expected assertion failures are separate results. Preparation alone is not a
native pass. Broader metadata/timer omission and clock-shift controls, integrated
full-game compilation, full Gaia/Europe cycles, source review and exact-head CI
are still required before accepting the new recovery format.

The isolated graph positive passed 16 checks on BYOND 516.1681, and generation,
alias and binding controls caught their intended failures. Each build had zero
errors and warnings. The separate field/timer positive passed 32 checks; clock,
omission and timer controls caught their exact expected assertion failures.
The runner rejects unrelated failures and unexpected caught exceptions.
The new helpers are included in the environment but are not yet
called by `Save_World` or recovery; they cannot fix the season gap until that
integration and its acceptance are complete.
