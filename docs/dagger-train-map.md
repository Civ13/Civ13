# Dagger train home: enlarged map draft

This is an **inactive map study**, with editable DMM output and a declarative
layout manifest. It is not selectable, does not load player saves, and adds no
shuttle controller or transport callback. The prototype is original Civ13
geometry using existing Civ13 turf and furniture types.

Revision 3 moves the helm and engine room inside the protected compartment.
Both train dimensions and both staging dimensions are doubled from the original
smaller draft. The world still has two
levels; this changes the WIP source only and allocates no live instances.

![Source layout diagram, not gameplay](images/dagger-train-map-preview.png)

## Layout

The train occupies a fixed **30 x 102 tile** rectangle, facing north. A four-tile
central passage links its main work areas. One **256 x 256 x 2** staging map contains
the prototype at a western home slot on z1, an empty eastern home slot, and two
empty raid berths on z2. Both z-levels have equal dimensions. The two home slots
demonstrate isolation and reuse requirements; they do **not** establish a
production train, crew, bed, or party-size cap.

| Local space | Purpose | Required protection |
| --- | --- | --- |
| Rear rooms, y0..38 | Bunks, gear lockers, party stores, mess/kitchen counter, wash stalls, treatment, engine room and upgradeable helm controls | Owning party only, including while raid-docked |
| Airlock, x12..17/y39..45 | A 4 x 5 vestibule between two distinct door placeholders | Party-only entry from either side; two-door interlock required |
| Centre carriage, y46..77 | Receiving stores, two 9 x 10 build pads, crafting/sorting benches and boarding cross passages | Exposed to boarding and looting |
| Forward rooms, y80..100 | Separate utility maintenance, spare-parts storage and forward cargo | Exposed |

The interior is redesigned with fifteen distinct room/working zones instead of
enlarging the old furniture. Six crew bunks have individual gear storage; two
treatment beds are separate from sleeping and eating spaces. Wash stalls have
privacy doors. Receiving stores, workbenches, large build bays and forward spare
stores support different activities. Bunk and furniture counts are not crew caps.

Four three-tile side openings at local y52..54 and y68..70 support two approaches
on either side. Each raid berth has two 7 x 3 boarding links to a sixteen-tile
shared platform. Both 9 x 10 build pads sit outside the four-tile spine and both
boarding cross passages, which remain connected with the pads fully occupied.
Worn floor patches and displaced station cargo suggest a repaired, scavenged
train rather than a pristine base.
The draft does not grant free production resources or decide starter inventory:
these are prototype furniture placements, not an accepted economy loadout.

The former quiet repair room is split into an engine room at x18..28/y27..31 and
a helm room at x18..28/y33..38 inside the protected compartment. Helm controls and
engine infrastructure must support upgrades; the draft does not choose upgrade
costs, effects or progression. The `helm_control` marker at `(24,37)` is an
ordinary table. The `engine_mount` marker at `(25,29)` is the existing inert
`/obj/structure/props/engineprops` prop with its `gasoline_static` sprite. Neither
is working fuel, control or upgrade machinery. The former exposed helm room is
forward cargo. Exposed hull and room walls do not require invincibility.

The protected compartment has no exterior boarding door. Its only entry passes
through the airlock: inner door `(14,39)`, outer door `(15,45)`, and clear interior
x13..16/y40..44. Closing either door must statically separate the safe rooms from
the exposed carriage. **Both ordinary locked doors are visible placeholders.**
They do not enforce party authorization, interlocking or invulnerability.
The protected boundary walls and doors, including both airlock doors, must resist
damage, deconstruction, forced entry, removal and replacement bypasses. High
health alone does not meet this requirement. Runtime protection must also cover
entry, remote interactions, projectiles, contents, construction and other
relevant paths, with the party check unchanged when docked. The engine room and
helm controls receive the same protected-compartment coverage. The map must
remain inactive until those contracts are implemented.
The manifest enumerates 162 boundary wall tiles and the two airlock doors;
transport and save restoration must preserve their required protection.
The player's confirmed protected-compartment rule is independent of Enginefall.

The boundary is interpreted as the protected safe compartment to the exposed
train section. The required airlock permits only party members to enter from
either side and must never have both doors open. Runtime work must cover cycling,
forced entry, bypass and occupancy. Safe egress after membership changes or
disconnect remains an unresolved policy decision; this map chooses no trapping
or forced-ejection behavior.

The manifest's `dagger_party_safe_compartment` marker and sustenance bounds
x0..29/y0..38 identify the safe rooms separately from the vestibule. While an
authorized party member actually occupies those rooms, nutrition and hydration
must passively increase up to normal healthy caps instead of ordinary drain,
including when raid-docked. No rate has been chosen. The mechanics owner must
apply this once per metabolism update, prevent overflow/double application and
resume ordinary behavior on exit. These are declarative markers and requirements;
no shared metabolism code is changed or runtime recovery claimed.

## Raid entry and extraction contract

Raid entry requires both loaded fuel and a boarding pass for the selected target
train section. Sections nearer the front of the target train offer better loot
and require a higher entry cost. This is a requirement for the future mechanics
owner; the draft defines no fuel quantity, pass price, tier names, loot tables,
travel time or extraction timer. These target-train progression rules do not
change the Dagger's protected-compartment boundary.

