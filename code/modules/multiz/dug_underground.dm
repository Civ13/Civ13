// Dug underground: single-level maps that opt in (dig_down_underground) get a
// cave level the first time someone digs a tunnel down from the surface.
// BYOND only appends levels, so the cave is physically world.maxz + 1 while
// it is logically below the surface (z 1). Ladders, digging and roofs ask the
// helpers below for "up" and "down" instead of using z + 1 / z - 1.
// A bedrock rim marks the level, so a restored world recognises it from its
// saved turfs alone; zone persistence restores its cave area.
#define DUG_SURFACE_Z 1
#define DUG_CAVE_NOISE_CELL 8

// Every single-level map has an underground (docs/underground-level.md); a
// map whose surface is not ground (open sea, orbit, a lobby) opts out.
/obj/map_metadata/var/dig_down_underground = TRUE
// A map compiled with its own underground level (Gaia, Desert, Jungle, Barren,
// Moon: z 1 under a z 2 surface) names it here. Its map file holds unformed
// rock there, which forms on demand like a dug cave (see below).
/obj/map_metadata/var/underground_compiled_z = 0
// Levels under the surface (docs/underground-level.md, "Deeper levels"): the
// cave and the deeper ones under it. Each deeper level is one more plane of
// unformed rock, added the first time someone digs down into it, and saved
// sparse around that rock, so a depth nobody reaches costs a header.
/obj/map_metadata/var/underground_depth = 4

/turf/wall/rockwall/bedrock
	name = "bedrock"
	desc = "Solid bedrock. Nothing can dig through it."
	damage = -100000

/turf/wall/rockwall/bedrock/attackby(obj/item/W, mob/user)
	to_chat(user, SPAN_WARNING("\The [src] is far too hard to work."))

/turf/wall/rockwall/bedrock/ex_act(severity)
	return FALSE

/turf/wall/rockwall/bedrock/take_damage(dam)
	return

/proc/dug_underground_supported()
	return map && map.dig_down_underground && building_base_maxz() == DUG_SURFACE_Z

// An unformed cave plane costs about 14 bytes a cell until it is dug (native
// grid plus cave area: +6 MB and +8 MB on a 1020 x 1020 plane, 2026-11-16), so
// it is admitted beside a surface up to the largest measured one, the
// Americas (1132 x 920 and 848 x 1224); see DUG_UNFORMED_MEASURED_CELLS.
#define DUG_UNFORMED_MEASURED_CELLS 1050000
/proc/dug_underground_fits()
	return world.maxx * world.maxy <= DUG_UNFORMED_MEASURED_CELLS

// The cave and the levels under it are the full levels a map may add below
// its surface. Each is added alone, the next time someone digs below the
// deepest one; a restore recreates saved ones through the building profile
// (building_admission.dm), which counts every underground level the map may
// have. Unformed rock costs about 14 bytes a cell, so the underground planes
// are left out of the charged cells: a dig is admitted whenever the other
// added planes still fit their measured profile.
/datum/world_z_budget/underground_admitted(target_z)
	var/limit = underground_depth_limit()
	if (!limit || target_z != world.maxz + 1 || !dug_underground_fits())
		return FALSE
	var/list/caves = underground_levels()
	if (caves.len >= limit)
		return FALSE
	var/levels = map.building_levels ? min(map.building_levels, initial(roof_limit)) : 0
	if (target_z > building_base_maxz() + underground_added_limit() + levels)
		return FALSE
	var/pending = (instance_reserve - instance_used) + (safehouse_reserve - safehouse_used)
	var/cells = world.maxx * world.maxy
	// Every plane but the compiled ones and the unformed underground.
	var/charged = target_z - (underground_added_count() + 1) + pending
	if (charged <= building_base_maxz())
		return TRUE // nothing but unformed rock is added
	if (map.building_level_standing && building_base_maxz() == 1 && !pending && cells * charged <= NEW_Z_STANDING_MEASURED_CELLS)
		return TRUE
	return cells * charged <= (map.building_levels ? NEW_Z_BUILDING_MEASURED_CELLS : NEW_Z_MEASURED_CELLS)

// The unformed underground planes are left out of the total-cell ceiling. A
// restore cannot see its underground until the cells load, so it counts every
// underground level the map may add.
/datum/world_z_budget/free_planes(target_z, purpose)
	if (target_z <= building_base_maxz() || !underground_depth_limit() || !dug_underground_fits())
		return 0
	if (purpose == "restore")
		return underground_added_limit()
	return min(underground_added_count() + (purpose == "underground" ? 1 : 0), underground_added_limit())

/datum/world_z_budget/ground_planes()
	return base_z + underground_added_count()

