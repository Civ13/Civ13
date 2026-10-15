/world
	hub = ""
	hub_password = ""
	maxx = 12
	maxy = 12
	maxz = 2
	turf = /turf/floor/plating
	area = /area
	visibility = 0

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/mob/living/human/nitrary_tester/New()
	species = new /datum/species/human
	body_build = new /datum/body_build
	ingested = new /datum/reagents(100, src)
	reagents = new /datum/reagents(100, src)

/mob/living/human/nitrary_tester/religion_check()
	return "Production"

/mob/living/human/nitrary_tester/remove_from_mob(obj/O)
	if (l_hand == O)
		l_hand = null
	if (r_hand == O)
		r_hand = null
	O.loc = loc
	return TRUE

/obj/map_metadata/nitrary_tester/New()
	return

/mob/living/nitrary_nonhuman/New()
	return

/proc/check_nitrary(condition, message)
	if (!condition)
		throw EXCEPTION(message)
	world.log << "NITRARY PASS: [message]"

/proc/nitrary_hold(mob/living/human/H, obj/item/W)
	W.loc = H
	H.l_hand = W

/proc/ash_count(turf/site)
	var/count = 0
	for (var/obj/item/wood_ash/A in site)
		count++
	return count

/proc/nitrary_load(datum/D, turf/site, filename)
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/savefile/F = new(filename)
	F["/format_version"] << 2
	var/id = map_storage.BuildVarDirectory(F,D,1)
	F.Flush()
	F = null
	F = new(filename)
	map_storage.clear_bookkeeping()
	return map_storage.Load_Entry(F,id,starting_loc = site)

/proc/nitrary_age(obj/structure/compost/C, ticks)
	while (ticks > 0)
		var/step = min(600, ticks)
		C.nitrary_last_tick = world.time - step
		C.process()
		ticks -= step

