// Full-source probe: bars, bolts and bracing (door_bars.dm), and the ways
// locks are defeated (fitted_locks.dm). A bar dropped in from its side shuts
// the door against both sides and only lifts from its side; blows wear the bar
// before the door; a bolt shoots and draws from its side; a braced door won't
// open for anyone else; a latch can be shimmed; event locks refuse the methods
// they list; mapped locks are fitted at load.
/world
	hub = ""
	visibility = 0
	maxx = 12
	maxy = 12
	maxz = 1
	fps = 20
	turf = /turf/floor/plating/door_bars_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/door_bars_probe/New()
	map = src

/turf/floor/plating/door_bars_probe

var/door_bars_probe_checks = 0
var/door_bars_runtime = null

/world/Error(exception/e)
	if (!door_bars_runtime)
		door_bars_runtime = "runtime [e] ([e.file]:[e.line])"

/proc/door_bars_assert(ok, label)
	door_bars_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/door_bars_actor(tx, ty, name)
	var/mob/living/human/H = new(locate(tx, ty, 1))
	H.canmove = TRUE
	H.stat = CONSCIOUS
	H.real_name = name
	H.name = name
	H.hand = 0
	H.a_intent = I_HELP
	return H

// A door between two solid tiles north and south: people pass east-west.
/proc/door_bars_door(tx, ty, path = /obj/structure/simple_door/key_door/anyone/wood)
	var/turf/N = locate(tx, ty + 1, 1)
	var/turf/S = locate(tx, ty - 1, 1)
	N.density = TRUE
	S.density = TRUE
	var/obj/structure/simple_door/D = new path(locate(tx, ty, 1))
	sleep(10)
	return D

/proc/door_bars_open(obj/structure/simple_door/D)
	D.Open()
	sleep(12)

/proc/door_bars_hands(mob/living/human/H, obj/item/active, obj/item/other)
	H.drop_l_hand()
	H.drop_r_hand()
	if (active)
		H.put_in_r_hand(active)
	if (other)
		H.put_in_l_hand(other)

