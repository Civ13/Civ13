# Remaining in-game UI migration

## Independent flavor reader checkpoint

At master `1c41467e`, Known Languages, Ship Stocks, Religion List, Crew Log,
Faction List and Crafting Atlas are merged, for sixteen modern routes including
the original ten. Photo #3470 and Notes #3471 are separate proposed readers.
The next local slice is the expanded character flavor More... reader, described
in [character-flavor.md](character-flavor.md). It needs no unmerged rich-text
parser or new dependency. Paper/books still need pencode/literacy contracts;
noticeboard writing depends on item/prompt workflows. Help, HUD, preferences
and manager owners retain their separate lanes. The historical inventory and
initial Known Languages checkpoint below are retained as dated source context.

Inventory baseline: `5255b72a3f40b52b6eb92599d29335cb4f4d81a2` (remote master
verified 2026-11-01). Main reports that baseline deployed; this source task did
not inspect or operate the live server. #3427 is merged. Its modern adapter is
the default for the ten converted NanoUI screens, with capability/classic
fallback. This plan extends that work; it does not reimplement it or claim every
game screen is already converted. Save/movement fixes remain higher priority.

## Baseline inventory and counting rules

The exact-source lexical scan covers 1,351 DM files. It finds 135 `browse()`
open candidates plus 3 browser-wrapper sites in 79 files, separately from 54
close calls, 4 empty-page clear calls and 6 browser transport callbacks. These
are call sites, not 138 unique screens: redraws, aliases, wrappers, hidden asset
probes and several views sharing a window ID are included. Reachability needs
per-family review. The review packet retains the full file/line/context CSV,
JSON and reproducible scan/grouping scripts; no runtime/player data was read.

The ten existing screens have 11 producer sites because one vending variant
has two branches. They are appearance, chemistry dispenser, warehouse, four
vending templates, research, faction creation and faction symbol. The retained
12 classic `.tmpl` files are ten compatibility screens plus two layouts, not
twelve unported screens. The generic NanoUI browse emitter is infrastructure.
Unused PC/map layout hooks are not evidence of completed application migration.

There are also 1,057 native input/alert wrapper call sites, 97 `/obj/screen`
type declarations and 54 engine-window-control calls. These are prompts,
widget/types and focus/host operations, not equivalent screen counts. The DMF
has five top-level windows: `mainwindow`, `mapwindow`, `rpane`, `outputwindow`
and `infowindow`. Existing chat and status/verb panes are HTML CivUI, but use
different lifecycle/protocols and have not been migrated merely by #3427.

The browser-family grouping below assigns every candidate file once by its
primary purpose. Mixed files (for example lobby plus wiki links) contain more
than one kind of surface; the raw call inventory retains that distinction.

| Family | Files / candidate sites | Representative surfaces and source |
| --- | --- | --- |
| Personal readers, help, ship ledgers | 5 / 10 | Known Languages (`game/mob/language/language.dm`), Notes/memory (`datums/mind.dm`), flavor/help (`game/mob/mob.dm`), Player Help, voyage Crew Log/Ship Stocks. |
| Paper, books, photos, noticeboard | 7 / 16 | Paper reading/writing, bundles, folders, clipboards, notices, photography and `modules/1713/book.dm`. |
| Inventory and containers | 4 / 4 | Carbon/human equipment views, filing cabinets and safes. |
| Crafting, gunsmithing, chemistry | 5 / 10 | Crafting Atlas, stack crafting, gunsmith/rechamber, ChemMaster/Condimaster/Pill Maker and dartgun. |
| Shops, vendors, economy | 7 / 15 | NPC shops, supplier stalls, fuel-pump buy/manage/refuel, vendor management, marketplace/member lists, Pepelsibirsk traders and magical vendor. Four vending storefronts are already modern; these other workflows remain. |
| Groups, teams, voting | 4 / 12 | Faction/religion lists, football jerseys/team creation and vote panels. Faction founding/symbol editor are already modern. |
| Instruments | 4 / 4 | Piano, violin, trombone and shamisen editors/playback controls. |
| Map, vehicle, combat, mode controls | 11 / 22 | Minimap/coordinates and map tools, ship wheels, radios, catapult/artillery/turret, gladiator control, wand controls, wizard sorting and submarine controls. |
| Computer desktop/programs | 2 / 2 | `modules/1713/computers/os.dm` and `programs.dm`; dynamic program markup and PC layout hooks require a program/action inventory before conversion. |
| Collectibles/embedded pages | 2 / 4 | Sticker albums, album readers and embedded external card pages. |
| Lobby, character setup, preferences | 4 / 8 | Pregame/title card, player setup, late choices, preferences. Also audit `new_player/preferences_setup.dm` and `client/preferencesSQLite/preference_setup/**`, which generate controls without opening their own window. |
| Admin/diagnostics | 16 / 21 | Player/notes/info panels, create mob/object/turf, permissions, variable editor, logs, process/GC views, age checks, error viewer, sticker and submarine admin panels. |
| Browser chat | 1 / 1 | `modules/chat/chat.dm`, `interface/chat/chat.html`, input/output/focus behavior. |
| Browser status/verbs | 1 / 1 | `modules/statpanel/statpanel.dm`, `interface/info/info.html`; status updates, verb categories and command dispatch. |
| External navigation | 1 / 1 | Client wiki viewer; additional wiki/card links occur inside mixed families. Modernize the in-game navigation frame without pretending an external website is repository-owned UI. |
| Infrastructure/retained renderer | 5 / 7 | Browser helper/macro, NanoUI emitter, asset-cache probes and hidden map-image generation. Reuse/support these; they are not seven extra player screens. |

