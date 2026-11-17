// New players start near people (chat feedback, 2026-11-17). A random start
// could land a newcomer hundreds of tiles from anyone. An account in its
// first two days (the same window staff see the "new player" mark for) starts
// a short walk from the largest group of awake players outdoors, on a tile
// that passes the usual safe-start checks. With nobody about, or no safe
// tile found, the ordinary random start applies. Nobody is put into a
// faction: joining one still happens in play.

#define NEWCOMER_MIN_DISTANCE 40
#define NEWCOMER_MAX_DISTANCE 80
#define NEWCOMER_GROUP_RADIUS 30
#define NEWCOMER_ATTEMPTS 60

// Awake, connected people standing outdoors on the starting level.
/obj/map_metadata/nomads/proc/newcomer_hosts()
	var/list/hosts = list()
	for (var/client/C in clients)
		var/mob/living/human/H = C.mob
		if (!istype(H) || H.stat != CONSCIOUS || istype(H, /mob/living/human/practice))
			continue
		var/turf/T = get_turf(H)
		if (!T || T.z != new_player_start_z)
			continue
		var/area/A = get_area(T)
		if (!A || A.location != AREA_OUTSIDE)
			continue
		hosts += H
	return hosts

// The person with the most other hosts around them, or null.
/obj/map_metadata/nomads/proc/newcomer_gathering(list/hosts)
	var/mob/living/human/best = null
	var/best_count = 0
	for (var/mob/living/human/H in hosts)
		var/count = 0
		for (var/mob/living/human/other in hosts)
			if (get_dist(H, other) <= NEWCOMER_GROUP_RADIUS)
				count++
		if (count > best_count)
			best = H
			best_count = count
	return best

// A safe start NEWCOMER_MIN_DISTANCE to NEWCOMER_MAX_DISTANCE tiles from centre.
/obj/map_metadata/nomads/proc/newcomer_ground_near(turf/centre)
	if (!centre)
		return null
	for (var/attempt = 1, attempt <= NEWCOMER_ATTEMPTS, attempt++)
		var/angle = rand(0, 359)
		var/distance = rand(NEWCOMER_MIN_DISTANCE, NEWCOMER_MAX_DISTANCE)
		var/x = round(centre.x + distance * cos(angle))
		var/y = round(centre.y + distance * sin(angle))
		if (x < 1 || y < 1 || x > world.maxx || y > world.maxy)
			continue
		var/turf/T = locate(x, y, new_player_start_z)
		if (T && new_player_has_exit(T))
			return T
	return null

/obj/map_metadata/nomads/proc/pick_newcomer_ground(client/C)
	if (!new_player_start_z || !new_player_marks.is_new(C))
		return null
	var/mob/living/human/host = newcomer_gathering(newcomer_hosts())
	var/turf/T = host ? newcomer_ground_near(get_turf(host)) : null
	if (T)
		log_game("[key_name(C)] is new and starts near [key_name(host)] at ([T.x],[T.y],[T.z]).")
	return T

#undef NEWCOMER_MIN_DISTANCE
#undef NEWCOMER_MAX_DISTANCE
#undef NEWCOMER_GROUP_RADIUS
#undef NEWCOMER_ATTEMPTS
