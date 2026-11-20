// Full-source probe: fitted locks (fitted_locks.dm). Keyed locks go on with
// their tool, lock and unlock with their own key only and have a thumb-turn on
// the far side; latches lock themselves; padlocks fit chests and crowbars force
// them; seals break, knots untie, hidden catches stop strangers; key blanks cut
// copies; a door's inside decides where it can be taken off its hinges.
/world
	hub = ""
	visibility = 0
	maxx = 12
	maxy = 12
	maxz = 1
	fps = 20
	turf = /turf/floor/plating/door_locks_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/door_locks_probe/New()
	map = src

/turf/floor/plating/door_locks_probe

var/door_locks_probe_checks = 0
var/door_locks_runtime = null

/world/Error(exception/e)
	if (!door_locks_runtime)
		door_locks_runtime = "runtime [e] ([e.file]:[e.line])"

/proc/door_locks_assert(ok, label)
	door_locks_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/door_locks_actor(tx, ty, name)
	var/mob/living/human/H = new(locate(tx, ty, 1))
	H.canmove = TRUE
	H.stat = CONSCIOUS
	H.real_name = name
	H.name = name
	H.hand = 0
	H.a_intent = I_HELP
	return H

// A door between two solid tiles north and south: people pass east-west.
/proc/door_locks_door(tx, ty, path = /obj/structure/simple_door/key_door/anyone/wood)
	var/turf/N = locate(tx, ty + 1, 1)
	var/turf/S = locate(tx, ty - 1, 1)
	N.density = TRUE
	S.density = TRUE
	var/obj/structure/simple_door/D = new path(locate(tx, ty, 1))
	sleep(10)
	return D

/proc/door_locks_open(obj/structure/simple_door/D)
	D.Open()
	sleep(12)

/proc/door_locks_hands(mob/living/human/H, obj/item/active, obj/item/other)
	H.drop_l_hand()
	H.drop_r_hand()
	if (active)
		H.put_in_r_hand(active)
	if (other)
		H.put_in_l_hand(other)

