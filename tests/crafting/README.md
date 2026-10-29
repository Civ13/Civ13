# Compiled recipe validation

Run from the repository root with BYOND 516.1681:

    python3 scripts/check-recipes.py --report recipe-checks.txt

On Windows use a verified Python executable and pass full paths to --compiler
(dm.exe) and --runtime (dd.exe). The installed default BYOND may be older.

The runner compiles the real game definitions and tests the compiled type tree.
It removes maps/UI and substitutes isolated startup bodies in generated sources
only. It bypasses world/global/controller startup, disables hub advertising,
copies only crafting/name inputs to temporary storage, uses an ephemeral daemon
port, and cleans generated DME/DMB/RSC and runtime state on completion/timeout.
No game server configuration, SQL, saves, Discord bridge or production processes
are loaded. Compiler and daemon execution are bounded to 180 and 90 seconds.
A missing completion report, compiler warning/error or runtime error fails CI.
The daemon's Windows account login message is engine behavior, not a game login.

## Coverage

`canopy.dm` adds both original paid canopy routes, real roof/area creation and
retirement, competing unfold/fold actions, late destination occupancy, protected
independent roofs, legacy shared cover and neighbor icon states. It expands the
isolated map to 4x3 tiles; normal game dimensions remain unchanged. Existing 35 ds
canopy waits run normally. No client rendering or saved-world acceptance implied.

`sofa_materials.dm` checks the three existing eight-cloth sofa recipes and their
three map-only chair variants. Fixed upholstery must reject padding without
debit and refuse generic wood recovery. An ordinary bed control still accepts
paid cloth/leather padding and returns exactly one unit on removal, as does a
wooden stool. Actual padded bed/stool hammer paths return paid cloth/leather or
refuse frame output/deletion for unmapped padding. Bed-wait cancellation and late
unmapped-padding controls preserve installed material. An unpadded wooden-bed
hammer control keeps its existing recovery. No new sofa recipe,
art or connected-client acceptance is implied.
The steel-frame comfy-chair control also refuses generic wood recovery.

`document_drawers.dm` checks paid planks/pegs, document-only admission and late
occupancy/tool/research rejection through the existing joinery action. It does
not exercise the connected retrieval browser or establish save/world acceptance.

`rope_hammock.dm` adds paid six-rope construction, short-stock and occupied-turf
refusal, unoccupied processing and legal-hand hammer-refund checks. It uses the
existing inert actor adapters and does not establish suspension physics or
connected gameplay. See `docs/rope-hammock-audit.md` for scope and history limits.

- All active config/crafting/material_recipes_*.txt rows, including map/faction
  lists: 13 fields, canonical compiled material paths, compiled object outputs,
  positive (including fractional) costs, numeric flags, nonnegative time/research
  and age caps, and registered supplied material names.
- Each valid material row must appear through production generate_recipes_civs,
  including grouped menus, with declared research thresholds satisfied. The real
  research tree is initialized, a temporary faction has all nodes marked done,
  age is zero, and resource-research and Chad modes are enabled so conditional
  recipes are not mislabeled broken.
- Compiled anvil entries: menu lookup key matches display name, item output,
  nonempty age window and at least one positive material alternative.
  Costs are alternatives, not a requirement to supply all metals.
- Production stack produce_recipe, use and can_use methods execute with explicit
  constructor/fingerprint/religion adapters. Tests assert exact consumption and
  output quantities, and rejection for insufficient ingredients and occupied
  one-per-turf output.
- Thirteen deliberately invalid row fixtures must produce diagnostics.
  A valid fractional-cost inherited-output fixture must be accepted.

## Food bootstrap gate regression

The normal run also checks a separate unresearched Stone Age faction against all
real global recipe rows, without the catalog fixture's all-nodes-DONE state.
It verifies the two-log wooden knife, two-stone hatchet and eight-plank research
bench, then checks that 94 Basic Agriculture study ticks leave the plough locked
and the 95th unlocks its four-plank recipe. Raw logs are rejected for that recipe.
The starter bench can select Basic Agriculture; irrigation rejects missing
prerequisites and requires bench tier one. Era advancement grants neither
specialist irrigation nor Basic Agriculture to an established faction whose
baseline was Stone Age. A factionless Bronze Age player gets the Main-tree grant.

For a local mutation control, add `--food-bootstrap-negative-control`. A generated
research-node source maps the wooden plough to the baseline Basic Tools node.
Success requires exactly the two premature-plough diagnostics, with no compiler
warnings, runtime errors or other catalog failures. Production sources are not
modified. The normal CI command is unchanged; this extra control is opt-in.

These are recipe eligibility and production study-accounting contracts. The
fixture supplies ticks directly and a bench instance, without simulating a
connected authorised researcher, natural resources, faction founding, timed
crafting, player movement, permissions, bench upgrades or seasons. See
[the bootstrap route checklist](../../docs/outdoor-crop-bootstrap.md). They do
not complete natural-map acceptance under #3048 or irrigation acceptance #3049.
## Catalog repairs

Path spelling/whitespace, missing slashes, incorrect material names, a malformed
pimp-coat row, named-argument text in boolean columns and the Mesh Pickelhaube
anvil lookup mismatch are corrected to existing definitions.

Legacy rows without a compiled target (removed SS13 department stamps,
sandstone arrowheads, two pygmy uniforms) are individually retained as disabled
comments naming the nonexistent path. Fossil conversion rows are also disabled
individually: fossil stack objects currently use the stone datum and there is no
/material/fossil datum, so those rows could never register. This does not add
working substitutes or change ingredient balance. Reenable a row only after
restoring its definition and verifying its intended interaction.