// How many open-air building levels stand above the compiled map: every added
// level but the dug cave and an open practice level.
/proc/building_levels_built()
	var/built = world.maxz - building_base_maxz() - underground_added_count()
	if (practice_room_z && practice_room_z > building_base_maxz())
		built--
	return max(built, 0)

// The underground levels, shallowest first: the compiled one (if the map has
// one), then the added ones in the order they were dug. A deeper level is only
// ever added under the deepest, so the added levels' z order is their depth
// order, and a restore, which recreates levels in z order, keeps it. Each
// added level carries a bedrock marker in its corner, so a restored world
// recognises its underground from the saved cells alone. The answer is kept
// (underground_live_levels, turf_changing.dm) while those markers stand.
var/global/underground_live_maxz = 0

/proc/underground_levels()
	if (!map)
		return list()
	if (underground_live_maxz && underground_live_maxz == world.maxz && !building_allocating_z)
		var/valid = TRUE
		for (var/z in underground_live_levels)
			if (z != map.underground_compiled_z && !istype(locate(1, 1, z), /turf/wall/rockwall/bedrock))
				valid = FALSE
				break
		if (valid)
			return underground_live_levels
	var/list/found = list()
	if (map.underground_compiled_z)
		found += map.underground_compiled_z
	var/limit = underground_depth_limit()
	for (var/z = building_base_maxz() + 1, z <= world.maxz && found.len < limit, z++)
		if (z != building_allocating_z && istype(locate(1, 1, z), /turf/wall/rockwall/bedrock))
			found += z
	underground_live_levels = found
	underground_live_maxz = building_allocating_z ? 0 : world.maxz
	return found

// Forgets the kept answer: a load or an allocation changed the levels.
/proc/underground_levels_refresh()
	underground_live_maxz = 0
	return underground_levels()

// How many levels this map may have under its surface, or 0 for none.
/proc/underground_depth_limit()
	if (!map)
		return 0
	if (map.underground_compiled_z)
		return max(1, map.underground_depth)
	return dug_underground_supported() ? max(0, map.underground_depth) : 0

// The underground levels added above the compiled map, and how many may be.
/proc/underground_added_count()
	var/list/caves = underground_levels()
	return caves.len - (map && map.underground_compiled_z ? 1 : 0)

/proc/underground_added_limit()
	var/limit = underground_depth_limit()
	return limit ? limit - (map.underground_compiled_z ? 1 : 0) : 0

// How deep z lies: 1 for the cave under the surface, 2 under that..., 0 when
// z is not underground.
/proc/underground_depth_of(z)
	if (!z)
		return 0
	var/list/caves = underground_levels()
	return caves.Find(z)

// TRUE for an underground level added above the compiled map: never a
// building level, whatever its z.
/proc/underground_added(z)
	return z > building_base_maxz() && underground_depth_of(z)

// The underground level at depth, or 0.
/proc/underground_z_at(depth)
	var/list/caves = underground_levels()
	return depth >= 1 && depth <= caves.len ? caves[depth] : 0

// The ground level straight over the underground (z 1, or Gaia's z 2).
/proc/underground_surface_z()
	var/list/caves = underground_levels()
	if (!caves.len)
		return DUG_SURFACE_Z
	var/list/column = multiz_column()
	return column.len > caves.len ? column[caves.len + 1] : DUG_SURFACE_Z

// The physical z of the dug cave (the first added underground level of a
// single-level map), or 0.
/proc/dug_underground_z()
	if (!dug_underground_supported())
		return 0
	var/list/caves = underground_levels()
	return caves.len ? caves[1] : 0

// Every level from the deepest underground up to the highest open-air level,
// in the order a ladder climbs them. BYOND only appends levels, so a level's
// z says nothing about its height: an added underground level may lie among
// the open-air levels. The practice level stands apart.
var/global/list/multiz_column_cache
var/global/list/multiz_column_caves
var/global/multiz_column_maxz = 0
var/global/multiz_column_practice = 0

/proc/multiz_column()
	var/list/caves = underground_levels()
	if (multiz_column_cache && caves == multiz_column_caves && multiz_column_maxz == world.maxz && multiz_column_practice == practice_room_z)
		return multiz_column_cache
	var/list/column = list()
	for (var/i = caves.len, i >= 1, i--)
		column += caves[i]
	for (var/z = 1 to world.maxz)
		if (z != practice_room_z && !(z in caves))
			column += z
	multiz_column_cache = column
	multiz_column_caves = caves
	multiz_column_maxz = world.maxz
	multiz_column_practice = practice_room_z
	return column

