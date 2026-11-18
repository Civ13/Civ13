// Seeing down through open air. A player on an upper level who looks out over
// open air sees the level below: the ground, what stands on it and who moves
// there, darker than their own level, and darker again for each level further
// down.
//
// An open-air cell near a viewer holds a view object in its vis_contents. The
// view object never holds the turf below itself: a turf shown through
// vis_contents is sent to the client again and again (a real client measured
// about 2.7 Mbps one level up, 4.8 two levels up, against 0.1 on the ground).
// Instead the view holds a copy of the turf's look (the ground object) and the
// movables standing on that turf, which cost what they cost on the ground. If
// the turf below is open air too, the view holds that cell's own view, and the
// shading multiplies: each level down is darker than the one above.
//
// Keeping the copy current: whatever moves with Move() or forceMove() is
// added to or taken from the views of the turfs it leaves and enters at once,
// and the scan (code/processes/open_air_view.dm) resyncs the views around each
// viewer every second for the rest (new objects, raw loc changes, a changed
// turf look).
//
// Cost: only open-air cells that a viewer has had in sight get a view object,
// once. The views are never saved (turf vis_contents are not recorded, the
// fields are tmp).
//
// Proxies: what stands below a cell is not held in the cell's view. Each such
// movable gets one proxy on the open-air cell above it, a real map object that
// holds the movable in its own vis_contents and follows it with the movable's
// own glide, so people and animals below walk smoothly instead of jumping a
// tile at a time (a movable drawn inside another object cannot glide). Being
// in the viewer's view(), a proxy is listed on the right-click menu under the
// name of what it shows, and Examine reads the real thing; every click and
// drag on it acts on the open-air cell. A proxy sits under any floor and under
// the cell's own sky sprite, so it is only seen where the cell shows below.
//
// Clicks: everything shown through open air counts as the open-air cell itself
// (VIS_INHERIT_ID), so grabbing open air to climb down, building on it and
// placing ladders work as before, and nothing below can be clicked from above.
// Floors: a solid floor over open air hides the level below, so its cell holds
// no view. A floor whose sprite has gaps (patched planks, a catwalk) keeps the
// view, and the level below shows through the gaps instead of the sky.
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
// A moving viewer is linked further ahead by as many tiles as it moved since
// the last scan, at most this many, so running or a flying ghost does not
// reach the sky at the edge of the screen before the next scan.
#define OPEN_AIR_VIEW_LEAD 10
// Under the ground of the viewer's level (2) and under floors over open air
// (1.99), over anything hidden under a floor. The open-air cell's own sky
// sprite is taken off while it shows the level below.
#define OPEN_AIR_VIEW_LAYER 1.95

// What is drawn through vis_contents takes the plane of what shows it and
// counts as it for the mouse. Only matters for atoms shown in vis_contents.
// A turf shown that way also takes the layer of what shows it, which is under
// every object: a floor built over open air has layer 1.99 on the game plane,
// and on one plane it would otherwise sit under the turf it covers.
/atom/movable
	vis_flags = VIS_INHERIT_PLANE | VIS_INHERIT_ID

/turf
	vis_flags = VIS_INHERIT_PLANE | VIS_INHERIT_ID | VIS_INHERIT_LAYER

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
	layer = OPEN_AIR_VIEW_LAYER
	color = OPEN_AIR_VIEW_SHADE
	// The turf this view shows, and the copy of its look.
	var/tmp/turf/shows = null
	// The open-air cell holding this view; null for views no cell holds (a
	// murder hole's), which keep what stands below in their own vis_contents.
	var/tmp/turf/sky/building/cell = null
	var/tmp/obj/effect/open_air_view_ground/ground = null
	var/tmp/ground_appearance = null

// The look of the turf below, copied (never the turf itself, see above). It
// takes the view's layer like the turf did, under floors built over open air.
/obj/effect/open_air_view_ground
	name = "the ground below"
	anchored = TRUE
	simulated = FALSE

