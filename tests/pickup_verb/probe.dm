// Native probe: the right-click Pick up verb on items, including seated players.
// Real humans and native pixel moves; headless authority is an explicit adapter.
/world
	hub = ""
	visibility = 0
	maxx = 16
	maxy = 16
	maxz = 1
	fps = 20
	turf = /turf/floor/plating/pickup_verb_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/pickup_verb_probe/New()
	map = src

/turf/floor/plating/pickup_verb_probe
	var/entered_count = 0

/turf/floor/plating/pickup_verb_probe/Entered(atom/movable/M, atom/old)
	if (ishuman(M))
		entered_count++
	return ..()

/mob/living/human/pickup_verb_probe/human_subtile_authority(client/owner)

var/pickup_verb_probe_checks = 0
var/pickup_verb_probe_log = ""

/proc/pickup_verb_probe_assert(ok, label)
	pickup_verb_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/pickup_verb_probe_actor(tx, ty)
	var/mob/living/human/pickup_verb_probe/H = new(locate(tx, ty, 1))
	H.canmove = TRUE
	H.stat = CONSCIOUS
	H.lastarea = get_area(H)
	H.real_name = "Picker"
	H.name = H.real_name
	H.set_human_subtile(TRUE)
	return H

// Run the right-click Pick up verb as the picker and report whether the item
// ended up in the active hand. setup is "", "seated", "offset" or "far".
/proc/pickup_verb_probe_try(setup, ix, iy)
	var/mob/living/human/pickup_verb_probe/H = pickup_verb_probe_actor(5, 5)
	var/obj/structure/bed/chair/seat
	if (setup == "seated")
		seat = new(H.loc)
		seat.buckle_mob(H)
	if (setup == "offset")
		H.step_x = 10
		H.step_y = -6
	var/obj/item/I = new /obj/item/weapon/material/kitchen/utensil/knife(locate(ix, iy, 1))
	usr = H
	I.verb_pickup()
	. = H.get_active_hand() == I
	pickup_verb_probe_log += "[setup] [ix],[iy] canmove=[H.canmove] buckled=[!!H.buckled] held=[.]\n"
	qdel(I)
	if (seat)
		seat.unbuckle_mob()
		qdel(seat)
	qdel(H)

/proc/pickup_verb_probe_run()
	config = new
	config.webhook_can_fire = FALSE
	makeDatumRefLists()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	GLOB.stat_set_event = new
	GLOB.name_set_event = new
	movementMachine = new
	ticker = new
	map = new /obj/map_metadata/pickup_verb_probe
	pickup_verb_probe_assert(world.byond_version == 516 && world.byond_build == 1688, "pinned_native_engine")
	pickup_verb_probe_assert(pickup_verb_probe_try("", 5, 5), "picks_up_from_own_tile")
	pickup_verb_probe_assert(pickup_verb_probe_try("", 6, 5), "picks_up_from_next_tile")
	pickup_verb_probe_assert(pickup_verb_probe_try("offset", 6, 5), "picks_up_mid_step")
	// Players sitting in a chair cannot walk (canmove is off) but can still
	// reach: clicking picks things up, and so must the right-click verb.
	pickup_verb_probe_assert(pickup_verb_probe_try("seated", 5, 5), "seated_picks_up_from_own_tile")
	pickup_verb_probe_assert(pickup_verb_probe_try("seated", 6, 5), "seated_picks_up_from_next_tile")
	// Out of reach stays refused.
	pickup_verb_probe_assert(!pickup_verb_probe_try("", 7, 5), "refuses_two_tiles_away")

/world/New()
	OpenPort("none")
	var/error = null
	try
		pickup_verb_probe_run()
	catch (var/exception/probe_error)
		error = probe_error.name
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = pickup_verb_probe_checks, "error" = error, "log" = pickup_verb_probe_log, "byond_build" = byond_build)), "receipt.json")
	del(world)