// Where a ladder, tunnel or falling item goes from z. 0 means solid ground.
/proc/multiz_level_below(z)
	if (practice_room_z && z == practice_room_z)
		return 0
	// An orbit world's decks are linked planes (space/orbit_world.dm).
	if (orbit_world())
		return orbit_plane_link(z, "down")
	var/list/column = multiz_column()
	var/i = column.Find(z)
	return i > 1 ? column[i - 1] : 0

/proc/multiz_level_above(z)
	if (practice_room_z && z == practice_room_z)
		return 0
	if (orbit_world())
		return orbit_plane_link(z, "up")
	var/list/column = multiz_column()
	var/i = column.Find(z)
	return i && i < column.len ? column[i + 1] : 0

// The highest ground level open to the sky (radiation, observer spawn). An
// underground level can be world.maxz while lying under the surface, and an
// added building level is open air over the surface (Gaia keeps one from
// round start).
/proc/multiz_top_z()
	var/list/column = multiz_column()
	var/top = column.len ? column[column.len] : world.maxz
	if (map && map.building_levels && top > building_base_maxz())
		return building_base_maxz()
	return top

/proc/dug_underground_area()
	for (var/area/caribbean/void/caves/A in world)
		if (A.type == /area/caribbean/void/caves)
			return A
	return new /area/caribbean/void/caves

// The rock that lies under one surface tile.
// What lies on the surface straight above an underground cell, as far as the
// rock under it cares (docs/underground-level.md, "Water above"): "sea" under
// deep saltwater, "wet" under a lake or a river, "mud" under shallows, swamp
// and coast water, "lava" under lava, null under everything else.
/proc/underground_above(turf/surface)
	if (!surface)
		return null
	if (istype(surface, /turf/floor/lava))
		return "lava"
	if (!is_liquid_water(surface))
		return null
	var/turf/floor/beach/water/W = surface
	if (istype(W, /turf/floor/beach/water/deep))
		return W.salty ? "sea" : "wet"
	if (!W.salty && !istype(W, /turf/floor/beach/water/swamp) && underground_river_at(W))
		return "wet"
	return "mud"

// TRUE where surface tile T belongs to a river reach (river_flood.dm).
/proc/underground_river_at(turf/T)
	if (!map)
		return FALSE
	var/datum/river_flood/F = map.river_flood()
	if (!F || T.z != F.z_level || T.x < 1 || T.x > F.maxx || T.y < 1 || T.y > F.maxy)
		return FALSE
	return F.reach_at(T.x, T.y) > 0

// The water or lava above underground cell T, as underground_above() reads it.
// Only the cave straight under the surface feels water or lava overhead;
// the levels under it lie beneath that cave's rock (see dug_underground_rock).
/proc/underground_above_cell(turf/T)
	if (!T)
		return null
	var/depth = underground_depth_of(T.z)
	if (depth > 1)
		return null
	// A level no map names as underground (a fixture, an old tunnel level)
	// lies under the level above it.
	var/surface_z = depth ? underground_surface_z() : (multiz_level_above(T.z) || DUG_SURFACE_Z)
	return underground_above(locate(T.x, T.y, surface_z))

// What the rock under surface tile T holds at depth: the cave under the
// surface feels every kind of water above; deeper levels lie under that rock,
// so only the sea floor and lava reach them.
/proc/underground_above_at(turf/surface, depth = 1)
	var/above = underground_above(surface)
	if (depth > 1 && (above == "wet" || above == "mud"))
		return null
	return above

/proc/dug_underground_rock(turf/surface, depth = 1)
	switch (underground_above_at(surface, depth))
		if ("sea")
			return /turf/wall/rockwall
		if ("wet")
			return /turf/floor/dirt/underground/wet
		if ("mud")
			return /turf/floor/dirt/underground/mud
		if ("lava")
			return /turf/floor/dirt/underground/hot
	if (istype(surface, /turf/floor/winter) || istype(surface, /turf/floor/dirt/winter) || istype(surface, /turf/floor/beach/water/ice))
		return /turf/floor/dirt/underground/icy
	if (istype(surface, /turf/floor/beach/sand) || istype(surface, /turf/floor/dirt/dust))
		return /turf/floor/dirt/underground/sandy
	return /turf/floor/dirt/underground

// Seeded lattice noise: a cell's rock is the same whenever it forms, so only
// the cells that formed are saved. The seed is the map's ID.
/proc/dug_underground_lattice(salt, gx, gy)
	var/hash = md5("[map ? map.ID : "map"]:[salt]:[gx]:[gy]")
	return text2num(copytext(hash, 1, 7), 16) / 16777216

