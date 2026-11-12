// Plane pools (docs/craft-core.md): where charts get the map they load sites
// onto. BYOND cannot grow the world safely on a 32-bit server, so a region
// that loads things on demand compiles a fixed pool of levels and hands them
// out. A pool claims and releases planes, counts what each owner holds and
// can be paused by an admin when memory is tight.
//
// The orbit pool wraps the plane registry orbit regions already have
// (space/orbit_world.dm). Clearing a plane before reuse and slots inside a
// plane come with the phase that loads sites.

/datum/plane_pool
	var/name = "plane pool"
	var/paused = FALSE            // No new claims while TRUE.

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

// Why owner cannot have a plane now, or null.
/datum/plane_pool/proc/claim_refusal(owner)
	if (paused)
		return "loading is paused"
	if (!istext(owner) || !length(owner))
		return "nobody is asking"
	var/limit = quota(owner)
	if (limit && length(planes_of(owner)) >= limit)
		return "that owner already holds [limit] planes"
	if (!length(free_planes()))
		return "every plane is taken"
	return null

// A plane for owner, or 0.
/datum/plane_pool/proc/claim(owner)
	return 0

/datum/plane_pool/proc/release(z)
	return FALSE

/datum/plane_pool/orbit
	name = "orbit plane pool"

/datum/plane_pool/orbit/free_planes()
	return orbit_free_planes()

/datum/plane_pool/orbit/planes_of(owner)
	return orbit_owned_planes(owner)

/datum/plane_pool/orbit/owner_of(z)
	return orbit_plane_owner(z)

/datum/plane_pool/orbit/quota(owner)
	return orbit_station_plane_quota()

/datum/plane_pool/orbit/claim(owner)
	if (claim_refusal(owner))
		return 0
	return orbit_claim_plane(owner)

/datum/plane_pool/orbit/release(z)
	return orbit_release_plane(z)
