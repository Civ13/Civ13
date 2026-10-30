# Civ13 tgui migration proposal

Research date: 2026-10-30. This document starts a draft implementation PR;
checkboxes are acceptance criteria, not claims of completed work.

## Pinned evidence and scope

- Civ13 `master`: `ef3faa6b90e0e56affa072d93dae3aa7ffbdc927` (remote verified).
- Requested reference: [Giacom/-tg-station](https://github.com/Giacom/-tg-station/tree/f8f6a3693ec1c0e24ad14412e8ba54948f2ef9c1/tgui),
  commit `f8f6a3693ec1c0e24ad14412e8ba54948f2ef9c1`, dated 2020-05-31.
  Its package version is **tgui 2.0.0**, Inferno 7, webpack 4, Babel 7,
  Node 12.13+/Yarn 1.19+. This is a historical tgui design reference, not
  current /tg/station and not evidence that its dependencies are modern.
- Civ13 currently uses NanoUI: jQuery/doT templates, `datum/nanoui`,
  `GLOB.nanomanager`, `process/nanoUI`, and `datum/topic_state` authorization.
  There are **12 `.tmpl` files: 10 screens and two layouts**; the thirteenth
  directory entry is `TemplatesGuide.txt`, not an interface.
- Scope is those ten screens and their reusable UI foundation. Ordinary
  `browse()` windows, chat, HUD, launcher and OpenDream runtime are not migrated.
  No gameplay, map, persistence, or /tg/ machine implementation is imported.

## Architecture decision

Retain Civ13's manager, scheduler, ownership checks, topic states, existing
`ui_interact` data producers and domain `Topic` handlers. Introduce a compatible
`/datum/nanoui/tgui` renderer, not a second competing UI manager. Keep legacy
NanoUI templates and an explicit fallback during migration. Use JSX components
and the pinned reference's component conventions with a reproducible supported
Node 24 build. Do not execute the old build scripts or import its webpack 4
lockfile wholesale. A webpack 5/Babel build must explicitly target legacy JS;
modern Node does not imply modern browser output.

Upstream DM is not drop-in: it redefines `ui_interact` and `mob.open_uis`, uses
`SStgui` rather than Civ13 processes, `ui_state` rather than `topic_state`, and
requires absent preferences and lifecycle hooks. A wholesale import would
conflict and could bypass existing authorization or break logout/transfer.

Frontend messages must point to the UI datum, never directly to the machine.
The adapter rechecks ownership and live interaction status before forwarding
only the expected legacy action parameters. Client disabled states are not an
authorization boundary. Preserve per-screen validation and state updates.

## Proposed implementation commits

1. **Reproducible frontend foundation** (`tgui/`, generated `UI/tgui/`):
   pin provenance and dependencies, retain applicable license notices, add
   component/runtime subset and a deterministic production build, status/update
   bridge and bounded queue, safe text rendering, and local browser fixtures.
   Build from source; never copy the reference's stale compiled bundle.
2. **Civ13 adapter** (`code/modules/nano/tgui.dm`, `civ13.dme`, asset registry):
   inherit manager lifecycle; use existing `receiveUpdateData` transport;
   deliver assets through the existing cache; preserve close/logout/transfer,
   parent/child status and polling. Make fallback explicit and keep legacy files.
3. **Screen conversions**, preserving all current actions/data:

   | Existing template | Existing producer | Coverage |
   | --- | --- | --- |
   | `warehouse_book.tmpl` | `pepelsibirsk.dm` warehouse book | empty/populated read-only inventory |
   | `chem_disp.tmpl` | `Chemistry-Machinery.dm` | amount, dispense, contents, eject |
   | `appearance_changer.tmpl` | `nano/modules/appearance_changer.dm` | all permitted appearance controls |
   | `vending_machine.tmpl` | `vending.dm` | stock, coin, payment, cancel, panel |
   | `vending_machine2.tmpl` | `vending_sales.dm` | sales workflow |
   | `vending_machine_gulag.tmpl` | `vending_sales.dm` | gulag variant |
   | `vending_machine_taotd.tmpl` | `vending_sales.dm` | TAOTD variant |
   | `research_bench.tmpl` | `research_tree/research_bench.dm` | tree, selection, filters, progress/actions |
   | `faction_symbol.tmpl` | `groups/faction_symbol.dm` | grid, drag batching, tools, colors, undo/save |
   | `faction_creation.tmpl` | `groups/faction_creation.dm` | draft fields/grid, founding, cancel |

   The two layouts become reusable chrome/status components. Specialized
   research and faction scripts must be deliberately ported or bridged; they
   cannot silently disappear in a generic template replacement.
4. **Regression and CI integration** (`tests/tgui/`, frontend tests, scoped CI):
   build/lint/source contracts, browser interaction tests, generated artifact
   consistency and exact-head hosted compilation. Admit only bounded offline
   tests; no expansion of held/native jobs or existing security settings.
5. **Review and verification report**: independently review action boundaries,
   lifecycle and all screen parity; fix valid findings; push reviewed increments
   to this same draft PR and inspect checks on the final commit.

## Browser and compatibility risks

Civ13 targets BYOND 516.1688 with minimum compiler 516.1681. The reference
explicitly transpiles for IE8 and ships IE shims; that is intent, not proof of
rendering on the currently deployed client. Preserve conservative browser
output and do not assume Chromium-only support. Its `byond.js` currently
accesses `groups[1]` after a Trident regex without checking for a match, crashing
on non-Trident user agents; adapted code needs a regression test for both.
Modern browser automation is useful but is not native BYOND or OpenDream proof.

Test startup updates before scripts load, malformed data, Unicode and HTML-like
names, empty lists, large inventories, repeated actions, Cancel/Close/reopen,
status-only updates, loss of access, deleted hosts, logout and mob transfer.
For canvas screens test drag outside/re-entry, interrupted strokes, chunking,
undo boundaries, cancel without commit and repeated save/found attempts.

## Licensing and supply chain

Civ13 and upstream root LICENSE are AGPL-3.0. Upstream README separately calls
tgui clientside MIT, assets CC-BY-SA-4.0 and Font Awesome SIL OFL; some individual
files have additional notices (notably `styles/functions.scss` GPL-2.0-or-later).
Record copied-file provenance and preserve actual per-file notices, rather than
relabeling the whole tree MIT. Prefer omitting unrelated artwork, fonts, themes,
optional developer-server integration and unused upstream game screens.
Dependencies need lockfile integrity and license inventory. No install hooks,
unrecognized downloaded binaries, privileged execution, credentials in builds,
new paid services, branch protections or security-setting changes are authorized.

## Acceptance and rollback

- [ ] Supported toolchain installs reproducibly and builds from reviewed source.
- [ ] All ten screen contracts preserve controls, data and authorization.
- [ ] Legacy renderer remains available; no unrelated browser UI migration.
- [ ] Browser tests cover update/action/close and complex interrupted flows.
- [ ] Source/lint/build tests pass; generated assets match source.
- [ ] Current-head hosted compilation and applicable CI results are recorded.
- [ ] Independent review findings are resolved and reported.
- [ ] Native BYOND 516.1688/in-game rendering, focus, cache, logout/transfer and
      OpenDream compatibility are explicitly reported as not run unless separately
      authorized and actually exercised. They are not inferred from browser tests.

Rollback is to select the retained legacy renderer or revert the migration
commits. This draft does not authorize merging, deployment, server restart,
feature activation, native execution or client/runtime changes.

Toolchain references: [Node supported releases](https://nodejs.org/en/about/previous-releases),
[webpack target](https://webpack.js.org/configuration/target/),
[webpack output environment](https://webpack.js.org/configuration/output/).
