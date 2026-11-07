// ============================================================
// Orbit world skeleton (orbital stations, stage A, inactive)
// ------------------------------------------------------------
// An orbit region (shard kind ORBIT, docs/orbital-stations-plan.md) is its
// own world: a compiled pool of small vacuum planes (maps/space/orbit.dmm,
// 64 x 64 x 24). Nothing grows the world at runtime; the plane registry
// hands planes out and records how they link: up and down (decks) and at
// the four edges (sectors). Plane 1 is the arrival plane and is never
// released.
//
// multiz_level_above/below answer from the registry on an orbit world, so
// ladders, cable risers and anything else that follows them use the plane
// graph. Walking onto the edge of a plane with a linked neighbour on that
// side moves the walker to the matching edge of the neighbour.
//
// Every plane but the first saves sparsely against vacuum (sparse kind
// "orbit", persistence/functions.dm). The registry is an ordinary saved
// object on plane 1 whose fields are plain text and numbers.
//
// No orbit content (launches, stations, modules) exists yet, and no live
// region uses this map.
// ============================================================

#define ORBIT_ARRIVAL_PLANE 1
#define ORBIT_STATION_PLANE_QUOTA 6
#define ORBIT_VACUUM_C -100

// TRUE on an orbit world (the map, not the shard kind, so fixtures work).
/proc/orbit_world()
	return istype(map, /obj/map_metadata/nomads/orbit)

// ---------------------------------------------------------------- ground

/turf/floor/space/orbit
	name = "vacuum"
	desc = "Open space. Nothing to stand on and nothing to breathe."
	is_diggable = FALSE

/turf/floor/space/orbit/outside_air_breathable()
	return FALSE

// The cold of open space, for code compiled before this file.
/proc/orbit_ambient_c()
	return ORBIT_VACUUM_C

/turf/floor/space/orbit/outside_ambient_c()
	return ORBIT_VACUUM_C

/area/caribbean/nomads/orbit
	name = "Orbit"
	base_turf = /turf/floor/space/orbit
	icon_state = "blue1"
	ambience = list()
	climate = "tundra"
	location = AREA_OUTSIDE

/obj/map_metadata/nomads/orbit
	title = "Orbit"
	description = "Open space above the world. Crews live in sealed stations they launch, dock and keep alive themselves."
	battle_name = "orbit"
	mission_start_message = "<big>Open space above the world. Crews live in sealed stations they launch, dock and keep alive themselves.</big>"
	valid_weather_types = list(WEATHER_NONE)
	ambience = list()

// ---------------------------------------------------------------- registry

var/global/obj/structure/orbit_registry/orbit_registry = null
var/global/list/orbit_directions = list("up" = UP, "down" = DOWN, "north" = NORTH, "east" = EAST, "south" = SOUTH, "west" = WEST)
var/global/list/orbit_opposites = list("up" = "down", "down" = "up", "north" = "south", "south" = "north", "east" = "west", "west" = "east")

// One per orbit world, on plane 1. Saved fields are text keys with number or
// text values only: links["z:dir"] = linked z, owners["z"] = owner id.
/obj/structure/orbit_registry
	name = "orbit registry"
	invisibility = 101
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/list/links = list()
	var/list/owners = list()

/obj/structure/orbit_registry/New()
	..()
	orbit_registry = src

/obj/structure/orbit_registry/Destroy()
	if (orbit_registry == src)
		orbit_registry = null
	return ..()

/obj/structure/orbit_registry/ex_act(severity)
	return

/proc/orbit_get_registry()
	if (!orbit_world())
		return null
	if (!orbit_registry || QDELETED(orbit_registry))
		var/turf/T = locate(1, 1, ORBIT_ARRIVAL_PLANE)
		if (!T)
			return null
		orbit_registry = locate(/obj/structure/orbit_registry) in T
		if (!orbit_registry)
			orbit_registry = new /obj/structure/orbit_registry(T)
	if (!islist(orbit_registry.links))
		orbit_registry.links = list()
	if (!islist(orbit_registry.owners))
		orbit_registry.owners = list()
	orbit_registry.owners["[ORBIT_ARRIVAL_PLANE]"] = "arrival"
	return orbit_registry

/proc/orbit_valid_plane(z)
	return isnum(z) && z == round(z) && z >= 1 && z <= world.maxz

/proc/orbit_valid_direction(direction)
	return istext(direction) && !isnull(orbit_directions[direction])

// The plane linked to z on that side ("up", "down", "north", ...), or 0.
/proc/orbit_plane_link(z, direction)
	var/obj/structure/orbit_registry/R = orbit_get_registry()
	if (!R || !orbit_valid_plane(z) || !orbit_valid_direction(direction))
		return 0
	var/target = R.links["[z]:[direction]"]
	return orbit_valid_plane(target) ? target : 0