/proc/dug_underground_noise(salt, x, y)
	var/fx = (x - 1) / DUG_CAVE_NOISE_CELL
	var/fy = (y - 1) / DUG_CAVE_NOISE_CELL
	var/gx = round(fx)
	var/gy = round(fy)
	var/tx = fx - gx
	var/ty = fy - gy
	var/a = dug_underground_lattice(salt, gx, gy)
	var/b = dug_underground_lattice(salt, gx + 1, gy)
	var/c = dug_underground_lattice(salt, gx, gy + 1)
	var/d = dug_underground_lattice(salt, gx + 1, gy + 1)
	var/top = a + (b - a) * tx
	var/bottom = c + (d - c) * tx
	return top + (bottom - top) * ty

// Per-cell jitter in [0, 1), so pocket edges are ragged but repeatable.
/proc/dug_underground_jitter(x, y, depth = 1)
	var/hash = md5(depth > 1 ? "[map ? map.ID : "map"]:cell[depth]:[x]:[y]" : "[map ? map.ID : "map"]:cell:[x]:[y]")
	return text2num(copytext(hash, 1, 5), 16) / 65536

// Each depth has its own pockets and veins; the cave keeps its original seed.
/proc/dug_underground_cell(x, y, surface_z = DUG_SURFACE_Z, depth = 1)
	if (x == 1 || y == 1 || x == world.maxx || y == world.maxy)
		return /turf/wall/rockwall/bedrock
	var/turf/surface = locate(x, y, surface_z)
	var/rock = dug_underground_rock(surface, depth)
	// No natural pockets under water or lava.
	if (underground_above_at(surface, depth))
		return rock
	var/salt = depth > 1 ? "[depth]" : ""
	if (dug_underground_noise("pocket[salt]", x, y) > 0.8 && dug_underground_jitter(x, y, depth) < 0.7)
		return /turf/floor/dirt
	if (dug_underground_noise("vein[salt]", x, y) > 0.82)
		return /turf/wall/rockwall
	return rock

// Unformed rock (docs/underground-level.md): the cave level is grown as the
// world's native open-air fill, with no constructor, lighting or saved field
// per cell. On the cave level that fill is solid rock nobody has reached yet.
// Real turfs form only around cells that open, so the cost of the level
// follows what players dig, not its size.
var/global/dug_underground_forming = FALSE
// Most cave-pocket cells one opening forms at once; past it a pocket's far
// side forms as plain rock and the rest of the pocket stays unformed.
#define DUG_POCKET_LIMIT 400

// Unformed rock compiled into a map's own underground level. Its constructor
// does nothing, as a native cell of an added level skips its constructor, so
// the level costs no registry entry, lighting or saved field per cell.
/turf/sky/building/unformed
	name = "rock"
	desc = "Solid rock nobody has dug into yet."
	lighting_never = TRUE

/turf/sky/building/unformed/New()
	return

// The cave straight under the surface: a compiled one, or the dug cave.
/proc/underground_level_z()
	return underground_z_at(1)

// Unformed rock: the native fill on any underground level.
/proc/dug_underground_unformed(turf/T)
	return T && istype(T, /turf/sky/building) && underground_depth_of(T.z)

// An unformed cell is rock no one has reached: nothing but a ghost moves in.
/turf/sky/building/Enter(atom/movable/O, atom/oldloc)
	if (!isobserver(O) && dug_underground_unformed(src))
		return FALSE
	return ..()

// Something put straight into unformed rock (a fall, a shaft, an admin) finds
// a pocket opened around it rather than being sealed in.
/turf/sky/building/Entered(atom/movable/A)
	if (!isobserver(A) && !istype(A, /atom/movable/lighting_overlay) && !istype(A, /atom/movable/lighting_fullbright) && !persistence_save_in_progress && dug_underground_unformed(src))
		ChangeTurf(/turf/floor/dirt)
		return
	return ..()

// Forms one unformed cell from the generator and lights it. With solid set,
// a pocket cell forms as rock instead (the edge of a capped pocket).
/proc/dug_underground_form(turf/T, solid = FALSE)
	if (!dug_underground_unformed(T))
		return T
	var/surface_z = underground_surface_z()
	var/depth = underground_depth_of(T.z)
	var/path = dug_underground_cell(T.x, T.y, surface_z, depth)
	if (solid && path == /turf/floor/dirt)
		path = dug_underground_rock(locate(T.x, T.y, surface_z), depth)
	var/was_forming = dug_underground_forming
	dug_underground_forming = TRUE
	var/turf/W = T.ChangeTurf(path)
	dug_underground_forming = was_forming
	if (W && !W.lighting_overlay && created_lighting_corners_and_overlays)
		var/area/A = W.loc
		if (A && A.dynamic_lighting && !(map && (W.z in map.zlevels_without_lighting)))
			W.lighting_build_overlay()
	return W

