// Modular aircraft, phase 2: what an airborne aircraft shows of the ground, the
// shadow it casts on the ground, and what becomes of one saved in flight.
//
// None of these visuals are map atoms. The shadows and the ground view live in
// nullspace and are drawn through turf vis_contents, which the saver does not
// record, so a save never captures them.

// How many tiles of ground around the airframe's centre the open air shows in
// full, and how far beyond that a fainter ring reaches. The client view is 15
// tiles wide and the pilot sits inside the footprint, so the ring covers the
// whole screen with a soft edge instead of a black cut-off.
#define AIRCRAFT_GROUND_VIEW_RANGE 7
#define AIRCRAFT_GROUND_VIEW_FAR 10
// The haze matrices: the far ring keeps the same tint at less than half the
// opacity. (alpha is folded into a colour matrix, so the ring has its own.)
#define AIRCRAFT_GROUND_VIEW_HAZE list(0.8,0,0,0, 0,0.8,0,0, 0,0,0.8,0, 0,0,0,1, 0.08,0.1,0.14,0)
#define AIRCRAFT_GROUND_VIEW_HAZE_FAR list(0.8,0,0,0, 0,0.8,0,0, 0,0,0.8,0, 0,0,0,0.43, 0.08,0.1,0.14,0)
// Shadow offset in pixels: lower flight casts a closer shadow.
#define AIRCRAFT_SHADOW_OFFSET_LOW 8
#define AIRCRAFT_SHADOW_OFFSET_CRUISE 16

/obj/structure/vehicleparts/axis/aircraft
	var/tmp/obj/effect/aircraft_ground_view/ground_view
	// The fainter outer ring, sharing ground_view_anchor.
	var/tmp/obj/effect/aircraft_ground_view/ground_view_far
	var/tmp/turf/ground_view_anchor
	// frame -> its shadow; shadow -> the ground turf showing it
	var/tmp/list/shadows
	var/tmp/list/shadow_turfs

/obj/structure/vehicleparts/axis/aircraft/persistence_runtime_var(key)
	return (key in list("ground_view", "ground_view_far", "ground_view_anchor", "shadows", "shadow_turfs")) || ..(key)

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
	color = AIRCRAFT_GROUND_VIEW_HAZE

// The faint outer ring of the ground view.
/obj/effect/aircraft_ground_view/far
	color = AIRCRAFT_GROUND_VIEW_HAZE_FAR

/obj/structure/vehicleparts/axis/aircraft/proc/ground_z()
	var/z = flight_z()
	return z ? multiz_level_below(z) : 0

// The tile at the middle of the airframe (the frames' bounding box), which the
// ground view is centred on; the axis itself sits in a corner frame.
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

// Ground turfs under open air around centre: those within the full range,
// those in the fainter ring beyond it, and the bottom-left corner of the
// whole block, where vis_contents lays the grid out from.
/obj/structure/vehicleparts/axis/aircraft/proc/visible_ground(turf/centre, ground)
	var/list/near = list()
	var/list/far = list()
	var/min_x = world.maxx + 1
	var/min_y = world.maxy + 1
	for (var/turf/air in block(locate(max(1, centre.x - AIRCRAFT_GROUND_VIEW_FAR), max(1, centre.y - AIRCRAFT_GROUND_VIEW_FAR), centre.z), locate(min(world.maxx, centre.x + AIRCRAFT_GROUND_VIEW_FAR), min(world.maxy, centre.y + AIRCRAFT_GROUND_VIEW_FAR), centre.z)))
		if (!istype(air, /turf/sky/building) || (locate(/obj/covers) in air))
			continue
		var/turf/below = locate(air.x, air.y, ground)
		if (!below)
			continue
		if (max(abs(air.x - centre.x), abs(air.y - centre.y)) <= AIRCRAFT_GROUND_VIEW_RANGE)
			near += below
		else
			far += below
		min_x = min(min_x, below.x)
		min_y = min(min_y, below.y)
	if (!near.len && !far.len)
		return null
	return list(near, far, locate(min_x, min_y, centre.z))

/obj/structure/vehicleparts/axis/aircraft/proc/update_ground_view()
	var/turf/centre = footprint_centre()
	var/ground = ground_z()
	var/list/seen = (airborne() && centre && ground) ? visible_ground(centre, ground) : null
	if (!seen)
		clear_ground_view()
		return
	if (!ground_view)
		ground_view = new
		ground_view.loc = null
	if (!ground_view_far)
		ground_view_far = new /obj/effect/aircraft_ground_view/far
		ground_view_far.loc = null
	var/turf/anchor = seen[3]
	if (ground_view_anchor != anchor)
		if (ground_view_anchor)
			ground_view_anchor.vis_contents -= ground_view
			ground_view_anchor.vis_contents -= ground_view_far
		ground_view_anchor = anchor
		anchor.vis_contents += ground_view_far
		anchor.vis_contents += ground_view
	ground_view.vis_contents = seen[1]
	ground_view_far.vis_contents = seen[2]

// Whether the ground turf T is shown through the open air, in full or faint.
/obj/structure/vehicleparts/axis/aircraft/proc/ground_shown(turf/T)
	return (ground_view && (T in ground_view.vis_contents)) || (ground_view_far && (T in ground_view_far.vis_contents))

/obj/structure/vehicleparts/axis/aircraft/proc/clear_ground_view()
	if (ground_view_anchor)
		ground_view_anchor.vis_contents -= ground_view
		ground_view_anchor.vis_contents -= ground_view_far
	ground_view_anchor = null
	if (ground_view)
		ground_view.vis_contents = list()
		qdel(ground_view)
	if (ground_view_far)
		ground_view_far.vis_contents = list()
		qdel(ground_view_far)
	ground_view = null
	ground_view_far = null

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

#undef AIRCRAFT_SHADOW_OFFSET_CRUISE
#undef AIRCRAFT_SHADOW_OFFSET_LOW
#undef AIRCRAFT_GROUND_VIEW_HAZE_FAR
#undef AIRCRAFT_GROUND_VIEW_HAZE
#undef AIRCRAFT_GROUND_VIEW_FAR
#undef AIRCRAFT_GROUND_VIEW_RANGE
