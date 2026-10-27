# Backrooms expedition and colonization

Status: design-first proposal and disabled implementation foundation. This is a
separate scenario from the finite Liminal Facility escape mode. No map, lobby
entry, job, process, gateway object or production activation is installed by the
foundation. Source audit: Civ13 `10d264e5896221b34949ee4b67c0fd2b94bde249`.

## Scenario and period

A staffed surface research facility deliberately powers a doorway into a fixed,
dedicated Backrooms z-level. Teams survey authored indoor rooms, mark routes,
carry supplies through the aperture and establish a colony. Returning with
observations and maintaining a viable outpost replace the escape mode's marker,
service-task and extraction victory loop. There is no mandatory short round
timer, resetting maze, endless runtime generation or automatic victory for
crossing home. The first playable target is cooperative, with one shared colony.

Default configurable year: **1990**, restricted initially to 1990-1993. This is
a scenario choice for powered-gateway exploration, not a claim that every episode
occurs in one year. Creator sources: Kane Pixels' [First Contact](https://www.youtube.com/watch?v=eXdIDjzy6KY)
description dates contact to October 17, 1989; [Pitfalls](https://www.youtube.com/watch?v=0XwlWXtpaCM)
and [Presentation](https://www.youtube.com/watch?v=ITuGdHxHi0A) describe May 6 and
May 8, 1990. These dates support the powered-expedition era choice. No exact canon
day is required. Release year and the Found Footage date do not set the gateway era.

Set metadata `age` to the selected year string and **ordinal_age = 7** explicitly.
The base `set_ordinal_age()` only recognizes canonical year labels, not 1990;
changing the displayed date alone is insufficient. Existing 1992/1993 maps use
tier 7. Keep the scenario research policy fixed and separate from ordinary global
era advancement. Modern generator recipes require tier 8 and cannot be silently
unlocked to obtain a gateway.

Use an explicit period allowlist for starting gear, loot and build recipes:
film camera `/obj/item/camera/coldwar` plus paid film; portable radios; paper,
pens and maps; protective clothing; flashlights; hand tools; industrial repair
and finite engine fuel. Candidate video camera art is available but the existing
`/obj/item/video_camera` declaration does not establish actual video recording.
CRT terminals, wired control panels, analog CCTV and specialist suits require
per-type capability/asset checks before selection. Generic Modern job loadouts,
smart devices, post-1993 weapons, drones, nuclear/solar tech trees and unrestricted
Modern crafting are excluded. The gateway is exceptional speculative machinery.
Period weapon variants and ammunition must be individually audited if enabled;
initial expedition loadouts need no guns. The allowlist must cover material and
research prerequisites, not merely hide later recipes in the UI. The foundation
does not yet provide this equipment or recipe adapter.

## Selected protective and survey kit

The first expedition's chosen protective kit is the existing **yellow/ochre
hazmat suit** `/obj/item/clothing/suit/hazmat`, state `hazmat_suit`, with a
separate unbranded industrial half mask. This is the initial design selection,
pending ordinary-player loadout and worn-appearance tests; no working spawn
adapter is supplied. No artwork port or new suit is needed.

| Item | Exact selected type / quantity | Design use |
| --- | --- | --- |
| Hooded suit | /obj/item/clothing/suit/hazmat x1 | Suit slot; yellow full-body visual with hood drawn into suit |
| Separate facepiece | /obj/item/clothing/mask/gas/halfmask x1 | Mask slot; generic industrial half-face design, no claim of a particular show/manufacturer model |
| Work gloves | /obj/item/clothing/gloves/thick x1 | Glove slot; existing black work gloves |
| Work boots | /obj/item/clothing/shoes/workboots x1 | Shoe slot; existing industrial boots |
| Hand light | /obj/item/flashlight/flashlight x1 | Existing unlimited-power behavior; no invented battery drain |
| Radio | /obj/item/weapon/radio x1 | Existing portable radio; reserve back slot and verify equipped use/cross-z policy |
| Film camera | /obj/item/camera/coldwar x1; /obj/item/camera_film x2 | Period survey photos and paid film use; no video-recording claim |
| Survey record | /obj/item/weapon/paper x5; /obj/item/weapon/pen x1 | Written route/observation record |

This fixes the PPE/survey subset of the period roster. Food, clean water,
medicine, tools and settlement materials remain finite facility logistics with
their own pending exact acquisition manifest; no generic Modern starting kit or
automatic filled backpack supplements this table. Slot packing, containment and
actual sprite states must pass before any loadout is granted. Weapons are absent
from this initial kit. Do not add a separate NBC hood over the hazmat suit merely
to obtain its drawn hood: yellow NBC uses `/suit/nbc` plus `/head/nbc` (`nbc`), and
olive NBC uses their `/olive` variants (`nbc2`), a different two-item design.

The suit source declares HEAD, torso, arms, legs, hands and feet coverage,
bio=100/rad=100, energy=5/bomb=5 and `ripable = FALSE`. These are gameplay source
values, not evidence of a sealed suit, oxygen supply, whole-body immunity or
real-world protection. The inventory/worn 32x32 four-direction art has a
transparent face opening; the hood does not include a respirator. Source:
[apparel_coldwar.dm](https://github.com/Civ13/Civ13/blob/10d264e5896221b34949ee4b67c0fd2b94bde249/code/modules/1713/apparel_coldwar.dm#L1779),
inventory `icons/obj/clothing/suits.dmi`, worn `icons/mob/suit.dmi`; separate NBC
hood art is in `icons/obj/clothing/hats.dmi` and `icons/mob/head.dmi`.

The selected half mask inherits BLOCK_GAS_SMOKE_EFFECT and AIRTIGHT item flags
and `filter_air` from `/mask/gas`, changes coverage to FACE and does not cover
EYES. Its source declares bio=100/rad=70 and reduced view; these do not establish
an integrated breathing apparatus. The inspected mask code has no consumable
filter/cartridge-depletion ledger. Do not invent a filter timer, oxygen tank or
full-face seal. The human smoke override checks worn mask/head item flags;
`filter_air` handles only its actual gas-name list. That list and every relevant
caller need targeted tests before a chemical hazard is designed around them.
Radiation's ordinary protection path calls `getarmor(null, "rad")`, so test
actual covered-body aggregation rather than reading the suit's rad value as a
global damage multiplier. Sources:
[gasmask.dm](https://github.com/Civ13/Civ13/blob/10d264e5896221b34949ee4b67c0fd2b94bde249/code/game/objects/items/clothing/masks/gasmask.dm),
[human_life.dm](https://github.com/Civ13/Civ13/blob/10d264e5896221b34949ee4b67c0fd2b94bde249/code/game/mob/living/carbon/human/human_life.dm#L448),
[damage_procs.dm](https://github.com/Civ13/Civ13/blob/10d264e5896221b34949ee4b67c0fd2b94bde249/code/game/mob/living/damage_procs.dm#L54).

The initial rooms remain breathable and have no required chemical/radiation
passage or vacuum. Wearing this kit supports the expedition's identity; survival
must not depend on unverified sealing/filter/armor behavior. Later hazards need
separate acceptance, including suit-only, mask-only, full kit, removed/damaged
equipment and exposed-eye controls. Equipment removal/death/reconnect must
preserve actual worn/nested items without issuing a duplicate free kit.

## Colony and resources

The colony occupies a precompiled plane of the **same XY dimensions** as the
surface facility. Begin with a compact static two-plane scenario; never allocate
a large new plane on a live Nomads/TDM map. A 96x96x2 design envelope is 18,432
native cells, not a measured host-capacity guarantee. Final footprint follows
the generator owner's native export and memory review. Dynamic growth remains
subject to world_z_budget's UNMEASURED hold and is out of scope.

The facility supplies finite food, clean water, medical stock, tools, material
stacks, portable light and gateway charge packs. The colony has independent,
finite replenishable stores; ordinary hunger, injury, disease and local light
continue when disconnected. Do not tie survival to facility power or magically
delete/evacuate inhabitants when it fails. Initially use breathable indoor areas
and stable ambient temperature; no new oxygen/pump simulation. Use existing
containers, consumed stacks and crafting rather than a second inventory economy.
No guaranteed edible plants, rainfall, wood or ore exists behind office walls.
Later sustainable farming requires audited soil, water, seeds, growth and light.

Survey and settlement are persistent work: placed walls/floors, doors, beds,
containers and their nested contents, spent resources, injuries, discovered room
IDs, paper records and placed trail markers. Structural boundaries, portal
approaches, emergency stores and return pads are protected from construction and
destruction. Destructible optional rooms must not carry mandatory return routes.
Building consumes real resources; no free material restoration on reconnect.
The initial blueprint is generated once offline, then mutated by paid building.
Never regenerate from seed over saved construction or reconstruct consumed loot.
No offline survival simulation is added: stopped-server time spends no food,
fuel or injury time. Online disconnected bodies follow existing body rules.

## Purposeful furnishings within shared room profiles

Room function determines dressing before decorative variety. Arrival/orientation
rooms need readable route information and clear staging space; utility/store
rooms need reachable paid supply and repair sites; colony rooms need genuinely
empty construction plots. Shelves, tables and repeated office props should make
those roles legible rather than populate every free tile with interchangeable
clutter. Exact Civ13 types and visual states still require the native palette
audit; these are semantic placement rules, not new available furniture.

Office and archive rooms should read as workplaces: wooden work desks with a
usable chair/standing approach, filing cabinets with reachable drawer fronts,
and period computer positions where the room's function calls for them. Keep
records/storage next to plausible work areas; do not scatter desks and terminals
through bare service corridors or use industrial machinery as generic office
decoration. A utility room may contain repair equipment and supply racks; an
empty liminal room or reserved colony plot should remain intentionally empty.
Room themes determine whether furniture is appropriate at all.

An office arrangement in [The Art of the Deal](https://github.com/Civ13/Civ13/blob/10d264e5896221b34949ee4b67c0fd2b94bde249/maps/special/the_art_of_the_deal.dmm)
can inform proportions, work groupings and asset purpose without copying its
coordinates or floor plan. Source-backed Civ13 palette candidates include
`/obj/structure/table/wood` as a wooden work surface,
`/obj/structure/filingcabinet` for records, and
`/obj/structure/props/computerprops` with `1980_computer_on` for a period computer
prop. A table is not automatically a desk assembly, and a computer sprite is not
a working powered terminal: native chair/interaction/appearance selection and
the 1990 equipment policy still require review. These candidates do not alter
the room generator, gateway supply or initial item grants.

Use three placement classes in the shared room-profile contract:

| Class | Placement intent | Mandatory exclusion |
| --- | --- | --- |
| Against wall | Shelving, wall-facing repair/storage sites and route information, with an accessible front approach | Door/socket apertures, pad footprints and equipment-use reserves |
| Open floor | Approved freestanding tables/columns or deliberate survey features in sufficiently large rooms | Connected walking clearance, colony construction plots and rescue staging |
| Narrow passage | Sparse approved nonblocking markings or wall-mounted details; an empty passage is valid | Dense props, loose supply piles and any reduction of return-route clearance |

The shared generator owner supplies these semantic slots and deterministic
dressing choices; the expedition adapter does not implement another room
generator. Bind choices to the immutable template's room/slot IDs, exact seed,
configuration, catalog and palette version. Record initial placements and item
quantities in the manifest, validate collision/reachability after dressing, and
reject blocked approaches rather than silently deleting mandatory content.
Survey/utility sites cannot be hidden behind furniture or an escape-only flag.

This distinction is informed by Yogstation's pinned maintenance dressing pass,
linked in CONTRACT.md. Its independent random selections and any random door
passes are not our seed/replay or progression proof. Native adapter clearance,
our own authored layouts and validated instance/return contracts remain
authoritative. Player-built furniture, removed props and spent stores become
mutable instance state; neither an outage nor save restoration reruns dressing.

## Power and doorway

Gateway energy uses integer **scenario charge units**, not watts, PU, cable
powerflow or a claim about real physics. One source instance owns available charge
and connected/failed status. Only it debits paid packs and capacity. The controller
uses `draw(units)` synchronously; false spends nothing. No sleeps, prompts, world
scans or external I/O are allowed inside the interface. See CONTRACT.md.

The first supply is an isolated expedition cabinet with finite paid charge,
capacity and explicit connection. A pack becomes charge only after successful
stack consumption and capacity checks; removal/repair cannot replay it. An
existing engine or cable adapter can be added later with actual reservation and
fuel accounting, without modifying the general grid. Decorative transformer or
station sprites cannot report power. Cable instantaneous capacity is not energy.
The first foundation supplies accounting datums only, with no refill UI or item.

Provisional defaults: startup cost 10 units, startup duration 30 seconds,
maintenance 1 unit per second while starting/ready, crossing 2 units, cooldown
2 seconds. Paid startup is not refunded after failure. Poll at most once per
second; expire a missed maintenance interval instead of backfilling time or
granting free operation. Costs/times are design values requiring playtests.

| State | Transition and admission |
| --- | --- |
| OFF | No crossings. Operator requests start only with admitted destination, valid bindings, access and paid startup plus first maintenance interval. |
| STARTING | Continuous paid maintenance for startup duration. No crossing; outage, disabled scenario, endpoint mismatch or destination failure stops it. |
| READY | Paid current interval and fresh endpoint/power validation required for every crossing. Idle intervals still cost charge. |
| OFF after shutdown | Stop admission immediately and invalidate pending requests. Destination, colony and supplies remain. Restart pays a new startup. |
| FAULT | Power loss, interrupted maintenance, destroyed/disconnected source or failed destination invalidates readiness and pending requests immediately. Repair does not auto-start. |
| RESTORED/OFF | Loading never restores energized state, live requests or deadlines. Bind endpoints and revalidate before a fresh paid start. |

No autonomous constructor timers. One future scenario owner drives maintenance,
bounded to one gateway pair. The disabled foundation has no such owner. A fault
can clear to OFF after repair, but no start succeeds while failure remains.

## Crossing and access

Entry is deliberate use of a visible doorway control; bump events may offer use
but must not queue an unconditional delayed teleport. Require an authorized
living human at the exact approach, scenario/colony membership, current paired
endpoint identity, no save/load operation, unexpired paid power, valid capacity,
and an unobstructed reserved landing footprint. Entry access is role/party based;
an operator can open a planned expedition, not globally bypass access. Reconnect
uses durable body ownership, never lastKnownCkey as sole identity.

Crossings are one actor with its existing contained inventory. Reject vehicles,
loose freight, dragging/pulling, buckled riders and spatial links rather than
silently transporting half a group. Rescue of an incapacitated human requires a
separate explicitly tested assisted transfer; do not treat corpse transport as an
ordinary conscious entry. Observers, AI, thrown items and nested stowaways cannot
cross through the human API. Initial capacity counts living colony bodies,
including disconnected/protected sleepers; spectators do not occupy entry slots.
Return never fails solely because inbound capacity is full.

The future native crossing owner serializes the pair. Acquire one short-lived
token carrying session/colony/endpoint epoch and actor identity. Choose a landing
from a bounded ordered set of 4 pads, reserve it, recheck actor/source/destination,
power/access/capacity/save ownership, and atomically debit crossing energy plus
move **without yielding**. Use the persistence movement gate and explicitly
review the movement adapter: `persistence_set_loc` preserves raw movement but
omits Entered callbacks; `forceMove` has callbacks which can recurse. Neither
unconditionally proves safe pixel landing or the absence of indirect yields.
Until that audit is complete, physical crossing stays unimplemented.

If checks fail, release the token/pad and change no location, occupancy or crossing
charge. A rejected destination must not shove occupants aside, select random
coordinates, bypass a wall, send a player to z1 or silently search an entire map.
Once a native move succeeds, ownership/location is authoritative and must be
reconciled if callbacks fail; do not refund energy while leaving the actor moved.
Set per-body and pair cooldowns only after success, shared both directions.
Power loss during a queued/animated request invalidates it; an old token cannot
authorize a crossing after restart or restoration. No save can observe a half
transfer. This transaction is a later slice, not supplied by the state predicate.

## Disconnection, return and rescue decisions

**Default outage behavior:** both ordinary directions stop. No level/occupant
deletion, teleport damage, colony reset or implied free one-way portal. Normal
return requires the facility pair to be powered and a safe home landing.

A future colony-side **powered emergency egress** has its own protected finite
reserve and one-way landing at the facility evacuation pad. It bypasses operator
entry access but retains membership, body, landing and save guards. Its reserve
is separate from construction/maintenance budgets and cannot feed inbound travel.
Before a fresh inbound crossing, reserve one return entitlement per additional
resident, including startup/hold/crossing costs under the configured emergency
policy. Entitlements bind colony body ownership, survive saves and are released
only on verified return/death, not logout. Refuse entry if reserve cannot cover
current residents plus the entrant. Do not claim a guaranteed return before that
ledger and protected-pad adapter exist; the foundation does not implement them.

Facility operators repair/recharge and reopen the original pair for normal rescue.
A reserved surface rescue role/loadout must remain obtainable when all explorers
are away. Body recovery, long disconnection and party leadership changes cannot
erase membership or change the destination colony. If either home pad is blocked,
show the reason and keep the actor in place while operators clear an alternate
reserved pad. If reserve/equipment is destroyed or all pads are invalid, players
can remain stranded pending operator repair. This is a **softlock risk**, never
a hidden reset/reward. Default protected infrastructure and admission checks aim
to prevent it. A later hardcore preset may allow reserve destruction only with
an explicit pre-round warning and an independently reviewed rescue policy. No
irreversible trapping preset is in the initial implementation.

Deaths follow ordinary Civ13 rules and do not regenerate gear or become wins.
Late joins start at the facility after capacity/research/loadout checks. Do not
spawn new bodies inside a closed colony as a way to bypass the powered doorway.
Existing colony bodies may reconnect where saved through ordinary reclaim.

## Configurable rules and staging

| Rule | Initial proposed default / bound |
| --- | --- |
| enabled | false; no registration supplied |
| scenario_year / research tier | 1990 / 7; year 1990-1993, period allowlist required |
| colonies / gateway pairs / Backrooms planes | 1 / 1 / 1, fixed before startup |
| living residents | 8, configurable 1-16 pending native capacity tests |
| generation | exact shared indoor profile/catalog/manifest, finite offline output |
| plane envelope | design target 96x96, same XY each plane; final measured separately |
| supply capacity | 600 units; 1-100000 integer, finite paid input only |
| startup / maintenance / crossing | 10 / 1 per second / 2 charge units |
| startup / cooldown | 300 / 20 deciseconds; reviewed bounded overrides only |
| disconnected behavior | keep colony, independent survival, no offline simulation |
| emergency return | protected paid reserve required before playable entry |
| build / supply / threats | approved recipe/type/room allowlists; threats initially off |
| persistence | whole paired scenario generation; never independent half restores |

Expose a small reviewed preset rather than arbitrary endpoint coordinates, type
paths or eval. Unknown/malformed policy rejects before allocation or spending.
Changing content/identity or the policy requires a fresh colony or an explicit
migration; never reinterpret an old save with newly generated rooms.

Milestones: design; disabled power/identity foundation; shared generator native
export; period gear/paid supply and rescue ledgers; native atomic crossing; paired
world-save/reconnect; bounded headless then connected-client acceptance; separate
activation review. CONTRACT.md defines dependencies and ACCEPTANCE.md defines
the bounded plan. Documentation and implementation commits remain distinct.