// An open cell must never touch unformed rock: forms its eight neighbours,
// and any cave pocket it breaks into, up to DUG_POCKET_LIMIT cells.
/proc/dug_underground_form_around(turf/start)
	// A load restores formed cells itself; forming around them would only be
	// overwritten by the cells still to come.
	if (!start || dug_underground_forming || persistence_save_in_progress || !underground_depth_of(start.z))
		return 0
	dug_underground_forming = TRUE
	var/formed = 0
	var/pocket = 0
	var/list/queue = list(start)
	var/i = 1
	try
		while (i <= queue.len)
			var/turf/open = queue[i++]
			for (var/d in alldirs)
				var/turf/N = get_step(open, d)
				if (!dug_underground_unformed(N))
					continue
				var/turf/W = dug_underground_form(N, pocket >= DUG_POCKET_LIMIT)
				formed++
				if (W && !W.density)
					pocket++
					queue += W
	catch (var/exception/e)
		dug_underground_forming = FALSE
		throw e
	dug_underground_forming = FALSE
	return formed

// An explosion that reaches unformed rock forms it first, then breaks it.
/turf/sky/building/ex_act(severity)
	if (!dug_underground_unformed(src))
		return ..()
	var/turf/W = dug_underground_form(src)
	if (W && !dug_underground_unformed(W))
		W.ex_act(severity)

// The core ChangeTurf hook (turf_changing.dm): a cell of the cave level that
// opens forms what lies around it. One opened under a lake or a river breaks
// through to it, and the water pours into the tunnel (flood_cellars.dm).
/turf/underground_opened()
	if (underground_above_cell(src) == "wet" && !(src in tunnel_breaches))
		tunnel_breaches += src
		if (!dug_underground_forming && !persistence_save_in_progress)
			visible_message(SPAN_DANGER("Water bursts through the rock overhead!"))
	dug_underground_form_around(src)

// Finds the open cells under lakes and rivers on underground level z, which
// pour into the tunnels (flood_cellars.dm). Run once the level is in place
// after a load; breaches are not saved.
/proc/underground_breach_scan(z)
	if (!z || underground_depth_of(z) != 1)
		return 0
	var/found = 0
	for (var/turf/T in block(locate(1, 1, z), locate(world.maxx, world.maxy, z)))
		if (T.density || istype(T, /turf/sky/building))
			continue
		if (underground_above_cell(T) == "wet")
			tunnel_breaches |= T
			found++
		CHECK_TICK
	return found

// Rock under a lake or a river: it holds the water back until it is broken.
/turf/floor/dirt/underground/wet
	name = "wet rock"
	desc = "Soft rock dripping with water. There is a lake or a river overhead: break it and the water comes in."

// Earth under shallows, swamp and coast water: an opened cell seeps a little.
/turf/floor/dirt/underground/mud
	name = "wet earth"
	desc = "Soft, wet earth. Water seeps in from the shallows overhead."

// Rock under lava: too hot to work, and it burns whoever touches it.
/turf/floor/dirt/underground/hot
	name = "hot rock"
	desc = "Rock glowing with the heat of the lava overhead. It is far too hot to dig."
	is_mineable = FALSE
	light_power = 1
	light_range = 2
	light_color = "#FF6A00"

/turf/floor/dirt/underground/hot/attackby(obj/item/W, mob/user)
	to_chat(user, SPAN_WARNING("\The [src] is far too hot to work. There is lava overhead."))
	underground_hot_burn(user)
	return TRUE

/turf/floor/dirt/underground/hot/attack_hand(mob/user)
	underground_hot_burn(user)

/turf/floor/dirt/underground/hot/Bumped(atom/movable/AM)
	underground_hot_burn(AM)
	return ..()

/proc/underground_hot_burn(mob/living/L)
	if (!istype(L) || L.stat == DEAD)
		return
	L.apply_damage(5, BURN)
	to_chat(L, SPAN_DANGER("The rock is searing hot!"))

// Native lighting covers the startup levels only. Unformed cells need none;
// formed cells of a restored cave get corners and overlays here.
/proc/dug_underground_light_level(z)
	if (!created_lighting_corners_and_overlays || (map && (z in map.zlevels_without_lighting)))
		return
	for (var/turf/T in block(locate(1, 1, z), locate(world.maxx, world.maxy, z)))
		if (T.type == /turf/sky/building)
			continue
		if (!T.lighting_overlay)
			for (var/i = 1 to 4)
				if (!T.get_corner(i))
					T.set_corner(i, new /datum/lighting_corner(T, LIGHTING_CORNER_DIAGONAL[i]))
			var/area/A = T.loc
			if (A && A.dynamic_lighting)
				T.lighting_build_overlay()
		TICK_CHECK

