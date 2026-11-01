# Human movement during world saves: candidate boundaries

The candidate remains disabled in production builds. It captures an unlinked
human's position at a movement boundary without holding that human for the
world save. The candidate validates the saved graph and destination before
publishing a completion marker. Ordinary saves and restart-owned saves use the
same capture path; an admitted restart must own the save operation. Load,
startup and dimension recovery holds are not bypassed.

This proof is deliberately incomplete. A saveable human in a container, an
unsettled pull, buckle, ride or other physical control relationship, a changed
or unavailable roster member, an unproved saved parent or slot, or an unknown
reference can reject the whole candidate. The geometry proof currently admits
only the exact floor and item types in `human_spatial_audited_floor` and
`human_spatial_audited_item`, with encoded nondense values. Other occupants,
including another human, and unaudited floor subtypes fail closed. This applies
even when the human's captured offsets are zero. It can reject a whole world
save; it does not silently turn off the proof or immobilize the player.

The proposed local expansion includes selected grass, snow, dirt and sand types
and selected dropped flint, hatchet and pickaxe types. It still does not cover
ordinary furniture, most dropped items, terrain, animals or players sharing a
checked turf. In particular, the current loader's destination check calls
`CanPass` for every movable on every touched turf; a simple geometric
non-overlap test in the saver alone cannot prove that the loader will accept
two adjacent humans. The loader and that acceptance contract need joint review
and synthetic tests before widening this case.

A static count of `maps/nomads/nomads_gaia.dmm` found 26,312 cells of the
original three exact floor types and 66,285 of the proposed twelve, out of
350,000 cells. This is a map-template count, not a measure of walkable cells,
live terrain, player positions or save success. The expanded set adds captured
density and transformation fields to approximately 39,973 additional template
cells. Save latency and size impacts have not been measured. No claim of Gaia
readiness follows from these counts or from a headless fixture.

The existing synthetic fixture can replace its ordinary positive floor and
dropped item without increasing its process count. Expanding it to prove
multiple simultaneous human placements, connected input, real-world save
latency or additional states requires a separately reviewed execution scope.