All source paths in the table are relative to `code/` unless prefixed by
`interface/`. The full inventory supplies exact paths and line numbers for all
79 files, including surfaces not named individually in this summary.

## Existing plans and ownership

- Preserve the architecture/reference/licensing decisions in
  [upgrade-plan.md](upgrade-plan.md), and the unrun native cases in
  [native-acceptance.md](native-acceptance.md). Browser renders and CI are not
  native acceptance. Do not start another UI manager/window-pool implementation.
- [Character discoveries](../character-discoveries.md) and
  [nutrition design #3313](https://github.com/Civ13/Civ13/issues/3313) constrain
  Notes: only learned information may reach the client, same-life persistence
  must remain intact, and UI rendering must not mutate saved records. This is
  a later reader migration, not permission to change nutrition or save models.
- Reuse the existing [Crafting Atlas](../crafting-atlas.md),
  [Player Help](../player-help.md) and character-return/reclaim contracts.
  Do not rebuild their retrieval, crafting or save behavior as UI work.
- Focused accessible issue/PR searches for TGUI/NanoUI did not locate a separate
  open umbrella migration task. This is a bounded search result, not proof that
  no older design exists. No issue, PR or archived Claude task was revived.
- The existing TGUI task owns this private preparation. No competing active
  TGUI implementation owner was found in accessible task records. Main owns
  scope review; preferences/Notes/vehicle work must defer to save/movement owners.

## Dependency order

1. **Shared read-only foundation and Known Languages (current source slice).**
   Reuse the default adapter/manager, add owner-only read-only topic state that
   still permits observers, and retain a real classic template. No server
   action, mob save field, polling service or movement lock is needed.
2. **Other bounded readers.** Crew/stock ledgers and simple faction/religion
   lists can share structured read-only components after preserving role gates.
   Notes, papers, books, photos and Help need structured rich-text/image policy,
   existing sanitizers and private-knowledge filtering before rendering; never
   pass arbitrary stored HTML through React. Atlas keeps its bounded query and
   pagination APIs. Do these in separate small patches.
3. **Typed prompts and cancellation primitive.** Many already modern screens
   still invoke native color/text/number/choice prompts. Design a bounded
   request/result service on the current owner/window/generation contract,
   with typed finite choices, server validation, deadlines, explicit cancellation
   and native fallback. Preserve awaited-proc cancellation semantics and keyboard
   focus; do not replace all 1,057 call sites mechanically.
4. **Interactive transactions and item workflows.** Migrate vendors, fuel,
   crafting, inventory/containers, group/team/vote actions and instruments in
   bounded families once needed prompts exist. Keep each domain handler's
   distance, membership, role, payment/conservation and post-wait checks. Never
   trust client disabled flags or expose arbitrary href/verb forwarding.
5. **Preferences, lobby and program host adapters.** After save/character work
   settles, define bounded client/preferences/admin host adapters using the
   existing manager. Preserve SQLite validation, character/trait rules, join
   readiness, draft/apply/cancel behavior and current body identity. Computer
   programs need explicit per-program actions; unused PC hooks are not a port.
6. **Privileged panels and integrated shell.** Admin tools need per-action
   rights checks and bounded/private data schemas. Chat/status panes need
   separate entry/lifecycle integration while reusing components/transport
   safeguards; do not import the current broad command/proc fallback into a
   general modern action router. Vehicle/combat controls wait for movement
   work and require held-key release/focus/cancellation acceptance.
7. **Engine-boundary review.** MAP rendering, native INPUT and OUTPUT hosting,
   macros and `/obj/screen` widgets cannot be restyled by substituting an HTML
   template. Modernize surrounding panes/themes and suitable HUD overlays only
   after Main reviews the boundary. Retain engine map/input controls and
   persistence exclusions until an explicitly verified replacement exists.
   These surfaces stay on the inventory; they are not silently omitted.

Across every phase, use semantic headings/lists/labels, keyboard-operable
controls, visible default/selection/busy states, readable contrast, focus
restoration and explicit close/cancel. A native fallback stays available during
migration. No automatic cutover based only on a screenshot is implied.

## Current source slice: Known Languages

The IC verb now builds only the actor's existing visible language list. It
preserves the `NONGLOBAL` filter, prefix, description and living default marker;
values are escaped for classic templates and decoded as inert React text.
An owner-only `self_read_only_state` returns update-only status even for an
observer, retaining the original reader's access without permitting actions.
The route has no action allowlist entry and no domain controls.

The view uses a small adapter subtype to route manager refreshes back to its
own data producer. There is no new mob field, save change, auto-update loop,
`using_object` assignment or movement code. The shared adapter still owns ready/
snapshot/ack, fallback, generation, close/logout and transfer handling; moving
to another body fails the old self-owner state instead of exposing that body's
private view. Reopening the verb refreshes current data. The new template is
included by the existing asset-directory discovery.

The reader disables the inherited legacy close side effect before opening:
native `nanoclose` still closes and unregisters this UI, but cannot clear an
unrelated `using_object` interaction through its no-ref callback branch.
The concurrent machine-window/native-close acceptance case remains unrun.

The source patch includes React empty/default/text-escaping tests, owner/filter/
movement boundary source contracts, actual classic doT template compilation and
production-bundle JSDOM rendering. It also extends the existing frontend CI path
selection for the language producer and classic compiler dependency. It has not
been compiled in BYOND, exercised natively, published, merged or deployed.
Native observer access, real asset delivery, focus/movement, scroll/close and
body-transfer behavior remain explicit future acceptance work after scope review.
