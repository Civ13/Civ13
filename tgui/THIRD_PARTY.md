# Third-party provenance

The build uses the official tgui6 component architecture, pinned to
`tgstation/tgstation@bf6f771a1e221e06938978e36bbaf78543f85ebe`.
Civ13 screens and transport are locally authored, with one exception: the
integrated circuit editor. The `.jsx` and `.ts` files in
`src/interfaces/IntegratedCircuit/` and `src/interfaces/common/Connections.tsx`
are copied unchanged from
`tgstation/tgstation@bacb22efd80de34f9b992ec3c731a1321147119e`
(`tgui/packages/tgui/interfaces/`). `IntegratedCircuit.scss` is the
`tgui/packages/tgui/styles/interfaces/IntegratedCircuit.scss` of that revision adapted
to the tgui-core style modules, and `grid_background.png` is the same revision
`icons/ui/tgui/grid_background.png`, unchanged. That source carries no
per-file licence header, so it is under the /tg/station parent licence, AGPL-3.0
(the same as Civ13); the image is CC BY-SA 3.0 under the /tg/station asset notice.
Credit: the /tg/station 13 contributors. Imported by Terrariola (GitHub
`Terra1`); `src/interfaces/WiremodCircuit.tsx`, `src/backend.ts`,
`src/assets.ts`, `src/layouts/` and `wiremod-compat.scss` are the Civ13
adapters. No other upstream application files or game assets are copied.

Complete production-dependency license text and versions are generated in
[`UI/tgui/THIRD_PARTY.txt`](../UI/tgui/THIRD_PARTY.txt) from installed locked
packages by `node scripts/licenses.mjs`. React, React DOM and tgui-core source
notices are also retained in `licenses/`. The npm lockfile records integrity.