## Furniture joinery

The fixture also includes `furniture_joinery.dm`: actual global peg-jointed
table/chair/bed and dowel-set construction, exact dual debits, tool reuse,
rejection after tool/stock/research/save changes, occupied tiles, cancellation,
last-set hand cleanup and competing waits. It also checks preset log/plank
subtypes and rejected crafting XP. Assembly tools lie
on a separate clear fixture tile, rather than invalid equipment slots; tools at
the player's feet are a supported production route. Character startup uses the
existing handle fixture adapters; this is not connected-player acceptance.
Research rejection controls temporarily move the required node beyond the
fixture faction's baseline, then restore its actual tier after the action.
An era-0 Main-tree node is already granted at baseline zero even with an
incomplete entry. The controls check both initial denial and revocation during
the wait; this controlled metadata change does not change gameplay gates.
Wooden-shelf assertions additionally cover its six-plank debit, subtype fields,
destruction, broken parts, top/frame disassembly, frame wrenching and cancellation.
Use `--compile-only` to compile the isolated fixture without starting DreamDaemon.
That option explicitly reports runtime checks as not run. It cannot certify
recipe registration or any native assertion. See `docs/furniture-joinery-audit.md`.

`cloth_bedroll.dm` additionally uses real four-unit cloth/leather construction,
three fold/unfold cycles per type, refusal to fold used bedding, and ordinary
backpack insertion/removal. Hammering either textile bedroll must preserve the
bedroll and produce no wood. See `docs/cloth-bedroll-audit.md` for the inherited
generic-structure refund finding and the historical/gameplay distinction.

## Limits

Green CI means covered schema/registration contracts and the generic crafting
fixture passed. It does not mean every item is obtainable or every declared
recipe succeeds in every game mode. This does not run all output constructors,
interactive customization prompts, timed builds, tools/stations, skill or
religion requirements, location restrictions, subtype/reagent acquisition,
noncraft sources, progression dependencies or inventory interactions. Anvil
menu interactions are checked structurally, not clicked. Ammunition attackby,
smelting, clay firing, food/chemistry and other bespoke transformation handlers
are outside this catalog checker. Runtime associative lists cannot reveal
duplicate anvil keys overwritten at compilation.

Do not infer unobtainability from a missing recipe output: maps, loot, vendors,
gathering and other transformations also supply ingredients. This is a bounded
regression gate, not a universal craftability/reachability solver.

## Optional genuine gameplay replication

The opt-in gameplay adapter is excluded from the production DME and CI schema
fixture. It requires a nonce plus a local admin client, refuses remote requests
and multiple clients, and supplies only isolated test inputs/progression.

1. From a clean checkout run tests/crafting/start-gameplay.ps1 -ByondBin
   <trusted-516.1681-bin>. It prints session.json and an unused localhost port.
   The full game runs with temporary config/SQL/UI, hub advertising disabled,
   and webhook, ToRban and shell execution adapters disabled.
2. Connect a fresh Dream Seeker to the printed localhost URL. Use
   tests/crafting/query-gameplay.ps1 -SessionJson <printed-file> -ByondBin
   <trusted-bin> -Action prepare, then status until state is 3, then join.
3. Query action road. In the actual stone crafting menu open roads, choose
   smooth modern road (1 stone), and close the menu. Query inspect: expect an
   /obj/covers/roads/modern output and input_remaining 9. Capture the selected
   menu and the actual resulting road/HUD.
4. Query action helmet. Use the held steel on the supplied steel anvil, choose
   helmets, then Mesh Pickelhaube Helmet (6 steel), and remain still through
   the normal timed build. Query inspect: expect the real pickelhaube2 output
   and input_remaining 14. Capture the menu, build sequence and result.
5. Record the session commit, Nomads map name/dimensions, compiler log, inputs,
   output observations and real client screenshots/video. Supplies, trained
   skill, clear local test tile and completed research are test setup; neither
   output is injected by the adapter. This samples two repairs, not all recipes.
6. Stop only the daemon PID recorded in this session and its own client when
   capture is finished. Keep logs/manifest; upload media as verified direct PR
   attachments and remove local media only after URL verification.

### Explicit procedure-test alternative

When native tooling cannot target BYOND's embedded WebView, the road-procedure
action locates the real generated catalog datum and calls production
produce_recipe. The helmet-procedure action calls production anvil attackby in
an isolated source copy: its dialog boundary delegates to the original WWinput
except during this explicit test action, which injects only selections present
in the actual offered lists. It records all offered lists/selections. Recipe
lookup, age/skill/material checks, timed build, consumption and output creation
are unchanged. It neither creates nor substitutes output objects itself.

These are adapter-driven production procedure tests, not menu clicks. Capture
the actual game and result plus the prominently labeled dialog trace. Retain
the manually offered stone menu observation separately. No universal gameplay
reachability or native menu input acceptance is inferred. Stage setup closes
only local character popups and grants fixture visibility for inspecting output.

## Camera prototype progression

The normal runner checks two established Cold War factions through production
recipe generation and research completion. One reaches Modern first; the other
retains the seven-electronics cold-war camera required by Digital Computing.
The modern camera parent does not match that subtype. Assembly Line and full
study/prototype requirements remain enforced. Study and prototype flags are
supplied directly; this is not connected-player submission or timed crafting.
`--camera-prototype-negative-control` restores the old era-seven cap in temporary
runtime recipe data and must detect exactly the lost paid prototype recipe.
