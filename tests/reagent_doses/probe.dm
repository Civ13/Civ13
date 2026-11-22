// Native probe: reagent dose fixes (#6295, #6310, #6312, #6335).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/reagent_doses/probe.dm
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
/obj/map_metadata/rd_probe/New()
	return

var/rd_failures = 0
var/rd_runtime_error = FALSE
/proc/rd_check(condition, label)
	if (!condition)
		rd_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	rd_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.name_set_event = new /decl/observ/name_set
		GLOB.stat_set_event = new /decl/observ/stat_set
		makeDatumRefLists()
		movementMachine = new
		map = new /obj/map_metadata/rd_probe
		rd_checks()
	catch(var/exception/e)
		rd_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = rd_failures, "runtime_error" = rd_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/rd_reagent(datum/reagents/holder, id, amount)
	holder.add_reagent(id, amount)
	for (var/datum/reagent/R in holder.reagent_list)
		if (R.id == id)
			return R
	return null

/proc/rd_checks()
	// #6295: crack overdose damages the brain by the amount metabolized this tick.
	var/mob/living/human/addict = new(locate(2, 2, 1))
	var/datum/reagent/crack/C = rd_reagent(addict.bloodstr, "crack", 30)
	C.dose = 25
	var/brain_before = addict.getBrainLoss()
	C.on_mob_life(addict, 0, CHEM_BLOOD)
	rd_check(addict.getBrainLoss() > brain_before, "a crack overdose causes dose-scaled brain damage")

	// #6310: iced beer cools by its rate and stops at its target.
	var/mob/living/human/drinker = new(locate(3, 2, 1))
	var/datum/reagent/ethanol/iced_beer/B = rd_reagent(drinker.ingested, "iced_beer", 10)
	drinker.bodytemperature = 310
	B.affect_ingest(drinker, 0, 1)
	rd_check(abs(drinker.bodytemperature - 280) < 0.01, "iced beer cools 310 K to 280 K on one tick")
	B.affect_ingest(drinker, 0, 1)
	rd_check(abs(drinker.bodytemperature - 270) < 0.01, "iced beer stops cooling at its 270 K target")

	// #6312: charcoal binds three units of poison per unit, shared across toxins.
	var/mob/living/human/patient = new(locate(4, 2, 1))
	patient.bloodstr.add_reagent("amatoxin", 10)
	patient.bloodstr.add_reagent("solanine", 10)
	charcoal_absorb_poisons(patient, 1)
	var/left = patient.bloodstr.get_reagent_amount("amatoxin") + patient.bloodstr.get_reagent_amount("solanine")
	rd_check(abs(left - 17) < 0.01, "one unit of charcoal binds three units of poison in total")

	// #6335: eye-slot goggles that cover the eyes keep pepper spray out.
	var/mob/living/human/goggled = new(locate(5, 2, 1))
	var/obj/item/clothing/glasses/tactical_goggles/ballistic/G = new(goggled)
	goggled.equip_to_slot_or_del(G, slot_eyes)
	rd_check(goggled.eyes == G, "the goggles are worn")
	var/datum/reagent/capsaicin/condensed/P = new
	goggled.eye_blind = 0
	P.affect_touch(goggled, 0, 1)
	rd_check(goggled.eye_blind == 0, "eye-covering goggles keep pepper spray out of the eyes")
	var/mob/living/human/bare = new(locate(6, 2, 1))
	bare.eye_blind = 0
	P.affect_touch(bare, 0, 1)
	rd_check(bare.eye_blind > 0, "uncovered eyes are still blinded")

	// #6738: eye-slot goggles that cover the eyes also block a dropper.
	var/obj/item/weapon/reagent_containers/dropper/D = new(locate(7, 2, 1))
	rd_check(D.eye_shield(goggled) == G, "eye-covering goggles shield the eyes from a dropper")
	rd_check(isnull(D.eye_shield(bare)), "a dropper reaches uncovered eyes")
