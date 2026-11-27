/world
	hub = ""
	hub_password = ""
	maxx = 10
	maxy = 10
	maxz = 3
	turf = /turf
	area = /area
	visibility = 0

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/mob/living/human/window_lob_probe
	var/atom/movable/last_lob_hit
/mob/living/human/window_lob_probe/New()
	icon_update = FALSE
/mob/living/human/window_lob_probe/hitby(atom/movable/AM, speed)
	last_lob_hit = AM

/obj/item/weapon/grenade/window_lob_probe
	var/turf/primed_at
	var/turf/refuse_move_to
/obj/item/weapon/grenade/window_lob_probe/forceMove(atom/destination, special_event)
	if (destination == refuse_move_to)
		return FALSE
	return ..()
/obj/item/weapon/grenade/window_lob_probe/prime()
	primed_at = get_turf(src)

var/window_lob_failures = 0
var/window_lob_runtime = FALSE

/proc/window_lob_check(condition, name)
	if (!condition)
		window_lob_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [name]"

/world/Error(exception/e)
	window_lob_runtime = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		var/turf/ground = locate(2, 5, 1)
		var/turf/exterior = locate(3, 5, 1)
		var/turf/opening = locate(4, 5, 2)
		var/turf/inside = locate(5, 5, 2)
		new /turf/sky/building(locate(2, 5, 2))
		new /turf/sky/building(locate(3, 5, 2))
		var/mob/living/human/window_lob_probe/H = new(ground)
		var/list/path = window_lob_approach(H, ground, opening, 2)
		window_lob_check(path.len == 1 && path[1] == exterior, "approach has one exterior waypoint")
		window_lob_check(!window_lob_inside(H, exterior, opening, EAST), "no window cannot yield an upstairs landing")
		var/obj/structure/window_frame/F = new(opening)
		window_lob_check(F.loc == opening && window_lob_inside(H, exterior, opening, EAST) == inside, "empty frame yields only the first inside tile")
		var/turf/eye = locate(2, 5, 2)
		window_lob_check(window_lob_clicked_window(H, eye, inside) == opening, "clicking the first room tile chooses the blocking window")
		window_lob_check(!window_lob_clicked_window(H, eye, locate(6, 5, 2)), "clicking deeper in a room does not skip the first tile")
		var/turf/far_opening = locate(8, 4, 2)
		var/obj/structure/window_frame/far_frame = new(far_opening)
		window_lob_check(far_frame.loc == far_opening && window_lob_clicked_window(H, locate(1, 4, 2), locate(9, 4, 2)) == far_opening, "first inside tile resolves to a window at maximum range")
		window_lob_check(!window_lob_inside(H, ground, opening, EAST), "cannot skip across a distant opening")
		window_lob_check(!window_lob_inside(H, exterior, locate(4, 5, 3), EAST), "cannot skip to a higher storey")
		window_lob_check(!window_lob_inside(H, exterior, opening, NORTH), "cannot bypass the aperture from the side")
		var/obj/structure/simple_door/key_door/anyone/casement/C = new(opening)
		C.inner_dir = EAST
		C.state = TRUE
		window_lob_check(window_lob_inside(H, exterior, opening, EAST) == inside, "an open casement allows the lob")
		C.state = FALSE
		window_lob_check(!window_lob_inside(H, exterior, opening, EAST), "a closed casement stops the lob")
		C.state = TRUE
		C.door_bar_kind = list("4" = "iron")
		window_lob_check(!window_lob_inside(H, exterior, opening, EAST), "bars prevent passage even while the casement is open")
		C.door_bar_kind = null
		var/obj/structure/simple_door/key_door/anyone/window_shutters/S = new(opening)
		S.state = FALSE
		window_lob_check(!window_lob_inside(H, exterior, opening, EAST), "closed shutters prevent passage")
		S.state = TRUE
		var/obj/structure/window/W = new(opening)
		window_lob_check(!window_lob_inside(H, exterior, opening, EAST), "open shutters do not bypass an intact pane")
		qdel(W)
		window_lob_check(window_lob_inside(H, exterior, opening, EAST) == inside, "the opening is usable again once the pane is gone")
		var/obj/block = new(inside)
		block.density = TRUE
		window_lob_check(!window_lob_inside(H, exterior, opening, EAST), "a solid object immediately inside stops the lob")
		qdel(block)
		var/obj/roof/R = new(exterior)
		path = window_lob_approach(H, ground, opening, 2)
		window_lob_check(!path.len, "a roof along the exterior approach stops the lob")
		qdel(R)
		path = window_lob_approach(H, ground, opening, 2)
		window_lob_check(window_lob_range(1.5, ITEM_SIZE_SMALL) > window_lob_range(1, ITEM_SIZE_SMALL), "strength raises lob range")
		window_lob_check(window_lob_accuracy(120, 5) > window_lob_accuracy(100, 5), "throwing skill improves the chance at the same distance")
		var/obj/item/weapon/grenade/window_lob_probe/G = new(ground)
		G.start_window_lob(H, opening, EAST, path.Copy(), TRUE)
		var/list/flight = G.throw_flight_token
		flight["window_lob_next_tick"] = world.time
		G.window_lob_hop(flight)
		window_lob_check(G.loc == exterior && G.throw_flight_token == flight, "first hop stays outside and in the same flight")
		flight["window_lob_next_tick"] = world.time
		G.window_lob_hop(flight)
		window_lob_check(G.loc == inside && !G.throw_flight_token && !G.throwing && !(G in thrown_list), "cross-storey landing leaves no old flight queued")
		G.forceMove(ground)
		G.start_window_lob(H, opening, EAST, path.Copy(), TRUE)
		flight = G.throw_flight_token
		flight["window_lob_next_tick"] = world.time
		G.window_lob_hop(flight)
		C.state = FALSE
		flight["window_lob_next_tick"] = world.time
		G.window_lob_hop(flight)
		window_lob_check(G.loc == exterior && !G.throwing, "a window that closes midflight leaves the grenade outside")
		C.state = TRUE
		G.forceMove(ground)
		G.start_window_lob(H, opening, EAST, path.Copy(), TRUE)
		flight = G.throw_flight_token
		flight["window_lob_next_tick"] = world.time
		G.window_lob_hop(flight)
		G.refuse_move_to = inside
		flight["window_lob_next_tick"] = world.time
		G.window_lob_hop(flight)
		window_lob_check(G.loc == exterior && !G.throwing && !G.throw_flight_token && !(G in thrown_list), "a refused entry finishes outside without retrying after the save gate opens")
		G.refuse_move_to = null
		G.window_lob_hop(flight)
		window_lob_check(G.loc == exterior, "cleared flight cannot enter after movement becomes allowed")
		G.forceMove(ground)
		G.det_time = 1
		G.activate()
		G.start_window_lob(H, opening, EAST, path.Copy(), TRUE)
		flight = G.throw_flight_token
		flight["window_lob_next_tick"] = world.time
		G.window_lob_hop(flight)
		sleep(3)
		window_lob_check(G.primed_at == exterior && G.active, "the original fuse fires during flight on the grenade's current tile")
		// A second garden wall has exposed upper floor, not a window.
		var/turf/yard = locate(2, 7, 1)
		var/turf/yard_edge = locate(3, 7, 1)
		var/turf/ledge = locate(4, 7, 2)
		new /turf/sky/building(locate(2, 7, 2))
		new /turf/sky/building(locate(3, 7, 2))
		new /turf/sky/building(locate(4, 7, 3))
		var/list/ledge_path = window_lob_approach(H, yard, ledge, 2)
		window_lob_check(ledge_path.len == 1 && window_lob_landing(H, yard_edge, ledge, EAST, FALSE) == ledge, "exposed upper floor is a valid distinct landing")
		window_lob_check(!window_lob_landing(H, yard_edge, ledge, EAST, TRUE), "an exposed floor does not masquerade as a window")
		window_lob_check(!window_lob_landing(H, exterior, opening, EAST, FALSE), "a window does not masquerade as an exposed floor")
		var/obj/item/tool = new(yard)
		tool.start_window_lob(H, ledge, EAST, ledge_path.Copy(), TRUE, FALSE)
		var/list/item_flight = tool.throw_flight_token
		item_flight["window_lob_next_tick"] = world.time
		tool.window_lob_hop(item_flight)
		item_flight["window_lob_next_tick"] = world.time
		tool.window_lob_hop(item_flight)
		window_lob_check(tool.loc == ledge && !tool.throwing, "an ordinary item reaches an exposed upper floor")
		var/mob/living/human/window_lob_probe/occupant = new(inside)
		tool.forceMove(ground)
		tool.start_window_lob(H, opening, EAST, path.Copy(), TRUE)
		item_flight = tool.throw_flight_token
		item_flight["window_lob_next_tick"] = world.time
		tool.window_lob_hop(item_flight)
		item_flight["window_lob_next_tick"] = world.time
		tool.window_lob_hop(item_flight)
		window_lob_check(tool.loc == inside && !tool.throwing, "an ordinary item also reaches the first tile through a window")
		window_lob_check(occupant.last_lob_hit == tool, "landing on a standing occupant uses ordinary throw impact")
		var/turf/deeper_ledge = locate(5, 7, 2)
		new /turf/sky/building(locate(5, 7, 3))
		var/list/deeper_path = window_lob_approach(H, yard, deeper_ledge, 3)
		window_lob_check(deeper_path.len == 1 && window_lob_landing(H, yard_edge, deeper_ledge, EAST, FALSE) == deeper_ledge, "a clicked visible floor beyond the exposed edge is a valid landing")
		var/obj/behind_edge = new(ledge)
		behind_edge.density = TRUE
		window_lob_check(!window_lob_landing(H, yard_edge, deeper_ledge, EAST, FALSE), "the lob cannot skip a blocked exposed edge")
		qdel(behind_edge)
		var/turf/diagonal = locate(4, 8, 2)
		new /turf/sky/building(locate(4, 8, 3))
		new /turf/sky/building(locate(3, 8, 2))
		window_lob_check(window_lob_landing(H, yard_edge, diagonal, NORTHEAST, FALSE) == diagonal, "a diagonal exposed target can pass its open-air corner")
		var/obj/flank_a = new(ledge)
		flank_a.density = TRUE
		var/obj/flank_b = new(locate(3, 8, 2))
		flank_b.density = TRUE
		window_lob_check(!window_lob_landing(H, yard_edge, diagonal, NORTHEAST, FALSE), "a diagonal target cannot cut between two blocked tiles")
		qdel(flank_a)
		qdel(flank_b)
		var/obj/roof/ledge_roof = new(ledge)
		window_lob_check(!window_lob_landing(H, yard_edge, ledge, EAST, FALSE), "a roof rules out a direct landing")
		qdel(ledge_roof)
		var/obj/ledge_wall = new(ledge)
		ledge_wall.density = TRUE
		tool.forceMove(yard)
		tool.start_window_lob(H, ledge, EAST, ledge_path.Copy(), TRUE, FALSE)
		item_flight = tool.throw_flight_token
		item_flight["window_lob_next_tick"] = world.time
		tool.window_lob_hop(item_flight)
		item_flight["window_lob_next_tick"] = world.time
		tool.window_lob_hop(item_flight)
		window_lob_check(tool.loc == yard_edge && !tool.throwing, "a new obstacle on the exposed ledge stops flight outside")
	catch (var/exception/e)
		window_lob_check(FALSE, "[e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = window_lob_failures, "runtime_error" = window_lob_runtime, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
