# Tree planting native validation status

> Historical Windows attempt record. The failures below remain failures.
> Newer exact-source Linux BYOND 516.1688 checks passed on 2026-10-25; see
> [the separate Linux evidence and remaining coverage limits](tree-planting-linux-validation.md).
> That result does not satisfy or alter this Windows startup no-socket guard.

The follow-up to draft #3283 integrates master
`5528a46823ba264d934ff54b188d65b1e5ed540f`, including #3286's rack inventory and
processing-only hide fixes at `580a7399d3060c5ba38c8782da8e87411d2650ab` and the
subsequent #3281 animal changes without editing their implementation.
The grouped Atlas catalog from #3282 was regenerated through the combined
generator, preserving tree acquisition routes and processing-only hide exclusions.
This branch adds no further grouping or generator behavior and does not manually
combine generated JSON. Atlas variant, navigation and tanning checks are separate
from the blocked native tree gameplay scope below.

## Attempted Windows native evidence

All worlds were synthetic 8x4x1 fixtures with normal game/global startup disabled.
The compiler entry point is a generated DME including production sources and
`tests/tree_planting/probe.dm`. The toolchain is cached BYOND 516.1681; runtime DLL
file version is `5.0.516.1681`. OS is Windows NT `10.0.22631.0`. No production save,
live Gaia state, OpenDream process or installed runtime was modified.

The local evidence root is the task workspace's sibling `evidence/` directory,
outside the source checkout. Preserve these failed receipts and their dirty
patches; neither is a passing final-head gameplay result.

| Evidence directory | Build | Runtime result |
| --- | --- | --- |
| `native-initial-70f0c3211` | 516.1681, 0 errors/0 warnings | Uncontained initial fixture emitted six checks, then failed because its direct `del()` cleanup tripped production GC. No save/load pass. |
| `native-extended-attempt1` | 516.1681, 0 errors/0 warnings | Existing Windows Session rejected a sampled TCP listener on `127.0.0.1:56755` before fixture assertions. Owned exit accounting completed. |
| `native-extended-early-close` | 516.1681, 0 errors/0 warnings | Closing the port at the earliest production global initializer still failed the unchanged startup-socket guard. Owned exit accounting completed. |

The fixture cleanup now uses production `qdel()`. The runner uses the existing
`scripts/native_fixture.py` Session without modifying its limits, sampling,
process accounting or socket predicate. It requests loopback binding and no web
client, closes again before assertions and refuses reopening/clients. A native
engine bind before DM startup still fails. No runtime was retried after the
earlier-close variant was rejected, and no uncontained fallback was used.

The shared Session retains one-process Jobs and handles, enforces a 1920 MiB child
private-memory cap, a 6 GiB host free-memory floor and bounded phase/aggregate
deadlines. The no-socket predicate includes startup. Its observations do not
establish continuous absence of short-lived sockets between samples; a sampled
socket is always a failure. Final-head compile-only execution is recorded
separately in the PR and local receipt and launches no runtime.

## Prepared checks and remaining acceptance at the Windows attempt boundary

The bounded runner compiles once and has three sequential runtime phases:

1. Production planting debit and rejected-plot behavior, watering, a real entry
   disk round trip, restoration registration, winter pause, mature tree creation,
   ordinary seven-log yield and drought death.
2. A fresh writer exports nondefault stage/water/nutrition and 277 ticks of partial
   duration, asserting the runtime clock is absent before inserting a legacy clock
   field for the import check.
3. A fresh reader imports that file with the production loader, checks the legacy
   clock is ignored, calls `after_load` twice, then uses actual `process/obj/fire`
   dispatch to verify partial-duration resume, duplicate-service rejection,
   save/load holds and exactly one mature tree. Durations are shortened only via
   fixture-owned field assignments; production growth helpers are not replaced.

Optional generated-source controls target seed debit, runtime-clock serialization
and duration reset. They require an exact named assertion, and do not accept a
compiler error, runtime error, guard failure or timeout as control detection.
At this Windows attempt boundary, the controls and new runtime phases remained
**unrun** because of the startup guard.
Source preparation and native compilation do not validate their runtime result.

These attempts left Windows native acceptance blocked on an execution path that
satisfies its existing runtime guard. The later Linux lane separately passed its
positive native phases and all three controls; it did not change the Windows
contract. Natural scheduler cadence, controlled full-world fresh-process recovery
and genuine connected-client planting/maturation captures remain outside the
accepted synthetic Linux scope. No synthetic image is a substitute.
