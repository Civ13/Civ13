// Full-source probe for the rusty bolt effect (code/modules/1713/rusty_bolt.dm):
// which metal hums, range and clarity, deaf and duplicate listeners, the source
// cap, and that only strong transmitters drive it. Real humans and structures.
/world
	hub = ""
	visibility = 0
	maxx = 60
	maxy = 20
	maxz = 1
	fps = 20
	turf = /turf/floor/plating/rusty_bolt_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/rusty_bolt_probe/New()
	map = src

/turf/floor/plating/rusty_bolt_probe

/mob/living/human/rusty_bolt_probe
	var/heard = 0
	var/last_line = ""
	var/last_source = null

/mob/living/human/rusty_bolt_probe/hear_rusty_bolt(obj/source, line)
	heard++
	last_line = line
	last_source = source

var/rusty_bolt_probe_checks = 0

/proc/rusty_bolt_probe_assert(ok, label)
	rusty_bolt_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/rusty_bolt_probe_listener(tx, ty)
	var/mob/living/human/rusty_bolt_probe/H = new(locate(tx, ty, 1))
	H.stat = CONSCIOUS
	H.real_name = "Listener"
	H.name = H.real_name
	return H

/proc/rusty_bolt_probe_run()
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
	map = new /obj/map_metadata/rusty_bolt_probe
	rusty_bolt_probe_assert(world.byond_version == 516 && world.byond_build == 1688, "pinned_native_engine")

	rusty_bolt_probe_assert(rusty_bolt_clarity(1) == 64 && rusty_bolt_clarity(6) == 34 && rusty_bolt_clarity(10) == 30, "clarity_falls_with_distance")

	// Which metal hums.
	var/obj/structure/grille/chainlinkfence/fence = new(locate(10, 10, 1))
	rusty_bolt_probe_assert(fence.rusty_bolt_chance() > 0, "chain_link_hums")
	var/obj/structure/coolingfan/fan = new(locate(40, 10, 1))
	rusty_bolt_probe_assert(fan.rusty_bolt_chance() == 0, "stopped_fan_silent")
	fan.on = TRUE
	rusty_bolt_probe_assert(fan.rusty_bolt_chance() > 0, "running_fan_hums")
	var/obj/structure/bed/steel_bed = new(locate(50, 3, 1), "steel")
	var/obj/structure/bed/wood_bed = new(locate(50, 5, 1), "wood")
	rusty_bolt_probe_assert(steel_bed.rusty_bolt_chance() > 0 && wood_bed.rusty_bolt_chance() == 0, "only_metal_beds_hum")
	var/obj/structure/grille/logfence/palisade = new(locate(50, 7, 1))
	rusty_bolt_probe_assert(palisade.rusty_bolt_chance() == 0, "wooden_palisade_silent")
	qdel(steel_bed)
	qdel(wood_bed)
	qdel(palisade)

	// A transmitter three tiles from the fence; a listener beside the fence.
	var/obj/structure/radio/transmitter/nopower/mast = new(locate(7, 10, 1))
	var/mob/living/human/rusty_bolt_probe/near = rusty_bolt_probe_listener(11, 10)
	rusty_bolt_probe_assert(rusty_bolt_reradiate(mast, "hello hello this is the river station", null, 100) == 1, "fence_reradiates")
	rusty_bolt_probe_assert(near.heard == 1 && near.last_source == fence && length(near.last_line) == length("hello hello this is the river station"), "listener_hears_fence")
	rusty_bolt_probe_assert(rusty_bolt_reradiate(mast, "silent", null, 0) == 0 && near.heard == 1, "chance_can_miss")

	// Deaf and unconscious listeners hear nothing.
	near.ear_deaf = 5
	rusty_bolt_probe_assert(rusty_bolt_reradiate(mast, "anyone", null, 100) == 0 && near.heard == 1, "deaf_hears_nothing")
	near.ear_deaf = 0
	near.stat = UNCONSCIOUS
	rusty_bolt_probe_assert(rusty_bolt_reradiate(mast, "anyone", null, 100) == 0, "unconscious_hears_nothing")
	near.stat = CONSCIOUS

	// Out of range: the fence moves eight tiles from the mast.
	fence.forceMove(locate(15, 10, 1))
	near.forceMove(locate(16, 10, 1))
	rusty_bolt_probe_assert(rusty_bolt_reradiate(mast, "too far", null, 100) == 0 && near.heard == 1, "out_of_range_silent")
	fence.forceMove(locate(10, 10, 1))
	near.forceMove(locate(11, 10, 1))

	// Two fences beside one listener: heard once.
	var/obj/structure/grille/ironfence/iron = new(locate(11, 11, 1))
	rusty_bolt_probe_assert(rusty_bolt_reradiate(mast, "once only", null, 100) == 1 && near.heard == 2, "heard_once_per_line")

	// At most three humming sources per line.
	var/list/far_listeners = list()
	for (var/i in 1 to 4)
		new /obj/structure/grille/metalsheetfence(locate(3, 4 + i * 3, 1))
		far_listeners += rusty_bolt_probe_listener(2, 4 + i * 3)
	qdel(iron)
	// Five candidate sources (the chain-link fence and four sheet fences),
	// each with exactly one listener beside it; only three may hum.
	rusty_bolt_probe_assert(rusty_bolt_reradiate(mast, "capped", null, 100) == 3, "no_more_than_three_sources")

	// Only strong sets drive it: handhelds and unpowered mains sets do not.
	var/obj/item/weapon/radio/handheld = new(locate(7, 11, 1))
	rusty_bolt_probe_assert(rusty_bolt_from_radio(handheld, "walkie", null) == 0, "handheld_too_weak")
	var/obj/structure/radio/transmitter/unpowered = new(locate(7, 12, 1))
	rusty_bolt_probe_assert(rusty_bolt_from_radio(unpowered, "dead set", null) == 0, "unpowered_set_silent")

/world/New()
	OpenPort("none")
	var/error = null
	try
		rusty_bolt_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] ([probe_error.file]:[probe_error.line])"
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = rusty_bolt_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
