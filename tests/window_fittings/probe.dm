// Full-source probe: opening windows and shutters (window_fittings.dm). A
// casement goes in an empty window frame, shutters on a frame; a shut casement
// is see-through and solid, an open one lets things through but people climb;
// shutters block sight shut and step aside open; both take locks and bars
// with the door side rules; closers are refused; glass on shutters glazes the
// frame behind them.
/world
	hub = ""
	visibility = 0
	maxx = 12
	maxy = 12
	maxz = 1
	fps = 20
	turf = /turf/floor/plating/window_fittings_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/window_fittings_probe/New()
	map = src

/turf/floor/plating/window_fittings_probe

var/window_fittings_probe_checks = 0
var/window_fittings_runtime = null

/world/Error(exception/e)
	if (!window_fittings_runtime)
		window_fittings_runtime = "runtime [e] ([e.file]:[e.line])"

/proc/window_fittings_assert(ok, label)
	window_fittings_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/window_fittings_actor(tx, ty, name)
	var/mob/living/human/H = new(locate(tx, ty, 1))
	H.canmove = TRUE
	H.stat = CONSCIOUS
	H.real_name = name
	H.name = name
	H.hand = 0
	H.a_intent = I_HELP
	return H

/proc/window_fittings_open(obj/structure/simple_door/D)
	D.Open()
	sleep(12)

/proc/window_fittings_hands(mob/living/human/H, obj/item/active, obj/item/other)
	H.drop_l_hand()
	H.drop_r_hand()
	if (active)
		H.put_in_r_hand(active)
	if (other)
		H.put_in_l_hand(other)



// A window frame with walls north and south: people pass east-west.
/proc/window_fittings_frame(tx, ty)
	new /turf/wall(locate(tx, ty + 1, 1))
	new /turf/wall(locate(tx, ty - 1, 1))
	return new /obj/structure/window_frame(locate(tx, ty, 1))