// Why the underground level at depth cannot be dug into yet, or null.
/proc/underground_dig_error(depth = 1)
	if (depth < 1 || depth > underground_depth_limit())
		return "There is only bedrock below."
	if (underground_z_at(depth))
		return null
	var/list/caves = underground_levels()
	if (depth != caves.len + 1)
		return "There is only bedrock below."
	if (persistence_save_in_progress || building_allocating_z || world_z_budget.active)
		return "The ground is settling. Try again shortly."
	return world_z_budget.error(world.maxz + 1, "underground")

/proc/dug_underground_error()
	if (!dug_underground_supported())
		return "There is only bedrock below."
	return underground_dig_error(1)

// Allocates the underground level at depth as unformed rock, under the
// deepest one. Returns TRUE once it exists.
/proc/underground_create(depth = 1)
	if (underground_z_at(depth))
		return TRUE
	if (underground_dig_error(depth))
		return FALSE
	var/target_z = world.maxz + 1
	var/datum/new_z_reservation/reservation = world_z_budget.reserve(target_z, "underground")
	if (!reservation)
		return FALSE
	if (!world_z_budget.claim_level(reservation, target_z))
		world_z_budget.finish(reservation, FALSE)
		return FALSE
	var/area/caves = dug_underground_area()
	building_allocating_z = target_z
	try
		// Native growth fills the plane with unformed rock (world.turf) in one
		// step, skipping every constructor (building_levels.dm). Area membership
		// is one bulk add (per-turf adds cost ~250x more).
		world.maxz = target_z
		caves.contents.Add(block(locate(1, 1, target_z), locate(world.maxx, world.maxy, target_z)))
	catch (var/exception/allocation_error)
		world_z_budget.finish(reservation, FALSE)
		// Keep the busy flag: a partly initialized native grid requires restart.
		throw allocation_error
	building_allocating_z = 0
	if (!world_z_budget.finish(reservation, world.maxz == target_z))
		return FALSE
	// The bedrock corner marks the level, so a restored world recognises it
	// from its saved cells alone.
	var/turf/marker = locate(1, 1, target_z)
	dug_underground_forming = TRUE
	marker.ChangeTurf(/turf/wall/rockwall/bedrock)
	dug_underground_forming = FALSE
	underground_levels_refresh()
	practice_rooms.underground_added(target_z)
	log_game("Underground level [depth] created at z [target_z] ([world.maxx]x[world.maxy]), unformed.")
	return underground_z_at(depth) == target_z

/proc/dug_underground_create()
	if (!dug_underground_supported())
		return FALSE
	return underground_create(1)

// Restored worlds: the load regenerates unformed cells in the world's default
// area, so the cave area is put back on them, and formed cells get the
// lighting that startup did not build (it ran before the level existed).
/map_storage/proc/restore_dug_underground()
	underground_levels_refresh()
	// Open cells under lakes and rivers pour again (they are not saved).
	tunnel_breaches.Cut()
	underground_breach_scan(underground_level_z())
	var/area/caves = dug_underground_area()
	for (var/z in underground_levels())
		if (z <= building_base_maxz())
			continue
		var/list/strays = list()
		for (var/turf/T in block(locate(1, 1, z), locate(world.maxx, world.maxy, z)))
			var/area/A = T.loc
			if (A != caves && A.type == world.area)
				strays += T
			TICK_CHECK
		if (strays.len)
			caves.contents.Add(strays)
		dug_underground_light_level(z)

// Starts every world with its cave level (unformed rock costs about five
// bytes a cell), after the startup import settles like the standing building
// level: a restore recreates a saved cave itself, and adding a level while a
// save waits to load would refuse that save. The standing open-air level waits
// for this, so the cave is always the first added level.
var/global/dug_underground_boot_done = FALSE

/proc/dug_underground_boot_try()
	if (!map)
		return FALSE
	underground_level_z() // A compiled underground starts forming at once.
	if (!dug_underground_supported() || dug_underground_z())
		dug_underground_boot_done = TRUE
		return TRUE
	if (!building_standing_ready())
		return FALSE
	if (!dug_underground_create())
		world.log << "Underground level refused: [world_z_budget.last_error ? world_z_budget.last_error : dug_underground_error()]"
	dug_underground_boot_done = TRUE
	return TRUE

/hook/startup/proc/dug_underground_level()
	dug_underground_boot_loop()
	return TRUE

/proc/dug_underground_boot_loop()
	set waitfor = FALSE
	while (!dug_underground_boot_try())
		sleep(5 SECONDS)

