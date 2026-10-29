# Finite authored-room topology tool

This is the first independent source slice of the
[Liminal Facility design](../../docs/liminal/README.md). It assembles a small
finite chapter from original room families, checks physical sockets, zones,
footprint clearance and abstract objective/lock/exit reachability, then writes a
reproducible JSON bundle. It is not a registered or playable Civ13 game mode.

**Room-layout status:** This tool still uses the version-1 room catalog. Its
corresponding [room-layout previews](../../docs/liminal/ROOM-PREVIEWS.md) were
rejected as room designs. A successful topology check verifies the stated graph,
clearance and progression rules; it does not approve the layouts for a mode.
Revised room design and native integration remain separate work.

Run from a complete repository checkout with Python **3.11+**. Only the standard
library is used; no pip installation, engine, assets or native save is required:

```sh
python3 -m tools.liminal_maps preset --seed liminal-0 --out data/liminal/config.json
python3 -m tools.liminal_maps generate --config data/liminal/config.json --out data/liminal/chapter
python3 -m tools.liminal_maps validate data/liminal/chapter/plan.json
python3 -m tools.liminal_maps verify data/liminal/chapter
```

On Windows use a verified full Python executable, for example:

```powershell
$Python = 'C:\Path\To\Python\python.exe'
& $Python --version
& $Python -m tools.liminal_maps preset --seed liminal-0 --out data/liminal/config.json
& $Python -m tools.liminal_maps generate --config data/liminal/config.json --out data/liminal/chapter
& $Python -m tools.liminal_maps verify data/liminal/chapter
```

Every destination must be new, including an incomplete earlier output. Existing
files/directories, symlink/reparse output components and native saves are refused.
JSON inputs have a 2 MiB cap and reject duplicate keys/nonfinite values. Exit0
means the requested offline operation passed; bounded rejection returns1 and
writes rejection.json with every candidate outcome. Input/output errors return2.
There is no silent retry/repair, world read or player-change overwrite.

## What the small recipe implements

The catalog contains ten original families and five alternative office hubs.
The recipe is arrival -> selected hub -> threshold -> service -> extraction,
with an optional authored discovery alcove. Discovery grants FOUND_MARKER;
service requires it and grants SERVICE_DONE; the final door edge and exit require
service. These are monotone symbolic flags. Native interaction, locks, threat
AI, extraction timing and player inventory are not evaluated by the tool.

The original authored masks are in room-archetypes-v1.json and match the frozen
design catalog. W/B cells are wall/solid-prop intentions; F is clear floor and
V is sealed void. Physical socket apertures must mate with matching facing/type/
width; unused sockets seal. The stored blueprint must reconstruct exactly from
the authored masks and links. The actor's full square footprint, not only a room
graph, must reach the required objectives/rooms/exit.

Config controls are documented in
[ROOM-GENERATION.md](../../docs/liminal/ROOM-GENERATION.md). Use example-config.json
or preset, then edit the new file. Bounds and invariants are validated before
candidate work. max_rooms is a resource cap, not a target room count. Full config,
including budgets, is part of the seed frame; replay requires the exact config.
The default recipe has six rooms and no general maze, return-loop or multi-level
facility generator. Only rotation0 and HUMAN_DOOR sockets are implemented.
Unsupported portal/service/hatch types reject explicitly.

`generate --reverse` reverses room/link raster construction and retains the same
canonical document/manifest. Outputs are plan.json, manifest.json, proof.json and
complete.json. Keep them together. Completion hashes plus semantic revalidation
bind config, catalog and versions; an edited/tampered bundle rejects.

The bundle also includes level-template.json and escape-scenario.json. Immutable
template identity excludes escape gate predicates and mutable/scenario state;
it is not a live or inhabited-level instance ID. No instance is created or reset.
The separate escape specification defaults to scenario year **1990**; use
`generate --scenario-year 1991` for another initial-policy year 1990-1993.
Changing the year changes the scenario identity without resetting geometry.
It records PENDING period equipment/prop/recipe/research allowlists, not actual
native filtering. Native readiness remains false. The powered-gateway scenario
is owned separately and can consume the template contract without inheriting
escape objectives, power logic or a mutable instance reset.

The default semantic topology SHA-256 is
`6e4e1946ee62525bad82681d6b7cb5b0d2b8d8c03472b8856009108a93bcad40`.
This is a small authored topology fixture, not a seed matching a game/show scene.

## Native boundary and contributions

No DMM, image, sprite, audio file, native game object or mode registration is
created. Indoor native palette/DMM emission and the finite mode adapter are the
next design slices; the Nomads terrain exporter is not reused as an indoor
palette. Critical walls/props/gates require source-backed native mappings and
must not be silently dropped into sidecar-only semantics.

No external assets are copied. Source/RNG/IO provenance is in SOURCE-PROVENANCE.json.
Original code and room data use the repository license. Third-party art ports,
including individual CC-BY-SA files, need separate provenance/compatibility
review; no blanket repository license assumption is made.

Run the explicit offline tests:

```sh
python3 -I -B tests/liminal_maps/run.py --report data/liminal-tests.json
```

Add a focused negative control for each new contract, preserve old hash vectors
or bump content/algorithm/profile versions, and update the design/catalog mirror
deliberately. Never mix native engine launchers or wildcard native-test discovery
into this bounded offline test runner. Passing tests do not prove native
appearance, collision, lighting/audio, threats, timers, group play or survival.