/world/New()
	OpenPort("none")
	sleep(1)
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		GLOB.name_set_event = new
		text2file(json_encode(list("byond_version" = world.byond_version, "byond_build" = world.byond_build, "dimensions" = "12x12x2", "network" = "closed", "startup" = "disabled", "aging" = "controlled clock deltas through production process")), "fixture.json")
		map = new /obj/map_metadata/nitrary_tester
		var/turf/site = locate(3,3,1)
		var/mob/living/human/nitrary_tester/H = new(site)
		H.a_intent = I_HELP
		var/obj/structure/oven/O = new(site)
		var/obj/item/stack/material/wood/W = new(H)
		W.amount = 2
		O.attackby(W,H)
		check_nitrary(O.fuel == 2 && O.wood_residue.wood_remaining == 2 && !W.loc && ash_count(site) == 0, "refueling pays wood without producing ash")
		O.attackby(W,H)
		check_nitrary(O.fuel == 2, "queued deletion cannot refuel again")
		var/obj/item/stack/ore/coal/coal = new(H)
		coal.amount = 1
		O.attackby(coal,H)
		check_nitrary(O.fuel == 5 && O.wood_residue.wood_remaining == 2, "coal does not supply wood residue")
		O.burn_structure_fuel(2)
		check_nitrary(O.fuel == 3 && ash_count(site) == 2, "only paid burned wood leaves ash")
		O.burn_structure_fuel(2)
		check_nitrary(ash_count(site) == 2, "consumed wood cannot leave ash twice")
		O.burn_structure_fuel(20)
		check_nitrary(O.fuel == 0 && ash_count(site) == 2, "burn bounded to available fuel")
		var/obj/structure/oven/legacy = new(locate(4,3,1))
		legacy.fuel = 4
		legacy.after_load()
		legacy.burn_structure_fuel(4)
		check_nitrary(ash_count(get_turf(legacy)) == 0, "unattributed legacy fuel has no wood credit")
		var/obj/structure/oven/fireplace/fire = new(locate(5,3,1))
		fire.cooking_time = 1
		fire.attack_hand(H)
		check_nitrary(fire.fuel == 3 && ash_count(get_turf(fire)) == 1, "campfire construction wood produces paid residue")
		var/obj/structure/furnace/F = new(locate(6,3,1))
		W = new(H)
		W.amount = 3
		F.attackby(W,H)
		F.attack_hand(H)
		check_nitrary(F.fuel == 1 && F.wood_residue.wood_remaining == 1 && ash_count(get_turf(F)) == 2, "bloomery production ignition debits wood")
		var/obj/structure/machinery/factory/M = new(locate(7,3,1))
		W = new(H)
		W.amount = 3
		M.attackby(W,H)
		M.attack_hand(H)
		check_nitrary(M.fuel == 1 && M.wood_residue.wood_remaining == 1 && ash_count(get_turf(M)) == 2, "factory production ignition debits wood")
		var/datum/wood_fuel_residue/fraction = new(1.5)
		fraction.burn(0.5,1.5,site)
		var/datum/wood_fuel_residue/restored_fraction = nitrary_load(fraction, site, "fraction.sav")
		check_nitrary(restored_fraction.wood_remaining == 1 && restored_fraction.ash_fraction == 0.5, "native residue fractional progress preserved")
		restored_fraction.burn(0.5,1,site)
		check_nitrary(ash_count(site) == 3 && restored_fraction.ash_fraction == 0, "fractional burns mint only whole paid ash")
		var/obj/structure/oven/restored_oven = nitrary_load(O,locate(8,3,1),"oven.sav")
		check_nitrary(restored_oven.fuel == 0 && restored_oven.wood_residue.wood_remaining == 0, "spent structure ledger remains spent after native load")
		var/obj/item/wood_ash/A = locate() in site
		var/obj/item/weapon/reagent_containers/glass/small_pot/P = new(H)
		P.reagents.clear_reagents()
		P.reagents.add_reagent("water",P.reagents.maximum_volume)
		A.attackby(P,H)
		check_nitrary(A.loc && !P.reagents.get_reagent_amount("ash"), "full ash collector preserves residue")
		A.attackby(W,H)
		check_nitrary(A.loc, "non glass collector preserves residue")
		P.reagents.clear_reagents()
		A.attackby(P,H)
		A.attackby(P,H)
		check_nitrary(!A.loc && P.reagents.get_reagent_amount("ash") == 1, "ash collection pays one existing residue once")

		H.loc = locate(3,7,1)
		var/obj/structure/compost/C = new(H.loc)
		var/mob/living/nitrary_nonhuman/N = new(H.loc)
		check_nitrary(!C.nitrary_convert(N), "nonhuman cannot convert compost")
		C.current = 1
		check_nitrary(!C.nitrary_convert(H), "ordinary paid compost cannot be overwritten")
		C.current = 0
		check_nitrary(C.nitrary_convert(H), "existing empty bin converts without new station")
		var/obj/item/stack/material/leaf/L = new(H)
		L.amount = 40
		nitrary_hold(H,L)
		C.attackby(L,H)
		check_nitrary(L.amount == 8 && C.nitrary_plants == 8, "plant feedstock paid in full")
		C.attackby(L,H)
		check_nitrary(L.amount == 8 && C.nitrary_plants == 8 && C.nitrary_stage == 0, "plant credit capped and water required")
		var/obj/structure/compost/partial = nitrary_load(C,locate(4,7,1),"partial.sav")
		check_nitrary(partial.nitrary_mode && partial.nitrary_plants == 8 && partial.nitrary_water == 0, "native partial feedstock restored")
		P.reagents.clear_reagents()
		P.reagents.add_reagent("water",15)
		nitrary_hold(H,P)
		C.attackby(P,H)
		check_nitrary(C.nitrary_stage == 1 && C.nitrary_time_left == 18000 && P.reagents.get_reagent_amount("water") == 5, "paid plants and water require aging")
		C.process()
		check_nitrary(C.nitrary_stage == 1 && C.nitrary_time_left > 17990, "same tick cannot age batch")
		check_nitrary(!("nitrary_last_tick" in C.get_saved_vars()) && !("composting" in C.get_saved_vars()), "runtime clock excluded")
		C.nitrary_last_tick = -100000
		var/obj/structure/compost/aged = nitrary_load(C,locate(5,7,1),"aging.sav")
		check_nitrary(aged.nitrary_time_left == C.nitrary_time_left && aged.nitrary_last_tick == world.time && (aged in processing_objects), "native aging resumes without offline time")
		P.reagents.clear_reagents()
		P.reagents.add_reagent("ash",2)
		C.attackby(P,H)
		check_nitrary(P.reagents.get_reagent_amount("ash") == 2 && C.nitrary_stage == 1, "ash cannot skip aging")
		nitrary_age(C,17999)
		check_nitrary(C.nitrary_stage == 1, "batch immature before full aging")
		nitrary_age(C,1)
		check_nitrary(C.nitrary_stage == 2, "production process completes paid aging")
		C.attackby(P,H)
		check_nitrary(C.nitrary_stage == 3 && P.reagents.get_reagent_amount("ash") == 1 && C.nitrary_time_left == 600, "mature batch pays ash for timed leaching")
		P.reagents.clear_reagents()
		check_nitrary(!C.nitrary_draw(P,H), "leaching cannot be drawn early")
		nitrary_age(C,599)
		check_nitrary(C.nitrary_stage == 3, "leaching requires full interval")
		nitrary_age(C,1)
		check_nitrary(C.nitrary_stage == 4, "timed leaching completes")
		var/obj/structure/compost/ready = nitrary_load(C,locate(6,7,1),"ready.sav")
		check_nitrary(ready.nitrary_stage == 4 && ready.nitrary_plants == 8, "native completed paid batch restored")
		P.reagents.add_reagent("water",1)
		check_nitrary(!C.nitrary_draw(P,H) && C.nitrary_stage == 4, "nonempty pot cannot waste batch")
		P.reagents.clear_reagents()
		H.l_hand = null
		check_nitrary(!C.nitrary_draw(P,H), "unheld pot cannot draw")
		nitrary_hold(H,P)
		check_nitrary(C.nitrary_draw(P,H) && P.reagents.get_reagent_amount("nitrate_leachate") == 10 && !P.reagents.get_reagent_amount("potassium") && !P.reagents.get_reagent_amount("nitrogen"), "draw gives finite dilute leachate before boiling")
		check_nitrary(!C.nitrary_draw(P,H) && C.nitrary_stage == 0 && C.nitrary_plants == 0 && C.nitrary_water == 0, "batch can be drawn only once")
		var/obj/structure/oven/stove = new(H.loc)
		stove.cooking_time = 1
		stove.attackby(P,H)
		sleep(2)
		check_nitrary(P.reagents.get_reagent_amount("nitrate_leachate") == 10, "unlit stove does not boil leachate")
		W = new(H)
		W.amount = 2
		stove.attackby(W,H)
		stove.attack_hand(H)
		sleep(2)
		check_nitrary(!P.reagents.get_reagent_amount("nitrate_leachate") && P.reagents.get_reagent_amount("potassium") == 1 && P.reagents.get_reagent_amount("nitrogen") == 1, "actual small pot callback recovers legacy mineral IDs")
		stove.attackby(P,H)
		stove.attack_hand(H)
		sleep(2)
		check_nitrary(P.reagents.get_reagent_amount("potassium") == 1 && P.reagents.get_reagent_amount("nitrogen") == 1, "reboiling spent extract cannot mint minerals")
		text2file("PASS: wood residue and nitrary native disk round trips", "result.txt")
	catch (var/exception/E)
		world.log << "NITRARY exception: [E] at [E.file]:[E.line]"
		text2file("FAIL: [E.name]", "result.txt")
	shutdown()