// Shoring a tunnel is craftsmanship (crafting, squared); the digging itself
// is labour (work_speed.dm) with the shovel in hand.
/proc/dug_underground_dig_time(mob/living/human/user, base)
	if (!istype(user))
		return base
	var/craft = user.getStatCoeff("crafting")
	return work_delay(user, base / max(0.25, craft * craft), WORK_DIG, user.get_active_hand())

/proc/dug_underground_finish(mob/living/human/user)
	user.adaptStat("crafting", 1)
	user.adaptStat("strength", 1)

// Tunnel digging on every map with an underground: from the surface down
// into the cave, and from any underground level up, or down into the next
// level while the map's depth allows. Returns TRUE when it handled the
// request, FALSE to fall back to the older fixed-level tunnel code.
/proc/dug_underground_tunnel(mob/living/human/user)
	if (!istype(user) || !underground_depth_limit())
		return FALSE
	var/turf/floor/here = get_turf(user)
	if (!istype(here))
		return FALSE
	var/depth = underground_depth_of(here.z)
	if (!depth)
		if (here.z == underground_surface_z())
			return dug_underground_tunnel_down(user, here, 1)
		return FALSE
	if (depth < underground_depth_limit())
		var/way = WWinput(user, "Dig up to the level above, or down into the rock below?", "Tunnel", "Down", list("Down", "Up", "Cancel"))
		if (way == "Cancel" || get_turf(user) != here)
			return TRUE
		if (way == "Down")
			return dug_underground_tunnel_down(user, here, depth + 1)
	return dug_underground_tunnel_up(user, here)

// Each level down is harder going: half as long again per level.
/proc/underground_shaft_time(depth)
	return 200 + 100 * (max(depth, 1) - 1)

/proc/dug_underground_tunnel_down(mob/living/human/user, turf/floor/here, depth = 1)
	if (locate(/obj/structure/multiz) in here)
		to_chat(user, SPAN_WARNING("There already is something here."))
		return TRUE
	if (!here.is_diggable)
		to_chat(user, SPAN_WARNING("You cannot dig a hole here!"))
		return TRUE
	var/error = underground_dig_error(depth)
	if (error)
		to_chat(user, SPAN_WARNING(error))
		return TRUE
	if (!dug_underground_open_below(user, here, FALSE, depth))
		return TRUE
	user.visible_message(SPAN_DANGER("[user] starts digging a tunnel downwards!"), SPAN_DANGER("You start digging a tunnel downwards."))
	if (!do_after(user, dug_underground_dig_time(user, underground_shaft_time(depth)), here))
		return TRUE
	if (get_turf(user) != here || (locate(/obj/structure/multiz) in here))
		return TRUE // another digger finished this entrance during the wait
	if (!underground_z_at(depth))
		user.visible_message(SPAN_DANGER("The ground groans as [user] breaks into the deep rock below!"), SPAN_DANGER("You break into the deep rock below. The ground groans and settles..."))
	if (!underground_create(depth))
		if (world_z_budget.last_error)
			log_debug("Underground level [depth] refused: [world_z_budget.last_error]")
		to_chat(user, SPAN_WARNING("The ground below will not give way."))
		return TRUE
	var/turf/below = dug_underground_open_below(user, here, TRUE, depth)
	if (!below)
		return TRUE
	new /obj/structure/multiz/ladder/ww2/tunneltop/pit(here)
	user.visible_message(SPAN_DANGER("[user] finishes digging the tunnel entrance."), SPAN_DANGER("You break through into the rock below."))
	excavation_shaft_spoil(user)
	dug_underground_finish(user)
	return TRUE

// Checks (and with open = TRUE, clears) the cell under a tile, on the
// underground level at depth.
/proc/dug_underground_open_below(mob/living/human/user, turf/here, open, depth = 1)
	var/dug = underground_z_at(depth)
	if (!dug)
		return !open // the level is generated when the digging finishes
	var/turf/below = dug_underground_form(locate(here.x, here.y, dug))
	if (!below || istype(below, /turf/wall) || istype(below, /turf/floor/dirt/underground/hot) || (locate(/obj/structure/multiz) in below))
		if (istype(below, /turf/floor/dirt/underground/hot))
			to_chat(user, SPAN_WARNING("The rock below is searing hot. You cannot dig down here."))
		else
			to_chat(user, SPAN_WARNING("You hit solid stone. You cannot dig down here."))
		return null
	if (!open)
		return below
	if (istype(below, /turf/floor/dirt/underground))
		below.ChangeTurf(/turf/floor/dirt)
	below = locate(here.x, here.y, dug)
	dug_underground_form_around(below)
	return below