// Views showing this turf, so movables entering or leaving it update them.
/turf/var/tmp/list/open_air_shown_by = null
// Set once any view exists; until then a move costs one global read here.
var/global/open_air_view_any = FALSE

// Starts showing a turf: its look, what stands on it and, for open air, the
// view under it.
/obj/effect/open_air_view/proc/open_air_show(turf/below)
	open_air_unshow()
	open_air_view_any = TRUE
	shows = below
	ground = new
	ground.loc = null
	vis_contents += ground
	open_air_view_sync()

/obj/effect/open_air_view/proc/open_air_unshow()
	if (shows && shows.open_air_shown_by)
		shows.open_air_shown_by -= src
		if (!shows.open_air_shown_by.len)
			shows.open_air_shown_by = null
	shows = null
	vis_contents.Cut()
	if (ground)
		qdel(ground)
		ground = null
	ground_appearance = null

/obj/effect/open_air_view/Destroy()
	open_air_unshow()
	return ..()

/proc/open_air_view_shows_movable(atom/movable/A)
	return !(A.vis_flags & VIS_HIDE) && !istype(A, /obj/effect/open_air_view)

// TRUE when this view leaves what stands below to proxies (see above). A proxy
// itself, seen one level further up, is held in the view like before.
/obj/effect/open_air_view/proc/open_air_view_proxies(atom/movable/A)
	return cell && cell.open_air_view == src && !istype(A, /obj/effect/open_air_proxy)

/obj/effect/open_air_proxy
	name = "something below"
	anchored = TRUE
	simulated = FALSE
	should_save = FALSE
	density = FALSE
	appearance_flags = KEEP_TOGETHER
	plane = FLOOR_PLANE
	layer = OPEN_AIR_VIEW_LAYER + 0.01
	color = OPEN_AIR_VIEW_SHADE
	// Glides only; never turns or flicks with a step.
	animate_movement = SLIDE_STEPS
	var/tmp/atom/movable/shows = null

/atom/movable/var/tmp/obj/effect/open_air_proxy/open_air_proxy = null
var/global/list/open_air_proxies = list()

/obj/effect/open_air_proxy/Destroy()
	if (shows && shows.open_air_proxy == src)
		shows.open_air_proxy = null
	shows = null
	vis_contents.Cut()
	open_air_proxies -= src
	return ..()

// The open-air cell that shows the turf A stands on, or null.
/proc/open_air_proxy_cell(atom/movable/A)
	var/turf/T = A.loc
	if (!isturf(T) || !T.open_air_shown_by || !open_air_view_shows_movable(A) || istype(A, /obj/effect/open_air_proxy))
		return null
	for (var/obj/effect/open_air_view/V in T.open_air_shown_by)
		if (V.shows == T && V.open_air_view_proxies(A))
			return V.cell
	return null

// Puts A's proxy on the open-air cell above it, moved with A's glide, or drops
// the proxy once nothing above shows A.
/proc/open_air_proxy_update(atom/movable/A)
	var/turf/sky/building/cell = open_air_proxy_cell(A)
	var/obj/effect/open_air_proxy/P = A.open_air_proxy
	if (!cell)
		if (P)
			qdel(P)
		return
	if (!P || QDELETED(P))
		P = new
		P.loc = null
		P.shows = A
		P.vis_contents += A
		A.open_air_proxy = P
		open_air_proxies += P
	if (P.name != A.name)
		P.name = A.name
	// Southern things draw over northern ones, and keep their own order.
	var/want_layer = OPEN_AIR_VIEW_LAYER + 0.01 + 0.009 * (world.maxy - cell.y) / max(1, world.maxy) + clamp(A.layer, 0, 20) * 0.00005
	if (P.layer != want_layer)
		P.layer = want_layer
	P.glide_size = A.glide_size
	// A raw loc change: no Enter/Entered, so nothing falls through open air.
	if (P.loc != cell)
		P.loc = cell
	if (P.step_x != A.step_x)
		P.step_x = A.step_x
	if (P.step_y != A.step_y)
		P.step_y = A.step_y

