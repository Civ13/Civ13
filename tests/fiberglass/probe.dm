// Epoxy, fiberglass and aramid laminate (code/modules/1713/fiberglass.dm):
// the bakelizer epoxy setting and the layup table. The procs run; only the
// do_after wait and the probe mob's hands are stood in for.
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
/obj/map_metadata/fiberglass_probe/New()
	return
/mob/living/human/fiberglass_probe/New()
	return
/mob/living/human/fiberglass_probe/put_in_hands(obj/item/W)
	return FALSE
var/fg_failures = 0
var/fg_runtime_error = FALSE
var/fg_wait_ok = TRUE
/proc/fg_check(condition, label)
	if (!condition)
		fg_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	fg_runtime_error = TRUE
	world.log << "runtime error: [e] [e.file]:[e.line]"
/obj/structure/layup_table/layup_wait(mob/living/human/H)
	return fg_wait_ok


/proc/fg_count(turf/T, path)
	. = 0
	for (var/obj/item/stack/S in T)
		if (istype(S, path))
			. += S.amount

/proc/fg_checks(mob/living/human/fiberglass_probe/H, turf/T)
	H.a_intent = I_HELP
	var/obj/structure/bakelizer/K = new(T)
	K.setting = "epoxy"
	K.bakelizer_make()
	K.bakelizer_make()
	var/obj/item/weapon/reagent_containers/glass/bucket/B = new(H)
	K.attackby(B, H)
	fg_check(B.reagents.get_reagent_amount("epoxy") == 20, "the epoxy setting makes epoxy to draw off")
	fg_check(bakelizer_setting_age("epoxy") == 7, "epoxy waits for the Cold War")
	var/obj/structure/layup_table/L = new(locate(7, 5, 1))
	var/turf/LT = get_turf(L)
	var/obj/item/stack/material/glass_cloth/G = new(locate(8, 8, 1), 6)
	L.attackby(G, H)
	fg_check(G.amount == 6, "no epoxy, no layup")
	L.attackby(B, H)
	fg_check(L.reagents.get_reagent_amount("epoxy") == 20 && !B.reagents.total_volume, "epoxy pours into the pans")
	fg_wait_ok = FALSE
	L.attackby(G, H)
	fg_wait_ok = TRUE
	fg_check(G.amount == 6 && L.reagents.get_reagent_amount("epoxy") == 20 && L.icon_state == "layup_table", "an interrupted layup uses nothing")
	L.attackby(G, H)
	fg_check(G.amount == 3 && L.reagents.get_reagent_amount("epoxy") == 10 && fg_count(LT, /obj/item/stack/material/fiberglass) == 2, "three glass cloth and 10 epoxy set two fiberglass")
	var/obj/item/stack/material/kevlar/KV = new(locate(9, 8, 1), 3)
	L.attackby(KV, H)
	fg_check(QDELETED(KV) || KV.amount == 0, "kevlar is used")
	fg_check(fg_count(LT, /obj/item/stack/material/aramid_laminate) == 2 && L.reagents.get_reagent_amount("epoxy") == 0, "three Kevlar sheets bond into two aramid laminate")
	var/obj/item/stack/material/cloth/C = new(locate(9, 9, 1), 3)
	L.attackby(C, H)
	fg_check(C.amount == 3, "plain cloth is not laid up")
	for (var/name in list("glass_cloth", "fiberglass", "aramid_laminate"))
		var/material/M = get_material_by_name(name)
		fg_check(M && M.stack_type, "[name] is a material")

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/fiberglass_probe
		map.ordinal_age = 1
		populate_material_list()
		var/turf/T = locate(5, 5, 1)
		var/mob/living/human/fiberglass_probe/H = new(locate(5, 6, 1))
		fg_check(!world.port, "fixture has no listening port")
		fg_checks(H, T)
	catch(var/exception/e)
		fg_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = fg_failures, "runtime_error" = fg_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
