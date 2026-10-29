# Optional geographic elevation

Elevation is metadata measured in metres. It is independent of native `/area`
room membership, climate/biome, turf type and native z-level height. Existing maps
default to **0 metres everywhere**. This foundation does not change temperature,
precipitation, movement or terrain. Elevation does not yet make mountains colder.

`get_elevation(atom)` reads the effective profile at the atom's physical turf,
including contained items. An atom without a physical turf, or a missing map,
returns zero. Changing a turf or its area cannot erase coordinate-owned geography.

## Authoring

Set optional fields on the map's `/obj/map_metadata` subtype, before the first
elevation read or save. No maps are converted by this change.

```dm
/obj/map_metadata/example
	elevation_default_metres = 0
	elevation_regions = list(list("x1" = 10, "x2" = 20, "y1" = 30, "y2" = 40, "z" = 1, "metres" = 1250))
```

The default and every region height must be finite numbers from -12,000 through
12,000 metres, inclusive. Fractional metres are accepted. Each region has exactly
the six keys shown above. x/y endpoints and z are inclusive integer coordinates
inside the current world. x1 <= x2 and y1 <= y2. z selects one native plane; no
height is calculated from it. Dimensions must be integers from 1 through 32,767.

There may be at most 256 rectangles. Any shared coordinate on the same z-plane
is rejected, including equal-height overlaps and shared edges. Adjacent
rectangles without a shared tile are allowed. Region order has no priority.
Invalid authoring throws before publishing an effective profile or saving.

Admission checks overlap in O(R²), at most 32,640 rectangle pairs. The effective
profile copies scalar rows and is cached once. Reads are O(R), at most 256
rectangle checks, with O(1) reads on flat maps. No query scans world turfs or
revalidates the complete profile. Memory is O(R), independent of map area.
Author-list edits after initialization are not a runtime editor; the effective
profile is authoritative until a validated restore replaces it.

## Persistence

New round-v1 and round-v2 `round.json` files include an optional `elevation`
snapshot with exactly `version`, `maxx`, `maxy`, `maxz`, `default_metres` and
`regions`. Its version is 1. Every snapshot copies its scalar rows independently
of authoring and live profile lists. The world header binds it to the existing
generation/map/dimensions; its dimensions must also match the validated load
dimensions. Bounds and overlaps are checked again before world mutation.

The validated saved profile is installed before map clearing and replacement
constructors. It overrides newer map authoring defaults. An absent elevation
field, including a legacy generation without a round header, restores flat zero.
A present null, malformed or unsupported snapshot rejects the load. A failed
preflight retains the running world and its effective profile. Existing durable
metadata inventories and per-turf saves are unchanged. Backward reading of old
saves is supported. Forward loading of new saves into old builds is not: the old
reader requires exactly 11 round-v1 or 12 round-v2 header fields and rejects the
extra elevation field. Offline checks execute the immutable old reader against
both old and new headers. Retain original generations/backups before upgrading.

The effective cache is written only by its lazy initializer and validated
restore. Restore installs it before clearing/reconstruction. Later changes to
author fields cannot replace that non-null cache. Ordinary map-metadata entries
are not reconstructed by Load_Entry, and neither the legacy metadata loader nor
the durable field inventory assigns these author fields or the cache. The single
existing map persistence exclusion hook excludes all three elevation fields.

Profiles are plain, unregistered datums containing only numeric scalars and copied
lists of scalar rows. They have no timers, callbacks, New/Destroy overrides,
observer registration, resources, backreferences or cycles. Ignored validation
results and failed-build locals become eligible for ordinary native datum
collection when their last references leave the call stack. A snapshot's
temporary profile can be collected independently while its returned rows remain
owned by the snapshot. The effective profile lives as long as the map cache or
an active reader references it; replacing the cache releases that owner.
Repository datum documentation describes automatic collection without remaining
references; registering these temporary values with the custom qdel queue is
unnecessary. This is a source/lifetime argument, not a measured native GC result.

## Scope and verification

Nonzero temperature coupling is deferred. Weather visuals and precipitation type
are currently area-wide; applying a per-coordinate Celsius/km lapse rate alone
could disagree with rain/snow. Any later configurable lapse rate should default
to zero and share a geographic resolver with precipitation. No new mountain
biome, regional layering framework, admin editor or z allocation is introduced.

Run offline checks with a verified interpreter:

```powershell
& $PythonPath -B -m unittest discover -s tests/elevation -v
& $PythonPath -B tests/elevation/prepare.py --output <new-temporary-directory>
```

The restricted projection executes selected production statements with explicit
list and file adapters. It checks finite bounds, edges, overlap, aliases, legacy
defaults, v1/v2 disk JSON admission and load ordering. Generated-source controls
exercise overlap, aliasing and legacy-default defects. This is algorithm/source
evidence, not native DM acceptance.

Preparation copies the real serializer/loadmap plus minimal existing world-save
adapters and the production physical-turf macro. The 8x6x2 native fixture source
covers contained items, area reassignment, native/ChangeTurf replacement, real
disk save/load, invalid snapshot rejection, changed defaults, edges and legacy
missing fields. It has not been compiled or executed. It models roofing's area
replacement seam; actual roof construction, full-game callbacks, round-v2 native
integration and connected-client behavior remain unverified. Preparation never
launches a compiler, daemon or client, inventories processes or clears holds.
