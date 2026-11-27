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

/mob/living/human/window_lob_probe/New()
	icon_update = FALSE

/obj/item/weapon/grenade/window_lob_probe
	var/turf/primed_at
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
		var/list/path = window_lob_approach(H, ground, opening, EAST, 2)
		window_lob_check(path.len == 1 && path[1] == exterior, "approach has one exterior waypoint")
		window_lob_check(!window_lob_inside(H, exterior, opening, EAST), "no window cannot yield an upstairs landing")
		var/obj/structure/window_frame/F = new(opening)
		window_lob_check(F.loc == opening && window_lob_inside(H, exterior, opening, EAST) == inside, "empty frame yields only the first inside tile")
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
		path = window_lob_approach(H, ground, opening, EAST, 2)
		window_lob_check(!path.len, "a roof along the exterior approach stops the lob")
		qdel(R)
		path = window_lob_approach(H, ground, opening, EAST, 2)
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
		G.det_time = 1
		G.activate()
		G.start_window_lob(H, opening, EAST, path.Copy(), TRUE)
		flight = G.throw_flight_token
		flight["window_lob_next_tick"] = world.time
		G.window_lob_hop(flight)
		sleep(3)
		window_lob_check(G.primed_at == exterior && G.active, "the original fuse fires during flight on the grenade's current tile")
	catch (var/exception/e)
		window_lob_check(FALSE, "[e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = window_lob_failures, "runtime_error" = window_lob_runtime, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
