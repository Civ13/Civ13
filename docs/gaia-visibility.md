# Gaia geometric visibility and root-owned tree presentation

## Mouse routing correction (2026-10-31)

The game/tree compositor uses hidden render targets. Its interactive relay
chain must opt into `PASS_MOUSE`, with mouse-transparent plane masters at 1
(children retain their own mouse opacity), rather than plane-wide input at 0.
Only game/tree relays opt in; mask, roof and weather copies remain inert.
This preserves the original atom for hover, clicks and native context menus,
including human visible names, without inventing targets in server hover code.
Withdrawn tree images keep mouse opacity 0 and blank appearances.
See the [BYOND render-source reference](https://www.byond.com/docs/ref/info.html#/atom/var/render_source).
Source/model tests verify the routing flags; actual mouse priority, popup lists,
and client pixels remain native acceptance items.

## Player movement cadence (2026-10-31)

Player-driven presentation uses tile-centered eyes and human target footprints.
Transparent connected players' offset-only movement attempts leave that display
snapshot intact; both the movement callback and scheduled presentation identity
ignore their step offsets. A tile transition refreshes the moving viewer and
nearby viewers before the movement callback returns. Explicit relocations keep
their forced refresh, including relocation within one tile.

This deliberately makes the geometric display boundary advance at native tile
transitions while sprites continue smooth movement. Fresh hover/examine reads
still capture physical eye/target offsets and retain the full stale-snapshot
guard; presentation identity is not their authorization identity. Opaque movers
and blockers keep physical offsets. Door/wall invalidation, vision/FOV and body/
client changes, reconstruction guards, and the periodic raw-writer audit remain
active independently of player movement. A turn or audit can therefore still
refresh presentation while a player remains on the same tile.

Source-derived movement and geometry projections cover offset pulses, tile and
z transitions, forced relocation, nearby versus distant viewers, and a character
entering a denied tile. Omission controls demonstrate offset recapture and stale
neighbor presentation when their respective guards are removed. These checks
do not establish engine scheduling, native mouse priority, or client pixels.

## Distance view camera (2026-11-01)

Looking into the distance hides individual HUD controls while leaving plane
masters and compositor relays visible. This includes the lighting/weather
masters and the plane that carries the exempt aiming/scope buttons. Repeated
enter/exit and renderer replacement retain the same distinction. Scope exit
still restores only objects marked by the scope routine.

Client camera pixel offsets now participate in the presentation/read snapshot
identity. Capture and neighborhood invalidation cover the body-centered view
plus the absolute camera pan, rounded outward to whole tiles, in each axis.
Before each scope animation, a client-owned lease retains the old full viewport,
new endpoint and any still-active earlier extrema through the declared animation
duration plus one decisecond. This also covers exit, view shrink and rapid axis
changes, despite endpoint vars changing immediately. Lease expiry changes the
snapshot identity so the scheduler can release extra coverage. HUD/context
replacement does not discard an active client lease. View and pan extrema are
combined independently: growing the viewport also expands the earlier animated
pan, including growth without a new scope animation. LOS rays keep
the player's actual eye (tile-centered for presentation, physical for reads);
the camera cannot see around an intervening blocker. Scope entry/exit refreshes
presentation synchronously after changing the camera and HUD state.

This expands capture work while panned and may audit both sides of the player,
although only one side is displayed. Player step-offset cadence is unchanged.
The existing 63-cell scalar-view admission remains; larger pre-existing scope
views still use the established unsupported-view behavior. No native camera
animation, slate alignment, hit testing or performance result is claimed.

## Scope and current evidence

The October 30 request is to make LOS and oversized-tree lighting enabled by
default, make the implementation suitable for Gaia, and then restart the server.
Source integration is separate from restart: preserve the running world and save
before any approved rollout. This document is an acceptance plan, not a receipt.

The visual LOS presenter is **conservative**: it removes native-visible atoms
whose geometric decision denies visibility. It does not reveal atoms that BYOND's
native visibility already omits, replace movement/combat permissions, or provide
an action-authority lease. Hover/examine capture fresh geometry. Rendering uses
one revision-valid snapshot per client pass. Nonhuman, camera and observer views
retain their existing behavior.

Denied terrain receives a black override at its own plane and layer, not a
viewport-wide black shutter. Hidden contents receive blank per-atom overrides.
Root-owned tree presentation owns its own trees; terrain masking must not clip a
visible-root canopy over adjacent hidden tiles. Both systems preserve original
world atom identity and collision. Ordinary non-tree overhang discovery has a
two-tile margin, not arbitrary-size sprite coverage.

Offline source contracts check ownership, cleanup, bounded traversal, shared
scheduler use and publication guards. They do **not** establish native rendering,
client hit testing, compile success, save/load acceptance, or performance. Record
actual compiler and runner commands separately; do not turn a skipped/unavailable
check into a pass. No native pixel/performance acceptance is claimed here.

## Bounded native acceptance plan

Use the exact candidate commit and pinned BYOND version in an isolated approved
fixture. Keep production runtime ownership with its existing owner. Record build
hashes, client/server versions, map seed/save generation and actual command lines
without credentials. Do not run untrusted fork code with privileged credentials.

1. Compile the production DME, then run the LOS, root-tree, lighting-composition
   and geometric-presentation focused tests. Preserve failed controls/logs.
2. Use ordinary Gaia grass/dirt/snow, items, doors and trees. Exercise at least
   three clients and more than eight visible roots, multiple viewport sizes and
   two z-levels. Include normal pine/snow, palm and jungle families where present.
3. Capture stationary pixels and moving video at dusk/night/rain: visible roots
   have uniformly root-lit whole canopies, hidden roots reveal no canopy,
   neighboring dark tiles do not cut visible trees, and tint/alpha/offsets apply
   once. Check scene shadows, overlapping trees, roofs and weather ordering.
4. Move across tile edges, open/close opaque doors, change z-level and walk behind
   roots. Check actual mouse hover/examine and native targeting, not screenshots
   alone. Inventory/HUD and the player's own body must remain functional.
5. Reconnect, transfer/respawn body, rebuild HUD, create/delete a tree and change
   seasonal art. Verify no orphan images/plane leases. Save and restore in an
   isolated copy, with presentation rebuilt only after world/lighting settles.
6. Record dense-scene per-refresh cost, icon allocations/cache hits, network
   updates and movement responsiveness against the known-good build. The shared
   scheduler bounds clients between budget checks, not the cost of one dense
   client's entire snapshot. Measure that case rather than assume it cheap.
7. Exercise the existing client runtime opt-out by calling
   `set_geometric_los(FALSE)` through an authorized administrative/test path.
   Confirm both presenters retire, owned images/screens disappear and leased
   plane state returns. Re-enable with `set_geometric_los(TRUE)` and confirm a
   fresh context/presentation, not stale caches. No new public player verb is
   implied by this internal proc.
8. Only after readiness review, preserve a fresh save and known-good binaries,
   install the exact validated candidate and perform the explicitly authorized
   restart. Verify the running build and enabled defaults, reconnect, repeat a
   short night/tree/door check, and inspect fresh runtime logs. Roll back using
   preserved artifacts if that verification fails; never infer success merely
   from a listening port.

## Conservative mixed-scene fallback

The scene compositor cannot flatten native GAME layers without changing overlap:
real roofs and their independent client images are GAME layer10.1/11.1, and
vehicle parents may contain higher-layer overlays. The candidate therefore
restores the entire viewport to native tree rendering whenever a foreground or
rich appearance conflicts with tree-layer composition. It never removes or
replaces third-party client images. Generic geometric LOS continues. Low-layer
jungle bushes are not promoted above standing mobs.

This deliberately limits whole-root lighting coverage: mixed roof/vehicle/effect
scenes can retain native tile clipping. It is not complete Gaia tree acceptance.
The owner exposes fallback reason/count rather than spamming logs. Verify safe
scene -> fallback -> safe scene and exact filter/image cleanup natively before
considering rollout. During ordinary saves, geometry stays fresh as players can
move; world reconstruction suspends capture while retaining denial masks.

### Pending-blocker masking

Known blocker hooks now immediately add denial images for tracked visible content
in the changed cell's geometric shadow, leaving unrelated map regions and HUD
untouched. Door and curtain writes invalidate before changing opacity; movement
invalidates old/new neighborhoods and owned viewers refresh synchronously after
movement callbacks rather than intentionally waiting for the process. Smooth
blocker/target offsets enter the mask geometry. Unhooked direct opacity writers
still rely on the periodic raw audit; native callback yielding and actual display
latency remain explicit fixture requirements, not proved by source tests.