// Clicks and drags act on the open-air cell, as before proxies.
/obj/effect/open_air_proxy/Click(location, control, params)
	var/turf/T = loc
	return T ? T.Click(T, control, params) : null

/obj/effect/open_air_proxy/DblClick(location, control, params)
	var/turf/T = loc
	return T ? T.DblClick(T, control, params) : null

/obj/effect/open_air_proxy/MouseDrop(over_object, src_location, over_location, src_control, over_control, params)
	var/turf/T = loc
	return T ? T.MouseDrop(over_object, T, over_location, src_control, over_control, params) : null

/obj/effect/open_air_proxy/MouseDrop_T(atom/dropping, mob/user)
	var/turf/T = loc
	return T ? T.MouseDrop_T(dropping, user) : null

// Examine reads what is shown (right-click > Examine on it).
/obj/effect/open_air_proxy/examine(mob/user, var/distance = -1, var/infix = "", var/suffix = "")
	if (shows && !QDELETED(shows))
		return shows.examine(user, distance, infix, suffix)
	return ..()

// Drops a proxy whose thing went, or follows a raw loc change. Run by the
// process for every proxy each time it fires.
/obj/effect/open_air_proxy/proc/open_air_proxy_check()
	var/atom/movable/A = shows
	if (!A || QDELETED(A) || A.open_air_proxy != src)
		qdel(src)
	else
		open_air_proxy_update(A)

// Brings the copy in line with the turf below: its look, what stands on it,
// and the view under open air.
/obj/effect/open_air_view/proc/open_air_view_sync()
	var/turf/below = shows
	if (!below || !ground)
		return
	// A replaced turf (ChangeTurf) starts with fresh vars.
	if (!below.open_air_shown_by)
		below.open_air_shown_by = list(src)
	else if (!(src in below.open_air_shown_by))
		below.open_air_shown_by += src
	if (ground_appearance != below.appearance)
		ground_appearance = below.appearance
		var/mutable_appearance/look = new(below)
		look.plane = FLOAT_PLANE
		look.layer = OPEN_AIR_VIEW_LAYER
		look.vis_flags = VIS_INHERIT_PLANE | VIS_INHERIT_ID | VIS_INHERIT_LAYER
		ground.appearance = look
	var/list/want = list(ground)
	// A turf's contents also list movables that only overlap it (a body
	// stepping between tiles): each is shown once, by the view of its loc.
	for (var/atom/movable/A in below)
		if (A.loc == below && open_air_view_shows_movable(A))
			if (open_air_view_proxies(A))
				open_air_proxy_update(A)
			else
				want += A
	var/turf/sky/building/next = below
	if (istype(next) && next.open_air_view)
		want += next.open_air_view
	for (var/thing in vis_contents)
		if (!(thing in want))
			vis_contents -= thing
	for (var/thing in want)
		if (!(thing in vis_contents))
			vis_contents += thing

// Called after a movable moves with Move() or forceMove(): the views of the
// turf it left drop it, the views of the turf it entered show it.
// A step within the same tile (old_loc == loc) only moves its proxy.
/proc/open_air_view_moved(atom/movable/A, atom/old_loc)
	var/turf/from = old_loc
	if (from != A.loc && isturf(from) && from.open_air_shown_by)
		for (var/obj/effect/open_air_view/V in from.open_air_shown_by)
			V.vis_contents -= A
	var/turf/into = A.loc
	if (isturf(into) && into.open_air_shown_by && open_air_view_shows_movable(A))
		for (var/obj/effect/open_air_view/V in into.open_air_shown_by)
			if (!V.open_air_view_proxies(A) && !(A in V.vis_contents))
				V.vis_contents += A
	if (A.open_air_proxy || (isturf(into) && into.open_air_shown_by))
		open_air_proxy_update(A)