/proc/door_bars_probe_run()
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
	map = new /obj/map_metadata/door_bars_probe

	var/obj/structure/simple_door/key_door/anyone/wood/D = door_bars_door(5, 5)
	var/mob/living/human/west = door_bars_actor(4, 5, "West")
	var/mob/living/human/east = door_bars_actor(6, 5, "East")
	var/obj/item/weapon/hammer/hammer = new

	// Brackets need a hammer and go on the fitter's side.
	var/obj/item/door_brackets/brackets = new
	door_bars_hands(east, brackets, null)
	D.attackby(brackets, east)
	door_bars_assert(!D.door_brackets && !QDELETED(brackets), "brackets_need_hammer")
	door_bars_hands(east, brackets, hammer)
	D.attackby(brackets, east)
	door_bars_assert(D.door_has_brackets(EAST) && QDELETED(brackets), "brackets_fitted_east")

	// The bar only goes in from the brackets' side, and bars the door both ways.
	var/obj/item/door_bar/bar = new
	door_bars_hands(west, bar, null)
	D.attackby(bar, west)
	door_bars_assert(!D.door_barred() && !QDELETED(bar), "no_brackets_on_west")
	door_bars_hands(east, bar, null)
	D.attackby(bar, east)
	door_bars_assert(D.door_barred() && D.door_bar_on(EAST) == "wood" && QDELETED(bar), "barred")
	door_bars_assert(!D.canOpen(west) && !D.canOpen(east), "barred_both_ways")
	door_bars_assert(!D.door_workable(), "barred_not_workable")
	door_bars_assert(D.fitting_images && D.fitting_images.len, "bar_overlay")

	// Pushing from the far side does nothing; the bar's side lifts it.
	D.attack_hand(west)
	door_bars_assert(D.door_barred() && !D.state, "far_side_cannot_lift")
	door_bars_hands(east, null, null)
	D.attack_hand(east)
	door_bars_assert(!D.door_barred() && istype(east.r_hand, /obj/item/door_bar), "bar_lifted")
	bar = east.r_hand
	D.attackby(bar, east)
	door_bars_assert(D.door_barred(), "barred_again")

	// Blows land on the bar first; a broken bar frees the door.
	var/health_before = D.health
	D.update_damage(-100)
	door_bars_assert(D.health == health_before && D.door_bar_health["[EAST]"] == 50, "bar_takes_blows")
	D.update_damage(-60)
	door_bars_assert(!D.door_barred() && D.health == health_before - 10, "bar_snaps_rest_to_door")
	door_bars_assert(D.door_has_brackets(EAST), "brackets_stay")

	// A slide bolt on the west: grab shoots it, a hand draws it.
	var/obj/item/door_bolt/bolt = new
	door_bars_hands(west, bolt, hammer)
	D.attackby(bolt, west)
	door_bars_assert(D.door_bolt_side == WEST && !D.door_bolt_shot, "bolt_fitted")
	door_bars_hands(west, null, null)
	west.a_intent = I_GRAB
	D.attack_hand(west)
	west.a_intent = I_HELP
	door_bars_assert(D.door_bolt_shot && !D.canOpen(east), "bolt_shot")
	D.attack_hand(east)
	door_bars_assert(D.door_bolt_shot, "bolt_holds_from_east")
	D.attack_hand(west)
	door_bars_assert(!D.door_bolt_shot, "bolt_drawn")

	// Taking the bolt off with a hammer returns it.
	door_bars_hands(west, hammer, null)
	D.attackby(hammer, west)
	door_bars_assert(!D.door_bolt_side && istype(west.l_hand, /obj/item/door_bolt), "bolt_removed")

	// Bracing: grab with an empty hand holds it shut against everyone else.
	door_bars_hands(east, null, null)
	east.a_intent = I_GRAB
	D.attack_hand(east)
	east.a_intent = I_HELP
	var/obj/item/door_hold/brace/brace = D.door_held()
	door_bars_assert(istype(brace) && east.r_hand == brace, "braced")
	door_bars_assert(!D.canOpen(west) && D.canOpen(east), "brace_blocks_others")
	door_bars_assert(brace.resist_strength() > 0, "brace_resists")
	east.drop_from_inventory(brace)
	door_bars_assert(!D.door_held() && D.canOpen(west), "brace_let_go")

	// A smashed door drops its bar.
	var/obj/structure/simple_door/key_door/anyone/wood/S = door_bars_door(8, 5)
	var/mob/living/human/smasher = door_bars_actor(9, 5, "Smasher")
	door_bars_hands(smasher, new /obj/item/door_brackets, hammer)
	S.attackby(smasher.r_hand, smasher)
	door_bars_hands(smasher, new /obj/item/door_bar/iron, null)
	S.attackby(smasher.r_hand, smasher)
	door_bars_assert(S.door_bar_on(EAST) == "iron", "iron_barred")
	var/turf/ST = S.loc
	qdel(S)
	door_bars_assert(locate(/obj/item/door_bar/iron) in ST, "smashed_drops_bar")

	// A spring latch can be shimmed with a knife from the key side, unless the
	// lock refuses it.
	var/obj/structure/simple_door/key_door/anyone/wood/L = door_bars_door(2, 9)
	var/mob/living/human/burglar = door_bars_actor(1, 9, "Burglar")
	var/datum/lock/latch = new
	latch.kind = "latch"
	latch.family = "warded"
	latch.code = 123
	latch.locked = TRUE
	latch.side = WEST
	host_set_lock(L, latch)
	latch.refuses = list("shim")
	var/obj/item/weapon/material/kitchen/utensil/knife/knife = new
	door_bars_hands(burglar, knife, null)
	burglar.stats["dexterity"] = list(500, 500)
	L.attackby(knife, burglar)
	door_bars_assert(latch.locked, "refused_shim")
	latch.refuses = null
	for (var/i in 1 to 12)
		if (!latch.locked)
			break
		L.attackby(knife, burglar)
	door_bars_assert(!latch.locked, "shimmed")

	// Every method can be refused at once.
	latch.refuses = list("all")
	door_bars_assert(latch.refuses_method("pick") && latch.refuses_method("force") && latch.refuses_method("crack"), "refuse_all")

	// A mapped door starts with its lock, keyed outside its inside.
	var/obj/structure/simple_door/key_door/anyone/wood/M = new(locate(10, 10, 1), null)
	door_bars_assert(!M.door_lock, "no_mapped_lock_by_default")
	M.mapped_lock = /obj/item/fitted_lock/tumbler
	M.mapped_lock_code = 4242
	M.mapped_lock_refuses = list("pick")
	M.inner_dir = NORTH
	var/datum/lock/ML = host_apply_mapped_lock(M)
	door_bars_assert(ML && M.door_lock == ML && ML.locked && ML.code == 4242, "mapped_lock_fitted")
	door_bars_assert(ML.side == SOUTH && ML.refuses_method("pick") && !ML.refuses_method("cut"), "mapped_lock_side_and_refusals")

/world/New()
	OpenPort("none")
	var/error = null
	try
		door_bars_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] ([probe_error.file]:[probe_error.line])"
	if (!error && door_bars_runtime)
		error = door_bars_runtime
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = door_bars_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
