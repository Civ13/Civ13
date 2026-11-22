// Native butter probe, included by tests/ecology_spawning/run_linux.py, never
// by the game DME. It drives code/modules/1713/butter.dm and the crock potting hooks in preserves.dm.
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
/obj/map_metadata/butter_probe/New()
	map = src
/mob/living/human/butter_probe/New()
	icon_update = FALSE // no species: skip body overlays when held items change
	return
var/butter_failures = 0
var/butter_runtime_error = FALSE
/proc/butter_check(condition, label)
	if (!condition)
		butter_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	butter_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/butter_probe
		initialize_chemical_reactions()
		season = "SUMMER"
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		butter_churn_checks()
		butter_salt_checks()
		butter_spread_checks()
		butter_pot_checks()
	catch(var/exception/e)
		butter_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = butter_failures, "runtime_error" = butter_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)


var/butter_wait_ok = TRUE
/obj/item/weapon/reagent_containers/glass/butter_churn/churn_wait(mob/user)
	return butter_wait_ok

/proc/butter_count(turf/T, path)
	. = 0
	for (var/obj/O in T)
		if (O.type == path)
			.++

/proc/butter_churn_checks()
	var/turf/stand = locate(3, 3, 1)
	var/mob/living/human/butter_probe/H = new(stand)
	var/obj/item/weapon/reagent_containers/glass/butter_churn/C = new(locate(4, 3, 1))
	var/turf/CT = get_turf(C)
	C.reagents.add_reagent("milk", 25)
	C.flags &= ~OPENCONTAINER
	C.update_icon()
	butter_check(C.icon_state == "butter_churn_closed", "closed churn shows its lid")
	butter_check(!C.churn(H) && C.reagents.get_reagent_amount("milk") == 25, "25 milk is not enough to churn")
	C.flags |= OPENCONTAINER
	C.reagents.add_reagent("milk", 35)
	butter_check(!C.churn(H), "an open churn will not churn")
	C.flags &= ~OPENCONTAINER
	butter_wait_ok = FALSE
	butter_check(!C.churn(H) && C.reagents.get_reagent_amount("milk") == 60, "an interrupted churn makes nothing")
	butter_wait_ok = TRUE
	C.churn(H)
	butter_check(butter_count(CT, /obj/item/weapon/reagent_containers/food/snacks/butter) == 2, "60 milk churns two pats")
	butter_check(!C.reagents.get_reagent_amount("milk") && C.reagents.get_reagent_amount("buttermilk") == 40, "40 buttermilk is left")
	for (var/obj/item/weapon/reagent_containers/food/snacks/butter/B in CT)
		butter_check(B.reagents.get_reagent_amount("butter") == 10 && !B.salted_meat, "a fresh pat holds 10 butter")
		qdel(B)
	C.reagents.clear_reagents()
	C.reagents.add_reagent("cream", 30)
	C.reagents.add_reagent("sodiumchloride", 1)
	C.churn(H)
	butter_check(butter_count(CT, /obj/item/weapon/reagent_containers/food/snacks/butter/salted) == 1 && butter_count(CT, /obj/item/weapon/reagent_containers/food/snacks/butter) == 1, "30 cream with 1 salt gives one salted and one fresh pat")
	butter_check(!C.reagents.get_reagent_amount("sodiumchloride") && C.reagents.get_reagent_amount("buttermilk") == 10, "salt used, 10 buttermilk left")
	var/obj/item/weapon/reagent_containers/food/snacks/butter/salted/S = locate() in CT
	var/obj/item/weapon/reagent_containers/food/snacks/butter/F = new
	butter_check(S && S.decay == F.decay * 4, "salted butter keeps four times as long")
	qdel(F)
	for (var/obj/item/I in CT)
		qdel(I)
	qdel(C)
	qdel(H)

/proc/butter_salt_checks()
	var/turf/stand = locate(8, 8, 1)
	var/mob/living/human/butter_probe/H = new(stand)
	var/obj/item/weapon/reagent_containers/food/snacks/butter/B = new(stand)
	var/base = B.decay
	B.decaytimer = 600
	var/obj/item/weapon/reagent_containers/food/condiment/saltshaker/Sh = new(stand)
	Sh.afterattack(B, H, TRUE)
	butter_check(B.salted_meat && B.decay == base * 4 && B.decaytimer == 2400 && B.name == "salted butter" && B.icon_state == "butter_salted", "salting a pat keeps it four times as long")
	var/d = B.decay
	Sh.afterattack(B, H, TRUE)
	butter_check(B.decay == d, "a pat is not salted twice")
	B.rot()
	butter_check(B.rotten && B.icon_state == "butter_rancid" && B.name == "rancid salted butter", "spoiled butter goes rancid")
	for (var/obj/item/I in stand)
		qdel(I)
	qdel(H)