/atom/movable/Destroy()
	var/turf/T = loc
	if (isturf(T) && T.open_air_shown_by)
		for (var/obj/effect/open_air_view/V in T.open_air_shown_by)
			V.vis_contents -= src
	if (open_air_proxy)
		qdel(open_air_proxy)
		open_air_proxy = null
	return ..()

/turf/sky/building/var/tmp/obj/effect/open_air_view/open_air_view = null

// TRUE for a floor whose sprite has see-through gaps between its boards or bars.
/obj/covers/var/gaps_show_below = FALSE

/obj/covers/repairedfloor
	gaps_show_below = TRUE

/obj/covers/catwalk
	gaps_show_below = TRUE

// TRUE when a floor here hides the level below entirely.
/turf/sky/building/proc/open_air_view_floored()
	for (var/obj/covers/C in src)
		if (!C.gaps_show_below)
			return TRUE
	return FALSE

// Shows the level below through this cell, or stops if a solid floor now covers it.
// The turf below is shown whole; open air there shows the level under it.
/turf/sky/building/proc/open_air_view_refresh(depth = 1, wake = TRUE)
	var/below_z = multiz_level_below(z)
	var/turf/below = below_z ? locate(x, y, below_z) : null
	if (!below || depth > OPEN_AIR_VIEW_DEPTH || istype(src, /turf/sky/building/unformed) || open_air_view_floored())
		open_air_view_clear()
		return
	// The client only draws a cell that is lit or within see_in_dark, and an
	// asleep cell of an added level has no lighting of its own yet. A cell first
	// linked from the level above (wake FALSE) is woken once a viewer on its own
	// level scans it; until then it showed black there.
	if (wake && !lighting_overlay)
		building_wake()
	if (!open_air_view)
		var/obj/effect/open_air_view/V = new
		V.loc = null
		// Southern cells draw over northern ones, so a tall sprite below (a
		// tree) overhangs the open air north of it instead of being cut off.
		V.layer = OPEN_AIR_VIEW_LAYER + 0.009 * (world.maxy - y) / max(1, world.maxy)
		open_air_view = V
		V.cell = src
		vis_contents += V
		// The sky sprite would hide the view (icon is not a saved turf field).
		icon = null
		V.open_air_show(below)
	else
		// Self-repair: a restored or reset look puts the sky sprite back over the
		// view, and a cleared vis_contents drops it; both showed the sky.
		if (icon)
			icon = null
		if (!(open_air_view in vis_contents))
			vis_contents += open_air_view
		if (open_air_view.shows != below)
			open_air_view.open_air_show(below)
	var/turf/sky/building/next = below
	if (istype(next))
		next.open_air_view_refresh(depth + 1, FALSE)
	open_air_view.open_air_view_sync()

/turf/sky/building/proc/open_air_view_clear()
	if (!open_air_view)
		return
	vis_contents -= open_air_view
	icon = initial(icon)
	// The view above this cell showed this view; it goes at once.
	if (open_air_shown_by)
		for (var/obj/effect/open_air_view/above in open_air_shown_by)
			above.vis_contents -= open_air_view
	qdel(open_air_view)
	open_air_view = null
	// What stood below is no longer seen from here.
	for (var/obj/effect/open_air_proxy/P in src)
		qdel(P)

/turf/sky/building/ChangeTurf(var/path, var/tell_universe = 1, var/force_lighting_update = FALSE, datum/durable_nomads_event/nomads_event = null)
	open_air_view_clear()
	return ..()

/client/var/tmp/turf/open_air_view_centre = null
/client/var/tmp/open_air_view_scanned_at = 0
// Cells showing the level below at the last scan; while any are in sight the
// scan resyncs them every time the process fires.
/client/var/tmp/open_air_view_in_sight = 0

