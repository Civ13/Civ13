# Tgui native acceptance scene plan

Prepared 2026-10-31 for PR #3427. Status: source plan only; every native case
below is **not run**. No new UI, runtime installation, native compilation,
daemon/client launch, security change, save access or publication is authorized
by this document. Main retains final acceptance and publication.

## Exact inputs and existing machinery

- Civ13 source: `53ac7726baefa4ff24aef969a9e6a9cdba4cb101`, branch
  `codex/tgui-upgrade`. Official tgstation reference:
  `bf6f771a1e221e06938978e36bbaf78543f85ebe`; React 19.2.7 and
  tgui-core 6.1.1 are locked in `tgui/package-lock.json`.
- Retain production `code/modules/nano/tgui.dm`, `_nanoui.dm`,
  `nanomanager.dm`, `interaction/`, `code/modules/client/asset_cache.dm`,
  `UI/tgui/` and the legacy scripts/templates. Keep the real bootstrap's
  `byond://`/`cef_to_byond` route and real `receiveUpdateData`; do not replace
  `window.Civ13Tgui` with the browser smoke's stub.
- Reuse `tests/nanoui_ownership/` extraction/assertion/evidence conventions
  for a small isolated host fixture, and `docs/game-verification.md` for receipts.
  Its current `run.py` pins **516.1681**, substitutes browser/manager/assets,
  and has no connected client: do not execute it unchanged or relabel its
  ownership result as 516.1688 transport acceptance.
- Reuse `scripts/native_fixture.py` containment/cleanup accounting only where
  its existing policy admits the intended operation. The Windows no-sampled-
  sockets Session cannot host a connected client. See
  `tests/human_subtile/RUNTIME-ISOLATION.md` for the retained 1688 startup-socket
  limitation. Do not weaken or copy around that guard. Main must select an
  already authorized connected-client executor/profile before native work.
- Reuse `tgui/scripts/browser-smoke.mjs`, component/source/bootstrap checks
  and the existing four-image gallery as completed browser evidence. Do not
  rebuild the gallery or add a competing frontend. Exact blob/SHA256 pins for
  the reviewed inputs are in the accompanying private packet's `source-pins.json`.

## Smallest proposed fixture and observation seams

Prepare one disposable 9 x 9 x 1 floor scene, two synthetic test mobs A/B and
one adjacent synthetic host. Record the eventual DMM path/hash and dimensions;
the scene is proposed, not an existing runnable TGUI fixture. Retain production
NanoUI manager, topic-state authorization, assets, browse/output and client
close/logout/transfer hooks. The host supplies only chemistry-shaped fictional
data (`amount=5`, no reagents or beaker); its allowlisted `amount` action changes
a fixture counter to 10 and requests the ordinary manager update. This tests
transport without dispensing or touching gameplay/save state.

Observe at the UI datum and host boundary with fixture-only wrappers that call
their production parent implementations: append monotonic sequence/time,
case ID, owner A/B, window, generation, message type, status, host dispatch count,
counter and manager membership to a local receipt. Capture outgoing snapshots
without suppressing actual client delivery. A passive diagnostic wrapper may
record `window.receiveUpdateData` then call the original unchanged; record its
diff/hash. Counters must come from server state, not an optimistic React overlay.
No synthetic `usr`, direct `Topic()` call or fabricated ready receipt counts as
connected-client evidence. Bind every receipt to the frozen source, overlay,
compiler/runtime binaries, DMB/RSC, OS and actual embedded UA/engine version.

One real connected client is sufficient for the A -> B transfer sequence.
Wrong-owner rejection requires a second consenting isolated client acting on
the first owner's real UI URL; transferring the same client to B does not make
that client's retained window an unauthorized caller. If the second client is
unavailable, mark the native wrong-owner case not run. Use a fresh
isolated client cache/profile if supported by the selected executor; never delete
or edit the user's existing cache. If a fresh cache cannot be isolated, mark the
cold-cache case not run. No production Gaia, save import, live configuration,
external integration or account credentials are required by this scene.

## Cases and observable oracles

