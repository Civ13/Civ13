# Persistence: scoped agent notes

<!-- 2026-10-29: pointer classification audit -->
See [the #3407 pointer audit](../../persistence-pointer-audit.md) and
`tests/persistence_pointers` for the bounded typed inventory, safe runtime
exclusions, legacy grab/action constructor rejection and repeated-save alerts.
AI targets require their dependent stance/path state to be excluded too.
`following_mob` includes a consumed/refundable leash; keep it fail-closed pending
the paid-relationship policy. Ladder topology and unknown links also remain
fail-closed. Do not clear live pointers to make export succeed. The full-game
frog regression is prepared source, not proof that native save/load ran.

Read only the entries relevant to the paths or behavior being changed.
Code paths and commands below are relative to the repository root unless
shown as Markdown links. These dated notes preserve subsystem contracts
and historical evidence; they are not a task-wide completion checklist.
Use the root [PR completion policy](../../../CODEX.md) for the finish line.

Explicit restrictions on live actions, held runners, credentials and feature
activation still apply to those actions. Missing native, graphical or
save/load evidence belongs in the report and never blocks a source fix.
Do not turn an evidence limitation into a new approval requirement.

<!-- 2026-10-24: persistence construction weathering -->
Seasonal construction is an exact-design opt-in in code/processes/seasonal_construction.dm,
gated by map.persistence, with 16/32/64-season fibre/earth/timber defaults. Paired
roof/floor slabs are exempt because generic wood roofs can underlie modern floors.
Save hooks accrue unpaid debt without destruction; roofs explicitly save debt,
and after_load rebases excluded runtime clocks/indexes. The owner retained the
16/32/64 rates and removed contents-based terminal deferral: normal qdel/collapse
hooks are dispatched; child/occupant consequences remain unverified. Tests are
offline; prepare.py only prepares
an uncompiled native packet. Keep native/graphical acceptance and balancing pending.


<!-- 2026-10-24: authoritative zones and spawn registries -->
Durable schema 2/topology 2 captures native area IDs in per-level zone_capture
records at turf-frame admission. IDs use lineage counters, not new RNG calls.
Validate candidate files with yields; do not restore a full-world no-yield JSON
comparison. Area registration is operation-staged, retirement precedes publication,
and load/recovery readers require admission. No rollback exists after ClearMap.
Schema 1 keeps its legacy reader; tests/zone_persistence is offline/preparation
evidence only. Local IDs are not shard/custody IDs or logical geographic layers.

<!-- 2026-10-19: protected sleep buckle ownership -->
<!-- 2026-10-23: save movement and physical sleep guards -->
Cross-z movement admission reads persistence_active_operation.kind == "save";
load reconstruction and same-z serialization hooks must remain nonblocking.
Resolve physical turfs through containers, and allow qdel's gc_destroyed mark
to detach atoms before gcDestroyed is assigned. Raw loc/z assignment bypasses
Move/forceMove; explicit transport paths use persistence_set_loc/set_z.
tests/save_movement is offline source-flow evidence, not native acceptance or
proof that all remaining raw location writers are covered. Protected sleep's
physical predicate includes (1,1,1) and the existing admin sleep area; stale
return coordinates inside that area must keep protection and refuse waking.

Protected sleep relocates the body between z-levels, so release only its matching
reciprocal buckle before entry or wake. Keep return coordinates captured before
unbuckling, reject mismatched occupants, and leave sleep protection active on a
failed wake. Both delayed verbs retain the initiating client/body and recheck the
persistence gate at transfer time. Per-level saves still reject cross-z object
fields; never suppress that guard to hide a stale spatial relationship.
`map_storage.last_save_reference_failure` is a bounded admin VV snapshot for
cross-level and duplicate-entry failures, including direct Save_World calls.
Keep only scalar identities/coordinates and at most eight schema-field frames;
never pin live objects, retain values or print lookup refs in public reports.
Preserve it through cleanup, clear it only at accepted save admission, and verify
lookup type/location because native refs can be recycled after deletion.

<!-- 2026-10-18: restored input clocks and action locks -->
The custom saver includes changed tmp fields. Mob next_click/next_move and
may_do_after/may_do_mob are process-local deadlines/locks: exclude them on export
and legacy import through persistence_runtime_var. Do not reset them on every
Login or click, which would bypass live cooldowns/actions. The world-save
runner's --input-runtime adapter checks disk-backed migration and the production
early click gate; connected-client interaction remains separate evidence.

<!-- 2026-10-24: bounded-save roof compatibility -->
Roof preflight must use the shared versioned content decoder for typed formats
2 and 3. A format-2-only plan skips chunked roof contents before area validation.
Offline source checks do not establish native format-3 roof recovery.

<!-- 2026-10-24: complete conditional offline projections -->
The save_movement adapter selects the explicitly declared collector-disabled
branch; it is not a general DM preprocessor. Proc-local column-zero #ifdef lines
must not truncate ownership/return tails. Unknown symbols/directives and malformed
conditional scope fail even in inactive branches. Preserve both-branch/sentinel
and historical-defect controls. These are offline models, not collector or native
gameplay acceptance; do not change production code to make an adapter pass.

<!-- 2026-10-23: persistence minimum date -->
Persistence activation, configured startup and completed metadata restoration use
apply_persistence_age_floor(). age is the displayed date/epoch; ordinal_age is a
separate research tier, and prototype research can advance it independently.
The 1943 floor preserves later dates and research data; unknown epoch labels are
not converted. tests/persistence_year checks source-derived offline traces;
run-durable-world.py --persistence-year separately exercises the real helper,
admin toggle, extracted configured activation and 24 v1/v2 ticker disk imports
in an isolated 8x8x2 world. Its three controls must reach their named assertions.

<!-- 2026-10-24: area topology and persistence review -->
Area references are anchor coordinates plus type, not independently recreated
area objects. Reconstruct only proven saved roof topology before field decoding;
retain/recheck exact base/destination identities, including empty instances, and
scope entry IDs by z. Never fabricate unrelated areas or weaken mismatch checks.
World-preserving preflight is separate from input-file byte immutability: absent
native savefile fields need presence checks and copy-only tests. Honor refused
movement before landing effects or ownership/success changes. Offline source
adapters must reject unhandled preprocessor directives, not silently truncate
procedures. Cross-z guards do not make a yielding save atomic. See
`docs/zone-persistence-audit.md` for #3290, known gaps and the regression matrix.
Future atmospheric rooms/networks need logical identities separate from area
types/objects, versioned topology and authoritative gas/thermal stores. Rebuild
derived caches and admit workers only after full restore/conservation checks;
see `docs/atmosphere-persistence-readiness.md`. This plan does not activate atmos.

<!-- 2026-10-15: durable invulnerable areas -->
Placed admin/sewer areas use native `INFINITY` for `artillery_integrity`.
Durable JSON uses the exact `positive_infinity` sentinel only for that field;
ordinary numbers remain finite and bounded. Preserve finite legacy values and
reject malformed/wrong-field sentinels before world mutation. Contract probes
and the full metadata fixture audit inherited area defaults and placed areas.

<!-- 2026-10-11: world-save verification -->
- Persistence regressions are in `tests/world_save`; the focused fixture uses
  the actual saver/loader with isolated adapters, and `run-game.ps1` exercises
  real constructors in temporary storage. New saves use version-2 typed values
  and sharded entries; retain legacy flat-entry reading. Never restore `loc`,
  `pixloc`, or client session fields as ordinary variables. Linux DreamDaemon
  needs a relative log path inside the isolated working directory.

<!-- 2026-10-14: optional save fields and player reclaim -->
- Reading an absent native savefile field can create a null directory entry.
  Check `F.dir` membership before reading optional legacy fields; otherwise
  typed-value validation can reject a valid generation. The reclaim suite's
  `legacy` control checks this mutation before broader world preflight.
- `lastKnownCkey` is login history, not unique body ownership. Reclaim uses the
  explicit canonical owner, complete-load readiness and ordinary admission
  guards. Legacy migration requires a reviewed generation-bound unique body
  mapping and a fresh derived save; preserve all original generations.

<!-- 2026-10-15: isolated recovery observer setup -->
When normal global startup is disabled, fixtures that remove real mobs must
initialize `GLOB.all_observable_events = list()` before constructing the moved,
direction, name and stat observer events. Otherwise event construction can turn
the null registry into one datum, and the second event raises a type mismatch.
Missing direction observers also make real contained-item removal fail.

<!-- 2026-10-12: inherited runtime exclusion precedence -->
DM `in` binds below `||`; parenthesize membership before combining a runtime-field
list with `..()`. Otherwise a nonempty list short-circuits the parent exclusion.
The human corpse fixture checks inherited human/equipment exclusions and its
`--negative-control runtime-parent` restores the faulty human expression.

<!-- 2026-10-15: native associative collections -->
`code/_macros.dm` redefines `islist(A)` as `istype(A, /list)`, excluding `/alist`
although native BYOND `islist` accepts it. Squad and leader defaults are alists
with numeric keys and null associations. Collection codecs must handle `/alist`
explicitly; isolated probes must import the production macro. Numeric alist
indexing addresses keys, so iterate keys instead of positional indexes.

<!-- 2026-10-15: save and continuous-round guard ordering -->
Ticker save-in-progress gating precedes continuous persistence-round recovery.
Do not clear a saved finished flag or change round state while serialization is
yielding. tests/persistence_round/run.py --negative-control save removes that
guard and must fail the production ticker/save interaction assertion.
<!-- 2026-10-15: persistence runtime view helper -->
ClearMap must preserve the global dview_mob identity. Retiring this runtime mob
breaks FOR_DVIEW in post-import lighting processing after GC clears the global.
The lighting recovery fixture runs production lighting_sources.fire(), not only
light constructor/registration checks; lighting-view removes the preservation guard.
<!-- 2026-10-19: bounded admitted saver draft -->
World-save traversal retains operation admission, durable state/player ownership,
and active before_save_context transfer frames. Invalidated active parents fail
closed with backup recovery; do not restore the old detached-parent exporter.
Level format 3 adds bounded content chunks; keep version-2 and legacy readers,
including durable reachability and ownership decoding. Round-state versioning is
independent. Old readers reject version 3, so downgrade needs retained old files.
The sleep(0)-below-80% policy increases effective duty cycle and is experimental.
Dispatch save_latency_regressions for native dense/backup/heartbeat/refusal and
current persistence checks; preparation alone is not acceptance or deployment.
<!-- 2026-10-19: serializer profile admission -->
Test-only save profiling starts after save_world_contents accepts its operation
token. Never wrap the public Save_World entry on current sources: busy/reentrant
requests must not restart another serializer's clock. Source tests are offline;
manual world_save_profile_regressions is separate native evidence.

<!-- 2026-10-19: exclusion dispatch source contract -->
Runtime-exclusion hooks can have early mining ownership guards before their
terminal list-membership return. Preserve those guards when replacing only the
list with switch dispatch; source fixtures must pin current inherited helpers
and include all mining fields. Offline source parity is not native evidence.

<!-- 2026-10-19: Linux exclusion parity lane -->
Exclusion dispatch run-ci.py consumes source-only packets for bounded Linux CI
parity and three controls, retaining receipts. It is separate from run.py's held
Windows grant runner; neither an offline pass nor workflow addition proves native
parity, and this lane makes no benchmark or listener-sampling claim.

<!-- 2026-10-13: extraction census and receipt boundaries -->
Extraction census read leases guard account_store.write_phase across store
instances and child journals, not external processes or runtime world movement.
Failed scans retain their lease until explicit abandonment; abandonment locks the
census. Surface auxiliary ownership remains incomplete and disabled.
extraction_crypto_bytes is ASCII-only. Receipt reason validation instead uses
DM byte length and canonical codepoint round trips for UTF-8; text2ascii positions
are bytes. tests/extraction/run_ipc.py --compile-only never launches a daemon.

<!-- 2026-10-28: extraction exclusion custody -->
For extraction-descended heads, additionally require the exact reviewed extraction
custody projection against that event base; never accept a lighting-only result in
place of the extraction source. Verify all committed fixture and helper inputs.

<!-- 2026-10-20: extraction corpse-release oracle -->
The mode fixture catches corpse-release assertion failures as `FAIL:` records,
not engine `Runtime error:` records. Its omission control first reaches the
configured insured-weapon release assertion in scope_insurance_probe.dm. Match
that exact caught assertion and reject collateral failures in every output stream;
do not reuse the superseded bones-transition message as the oracle.

<!-- 2026-10-12: extraction NPC retirement -->
When an NPC's own procedure qdels that actor, its caller can observe a null
return even after the durable retirement receipt commits. Assert receipt state
and original-object retirement, and stop subsequent AI when loc is null.

<!-- 2026-10-12: extraction material restoration -->
Extraction material stacks must construct at null before relocation: native
stack constructors can otherwise merge into an existing stack. Serialize
`!!is_open_container()` for boolean lid state; its native return is a flag mask.

<!-- 2026-10-13: extraction auxiliary census -->
Extraction surface ownership reads actual auxiliary journal records through
`surface_inventory.dm`, never recovery/repair readers. Market listings bind the
actual escrow stash root/digest once; mail ownership joins page graphs to active
node owner/page/root indices. Terminal NPC receipts are historical, not permanent
identity tombstones because insurance can return those IDs. This disabled census
still lacks a fresh-world/private-home replica contract; compile-only controls
do not establish native ownership acceptance.

<!-- 2026-10-13: explicit home replicas -->
`home_replica.dm` binds floor-only account/world replicas to actual marker owner,
revision, graph digest and placement under explicit maintenance ownership. Bound
profiles refuse admission before decode until a future retirement handoff.
Loaded surface feeds require the same map/dimensions/world tick and recheck roots;
yielding loaders fail this conservative barrier. Fresh-world completeness stays
false: no authoritative opt-in constructor ledger is established before DMM load.

<!-- 2026-10-13: replica room selection and effect persistence -->
Admission must reserve markers carrying any partial replica binding, not just
session owners. `admission_available()` requires exact null owner/digest and numeric
revision zero. Effect partial persistence requires an explicit parent-calling
marker allowlist for room and binding fields; runtime session is excluded.

<!-- 2026-10-12: extraction bot economics -->
Extraction bot economic mutations use the shared conservation journal and put
operation receipts in the participant snapshot. Reserved vendor/market accounts
cannot be player sessions; `_bot` is an internal journal directory in ownership
scans. `tests/extraction/run.py --probe equipment` checks signed offline market
flows and interrupted settlement recovery; its economic payment negative control
must reject a missing buyer debit. This does not enable live IPC or prove bot UI.

<!-- 2026-10-12: native spool publication -->
Disabled extraction spool replies use `.reply.pending` as a read barrier. Recovery
requires the authenticated original request and matching durable response, keeps
the original expiry, and never executes an expired request. `run_ipc.py` checks
three disposable native processes, partial writes, marker-removal interruption
and signed mismatching markers; publication negative control must detect omission
of the receipt comparison. Single-writer ownership is enforced within a world;
host provisioning must also prevent concurrent processes sharing that directory.

<!-- 2026-10-11: extraction vehicle account graph -->
Extraction garage snapshots use explicit bounded part/link/config/fuel graphs;
never serialize movement callbacks, passengers or arbitrary vehicle vars.
`tests/extraction/run.py --probe vehicles` uses three native processes for
acknowledged reload, removal and quarantined-debit loss settlement. Its
`--vehicle-loss-negative-control` detects retaining an uncertain old garage
when stash is empty. These checks do not establish playable vehicle extraction.
Paid car acquisition journals payment before factory construction. Pending
construction blocks login; offline `recover.py --action retire-vehicle` requires
the exact purchase/revision and `--loss-confirmation forfeit-paid-car`, preserves
a fixed receipt and never refunds or reissues. The mode purchase control detects
retaining spent parts in the stash.

<!-- 2026-10-11: atomic raid groups -->
Group deployment reuses the shared journal under `_settlement/groups/`; exact
home-to-raid projections come from the solo raid planner. Never move members
before all account debits commit. `--probe groups` checks three-process recovery
across eleven cuts; mode fixtures exercise consent/readiness and original atoms.

<!-- 2026-10-12: native IPC clock precision -->
Unix timestamps exceed DM's exact integer range. Keep their decimal text and
split days/seconds before short expiry comparisons. world.realtime can round by
several seconds; combine its UTC date with precise world.timeofday and correct
adjacent-day rounding near midnight. DM logical expressions can return operands,
so normalize leap-year arithmetic with !!. tests/extraction/run_crypto.py checks
independent UTC, midnight, signing and schema vectors without a live bot.

<!-- 2026-10-13: replica retirement receipt scope -->
Floor replica retirement records account/binding before removing actual roots,
but does not clear room/account bindings. Prepared/retired receipts cannot prove
an old world save will not restore roots; restart refuses missing runtime refs.
Final admission/unbinding needs authoritative durable-world generation and
complete restored-world coverage. The unfinished _home_replica journal makes
surface auxiliary census fail closed until that contract is supported.

<!-- 2026-10-28: ordinary roundtrip null-topology boundary -->
Only roundtrip.dme selects the roundtrip_fixture storage subtype. It returns
before operation ownership checks only when validated_zone_state is null;
every present state, including an empty list, delegates to the shared refusal.
Keep the legacy positive import assertion. The scoped setup and boundary probe
must not leak to the string-path or floor-decal fixture. Offline source checks
are not native acceptance: published head2830578 failed legacy import after a
clean 516.1688 compile. Preserve that failure and the original input hashes as
historical reference data. Current saved-character preparation checks scoped
lifecycle procedure contracts and records hashes of all actual input bytes.

<!-- 2026-10-28: ordinary roundtrip loader compatibility -->
`roundtrip_compat.dm` supplies ordinary area membership only to roundtrip.dme;
shared world-save stubs retain null-only legacy admission and reject every
present topology payload. Do not freeze unrelated current source to old file pins.
It reuses the shared area registry declaration and clear-ground snow adapter;
nonzero snow still fails closed. Do not redeclare those shared symbols or add
weather/topology simulation. Offline preparation tests do not compile DM. That historical
declaration-only packet left run-round-metadata.py unchanged; without
--byond-archive the default still requires legacy 516.1681.
