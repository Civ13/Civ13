// The sea layer: open water under the ocean that submarines dive into.
//
// A map with sea_layer_surface_z set turns the solid rock straight under its
// deep ocean, on the level below that surface, into open sea. Only cells
// under open water qualify: every neighbour on the surface must be deep
// saltwater as well, and every neighbour below must still be rock or sea, so a
// one-tile rock shell stays under the coast and around any tunnel dug there
// before. Continents, islands and shallows therefore wall the sea layer in,
// and a submerged boat goes only where the ocean above is open.
//
// Nobody walks or swims down here: a mob may stand only where a vessel's
// frame covers the tile, so crew stay aboard while submerged and a tunnel
// that later reaches the sea meets a wall of water rather than flooding.
// Loose objects that fall off a boat sink the way they do on the surface.
//
// The conversion runs once the startup import has settled (like the standing
// building level), and only ever changes rock into sea, so later rounds find
// it done and the scan costs a pass over the surface. Changed cells save like
// any other changed turf.

/obj/map_metadata/var/sea_layer_surface_z = 0

/turf/floor/beach/water/deep/saltwater/underwater/sea_layer
	name = "open sea"
	desc = "Cold, dark water under the ocean. Only a submarine can go here."

/turf/floor/beach/water/deep/saltwater/underwater/sea_layer/CanPass(atom/movable/mover)
	if (ismob(mover) && !iscovered())
		return FALSE
	return ..()

#define SEA_LAYER_POLL (5 SECONDS)

var/global/sea_layer_watch = FALSE
var/global/sea_layer_built = FALSE
var/global/sea_layer_converted = 0

// Open ocean at the surface: deep saltwater that is not itself under water.
/proc/sea_layer_open_surface(turf/T)
	return istype(T, /turf/floor/beach/water/deep/saltwater) && !istype(T, /turf/floor/beach/water/deep/saltwater/underwater)

/proc/sea_layer_cell(turf/T)
	return istype(T, /turf/floor/beach/water/deep/saltwater/underwater/sea_layer)

// The level the sea layer lies on for this map, or 0 when it has none.
/proc/sea_layer_z()
	if (!map || !map.sea_layer_surface_z)
		return 0
	return multiz_level_below(map.sea_layer_surface_z)

// TRUE when the rock at B (under surface cell S) may become sea.
/proc/sea_layer_candidate(turf/B, turf/S)
	if (!B || B.type != /turf/wall/rockwall || !sea_layer_open_surface(S))
		return FALSE
	for (var/atom/movable/M in B)
		if (M.density)
			return FALSE
	for (var/d in alldirs)
		var/turf/N = get_step(S, d)
		if (N && !sea_layer_open_surface(N))
			return FALSE
		var/turf/NB = get_step(B, d)
		if (NB && NB.type != /turf/wall/rockwall && !sea_layer_cell(NB))
			return FALSE
	return TRUE

// Converts every candidate cell; returns how many it changed. Pauses while a
// save runs so a save never captures a half-built layer twice over.
/proc/sea_layer_build(surface_z, below_z)
	. = 0
	if (!surface_z || !below_z)
		return
	for (var/y = 1, y <= world.maxy, y++)
		for (var/x = 1, x <= world.maxx, x++)
			var/turf/B = locate(x, y, below_z)
			if (!sea_layer_candidate(B, locate(x, y, surface_z)))
				continue
			B.ChangeTurf(/turf/floor/beach/water/deep/saltwater/underwater/sea_layer)
			.++
		CHECK_TICK
		while (persistence_save_in_progress)
			sleep(SEA_LAYER_POLL)

/proc/sea_layer_try()
	if (!map)
		return FALSE // Map metadata is not chosen yet.
	if (sea_layer_built || !map.sea_layer_surface_z)
		return TRUE
	var/below = sea_layer_z()
	if (!below)
		return TRUE // Nothing under this surface.
	if (!building_standing_ready())
		return FALSE
	sea_layer_built = TRUE
	sea_layer_converted = sea_layer_build(map.sea_layer_surface_z, below)
	if (sea_layer_converted)
		world.log << "Sea layer: [sea_layer_converted] cells of rock under the ocean opened to the sea on level [below]."
	return TRUE

/proc/sea_layer_watch_loop()
	set waitfor = FALSE
	if (sea_layer_watch)
		return
	sea_layer_watch = TRUE
	while (!sea_layer_try())
		sleep(SEA_LAYER_POLL)
	sea_layer_watch = FALSE

/hook/startup/proc/sea_layer()
	sea_layer_watch_loop()
	return TRUE

#undef SEA_LAYER_POLL
