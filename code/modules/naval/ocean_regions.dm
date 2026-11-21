// ============================================================
// The ocean regions (docs/ocean-regions.md)
// ------------------------------------------------------------
// Five oceans fill the water between the lands of the earth group, so every
// sea edge of every land leads somewhere: the Atlantic, the Pacific, the
// Indian, the Arctic and the Southern Ocean. Each is its own world: one level
// of deep salt water written by tools/ocean_maps/generate.py from
// tools/world_links/world_links.json, which also lists which stretch of which
// ocean edge meets which coast (world_sea_links in world_links.dm).
//
// An ocean is cheap on purpose: no underground, no open-air level, no
// heights, no plants and no land animals. The only land drawn is a small rock
// in the middle, where a traveller with nowhere better to stand is put down.
// Island lands that lie inside an ocean (Gaia and Greenland in the Atlantic)
// are insets: a block of breakers no ship sails through, whose sides lead to
// that land's coasts.
// ============================================================

/area/caribbean/nomads/ocean
	name = "Open Ocean"
	base_turf = /turf/floor/beach/water/deep/saltwater
	icon_state = "blue1"
	ambience = list("sound/ambience/ship1.ogg")
	climate = "sea"

/area/caribbean/nomads/ocean/cold
	name = "Cold Ocean"
	climate = "tundra"
	ambience = list("sound/ambience/winter.ogg")

// The waters round an island land inside an ocean (world_insets). Ships do
// not sail through them; they cross to the land at their edge.
/turf/floor/beach/water/deep/saltwater/breakers
	name = "breakers"
	desc = "White water breaking over the shoals off a coast. Land lies beyond."
	density = TRUE

/turf/floor/beach/water/deep/saltwater/breakers/CanPass(atom/movable/mover)
	return istype(mover, /obj/effect/effect/smoke) || istype(mover, /obj/item/projectile)

/turf/floor/beach/water/deep/saltwater/breakers/attackby(obj/item/C as obj, mob/user as mob)
	to_chat(user, SPAN_WARNING("The breakers would tear it away."))

/turf/floor/beach/water/deep/saltwater/breakers/fish_cast(obj/item/W, mob/living/human/user)
	to_chat(user, SPAN_WARNING("No line holds in the breakers."))

// TRUE on an ocean world.
/proc/ocean_world()
	return istype(map, /obj/map_metadata/nomads/ocean)

// This world's ocean id, or null.
/proc/ocean_id()
	var/obj/map_metadata/nomads/ocean/O = map
	return istype(O) ? O.ocean : null
