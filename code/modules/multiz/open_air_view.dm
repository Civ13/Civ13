// Seeing down through open air. A player on an upper level who looks out over
// open air sees the level below: the ground, what stands on it and who moves
// there, darker than their own level, and darker again for each level further
// down.
//
// An open-air cell near a viewer holds a view object in its vis_contents; the
// view object holds the turf below in its own vis_contents, so the client
// draws that turf and everything on it live, with no copying on the server. If
// the turf below is open air too, it holds its own view of the level under it,
// and the shading multiplies: each level down is darker than the one above.
//
// Cost: only open-air cells that a viewer has had in sight get a view object,
// once; nothing is redrawn on the server when things move below. The views are
// never saved (turf vis_contents are not recorded, the fields are tmp).
//
// Clicks: everything shown through open air counts as the open-air cell itself
// (VIS_INHERIT_ID), so grabbing open air to climb down, building on it and
// placing ladders work as before, and nothing below can be clicked from above.
// Lighting: the lighting of the cell below is hidden and the open-air cell's
// own lighting applies, so the view goes dark at night with the viewer's level.

// How dark each level down is drawn: about 60% brightness per level with a faint
// blue haze, so the second level down is about 37% and the third about 23%.
#define OPEN_AIR_VIEW_SHADE list(0.6,0,0, 0,0.6,0, 0,0,0.64, 0.015,0.025,0.05)
// Levels of open air under open air that are linked at most.
#define OPEN_AIR_VIEW_DEPTH 6
// Tiles beyond the edge of a viewer's screen that are linked ahead of time, so
// walking does not show the sky at the edge before the next scan.
#define OPEN_AIR_VIEW_MARGIN 2
// A viewer standing still is rescanned this often, for floors built or taken
// away over open air.
#define OPEN_AIR_VIEW_RESCAN 5 SECONDS

// What is drawn through vis_contents takes the plane of what shows it and
// counts as it for the mouse. Only matters for atoms shown in vis_contents.
/atom/movable
	vis_flags = VIS_INHERIT_PLANE | VIS_INHERIT_ID

/turf
	vis_flags = VIS_INHERIT_PLANE | VIS_INHERIT_ID

// Lighting cells stay on their own planes and are never shown second-hand.
/atom/movable/lighting_overlay
	vis_flags = VIS_HIDE

/atom/movable/lighting_fullbright
	vis_flags = VIS_HIDE

/obj/effect/open_air_view
	name = "the level below"
	mouse_opacity = 0
	anchored = TRUE
	simulated = FALSE
	appearance_flags = KEEP_TOGETHER
	plane = FLOOR_PLANE
	layer = TURF_LAYER + 0.01
	color = OPEN_AIR_VIEW_SHADE

/turf/sky/building/var/tmp/obj/effect/open_air_view/open_air_view = null

// Shows the level below through this cell, or stops if a floor now covers it.
// The turf below is shown whole; open air there shows the level under it.
/turf/sky/building/proc/open_air_view_refresh(depth = 1, wake = TRUE)
	var/below_z = multiz_level_below(z)
	var/turf/below = below_z ? locate(x, y, below_z) : null
	if (!below || depth > OPEN_AIR_VIEW_DEPTH || istype(src, /turf/sky/building/unformed) || (locate(/obj/covers) in src))
		open_air_view_clear()
		return
	if (!open_air_view)
		// The client only draws a cell that is lit or within see_in_dark, and an
		// asleep cell of an added level has no lighting of its own yet.
		if (wake)
			building_wake()
		var/obj/effect/open_air_view/V = new
		V.loc = null
		// Southern cells draw over northern ones, so a tall sprite below (a
		// tree) overhangs the open air north of it instead of being cut off.
		V.layer = TURF_LAYER + 0.01 + 0.009 * (world.maxy - y) / max(1, world.maxy)
		V.vis_contents += below
		open_air_view = V
		vis_contents += V
	var/turf/sky/building/next = below
	if (istype(next))
		next.open_air_view_refresh(depth + 1, FALSE)

/turf/sky/building/proc/open_air_view_clear()
	if (!open_air_view)
		return
	vis_contents -= open_air_view
	open_air_view.vis_contents.Cut()
	qdel(open_air_view)
	open_air_view = null

/turf/sky/building/ChangeTurf(var/path, var/tell_universe = 1, var/force_lighting_update = FALSE, datum/durable_nomads_event/nomads_event = null)
	open_air_view_clear()
	return ..()

/client/var/tmp/turf/open_air_view_centre = null
/client/var/tmp/open_air_view_scanned_at = 0

// Links the open-air cells on and just beyond the client's screen. The eye may
// be panned (Look into Distance), so the screen centre counts the pan.
/client/proc/open_air_view_scan()
	var/turf/centre = get_turf(eye)
	if (!centre || !multiz_level_below(centre.z))
		open_air_view_centre = null
		return
	var/pan_x = ceil(abs(pixel_x) / world.icon_size)
	var/pan_y = ceil(abs(pixel_y) / world.icon_size)
	if (centre == open_air_view_centre && !pan_x && !pan_y && world.time < open_air_view_scanned_at + OPEN_AIR_VIEW_RESCAN)
		return
	open_air_view_centre = centre
	open_air_view_scanned_at = world.time
	var/list/size = getviewsize(view)
	var/rx = round(size[1] / 2) + OPEN_AIR_VIEW_MARGIN + pan_x
	var/ry = round(size[2] / 2) + OPEN_AIR_VIEW_MARGIN + pan_y
	var/cx = centre.x + round(pixel_x / world.icon_size)
	var/cy = centre.y + round(pixel_y / world.icon_size)
	open_air_view_link_around(centre.z, cx, cy, rx, ry)

// Links every open-air cell in the box around (cx, cy) on level z.
/proc/open_air_view_link_around(z, cx, cy, rx, ry)
	var/turf/low = locate(max(1, cx - rx), max(1, cy - ry), z)
	var/turf/high = locate(min(world.maxx, cx + rx), min(world.maxy, cy + ry), z)
	if (!low || !high)
		return
	for (var/turf/sky/building/T in block(low, high))
		T.open_air_view_refresh()

/proc/open_air_view_busy()
	return persistence_active_operation || persistence_save_in_progress || building_allocating_z

#undef OPEN_AIR_VIEW_MARGIN
#undef OPEN_AIR_VIEW_RESCAN
