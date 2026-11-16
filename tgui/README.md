# Civ13 tgui frontend

This is a Civ13 adaptation of the current official tgui component architecture,
not a wholesale /tg/station runtime port. Reference: tgstation/tgstation
`bf6f771a1e221e06938978e36bbaf78543f85ebe`, tgui 6.0.0, 2026-10-30.
The component package is upstream's integrity-pinned `tgui-core` 6.1.1 with
React 19.2.7. Civ13's application, screen components and bridge are new code.
See [how windows work and how to add one](../docs/tgui/README.md).

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

Modern assets target Edge/Chromium >=123, the browser in BYOND 516, which is
the minimum client. The ES5 bootstrap checks the actual browser before loading
them and installs the early update queue. There is one renderer: no classic
NanoUI templates, no **Classic interface** button and no server startup
watchdog. If the browser cannot run the screen, the assets fail to load, startup
times out or a screen throws, the window says it could not load and asks the
player to close and reopen it.

A few windows keep a complete plain page of their own for content the modern
screen cannot show (old imported markup in books, Notes, flavor text and
documents, and the Crafting Atlas page). They declare it with
`has_plain_page()`; the browser's `fallback` message, or the window itself,
switches such a window with `show_plain_page()`, and it keeps that page until it
closes. A prompt ends instead, so the caller shows BYOND's own dialog, and the
Crafting window hands over to the plain recipe list.

React mounting sends `ready` but leaves the 15-second browser startup timer
pending. Only a valid snapshot matching this UI ref, window and generation
completes client startup and sends `ack`. Close invalidates the generation. Mob
transfer invalidates startup state before the new mob has a client; the
post-key-assignment hook reopens only after reciprocal binding to the intended
client is confirmed, then starts a new handshake. Modern gameplay actions
require ready and acknowledgement in addition to the existing
owner/status/generation checks. Pre-ack actions are rejected; a later ack does
not queue or replay them.

`node tests/tgui/bootstrap.test.cjs` executes the actual bootstrap with fake
transport and clocks. Its server side is a model using the production guard
expressions, not DM execution. The production-bundle JSDOM check uses the real
bootstrap, completes ready/snapshot/ack and rejects a stale-generation
snapshot. Native Topic delivery, cache, focus and transfer still require
separate authorized acceptance.

NanoUI owns windows, authorization, processing and cleanup. Modern actions go
through a UI-datum ref, window id and generation token; the backend allowlists
one action and its payload keys and rechecks ownership/status before dispatch.
`src/data.ts` declares the snapshot each window receives, with every field
optional, and a screen takes it as `ScreenProps<ItsData>`. `src/fixtures.mts`
holds one fictional snapshot set for every window; fixtures of typed windows
are checked against those types. `src/fixtures.test.tsx` fails when a
registered window has no fixture or does not render from it. Add the type and
the fixture with any new window.

`node tgui/scripts/screenshots.mjs` renders every fixture from the production
bundle in Chromium at the size the game opens the window, and writes one PNG
per window plus an `index.html` gallery into `SCREENSHOT_DIR`. CI uploads that
folder as the `tgui-previews` artifact.

Server text may arrive entity encoded. `updateState()` decodes every display
string in a snapshot once (`decodeData()` in `src/state.ts`), so a screen shows
a field as it is and never calls a decoder. Fields named `id`, `key` or ending
in `_id` are left untouched because they go back to the server. The document
windows listed in `documentTemplates` (book, paper, Notes, flavor, photo) get
their snapshot exactly as sent and validate it themselves. Tests that render a
screen directly import `render` from `src/testing.tsx`, which takes the same step.

A request is one declared action with an optional `value` and the extra fields
the owner names in `ui_action_fields()`; text and numbers arrive typed. An owner
that defines `ui_act(action, params, user, ui)` handles it there and needs no
`Topic()`; other owners still receive it as href-style text, with the action
naming its value.
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