// Links the open-air cells on and just beyond the client's screen. The eye may
// be panned (Look into Distance), so the screen centre counts the pan.
/client/proc/open_air_view_scan()
	var/turf/centre = get_turf(eye)
	if (!centre || !multiz_level_below(centre.z))
		open_air_view_centre = null
		return
	var/pan_x = ceil(abs(pixel_x) / world.icon_size)
	var/pan_y = ceil(abs(pixel_y) / world.icon_size)
	// Standing still on a level with no open air in sight: nothing to link or
	// resync until the viewer moves or the rescan time comes.
	if (centre == open_air_view_centre && !pan_x && !pan_y && !open_air_view_in_sight && world.time < open_air_view_scanned_at + OPEN_AIR_VIEW_RESCAN)
		return
	var/turf/last = open_air_view_centre
	var/lead_x = 0
	var/lead_y = 0
	if (last && last.z == centre.z)
		lead_x = clamp(centre.x - last.x, -OPEN_AIR_VIEW_LEAD, OPEN_AIR_VIEW_LEAD)
		lead_y = clamp(centre.y - last.y, -OPEN_AIR_VIEW_LEAD, OPEN_AIR_VIEW_LEAD)
	open_air_view_centre = centre
	open_air_view_scanned_at = world.time
	var/list/size = getviewsize(view)
	var/rx = round(size[1] / 2) + OPEN_AIR_VIEW_MARGIN + pan_x
	var/ry = round(size[2] / 2) + OPEN_AIR_VIEW_MARGIN + pan_y
	var/cx = centre.x + round(pixel_x / world.icon_size)
	var/cy = centre.y + round(pixel_y / world.icon_size)
	open_air_view_in_sight = open_air_view_link_around(centre.z, cx, cy, rx, ry, lead_x, lead_y)

// Links every open-air cell in the box around (cx, cy) on level z and resyncs
// the views already there; the box reaches lead_x/lead_y tiles further on the
// side the viewer is moving towards. Returns how many cells show the level below.
/proc/open_air_view_link_around(z, cx, cy, rx, ry, lead_x = 0, lead_y = 0)
	var/turf/low = locate(max(1, cx - rx + min(0, lead_x)), max(1, cy - ry + min(0, lead_y)), z)
	var/turf/high = locate(min(world.maxx, cx + rx + max(0, lead_x)), min(world.maxy, cy + ry + max(0, lead_y)), z)
	if (!low || !high)
		return 0
	// A level being added is not ready to show or be shown; the other levels
	// keep their views (the whole scan used to stop for any allocation).
	if (building_allocating_z && (z == building_allocating_z || multiz_level_below(z) == building_allocating_z))
		return 0
	. = 0
	for (var/turf/sky/building/T in block(low, high))
		// One failing cell must not leave the rest of the screen showing the sky.
		try
			T.open_air_view_refresh()
		catch (var/exception/cell_error)
			open_air_view_error(cell_error, T)
		if (T.open_air_view)
			.++

// Logs a scan failure once per distinct error, so a cell failing every second
// does not flood the log and is still found.
var/global/open_air_view_last_error = null

/proc/open_air_view_error(exception/E, atom/where)
	var/text = "[E ? E.name : "unknown"] at [E ? E.file : "?"]:[E ? E.line : "?"]"
	if (text == open_air_view_last_error)
		return
	open_air_view_last_error = text
	log_debug("Open air view: [text] ([where ? "[where.x],[where.y],[where.z]" : "no cell"])")

// Views that no scan reaches (a murder hole's look at the tile under it),
// resynced by the process every time it fires.
var/global/list/open_air_views_fixed = list()

/proc/open_air_view_sync_fixed()
	for (var/obj/effect/open_air_view/V in open_air_views_fixed)
		V.open_air_view_sync()

// The saver owns turf fields and the lighting registry while it works, and a
// lighting startup would make a woken cell wait (and the process look hung).
/proc/open_air_view_busy()
	return persistence_active_operation || persistence_save_in_progress || lighting_startup_in_progress

#undef OPEN_AIR_VIEW_MARGIN
#undef OPEN_AIR_VIEW_RESCAN
#undef OPEN_AIR_VIEW_LEAD
#undef OPEN_AIR_VIEW_LAYER
