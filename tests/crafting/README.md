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
