# Civ13 tgui frontend

This is a Civ13 adaptation of the current official tgui component architecture,
not a wholesale /tg/station runtime port. Reference: tgstation/tgstation
`bf6f771a1e221e06938978e36bbaf78543f85ebe`, tgui 6.0.0, 2026-10-30.
The component package is upstream's integrity-pinned `tgui-core` 6.1.1 with
React 19.2.7. Civ13's application, screen components and bridge are new code.
See [the migration plan](../docs/tgui/upgrade-plan.md).

## Build and test

Use Node 24 (tested 24.22.1) and npm. No global installations or Bun bootstrap.

```sh
cd tgui
npm ci --ignore-scripts
npm run check
cd ..
python3 -B -m unittest discover -s tests/tgui -p 'test_*.py' -v
node tests/tgui/bootstrap.test.cjs
```

Dependencies are locked, lifecycle scripts disabled. Rspack uses its ordinary
registry-distributed native binding; no arbitrary repository bootstrap is run.
`UI/tgui/civ13-tgui.js` and `.css` are committed generated assets so existing
BYOND packaging does not require Node. Rebuild them whenever source changes;
CI checks the generated diff. The build uses the Rspack API directly and does not
install or start its optional development server. `civ13-tgui-bootstrap.js` is hand-authored ES5,
not generated, and must remain parseable before any modern script loads.

Upstream uses Bun/Rspack. This intentionally uses Node/npm/Rspack, the existing
supported cloud runtime, without changing the React/component stack. The build
outputs one JS and one CSS asset and embeds any required assets rather than
fetching external fonts, CDNs, developer servers or gameplay resources.

## Browser/lifecycle contract

Modern assets target Edge/Chromium >=123. The ES5 bootstrap checks the actual
browser before loading them, installs the early update queue, and falls back to
retained NanoUI on incompatibility, loading timeout or runtime error. Every
modern screen also exposes **Classic interface**. It is a per-window fallback,
not an account setting. No IE support is claimed for React19.

The ten converted producers select the modern adapter by default; there is no
opt-in feature toggle. Capability checks and retained classic rendering provide
compatibility fallback, not a dormant modern path.

React mounting sends `ready` but leaves the 15-second startup watchdog pending.
Only a valid snapshot matching this UI ref, window and generation completes
client startup and sends `ack`. The server retains a separate 20-second startup
watchdog until that owner/generation's acknowledgement arrives. If ready,
snapshot or ack delivery fails, the server can select the retained classic
renderer without a successful client fallback message. Close invalidates the
callback. Mob transfer invalidates startup state before the new mob has a client;
the post-key-assignment hook reopens only after reciprocal binding to the intended
client is confirmed, then starts a new bounded handshake. Classic fallback remains sticky for that
UI datum. This covers initial handshake recovery, not failures after startup.
Modern gameplay actions require ready and acknowledgement in addition to the
existing owner/status/generation checks. Pre-ack actions are rejected; a later
ack does not queue or replay them.

`node tests/tgui/bootstrap.test.cjs` executes the actual bootstrap with fake
transport and clocks. Its server side is a model using the production watchdog
guard expressions, not DM execution. The production-bundle JSDOM check uses the
real bootstrap, completes ready/snapshot/ack and rejects a stale-generation
snapshot. Native Topic delivery, timer scheduling, actual classic reopen,
cache, focus and transfer still require separate authorized acceptance.

NanoUI owns windows, authorization, processing and cleanup. Modern actions go
through a UI-datum ref, window id and generation token; the backend allowlists
one action and its payload keys and rechecks ownership/status before dispatch.
Server gameplay checks remain authoritative. The frontend does not import
upstream pooled-window routing, client identifiers, chat, key-command hooks,
lobby or machine behavior.

Native BYOND 516.1688, OpenDream, client asset cache and in-game visual/focus
validation are not established by DOM/browser or source tests.

## Licenses

Civ13 application code follows the repository AGPL-3.0 license. `tgui-core`,
React and React DOM are MIT; copies of their notices are in `licenses/`.
The generated bundle references the complete generated
`UI/tgui/THIRD_PARTY.txt` notice file distributed beside it. No old Giacom files, unrelated tgstation graphics,
font packs or interface code are copied. See `THIRD_PARTY.md` for the exact
bundled dependency inventory and source provenance.
