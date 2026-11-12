// Plane pools (docs/craft-core.md): where charts get the map they load sites
// onto. BYOND cannot grow the world safely on a 32-bit server, so a region
// that loads things on demand compiles a fixed pool of levels and hands them
// out. A pool claims and releases planes, counts what each owner holds and
// can be paused by an admin when memory is tight.
//
// A plane can be emptied before reuse (clear()), refused while a character
// or a claimed bunk is on it. A plane can also be shared: a pool with a
// slot_size hands out squares of a plane (a transit plane for craft in
// flight, patches of open space where craft meet). Owners named "site:..."
// are loaded sites and share a cap, so stations keep their share of the pool.
//
// The orbit pool wraps the plane registry orbit regions already have
// (space/orbit_world.dm).

/datum/plane_pool
	var/name = "plane pool"
	var/paused = FALSE            // No new claims while TRUE.
	// The most planes that owners named "site:..." (loaded sites) may hold
	// together, so stations keep their share. 0 means no limit.
	var/site_cap = 0
	// The side of a slot in tiles. A plane with slots is shared: each slot
	// is a square of it handed to one owner. 0 means planes have no slots.
	var/slot_size = 0
	var/list/slot_owners = list() // "z:n" = owner

// Every level this pool hands out.
/datum/plane_pool/proc/all_planes()
	return list()

// Levels nobody holds.
/datum/plane_pool/proc/free_planes()
	return list()

/datum/plane_pool/proc/planes_of(owner)
	return list()

/datum/plane_pool/proc/owner_of(z)
	return null

// The most planes one owner may hold, or 0 for no limit.
/datum/plane_pool/proc/quota(owner)
	return 0

/datum/plane_pool/proc/is_paused()
	return paused

/datum/plane_pool/proc/set_paused(state)
	paused = state ? TRUE : FALSE

// The planes loaded sites hold.
/datum/plane_pool/proc/site_planes()
	. = list()
	for (var/z in all_planes())
		var/owner = owner_of(z)
		if (istext(owner) && findtext(owner, "site:") == 1)
			. += z

// Why owner cannot have a plane now, or null.
/datum/plane_pool/proc/claim_refusal(owner)
	if (is_paused())
		return "loading is paused"
	if (!istext(owner) || !length(owner))
		return "nobody is asking"
	var/limit = quota(owner)
	if (limit && length(planes_of(owner)) >= limit)
		return "that owner already holds [limit] planes"
	if (site_cap && findtext(owner, "site:") == 1 && length(site_planes()) >= site_cap)
		return "every encounter plane is in use"
	if (!length(free_planes()))
		return "every plane is taken"
	return null

// A plane for owner, or 0.
/datum/plane_pool/proc/claim(owner)
	return 0

// Gives a plane back. With clear it is emptied first, and kept when it
// cannot be (clear_refusal()).
/datum/plane_pool/proc/release(z, clear = FALSE)
	return FALSE

// ---- Clearing ----

// What an emptied plane is made of, or null to leave its turfs alone.
/datum/plane_pool/proc/base_turf(z)
	return null

// The area an emptied plane belongs to, or null to leave areas alone.
/datum/plane_pool/proc/base_area(z)
	return null

// Why plane z cannot be emptied, or null: a character aboard, awake, asleep
// or logged out, or a bunk somebody keeps as home.
/datum/plane_pool/proc/clear_refusal(z)
	if (!(z in all_planes()))
		return "that is not one of this pool's planes"
	for (var/turf/T in block(locate(1, 1, z), locate(world.maxx, world.maxy, z)))
		for (var/atom/movable/A in T)
			var/mob/living/human/H = A
			if (istype(H) && (H.stat != DEAD || H.client))
				return "[H.real_name || H.name] is there"
			var/obj/structure/bed/B = A
			if (istype(B) && B.persistence_bed_owner_ckey)
				return "someone keeps a bunk there as home"
	return null

// Empties plane z: everything on it is deleted and its turfs go back to the
// base turf. FALSE with nothing changed when it cannot be (clear_refusal()).
/datum/plane_pool/proc/clear(z)
	if (clear_refusal(z))
		return FALSE
	var/base = base_turf(z)
	var/area/home = base_area(z)
	for (var/turf/T in block(locate(1, 1, z), locate(world.maxx, world.maxy, z)))
		for (var/atom/movable/A in T)
			if (isobserver(A) || istype(A, /atom/movable/lighting_overlay) || istype(A, /atom/movable/lighting_fullbright))
				continue
			qdel(A)
		if (base && T.type != base)
			T = T.ChangeTurf(base) || T
		if (home && T.loc != home)
			home.contents += T
	forget_slots(z)
	return TRUE

