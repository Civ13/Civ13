# Per-map weather policy (draft)

Two optional author fields configure the existing randomized weather process.
Both default to null, preserving the existing timings, probability rolls and
seasonal choice lists. This is independent of season duration, season order,
game-year progression and decay counters. Weather is **not** made deterministic
or assigned the 60-minute season duration.

## Timing

`map.weather_timing` is an associative ordinary list with any of these numeric
keys, in **deciseconds**:

| Key | Existing process default | Meaning |
| --- | --- | --- |
| `mod_interval` | 3500 | Denominator of the existing intensity-modification probability |
| `change_interval` | 3500 | Denominator of the existing weather-change probability |
| `minimum_mod_delay` | 1000 | Cooldown after an admitted intensity modification |
| `minimum_change_delay` | 1000 | Existing change-branch cooldown assignment |

Every supplied value must be between 10 and 864000 (1 second to 24 hours).
Unspecified keys inherit the current process values, including restored process
values. For example, `list("change_interval" = 7000)` halves the existing change
probability. This is not a fixed 700-second interval: the process retains its
10-second sampling, modification-first branch, 25-based formula and triple change
probability during wet/extreme weather. Existing minimum-deadline checks and
special-event code stay unchanged. Applying policy does not rewrite an already
pending deadline; its delay is used when the existing branch next assigns one.

## Allowed transitions

`map.weather_transitions` maps a current identifier (`NONE`, `WET`, `EXTREME`,
`SMOG`) or fallback `ANY` to a plain ordered list of allowed target identifiers.
Example: `list("ANY" = list("NONE", "WET"), "WET" = list("NONE"))` excludes
random extremes and makes the next random selection from wet weather clear.
The current state's row takes precedence over `ANY`. If neither is supplied,
the existing seasonal selection remains unchanged. A null policy is wholly inert.

A configured row filters the existing seasonal choice list and the map's existing
`valid_weather_types` (clear weather remains universally allowed). Selection still
uses the existing random pick; there are no new weights or RNG calls. The policy
cannot introduce summer extremes or weather not in that season's pool. Desert wet
season keeps its existing restricted pool. The existing area/climate application
still decides whether precipitation appears as rain, snow or another effect.
An empty row or empty intersection explicitly **holds the current weather**;
it never substitutes clear weather or an otherwise disallowed target. `SMOG` has
an existing renderer but is absent from ordinary seasonal pools, so merely listing
it does not add smog to those pools. Unknown future event identifiers are rejected
until an implemented/reviewed source profile adds them. No executable callbacks,
arbitrary identifiers, event content or saved policy cursor are introduced.

This policy affects random selection, including the existing admin random-weather
helper. Direct `change_weather(...)` calls and special blizzard/heatwave/sandstorm
start/end logic retain their explicit behavior. It is not a replacement for those
event state machines or a way to bypass their climate rules.

## Invalid policy, reload and evidence

Unknown keys/identifiers, wrong types, out-of-range timing values, duplicate targets,
associated targets or malformed rows reject the whole policy. The automatic
weather process returns before RNG, intensity changes or deadline updates; random
selection and intensity helpers also refuse invalid policy. No partial timing
override is applied. Repair the installed map policy to resume normal scheduling.
This does not block explicit direct weather/event calls.

Fields are author policy, excluded from historical imports and absent from the
durable metadata schema. On reload, installed policy is evaluated against the
restored current weather and existing process/deadline state. Repeated policy
lookups have no side effects. No live config, map, save or server is changed here.

Offline tests project production policy validation/filtering and the weather
process's probability/cooldown prefix. Default behavior is compared against an
immutable master; climate application and direct special-event bodies are checked
unchanged. These are source/algorithm checks with Python adapters for native lists,
RNG outcomes and world time. They do not prove native timer/list behavior, rendering,
fresh-process recovery or connected-client acceptance. Native tests remain held
because the movement launch outcome is uncertain and process inventory was denied.
The user extended testing through 2026-10-25 02:27:29 UTC; that extension does not
release the native hold or change ownership/admission/resource limits. Review
balancing and run native regressions only after the parent resolves the hold and
reviews containment. Existing sealed packets are not changed by this documentation.
