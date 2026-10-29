# Persistence pointer audit - issue #3407

Audited 2026-10-29 against master `de1516089fc32a739ee04f747f48bd69d1950a53`.
The custom saver includes changed tmp vars. Only explicitly classified runtime
fields are omitted, on export and legacy import. Export does not erase live
references. Unknown and durable links retain the cross-level rejection.

| Candidate | Classification and evidence | Action |
| --- | --- | --- |
| Animal `target_obj`, `target_mob`, `pathfind_target` | Current AI search/combat/navigation state | Exclude alongside `found_path`, `moving`, `last_pathfound`, `move_gen`, `stance`, `stance_step`; imports use type defaults |
| Hostile `target` | Current AI target | Exclude only on hostile animals, with parent delegation |
| Pet `movement_target`, `flee_target` | Prey/pursuit and fleeing state in `handle_movement_target`/`handle_flee_target` | Exclude only on pets |
| Animal `following_mob` | Paid leash is consumed in `attackby` and recreated in `free_animal`; NPC speech commands also use it | Retain fail-closed pending policy below |
| NPC transaction `target`, `combat_target`, `following`, pulse/transaction `actor` | Both owner datums explicitly `should_save = FALSE` | No direct save blocker; preserve owner exclusions |
| Grab `assailant`, `affecting`, `hud` and reciprocal indexes | Entire live combat/UI graph; constructor requires user/victim | Exclude whole grab type and mob `grab_list`/`grabbed_by`; reject legacy grab type before constructing; hand/content refs encode null |
| Operating table `victim` | `check_victim` only clears it; `take_victim` moves C but never assigns this cache | No proven non-null gameplay writer; retain guard |
| Plastique `target` | `afterattack(atom/movable/target, ...)` shadows the field; `target = target` assigns the argument | No proven non-null field writer; retain guard, do not silently change armed explosive behavior |
| Stair/ladder `target` | Durable topology/cache: constructors/initialization call `find_target`; linked ladders point to another level by design | Retain fail-closed; initialization reconstruction is not a saved cross-level codec |
| Pull pair `leader`, `follower`, capability `member` | Owner datums explicitly `should_save = FALSE`; save admission resolves paired movement separately | No direct blocker from these datums; preserve admission checks |
| Ghost `following` | Ghosts are not on `ignore_types`; spectator follow can retain another level | Exclude only the follow field; do not assume all ghosts are unsaved |
| HUD action `target`, `owner`, `button` | `/datum/action` is held in `mob.actions`; it is distinct from `/datum/hud` | Exclude whole action type plus mob index; reject legacy action constructors |
| Human `laddervision` (untyped) | Client eye cache assigned by `update_laddervision` | Exclude through the existing human hook, retaining parent delegation |
| Animal `last_loc` | Turf coordinate reference, supported across levels by the existing codec | Retain |
| Animal `origin` | Spawner/sink `alive_mobs` accounting during retirement | Retain fail-closed pending ownership/accounting review |
| `pulling`/`pulledby`, `buckled`/`buckled_mob` | Physical relationships, not disposable AI targets | Retain existing movement/save admission and reciprocal release guards; do not globally exclude |

The typed inventory gate is bounded to the ten audited modules and records 28
declarations. It deliberately includes unsaved owners so losing an owner
exclusion is detectable. It does not claim repository-wide coverage; untyped
fields, collections, aliases, dynamic writes, explicit inheritance changes and
other modules remain review surfaces. See
[the regression scope](../tests/persistence_pointers/README.md).

## Repeated failures

Admitted save backend failures are counted once, including direct Save_World
calls, exceptions and false returns. Success resets the counter. Rejected/busy
requests and loads do not count. Failure 3 and every tenth failure write to the
existing world log and admin notification infrastructure. The message carries
the bounded diagnostic kind, source type/field, target type and level numbers;
it omits native lookup refs, player identities and values. Alert errors cannot
replace the export exception or strand admission. No Discord destination or
test/live message is introduced. The counter is process-local and not saved.

## Decisions and remaining work

`following_mob` needs an owner decision: preserve paid leash relationships
through stable cross-level identities (recommended), or explicitly end/refund
them at save/load boundaries. Command-follow should become a separate transient
field. Blindly discarding the shared pointer loses a paid relationship.

Stair/ladder topology needs a reviewed durable identity/restore contract, or an
explicitly proven reconstruction contract across every ladder subtype and load
order. This patch does not declare initialization alone sufficient, and it
does not implement cross-level power networks.

The policy for known transient fields is explicit omission before encoding and
before legacy decoding. There is no catch-and-drop fallback for unknown
cross-level pointers. Newly found pointers require their own classification.

Native acceptance remains separate: run the isolated full-game frog/cross-level
save/import regression only with authorization for that runner, temporary saves
and its external-effect adapters. Offline checks and compilation do not prove
native save/load behavior or a deployed fix. Keep #3407 open for the unresolved
paid-follow/topology decisions and native evidence. Vertical power connections
remain queued until #3407 is finished.
