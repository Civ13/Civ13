// Native signal fire probe, included by tests/ecology_spawning/run_linux.py,
// never by the game DME. It drives code/modules/1713/signal_fires.dm through
// the real campfire attackby.
/world
	hub = ""
	hub_password = ""
	maxx = 400
	maxy = 400
	maxz = 2
	turf = /turf/floor/plating
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/client/New()
	del(src)
	return
/obj/map_metadata/signal_probe/New()
	map = src
/mob/living/human/signal_tester/New()
	return
/mob/living/human/signal_tester/adaptStat(stat, amount)
	return
/area/signal_probe_roofed
	location = AREA_INSIDE
var/signal_failures = 0
var/signal_runtime_error = FALSE
/proc/signal_check(condition, label)
	if (!condition)
		signal_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	signal_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/signal_probe
		signal_setup()
		signal_bearing_checks()
		signal_watcher_checks()
		signal_use_checks()
	catch(var/exception/e)
		signal_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = signal_failures, "runtime_error" = signal_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/signal_setup()
	var/area/A = get_area(locate(1, 1, 1))
	A.location = AREA_OUTSIDE
	A.climate = "temperate"
	A.weather = WEATHER_NONE
	// A roofed hut at 70,70-74,74.
	var/area/signal_probe_roofed/R = new
	for (var/turf/T in block(locate(70, 70, 1), locate(74, 74, 1)))
		R.contents += T

/proc/signal_bearing_checks()
	var/turf/F = locate(50, 50, 1)
	signal_check(signal_fire_bearing(locate(50, 40, 1), F) == "to the north, close by", "a fire straight north is north (the old code said nothing)")
	signal_check(signal_fire_bearing(locate(50, 120, 1), F) == "to the south, some way off", "a fire straight south is south")
	signal_check(signal_fire_bearing(locate(150, 50, 1), F) == "to the west, far off", "a fire straight west, far off")
	signal_check(signal_fire_bearing(locate(350, 50, 1), F) == "to the west, very far off", "three hundred tiles is very far off")
	signal_check(signal_fire_bearing(locate(40, 40, 1), F) == "to the north-east, close by", "diagonals read north-east")
	signal_check(signal_fire_bearing(locate(51, 51, 1), F) == "right beside you", "next to the fire")

/proc/signal_tester(x, y, z = 1)
	var/mob/living/human/H = new /mob/living/human/signal_tester(locate(x, y, z))
	human_mob_list |= H // The stub New() skips the normal registration.
	return H

/proc/signal_watcher_checks()
	var/obj/structure/oven/fireplace/FP = new(locate(50, 50, 1))
	FP.on = TRUE
	var/mob/living/human/signaller = signal_tester(51, 50)
	var/mob/living/human/north = signal_tester(50, 20)
	var/mob/living/human/edge = signal_tester(350, 350)
	var/mob/living/human/beyond = signal_tester(351, 50)
	var/mob/living/human/upstairs = signal_tester(50, 45, 2)
	var/mob/living/human/indoors = signal_tester(72, 72)
	var/mob/living/human/asleep = signal_tester(45, 45)
	asleep.sleeping = 5
	var/mob/living/human/blind = signal_tester(46, 45)
	blind.blinded = TRUE
	var/list/seen = FP.signal_fire_watchers(signaller)
	signal_check((north in seen) && (edge in seen), "people outdoors within 300 tiles see it, including straight north and the far corner")
	signal_check(!(signaller in seen), "the signaller is told separately")
	signal_check(!(beyond in seen), "301 tiles is out of range")
	signal_check(!(upstairs in seen), "another level does not see it")
	signal_check(!(indoors in seen), "nobody under a roof sees it")
	signal_check(!(asleep in seen) && !(blind in seen), "the asleep and the blind do not see it")
	// Symmetric: a fire under the roof reaches nobody, even outdoors next to it.
	var/obj/structure/oven/fireplace/hut = new(locate(71, 71, 1))
	hut.on = TRUE
	var/mob/living/human/outside_hut = signal_tester(69, 71)
	signal_check(!length(hut.signal_fire_watchers(null)) && !(outside_hut in hut.signal_fire_watchers(null)), "a roofed fire signals nobody")
	for (var/mob/M in list(signaller, north, edge, beyond, upstairs, indoors, asleep, blind, outside_hut))
		qdel(M)
	qdel(FP)
	qdel(hut)

/proc/signal_use_checks()
	var/obj/structure/oven/fireplace/FP = new(locate(20, 20, 1))
	var/mob/living/human/H = signal_tester(21, 20)
	var/obj/item/stack/material/cloth/C = new(null, 3, FALSE)
	FP.on = FALSE
	FP.attackby(C, H)
	signal_check(C.amount == 3 && FP.next_signal == 0, "an unlit fire sends nothing")
	FP.on = TRUE
	FP.attackby(C, H)
	signal_check(C.amount == 2 && FP.next_signal > world.time, "a signal uses one cloth and starts the cooldown")
	FP.attackby(C, H)
	signal_check(C.amount == 2, "a second signal inside the cooldown uses nothing")
	FP.next_signal = 0
	var/obj/item/stack/material/leather/L = new(null, 1, FALSE)
	FP.attackby(L, H)
	signal_check(QDELETED(L) || L.amount == 0, "leather works too and the last piece is used up")
	signal_check(FP.persistence_runtime_var("next_signal"), "the cooldown is not saved")
	var/obj/structure/oven/fireplace/hut = new(locate(72, 72, 1))
	hut.on = TRUE
	var/mob/living/human/H2 = signal_tester(72, 73)
	var/obj/item/stack/material/cloth/C2 = new(null, 2, FALSE)
	hut.attackby(C2, H2)
	signal_check(C2.amount == 2 && hut.next_signal == 0, "a roofed fire refuses and uses nothing")
	var/obj/structure/oven/fireplace/pit/P = new(locate(30, 30, 1))
	P.on = TRUE
	P.attackby(C2, H)
	signal_check(C2.amount == 1, "a fire pit signals too")
