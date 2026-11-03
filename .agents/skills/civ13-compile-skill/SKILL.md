---
name: civ13-compile-skill
description: Diagnose recurring Civ13 DM compilation errors and warnings in isolated BYOND fixtures, especially source-projection and harness drift. Use for Civ13 compile preflight or failed fixture builds, not general-language compilation.
---

# Civ13 fixture compile checks

Separate production defects from fixture defects before changing code. An isolated fixture is a projection of production behavior, not permission to replace that behavior with convenient stubs.

## Preflight before a native compile

- Record the source revision, fixture generator or projector, exact generated inputs, build command, and pinned BYOND version. The historical study failure below used 516.1688; use the current task's actual pin.
- Inspect applicable repository instructions and compare projected declarations, macros, type ancestry, constants, and overrides against production. Trace missing symbols to their definitions and include dependencies; do not guess values or treat project-defined fields as BYOND builtins.
- Run available offline generation, projection, syntax-oriented, and invariant checks first. Verify the projector accepts the exact final source syntax and emits the intended behavior. These checks are not a native BYOND compile.
- If hosted regression evidence is intended, follow the [PR preflight selection check](../civ13-pr-preflight/SKILL.md#verify-hosted-selection-as-well-as-local-execution). Confirm the exact event/base/head selects this fixture; a local compile cannot establish hosted execution.
- Use the authorized environment for an expensive native compile. This skill does not authorize extra services, environment changes, or external publication.

## Observed failure patterns

These historical examples suggest where to look; they do not prove the cause of a current failure without inspecting its generated source.

| Diagnostic or symptom | Check and repair |
| --- | --- |
| Duplicate declarations plus missing `moved_event` / `paper_authoring_event` | Inspect the synthetic `GLOBAL_DATUM_INIT` definition and expansion. A malformed fixture macro caused both in the study fixture. Restore declaration and initialization semantics rather than adding duplicate globals or unrelated stubs. |
| Assignment to constant `atom.loc` in fixture `/atom/proc/forceMove` | Check the receiver's static type. Use a movable-typed reference where the operation applies to a movable, handling other receivers appropriately. Preserve the real moved override and `Entered` / `Exited` dispatch. |
| Undeclared `anchored` in a mount fixture | Trace Civ13's field declaration and type ancestry. It was project-defined, not a builtin at the failing type. Restore the faithful dependency or projection rather than inventing a field on every atom. |
| Unused `caught`, `ignored`, or `e` exception locals | If the exception value is genuinely unused, use a bare `catch`. Preserve handler behavior and ensure the exact-source projector supports that syntax. Do not remove exception handling to silence the warning. |
| Unused scene locals or `old_mount` | Check whether the binding or initializer carries required behavior or assertions. Remove only genuinely unused bindings while preserving side effects and coverage. A missing use may reveal a broken projection. |
| Unqualified `OpenPort` or `port` in a global cleanup proc | Resolve the proc and variable receiver from the actual type. A tree fixture compile reported two errors and zero warnings until it used `world.OpenPort("none")` and `world.port`; it launched no daemon or client. Do not assume implicit world context. |
| Other missing production constants or variables | Find the authoritative definition and why it was omitted. Add only the minimal behaviorally faithful fixture dependency; never fabricate values or blanket-stub missing symbols. |

The historical study fixture reported 50 errors and 11 warnings; identified roots included its synthetic global macro and movement receiver, with nine unused exception bindings and two unused scene locals. An editor CI run reported 0 errors and 1 warning for unused `catch(var/exception/e)`. A mount fixture also exposed `anchored` and unused `old_mount`. A corrected study v5 compiled with 0 errors and 0 warnings, but its runtime aborted when an established loopback connection exceeded the listener-only policy. These are separate historical results, not evidence that any current fixture passes.

## Verify without weakening the test

1. Classify each root cause as production, projection or generator, harness, or uncertain. Fix the generator when generated output would otherwise be overwritten. Retain the original failure log and map cascading diagnostics to root causes.
2. Re-run offline checks on final inputs, then the authorized pinned native compile. Report exit status and exact error and warning counts; do not suppress warnings, weaken assertions, or call a nonzero-warning result warning-free.
3. Treat runtime verification separately. Compilation does not establish event dispatch, movement semantics, or timer behavior. Preserve any required real 3000-decisecond timer; do not shorten it to claim equivalent runtime coverage. Retain runtime assertions and termination evidence.
4. Preserve commands, versions, source and input identity, failure and success logs, and cleanup evidence. Confirm owned test processes and artifacts were cleaned up as required; do not terminate unrelated processes. Label passed, failed, pending, and not-run stages.

If blocked, report the exact action, target, reason, and whether access was denied, approval is pending, or the result is uncertain. Do not retry through another environment to evade a restriction.
Keep this blocker with the owned branch/PR and continue independent authorized
projection checks or source work under CODEX.md's handoff rules.
