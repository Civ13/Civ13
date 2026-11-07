// Modular aircraft, phase 2: what an airborne aircraft shows of the ground, the
// shadow it casts on the ground, and what becomes of one saved in flight.
//
// None of these visuals are map atoms. The shadows and the ground view live in
// nullspace and are drawn through turf vis_contents, which the saver does not
// record, so a save never captures them.

// How many tiles of ground around the aircraft the open air shows.
#define AIRCRAFT_GROUND_VIEW_RANGE 8
// Shadow offset in pixels: lower flight casts a closer shadow.
#define AIRCRAFT_SHADOW_OFFSET_LOW 8
#define AIRCRAFT_SHADOW_OFFSET_CRUISE 16

/obj/structure/vehicleparts/axis/aircraft
	var/tmp/obj/effect/aircraft_ground_view/ground_view
	var/tmp/turf/ground_view_anchor
	// frame -> its shadow; shadow -> the ground turf showing it
	var/tmp/list/shadows
	var/tmp/list/shadow_turfs

/obj/structure/vehicleparts/axis/aircraft/persistence_runtime_var(key)
	return (key in list("ground_view", "ground_view_anchor", "shadows", "shadow_turfs")) || ..(key)

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

// The ground below, shown through the open air around an airborne aircraft.
/obj/effect/aircraft_ground_view
	name = "the ground below"
	mouse_opacity = 0
	anchored = TRUE
	appearance_flags = KEEP_TOGETHER
	plane = FLOOR_PLANE
	layer = TURF_LAYER + 0.01
	// Distance haze.
	color = list(0.8,0,0, 0,0.8,0, 0,0,0.8, 0.08,0.1,0.14)

/obj/structure/vehicleparts/axis/aircraft/proc/ground_z()
	var/z = flight_z()
	return z ? multiz_level_below(z) : 0

// Ground turfs under open air within range, and the bottom-left corner of
// their bounding box, where vis_contents lays the grid out from.
/obj/structure/vehicleparts/axis/aircraft/proc/visible_ground(turf/centre, ground)
	var/list/turfs = list()
	var/min_x = world.maxx + 1
	var/min_y = world.maxy + 1
	for (var/turf/air in block(locate(max(1, centre.x - AIRCRAFT_GROUND_VIEW_RANGE), max(1, centre.y - AIRCRAFT_GROUND_VIEW_RANGE), centre.z), locate(min(world.maxx, centre.x + AIRCRAFT_GROUND_VIEW_RANGE), min(world.maxy, centre.y + AIRCRAFT_GROUND_VIEW_RANGE), centre.z)))
		if (!istype(air, /turf/sky/building) || (locate(/obj/covers) in air))
			continue
		var/turf/below = locate(air.x, air.y, ground)
		if (!below)
			continue
		turfs += below
		min_x = min(min_x, below.x)
		min_y = min(min_y, below.y)
	if (!turfs.len)
		return null
	return list(turfs, locate(min_x, min_y, centre.z))

/obj/structure/vehicleparts/axis/aircraft/proc/update_ground_view()
	var/turf/centre = get_turf(src)
	var/ground = ground_z()
	var/list/seen = (airborne() && centre && ground) ? visible_ground(centre, ground) : null
	if (!seen)
		clear_ground_view()
		return
	if (!ground_view)
		ground_view = new
		ground_view.loc = null
	var/turf/anchor = seen[2]
	if (ground_view_anchor != anchor)
		if (ground_view_anchor)
			ground_view_anchor.vis_contents -= ground_view
		ground_view_anchor = anchor
		anchor.vis_contents += ground_view
	ground_view.vis_contents = seen[1]

/obj/structure/vehicleparts/axis/aircraft/proc/clear_ground_view()
	if (ground_view_anchor)
		ground_view_anchor.vis_contents -= ground_view
	ground_view_anchor = null
	if (ground_view)
		ground_view.vis_contents = list()
		qdel(ground_view)
	ground_view = null

/obj/structure/vehicleparts/axis/aircraft/proc/update_shadows()
	var/ground = ground_z()
	if (!airborne() || !ground)
		clear_shadows()
		return
	if (!shadows)
		shadows = list()
		shadow_turfs = list()
	var/offset = flight_state == AIRCRAFT_CRUISE ? AIRCRAFT_SHADOW_OFFSET_CRUISE : AIRCRAFT_SHADOW_OFFSET_LOW
	var/list/current = frames()
	for (var/obj/structure/vehicleparts/frame/gone in shadows)
		if (!(gone in current))
			drop_shadow(gone)
	for (var/obj/structure/vehicleparts/frame/F in current)
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
	update_ground_view()

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
	var/hard = clear_at_level(down)
	moving = FALSE
	currentspeed = 0
	if (engine)
		engine.on = FALSE
		engine.update_icon()
	if (!aircraft_shift(down))
		return FALSE
	set_flight_state(AIRCRAFT_GROUND)
	if (hard)
		for (var/obj/structure/vehicleparts/movement/W in wheels)
			W.broken = TRUE
			W.update_icon()
	visible_message(SPAN_NOTICE("\The [src] has been set down [hard ? "hard " : ""]on the ground below."))
	return TRUE

#undef AIRCRAFT_SHADOW_OFFSET_CRUISE
#undef AIRCRAFT_SHADOW_OFFSET_LOW
#undef AIRCRAFT_GROUND_VIEW_RANGE