| Case | Steps | Required observation |
| --- | --- | --- |
| Ready/snapshot/action/update | Open modern chemistry scene as A; wait for actual ready; click Amount 10 once. | Browser sends `type=ready` with datum ref/window/generation; server records `frontend_ready`, emits initial `data.amount=5`; exactly one native `act/amount` with `{amount:10}` reaches host; later server snapshot and visible UI show 10. Preserve this ordered chain. |
| Before ready and status-only | In a separately controlled run delay ready within 15 s; update counter to 7 before readiness; then release ready. Disable interaction via actual fixture topic state. | Latest snapshot after ready shows 7; pre-ready action dispatch count remains zero; disabled config is delivered and a real action attempt has no host effect. Receipt distinguishes observer/control injection from ordinary clicks. |
| Cold/warm cache and focus | In isolated fresh profile open once, close and reopen without clearing it; click/edit UI then use map input. | Record requested/sent assets and received hashes in both passes, successful handshake and visible state; no stale old bundle. Focus returns to map on open per base `open()`; keyboard/close interactions remain usable. Warm-cache traffic reduction is a measurement, not an assumed pass criterion. |
| Manual fallback | Click Classic interface after a modern snapshot. | Actual native `fallback` reaches current UI; `legacy_renderer` becomes true; `open()` advances generation and real legacy templates render with latest data; legacy action reaches host once. A fallback callback alone is insufficient. |
| Bootstrap/bundle failure | Separate fixture-only asset-delivery variants omit bootstrap, then omit modern JS/CSS; retain exact variant diff and clean control. | The inline bootstrap-error link and bootstrap automatic fallback paths actually reopen legacy; observe server fallback and successful legacy action, not only navigation. Also exercise the 15 s timeout with delayed bundle. No timeout/retry acceptance on partial receipts. |
| Unsupported capability | Only if executor can provide an isolated unsupported native engine/capability control without changing installed security/runtime settings. | Modern bundle is not parsed; classic window is usable. Otherwise retain browser negative-control evidence and mark native unsupported-engine case not run. |
| Close/logout | Close via native window chrome; reopen through the normal producer with valid topic state; then disconnect/logout. | Close clears ready/state and increments generation; manager/processing/mob ownership contains no closed UI; reopen obtains current snapshot; logout closes all owned UIs. Delayed old-page actions cause zero host mutations. Do not call `open()` on a closed datum with null state and assume reopen succeeded. |
| Transfer | With one open window transfer the real client A -> B using the retained client/mob lifecycle. | Manager owns UI on B and removes A membership; no duplicate processing entry; usable B action passes current topic state, stale A page/action cannot mutate as A. Preserve actual outcome if the production transfer invalidates/closes the page instead; require a clean B reopen and no unauthorized effect. |
| Stale generation/window | Retain a real old-page URL, close/reopen or fallback, then navigate to the old ready/action/fallback URL from the connected client. Repeat with wrong window. | Stale messages have zero host effects and do not change current ready/renderer state; a valid current action is the positive control. Log tokens only in private evidence. |
| Wrong owner | From the second isolated client navigate to the first owner's actual ready/action/fallback URL. | `usr != user` rejects it before state/host mutation; valid owner action is the positive control. One client's A -> B transfer is not this negative control. |
| Loss of access/deleted host | Move out of allowed range or change real topic state; separately delete the synthetic host while open. | Ordinary status/closure path runs, no stale action mutates a host, no runtime error or lingering registered window. |

## Native faction scene extension

After transport acceptance, use the same disposable environment with production
`code/game/mob/groups/faction_creation.dm` and `faction_symbol.dm` handlers and
the real `tgui/src/interfaces/Faction.tsx` bundle. Include only synthetic faction
state in memory; record constructor/state adapters explicitly. A synthetic host
counter cannot accept faction parity. No Save/Found action may write real data.

Start with a blank 1024-cell server grid and empty undo stack. Hold one drag
through row 1 from (1,1) -> (32,1), then (32,2) -> (1,2), then (1,3).
That visits 65 unique cells, requiring 60 + 5 cells in two actual native
`act/stroke` messages. First message omits `stroke_continue`; second carries 1;
record their order and payloads, server grid after each and undo depth = 1.
After final delivery the server grid must have exactly those 65 colored cells;
one actual Undo must restore all 1024 original cells and empty the stack.
Repeat a separate interrupted stroke with mouse-up outside/re-entry and blur;
verify no stuck busy/overlay state and no phantom continuation. Repeat status
loss, close and transfer between chunks; record whether an already scheduled
chunk lands before revocation, and require zero mutations after server-side
revocation. A fixed 250 ms client timer is not proof of delivery or ordering.

Test the faction editor and founding draft separately where their ownership
rules differ. Cancel/close must abandon an uncommitted draft. Actual Save/Found,
banner baking and persistence remain a separate scoped game test if their real
handlers cannot be isolated without side effects. Do not infer their acceptance
from the transport fixture or the existing Chrome screenshot.

## Execution handoff

Before any future run, main must reconcile the original owner, freeze a clean
candidate plus explicit fixture overlay, and choose a permitted BYOND 516.1688
compiler/daemon and real DreamSeeker/WebView2 executor with an isolated bounded
loopback client session. The current task expressly excludes native execution.
Use existing process/time/memory/output bounds and retained cleanup; if the
profile rejects sockets or clients, stop and report that exact rejection.
Do not install a runtime, alter the policy, open a production listener or retry
under a weaker wrapper. Record any permitted listener and its closure.

Retain full compile/runtime logs, case receipts including failures/not-run,
source/overlay/artifact hashes, real client captures when needed to resolve
focus/canvas uncertainty, and cleanup/PID/listener evidence. Validate the final
bundle with `scripts/check-game-evidence.py` under its existing schema. A bundle
validator proves consistency, not gameplay acceptance. Refresh affected checks
for changed implementation bytes; reuse unchanged browser evidence with its
original head. Missing native evidence is a report limit, not an invented source
merge gate. OpenDream remains out of scope.
