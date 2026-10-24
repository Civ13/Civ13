# Configurable base season flow (draft)

`/obj/map_metadata/season_cycle` is an optional ordinary ordered list of season
identifiers. Null retains `SPRING -> SUMMER -> FALL -> WINTER -> SPRING`.
For example, `list("SPRING", "SUMMER", "WINTER")` skips Fall. A transition selects
the entry after the actual current season, wrapping at the end. Each actual
transition counts once for existing seasonal decay when requested; omitted
seasons do not charge extra age. Forced admin keep-age behavior stays unchanged.

This policy configures the shared serialized base season worker. Explicit custom
calendars on Mountain, Ice Age, Colonia and Pepelsibirsk remain unchanged and do
not consume this setting. The duration change in its separate PR is independent.

Validation requires 2-4 unique implemented identifiers, plain non-associative
entries, and the current season's presence. Empty/singleton cycles, unknown names,
duplicates, wrong value types, associations and a missing current season reject
the request before season/epoch/weather mutation, phase cancellation or completion
hooks. Rejection consumes the queued request; it does not change the climate or
pretend it ran. Fix the policy before the next request. Use the existing seasons
toggle to stop cycling, rather than a one-entry cycle. Future event identifiers
are deliberately unsupported until a named, reviewed terrain/weather profile is
implemented in source; there are no arbitrary callbacks or executable config.

The destination chooses one of the four existing terrain/announcement/weather
payloads. Those payloads and delayed phases remain unchanged. No game-year or
research progression changes are introduced. There is no saved cycle cursor:
reload uses the restored current season and installed map policy. The policy is
excluded from historical imports and absent from the durable metadata schema.
Changing installed policy to omit a restored current season intentionally holds
the next transition until an administrator repairs the policy.

Offline tests project the actual next-phase helper and verify dispatch ordering,
all destination payloads against immutable master, counted-hook wiring, lookup
idempotence, wraparound and invalid input. Existing isolated source extraction
retains the new helper/field. Native compiler/runtime, real skipped-season terrain
ecology, save/restart and graphical acceptance remain unrun under the current
native hold. Skipping/reordering seasons can change ecological balance; keep this
in draft review. This code does not change a live map, save or server.
