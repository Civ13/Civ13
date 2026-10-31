# Civ13 tgui migration proposal

Research date: 2026-10-30. The proposal and implementation sequence below
preserve the original decisions. Implementation is published in PR #3427;
the dated evidence appendix distinguishes verified source/browser checks from
remaining native acceptance. Checkboxes remain acceptance criteria, not an
independent verification record.

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

## Implementation evidence (reconciled 2026-10-31)

The adapter and all ten React/tgui-core screens are published in
[PR #3427](https://github.com/Civ13/Civ13/pull/3427), reviewed source head
`53ac7726baefa4ff24aef969a9e6a9cdba4cb101` on `codex/tgui-upgrade`.
The original local-only/publication-pending status is superseded. The PR remains
a draft at this evidence checkpoint; no merge, deployment or activation is claimed.

[Actual-head frontend CI](https://github.com/Civ13/Civ13/actions/runs/41096667753/job/124204083942)
passed TypeScript, the production Rspack build, 16 component/state tests,
eight backend source-contract tests, executable ES5 bootstrap checks,
production-bundle JSDOM smoke, generated-asset consistency and Chromium
interaction smoke. JSDOM renders all ten routes with real React/tgui-core.
[BYOND 516.1688 compilation](https://github.com/Civ13/Civ13/actions/runs/41096667959/job/124204352194)
passed with zero errors and zero warnings; the
[required aggregate](https://github.com/Civ13/Civ13/actions/runs/41096667959/job/124204908442)
passed. Skipped/path-filtered jobs do not add runtime coverage.

The initial local Chromium attempt was blocked by cloud process/socket limits.
The later hosted Chromium success above supersedes that pending-browser status;
it does not establish native transport. `tgui/scripts/browser-smoke.mjs`
substitutes `window.Civ13Tgui` and observes synthetic ready/action/update wiring.
It does not execute BYOND `Topic`, the native asset cache or a classic-window reopen.

[Four QA-reviewed Chrome previews](https://github.com/Civ13/Civ13/pull/3427#issuecomment-6528744788)
show research, faction creation, chemistry and warehouse using fictional data.
Reuse the [gallery and provenance](screenshots/README.md): captures came from
`9bc71d86c38a1560bd3c23e80acacd7ba6a1c282` with unchanged production assets,
and were committed at the reviewed head. These are cloud browser screenshots,
not native BYOND/OpenDream screenshots or acceptance of all ten screens.

Independent review found a research ancestor-highlighting mismatch and a
bootstrap-outage fallback gap; both were corrected with focused regressions.
The migrated close callback checks its owning client and the early update queue
is bounded. Unused management actions are not exposed through the bridge.
This records those fixes, not completion of every independent review criterion.
Unused legacy PC/map layout hooks are outside the completed ten-screen scope;
the proposed layout conversion above does not claim they were all ported.

Native BYOND 516.1688 acceptance is **not run**: actual ready -> snapshot ->
action -> update delivery, automatic/manual fallback and classic reopen,
cold/warm cache, focus, close/logout/mob transfer, stale generations and
multi-chunk faction stroke/undo ordering remain unverified. Compilation and
browser results do not prove these behaviors. OpenDream compatibility is also
unverified and is not included in the native plan. See the bounded
[native acceptance scene plan](native-acceptance.md), which prepares future work
without launching a compiler, daemon or client. Current-master integration
requires reconciliation and refreshed evidence if implementation bytes change.

A dependency audit found development-tool advisories in an initial test-runner
pin and unnecessary Rspack CLI development-server dependencies. The follow-on
changes update the test runner and use Rspack's build API directly; no developer
server is required or exposed. Final `npm audit` after those changes reports zero vulnerabilities across
all dependencies. A clean `npm ci --ignore-scripts` and repeat build are also
checked; the generated JS/CSS/license inventory reproduce byte for byte.
