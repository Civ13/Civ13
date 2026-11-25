// Full-source probe: fire doors, fusible links and panic bars (fire_doors.dm),
// and doors burning by material. A fire door is rated only shut, whole and set
// in masonry; a rated door stops fire spreading onto its tile and takes a small
// share of the heat; exposure spends its rating and burns the seals; a fusible
// link holds a door open until fire comes near; a panic bar opens a locked or
// bolted door from its side only; the closer can't be taken off.
/world
	hub = ""
	visibility = 0
	maxx = 12
	maxy = 12
	maxz = 1
	fps = 20
	turf = /turf/floor/plating/fire_doors_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/fire_doors_probe/New()
	map = src

/turf/floor/plating/fire_doors_probe

var/fire_doors_probe_checks = 0
var/fire_doors_runtime = null

/world/Error(exception/e)
	if (!fire_doors_runtime)
		fire_doors_runtime = "runtime [e] ([e.file]:[e.line])"

/proc/fire_doors_assert(ok, label)
	fire_doors_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/fire_doors_actor(tx, ty, name)
	var/mob/living/human/H = new(locate(tx, ty, 1))
	H.canmove = TRUE
	H.stat = CONSCIOUS
	H.real_name = name
	H.name = name
	H.hand = 0
	H.a_intent = I_HELP
	return H

/proc/fire_doors_open(obj/structure/simple_door/D)
	D.Open()
	sleep(12)

/proc/fire_doors_hands(mob/living/human/H, obj/item/active, obj/item/other)
	H.drop_l_hand()
	H.drop_r_hand()
	if (active)
		H.put_in_r_hand(active)
	if (other)
		H.put_in_l_hand(other)


// A door with walls north and south: people pass east-west.
/proc/fire_doors_door(tx, ty, path, wall = /turf/wall)
	new wall(locate(tx, ty + 1, 1))
	new wall(locate(tx, ty - 1, 1))
	var/obj/structure/simple_door/D = new path(locate(tx, ty, 1))
	sleep(10)
	return D

