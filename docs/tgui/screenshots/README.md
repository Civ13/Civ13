# Window previews

Production-bundle screenshots of every tgui window, captured on 2026-11-16 by
Chromium 153.0.8010.12 with Playwright from the fictional fixtures in
`tgui/src/fixtures.mts`. They are cloud browser previews, not checks in a BYOND
game client. No player or server data is used and nothing is retouched.

Source: `71e5dd4830a27deaa297558fb6a7fd7b9e19ed8c`. Device scale factor: 1. Each window is captured
at its in-game width. [provenance.json](provenance.json) records the browser,
head, viewports and full fixture inputs.

Reproduce with Node 24: `npm ci --ignore-scripts --prefix tgui`,
`npm --prefix tgui run build`, then
`SCREENSHOT_DIR=docs/tgui/screenshots CHROMIUM_PATH=/path/to/chrome PREVIEW_SOURCE_HEAD=$(git rev-parse HEAD) node tgui/scripts/screenshots.mjs`
(delete the `index.html` it also writes). CI captures the same gallery as an
artifact on every tgui change; refresh the committed copy after a visible change.

| Window | Template | Viewport | Image |
| --- | --- | --- | --- |
| Research | `research_bench.tmpl` | 900 x 1016 | [research.png](research.png) |
| Faction | `faction_creation.tmpl` | 620 x 1154 | [faction.png](faction.png) |
| Chemistry | `chem_disp.tmpl` | 390 x 655 | [chemistry.png](chemistry.png) |
| Warehouse | `warehouse_book.tmpl` | 400 x 500 | [warehouse.png](warehouse.png) |
| Religion list | `religion_list.tmpl` | 450 x 450 | [religion-list.png](religion-list.png) |
| Ship stocks | `ship_stocks.tmpl` | 500 x 520 | [ship-stocks.png](ship-stocks.png) |
| Crew log | `crew_log.tmpl` | 500 x 520 | [crew-log.png](crew-log.png) |
| Faction list | `faction_list.tmpl` | 420 x 520 | [faction-list.png](faction-list.png) |
| Known languages | `known_languages.tmpl` | 600 x 480 | [known-languages.png](known-languages.png) |
| Iron safe | `panel.tmpl` | 380 x 420 | [panel.png](panel.png) |
| Prompt | `prompt.tmpl` | 420 x 240 | [prompt.png](prompt.png) |
| Vending | `vending_machine2.tmpl` | 540 x 600 | [vending.png](vending.png) |
| Recruitment | `recruitment_station.tmpl` | 520 x 961 | [recruitment.png](recruitment.png) |
| Crafting | `crafting_window.tmpl` | 940 x 694 | [crafting.png](crafting.png) |
| Atlas | `crafting_atlas.tmpl` | 1000 x 714 | [atlas.png](atlas.png) |
| Appearance | `appearance_changer.tmpl` | 800 x 453 | [appearance.png](appearance.png) |
| Vending payment | `vending_machine2.tmpl` | 540 x 600 | [vending-payment.png](vending-payment.png) |
| Vending plain | `vending_machine.tmpl` | 540 x 600 | [vending-plain.png](vending-plain.png) |
| Vending gulag | `vending_machine_gulag.tmpl` | 540 x 600 | [vending-gulag.png](vending-gulag.png) |
| Vending market | `vending_machine_taotd.tmpl` | 540 x 600 | [vending-market.png](vending-market.png) |
| Faction symbol | `faction_symbol.tmpl` | 620 x 836 | [faction-symbol.png](faction-symbol.png) |
| Book | `research_book.tmpl` | 620 x 839 | [research-book.png](research-book.png) |
| Mara Flint | `character_flavor.tmpl` | 500 x 200 | [character-flavor.png](character-flavor.png) |
| Notes | `character_notes.tmpl` | 625 x 650 | [character-notes.png](character-notes.png) |
| Photograph | `photo_viewer.tmpl` | 360 x 400 | [photo.png](photo.png) |
| Book | `book_reader.tmpl` | 625 x 650 | [book.png](book.png) |
| Paper | `paper_editor.tmpl` | 625 x 650 | [paper.png](paper.png) |
