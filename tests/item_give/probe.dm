// Run with the isolated ecology_spawning/run_linux.py fixture and this file.
/world
	hub = ""
	hub_password = ""
	maxx = 8
	maxy = 8
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/give_probe/New()
	return
/mob/living/human/give_probe/New()
	icon_update = FALSE
	hand = FALSE
	return
var/give_failures = 0
var/give_runtime_error = FALSE
/proc/give_check(condition, label)
	if (!condition)
		give_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	give_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.global_listen_count = list()
		GLOB.event_sources_count = list()
		GLOB.event_listen_count = list()
		movementMachine = new
		populate_material_list()
		map = new /obj/map_metadata/give_probe
		give_probe_checks()
	catch(var/exception/e)
		give_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = give_failures, "runtime_error" = give_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/give_probe_checks()
	var/turf/ground = locate(4,4,1)
	ground = ground.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	var/turf/nearby = locate(5,4,1)
	nearby = nearby.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	var/mob/living/human/give_probe/giver = new(ground)
	var/mob/living/human/give_probe/receiver = new(nearby)
	var/obj/item/stack/material/stone/floor_stack = new(ground, 2, FALSE)
	var/obj/item/stack/material/stone/offered = new(giver, 3, FALSE)
	giver.r_hand = offered

	giver.stunned = 5
	give_check(!giver.give_held_item(offered, receiver) && giver.r_hand == offered && offered.loc == giver, "stunned giver retains the item")
	giver.stunned = 0
	receiver.stunned = 5
	give_check(!giver.give_held_item(offered, receiver) && giver.r_hand == offered && offered.loc == giver, "stunned recipient does not move the item")
	receiver.stunned = 0
	offered.nodrop = TRUE
	give_check(!giver.give_held_item(offered, receiver) && giver.r_hand == offered && offered.loc == giver, "a no-drop stack remains held")
	offered.nodrop = FALSE
	receiver.lying = TRUE
	give_check(!giver.give_held_item(offered, receiver) && giver.r_hand == offered && offered.loc == giver, "a recipient unable to use an empty hand cannot displace the stack")
	receiver.lying = FALSE

	var/obj/item/stack/material/stone/blocker = new(receiver, 1, FALSE)
	receiver.r_hand = blocker
	give_check(giver.give_held_item(offered, receiver), "accepted stack goes directly into an available inactive hand")
	give_check(!giver.r_hand && receiver.r_hand == blocker && receiver.l_hand == offered && offered.loc == receiver && offered.amount == 3, "the exact three-unit stack changes hands once")
	give_check(!QDELETED(floor_stack) && floor_stack.loc == ground && floor_stack.amount == 2, "the neighboring floor stack remains unchanged")
