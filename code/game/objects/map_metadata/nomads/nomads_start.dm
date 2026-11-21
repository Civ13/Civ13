// Random new-player starts on a starting land (docs/land-stages.md). A Nomads
// map that sets new_player_start_z places each new nomad on a random safe
// outdoor tile of that level; faction members may start at their station and
// players with a home bed in it.

#define START_SPAWN_ATTEMPTS 512
#define START_SPAWN_REACH_LIMIT 64
#define START_SPAWN_CONTENT_LIMIT 64

// The authored outdoor level new nomads start on, or 0 for no random starts.
// Not world.maxz: roofs and isolated instances may add levels above it.
/obj/map_metadata/nomads/var/new_player_start_z = 0

/obj/map_metadata/proc/uses_random_new_player_spawn(datum/job/job)
	return FALSE

/obj/map_metadata/nomads/uses_random_new_player_spawn(datum/job/job)
	return new_player_start_z && istype(job, /datum/job/civilian/civnomad)

// These are the climates handled by nomads_spawn(), not a new language table.
/obj/map_metadata/nomads/proc/new_player_ground(turf/floor/T)
	if (!istype(T) || T.z != new_player_start_z || T.density || T.water_level || T.watertile || T.radiation || T.to_be_destroyed)
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
	if (T.contents.len > START_SPAWN_CONTENT_LIMIT)
		return FALSE
	for (var/atom/movable/AM in T)
		if (AM.density || AM.radiation || istype(AM, /mob/living) || istype(AM, /obj/structure) || istype(AM, /obj/covers) || istype(AM, /obj/roof) || istype(AM, /obj/effect/fire) || istype(AM, /obj/item/mine) || istype(AM, /obj/item/weapon/beartrap))
			return FALSE
	return TRUE

// Reject tiny trapped pockets. Only cardinal dry, unobstructed steps count;
// this is bounded local egress, not a promise of a route to every settlement.
/obj/map_metadata/nomads/proc/new_player_has_exit(turf/start)
	if (!new_player_ground(start))
		return FALSE
	var/list/reachable = list(start)
	for (var/i = 1, i <= START_SPAWN_REACH_LIMIT, i++)
		if (i > reachable.len)
			break
		var/turf/current = reachable[i]
		if (get_dist(start, current) >= 4)
			return TRUE
		for (var/direction in cardinal)
			var/turf/next = get_step(current, direction)
			if (!next || (next in reachable) || !new_player_ground(next))
				continue
			if (reachable.len >= START_SPAWN_REACH_LIMIT)
				return FALSE
			reachable += next
	return FALSE

/obj/map_metadata/nomads/proc/pick_new_player_ground()
	// Independent uniform coordinates make every currently eligible surface
	// tile equally likely. No landmark/biome weighting or map-sized cache.
	for (var/attempt = 1, attempt <= START_SPAWN_ATTEMPTS, attempt++)
		var/turf/T = locate(rand(1, world.maxx), rand(1, world.maxy), new_player_start_z)
		if (new_player_has_exit(T))
			return T
	// Fail closed in the lobby. Never fall back to a landmark or unsafe tile.
	return null

/obj/map_metadata/nomads/proc/new_player_destination(mob/new_player/lobby)
	// A member who chose to start with their faction (faction_roster.dm).
	var/turf/faction_turf = lobby.faction_start_destination()
	if (faction_turf)
		return faction_turf
	// A signal fire whose keeper invited newcomers (immigration_fires.dm).
	var/turf/fire_turf = immigration_start_turf(lobby)
	if (fire_turf)
		return fire_turf
	// Existing home-bed respawns are distinct from first starts, just as saved
	// body reclaim is. Match the established region_home_bed_spawn contract.
	if (region_home_enabled() && lobby.client && !IsGuestKey(lobby.client.key))
		var/obj/structure/bed/B = region_home_bed(lobby.client.owner_key())
		if (B && B.valid_character_bed(null))
			return get_turf(B)
	// An account in its first two days starts near people (newcomer_start.dm).
	var/turf/near_people = pick_newcomer_ground(lobby.client)
	if (near_people)
		return near_people
	return pick_new_player_ground()

#undef START_SPAWN_ATTEMPTS
#undef START_SPAWN_REACH_LIMIT
#undef START_SPAWN_CONTENT_LIMIT
