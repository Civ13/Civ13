// ============================================================
// Asteroid mining (orbital stations, stage E)
// ------------------------------------------------------------
// Now and then a small asteroid drifts into a station's plane, out in open
// space. Crews go out on EVA to it:
//
// - Clip a safety tether to it to hold it beside the station; an untethered
//   asteroid drifts on and is gone after about half an hour of hazard clock.
// - Mine it with a pickaxe or jackhammer: each swing frees a few lumps of
//   iron, copper, water ice, and now and then silver or gold, until it is
//   worked out and crumbles.
//
// Asteroids only arrive while someone is online (the hazard clock), at most
// two on a station's planes at once. Ore left and drift left are plain saved
// numbers; nothing here is a world.time stamp.
// ============================================================

#define ORBIT_ASTEROID_CHANCE 4
#define ORBIT_ASTEROID_MAX 2
#define ORBIT_ASTEROID_DRIFT 1800
#define ORBIT_ASTEROID_MINE_DELAY 30
#define ORBIT_ASTEROID_MARGIN 4

var/global/list/orbit_asteroids = list()

// kind = list(ore path, lumps in a fresh asteroid (min, max))
var/global/list/orbit_asteroid_ores = list(
	"iron" = list(/obj/item/stack/ore/iron, 10, 16),
	"copper" = list(/obj/item/stack/ore/copper, 4, 8),
	"ice" = list(/obj/item/stack/ore/ice, 6, 10),
	"silver" = list(/obj/item/stack/ore/silver, 0, 3),
	"gold" = list(/obj/item/stack/ore/gold, 0, 2))

/obj/structure/orbit_asteroid
	name = "small asteroid"
	desc = "A tumbling lump of rock and ice a few metres across. Tether it before it drifts on, then mine it with a pickaxe or jackhammer."
	icon = 'icons/obj/mining.dmi'
	icon_state = "boulder1"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	// Ore left, as kind = lumps.
	var/list/ore = list()
	// Hazard-clock seconds until it drifts on, unless tethered.
	var/drift_left = ORBIT_ASTEROID_DRIFT
	var/tethered = FALSE

/obj/structure/orbit_asteroid/New()
	..()
	orbit_asteroids |= src
	icon_state = "boulder[rand(1, 4)]"

/obj/structure/orbit_asteroid/Destroy()
	orbit_asteroids -= src
	return ..()

// Gives a new asteroid its ore.
/obj/structure/orbit_asteroid/proc/fill()
	ore = list()
	for (var/kind in orbit_asteroid_ores)
		var/list/info = orbit_asteroid_ores[kind]
		var/n = rand(info[2], info[3])
		if (n > 0)
			ore[kind] = n

/obj/structure/orbit_asteroid/proc/lumps_left()
	var/n = 0
	for (var/kind in ore)
		n += ore[kind]
	return n

/obj/structure/orbit_asteroid/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE("About [lumps_left()] lumps of ore are left in it."))
	if (tethered)
		to_chat(user, SPAN_NOTICE("A tether holds it beside the station."))
	else
		to_chat(user, SPAN_WARNING("It is drifting: it will be gone in about [max(1, round(drift_left / 60))] minute\s unless tethered."))

/obj/structure/orbit_asteroid/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/eva_tether))
		if (tethered)
			to_chat(user, SPAN_WARNING("It is already tethered."))
			return
		if (!user.drop_from_inventory(W))
			return
		qdel(W)
		tethered = TRUE
		user.visible_message(SPAN_NOTICE("[user] clips a tether to \the [src] and pays it out to the station."), SPAN_NOTICE("You tether \the [src]. It will stay beside the station."))
		return
	if (istype(W, /obj/item/weapon/material/pickaxe))
		user.visible_message(SPAN_NOTICE("[user] starts chipping at \the [src]."))
		if (!do_after(user, ORBIT_ASTEROID_MINE_DELAY, src) || QDELETED(src))
			return
		var/got = mine_once(get_turf(user))
		to_chat(user, got ? SPAN_NOTICE("You break off [got].") : SPAN_WARNING("Nothing comes loose."))
		return
	return ..()

// Breaks off one swing's worth of ore at T. Returns what came loose, as
// text, or null. The asteroid crumbles once it is worked out.
/obj/structure/orbit_asteroid/proc/mine_once(turf/T)
	if (!length(ore))
		return null
	var/kind = pickweight(ore)
	var/n = min(ore[kind], rand(1, 3))
	ore[kind] -= n
	if (ore[kind] <= 0)
		ore -= kind
	var/list/info = orbit_asteroid_ores[kind]
	var/path = info[1]
	new path(T || get_turf(src), n)
	. = "[n] lump\s of [kind == "ice" ? "water ice" : "[kind] ore"]"
	if (!length(ore))
		visible_message(SPAN_NOTICE("\The [src] crumbles into dust, worked out."))
		qdel(src)

// Counts the drift down. Returns TRUE if it drifted away.
/obj/structure/orbit_asteroid/proc/drift(seconds)
	if (tethered)
		return FALSE
	drift_left -= seconds
	if (drift_left > 0)
		return FALSE
	visible_message(SPAN_NOTICE("\The [src] tumbles away into the dark."))
	qdel(src)
	return TRUE

// Asteroids on plane z.
/proc/orbit_asteroids_on(z)
	var/list/found = list()
	for (var/obj/structure/orbit_asteroid/A in orbit_asteroids)
		if (!QDELETED(A) && A.z == z)
			found += A
	return found

// Puts a fresh asteroid on a clear orbit tile of plane z. Returns it, or null.
/proc/orbit_asteroid_arrive(z)
	if (!z || z > world.maxz)
		return null
	var/m = ORBIT_ASTEROID_MARGIN
	for (var/i in 1 to 20)
		var/turf/T = locate(rand(m, world.maxx - m), rand(m, world.maxy - m), z)
		if (!istype(T, /turf/floor/space/orbit) || length(T.contents))
			continue
		var/obj/structure/orbit_asteroid/A = new(T)
		A.fill()
		return A
	return null

// One hazard step (orbit_upkeep.dm): drift asteroids on and, when roll is
// TRUE, maybe bring one to each station.
/proc/orbit_asteroid_step(seconds, roll = TRUE)
	for (var/obj/structure/orbit_asteroid/A in orbit_asteroids.Copy())
		if (!QDELETED(A))
			A.drift(seconds)
	if (!roll)
		return
	for (var/party in orbit_station_parties())
		var/list/planes = orbit_station_planes(party)
		if (!length(planes))
			continue
		var/count = 0
		for (var/p in planes)
			count += length(orbit_asteroids_on(p))
		if (count >= ORBIT_ASTEROID_MAX || !prob(ORBIT_ASTEROID_CHANCE * seconds / 60))
			continue
		var/obj/structure/orbit_asteroid/A = orbit_asteroid_arrive(pick(planes))
		if (A)
			orbit_station_announce(party, SPAN_NOTICE("Radar picks up a small asteroid drifting past the station. Tether it before it is gone."))

#undef ORBIT_ASTEROID_CHANCE
#undef ORBIT_ASTEROID_MAX
#undef ORBIT_ASTEROID_DRIFT
#undef ORBIT_ASTEROID_MINE_DELAY
#undef ORBIT_ASTEROID_MARGIN
