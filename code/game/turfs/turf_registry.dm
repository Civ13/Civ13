// Membership of the global turfs list, kept as one bit per map cell.
// A replaced turf keeps its cell, so a constructor that runs again for the
// same cell (ChangeTurf, a repeated New) never adds a second entry.
// This was an associative list keyed by turf. BYOND inserts sequential
// references into such a list in quadratic time: measured on 516.1688, one
// million inserts took 310 s and a 1132 x 920 map spent most of its boot here.
#define TURF_REGISTRY_WORD_BITS 16

// One list of words per z, allocated on first use.
var/global/list/turf_registry_planes = list()
// The world width the cell numbers were computed with.
var/global/turf_registry_width = 0

/proc/turf_registry_plane(z)
	if (turf_registry_width != world.maxx)
		turf_registry_rebuild()
	while (turf_registry_planes.len < z)
		turf_registry_planes += null
	var/list/plane = turf_registry_planes[z]
	if (!plane)
		plane = new /list(round((world.maxx * world.maxy + TURF_REGISTRY_WORD_BITS - 1) / TURF_REGISTRY_WORD_BITS))
		turf_registry_planes[z] = plane
	return plane

// The world was resized (only possible before the first turf registers in
// production): number the cells again from the list itself.
/proc/turf_registry_rebuild()
	turf_registry_width = world.maxx
	turf_registry_planes = list()
	for (var/turf/T in turfs)
		turf_registry_add(T)

/proc/turf_registry_has(turf/T)
	if (!T || T.z < 1)
		return FALSE
	var/list/plane = turf_registry_plane(T.z)
	var/cell = (T.y - 1) * turf_registry_width + T.x - 1
	var/word = round(cell / TURF_REGISTRY_WORD_BITS) + 1
	if (word > plane.len)
		return FALSE
	return (plane[word] & (1 << (cell % TURF_REGISTRY_WORD_BITS))) ? TRUE : FALSE

// TRUE when the cell was not registered before; the caller adds it to turfs.
/proc/turf_registry_add(turf/T)
	if (!T || T.z < 1)
		return FALSE
	var/list/plane = turf_registry_plane(T.z)
	var/cell = (T.y - 1) * turf_registry_width + T.x - 1
	var/word = round(cell / TURF_REGISTRY_WORD_BITS) + 1
	if (word > plane.len)
		plane.len = word
	var/bit = 1 << (cell % TURF_REGISTRY_WORD_BITS)
	if (plane[word] & bit)
		return FALSE
	plane[word] |= bit
	return TRUE

/proc/turf_registry_remove(turf/T)
	if (!T || T.z < 1 || T.z > turf_registry_planes.len)
		return
	var/list/plane = turf_registry_planes[T.z]
	if (!plane || turf_registry_width != world.maxx)
		return
	var/cell = (T.y - 1) * turf_registry_width + T.x - 1
	var/word = round(cell / TURF_REGISTRY_WORD_BITS) + 1
	if (word <= plane.len)
		plane[word] &= ~(1 << (cell % TURF_REGISTRY_WORD_BITS))

#undef TURF_REGISTRY_WORD_BITS
