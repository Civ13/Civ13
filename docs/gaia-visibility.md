# Gaia geometric visibility and root-owned tree presentation

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
