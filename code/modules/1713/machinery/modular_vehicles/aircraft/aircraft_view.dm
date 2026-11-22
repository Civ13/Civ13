// Modular aircraft, phase 2: the shadow an airborne aircraft casts on the
// ground, and what becomes of one saved in flight.
//
// The shadows are not map atoms: they live in nullspace and are drawn through
// turf vis_contents, which the saver does not record, so a save never captures
// them. The crew see the ground through the open-air view every upper level has
// (code/modules/multiz/open_air_view.dm); an older view here put the ground
// turfs themselves in vis_contents, drew a whiter haze over that view and kept
// resending the turfs to every client in sight.

// Shadow offset in pixels: the shadow falls farther from the airframe the
// higher it flies above the ground under it.
#define AIRCRAFT_SHADOW_OFFSET_MIN 4
#define AIRCRAFT_SHADOW_OFFSET_MAX 20

/obj/structure/vehicleparts/axis/aircraft
	// frame -> its shadow; shadow -> the ground turf showing it
	var/tmp/list/shadows
	var/tmp/list/shadow_turfs

/obj/structure/vehicleparts/axis/aircraft/persistence_runtime_var(key)
	return (key in list("shadows", "shadow_turfs")) || ..(key)

// A dark silhouette of one frame, drawn on the ground below it.
/obj/effect/aircraft_shadow
	name = "shadow"
	mouse_opacity = 0
	anchored = TRUE
	appearance_flags = KEEP_TOGETHER | RESET_TRANSFORM
	color = "#000000"
	alpha = 90
	plane = FLOOR_PLANE
	layer = TURF_LAYER + 0.05

// A copy of the frame's look rather than the frame in vis_contents: a frame is a
// saved structure, and a vis_locs entry on it must never point at a shadow.
/obj/effect/aircraft_shadow/proc/copy_frame(obj/structure/vehicleparts/frame/F, offset)
	appearance = F.appearance
	name = initial(name)
	mouse_opacity = initial(mouse_opacity)
	appearance_flags = initial(appearance_flags)
	color = initial(color)
	alpha = initial(alpha)
	plane = initial(plane)
	layer = initial(layer)
	pixel_x = offset
	pixel_y = -offset

/obj/structure/vehicleparts/axis/aircraft/proc/ground_z()
	var/z = flight_z()
	return z ? multiz_level_below(z) : 0

// The tile at the middle of the airframe (the frames' bounding box); the axis
// itself sits in a corner frame.
/obj/structure/vehicleparts/axis/aircraft/proc/footprint_centre()
	var/list/F = frames()
	if (!F.len)
		return get_turf(src)
	var/min_x = world.maxx
	var/min_y = world.maxy
	var/max_x = 1
	var/max_y = 1
	var/z = 0
	for (var/obj/structure/vehicleparts/frame/FR in F)
		min_x = min(min_x, FR.x)
		max_x = max(max_x, FR.x)
		min_y = min(min_y, FR.y)
		max_y = max(max_y, FR.y)
		z = FR.z
	return locate(round((min_x + max_x) / 2), round((min_y + max_y) / 2), z)

/obj/structure/vehicleparts/axis/aircraft/proc/update_shadows()
	var/ground = ground_z()
	if (!airborne() || !ground)
		clear_shadows()
		return
	if (!shadows)
		shadows = list()
		shadow_turfs = list()
	var/offset = clamp(AIRCRAFT_SHADOW_OFFSET_MIN + clearance(), AIRCRAFT_SHADOW_OFFSET_MIN, AIRCRAFT_SHADOW_OFFSET_MAX)
	var/list/current = frames()
	for (var/obj/structure/vehicleparts/frame/gone in shadows)
		if (!(gone in current))
			drop_shadow(gone)
	for (var/obj/structure/vehicleparts/frame/F in current)
		// A frame over an upper floor (cruise above a storey) throws no shadow
		// on the ground: the ground under it is under a roof.
		var/turf/here = get_turf(F)
		if (!istype(here, /turf/sky/building) || (locate(/obj/covers) in here))
			if (shadows[F])
				drop_shadow(F)
			continue
		var/obj/effect/aircraft_shadow/S = shadows[F]
		if (!S)
			S = new
			S.loc = null
			shadows[F] = S
		S.copy_frame(F, offset)
		var/turf/below = locate(F.x, F.y, ground)
		var/turf/old = shadow_turfs[S]
		if (old == below)
			continue
		if (old)
			old.vis_contents -= S
		shadow_turfs[S] = below
		if (below)
			below.vis_contents += S

/obj/structure/vehicleparts/axis/aircraft/proc/drop_shadow(obj/structure/vehicleparts/frame/F)
	var/obj/effect/aircraft_shadow/S = shadows[F]
	shadows -= F
	if (!S)
		return
	var/turf/old = shadow_turfs[S]
	if (old)
		old.vis_contents -= S
	shadow_turfs -= S
	qdel(S)

/obj/structure/vehicleparts/axis/aircraft/proc/clear_shadows()
	if (!shadows)
		return
	for (var/obj/structure/vehicleparts/frame/F in shadows.Copy())
		drop_shadow(F)
	shadows = null
	shadow_turfs = null

/obj/structure/vehicleparts/axis/aircraft/proc/update_flight_visuals()
	update_shadows()

/obj/structure/vehicleparts/axis/aircraft/do_matrix(var/olddir = 0, var/newdir = 0, var/tdir = "none", var/mob/user = null)
	. = ..()
	if (airborne())
		update_flight_visuals()

// An aircraft saved in flight comes back over open air with nobody at the
// controls. Once the world has loaded, it is set down on the ground below:
// gently where that is clear, as a hard landing (broken wheels) where it is not.
/obj/structure/vehicleparts/axis/aircraft/after_load()
	..()
	if (aloft_over_open_air())
		addtimer(CALLBACK(src, PROC_REF(set_down_after_restore)), 1)

/obj/structure/vehicleparts/axis/aircraft/proc/aloft_over_open_air()
	for (var/obj/structure/vehicleparts/frame/F in frames())
		var/turf/T = get_turf(F)
		if (istype(T, /turf/sky/building) && !(locate(/obj/covers) in T))
			return TRUE
	return FALSE

/obj/structure/vehicleparts/axis/aircraft/proc/set_down_after_restore()
	if (QDELETED(src) || !aloft_over_open_air())
		return FALSE
	var/down = ground_z()
	if (!down)
		return FALSE
	// Straight down where that is clear; else the nearest clear ground, as a
	// hard landing; with nothing clear nearby it comes down where it is.
	var/list/offset = clear_footprint_offset(down)
	var/hard = !offset || offset[1] || offset[2]
	if (!offset)
		offset = list(0, 0)
	moving = FALSE
	currentspeed = 0
	if (engine)
		engine.on = FALSE
		engine.update_icon()
	if (!aircraft_shift(down, offset[1], offset[2]))
		return FALSE
	set_flight_state(AIRCRAFT_GROUND)
	if (hard)
		for (var/obj/structure/vehicleparts/movement/W in wheels)
			W.broken = TRUE
			W.update_icon()
	visible_message(SPAN_NOTICE("\The [src] has been set down [hard ? "hard " : ""]on the ground below."))
	return TRUE

#undef AIRCRAFT_SHADOW_OFFSET_MAX
#undef AIRCRAFT_SHADOW_OFFSET_MIN