/proc/butter_spread_checks()
	var/turf/stand = locate(12, 12, 1)
	var/mob/living/human/butter_probe/H = new(stand)
	var/obj/item/weapon/reagent_containers/food/snacks/butter/B = new(stand)
	var/obj/item/weapon/reagent_containers/food/snacks/breadslice/S1 = new(stand)
	var/obj/item/weapon/reagent_containers/food/snacks/breadslice/S2 = new(stand)
	var/bread = S1.reagents.total_volume
	var/obj/item/weapon/reagent_containers/food/snacks/buttered_bread/BB = B.spread_butter(S1, H)
	butter_check(istype(BB) && QDELETED(S1) && BB.reagents.get_reagent_amount("butter") == 5 && BB.reagents.total_volume == bread + 5, "butter spreads on bread, keeping the bread")
	butter_check(!QDELETED(B) && B.reagents.get_reagent_amount("butter") == 5, "half the pat is left")
	B.spread_butter(S2, H)
	butter_check(QDELETED(B), "a pat spreads two slices")
	for (var/obj/item/I in stand)
		qdel(I)
	qdel(H)

/proc/butter_pot_checks()
	var/turf/stand = locate(20, 20, 1)
	var/mob/living/human/butter_probe/H = new(stand)
	var/obj/item/weapon/reagent_containers/glass/crock/C = new(locate(21, 20, 1))
	var/obj/item/weapon/reagent_containers/food/snacks/meat/raw = new(stand)
	butter_check(!C.pack_food(raw, H), "raw meat is refused")
	var/obj/item/weapon/reagent_containers/food/snacks/meat/M1 = new(stand)
	M1.raw = FALSE
	M1.roasted = TRUE
	var/obj/item/weapon/reagent_containers/food/snacks/meat/M2 = new(stand)
	M2.raw = FALSE
	butter_check(C.pack_food(M1, H) && C.pack_food(M2, H), "two cooked meats packed")
	var/obj/item/weapon/reagent_containers/food/snacks/butter/B = new(stand)
	C.flags &= ~OPENCONTAINER
	butter_check(!C.press_butter(B, H), "butter needs an open crock")
	C.flags |= OPENCONTAINER
	butter_check(C.press_butter(B, H) && QDELETED(B) && C.reagents.get_reagent_amount("butter") == 10, "a pat melts into the crock")
	C.flags &= ~OPENCONTAINER
	butter_check(C.crock_has_work(), "enough butter seals two pieces")
	C.flags |= OPENCONTAINER
	C.reagents.remove_reagent("butter", 5)
	C.reagents.add_reagent("lard", 4)
	C.flags &= ~OPENCONTAINER
	butter_check(!C.crock_has_work(), "9 fat cannot seal two")
	C.reagents.add_reagent("lard", 1)
	butter_check(C.crock_has_work(), "butter and lard seal together")
	C.crock_work()
	C.crock_work()
	butter_check(C.pot_progress == 2 && !M1.potted, "potting takes time")
	C.crock_work()
	butter_check(M1.potted && M2.potted && findtext(M1.name, "potted ") == 1, "both pieces are potted")
	butter_check(!C.crock_fat_amount() && !C.crock_has_work(), "the fat is used up")
	butter_check(crock_food_decay_step(M1, C) == 50, "potted food in a closed crock barely ages")
	var/obj/item/weapon/reagent_containers/food/snacks/meat/M3 = new(stand)
	M3.raw = FALSE
	butter_check(crock_food_decay_step(M3, C) == 300, "unpotted food ages as stored food")
	C.flags |= OPENCONTAINER
	butter_check(crock_food_decay_step(M1, C) == 300, "an open crock breaks the seal")
	butter_check(C.take_food(H) && C.pack_food(M2, H), "potted food can go back in")
	qdel(C)
	for (var/obj/item/I in stand)
		qdel(I)
	qdel(H)