// Links two planes both ways. Refuses a side already linked elsewhere.
/proc/orbit_link_planes(z, direction, other)
	var/obj/structure/orbit_registry/R = orbit_get_registry()
	if (!R || !orbit_valid_plane(z) || !orbit_valid_plane(other) || z == other || !orbit_valid_direction(direction))
		return FALSE
	var/back = orbit_opposites[direction]
	var/current = orbit_plane_link(z, direction)
	var/current_back = orbit_plane_link(other, back)
	if ((current && current != other) || (current_back && current_back != z))
		return FALSE
	R.links["[z]:[direction]"] = other
	R.links["[other]:[back]"] = z
	return TRUE

/proc/orbit_unlink_plane(z, direction)
	var/obj/structure/orbit_registry/R = orbit_get_registry()
	if (!R || !orbit_valid_plane(z) || !orbit_valid_direction(direction))
		return FALSE
	var/other = orbit_plane_link(z, direction)
	R.links -= "[z]:[direction]"
	if (other)
		R.links -= "[other]:[orbit_opposites[direction]]"
	return TRUE

/proc/orbit_plane_owner(z)
	var/obj/structure/orbit_registry/R = orbit_get_registry()
	if (!R || !orbit_valid_plane(z))
		return null
	var/owner = R.owners["[z]"]
	return istext(owner) && length(owner) ? owner : null

/proc/orbit_free_planes()
	var/list/free = list()
	if (!orbit_get_registry())
		return free
	for (var/z = ORBIT_ARRIVAL_PLANE + 1, z <= world.maxz, z++)
		if (!orbit_plane_owner(z))
			free += z
	return free

/proc/orbit_owned_planes(owner)
	var/list/owned = list()
	if (!istext(owner) || !orbit_get_registry())
		return owned
	for (var/z = ORBIT_ARRIVAL_PLANE + 1, z <= world.maxz, z++)
		if (orbit_plane_owner(z) == owner)
			owned += z
	return owned

// Takes the lowest free plane for owner, or 0 when the pool is empty or the
// owner already holds its quota. Linking it to the owner's other planes is
// the caller's choice (orbit_link_planes).
/proc/orbit_claim_plane(owner)
	var/obj/structure/orbit_registry/R = orbit_get_registry()
	if (!R || !istext(owner) || !length(owner) || owner == "arrival")
		return 0
	if (length(orbit_owned_planes(owner)) >= ORBIT_STATION_PLANE_QUOTA)
		return 0
	var/list/free = orbit_free_planes()
	if (!free.len)
		return 0
	var/z = free[1]
	R.owners["[z]"] = owner
	return z

// Frees a plane and cuts every link to it. Clearing what stands on it is
// separate (an admin confirms it in a later step).
/proc/orbit_release_plane(z)
	var/obj/structure/orbit_registry/R = orbit_get_registry()
	if (!R || !orbit_valid_plane(z) || z == ORBIT_ARRIVAL_PLANE)
		return FALSE
	for (var/direction in orbit_directions)
		orbit_unlink_plane(z, direction)
	R.owners -= "[z]"
	return TRUE

// ---------------------------------------------------------------- seams

// The side of the plane edge this turf is on, or null.
/turf/proc/orbit_edge_side()
	if (y >= world.maxy) return "north"
	if (y <= 1) return "south"
	if (x >= world.maxx) return "east"
	if (x <= 1) return "west"
	return null

// Where something stepping onto this edge turf arrives: one tile inside the
// matching edge of the linked plane, so it does not cross straight back.
/turf/proc/orbit_seam_destination()
	var/side = orbit_edge_side()
	if (!side)
		return null
	var/other = orbit_plane_link(z, side)
	if (!other)
		return null
	switch (side)
		if ("north") return locate(x, 2, other)
		if ("south") return locate(x, world.maxy - 1, other)
		if ("east") return locate(2, y, other)
		if ("west") return locate(world.maxx - 1, y, other)
	return null

/turf/floor/space/orbit/Entered(atom/movable/A, atom/old_loc)
	..()
	if (!A || A.loc != src || isobserver(A) || istype(A, /obj/effect) || istype(A, /obj/item/projectile))
		return
	if (istype(A, /atom/movable/lighting_overlay) || istype(A, /atom/movable/lighting_fullbright))
		return
	if (A.anchored)
		return
	var/turf/destination = orbit_seam_destination()
	if (!destination)
		return
	if (!persistence_movement_allowed(A, destination))
		return
	A.forceMove(destination)
