// Full-source probe: door fittings (door_fittings.dm). Closers shut a door once
// the doorway is clear, never on someone standing in it; spring hinges shut at
// once unless held; a wedge keeps a door open until pulled; fittings go on and
// come off with the right tool, only while unlocked; doors come down for most
// of their material; and the door knows its sides.
/world
	hub = ""
	visibility = 0
	maxx = 12
	maxy = 12
	maxz = 1
	fps = 20
	turf = /turf/floor/plating/door_fittings_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/door_fittings_probe/New()
	map = src

/turf/floor/plating/door_fittings_probe

var/door_fittings_probe_checks = 0
var/door_fittings_runtime = null

/world/Error(exception/e)
	if (!door_fittings_runtime)
		door_fittings_runtime = "runtime [e] ([e.file]:[e.line])"

/proc/door_fittings_assert(ok, label)
	door_fittings_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/door_fittings_actor(tx, ty, name)
	var/mob/living/human/H = new(locate(tx, ty, 1))
	H.canmove = TRUE
	H.stat = CONSCIOUS
	H.real_name = name
	H.name = name
	H.hand = 0
	H.a_intent = I_HELP
	return H

// A door between two solid tiles north and south: people pass east-west.
/proc/door_fittings_door(tx, ty, path = /obj/structure/simple_door/key_door/anyone/wood)
	var/turf/N = locate(tx, ty + 1, 1)
	var/turf/S = locate(tx, ty - 1, 1)
	N.density = TRUE
	S.density = TRUE
	var/obj/structure/simple_door/D = new path(locate(tx, ty, 1))
	sleep(10)
	return D

/proc/door_fittings_open(obj/structure/simple_door/D)
	D.Open()
	sleep(12)

/proc/door_fittings_hands(mob/living/human/H, obj/item/active, obj/item/other)
	H.drop_l_hand()
	H.drop_r_hand()
	if (active)
		H.put_in_r_hand(active)
	if (other)
		H.put_in_l_hand(other)

