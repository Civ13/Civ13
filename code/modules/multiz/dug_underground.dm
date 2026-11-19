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

// The cave is the one full level a dig-down map may add; restoring a saved
// world recreates it through the same admission before the save fills it in.
// On a map without building levels it is the only added level at all. A map
// that also opts into building levels (building_admission.dm) may have open-air
// levels already standing, so its cave is simply the next level, charged
// against the building profile along with them.
/datum/world_z_budget/underground_admitted(target_z)
	if (!dug_underground_supported())
		return FALSE
	var/pending = (instance_reserve - instance_used) + (safehouse_reserve - safehouse_used)
	var/cells = world.maxx * world.maxy
	// Added first at boot, the unformed cave fits beside any measured surface.
	var/first = target_z == building_base_maxz() + 1 && !pending && dug_underground_fits()
	if (!map.building_levels)
		return target_z == building_base_maxz() + 1 && (first || cells * (target_z + pending) <= NEW_Z_MEASURED_CELLS)
	if (target_z != world.maxz + 1 || target_z > building_base_maxz() + 1 + min(map.building_levels, initial(roof_limit)) || !dug_underground_fits())
		return FALSE
	return first || cells * (target_z + pending) <= NEW_Z_BUILDING_MEASURED_CELLS

// The unformed cave: about 14 bytes a cell until dug, so a map's cave plane
// is left out of the total-cell ceiling. A restore cannot see the cave until
// its cells load, so a restored added level counts it on a map that has one.
/datum/world_z_budget/free_planes(target_z, purpose)
	if (target_z <= building_base_maxz() || !dug_underground_supported() || !dug_underground_fits())
		return 0
	return dug_underground_z() || (purpose in list("underground", "restore")) ? 1 : 0

/datum/world_z_budget/ground_planes()
	return base_z + (dug_underground_z() ? 1 : 0)

// How many open-air building levels stand above the compiled map: every added
// level but the dug cave and an open practice level.
/proc/building_levels_built()
	var/built = world.maxz - building_base_maxz()
	if (dug_underground_z())
		built--
	if (practice_room_z && practice_room_z > building_base_maxz())
		built--
	return max(built, 0)

// The physical z of the dug cave level, or 0. Scans the few added levels,
// then remembers the answer (dug_underground_live_z, turf_changing.dm) while
// its bedrock marker stands.

/proc/dug_underground_z()
	if (!dug_underground_supported())
		return 0
	if (dug_underground_live_z && dug_underground_live_z <= world.maxz && dug_underground_live_z != building_allocating_z && istype(locate(1, 1, dug_underground_live_z), /turf/wall/rockwall/bedrock))
		return dug_underground_live_z
	dug_underground_live_z = 0
	for (var/z = building_base_maxz() + 1, z <= world.maxz, z++)
		if (z != building_allocating_z && istype(locate(1, 1, z), /turf/wall/rockwall/bedrock))
			dug_underground_live_z = z
			return z
	return 0

// Where a ladder, tunnel or falling item goes from z. 0 means solid ground.
/proc/multiz_level_below(z)
	if (practice_room_z && z == practice_room_z)
		return 0
	// An orbit world's decks are linked planes (space/orbit_world.dm).
	if (orbit_world())
		return orbit_plane_link(z, "down")
	var/dug = dug_underground_z()
	if (dug)
		if (z == dug)
			return 0
		if (z == DUG_SURFACE_Z)
			return dug
		// The cave may lie between two open-air levels: step over it.
		return z - 1 == dug ? z - 2 : z - 1
	return z > 1 ? z - 1 : 0

/proc/multiz_level_above(z)
	if (practice_room_z && (z == practice_room_z || z + 1 == practice_room_z))
		return 0
	if (orbit_world())
		return orbit_plane_link(z, "up")
	var/dug = dug_underground_z()
	if (dug)
		if (z == dug)
			return DUG_SURFACE_Z
		var/up = z + 1 == dug ? z + 2 : z + 1
		return up <= world.maxz ? up : 0
	return z < world.maxz ? z + 1 : 0

// The highest ground level open to the sky (radiation, observer spawn). A dug
// level can be world.maxz while lying under the surface, and an added building
// level is open air over the surface (Gaia keeps one from round start).
/proc/multiz_top_z()
	var/top = practice_room_z && practice_room_z == world.maxz ? world.maxz - 1 : world.maxz
	var/dug = dug_underground_z()
	if (dug && dug == top)
		top--
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
/proc/underground_above_cell(turf/T)
	if (!T)
		return null
	var/surface_z = multiz_level_above(T.z) || DUG_SURFACE_Z
	return underground_above(locate(T.x, T.y, surface_z))

/proc/dug_underground_rock(turf/surface)
	switch (underground_above(surface))
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
/proc/dug_underground_jitter(x, y)
	var/hash = md5("[map ? map.ID : "map"]:cell:[x]:[y]")
	return text2num(copytext(hash, 1, 5), 16) / 65536

/proc/dug_underground_cell(x, y, surface_z = DUG_SURFACE_Z)
	if (x == 1 || y == 1 || x == world.maxx || y == world.maxy)
		return /turf/wall/rockwall/bedrock
	var/turf/surface = locate(x, y, surface_z)
	var/rock = dug_underground_rock(surface)
	// No natural pockets under water or lava.
	if (underground_above(surface))
		return rock
	if (dug_underground_noise("pocket", x, y) > 0.8 && dug_underground_jitter(x, y) < 0.7)
		return /turf/floor/dirt
	if (dug_underground_noise("vein", x, y) > 0.82)
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