// ---- Slots ----

// Where slot ownership is kept: "z:n" = owner. A pool whose slots must
// outlive a restart keeps the table somewhere saved.
/datum/plane_pool/proc/slot_table()
	return slot_owners

/datum/plane_pool/proc/slot_count()
	return slot_size > 0 ? round(world.maxx / slot_size) * round(world.maxy / slot_size) : 0

// The tiles of slot n: list(x1, y1, x2, y2), or null.
/datum/plane_pool/proc/slot_box(n)
	if (!isnum(n) || n < 1 || n > slot_count())
		return null
	var/across = round(world.maxx / slot_size)
	var/column = (n - 1) % across
	var/row = round((n - 1) / across)
	return list(column * slot_size + 1, row * slot_size + 1, (column + 1) * slot_size, (row + 1) * slot_size)

/datum/plane_pool/proc/slot_owner(z, n)
	var/owner = slot_table()["[z]:[n]"]
	return (istext(owner) && length(owner)) ? owner : null

// The slot an owner holds: list(z, n), or null.
/datum/plane_pool/proc/slot_of(owner)
	if (!istext(owner) || !length(owner))
		return null
	var/list/table = slot_table()
	for (var/key in table)
		if (table[key] == owner)
			var/list/parts = splittext(key, ":")
			return list(text2num(parts[1]), text2num(parts[2]))
	return null

// The lowest free slot of plane z for owner: its number, or 0. An owner
// holds one slot at a time.
/datum/plane_pool/proc/claim_slot(owner, z)
	if (!istext(owner) || !length(owner) || !(z in all_planes()) || slot_of(owner))
		return 0
	for (var/n = 1, n <= slot_count(), n++)
		if (!slot_owner(z, n))
			slot_table()["[z]:[n]"] = owner
			return n
	return 0

// Drops every slot claim on plane z.
/datum/plane_pool/proc/forget_slots(z)
	var/list/table = slot_table()
	for (var/key in table.Copy())
		if (findtext(key, "[z]:") == 1)
			table -= key

/datum/plane_pool/proc/release_slot(z, n)
	var/list/table = slot_table()
	if (isnull(table["[z]:[n]"]))
		return FALSE
	table -= "[z]:[n]"
	return TRUE

// The pool of an orbit world: the plane registry (space/orbit_world.dm),
// which also keeps the slot table and the pause switch across restarts.
/datum/plane_pool/orbit
	name = "orbit plane pool"
	site_cap = 4
	slot_size = 32

/datum/plane_pool/orbit/all_planes()
	. = list()
	if (!orbit_get_registry())
		return
	for (var/z = 2, z <= world.maxz, z++)
		. += z

/datum/plane_pool/orbit/free_planes()
	return orbit_free_planes()

/datum/plane_pool/orbit/planes_of(owner)
	return orbit_owned_planes(owner)

/datum/plane_pool/orbit/owner_of(z)
	return orbit_plane_owner(z)

/datum/plane_pool/orbit/quota(owner)
	// A loaded site holds one plane; the cap on sites is site_cap.
	if (istext(owner) && findtext(owner, "site:") == 1)
		return 1
	return orbit_station_plane_quota()

/datum/plane_pool/orbit/is_paused()
	var/obj/structure/orbit_registry/R = orbit_get_registry()
	return R ? (R.pool_paused ? TRUE : FALSE) : paused

/datum/plane_pool/orbit/set_paused(state)
	var/obj/structure/orbit_registry/R = orbit_get_registry()
	if (R)
		R.pool_paused = state ? 1 : 0
	paused = state ? TRUE : FALSE

/datum/plane_pool/orbit/slot_table()
	var/obj/structure/orbit_registry/R = orbit_get_registry()
	if (!R)
		return slot_owners
	if (!islist(R.slot_owners))
		R.slot_owners = list()
	return R.slot_owners

/datum/plane_pool/orbit/base_turf(z)
	return /turf/floor/space/orbit

/datum/plane_pool/orbit/base_area(z)
	return locate(/area/caribbean/nomads/orbit)

/datum/plane_pool/orbit/claim(owner)
	if (claim_refusal(owner))
		return 0
	return orbit_claim_plane(owner)

/datum/plane_pool/orbit/release(z, clear = FALSE)
	if (clear && !src.clear(z))
		return FALSE
	. = orbit_release_plane(z)
	if (.)
		forget_slots(z)

var/global/datum/plane_pool/orbit/orbit_pool_made = null

// The pool of this orbit world, or null off an orbit world.
/proc/orbit_pool()
	if (!orbit_world())
		return null
	if (!orbit_pool_made)
		orbit_pool_made = new /datum/plane_pool/orbit
	return orbit_pool_made
