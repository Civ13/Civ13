// Native regression probe for beehive issues #4233, #4234 and #4235.
/world
	hub = ""
	hub_password = ""
	maxx = 16
	maxy = 8
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/bee_probe/New()
	return
/mob/living/human/bee_probe/New()
	return

var/bee_failures = 0
var/bee_runtime_error = FALSE
/proc/bee_check(condition, label)
	if (!condition)
		bee_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	bee_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/bee_probe
		populate_material_list()
		bee_checks()
	catch(var/exception/e)
		bee_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = bee_failures, "runtime_error" = bee_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
	return

/proc/bee_count_items(turf/T, item_type)
	var/count = 0
	for (var/obj/item/I in T)
		if (istype(I, item_type))
			count += istype(I, /obj/item/stack) ? I:amount : 1
	return count

/proc/bee_checks()
	var/turf/race_turf = locate(2, 2, 1)
	var/obj/structure/beehive/race = new(race_turf)
	race.frames = 1
	race.honeycombs = 100
	var/mob/living/human/bee_probe/first = new(race_turf)
	var/mob/living/human/bee_probe/second = new(race_turf)
	spawn(0) race.attack_hand(first)
	spawn(0) race.attack_hand(second)

	var/turf/colony_turf = locate(4, 2, 1)
	var/obj/structure/beehive/colony = new(colony_turf)
	var/mob/living/human/bee_probe/dismantler = new(colony_turf)
	var/obj/item/weapon/screwdriver/tool = new(colony_turf)
	var/obj/item/bee_jar/jar = new(colony_turf)
	spawn(0) colony.attackby(tool, dismantler)

	var/turf/refund_turf = locate(6, 2, 1)
	var/obj/structure/beehive/refund = new(refund_turf)
	refund.frames = 3
	refund.honeycombs = 250
	var/mob/living/human/bee_probe/refunder = new(refund_turf)
	spawn(0) refund.attackby(tool, refunder)

	var/turf/lid_turf = locate(8, 2, 1)
	var/obj/structure/beehive/lid = new(lid_turf)
	lid.frames = 1
	lid.honeycombs = 100
	var/mob/living/human/bee_probe/lid_user = new(lid_turf)
	spawn(0) lid.attack_hand(lid_user)

	var/turf/smoke_turf = locate(10, 2, 1)
	var/obj/structure/beehive/smoke = new(smoke_turf)
	smoke.frames = 1
	smoke.honeycombs = 100
	smoke.bee_count = 20
	smoke.smoked = 1
	var/mob/living/human/bee_probe/smoke_user = new(smoke_turf)
	spawn(0) smoke.attack_hand(smoke_user)

	var/turf/moved_turf = locate(12, 2, 1)
	var/obj/structure/beehive/moved = new(moved_turf)
	var/mob/living/human/bee_probe/move_user = new(moved_turf)
	spawn(0) moved.attackby(tool, move_user)

	sleep(5)
	colony.attackby(jar, dismantler)
	lid.closed = TRUE
	smoke.smoked = 0
	moved.loc = locate(15, 2, 1)
	sleep(40)

	bee_check(race.frames == 0 && race.honeycombs == 0 && bee_count_items(race_turf, /obj/item/honey_frame/filled) == 1, "two harvesters receive one frame and never overdraw the hive")
	bee_check(!QDELETED(colony) && colony.bee_count == 20 && bee_count_items(colony_turf, /obj/item/stack/material/wood) == 0, "a colony added during dismantling survives without wood output")
	bee_check(QDELETED(refund) && bee_count_items(refund_turf, /obj/item/honey_frame) == 3 && bee_count_items(refund_turf, /obj/item/honey_frame/filled) == 2, "dismantling returns every frame and preserves filled frames")
	bee_check(bee_count_items(refund_turf, /obj/item/stack/material/wood) == 6, "successful dismantling still returns six wood")
	bee_check(lid.frames == 1 && lid.honeycombs == 100 && bee_count_items(lid_turf, /obj/item/honey_frame) == 0, "closing the lid during harvest prevents output")
	bee_check(smoke.frames == 1 && smoke.honeycombs == 100 && bee_count_items(smoke_turf, /obj/item/honey_frame) == 0, "smoke expiring during harvest prevents output")
	bee_check(!QDELETED(moved) && bee_count_items(moved_turf, /obj/item/stack/material/wood) == 0, "moving the target during dismantling cancels the wait")
