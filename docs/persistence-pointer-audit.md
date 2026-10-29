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
| Animal `following_mob` | Paid leash is consumed in `attackby` and recreated in `free_animal`; NPC speech commands also use it | Durable: saved as-is, through the cross-level link codec when the followed atom is on another level |
| NPC transaction `target`, `combat_target`, `following`, pulse/transaction `actor` | Both owner datums explicitly `should_save = FALSE` | No direct save blocker; preserve owner exclusions |
| Grab `assailant`, `affecting`, `hud` and reciprocal indexes | Entire live combat/UI graph; constructor requires user/victim | Exclude whole grab type and mob `grab_list`/`grabbed_by`; reject legacy grab type before constructing; hand/content refs encode null |
| Operating table `victim` | `check_victim` only clears it; `take_victim` moves C but never assigns this cache | No proven non-null gameplay writer; retain guard |
| Plastique `target` | `afterattack(atom/movable/target, ...)` shadows the field; `target = target` assigns the argument | No proven non-null field writer; retain guard, do not silently change armed explosive behavior |
| Stair/ladder `target` | Durable topology/cache: constructors/initialization call `find_target`; linked ladders point to another level by design | Durable: the exact paired object is restored through the cross-level link codec |
| Pull pair `leader`, `follower`, capability `member` | Owner datums explicitly `should_save = FALSE`; save admission resolves paired movement separately | No direct blocker from these datums; preserve admission checks |
| Ghost `following` | Ghosts are not on `ignore_types`; spectator follow can retain another level | Exclude only the follow field; do not assume all ghosts are unsaved |
| HUD action `target`, `owner`, `button` | `/datum/action` is held in `mob.actions`; it is distinct from `/datum/hud` | Exclude whole action type plus mob index; reject legacy action constructors |
| Human `laddervision` (untyped) | Client eye cache assigned by `update_laddervision` | Exclude through the existing human hook, retaining parent delegation |
| Animal `last_loc` | Turf coordinate reference, supported across levels by the existing codec | Retain |
| Animal `origin` | Spawner/sink `alive_mobs` accounting during retirement | Retain fail-closed pending ownership/accounting review |
| `pulling`/`pulledby`, `buckled`/`buckled_mob` | Physical relationships, not disposable AI targets | Retain existing movement/save admission and reciprocal release guards; do not globally exclude |

Constructor-owned item `action`/`actions` and turret-control `azoom` are excluded
on export and legacy import so unsaved graph refs cannot overwrite their new
instances with null. Scopes already inherit the attachment exclusion. Restore
passes regrant held scope/gun/turret actions and regenerate generic item actions.
`mouth_covered`, `garroting` and the garrote deadline are transient; garrote
appearance is rebuilt after load. This does not reset cuffs, buckles, movement
restrictions or injury state.

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

## Cross-level links

<!-- 2026-10-29: durable leash/follow and stair/ladder links -->
A type opts a top-level field into the link codec with
`persistence_level_link_var(key)`; only `following_mob` on simple animals and
`target` on `/obj/structure/multiz` do so. Every other field keeps the per-level
`cross_level_object` rejection, and a same-level value still uses an ordinary
entry. The codec preserves the relationship exactly: it never refunds, drops or
re-derives a paid leash, command-follow or ladder pair.

- Export: when a declared field holds a movable whose turf is on another level,
  the field stores `{"kind": "level_link", "id": N}`. Row N of the optional
  `level_links` list in `round.json` records the target's own level, entry and
  exact type, bound when that level exports it (or immediately, if it already
  has). One row serves every link to the same target. A target that would not
  be saved encodes null, as an unsaved same-level entry does. A saved target
  which is never exported (`unbound_level_link`) or exported twice
  (`duplicate_level_link`) fails the save closed and is recorded in
  `last_save_reference_failure` for the repeated-failure alert.
- Preflight: `read_round_state` and `validate_world_save` check every row's
  shape, that each target entry has the recorded type in the same generation
  and is reachable from a turf, and that every link value names a row. Links
  are only valid as top-level fields; nested values are rejected.
- Import: link fields are deferred while levels load, then assigned after the
  last level, before roof verification. A missing or retyped target fails the
  load before players are restored. Saves without links keep the old
  `round.json` shape; older saves contain no link values.

`tests/persistence_pointers/level_links/run.py` runs the actual saver, loader
and preflight in an isolated 3x2x2 world: forward, backward, mutual pair,
nested and shared targets, same-level, undeclared field, unsaved target,
unbound target and tampered-row cases, plus export/import mutation controls.

## Decisions and remaining work

Cross-level power networks are still not implemented.

The policy for known transient fields is explicit omission before encoding and
before legacy decoding. There is no catch-and-drop fallback for unknown
cross-level pointers. Newly found pointers require their own classification.

Native acceptance remains separate: run the isolated full-game frog/cross-level
save/import regression only with authorization for that runner, temporary saves
and its external-effect adapters. Offline checks and compilation do not prove
native save/load behavior or a deployed fix. The link fixture above is native
evidence for the codec only, not for the full game. Vertical power connections
can now build on the cross-level link codec.