/proc/fire_doors_probe_run()
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
	map = new /obj/map_metadata/fire_doors_probe

	// A fire door in a stone wall is rated while shut and whole.
	var/obj/structure/simple_door/key_door/anyone/fire_door/F = fire_doors_door(5, 5, /obj/structure/simple_door/key_door/anyone/fire_door)
	fire_doors_assert(F.door_closer == "spring" && F.get_material_name() == "iron" && F.basic_icon == "firedoor_iron", "fire_door_built")
	fire_doors_assert(F.door_passage_axis() == EAST, "fire_door_axis")
	fire_doors_assert(F.fire_door_rated() && fire_blocked_at(get_turf(F)), "rated_in_masonry")

	// In a wooden wall it is not rated.
	var/obj/structure/simple_door/key_door/anyone/fire_door/W = fire_doors_door(9, 5, /obj/structure/simple_door/key_door/anyone/fire_door, /turf/wall/wood)
	fire_doors_assert(!W.fire_door_rated() && findtext(W.fire_rating_fault(), "masonry"), "wood_wall_not_rated")

	// Open, it is not rated and fire may spread onto its tile.
	F.Open()
	sleep(12)
	fire_doors_assert(F.state && !F.fire_door_rated() && !fire_blocked_at(get_turf(F)), "open_not_rated")
	F.Close()
	sleep(12)
	fire_doors_assert(!F.state && F.fire_door_rated(), "shut_rated_again")

	// Fire spreading stops at a rated door and passes an unrated one.
	fire_doors_assert(!fire_spread_to(get_turf(F)), "spread_blocked")
	var/obj/effect/fire/through = fire_spread_to(get_turf(W))
	fire_doors_assert(through, "spread_through_unrated")
	qdel(through)

	// A rated door takes a small share of the heat; a wooden door takes all of it.
	var/obj/structure/simple_door/key_door/anyone/wood/wood = fire_doors_door(2, 9, /obj/structure/simple_door/key_door/anyone/wood)
	var/wood_before = wood.health
	var/fire_before = F.health
	wood.fire_act(1200)
	F.fire_act(1200)
	fire_doors_assert(wood_before - wood.health >= 40 && fire_before - F.health <= 5, "heat_shares")

	// The closer is part of the assembly and can't come off.
	var/mob/living/human/east = fire_doors_actor(6, 5, "East")
	var/obj/item/weapon/screwdriver/screwdriver = new
	fire_doors_hands(east, screwdriver, null)
	F.remove_door_fitting(screwdriver, east)
	fire_doors_assert(F.door_closer == "spring", "closer_fixed")

	// Two nearby fires share the door's five-second debit interval.
	F.fire_rating_left = 60
	var/obj/effect/fire/first_fire = new(locate(4, 4, 1))
	var/obj/effect/fire/second_fire = new(locate(6, 4, 1))
	fire_nearby_doors(first_fire)
	fire_doors_assert(F.fire_rating_left == 10 && F.fire_seals_intact, "exposure_spends")
	fire_nearby_doors(second_fire)
	fire_doors_assert(F.fire_rating_left == 10 && F.fire_seals_intact, "two_fires_spend_rating_once")
	qdel(first_fire)
	qdel(second_fire)
	sleep(50)
	F.fire_door_exposure()
	fire_doors_assert(!F.fire_seals_intact && !F.fire_door_rated() && findtext(F.fire_rating_fault(), "spent"), "seals_burn")
	fire_doors_assert(F.fitting_images && F.fitting_images.len, "burnt_overlay")

	// Both workers can start, but only the first completed repair pays.
	var/mob/living/human/west = fire_doors_actor(4, 5, "West")
	var/obj/item/fire_seals/seals = new
	var/obj/item/fire_seals/spare_seals = new
	fire_doors_hands(east, seals, null)
	fire_doors_hands(west, spare_seals, null)
	spawn(0)
		F.attackby(seals, east)
	sleep(1)
	fire_doors_assert(!east.may_do_after && F.fire_rating_left == 0, "first_repair_waits_before_competing")
	F.attackby(spare_seals, west)
	fire_doors_assert(F.fire_seals_intact && F.fire_rating_left == F.fire_rating_full && QDELETED(seals) && F.fire_door_rated(), "seals_replaced")
	fire_doors_assert(!QDELETED(spare_seals) && west.get_active_hand() == spare_seals, "second_repair_preserves_held_seals")
	qdel(west)

	// A fusible link holds the door open until fire comes near.
	F.Open()
	sleep(12)
	var/obj/item/fusible_link/link = new
	fire_doors_hands(east, link, null)
	F.attackby(link, east)
	fire_doors_assert(F.fire_link_holding && QDELETED(link), "link_fitted")
	sleep(F.door_close_delay() + 20)
	fire_doors_assert(F.state, "link_holds_open")
	fire_doors_assert(!fire_blocked_at(get_turf(F)), "held_open_not_blocking")
	var/obj/effect/fire/blaze = new(locate(7, 5, 1))
	fire_nearby_doors(blaze)
	sleep(12)
	fire_doors_assert(!F.fire_link_holding && !F.state, "link_melts_door_shuts")
	qdel(blaze)

	// A hand unhooks a link and gets it back.
	F.Open()
	sleep(12)
	link = new
	fire_doors_hands(east, link, null)
	F.attackby(link, east)
	fire_doors_hands(east, null, null)
	F.attack_hand(east)
	fire_doors_assert(!F.fire_link_holding && istype(east.r_hand, /obj/item/fusible_link), "link_unhooked")
	sleep(F.door_close_delay() + 20)
	fire_doors_assert(!F.state, "closes_after_unhook")

	// A panic bar goes on with a screwdriver, on the fitter's side.
	var/obj/structure/simple_door/key_door/anyone/wood/P = wood
	var/obj/item/panic_bar/panic = new
	var/mob/living/human/inside = fire_doors_actor(3, 9, "Inside")
	var/mob/living/human/outside = fire_doors_actor(1, 9, "Outside")
	fire_doors_hands(inside, panic, null)
	P.attackby(panic, inside)
	fire_doors_assert(!P.panic_bar_side, "panic_needs_screwdriver")
	fire_doors_hands(inside, panic, screwdriver)
	P.attackby(panic, inside)
	fire_doors_assert(P.panic_bar_side == EAST && QDELETED(panic), "panic_fitted_east")

	// Locked, it opens from the bar's side and stays shut from the other.
	P.locked = TRUE
	P.door_bolt_side = EAST
	P.door_bolt_shot = TRUE
	fire_doors_hands(outside, null, null)
	P.attack_hand(outside)
	sleep(12)
	fire_doors_assert(P.door_bolt_shot && P.locked && !P.canOpen(outside), "outside_stays_shut")
	fire_doors_hands(inside, null, null)
	P.attack_hand(inside)
	sleep(12)
	fire_doors_assert(!P.door_bolt_shot && !P.locked && P.canOpen(inside), "panic_opens")
	fire_doors_assert(P.door_panic_release(inside) == FALSE, "nothing_left_to_release")

	// Taking the door down returns the bar.
	P.panic_bar_side = EAST
	P.fire_door_parts_returned(get_turf(P))
	fire_doors_assert(!P.panic_bar_side && (locate(/obj/item/panic_bar) in get_turf(P)), "parts_returned")

	// The steel door is rated longer.
	var/obj/structure/simple_door/key_door/anyone/fire_door/steel/S = fire_doors_door(5, 10, /obj/structure/simple_door/key_door/anyone/fire_door/steel)
	fire_doors_assert(S.fire_rating_full > F.fire_rating_full && S.basic_icon == "firedoor_steel" && S.get_material_name() == "steel", "steel_door")

/world/New()
	OpenPort("none")
	var/error = null
	try
		fire_doors_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] ([probe_error.file]:[probe_error.line])"
	if (!error && fire_doors_runtime)
		error = fire_doors_runtime
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = fire_doors_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
