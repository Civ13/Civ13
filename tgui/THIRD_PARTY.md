# Third-party provenance

The build uses the official tgui6 component architecture, pinned to
`tgstation/tgstation@bf6f771a1e221e06938978e36bbaf78543f85ebe`.
No upstream application files or game assets are copied. Civ13 screens and
transport are locally authored.

Complete production-dependency license text and versions are generated in
[`UI/tgui/THIRD_PARTY.txt`](../UI/tgui/THIRD_PARTY.txt) from installed locked
packages by `node scripts/licenses.mjs`. React, React DOM and tgui-core source
notices are also retained in `licenses/`. The npm lockfile records integrity.