/proc/door_locks_probe_run()
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
	map = new /obj/map_metadata/door_locks_probe

	var/obj/structure/simple_door/D = door_locks_door(5, 5)
	var/mob/living/human/west = door_locks_actor(4, 5, "West")
	var/mob/living/human/east = door_locks_actor(6, 5, "East")
	var/obj/item/weapon/screwdriver/driver = new
	var/obj/item/weapon/hammer/hammer = new

	// No inside on open ground; the builder's choice sets one.
	door_locks_assert(D.door_inner_side() == 0, "no_inside_by_default")
	D.inner_dir = WEST
	door_locks_assert(D.door_inner_side() == WEST, "chosen_inside")
	door_locks_assert(findtext(D.door_facing_text(west), "You are on the inside"), "facing_text_inside")
	door_locks_assert(findtext(D.door_facing_text(east), "You are on the outside"), "facing_text_outside")
	D.inner_dir = -1
	door_locks_assert(D.door_inner_side() == 0, "neither_side")
	D.inner_dir = 0

	// A warded lock: take its key, fit it with a screwdriver from the west.
	var/obj/item/fitted_lock/warded/lock = new
	door_locks_hands(west, lock, null)
	lock.attack_self(west)
	var/obj/item/weapon/key/warded/key = west.l_hand
	door_locks_assert(istype(key) && key.code && key.code == lock.code, "key_taken_out")
	D.attackby(lock, west)
	door_locks_assert(!D.door_lock && !QDELETED(lock), "lock_needs_tool")
	door_locks_hands(west, lock, driver)
	D.attackby(lock, west)
	door_locks_assert(D.door_lock && QDELETED(lock), "lock_fitted")
	door_locks_assert(D.door_lock.side == WEST && D.door_inner_side() == EAST, "keyhole_outside_hinges_inside")

	// The key locks it; nobody opens it by hand from the keyhole side.
	door_locks_hands(west, key, null)
	D.attackby(key, west)
	door_locks_assert(D.door_lock.locked && D.door_lock_engaged(), "key_locks")
	door_locks_assert(!D.canOpen(west), "locked_from_outside")
	var/obj/item/weapon/key/tumbler/wrong = new
	wrong.code = key.code
	door_locks_hands(west, wrong, null)
	D.attackby(wrong, west)
	door_locks_assert(D.door_lock.locked, "wrong_family_fails")

	// Outside, the hinges are out of reach.
	door_locks_hands(west, hammer, null)
	D.attackby(hammer, west)
	door_locks_assert(!QDELETED(D), "no_take_down_from_outside")

	// The thumb-turn opens it from inside.
	door_locks_assert(lock_hand_access(D, east) && !D.door_lock.locked, "thumb_turn_opens")
	door_locks_assert(lock_hand_lock(D, east) && D.door_lock.locked, "thumb_turn_locks")

	// A blank filed to the key opens it too.
	var/obj/item/weapon/key/blank/blank = new
	door_locks_hands(west, blank, key)
	blank.attackby(key, west)
	var/obj/item/weapon/key/warded/copy = west.r_hand
	door_locks_assert(istype(copy) && copy.code == key.code && !copy.blank, "blank_cut")
	D.attackby(copy, west)
	door_locks_assert(!D.door_lock.locked, "copy_unlocks")

	// A pen label is display only: the key keeps its name underneath, still fits,
	// copies carry it, and an empty label restores the original name.
	var/key_name = key.name
	var/key_code = key.code
	key.set_key_label("Workshop")
	door_locks_assert(key.name == "[key_name] (Workshop)" && key.key_label == "Workshop", "label_shown")
	key.set_key_label("Storeroom")
	door_locks_assert(key.name == "[key_name] (Storeroom)", "label_replaced_not_stacked")
	door_locks_assert(key.code == key_code && key.key_family == "warded", "label_keeps_cut")
	door_locks_hands(west, key, null)
	D.attackby(key, west)
	door_locks_assert(D.door_lock.locked, "labelled_key_locks")
	D.attackby(key, west)
	door_locks_assert(!D.door_lock.locked, "labelled_key_unlocks")
	var/obj/item/weapon/key/blank/blank2 = new
	door_locks_hands(west, blank2, key)
	blank2.attackby(key, west)
	var/obj/item/weapon/key/warded/copy2 = west.r_hand
	door_locks_assert(istype(copy2) && copy2.code == key_code && copy2.name == key.name && copy2.key_label == "Storeroom", "copy_keeps_label")
	copy2.set_key_label("")
	door_locks_assert(copy2.name == key_name && !copy2.key_label && key.key_label == "Storeroom", "empty_label_clears_one_key")
	var/obj/item/weapon/pen/pen = new
	door_locks_hands(west, pen, null)
	key.loc = west.loc
	door_locks_assert(key.key_label_reachable(pen, west), "label_reachable_beside_writer")
	var/obj/structure/closet/crate/box = new(locate(3, 5, 1))
	key.loc = box
	door_locks_assert(!key.key_label_reachable(pen, west), "label_not_reachable_in_container")
	key.loc = west.loc
	door_locks_hands(west, null, pen)
	door_locks_assert(!key.key_label_reachable(pen, west), "label_needs_pen_in_hand")
	qdel(pen)
	qdel(box)

	// A latch locks itself when the door shuts.
	var/obj/structure/simple_door/L = door_locks_door(8, 5)
	var/mob/living/human/latcher = door_locks_actor(7, 5, "Latcher")
	var/obj/item/fitted_lock/latch/latch = new
	door_locks_hands(latcher, latch, driver)
	L.attackby(latch, latcher)
	door_locks_assert(L.door_lock && L.door_lock.kind == "latch" && !L.door_lock.locked, "latch_fitted")
	L.Open()
	sleep(12)
	L.Close()
	sleep(12)
	door_locks_assert(L.door_lock.locked, "latch_locks_on_shut")

	// A padlock goes on a crate with no tool; a crowbar breaks it.
	var/obj/structure/closet/crate/C = new(locate(2, 2, 1))
	var/mob/living/human/thief = door_locks_actor(2, 3, "Thief")
	var/obj/item/fitted_lock/padlock/pad = new
	door_locks_hands(thief, pad, null)
	pad.attack_self(thief)
	var/obj/item/weapon/key/padkey = thief.l_hand
	C.attackby(pad, thief)
	door_locks_assert(C.fitted_lock && C.fitted_lock.kind == "padlock", "padlock_on_crate")
	C.attackby(padkey, thief)
	door_locks_assert(C.fitted_lock.locked, "crate_locked")
	door_locks_hands(thief, null, null)
	C.attack_hand(thief)
	door_locks_assert(!C.opened, "locked_crate_stays_shut")
	var/obj/item/weapon/crowbar/bar = new
	door_locks_hands(thief, bar, null)
	thief.a_intent = I_HARM
	C.attackby(bar, thief)
	thief.a_intent = I_HELP
	door_locks_assert(!C.fitted_lock, "crowbar_breaks_lock")

	// A clay seal stops nobody but breaks when opened.
	var/obj/structure/storage_container/basket/B = new(locate(10, 10, 1))
	var/mob/living/human/potter = door_locks_actor(10, 9, "Potter")
	var/obj/item/fitted_lock/seal/seal = new
	door_locks_hands(potter, seal, null)
	B.attackby(seal, potter)
	door_locks_assert(B.fitted_lock && B.fitted_lock.locked && !B.fitted_lock.blocks(), "seal_fitted")
	door_locks_assert(B.storage_access_allowed(thief) && !B.fitted_lock.locked, "seal_breaks")

	// A knot ties shut and unties by hand.
	var/obj/structure/closet/crate/K = new(locate(3, 9, 1))
	var/mob/living/human/sailor = door_locks_actor(3, 10, "Sailor")
	var/obj/item/fitted_lock/knot/knot = new
	door_locks_hands(sailor, knot, null)
	K.attackby(knot, sailor)
	door_locks_assert(lock_hand_lock(K, sailor) && K.fitted_lock.locked && K.fitted_lock.tied_by == "Sailor", "knot_tied")
	door_locks_assert(lock_hand_access(K, sailor) && !K.fitted_lock.locked, "knot_untied")

	// A hidden catch: its maker walks in; a stranger is stopped.
	var/obj/structure/closet/crate/H = new(locate(7, 9, 1))
	var/mob/living/human/maker = door_locks_actor(7, 10, "Maker")
	var/obj/item/fitted_lock/hidden_catch/hidden = new
	door_locks_hands(maker, hidden, hammer)
	H.attackby(hidden, maker)
	door_locks_assert(H.fitted_lock && H.fitted_lock.kind == "catch", "catch_fitted")
	door_locks_assert(lock_hand_access(H, maker, TRUE), "maker_knows_catch")
	door_locks_assert(!lock_hand_access(H, thief, TRUE), "stranger_stopped")

	// A jail door built without a key takes a padlock; its key locks it.
	var/obj/structure/simple_door/key_door/custom/jail/steeljail/J = door_locks_door(10, 5, /obj/structure/simple_door/key_door/custom/jail/steeljail)
	var/mob/living/human/jailer = door_locks_actor(9, 5, "Jailer")
	var/obj/item/fitted_lock/padlock/jailpad = new
	door_locks_hands(jailer, jailpad, null)
	jailpad.attack_self(jailer)
	var/obj/item/weapon/key/jailpadkey = jailer.l_hand
	J.attackby(jailpad, jailer)
	door_locks_assert(J.door_lock && J.door_lock.kind == "padlock", "padlock_on_keyless_jail")
	J.attackby(jailpadkey, jailer)
	door_locks_assert(J.door_lock.locked && !J.canOpen(jailer), "jail_padlocked")
	J.attackby(jailpadkey, jailer)
	door_locks_assert(!J.door_lock.locked && J.canOpen(jailer), "jail_padlock_unlocked")
	var/turf/JT = J.loc
	J.jail_dismantle()
	door_locks_assert(locate(/obj/item/fitted_lock/padlock) in JT, "jail_dismantle_returns_padlock")

	// A jail door keyed when built still takes a padlock, but no other lock;
	// each key works its own lock.
	var/obj/structure/simple_door/key_door/custom/jail/steeljail/KJ = door_locks_door(10, 2, /obj/structure/simple_door/key_door/custom/jail/steeljail)
	KJ.custom_code = 4321
	var/mob/living/human/warden = door_locks_actor(9, 2, "Warden")
	var/obj/item/fitted_lock/warded/wardlock = new
	door_locks_hands(warden, wardlock, driver)
	KJ.attackby(wardlock, warden)
	door_locks_assert(!KJ.door_lock && !QDELETED(wardlock), "keyed_jail_refuses_warded")
	var/obj/item/fitted_lock/padlock/hasp = new
	door_locks_hands(warden, hasp, null)
	hasp.attack_self(warden)
	var/obj/item/weapon/key/haspkey = warden.l_hand
	KJ.attackby(hasp, warden)
	door_locks_assert(KJ.door_lock && KJ.door_lock.kind == "padlock", "keyed_jail_takes_padlock")
	var/obj/item/weapon/key/cellkey = new
	cellkey.code = 4321
	door_locks_hands(warden, cellkey, null)
	KJ.attackby(cellkey, warden)
	door_locks_assert(KJ.locked && !KJ.door_lock.locked, "cell_key_works_own_lock")
	door_locks_hands(warden, haspkey, null)
	KJ.attackby(haspkey, warden)
	door_locks_assert(KJ.locked && KJ.door_lock.locked, "padlock_key_works_padlock")

	// From inside, with the door unlocked, it comes down and the lock with it.
	door_locks_hands(east, hammer, null)
	var/turf/T = D.loc
	D.attackby(hammer, east)
	door_locks_assert(QDELETED(D), "taken_down_from_inside")
	door_locks_assert(locate(/obj/item/fitted_lock/warded) in T, "lock_returned")

/world/New()
	OpenPort("none")
	var/error = null
	try
		door_locks_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] ([probe_error.file]:[probe_error.line])"
	if (!error && door_locks_runtime)
		error = door_locks_runtime
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = door_locks_probe_checks, "error" = door_locks_runtime ? door_locks_runtime : error, "byond_build" = byond_build)), "receipt.json")
	del(world)
