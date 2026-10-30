# Civ13 tgui migration proposal

Research date: 2026-10-30. This document starts a draft implementation PR;
checkboxes are acceptance criteria, not claims of completed work.

## Pinned evidence and scope

- Civ13 `master`: `ef3faa6b90e0e56affa072d93dae3aa7ffbdc927` (remote verified).
- Corrected requested reference: [tgstation/tgstation](https://github.com/tgstation/tgstation/tree/bf6f771a1e221e06938978e36bbaf78543f85ebe/tgui),
  commit `bf6f771a1e221e06938978e36bbaf78543f85ebe`, dated 2026-10-30 12:30:36 UTC.
  Workspace version is **tgui 6.0.0**. Its lockfile resolves React/React DOM
  19.2.7, tgui-core 6.1.1 and Rspack 1.7.12. The workspace declares TypeScript
  ^5.8.3 and Bun 1.2.16. Actual browser target is **Edge >=123**.
- This corrected reference supersedes the mistakenly supplied Giacom fork.
  No code, build assumptions or migration work from that 2020 fork is adopted.
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
NanoUI templates and an automatic/manual fallback for incompatible browsers.
Use current React 19, TypeScript and **tgui-core 6.1.1 components**, as used by
the corrected upstream, with a minimal Civ13 application shell and transport.
Avoid importing hundreds of unrelated upstream game interfaces, chat, lobby,
keybindings, window pooling or its entire helper runtime.

Use the existing supported Node 24 runtime with a pinned npm lockfile and
Rspack 1.7.12; upstream uses Bun, but Rspack supports Node >=18.12. Registry
metadata confirms tgui-core 6.1.1 MIT and the same integrity as upstream's lock.
This deliberate build-runner substitution avoids downloading an executable
bootstrap and leaves the actual React/component/rendering stack aligned.
Modern browser output is intentional; do not claim IE support through Babel.

Upstream DM is not drop-in: it redefines `ui_interact` and `mob.open_uis`, uses
`SStgui` rather than Civ13 processes, `ui_state` rather than `topic_state`, and
requires absent preferences and lifecycle hooks. A wholesale import would
conflict and could bypass existing authorization or break logout/transfer.

Frontend messages must point to the UI datum, never directly to the machine.
Current upstream uses `Byond.sendMessage('act/<name>', payload)` and typed
ready/update messages, not the old tgui initialize/action protocol. Its helper
routes `{tgui:1, window_id:...}` through client-owned window pools. Civ13's
bridge will explicitly add the UI datum ref and validate owner/window/status,
then map only allowlisted screen actions to existing legacy parameters.
Do not import upstream arbitrary key-command routing or expose unused client
metadata. Client disabled states are not an authorization boundary.

## Proposed implementation commits

1. **Reproducible frontend foundation** (`tgui/`, generated `UI/tgui/`):
   pin provenance and dependencies, retain applicable license notices, add
   React/tgui-core component application and a deterministic production build, status/update
   bridge and bounded queue, safe text rendering, and local browser fixtures.
   Build from source; never copy the reference's stale compiled bundle.
2. **Civ13 adapter** (`code/modules/nano/tgui.dm`, `civ13.dme`, asset registry):
   inherit manager lifecycle; adapt typed messages to existing `receiveUpdateData` transport;
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

Civ13 targets BYOND 516.1688 with minimum compiler 516.1681. Repository
`docs/byond-5161688.md` describes WebView2 prerequisites, but compiler version
alone does not prove which embedded browser actually renders a window.
The corrected reference targets Edge >=123 and depends on React 19/modern APIs.
IE cannot run it merely by transpiling syntax. An ES5 bootstrap must detect
supported browser capabilities before loading modern assets and select legacy
NanoUI otherwise; a manual fallback remains available if load/render fails.
Browser capability negotiation must not grant additional server permissions.
Test unsupported/unknown UA, failed bundles and missing modern APIs, without
silently presenting a blank window or falsely claiming modern compatibility.
Native BYOND and OpenDream remain unverified; browser automation is not proof.

Test startup updates before scripts load, malformed data, Unicode and HTML-like
names, empty lists, large inventories, repeated actions, Cancel/Close/reopen,
status-only updates, loss of access, deleted hosts, logout and mob transfer.
For canvas screens test drag outside/re-entry, interrupted strokes, chunking,
undo boundaries, cancel without commit and repeated save/found attempts.

## Licensing and supply chain

Civ13 and upstream root LICENSE are AGPL-3.0. Current upstream has per-file MIT
notices on its application entry/layout/styles, while its root README no longer
contains the historical blanket tgui-MIT statement. The reusable tgui-core 6.1.1
package explicitly declares MIT. Record actual package/file provenance and
retain licenses/notices; do not infer all upstream files have one license.
Unlike the mistakenly linked old fork, the corrected reference's
`styles/functions.scss` explicitly says MIT. Prefer no copied upstream artwork,
fonts, chat assets, themes or unrelated game screens. Inventory bundled
third-party dependencies and retain their applicable notices.

Use integrity-locked standard registry dependencies with lifecycle scripts
disabled unless specifically inspected. No unrecognized executable bootstrap,
privileged execution, credentials in builds, new paid services, branch-protection
or security-setting changes are authorized.

## Acceptance and rollback

- [ ] Supported Node/React/tgui-core toolchain installs reproducibly and builds from reviewed source.
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
[upstream Rspack browser target](https://github.com/tgstation/tgstation/blob/bf6f771a1e221e06938978e36bbaf78543f85ebe/tgui/rspack.config.ts),
[tgui-core component library](https://github.com/tgstation/tgui-core).

## Implementation evidence (2026-10-30, local work pending publication)

The adapter and all ten React/tgui-core screens have been implemented in the
isolated cloud checkout. The first implementation commit is local only until
publication authorization is resolved; the public draft currently contains this
proposal, not a claim of completed implementation or passed implementation CI.

Local checks: TypeScript, production Rspack build, 16 component/state tests,
eight backend source-contract tests, and executable ES5 bootstrap tests pass.
A second smoke executes the production bundle with real React/tgui-core in
JSDOM, rendering all ten routes and checking action/read-only/text/fallback
wiring. These source/DOM checks are not native gameplay or pixel validation.
Independent review found a research ancestor-highlighting mismatch and a
bootstrap-outage fallback gap; both were corrected with focused regressions.
The migrated close callback checks its owning client and the early update queue
is bounded. Unused management actions are not exposed through the bridge.

Real local Chromium smoke could not start: the cloud shell sandbox prevents
Chromium process sockets; escalation failed at environment setup. No denied
filesystem path was read or modified. A scoped CI workflow is prepared to run
that smoke with the runner's existing Chrome, alongside generated-asset
consistency and source tests. Hosted implementation CI, native compilation and
BYOND/OpenDream graphical acceptance remain pending/not run, not green.

A dependency audit found development-tool advisories in an initial test-runner
pin and unnecessary Rspack CLI development-server dependencies. The follow-on
changes update the test runner and use Rspack's build API directly; no developer
server is required or exposed. Final `npm audit` after those changes reports zero vulnerabilities across
all dependencies. A clean `npm ci --ignore-scripts` and repeat build are also
checked; the generated JS/CSS/license inventory reproduce byte for byte.