Target-train compartment doors must be breachable without a boarding pass. A
pass gates the entry transaction for its target section; it must not become an
unbreakable lock on every target compartment. Those breachable doors are distinct
from the invincible protected-boundary walls and airlock doors on the Dagger.
The target train and its compartment doors are not built by this map draft.

The future extraction controller must expose explicit reservation, call, arrival,
boarding and departure states, with completion and failure outcomes. A call is
not an arrival; arrival is not successful boarding or departure. State transitions
must revalidate the party, train identity, selected section, resource eligibility,
destination reservation and current occupancy on the server. Reservation must
precede constructors, loading or movement, and remain exclusive through the
transition that consumes it.

| State | Required future behavior |
| --- | --- |
| Reservation | Atomically claim only the selected berth and train footprint; validate loaded fuel and the target-section pass |
| Call | Authorize an idempotent request tied to the current train identity and reservation |
| Arrival | Revalidate ownership and occupancy before placement and after callbacks; retain boundary protection |
| Boarding | Track actual participants; enforce the protected party airlock while exposed sections remain boardable |
| Departure | Revalidate custody and durable movement; release claims only after verified empty-slot retirement |

Loaded fuel and the target-section pass need one server-authoritative atomic
commit decision. Concurrent or repeated requests must not spend either twice,
consume one without the other, or produce a free trip. Retries, callbacks,
disconnects, cancellation and restart recovery must be idempotent. The mechanics
owner must choose and document when resources are reserved and committed, which
failure states release reservations or refund payment, how refunds are recorded
exactly once, and when rollback or explicit quarantine is required. No refund
policy is selected here. A refund must not leave a completed transfer or duplicate
train/resources behind. Arrival, boarding and departure must each have explicit
failure handling rather than assuming a preceding successful state is enough.

All of this is a declarative handoff to the separate mechanics/persistence owner.
It adds no fuel/pass economy, extraction runtime or native SDK integration and
authorizes no runtime, server, client, live 1714 or SDK actions.

## Size and resource implications

| Measure | Superseded draft | Enlarged draft |
| --- | ---: | ---: |
| Train dimensions | 15 x 51 | 30 x 102 |
| Full footprint tiles per train | 765 | 3,060 |
| Staging dimensions | 128 x 128 x 2 | 256 x 256 x 2 |
| Staging turfs | 32,768 | 131,072 |
| Padded reservation per slot | 21 x 57 = 1,197 | 42 x 114 = 4,788 |
| Clear build pad tiles | 30 | 180 |
| Placed object entries on prototype | 42 | 266 |
| Placed object entries in staging map | 54 | 290 |

Both footprint and staging tile counts are four times larger. Object entries
include furniture, doors and decals; they are source placements, not measured
live atom counts. Transport mask checks and any full-footprint saves now have
3,060 candidate tiles per train instead of 765. More furnishings may increase
constructor, save and interaction work. Actual RAM, timing and saved byte growth
have not been measured and cannot be inferred as exactly fourfold. Runtime
allocation still needs bounded active slots, reuse and quotas; the demonstration
neither adds z-levels nor sets a production party limit.

## Files and coordinate contract

- `maps/WIP/dagger_train_home.dmm`: native editable map source, generated from
  `tests/dagger_map/build_map.py`; edit the generator and regenerate together.
- `maps/WIP/dagger_train_home.layout.json`: versioned, API-neutral static data.
- `tests/dagger_map/validate_map.py`: DMM and layout validator.
- `tests/dagger_map/test_layout.py`: focused static checks and mutation controls.
- `tests/dagger_map/preview.py`: source diagram export; it is not a native render.

Local coordinates start at the southwest tile `(0,0)`. World coordinates are
BYOND's one-based `(x,y,z)`. The transform is `world = slot.origin + local`;
the origin is a world coordinate, not a tile offset to be incremented again.
Only zero-degree rotation is described by v1. Bounds are inclusive. Mask rows
are explicitly ordered **south to north**, unlike DMM text rows, which are
written north to south. Every mask bit belongs to the moved rectangle, including
the hull and the filled corners around coupling passages.

| Slot ID | World origin | Inclusive reservation on that z |
| --- | --- | --- |
| `home_west` | (40,48,1) | x34..75, y42..155 |
| `home_east` | (168,48,1) | x162..203, y42..155 |
| `raid_west` | (72,72,2) | x66..107, y66..179 |
| `raid_east` | (130,72,2) | x124..165, y66..179 |

Each named slot supplies its own berth mask and anchor. The two raid reservation
rectangles are disjoint, as are their translated 30 x 102 arrival footprints.
Their exposed sides face the shared x108..123 platform. Bridge cells are world
triples outside the arrival masks; the destination floor is empty of furniture
and actors in the draft. Two arrivals can geometrically fit at once. That is
not evidence that concurrent loading or travel is safe.