/proc/door_fittings_probe_run()
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
	map = new /obj/map_metadata/door_fittings_probe

	var/obj/structure/simple_door/D = door_fittings_door(5, 5)
	var/mob/living/human/west = door_fittings_actor(4, 5, "West")
	var/mob/living/human/east = door_fittings_actor(6, 5, "East")

	// Sides: walls north and south give an east-west passage.
	door_fittings_assert(D.door_passage_axis() == EAST, "axis_from_walls")
	door_fittings_assert(D.door_side_of(west) == WEST && D.door_side_of(east) == EAST, "sides")
	door_fittings_assert(D.door_side_of(D) == 0, "doorway_is_both_sides")
	door_fittings_assert(D.door_seals_room(), "shut_door_seals")

	// No tool, no fitting; with a screwdriver in the other hand it goes on.
	var/obj/item/door_fitting/spring_closer/closer = new
	door_fittings_hands(west, closer, null)
	D.attackby(closer, west)
	door_fittings_assert(!D.door_closer && !QDELETED(closer), "fitting_needs_tool")
	var/obj/item/weapon/screwdriver/driver = new
	door_fittings_hands(west, closer, driver)
	D.attackby(closer, west)
	door_fittings_assert(D.door_closer == "spring" && QDELETED(closer), "spring_closer_fitted")
	door_fittings_assert(D.fitting_images && D.fitting_images.len == 1, "closer_overlay")

	// It shuts itself 4 s after opening.
	door_fittings_open(D)
	door_fittings_assert(D.state && !D.door_seals_room(), "opened")
	sleep(45)
	sleep(12)
	door_fittings_assert(!D.state && D.density, "spring_closer_shuts")

	// Never on someone in the doorway; once they step off it shuts.
	door_fittings_open(D)
	west.forceMove(D.loc)
	sleep(60)
	door_fittings_assert(D.state, "doorway_blocks_closing")
	west.forceMove(locate(4, 5, 1))
	sleep(30)
	sleep(12)
	door_fittings_assert(!D.state, "shuts_once_clear")

	// A late arrival can enter after the closer checked the doorway.
	door_fittings_open(D)
	D.door_schedule_close(1)
	sleep(4)
	door_fittings_assert(D.isSwitchingStates && D.state && !D.density, "automatic_close_animating")
	west.forceMove(D.loc)
	sleep(12)
	door_fittings_assert(D.state && !D.isSwitchingStates && !D.density && !D.opacity, "late_arrival_aborts_automatic_close")
	door_fittings_assert(D.icon_state == "[D.basic_icon]open", "aborted_close_remains_visually_open")
	west.forceMove(locate(4, 5, 1))
	sleep(30)
	door_fittings_assert(!D.state && D.density, "late_arrival_close_retries")

	// Manually closing still works; it must not eat either hold-open item.
	door_fittings_open(D)
	D.SwitchState() // a headless mob cannot pass the hand verb's client gate
	door_fittings_assert(D.isSwitchingStates && D.state, "manual_close_animating")
	var/closing_token = D.close_token
	var/obj/item/door_wedge/moving_wedge = new
	door_fittings_hands(west, moving_wedge, null)
	D.attackby(moving_wedge, west)
	door_fittings_assert(west.r_hand == moving_wedge && !QDELETED(moving_wedge) && !D.door_wedge && D.close_token == closing_token, "moving_door_keeps_wedge_in_hand")
	var/obj/item/fusible_link/moving_link = new
	door_fittings_hands(west, moving_link, null)
	D.attackby(moving_link, west)
	door_fittings_assert(west.r_hand == moving_link && !QDELETED(moving_link) && !D.fire_link_holding && D.close_token == closing_token, "moving_door_keeps_link_in_hand")
	sleep(12)
	door_fittings_assert(!D.state && D.density, "manual_close_finishes")
	door_fittings_open(D)
	D.attackby(moving_link, west)
	door_fittings_assert(D.fire_link_holding && QDELETED(moving_link), "settled_open_door_accepts_link")
	D.attack_hand(west)
	door_fittings_assert(!D.fire_link_holding, "settled_open_door_releases_link")
	sleep(57)

	// A wedge keeps it open; pulling it out by hand takes it back and the door shuts.
	var/obj/item/door_wedge/wedge = new
	door_fittings_hands(west, wedge, null)
	D.attackby(wedge, west)
	door_fittings_assert(!D.door_wedge, "wedge_needs_open_door")
	door_fittings_open(D)
	D.attackby(wedge, west)
	door_fittings_assert(D.door_wedge == "wood" && QDELETED(wedge), "wedged")
	sleep(60)
	door_fittings_assert(D.state, "wedge_holds_open")
	D.attack_hand(west)
	door_fittings_assert(!D.door_wedge && istype(west.r_hand, /obj/item/door_wedge), "wedge_pulled_to_hand")
	sleep(45)
	sleep(12)
	door_fittings_assert(!D.state, "shuts_after_unwedging")

	// Kicking a wedge out drops it on the floor.
	door_fittings_open(D)
	D.attackby(west.r_hand, west)
	west.a_intent = I_HARM
	D.attack_hand(west)
	west.a_intent = I_HELP
	door_fittings_assert(!D.door_wedge && (locate(/obj/item/door_wedge) in D.loc), "wedge_kicked_out")
	sleep(57)

	// Taking the closer off returns it; a wrench is the wrong tool.
	var/obj/item/weapon/hammer/hammer = new
	var/obj/item/weapon/wrench/spanner = new
	door_fittings_hands(west, spanner, null)
	D.attackby(spanner, west)
	door_fittings_assert(D.door_closer == "spring" && !QDELETED(D), "wrong_tool_keeps_closer")
	door_fittings_hands(west, driver, null)
	D.attackby(driver, west)
	door_fittings_assert(!D.door_closer && istype(west.l_hand, /obj/item/door_fitting/spring_closer), "closer_removed")
	door_fittings_assert(!D.fitting_images, "overlay_cleared")

	// Spring hinges: shut a second after the doorway clears, unless held.
	var/obj/item/door_fitting/spring_hinge/hinge = new
	door_fittings_hands(west, hinge, driver)
	D.attackby(hinge, west)
	door_fittings_assert(D.door_closer == "spring_hinge", "hinges_fitted")
	door_fittings_open(D)
	sleep(12)
	sleep(12)
	door_fittings_assert(!D.state, "spring_hinge_shuts")
	door_fittings_hands(west, null, null)
	door_fittings_open(D)
	west.a_intent = I_GRAB
	D.attack_hand(west)
	west.a_intent = I_HELP
	var/obj/item/door_hold/hold = D.door_hold
	door_fittings_assert(istype(hold) && west.r_hand == hold, "grab_holds_open")
	sleep(40)
	door_fittings_assert(D.state, "held_stays_open")
	west.drop_from_inventory(hold)
	door_fittings_assert(!D.door_hold, "drop_lets_go")
	sleep(12)
	sleep(12)
	door_fittings_assert(!D.state, "lets_go_and_shuts")
	door_fittings_open(D)
	west.a_intent = I_GRAB
	D.attack_hand(west)
	west.a_intent = I_HELP
	hold = D.door_hold
	west.forceMove(locate(2, 5, 1))
	hold.check_hold()
	door_fittings_assert(!D.door_hold && !west.r_hand, "walking_off_lets_go")
	sleep(25)
	door_fittings_assert(!D.state, "shut_after_walking_off")
	west.forceMove(locate(4, 5, 1))

	// Hydraulic delay is clamped.
	D.door_closer = "hydraulic"
	D.closer_delay = 500
	door_fittings_assert(D.door_close_delay() == 100, "hydraulic_clamped_high")
	D.closer_delay = 1
	door_fittings_assert(D.door_close_delay() == 20, "hydraulic_clamped_low")
	D.door_closer = null

	// A locked door takes no fittings and won't come down.
	var/obj/structure/simple_door/key_door/custom/locked = door_fittings_door(8, 5, /obj/structure/simple_door/key_door/custom)
	locked.locked = TRUE
	var/obj/item/door_fitting/counterweight/weight = new
	door_fittings_hands(east, weight, new /obj/item/weapon/hammer)
	locked.attackby(weight, east)
	door_fittings_assert(!locked.door_closer, "locked_refuses_fitting")
	var/obj/item/weapon/wrench/wrench = new
	door_fittings_hands(east, wrench, null)
	locked.attackby(wrench, east)
	door_fittings_assert(!QDELETED(locked), "locked_stays_up")

	// Taking a wooden door down: hammer, fittings back, three quarters of the wood.
	D.door_closer = "spring"
	door_fittings_hands(west, hammer, null)
	var/turf/T = D.loc
	D.attackby(hammer, west)
	door_fittings_assert(QDELETED(D), "door_taken_down")
	var/sheets = 0
	for (var/obj/item/stack/material/S in T)
		sheets += S.amount
	door_fittings_assert(sheets == 3, "refund_three_quarters")
	door_fittings_assert(locate(/obj/item/door_fitting/spring_closer) in T, "fitting_returned")

	// A smashed door drops its wedge.
	var/obj/structure/simple_door/W = door_fittings_door(10, 5)
	W.door_closer = "spring"
	door_fittings_open(W)
	W.door_wedge = "iron"
	var/turf/WT = W.loc
	qdel(W)
	door_fittings_assert(locate(/obj/item/door_wedge/iron) in WT, "smashed_drops_wedge")

/world/New()
	OpenPort("none")
	var/error = null
	try
		door_fittings_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] ([probe_error.file]:[probe_error.line])"
	if (!error && door_fittings_runtime)
		error = door_fittings_runtime
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = door_fittings_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
