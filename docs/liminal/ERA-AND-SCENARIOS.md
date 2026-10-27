# Early-1990s policy and a shared generated-level contract

The escape mode and the separately owned powered-gateway expedition/colonization
scenario are distinct. They may consume the same authored-room generator and
finite level template. Gateway power, ownership and persistence mechanics belong
to that scenario's design; they are not a replacement for escape objectives or
part of a global electricity system.

## Period decision

Default scenario year: **1990**, configurable within 1990-1993 for the initial
early-1990s policy. This is a deliberate design choice, not an assertion that
all of Kane Pixels' series happens in one year, or that one exact canon date
must be simulated. Do not infer the scenario date from a video's release year.

The creator-description audit records:

| Official creator video | Described date | Design implication |
| --- | --- | --- |
| [First Contact](https://www.youtube.com/watch?v=eXdIDjzy6KY) | October 17, 1989 | Background to powered access; not the requested general equipment year |
| [Pitfalls](https://www.youtube.com/watch?v=0XwlWXtpaCM) | May 6, 1990 | Supports the 1990 expedition-era default |
| [Presentation](https://www.youtube.com/watch?v=ITuGdHxHi0A) | May 8, 1990 | Supports the 1990 expedition-era default |

The later 1996 Found Footage description and 2022 release are not the gateway
opening-year basis. These timeline facts were supplied by the creator-description
audit; the design uses official links rather than copying footage or rooms.

## Era must govern gameplay, not only the title

Prefer analog cameras/CCTV, CRT terminals, wired controls, portable radios,
paper maps, protective industrial suits, generators and industrial tools.
These are candidate equipment families, not proof that each exact Civ13 asset
already exists or is approved. Any selected weapon, accessory, computer or tool
needs a period-compatible type/model decision. A powered gateway is exceptional
speculative technology, not permission for a futuristic general equipment roster.

Do not inherit the generic modern Lights Out loadout, its 2013 map age or all
technology in a broad modern ordinal bucket. A year label alone is insufficient.
Native mode admission must bind an explicit early-1990s policy covering:

- Equipment type/model allowlist, including cameras, radios, protective gear,
  medical supplies, tools, weapons and attachments actually granted to players.
- Decorative/interactive map prop allowlist, including terminals and controls.
- Available crafting recipes and research unlocks, with explicit ordinary-player
  exclusions for later or unreviewed technology. A broad ordinal age cannot
  silently enable everything in its bucket.
- Source revisions, item/recipe/research identifiers and period evidence for the
  chosen roster. Missing evidence does not fall back to a generic modern kit.

Use a separate native era-policy adapter, scoped to these scenarios. Do not
rewrite shared Nomads research or a global item roster to fake the desired era.
The native map age/calendar and ordinal age must be audited and tested alongside
the allowlists. Regular spawn, crafting and research paths require verification;
this is not a claim to police administrator-injected items or all game content.

The first offline tool can record year 1990 and a PENDING era catalog. That is
honest preparation, not implemented equipment/research filtering. Native READY
must remain false until actual roster/menu/recipe/source controls pass. No exact
canon day/month is invented. Initial source slices may omit unverified prop or
equipment families rather than import incompatible artwork.

## Shared immutable LevelTemplateRef

Both scenarios consume a generated template contract, independent of mission
state, power or inhabitants. Proposed schema: civ13-generated-level-template/1.

| Field | Contract |
| --- | --- |
| template_id | SHA-256 of canonical immutable geometry identity inputs; never a live-world instance ID |
| generator | Algorithm/profile/catalog version and catalog digest |
| seed and geometry_configuration_sha256 | Exact generation inputs needed to replay the template |
| geometry_sha256 | Canonical rooms, masks, typed socket geometry, sealed sockets and logical layer |
| logical_levels | Explicit logical IDs; no assumption that INDOOR_0 is a particular native z |
| anchors | Stable arrival/discovery/service/egress candidate sites with room/local coordinates and clear footprint |
| gate_slots | Stable physical connection IDs; scenario-specific predicates are bound separately |
| native_export | Separate catalog/mapping/file hashes and readiness; absent until admitted |

Template identity excludes escape objective flags, gateway power state, scenario
year/equipment policy and mutable player state. Geometry generation inputs still
include the exact bounded geometry configuration. Changing that configuration
can change room selection. Static output and mission-binding hashes remain
independent, so a scenario change cannot silently masquerade as a new geometry.

The escape adapter binds discovery/service/egress flags to the template's stable
anchors and gate slots. The gateway scenario may bind its own approved interface
to compatible anchors under its own policy. This document does not implement a
gateway, electricity network, colonization or persistence mechanism.

## Mutable LevelInstanceRef is a different authority

An instance has an authority-minted persistent instance ID, template ID, source/
native mapping lineage, state revision and owner scenario. Its identity is not
derived only from a seed: multiple rounds can instantiate one template, while
an inhabited expedition level must retain one mutable lineage.

Consumers must never regenerate or re-import the template over an inhabited
instance. Power loss, reconnect, content updates or a different scenario cannot
reset rooms, doors, inventories or player construction. A changed template makes
a new template record; applying it to existing state needs a separately reviewed
migration/recovery policy. Template export is not that policy. Runtime infinite
generation and in-place world resets remain out of scope.

## Separate versioned ScenarioSpec

The escape source slice should record ESCAPE, scenario version, scenario_year,
early-1990s policy version/admission, template ID and symbolic progression
bindings in a scenario manifest separate from geometry. The default is 1990.
Changing the year changes the scenario identity, not the immutable template.
Native DMM/type/era mapping and actual objectives/timers remain distinct gates.

Root will coordinate the exact consumer fields with the gateway task before a
shared runtime interface is admitted. The independent source slice can implement
template identity and the escape specification now, with explicit PENDING native
catalogs, without duplicating gateway power/persistence or changing terrain work.