Shared platform/concourse exclusions remain outside every train reservation.
Both arrival masks are empty before loading. Static composition places both
complete trains in their berths and checks connected platform access at every
declared boarding tile. Neither train's footprint or claimed padding may take
the other berth or the common access space.

`berth_geometry_groups.raid_pair_v1` links `raid_west` and `raid_east` for
cross-berth geometry validation only. **Each train/party atomically reserves
only its selected berth and its own whole footprint.** The second berth stays
available for another party to arrive while the first train is docked. The
geometry group grants no exclusive occupancy or lease over both berths. The
manifest's `reservation_policy` declares this requirement; it does not implement
a lock. Partial acquisition of the selected berth/footprint must not permit
construction, loading or placement.

The static template ID identifies a version of the design. It is **not a saved
train identity**. The manifest deliberately contains no sample persistent
train or crew ID to accidentally reuse. Future runtime IDs must survive slot
changes and restart independently of coordinates, DMM area names and temporary
round-party objects. Exact mask membership must be authoritative; an area-type
search is not an instance lookup.

## Existing movement code and integration boundary

Source inspection against base `7ebba01cb9e91176c81cc4a8af5f8e0d57ec4b6b` found:

- `code/modules/1713/trains.dm` moves individual train atoms and their followers,
  riders and registered cargo. Its collision and cycle checks do not relocate
  a multi-tile home or reserve a destination footprint.
- `code/modules/multiz/area_teleporter.dm` changes object/mob z coordinates after
  a delay. It preserves absolute x/y, does not move turfs, and has no destination
  reservation, unique-target enforcement, party policy or durable rollback.
  None of its teleporters or controllers is placed here.
- `code/_helpers/areas.dm` converts area instances to types before collecting
  matching areas. This cannot select one player's train by itself.

The Extraction branch has additional car-specific codecs and transfer helpers;
they are not a train ABI in this master-based map draft. No shared train,
vehicle, shuttle, save, map-selection, or persistence source is changed here.
No Baystation or other server source/assets were imported; an external reuse
proposal would need a separate license and attribution check first.

The mechanics/persistence owner must implement reservation before constructors,
loading, or movement; exclusive custody of each train; stable IDs and schema/
generation fences; occupancy revalidation after callbacks; rollback or explicit
quarantine; recovery after interruption; and verified empty-slot retirement and
reuse. The allocator must bound active instances, world allocation and work,
without treating this two-slot demonstration as the production quota. Durable
claims must prevent two trains taking one berth and one train appearing twice,
while allowing different parties to occupy the two distinct berths together.
The existing area teleporter must not be substituted for these contracts.

## Verification and next acceptance work

From a verified Python installation, run:

```powershell
py -3 tests/dagger_map/build_map.py --check
py -3 tests/dagger_map/validate_map.py
py -3 -m unittest discover -s tests/dagger_map -p "test_*.py" -v
```

The source preview additionally requires Pillow. Static checks cover encoded
DMM dimensions, literal tile overrides, deterministic output, disjoint slot masks,
empty arrival footprints, shared-space exclusions, both trains placed together,
full-width boarding routes, occupied build pads, airlock topology and inactive
integration. They also enforce the declared sustenance/airlock requirement flags
without simulating their future runtime behavior. Overlapping or obstructing data must be
rejected. These checks do not execute DM, constructors, doors, party checks,
crafting, saves, movement or transactions.

The `Dagger map static checks` workflow uses the existing CI suite-selection
policy: it runs this newly introduced suite on the introducing PR, then becomes
opt-in through `workflow_dispatch`. It performs only the three static commands
above; the existing production compile does not include this inactive WIP map.

For each PR map or icon revision:

- Regenerate the DMM, manifest and source diagram from the current source.
- Wait for the static map render at the current PR SHA.
- Replace inline PR preview images with that revision's images, then confirm
  they load and visually agree with the current layout.
- Label source diagrams, static renders and actual gameplay captures accurately.

Native acceptance belongs to the separate mechanics/persistence work: two
different crews, simultaneous arrivals, occupied destination rejection before
construction, unrelated contents preserved, repeated home/raid return with
unchanged train/contents identity, protected-compartment access and damage while
docked, interlocked airlock cycling/unauthorized entry/safe egress, nutrition and
hydration entry/exit/cap/double-tick behavior, interrupted movement and save
recovery, quota exhaustion and safe reuse. Acceptance must also exercise protected
wall/door damage, deconstruction, forced-entry, removal and replacement attempts;
upgradeable helm controls and engine-room protection; pass-free breaches of target
compartment doors; loaded-fuel and section-pass rejection; forward-section cost/
loot progression; and every extraction state with concurrent calls, duplicate
callbacks, resource commit/refund, rollback and restart failure controls.
This draft supplies the geometry for those checks, not their implementation.

## Inspiration

Enginefall's [official description](https://www.enginefall.com/) presents Dagger
shuttles as homes and raid transport alongside larger trains. Its [June playtest
post](https://www.enginefall.com/blog/welcome-to-the-enginefall-summer-playtest)
also describes early Dagger bases and combat. Those are concept references;
this draft copies no map or artwork and adopts no inferred protection, crew-size,
loss, economy or ownership-transfer rules from them.
