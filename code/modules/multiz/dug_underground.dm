// Dug underground: single-level maps that opt in (dig_down_underground) get a
// cave level the first time someone digs a tunnel down from the surface.
// BYOND only appends levels, so the cave is physically world.maxz + 1 while
// it is logically below the surface (z 1). Ladders, digging and roofs ask the
// helpers below for "up" and "down" instead of using z + 1 / z - 1.
// A bedrock rim marks the level, so a restored world recognises it from its
// saved turfs alone; zone persistence restores its cave area.
#define DUG_SURFACE_Z 1
#define DUG_CAVE_NOISE_CELL 8

/obj/map_metadata/var/dig_down_underground = FALSE

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

// The cave is the only level a dig-down map may add; restoring a saved world
// recreates it through the same admission before the save fills it in.
/datum/world_z_budget/underground_admitted(target_z)
	if (!dug_underground_supported() || target_z != building_base_maxz() + 1)
		return FALSE
	var/pending = (instance_reserve - instance_used) + (safehouse_reserve - safehouse_used)
	return world.maxx * world.maxy * (target_z + pending) <= NEW_Z_MEASURED_CELLS

// The physical z of the dug cave level, or 0. Scans the few added levels.
/proc/dug_underground_z()
	if (!dug_underground_supported())
		return 0
	for (var/z = building_base_maxz() + 1, z <= world.maxz, z++)
		if (z != building_allocating_z && istype(locate(1, 1, z), /turf/wall/rockwall/bedrock))
			return z
	return 0

// Where a ladder, tunnel or falling item goes from z. 0 means solid ground.
/proc/multiz_level_below(z)
	// An orbit world's decks are linked planes (space/orbit_world.dm).
	if (orbit_world())
		return orbit_plane_link(z, "down")
	var/dug = dug_underground_z()
	if (dug)
		if (z == dug)
			return 0
		if (z == DUG_SURFACE_Z)
			return dug
		return z - 1 == dug ? DUG_SURFACE_Z : z - 1
	return z > 1 ? z - 1 : 0

/proc/multiz_level_above(z)
	if (orbit_world())
		return orbit_plane_link(z, "up")
	var/dug = dug_underground_z()
	if (dug)
		if (z == dug)
			return DUG_SURFACE_Z
		var/up = z + 1 == dug ? z + 2 : z + 1
		return up <= world.maxz ? up : 0
	return z < world.maxz ? z + 1 : 0

// The highest level open to the sky (radiation, observer spawn). A dug level
// can be world.maxz while lying under the surface.
/proc/multiz_top_z()
	var/dug = dug_underground_z()
	return dug && dug == world.maxz ? world.maxz - 1 : world.maxz

/proc/dug_underground_area()
	for (var/area/caribbean/void/caves/A in world)
		if (A.type == /area/caribbean/void/caves)
			return A
	return new /area/caribbean/void/caves

// The rock that lies under one surface tile.
/proc/dug_underground_rock(turf/surface)
	if (istype(surface, /turf/floor/beach/water/deep))
		return /turf/wall/rockwall
	if (istype(surface, /turf/floor/winter) || istype(surface, /turf/floor/dirt/winter) || istype(surface, /turf/floor/beach/water/ice))
		return /turf/floor/dirt/underground/icy
	if (istype(surface, /turf/floor/beach/sand) || istype(surface, /turf/floor/dirt/dust))
		return /turf/floor/dirt/underground/sandy
	return /turf/floor/dirt/underground

// Coarse random lattice, smoothed: open pockets and hard veins form blobs.
/proc/dug_underground_noise_grid()
	var/list/grid = list()
	var/w = round(world.maxx / DUG_CAVE_NOISE_CELL) + 2
	var/h = round(world.maxy / DUG_CAVE_NOISE_CELL) + 2
	for (var/i = 1 to w * h)
		grid += rand()
	return grid

/proc/dug_underground_noise(list/grid, x, y)
	var/w = round(world.maxx / DUG_CAVE_NOISE_CELL) + 2
	var/fx = (x - 1) / DUG_CAVE_NOISE_CELL
	var/fy = (y - 1) / DUG_CAVE_NOISE_CELL
	var/gx = round(fx)
	var/gy = round(fy)
	var/tx = fx - gx
	var/ty = fy - gy
	var/a = grid[gy * w + gx + 1]
	var/b = grid[gy * w + gx + 2]
	var/c = grid[(gy + 1) * w + gx + 1]
	var/d = grid[(gy + 1) * w + gx + 2]
	var/top = a + (b - a) * tx
	var/bottom = c + (d - c) * tx
	return top + (bottom - top) * ty

/proc/dug_underground_cell(x, y, list/pockets, list/veins)
	if (x == 1 || y == 1 || x == world.maxx || y == world.maxy)
		return /turf/wall/rockwall/bedrock
	var/turf/surface = locate(x, y, DUG_SURFACE_Z)
	var/rock = dug_underground_rock(surface)
	if (rock == /turf/wall/rockwall)
		return rock
	if (dug_underground_noise(pockets, x, y) > 0.8 && prob(70))
		return /turf/floor/dirt
	if (dug_underground_noise(veins, x, y) > 0.82)
		return /turf/wall/rockwall
	return rock

