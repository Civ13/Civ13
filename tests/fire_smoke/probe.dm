// Full-source probe: spreading fire smoke and compartments (fire_smoke.dm).
// Smoke fills the room it starts in, stops at walls, is kept out entirely by
// a shut rated fire door, leaks slowly past an ordinary shut door, flows
// through an open one, blinds when thick, chokes the unmasked, clears fast
// outdoors and slowly indoors.
/world
	hub = ""
	visibility = 0
	maxx = 12
	maxy = 12
	maxz = 1
	fps = 20
	turf = /turf/floor/plating/fire_smoke_probe
	area = /area/fire_smoke_probe_inside

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/fire_smoke_probe/New()
	map = src

/turf/floor/plating/fire_smoke_probe

var/fire_smoke_probe_checks = 0
var/fire_smoke_runtime = null

/world/Error(exception/e)
	if (!fire_smoke_runtime)
		fire_smoke_runtime = "runtime [e] ([e.file]:[e.line])"

/proc/fire_smoke_assert(ok, label)
	fire_smoke_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/fire_smoke_actor(tx, ty, name)
	var/mob/living/human/H = new(locate(tx, ty, 1))
	H.canmove = TRUE
	H.stat = CONSCIOUS
	H.real_name = name
	H.name = name
	H.hand = 0
	H.a_intent = I_HELP
	return H

/proc/fire_smoke_open(obj/structure/simple_door/D)
	D.Open()
	sleep(12)

/proc/fire_smoke_hands(mob/living/human/H, obj/item/active, obj/item/other)
	H.drop_l_hand()
	H.drop_r_hand()
	if (active)
		H.put_in_r_hand(active)
	if (other)
		H.put_in_l_hand(other)


/area/fire_smoke_probe_inside
	location = AREA_INSIDE

/area/fire_smoke_probe_outside
	location = AREA_OUTSIDE

/proc/fire_smoke_tick(times = 1)
	for (var/i in 1 to times)
		var/list/all = list()
		for (var/obj/effect/fire_smoke/S in world)
			all += S
		for (var/obj/effect/fire_smoke/S in all)
			if (!QDELETED(S))
				S.process()

/proc/fire_smoke_clear()
	for (var/obj/effect/fire_smoke/S in world)
		qdel(S)

/proc/fire_smoke_probe_run()
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
	map = new /obj/map_metadata/fire_smoke_probe

	// Two rooms, x 2-4 and x 6-8, y 2-8, split by a wall at x 5 with a doorway at (5,5).
	for (var/x in 1 to 9)
		new /turf/wall(locate(x, 1, 1))
		new /turf/wall(locate(x, 9, 1))
	for (var/y in 1 to 9)
		new /turf/wall(locate(1, y, 1))
		new /turf/wall(locate(9, y, 1))
		if (y != 5)
			new /turf/wall(locate(5, y, 1))
	var/obj/structure/simple_door/key_door/anyone/fire_door/F = new(locate(5, 5, 1))
	sleep(10)
	fire_smoke_assert(F.fire_door_rated(), "fire_door_rated")

	// Smoke fills its room and stops at walls and the rated door.
	var/turf/source = locate(3, 5, 1)
	for (var/i in 1 to 8)
		add_fire_smoke(source, 5)
		fire_smoke_tick()
	fire_smoke_assert(fire_smoke_at(source) == 5, "source_thick")
	fire_smoke_assert(fire_smoke_at(locate(4, 5, 1)) >= 3 && fire_smoke_at(locate(2, 2, 1)) >= 1, "room_fills")
	fire_smoke_assert(!fire_smoke_at(locate(6, 5, 1)) && !fire_smoke_at(locate(5, 5, 1)), "fire_door_keeps_it_out")
	fire_smoke_assert(!fire_smoke_at(locate(1, 5, 1)), "walls_keep_it_in")

	// Thick smoke blinds.
	var/obj/effect/fire_smoke/S = locate() in source
	fire_smoke_assert(S.opacity, "thick_is_opaque")
	var/obj/effect/fire_smoke/thin = locate() in locate(2, 2, 1)
	fire_smoke_assert(!thin.opacity, "thin_is_clear")

	// It chokes the unmasked, not the masked.
	var/mob/living/human/coughing = fire_smoke_actor(3, 5, "Coughing")
	var/before = coughing.getOxyLoss()
	fire_smoke_breathe(coughing, 5)
	fire_smoke_assert(coughing.getOxyLoss() > before, "smoke_chokes")
	var/mob/living/human/masked = fire_smoke_actor(3, 6, "Masked")
	var/obj/item/clothing/mask/gas/mask = new
	masked.equip_to_slot_or_del(mask, slot_wear_mask)
	before = masked.getOxyLoss()
	fire_smoke_breathe(masked, 5)
	fire_smoke_assert(masked.wear_mask == mask && masked.getOxyLoss() == before, "gas_mask_protects")

	// An ordinary shut door leaks a little.
	qdel(F)
	var/obj/structure/simple_door/key_door/anyone/wood/W = new(locate(5, 5, 1))
	sleep(10)
	var/leaked = 0
	for (var/i in 1 to 60)
		add_fire_smoke(source, 5)
		fire_smoke_tick()
		leaked = max(leaked, fire_smoke_at(locate(6, 5, 1)))
		if (leaked)
			break
	fire_smoke_assert(W.density && leaked == 1 && !fire_smoke_at(locate(5, 5, 1)) && !fire_smoke_at(locate(7, 5, 1)), "shut_door_leaks_a_wisp")

	// An open door lets it through.
	W.Open()
	sleep(12)
	for (var/i in 1 to 6)
		add_fire_smoke(source, 5)
		fire_smoke_tick()
	fire_smoke_assert(fire_smoke_at(locate(6, 5, 1)) >= 2, "open_door_passes")

	// Indoors with no fire it lingers, then thins.
	fire_smoke_clear()
	var/turf/still = locate(7, 3, 1)
	add_fire_smoke(still, 1)
	fire_smoke_tick(4)
	fire_smoke_assert(fire_smoke_at(still) == 1, "lingers_indoors")
	fire_smoke_tick(1)
	fire_smoke_assert(!fire_smoke_at(still), "thins_indoors")

	// Outdoors it clears fast.
	var/turf/open = locate(11, 11, 1)
	var/area/fire_smoke_probe_outside/outside = new
	outside.contents += open
	add_fire_smoke(open, 5)
	fire_smoke_tick()
	fire_smoke_assert(fire_smoke_at(open) == 3, "clears_outdoors")

/world/New()
	OpenPort("none")
	var/error = null
	try
		fire_smoke_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] ([probe_error.file]:[probe_error.line])"
	if (!error && fire_smoke_runtime)
		error = fire_smoke_runtime
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = fire_smoke_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