// The underground level of this map: a compiled one, or the dug cave.
/proc/underground_level_z()
	if (map && map.underground_compiled_z)
		dug_underground_live_z = map.underground_compiled_z
		return map.underground_compiled_z
	return dug_underground_z()

/proc/dug_underground_unformed(turf/T)
	return T && istype(T, /turf/sky/building) && T.z == underground_level_z()

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
	var/surface_z = multiz_level_above(T.z) || DUG_SURFACE_Z
	var/path = dug_underground_cell(T.x, T.y, surface_z)
	if (solid && path == /turf/floor/dirt)
		path = dug_underground_rock(locate(T.x, T.y, surface_z))
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
	if (!start || dug_underground_forming || persistence_save_in_progress || start.z != underground_level_z())
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
	if (!z || z != underground_level_z())
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

/proc/dug_underground_error()
	if (!dug_underground_supported())
		return "There is only bedrock below."
	if (dug_underground_z())
		return null
	if (persistence_save_in_progress || building_allocating_z || world_z_budget.active)
		return "The ground is settling. Try again shortly."
	return world_z_budget.error(world.maxz + 1, "underground")

// Allocates the cave level as unformed rock. Returns TRUE once it exists.
/proc/dug_underground_create()
	if (dug_underground_z())
		return TRUE
	if (dug_underground_error())
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
	dug_underground_live_z = 0
	var/turf/marker = locate(1, 1, target_z)
	dug_underground_forming = TRUE
	marker.ChangeTurf(/turf/wall/rockwall/bedrock)
	dug_underground_forming = FALSE
	log_game("Underground level created at z [target_z] ([world.maxx]x[world.maxy]), unformed.")
	return dug_underground_z() == target_z

// Restored worlds: the load regenerates unformed cells in the world's default
// area, so the cave area is put back on them, and formed cells get the
// lighting that startup did not build (it ran before the level existed).
/map_storage/proc/restore_dug_underground()
	// Open cells under lakes and rivers pour again (they are not saved).
	tunnel_breaches.Cut()
	underground_breach_scan(underground_level_z())
	var/z = dug_underground_z()
	if (!z)
		return
	var/area/caves = dug_underground_area()
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

// Tunnel digging on dig-down maps. Returns TRUE when it handled the request,
// FALSE to fall back to the older fixed-level tunnel code.
/proc/dug_underground_tunnel(mob/living/human/user)
	if (!istype(user) || !dug_underground_supported())
		return FALSE
	var/turf/floor/here = get_turf(user)
	if (!istype(here))
		return FALSE
	var/dug = dug_underground_z()
	if (here.z == DUG_SURFACE_Z)
		return dug_underground_tunnel_down(user, here)
	if (dug && here.z == dug)
		return dug_underground_tunnel_up(user, here)
	return FALSE

/proc/dug_underground_tunnel_down(mob/living/human/user, turf/floor/here)
	if (locate(/obj/structure/multiz) in here)
		to_chat(user, SPAN_WARNING("There already is something here."))
		return TRUE
	if (!here.is_diggable)
		to_chat(user, SPAN_WARNING("You cannot dig a hole here!"))
		return TRUE
	var/error = dug_underground_error()
	if (error)
		to_chat(user, SPAN_WARNING(error))
		return TRUE
	if (!dug_underground_open_below(user, here, FALSE))
		return TRUE
	user.visible_message(SPAN_DANGER("[user] starts digging a tunnel downwards!"), SPAN_DANGER("You start digging a tunnel downwards."))
	if (!do_after(user, dug_underground_dig_time(user, 200), here))
		return TRUE
	if (get_turf(user) != here || !here.is_diggable || (locate(/obj/structure/multiz) in here))
		return TRUE // another digger finished this entrance during the wait
	if (!dug_underground_z())
		user.visible_message(SPAN_DANGER("The ground groans as [user] breaks into the deep rock below!"), SPAN_DANGER("You break into the deep rock below. The ground groans and settles..."))
	if (!dug_underground_create())
		if (world_z_budget.last_error)
			log_debug("Dug underground refused: [world_z_budget.last_error]")
		to_chat(user, SPAN_WARNING("The ground below will not give way."))
		return TRUE
	var/turf/below = dug_underground_open_below(user, here, TRUE)
	if (!below)
		return TRUE
	new /obj/structure/multiz/ladder/ww2/tunneltop/pit(here)
	user.visible_message(SPAN_DANGER("[user] finishes digging the tunnel entrance."), SPAN_DANGER("You break through into the rock below."))
	excavation_shaft_spoil(user)
	dug_underground_finish(user)
	return TRUE

// Checks (and with open = TRUE, clears) the cell under a surface tile.
/proc/dug_underground_open_below(mob/living/human/user, turf/here, open)
	var/dug = dug_underground_z()
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
	var/turf/above = locate(here.x, here.y, DUG_SURFACE_Z)
	if (dug_underground_surface_blocked(above))
		switch (underground_above(above))
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
	if (get_turf(user) != here || (locate(/obj/structure/multiz) in here) || dug_underground_surface_blocked(above))
		return TRUE
	new /obj/structure/multiz/ladder/ww2/tunneltop/pit(above)
	user.visible_message(SPAN_DANGER("[user] finishes digging up!"), SPAN_NOTICE("You finish digging up."))
	excavation_shaft_spoil(user)
	dug_underground_finish(user)
	return TRUE

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
	if (z == underground_level_z())
		return dug_underground_z() == z ? "cave (added)" : "cave (compiled)"
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