/proc/dug_underground_tunnel_up(mob/living/human/user, turf/floor/here)
	if (locate(/obj/structure/multiz) in here)
		to_chat(user, SPAN_WARNING("There already is something here."))
		return TRUE
	var/up_z = multiz_level_above(here.z)
	var/turf/above = up_z ? locate(here.x, here.y, up_z) : null
	// Under another underground level the shaft breaks into its rock.
	var/deep = above && underground_depth_of(up_z)
	if (deep)
		above = dug_underground_form(above)
	if (!above || (deep ? underground_shaft_blocked(above) : dug_underground_surface_blocked(above)))
		switch (deep ? null : underground_above(above))
			if ("lava")
				to_chat(user, SPAN_WARNING("The rock overhead is searing hot. There is lava above; you cannot dig up here."))
			if ("sea", "wet", "mud")
				to_chat(user, SPAN_WARNING("Water drips from the rock overhead. Digging up here would bring the water down on you."))
			else
				to_chat(user, SPAN_NOTICE("You can't dig up here, there is something blocking the way!"))
		return TRUE
	user.visible_message(SPAN_DANGER("[user] starts digging up!"), SPAN_NOTICE("You start digging up."))
	if (!do_after(user, dug_underground_dig_time(user, 400), here))
		return TRUE
	if (get_turf(user) != here || (locate(/obj/structure/multiz) in here))
		return TRUE
	above = locate(here.x, here.y, up_z)
	if (deep ? underground_shaft_blocked(above) : dug_underground_surface_blocked(above))
		return TRUE
	if (deep && istype(above, /turf/floor/dirt/underground))
		above = above.ChangeTurf(/turf/floor/dirt)
	new /obj/structure/multiz/ladder/ww2/tunneltop/pit(above)
	user.visible_message(SPAN_DANGER("[user] finishes digging up!"), SPAN_NOTICE("You finish digging up."))
	excavation_shaft_spoil(user)
	dug_underground_finish(user)
	return TRUE

// An underground cell a shaft from below cannot open: solid stone, hot rock,
// or something already standing there.
/proc/underground_shaft_blocked(turf/T)
	if (!T || dug_underground_unformed(T) || istype(T, /turf/wall) || istype(T, /turf/floor/dirt/underground/hot))
		return TRUE
	for (var/obj/O in T)
		if (O.density || istype(O, /obj/structure/multiz))
			return TRUE
	return FALSE

/proc/dug_underground_surface_blocked(turf/above)
	var/turf/floor/F = above
	if (!istype(F) || !F.is_diggable || istype(F, /turf/floor/beach/water) || istype(F, /turf/floor/lava))
		return TRUE
	for (var/obj/O in above)
		if (istype(O, /obj/covers) || O.density || istype(O, /obj/structure/multiz) || istype(O, /obj/structure/rails))
			return TRUE
	return FALSE

#undef DUG_CAVE_NOISE_CELL
#undef DUG_POCKET_LIMIT

// Admin > Debug: what every level holds, so staff can see how far play has
// reached into the cave and the open-air levels (docs/underground-level.md).
/proc/level_report_name(z)
	if (z == practice_room_z)
		return "practice rooms"
	var/depth = underground_depth_of(z)
	if (depth)
		var/where = z > building_base_maxz() ? "added" : "compiled"
		return depth == 1 ? "cave ([where])" : "underground [depth] ([where])"
	if (z <= building_base_maxz())
		return "ground"
	return "open air"

/proc/level_report_counts(z)
	var/formed = 0
	var/open = 0
	for (var/turf/T in block(locate(1, 1, z), locate(world.maxx, world.maxy, z)))
		if (!istype(T, /turf/sky/building))
			formed++
			if (!T.density)
				open++
		CHECK_TICK
	return list(formed, open)

/client/proc/underground_level_report()
	set category = "Debug"
	set name = "Level Report"
	set desc = "Formed cells on every level: the cave's dug rock and what stands on the open-air levels."
	if (!check_rights(R_DEBUG))
		return
	to_chat(src, "Counting [world.maxz] level(s) of [world.maxx] x [world.maxy]...")
	var/list/lines = list("<b>Levels</b> ([world.maxx] x [world.maxy], [building_levels_built()] open-air level(s) built)")
	for (var/z = 1 to world.maxz)
		var/name = level_report_name(z)
		if (name == "ground")
			lines += "z [z]: ground"
			continue
		var/list/counts = level_report_counts(z)
		lines += "z [z]: [name], [counts[1]] formed cell(s), [counts[2]] open"
	to_chat(src, jointext(lines, "<br>"))
