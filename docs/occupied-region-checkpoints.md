# Persistence: four-hour occupied-region checkpoints

Status: implementation design; this document does not change save behavior.

## Policy

Keep a successful save no more than four hours old while a Persistence region is occupied and in normal play. Start ahead of the deadline to leave time for export, validation, and a retry. A blocked or failed save can miss the target; report that to operators rather than bypassing a save guard or forcing a restart. The target is per region, not shared by all worlds in a shard group.

Keep the existing empty-region catch-up, save votes, manual saves, idle host request, and empty-only maintenance reboot. Use the same non-host player definition as the current save loop. Do not add a new externally accessible save action.

## Implementation

- Extend the occupied branch of [the persistence loop](../code/world.dm#L554-L615). Keep its existing play/empty bookkeeping and keep the existing empty deadline separate. Start the occupied checkpoint only in a playable Persistence world with saving enabled.
- Calculate age from [the latest completed generation](../code/modules/persistence/last_save_status.dm), not from the time of the last attempt. Use a validated completion timestamp; a new world without one uses its first playable timestamp. A fresh manual, vote, or idle save satisfies the deadline too. A restart or brief disconnect must not make a stale completed generation appear fresh.
- Use the existing save operation and online pacing. Recheck occupancy, eligibility, admission, and the latest completed generation immediately before starting; do not take another capture while a save, restore, handover, or maintenance operation is running. Do not bypass the metadata transition and restart holds. Verify the normal online save path with the moving-save setting in both states before enabling this scheduler for that path.
- Plan an initial 20-to-30-minute lead with a stable per-region offset inside that window; size it using isolated save-duration measurements. A region already overdue should attempt at its next safe opportunity. Staggering reduces coincident starts but does not serialize independently hosted worlds.
- Back off after a refusal or unsuccessful completion, including exceptions; do not retry on every scheduler tick. Backoff does not move the four-hour deadline. Clear overdue state only when a completed generation advances. Warn players before a scheduled checkpoint and report overdue/blocked state to admins without chat or log spam. Do not expose save internals to player chat.

## Conditional update and restart

Each four-hour cycle is a **save, not a scheduled reboot**. Ask the host's
[staged-build workflow](../scripts/gaia-host/gaia_host.py) whether a different,
validated build is ready for this region, or whether a separately authorized
maintenance restart is due. A changed upstream SHA alone, a staging failure,
and an unavailable host check are not reasons to restart.

- Current build, unknown status, or no restart required: save in place.
- Eligible staged build: check the existing region rollout policy, restart/transfer holds, and configured warning or deferral rules. Use the existing supervised save and handover or graceful restart path. Announce the interruption and recheck eligibility after the warning. Where a save-and-restart transaction can satisfy the checkpoint, do not perform two consecutive saves.
- If maintenance or rollout must wait because the region is occupied or a guard has not cleared, complete the checkpoint as a save-only cycle. Leave the staged build pending. This feature does not override an empty-only rollout policy, the existing empty-only maintenance reboot, or any veto/hold.
- Require a newly committed, validated save generation before replacing the running world; never restart on a failed or ambiguous save. Preserve the last known-good build and generation. Verify readiness and the running revision through the existing supervised transaction. On refusal or failure, follow its recovery path and report the reason; do not force-stop the region or retry in a loop.
- Keep update selection and lifecycle control with the host. Do not add a public update action or run Git/build commands in DM. Ship the scheduler and the updater integration as separate tested slices if host support is not ready.

## Acceptance before rollout

- With an injected clock, prove due/not-due boundaries, restored and unsaved world startup, independently staggered regions, host-only occupancy, reconnects, and that only a successful generation moves the deadline.
- Exercise overlap with manual/vote/idle saves, last player leaving just before dispatch, disabled saving, non-Persistence worlds, startup/maintenance/transfer holds, and repeated failure. Confirm the existing [idle host request](../code/modules/persistence/nomads_lifecycle.dm#L260-L274) still refuses while players are online and the empty-only reboot policy is unchanged.
- For the combined cycle, test current/running revision, a verified eligible staged revision, no ready build, failed host check, rollout held by policy or player deferral, failed save, staged revision changing during countdown, and failed restart/rollback. Assert zero restart requests for every save-only outcome and only one authorized lifecycle transaction for the eligible update.
- In an isolated cloud or GitHub-runner fixture, save a populated region with movement and ongoing region activity, restore its completed generation, and check character/world state and transfer consistency. Include interruption and failed-validation controls that preserve the last good generation. Measure wall time, tick impact, and memory headroom before tuning the lead window or enabling rollout. No live server changes are part of this PR.