// Native lighting covers the startup levels only; give the cave its corners
// and overlays so torches light it and it starts dark.
/proc/dug_underground_light_level(z)
	if (!created_lighting_corners_and_overlays || (map && (z in map.zlevels_without_lighting)))
		return
	create_lighting_corners_zlevel(z)
	for (var/turf/T in block(locate(1, 1, z), locate(world.maxx, world.maxy, z)))
		if (T.lighting_overlay)
			for (var/i = 1 to 4)
				var/datum/lighting_corner/C = T.get_corner(i)
				if (C && !C.active)
					C.update_active(TRUE)
		else
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

// Allocates and generates the cave level. Returns TRUE once it exists.
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
	var/list/pockets = dug_underground_noise_grid()
	var/list/veins = dug_underground_noise_grid()
	building_allocating_z = target_z
	try
		// Native growth fills the plane with world.turf in one step that cannot
		// yield. Area membership is one bulk add (per-turf adds cost ~250x more);
		// the rock replacement after it is spread across ticks.
		world.maxz = target_z
		caves.contents.Add(block(locate(1, 1, target_z), locate(world.maxx, world.maxy, target_z)))
		for (var/x = 1 to world.maxx)
			for (var/y = 1 to world.maxy)
				var/path = dug_underground_cell(x, y, pockets, veins)
				new path(locate(x, y, target_z))
			TICK_CHECK
	catch (var/exception/allocation_error)
		world_z_budget.finish(reservation, FALSE)
		// Keep the busy flag: a partly initialized native grid requires restart.
		throw allocation_error
	building_allocating_z = 0
	if (!world_z_budget.finish(reservation, world.maxz == target_z))
		return FALSE
	log_game("Dug underground level created at z [target_z] ([world.maxx]x[world.maxy]).")
	dug_underground_light_level(target_z)
	return dug_underground_z() == target_z

// Restored worlds: build lighting for a cave level that lighting startup
// did not cover (it ran before the level was allocated).
/map_storage/restore_dug_levels()
	var/z = dug_underground_z()
	if (!z)
		return
	var/turf/T = locate(2, 2, z)
	if (T && !T.lighting_overlay && !T.get_corner(1))
		dug_underground_light_level(z)

/proc/dug_underground_dig_time(mob/living/human/user, base)
	return base / (user.getStatCoeff("strength") * user.getStatCoeff("crafting") * user.getStatCoeff("crafting"))

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
		to_chat(user, SPAN_WARNING(world_z_budget.last_error ? world_z_budget.last_error : "The ground below will not give way."))
		return TRUE
	var/turf/below = dug_underground_open_below(user, here, TRUE)
	if (!below)
		return TRUE
	new /obj/structure/multiz/ladder/ww2/tunneltop(here)
	new /obj/structure/multiz/ladder/ww2/tunnelbottom(below)
	user.visible_message(SPAN_DANGER("[user] finishes digging the tunnel entrance."), SPAN_DANGER("You break through into the rock below."))
	dug_underground_finish(user)
	return TRUE

// Checks (and with open = TRUE, clears) the cell under a surface tile.
/proc/dug_underground_open_below(mob/living/human/user, turf/here, open)
	var/dug = dug_underground_z()
	if (!dug)
		return !open // the level is generated when the digging finishes
	var/turf/below = locate(here.x, here.y, dug)
	if (!below || istype(below, /turf/wall) || (locate(/obj/structure/multiz) in below))
		to_chat(user, SPAN_WARNING("You hit solid stone. You cannot dig down here."))
		return null
	if (!open)
		return below
	if (istype(below, /turf/floor/dirt/underground))
		below.ChangeTurf(/turf/floor/dirt)
	return locate(here.x, here.y, dug)

/proc/dug_underground_tunnel_up(mob/living/human/user, turf/floor/here)
	if (locate(/obj/structure/multiz) in here)
		to_chat(user, SPAN_WARNING("There already is something here."))
		return TRUE
	var/turf/above = locate(here.x, here.y, DUG_SURFACE_Z)
	if (dug_underground_surface_blocked(above))
		to_chat(user, SPAN_NOTICE("You can't dig up here, there is something blocking the way!"))
		return TRUE
	user.visible_message(SPAN_DANGER("[user] starts digging up!"), SPAN_NOTICE("You start digging up."))
	if (!do_after(user, dug_underground_dig_time(user, 400), here))
		return TRUE
	if (get_turf(user) != here || (locate(/obj/structure/multiz) in here) || dug_underground_surface_blocked(above))
		return TRUE
	new /obj/structure/multiz/ladder/ww2/tunneltop(above)
	new /obj/structure/multiz/ladder/ww2/tunnelbottom(here)
	user.visible_message(SPAN_DANGER("[user] finishes digging up!"), SPAN_NOTICE("You finish digging up."))
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
