# Lobby Join verification

The typed `Join` command is available on lobby mobs in the Lobby verb category.
Enter `Join` in the BYOND command bar. Direct-spawn modes use their usual join
handler; modes with role lists use a native BYOND role prompt. Cancel the prompt
to remain in the lobby. This source change requires a rebuilt server before use.

Both the lobby button and typed command share the existing join/admission and
SelectedJob bodies. Native selection rebuilds the same filtered role list after
its wait. A request retains its own client, map identity and game ID, rejects
concurrent requests, and clears transient state after completion or exceptions.
Role confirmations refresh eligibility before campaign quota changes. Existing
admin respawn bypasses still require an explicit confirmation and current admin
rights. Existing campaign faction matching is shared with eligibility refresh.

The original delayed-role replacement/refund path is preserved. The inherited
scheduled delayed-spawn callback is not redesigned here; these source checks do
not prove its completion, disconnect, hold or cancellation behavior.

## Offline checks

Run with a verified Python interpreter:

```text
<python> -m unittest discover -s tests/lobby_join -p test_source.py
```

Four source checks preserve the admission body and the four menu filter bodies
against immutable baseline `41e2d02fe1f9130e0987aee0efd2eba0ca7b3bf1`, normalizing
only the documented factoring, native title collection and prompt wrappers.
They also check title/link branch alignment, shared routing, owner cleanup and
native selection re-entry. They do not compile or run BYOND and do not establish
connected-client interaction, campaign accounting, delayed spawning or readiness.

## Bounded native control fixture

`run.py --byond-bin <516.1681-bin>` prepares and runs the control fixture in
temporary storage, preserving logs on failure, with a 45-second timeout per
compiler/runtime process. The focused CI guard selects this suite when first
introduced on this PR or when extensive regressions are explicitly requested.
Local native investigations can use the reviewed retained-handle Job wrapper
for additional process, memory and socket observations.

`prepare.py --output <new-evidence-directory>` stages sources and a SHA-256
manifest only. It launches no processes. Compile its generated `control.dme`
with pinned BYOND 516.1681, then run `control.dmb` from that isolated directory
with a relative log path and finite process/resource limits. Require compiler
zero errors/warnings, runtime exit zero, no native diagnostics, `result.json`
with `pass: true`, all named assertions and a closed native port. Preserve
failure output and do not retry automatically under a larger memory limit.

The fixture extracts production request ownership, identity checks, mode routing,
prompt wrappers, fresh-menu validation and native selector control. It injects
actor/client references, native prompt responses and small map/job collaborators.
It exercises cancellation, duplicate re-entry, exceptions, actor/map/round
changes, holds, ban/trait changes, role removal, rights revocation and campaign
policy/membership changes. Generated unsafe identity and role-confirmation
controls must demonstrate acceptance of stale responses. It does not execute
the full production admission/SelectedJob bodies or real delayed-spawn callbacks.
Those limits cannot be replaced by the fixture passing.

## Required remaining verification

Compile the complete changed checkout with BYOND 516.1681 and zero warnings.
Use isolated temporary state and a reviewed bounded fixture for mode routing,
ordinary and native selection, cancellation, duplicate requests, exception
cleanup, disconnect/client transfer, map/game-ID changes during prompts, restart
holds, revoked admin rights, changed campaign policy, changed job/faction bans
and quotas. Check ordinary button role switching and delayed reservation refunds.
Use a genuine connected client to verify the command/prompt when uncertainty
remains. No running recovery server or original save is a test fixture.

Changelog: Added a lobby Join command with native role prompts and shared admission checks.
