// Full-source probe: car doors by hand. A shut unlocked door pulls open from
// outside, a locked one stays shut, someone inside can take hold of it and
// tighten their grip, a yank from outside is a contest that tires the holder,
// and the hold lets go when the holder leaves, drops it or is struck.
/world
	hub = ""
	visibility = 0
	maxx = 12
	maxy = 12
	maxz = 1
	fps = 20
	turf = /turf/floor/plating/car_door_hold_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/car_door_hold_probe/New()
	map = src

/turf/floor/plating/car_door_hold_probe

var/car_door_hold_probe_checks = 0
var/car_door_hold_runtime = null

/world/Error(exception/e)
	if (!car_door_hold_runtime)
		car_door_hold_runtime = "runtime [e] ([e.file]:[e.line])"

/proc/car_door_hold_assert(ok, label)
	car_door_hold_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/car_door_hold_actor(tx, ty, name)
	var/mob/living/human/H = new(locate(tx, ty, 1))
	H.canmove = TRUE
	H.stat = CONSCIOUS
	H.real_name = name
	H.name = name
	H.hand = 0
	return H

/proc/car_door_hold_door(obj/structure/vehicleparts/frame/F)
	return F.w_left[7]

/proc/car_door_hold_probe_run()
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
	map = new /obj/map_metadata/car_door_hold_probe

	var/obj/structure/vehicleparts/frame/F = new(locate(5, 5, 1))
	F.dir = NORTH
	F.w_left = list("c_door", TRUE, TRUE, 20, 45, TRUE, FALSE)
	F.doorcode = 4321
	var/mob/living/human/inside = car_door_hold_actor(5, 5, "Driver")
	var/mob/living/human/outside = car_door_hold_actor(4, 5, "Thief")
	car_door_hold_assert(F.has_hand_door() && F.door_inside(inside) && !F.door_inside(outside), "inside_and_outside")

	// Locked: neither side opens it by hand.
	car_door_hold_assert(F.doors_locked(), "closed_with_lock_starts_locked")
	F.attack_hand(outside)
	car_door_hold_assert(!car_door_hold_door(F), "locked_resists_outside")
	// Inside, the release opens a locked door; the lock keeps people out, not in.
	F.attack_hand(inside)
	car_door_hold_assert(car_door_hold_door(F) && F.door_unlocked && !F.doors_locked(), "inside_release_opens_locked")
	F.key_turn_doors(null)
	car_door_hold_assert(!car_door_hold_door(F) && F.doors_locked(), "key_locks_it_again")

	// The key unlocks and opens; a hand shuts it without locking it.
	F.key_turn_doors(null)
	car_door_hold_assert(car_door_hold_door(F) && F.door_unlocked, "key_unlocks_and_opens")
	outside.setClickCooldown(0)
	F.attack_hand(outside)
	car_door_hold_assert(!car_door_hold_door(F) && !F.doors_locked(), "hand_shuts_unlocked")
	F.attack_hand(outside)
	car_door_hold_assert(car_door_hold_door(F), "unlocked_pulls_open")

	// Grab intent inside: shut it and take hold.
	inside.a_intent = I_GRAB
	F.attack_hand(inside)
	var/obj/item/car_door_hold/hold = F.door_hold
	car_door_hold_assert(istype(hold) && inside.r_hand == hold && !car_door_hold_door(F), "grab_shuts_and_holds")
	inside.a_intent = I_HELP

	// Tighten: the hold resists harder once braced.
	var/loose = hold.resist_strength()
	hold.attack_self(inside)
	car_door_hold_assert(hold.grip_tightened, "use_in_hand_tightens")
	sleep(11)
	var/tight = hold.resist_strength()
	car_door_hold_assert(tight > loose, "tight_braced_resists_more")
	car_door_hold_assert(car_door_yank_chance(1, 0) == 100 && car_door_yank_chance(1, 1000) == 5 && car_door_yank_chance(1000, 1) == 95, "yank_chance_bounded")

	// Yanks: every failed yank tires the hold; one eventually tears it open.
	var/opened = FALSE
	var/strain_ok = TRUE
	for (var/i in 1 to 40)
		var/before = hold.current_strain()
		var/won = F.yank_door(outside)
		if (won)
			opened = TRUE
			break
		if (hold.current_strain() <= before)
			strain_ok = FALSE
	car_door_hold_assert(strain_ok, "failed_yank_adds_strain")
	car_door_hold_assert(opened && car_door_hold_door(F) && !F.door_hold && !inside.r_hand && hold.released, "yank_tears_door_open")

	// Leaving the car lets go.
	inside.a_intent = I_GRAB
	F.attack_hand(inside)
	hold = F.door_hold
	car_door_hold_assert(istype(hold), "hold_again")
	inside.forceMove(locate(5, 7, 1))
	hold.check_hold()
	car_door_hold_assert(!F.door_hold && !inside.r_hand, "leaving_lets_go")
	inside.forceMove(F.loc)

	// Dropping lets go; with nobody holding, the door pulls open.
	F.attack_hand(inside)
	hold = F.door_hold
	inside.drop_from_inventory(hold)
	car_door_hold_assert(!F.door_hold && QDELETED(hold), "dropping_lets_go")

	// A blow to the hand breaks a tight hold, then knocks it free.
	F.attack_hand(inside)
	hold = F.door_hold
	hold.toggle_grip(inside)
	var/freed = FALSE
	for (var/i in 1 to 400)
		inside.hand_struck("r_hand", 100)
		if (!F.door_hold)
			freed = TRUE
			break
	car_door_hold_assert(freed && !inside.r_hand, "hand_blow_frees_door")

	// The verb takes hold and lets go.
	inside.hold_car_door()
	car_door_hold_assert(istype(F.door_hold) && F.door_hold.holder == inside, "verb_takes_hold")
	inside.hold_car_door()
	car_door_hold_assert(!F.door_hold, "verb_lets_go")

	// Key on a shut unlocked door locks it in place; the door stays shut.
	F.key_turn_doors(null)
	car_door_hold_assert(!car_door_hold_door(F) && F.doors_locked(), "key_locks_shut_door")
	outside.setClickCooldown(0)
	F.attack_hand(outside)
	car_door_hold_assert(!car_door_hold_door(F), "relocked_resists")

	// A door without any lock is never locked.
	var/obj/structure/vehicleparts/frame/plain = new(locate(8, 8, 1))
	plain.w_right = list("c_door", TRUE, TRUE, 20, 45, TRUE, FALSE)
	car_door_hold_assert(!plain.doors_locked(), "lockless_door_unlocked")

	// A tank's escape hatch: from inside, while she is stopped, out onto clear
	// ground beside her (vehicle_exits.dm).
	var/obj/structure/vehicleparts/axis/heavy/tank_axis = new(locate(2, 3, 1))
	var/obj/structure/vehicleparts/frame/tank_a = new(locate(2, 3, 1))
	var/obj/structure/vehicleparts/frame/tank_b = new(locate(3, 3, 1))
	tank_a.axis = tank_axis
	tank_b.axis = tank_axis
	car_door_hold_assert(tank_a.has_belly_hatch() && !F.has_belly_hatch(), "only_a_tank_has_a_belly_hatch")
	var/mob/living/human/crewman = car_door_hold_actor(2, 3, "Gunner")
	var/mob/living/human/infantry = car_door_hold_actor(2, 2, "Infantry")
	car_door_hold_assert(tank_a.belly_hatch_refusal(infantry) && !tank_a.use_belly_hatch(infantry, TRUE) && infantry.loc == locate(2, 2, 1), "the_hatch_does_not_open_from_outside")
	tank_axis.moving = TRUE
	car_door_hold_assert(findtext(tank_a.belly_hatch_refusal(crewman), "stopped"), "not_while_she_moves")
	tank_axis.moving = FALSE
	var/turf/out = tank_a.use_belly_hatch(crewman, TRUE)
	car_door_hold_assert(out && crewman.loc == out && get_dist(out, tank_a) == 1 && !(locate(/obj/structure/vehicleparts) in out), "crewman_crawls_out_beside_her")
	var/mob/living/human/boxed = car_door_hold_actor(3, 3, "Loader")
	for (var/turf/T in range(3, tank_b))
		if (!(locate(/obj/structure/vehicleparts) in T))
			T.density = TRUE
	car_door_hold_assert(findtext(tank_b.belly_hatch_refusal(boxed), "no clear ground"), "no_clear_ground_no_exit")
	for (var/turf/T in range(3, tank_b))
		T.density = FALSE

	// Ships keep their own hatches.
	var/obj/structure/vehicleparts/frame/ship/S = new(locate(10, 10, 1))
	S.w_left = list("c_door", TRUE, TRUE, 20, 45, TRUE, FALSE)
	car_door_hold_assert(!S.has_hand_door(), "ships_excluded")

/world/New()
	OpenPort("none")
	var/error = null
	try
		car_door_hold_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] ([probe_error.file]:[probe_error.line])"
	if (!error && car_door_hold_runtime)
		error = car_door_hold_runtime
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = car_door_hold_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
