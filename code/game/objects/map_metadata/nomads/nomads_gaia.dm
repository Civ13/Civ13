
/obj/map_metadata/nomads/gaia
	ID = MAP_NOMADS_GAIA
	title = "Nomads (Gaia)"
	lobby_icon = "icons/lobby/gaia.png"
	songs = list("In the beginning there was nothing:1" = "sound/music/in_the_beginning.ogg",)
	research_active = TRUE
	building_levels = 1
	building_level_standing = TRUE
	// The rock under Gaia's deep ocean (level 1) opens to the sea for submarines.
	sea_layer_surface_z = 2


// Gaia's authored outdoors are on level 2; level 1 is underground. Do not use
// world.maxz: roofs and isolated instances may add levels above the surface.
#define GAIA_SURFACE_Z 2
#define GAIA_SPAWN_ATTEMPTS 512
#define GAIA_SPAWN_REACH_LIMIT 64
#define GAIA_SPAWN_CONTENT_LIMIT 64

/obj/map_metadata/proc/uses_random_new_player_spawn(datum/job/job)
	return FALSE

/obj/map_metadata/nomads/gaia/uses_random_new_player_spawn(datum/job/job)
	return istype(job, /datum/job/civilian/civnomad)

// These are the climates handled by nomads_spawn(), not a new language table.
/obj/map_metadata/nomads/gaia/proc/new_player_ground(turf/floor/T)
	if (!istype(T) || T.z != GAIA_SURFACE_Z || T.density || T.water_level || T.watertile || T.radiation || T.to_be_destroyed)
		return FALSE
	if (!(istype(T, /turf/floor/grass) || istype(T, /turf/floor/dirt) || istype(T, /turf/floor/beach/sand) || istype(T, /turf/floor/winter) || istype(T, /turf/floor/gravel) || istype(T, /turf/floor/rocky)))
		return FALSE
	if (istype(T, /turf/floor/dirt/underground))
		return FALSE
	var/area/A = get_area(T)
	if (!A || istype(A, /area/caribbean/admin) || A.location != AREA_OUTSIDE || A.is_void_area || A.no_air || !A.has_gravity)
		return FALSE
	if (!(A.climate in list("tundra", "taiga", "temperate", "semiarid", "sea", "desert", "savanna", "jungle")))
		return FALSE
	// Bound work even on a tile with a pathological pile of objects.
	if (T.contents.len > GAIA_SPAWN_CONTENT_LIMIT)
		return FALSE
	for (var/atom/movable/AM in T)
		if (AM.density || AM.radiation || istype(AM, /mob/living) || istype(AM, /obj/structure) || istype(AM, /obj/covers) || istype(AM, /obj/roof) || istype(AM, /obj/effect/fire) || istype(AM, /obj/item/mine) || istype(AM, /obj/item/weapon/beartrap))
			return FALSE
	return TRUE

// Reject tiny trapped pockets. Only cardinal dry, unobstructed steps count;
// this is bounded local egress, not a promise of a route to every settlement.
/obj/map_metadata/nomads/gaia/proc/new_player_has_exit(turf/start)
	if (!new_player_ground(start))
		return FALSE
	var/list/reachable = list(start)
	for (var/i = 1, i <= GAIA_SPAWN_REACH_LIMIT, i++)
		if (i > reachable.len)
			break
		var/turf/current = reachable[i]
		if (get_dist(start, current) >= 4)
			return TRUE
		for (var/direction in cardinal)
			var/turf/next = get_step(current, direction)
			if (!next || (next in reachable) || !new_player_ground(next))
				continue
			if (reachable.len >= GAIA_SPAWN_REACH_LIMIT)
				return FALSE
			reachable += next
	return FALSE

/obj/map_metadata/nomads/gaia/proc/pick_new_player_ground()
	// Independent uniform coordinates make every currently eligible surface
	// tile equally likely. No landmark/biome weighting or map-sized cache.
	for (var/attempt = 1, attempt <= GAIA_SPAWN_ATTEMPTS, attempt++)
		var/turf/T = locate(rand(1, world.maxx), rand(1, world.maxy), GAIA_SURFACE_Z)
		if (new_player_has_exit(T))
			return T
	// Fail closed in the lobby. Never fall back to a landmark or unsafe tile.
	return null

/obj/map_metadata/nomads/gaia/proc/new_player_destination(mob/new_player/lobby)
	// Existing home-bed respawns are distinct from first starts, just as saved
	// body reclaim is. Match the established region_home_bed_spawn contract.
	if (region_home_enabled() && lobby.client && !IsGuestKey(lobby.client.key))
		var/obj/structure/bed/B = region_home_bed(lobby.client.ckey)
		if (B && B.valid_character_bed(null))
			return get_turf(B)
	return pick_new_player_ground()

#undef GAIA_SURFACE_Z
#undef GAIA_SPAWN_ATTEMPTS
#undef GAIA_SPAWN_REACH_LIMIT
#undef GAIA_SPAWN_CONTENT_LIMIT