/proc/window_fittings_probe_run()
	config = new
	config.webhook_can_fire = FALSE
	makeDatumRefLists()
	GLOB.all_observable_events = list()
	GLOB.global_listen_count = list()
	GLOB.event_sources_count = list()
	GLOB.event_listen_count = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	GLOB.stat_set_event = new
	GLOB.name_set_event = new
	movementMachine = new
	map = new /obj/map_metadata/window_fittings_probe

	var/casement_type = /obj/structure/simple_door/key_door/anyone/casement
	var/shutter_type = /obj/structure/simple_door/key_door/anyone/window_shutters

	// Build rules: a casement needs an empty frame; shutters a frame or window.
	window_fittings_assert(tile_build_refusal(locate(2, 2, 1), casement_type), "casement_needs_frame")
	window_fittings_assert(tile_build_refusal(locate(2, 2, 1), shutter_type), "shutters_need_window")
	var/obj/structure/window_frame/frame = window_fittings_frame(5, 5)
	window_fittings_assert(!tile_build_refusal(get_turf(frame), casement_type), "casement_in_frame")
	window_fittings_assert(!tile_build_refusal(get_turf(frame), shutter_type), "shutters_on_frame")
	window_fittings_assert(tile_build_refusal(get_turf(frame), /obj/structure/simple_door/key_door/anyone/wood), "door_not_in_frame")
	var/obj/structure/window_frame/medieval_old/odd = new(locate(9, 9, 1))
	window_fittings_assert(tile_build_refusal(get_turf(odd), casement_type) && !tile_build_refusal(get_turf(odd), shutter_type), "casement_needs_square_frame")

	var/obj/structure/simple_door/key_door/anyone/casement/C = new casement_type(get_turf(frame))
	sleep(10)
	window_fittings_assert(C.name == "casement window" && C.basic_icon == "casement" && C.is_window_door(), "casement_built")
	window_fittings_assert(tile_build_refusal(get_turf(frame), shutter_type), "one_window_door_per_tile")

	// Shut: solid and see-through; walking into it doesn't open it.
	var/mob/living/human/west = window_fittings_actor(4, 5, "West")
	var/obj/item/weapon/item_probe = new /obj/item/weapon/hammer
	window_fittings_assert(C.density && !C.opacity && !C.state, "shut_casement")
	window_fittings_assert(!C.CanPass(west, get_turf(C)) && !C.CanPass(item_probe, get_turf(C)), "shut_blocks")
	C.Bumped(west)
	sleep(12)
	window_fittings_assert(!C.state, "bump_does_not_open")
	window_fittings_assert(!C.window_climb_through(west), "no_climb_when_shut")

	// Open: things pass, people don't walk through but climb.
	C.Open()
	sleep(12)
	window_fittings_assert(C.state && C.density && !C.opacity, "open_casement")
	window_fittings_assert(!C.CanPass(west, get_turf(C)) && C.CanPass(item_probe, get_turf(C)), "open_lets_things_through")
	window_fittings_assert(C.window_climb_through(west) && get_turf(west) == locate(6, 5, 1), "climbed_through")
	window_fittings_assert(C.window_climb_through(west) && get_turf(west) == locate(4, 5, 1), "climbed_back")
	new /obj/structure/closet/crate(locate(6, 5, 1))
	window_fittings_assert(!C.window_climb_through(west) && get_turf(west) == locate(4, 5, 1), "landing_blocked")

	// Closers and wedges are refused; a lock goes on with the door rules.
	C.Close()
	sleep(12)
	var/obj/item/weapon/screwdriver/driver = new
	var/obj/item/door_fitting/spring_closer/closer = new
	window_fittings_hands(west, closer, driver)
	C.attackby(closer, west)
	window_fittings_assert(!C.door_closer && !QDELETED(closer), "closer_refused")
	var/obj/item/fitted_lock/latch/latch = new
	window_fittings_hands(west, latch, driver)
	C.attackby(latch, west)
	window_fittings_assert(C.door_lock && C.door_lock.kind == "latch" && C.door_lock.side == WEST, "latch_fitted")
	C.Open()
	sleep(12)
	C.Close()
	sleep(12)
	window_fittings_assert(C.door_lock.locked && C.door_lock_engaged(), "latch_catches")
	window_fittings_assert(!C.canOpen(west), "latched_from_outside")

	// Shutters on another frame: opaque shut, out of the way open.
	var/obj/structure/window_frame/frame2 = window_fittings_frame(5, 9)
	var/obj/structure/simple_door/key_door/anyone/window_shutters/S = new shutter_type(get_turf(frame2))
	sleep(10)
	window_fittings_assert(S.name == "wooden shutters" && S.density && S.opacity, "shutters_shut")
	var/mob/living/human/inside = window_fittings_actor(6, 9, "Inside")
	S.Bumped(inside)
	sleep(12)
	window_fittings_assert(!S.state, "shutters_ignore_bump")
	S.Open()
	sleep(12)
	window_fittings_assert(S.state && !S.density && !S.opacity, "shutters_open")
	S.Close()
	sleep(12)

	// Bar brackets and a bar from the inside.
	var/obj/item/weapon/hammer/hammer = new
	var/obj/item/door_brackets/brackets = new
	window_fittings_hands(inside, brackets, hammer)
	S.attackby(brackets, inside)
	var/obj/item/door_bar/bar = new
	window_fittings_hands(inside, bar, null)
	S.attackby(bar, inside)
	window_fittings_assert(S.door_barred() && S.door_bar_on(EAST) == "wood", "shutters_barred")

	// Glass on the shutters glazes the frame behind them.
	var/obj/item/stack/material/glass/glass = new(null, 5)
	window_fittings_hands(inside, glass, null)
	spawn(0)
		S.attackby(glass, inside)
	sleep(70)
	window_fittings_assert((locate(/obj/structure/window/classic) in get_turf(S)) && !(locate(/obj/structure/window_frame) in get_turf(S)) && !QDELETED(S), "glazed_behind_shutters")

	// A frame holding a casement won't take a fixed pane.
	glass = new(null, 5)
	window_fittings_hands(west, glass, null)
	frame.attackby(glass, west)
	window_fittings_assert(!(locate(/obj/structure/window/classic) in get_turf(C)) && glass.amount == 5, "no_pane_over_casement")

	// Iron shutters.
	var/obj/structure/window_frame/frame3 = window_fittings_frame(9, 5)
	var/obj/structure/simple_door/key_door/anyone/window_shutters/iron/I = new(get_turf(frame3))
	sleep(10)
	window_fittings_assert(I.name == "iron shutters" && I.basic_icon == "shutters_iron" && I.health == 250, "iron_shutters")

/world/New()
	OpenPort("none")
	var/error = null
	try
		window_fittings_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] ([probe_error.file]:[probe_error.line])"
	if (!error && window_fittings_runtime)
		error = window_fittings_runtime
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = window_fittings_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
