// Treated cloth (code/modules/1713/treated_cloth.dm): pitch, oil and beeswax
// worked into plain cloth make tarred canvas, oilcloth and waxed cloth. The
// treatment procs run; only the do_after wait and the probe mob's hands are
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
/obj/map_metadata/treated_cloth_probe/New()
	return
/mob/living/human/treated_cloth_probe
	var/obj/item/other_hand = null
/mob/living/human/treated_cloth_probe/get_inactive_hand()
	return other_hand
/mob/living/human/treated_cloth_probe/New()
	return
/mob/living/human/treated_cloth_probe/put_in_hands(obj/item/W)
	return FALSE
/mob/living/human/treated_cloth_probe/remove_from_mob(obj/O)
	return TRUE
var/cloth_failures = 0
var/cloth_runtime_error = FALSE
var/cloth_wait_ok = TRUE
/proc/cloth_check(condition, label)
	if (!condition)
		cloth_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	cloth_runtime_error = TRUE
	world.log << "runtime error: [e] [e.file]:[e.line]"
/obj/item/stack/material/cloth_treat_wait(mob/living/human/H)
	return cloth_wait_ok

/proc/cloth_count(turf/T, path)
	. = 0
	for (var/obj/item/stack/S in T)
		if (istype(S, path))
			. += S.amount

/proc/cloth_checks(mob/living/human/treated_cloth_probe/H)
	var/turf/here = get_turf(H)
	H.a_intent = I_HELP
	// Pitch.
	var/obj/item/stack/material/cloth/C = new(here, 10)
	var/obj/item/weapon/reagent_containers/glass/bucket/B = new(H)
	B.reagents.add_reagent("pitch", 4)
	C.attackby(B, H)
	cloth_check(C.amount == 10 && cloth_count(here, /obj/item/stack/material/tarred_canvas) == 0, "too little pitch coats nothing")
	B.reagents.add_reagent("pitch", 26)
	cloth_wait_ok = FALSE
	C.attackby(B, H)
	cloth_wait_ok = TRUE
	cloth_check(C.amount == 10 && B.reagents.get_reagent_amount("pitch") == 30, "an interrupted coating uses nothing")
	persistence_save_in_progress = TRUE
	C.attackby(B, H)
	persistence_save_in_progress = FALSE
	cloth_check(C.amount == 10, "no coating finishes during a world save")
	C.attackby(B, H)
	cloth_check(C.amount == 5 && B.reagents.get_reagent_amount("pitch") == 5 && cloth_count(here, /obj/item/stack/material/tarred_canvas) == 5, "pitch coats five sheets of tarred canvas at a time")
	H.a_intent = I_HARM
	C.attackby(B, H)
	H.a_intent = I_HELP
	cloth_check(C.amount == 5 && cloth_count(here, /obj/item/stack/material/tarred_canvas) == 5, "harm intent coats nothing")
	// Oil.
	B.reagents.clear_reagents()
	B.reagents.add_reagent("linseed_oil", 12)
	C.attackby(B, H)
	cloth_check(C.amount == 3 && B.reagents.get_reagent_amount("linseed_oil") == 2 && cloth_count(here, /obj/item/stack/material/oilcloth) == 2, "linseed oil makes oilcloth, one sheet per five units")
	B.reagents.clear_reagents()
	B.reagents.add_reagent("water", 20)
	C.attackby(B, H)
	cloth_check(C.amount == 3, "water makes nothing")
	// Wax.
	var/obj/item/weapon/beeswax/W = new(here)
	C.attackby(W, H)
	cloth_check(QDELETED(W) && C.amount == 0 && cloth_count(here, /obj/item/stack/material/waxed_cloth) == 3, "a cake of beeswax waxes three sheets")
	var/obj/item/stack/material/cloth/C2 = new(here, 2)
	var/obj/item/weapon/beeswax/W2 = new(here)
	W2.attackby(C2, H)
	cloth_check(QDELETED(W2) && cloth_count(here, /obj/item/stack/material/waxed_cloth) == 5, "cloth used on beeswax waxes it too")
	// Other cloths are left alone.
	var/obj/item/stack/material/silk/S = new(here, 5)
	B.reagents.add_reagent("olive_oil", 25)
	S.attackby(B, H)
	cloth_check(S.amount == 5 && B.reagents.get_reagent_amount("olive_oil") == 25, "silk is not oiled")
	// Latex and sulphur.
	var/obj/item/stack/material/cloth/C3 = new(here, 8)
	B.reagents.clear_reagents()
	B.reagents.add_reagent("latex", 40)
	C3.attackby(B, H)
	cloth_check(C3.amount == 8 && B.reagents.get_reagent_amount("latex") == 40, "latex without sulphur in the other hand cures nothing")
	var/obj/item/stack/ore/sulphur/SU = new(here, 2)
	H.other_hand = SU
	C3.attackby(B, H)
	cloth_check(C3.amount == 3 && SU.amount == 1 && B.reagents.get_reagent_amount("latex") == 15 && cloth_count(here, /obj/item/stack/material/rubberised_cloth) == 5, "latex and one sulphur cure five sheets of rubberised cloth")
	H.other_hand = null
	// Rain.
	var/obj/item/stack/material/rubberised_cloth/RC = locate() in here
	var/obj/item/clothing/suit/storage/jacket/custom/poncho/PO = new(here)
	cloth_check(coated_cloth_crafted(RC, PO) && PO.rain_resist == 90, "a poncho of rubberised cloth sheds more rain")
	var/obj/item/clothing/suit/storage/jacket/custom/poncho/PO2 = new(here)
	cloth_check(!coated_cloth_crafted(C3, PO2) && PO2.rain_resist == initial(PO2.rain_resist), "a poncho of plain cloth is unchanged")
	// Materials and recipes.
	for (var/name in list("tarred_canvas", "oilcloth", "waxed_cloth", "rubberised_cloth"))
		var/material/M = get_material_by_name(name)
		cloth_check(M && M.stack_type, "[name] is a material")
	var/obj/item/stack/material/oilcloth/O = locate() in here
	cloth_check(O && O.icon_state == "oilcloth" && ("oilcloth_4" in icon_states(O.icon)), "oilcloth has its pile sprites")

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/treated_cloth_probe
		map.ordinal_age = 1
		populate_material_list()
		var/mob/living/human/treated_cloth_probe/H = new(locate(5, 6, 1))
		cloth_check(!world.port, "fixture has no listening port")
		cloth_checks(H)
	catch(var/exception/e)
		cloth_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = cloth_failures, "runtime_error" = cloth_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
