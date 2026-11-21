// Silk (code/modules/1713/silk.dm): picking mulberry leaves and silkworm eggs
// in the silk lands, rearing silkworms in a tray, reeling cocoons in hot water,
// weaving silk thread at the loom, and silk as a material. The production procs
// run; only the do_after waits, the egg roll and the probe mob's hands are
// stood in for.
/world
	hub = ""
	hub_password = ""
	maxx = 12
	maxy = 12
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/silk_probe/New()
	return
/mob/living/human/silk_probe/New()
	return
/mob/living/human/silk_probe/put_in_hands(obj/item/W)
	return FALSE
/mob/living/human/silk_probe/remove_from_mob(obj/O)
	return TRUE
var/silk_failures = 0
var/silk_runtime_error = FALSE
var/silk_wait_ok = TRUE
var/silk_eggs_roll = FALSE
/proc/silk_check(condition, label)
	if (!condition)
		silk_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	silk_runtime_error = TRUE
	world.log << "runtime error: [e] [e.file]:[e.line]"
/obj/structure/wild/tree/live_tree/silk_pick_wait(mob/living/human/H)
	return silk_wait_ok
/obj/structure/wild/tree/live_tree/silk_egg_roll()
	return silk_eggs_roll
/obj/item/stack/silk_cocoons/silk_reel_wait(mob/living/human/H)
	return silk_wait_ok

/proc/silk_count(turf/T, path)
	. = 0
	for (var/obj/item/I in T)
		if (istype(I, path))
			if (istype(I, /obj/item/stack))
				var/obj/item/stack/S = I
				. += S.amount
			else
				.++

/proc/silk_checks(mob/living/human/silk_probe/H, turf/T)
	var/turf/here = get_turf(H)
	map.ID = MAP_NOMADS_EARTH_ASIA
	var/obj/structure/wild/tree/live_tree/M = new(locate(5, 7, 1))
	M.leaves = 2
	silk_check(M.mulberry_tree(), "a broadleaf tree in Asia is a mulberry")
	H.a_intent = I_HELP
	M.attack_hand(H)
	silk_check(silk_count(here, /obj/item/stack/material/leaf/mulberry) == 0, "help intent picks nothing")
	H.a_intent = I_GRAB
	silk_wait_ok = FALSE
	M.attack_hand(H)
	silk_wait_ok = TRUE
	silk_check(silk_count(here, /obj/item/stack/material/leaf/mulberry) == 0 && M.leaves == 2, "an interrupted picking gives nothing")
	M.attack_hand(H)
	silk_check(silk_count(here, /obj/item/stack/material/leaf/mulberry) == 2 && M.leaves == 1 && silk_count(here, /obj/item/silkworm_eggs) == 0, "grab intent picks 2 mulberry leaves")
	silk_eggs_roll = TRUE
	M.attack_hand(H)
	silk_eggs_roll = FALSE
	silk_check(silk_count(here, /obj/item/stack/material/leaf/mulberry) == 4 && silk_count(here, /obj/item/silkworm_eggs) == 1, "sometimes the leaves carry silkworm eggs")
	M.attack_hand(H)
	silk_check(silk_count(here, /obj/item/stack/material/leaf/mulberry) == 4, "a stripped mulberry gives no more leaves")
	var/obj/structure/wild/tree/live_tree/pine/P = new(locate(7, 7, 1))
	silk_check(!P.mulberry_tree(), "a pine is no mulberry")
	map.ID = MAP_NOMADS_GAIA
	silk_check(!M.mulberry_tree(), "on Gaia broadleaf trees are no mulberries")
	map.ID = "silk_probe_island"
	silk_check(M.mulberry_tree(), "a land that is no continent keeps its mulberries")
	// Rearing.
	var/obj/structure/silkworm_tray/S = new(T)
	var/obj/item/stack/material/leaf/plain = new(T, 6)
	S.attackby(plain, H)
	silk_check(S.leaves == 0 && plain.amount == 6, "ordinary leaves are refused")
	var/obj/item/stack/material/leaf/mulberry/L = new(T, 8)
	S.attackby(L, H)
	silk_check(S.leaves == 6 && L.amount == 2 && S.rear_left == 0, "the tray takes six mulberry leaves and waits for eggs")
	var/obj/item/silkworm_eggs/E = locate() in here
	S.attackby(E, H)
	silk_check(S.eggs && S.leaves == 0 && S.rear_left > 0, "eggs and leaves start a batch")
	S.rear_left = 50
	S.rear_tick()
	silk_check(S.rear_left == 0 && silk_count(T, /obj/item/stack/silk_cocoons) == 6 && S.eggs, "the batch gives six cocoons and keeps the eggs")
	S.attack_hand(H)
	silk_check(!S.eggs && silk_count(T, /obj/item/silkworm_eggs) == 1, "the eggs can be taken out again")
	// Reeling.
	var/obj/item/stack/silk_cocoons/C = locate() in T
	var/obj/item/weapon/reagent_containers/glass/bucket/B = new(H)
	B.reagents.add_reagent("water", 20)
	C.attackby(B, H)
	silk_check(C.amount == 6 && silk_count(here, /obj/item/stack/silk_thread) == 0, "cold water reels nothing")
	B.heated_until = world.time + 600
	persistence_save_in_progress = TRUE
	C.attackby(B, H)
	persistence_save_in_progress = FALSE
	silk_check(C.amount == 6, "no reeling finishes during a world save")
	C.attackby(B, H)
	silk_check(C.amount == 1 && silk_count(here, /obj/item/stack/silk_thread) == 5, "hot water reels five cocoons into five silk thread")
	// Material.
	var/obj/item/stack/material/silk/cloth = new(T, 2)
	silk_check(get_material_by_name("silk") && cloth.material && cloth.material.name == "silk", "silk is a material")

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/silk_probe
		map.ordinal_age = 1
		populate_material_list()
		var/turf/T = locate(5, 5, 1)
		var/mob/living/human/silk_probe/H = new(locate(5, 6, 1))
		silk_check(!world.port, "fixture has no listening port")
		silk_checks(H, T)
	catch(var/exception/e)
		silk_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = silk_failures, "runtime_error" = silk_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
