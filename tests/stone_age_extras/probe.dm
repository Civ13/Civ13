// Native Stone Age extras probe, included by tests/ecology_spawning/run_linux.py, never by
// the game DME. It drives code/modules/1713/stone_age_extras.dm.
/world
	hub = ""
	hub_password = ""
	maxx = 30
	maxy = 30
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/extras_probe/New()
	map = src
/mob/living/human/extras_probe/New()
	icon_update = FALSE
	return
var/extras_failures = 0
var/extras_runtime_error = FALSE
/proc/extras_check(condition, label)
	if (!condition)
		extras_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	extras_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"


/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/extras_probe
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
		extras_music_checks()
		extras_sickle_checks()
		extras_herd_checks()
	catch(var/exception/e)
		extras_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = extras_failures, "runtime_error" = extras_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/extras_probe_human(x, y)
	var/mob/living/human/extras_probe/H = new(locate(x, y, 1))
	H.real_name = "Probe [x] [y]"
	H.stat = CONSCIOUS
	return H

/proc/extras_music_checks()
	var/mob/living/human/A = extras_probe_human(3, 3)
	var/mob/living/human/B = extras_probe_human(5, 3)
	var/obj/item/stone_age_instrument/frame_drum/D = new(locate(3, 3, 1))
	extras_check(D.cheer_listeners(A) == 2, "music cheers everyone who hears it")
	extras_check(D.cheer_listeners(A) == 0 && B.next_music_mood > world.time, "listeners are cheered only once in a while")

/proc/extras_sickle_checks()
	var/obj/item/weapon/material/kitchen/utensil/knife/flint_sickle/S = new(locate(10, 9, 1))
	extras_check(S.name == "flint sickle" && is_tool(S, TOOL_KNIFE), "the flint sickle keeps its name and cuts like a knife")
	var/mob/living/human/H = extras_probe_human(10, 9)
	var/list/crops = list()
	for (var/i = 0 to 3)
		var/obj/structure/farming/plant/wheat/W = new(locate(10 + i, 10, 1))
		W.stage = W.readyStageMin
		crops += W
	var/obj/structure/farming/plant/wheat/far = new(locate(15, 10, 1))
	far.stage = far.readyStageMin
	var/obj/structure/farming/plant/wheat/first = crops[1]
	extras_check(length(first.sickle_neighbours()) == 1, "only touching ripe crops are reaped together")
	var/obj/structure/farming/plant/wheat/mid = crops[2]
	mid.attackby(S, H)
	var/left = 0
	for (var/obj/structure/farming/plant/wheat/W in crops)
		if (!QDELETED(W))
			left++
	extras_check(left == 1 && !QDELETED(far), "a sickle reaps the crop and the ripe ones beside it")
	extras_check(!sickle_reaping, "reaping leaves no stuck state")
	var/obj/item/weapon/material/kitchen/utensil/knife/K = new(locate(10, 9, 1))
	var/obj/structure/farming/plant/wheat/a = new(locate(20, 20, 1))
	var/obj/structure/farming/plant/wheat/b = new(locate(21, 20, 1))
	a.stage = a.readyStageMin
	b.stage = b.readyStageMin
	a.attackby(K, H)
	extras_check(QDELETED(a) && !QDELETED(b), "a plain knife reaps one crop")

/proc/extras_herd_checks()
	var/mob/living/simple_animal/bison/A = new(locate(5, 25, 1))
	var/mob/living/simple_animal/bison/B = new(locate(7, 25, 1))
	var/mob/living/simple_animal/bison/far = new(locate(25, 5, 1))
	extras_check(A.herd_alarm() == 1, "a hurt bison sets its herd running")
	extras_check(A.herd_alarm() == 0, "the herd alarm does not repeat at once")
	extras_check(B.next_herd_alarm > world.time && !far.next_herd_alarm, "only bison nearby bolt")
	var/before = A.next_herd_alarm
	A.next_herd_alarm = 0
	B.next_herd_alarm = 0
	A.adjustBruteLoss(10)
	extras_check(A.next_herd_alarm > 0 && before > 0, "hurting a bison raises the alarm")
