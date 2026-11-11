# Train body graph: local quarantine roundtrip

Current evidence (2026-11-11): full fixture 43/43, runtime_error=0, BYOND
516.1688, 0 errors/0 warnings. Two fixes closed the 13 human/corpse failures:

- The list encoder yielded with `TICK_CHECK` mid-capture, so the human capture
  crossed a tick. Atomic exporters set `export_atomic` and never yield; the
  graph is bounded by TRAIN_BODY_NODES/EDGES instead.
- Renderer output is not captured: external organ `overlays` and human
  `hud_list`, `overlays_standing`, `stand_icon`, `overlays` and `icon`
  (`export_omits_field`). Production update procs rebuild them from the saved
  inputs (hair, eye colour, skin, organ `mob_icon`); the head rebuild controls
  below sample that. `renderer_output_omitted` checks the export. The restored
  quarantine body keeps constructor renderer state until finalization calls
  update_body/regenerate_icons.

Plain datums (wounds, reagents, DNA) have no `name` field; only atoms must
carry one. Departure/source deletion remain disabled.

## Historical baseline

Recovered baseline tree `56d0868ba2dfae99f6d72283893fabfa479d5a61`
(local recovery commit `3d9785e`) matches the previously staged native tree.
Prior exact-tree evidence: BYOND 516.1688 compile 0 errors/0 warnings;
24/37 checks passed, 13 failed, runtime_error=0. Sheep local quarantine,
matrix/filter and durable-profile controls passed. Human/corpse failed,
including head.overlays unsupported and occasional same-tick refusal.
This is not a finished transport codec. Departure/source deletion remain disabled.

## Fresh field-level experiment

This is new implementation, not recovery of lost renderer commit cf1e89bab.
The fixture expects 43 checks: the original 37, five renderer assertions and
`renderer_output_omitted`.

Prior art: `tests/world_save/README.md` excludes composite appearance because
its unsupported null restores can reset separately restored transform/color/
alpha. `docs/saved-player-reclaim.md` rebuilds HUD at Login; that does not prove
HUD portability. Accordingly no composite-appearance equality is used here.

The existing admitted sheep roundtrip now carries non-default color and alpha,
with its existing six-coefficient transform assertion. A separate disposable
human tests production head.update_icon from durable eye-color inputs. Bounded
comparison samples every pixel of up to four icon states and the four cardinal
directions at frame 1, up to 64x64. Repeat reconstruction must match. Causal
controls change eye color and a custom pixel, each gated on baseline equality;
null input must reject. Capture sources are never rebuilt to fit the profile.

These sampled comparisons are **not admission/equivalence predicates**. They
cannot establish animation-frame preservation, native metadata, diagonal
variants, nested head overlays, general clothing, global-cache independence,
HUD rebuilding or remote asset authority. The helper lives only in the fixture.
No codec fields are omitted or admitted, no arbitrary icon filenames imported,
and same-tick/closed-world/source-retention guards remain unchanged.

## Validation and execution

`python3 -m unittest discover -s tests/train_body_graph -v` runs source guards.
`python3 tests/train_body_graph/run.py --prepare-only --evidence-dir <fresh>`
prepares isolated production sources without starting a daemon.
`--byond-bin <516.1688 bin> --compile-only` compiles only. Native execution
requires `--allow-native-execution` and the parent's exact-snapshot coordination.
The fixture closes its port and adds the adapter explicitly, not to production DME.
Keep failed labels and diagnostics; subset success is not overall acceptance.

## Local quarantine, not transport

The real production exporter captures an in-memory v3 graph. Local restore
requires the same adapter's exact one-shot receipt and validates references,
rooted containment and reachability before construction. Return bodies stay in
a detached holder. No clients, account registration, after_load,
restore_finished, source deletion or destination publication occur. Constructor
side effects/queued cleanup are not proven transactional. Local species/build
references and bounded organ icon copies are not remote import authority.
Production save hooks can update corpse age/subtile state; capture is not
side-effect-free and must run under authorized source custody.

## Historical failures

0f7e6f 8/19 (teeth/matrix); a509263 9/22 (species/filter);
dbe531 17/28 (limb metadata); 84bf08 19/30 (mob_icon);
6eb9 20/32 (native atom.icon); fbf064 16/33 (renderer/tick);
44531 24/37 (durable-profile controls). All listed runtime_error=0,
none a full acceptance pass. Local icon bounds do not establish compressed
size or frame-count limits. Preserve original evidence independently.

## Renderer profile source map (audit, not permission to omit fields)

| Owner / fields | Production writer / rebuild entrypoint | Profile treatment |
| --- | --- | --- |
| Human `hud_list` faction images | `human.dm` constructor creates BASE_FACTION, FACTION_TO_ENEMIES, SQUAD_FACTION images bound to src; `human_life.dm:handle_hud_list()` and `human_hud.dm` update faction presentation/viewer images | Viewer-local rendering, but not universally proven reconstructible: `never_set_faction_huds` gates rebuilding, and destination faction resolution must precede it. Recreate only recognized slots after validating their expected source shape; reject extra/custom images. No current omission. |
| Human `stand_icon` | `update_icons.dm:update_body()` creates blank icon; `reload_cached_icons()` blends organs, species/DNA/color/limb state using global icon cache | Normally derived. Forced rebuild must bypass cache and compare full source appearance before declaring omission safe. Custom pixels must be explicitly preserved or reject. |
| Human `overlays_standing` | `regenerate_icons(FALSE)` calls damage/mutation/hair, inventory, cuffs, fire, surgery and bandage layer builders | Slot-specific derived images with nested appearances. Audit every layer and its input first; unknown extra slots/images or custom mutations reject. Do not serialize arbitrary `/image` graphs. |
| Human `icon`, native `overlays`, posture transform | `update_icons()` clears overlays, assigns stand_icon, copies standing-layer images and applies `update_posture_transform()` | Derived only if `icon_update`, transformation/posture state and known slots match. Direct custom atom appearance changes are not proven recoverable and cannot be ignored. |
| External organ `mob_icon`, `icon` | `organ_icon.dm:update_icon()/get_icon()` rebuild species base art, skin, DNA gender, dead tint and body-build suffix. Head override adds eye/lip/hair/facial art. Atom `icon` is a native file handle even when mob_icon is /icon | Current local pins preserve exact pixels/state instead of dropping custom changes. 44531 confirms `isfile=1,isicon=0` on atom.icon. Only the current exact external-organ field is eligible for native clone; no string filename/import. Remote asset authority absent. |
| External organ/head `overlays` | `compile_icon()` rebuilds nested limb overlays; head `update_icon()` clears and rebuilds eyes/lips/hair/facial overlays from owner data | Usually renderer output, but severed limbs/custom overlays and nested contents need explicit equivalence checks. No blanket resource exemption or exclusion. |

Important finalization ordering: existing human `after_load()` methods restore
languages, actions, faction/adoption state and corpse lists/age. Corpse restore
calls `update_icons()` but there is no universal post-field `regenerate_icons`
contract established by this audit. `region_travel.dm` explicitly calls
update_hair/update_body/regenerate_icons for its different, lossy transfer path;
that is evidence of a rebuild entrypoint, not proof it preserves this graph.

A portable renderer profile therefore needs (1) immutable versioned source
assets; (2) approved durable render inputs; (3) quarantined forced regeneration
without client publication; (4) complete slot/state/direction/frame/transform
comparison; (5) rejection of unsupported custom appearance; and (6) finalization
under committed destination custody. This audit implements none of those
missing equivalence guarantees and does not broaden local pinning.
